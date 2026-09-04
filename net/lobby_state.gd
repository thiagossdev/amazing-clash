extends Node
## Server-authoritative room state: each connected peer's chosen
## character class (CharacterSelect, before ever connecting), team
## (Team mode only, self-service -- see set_local_team()), perk (Room
## Config, self-service), and ready flag -- plus the room-level
## settings the host picks in Room Config (match mode, friendly fire).
## Read by PlayerSpawner instead of its old index-cycling default -- a
## peer with no registered choice (e.g. a net/dev_bootstrap.gd headless
## test peer, which never goes through CharacterSelect/Room Config)
## falls back to PlayerSpawner's original cycling behavior unchanged
## (or, for perks, no perk at all -- all multipliers 1.0), so every
## prior phase's headless verification keeps working untouched. See
## memory/plan.md's "Slices 7-10" section.
##
## Phase 8: grew from a class-only registry to full room state (team,
## ready, mode, friendly fire) rather than adding a second parallel
## registry -- this node already *is* "the room's shared state," not
## just a class picker, so generalizing its existing name/shape fit
## better than inventing a sibling. Phase 9: grew again with perk_id,
## same reasoning; also corrected team assignment from host-controlled
## to self-service (see set_local_team()'s own doc comment) -- a real
## authority bug the human owner caught, not part of Phase 8's original
## design.

## Fired on every peer whenever any room state changes (class, team,
## perk, ready, mode, or friendly fire) -- ui/lobby/lobby.gd's Room
## Config screen listens to this to redraw itself.
signal room_state_changed

## Fired on every peer whenever the countdown's own broadcast value
## changes (Phase 14) -- see countdown_seconds_remaining's own doc
## comment below. Kept separate from room_state_changed so
## ui/lobby/lobby.gd can update just the countdown label without
## rebuilding its whole player-row list every second.
signal countdown_changed

## Canonical class id strings, in the same order as
## net/player_spawner.gd's CLASS_SCENES -- CharacterSelect and
## PlayerSpawner both key off these, never a raw index, so adding a
## 4th class later only touches this list plus CLASS_SCENES.
const CLASS_IDS: Array[String] = ["vanguard", "ranged_mage", "warden"]

## Canonical perk id strings, in the same order as PERK_RESOURCES below
## -- one fixed pool, identical for every class (confirmed by the human
## owner, see memory/plan.md's "Slices 8-10" Perks block), so unlike
## CLASS_IDS this list never varies per character.
const PERK_IDS: Array[String] = ["vitality", "swift", "adept", "balanced"]

## Lives here (an autoload), not on PlayerSpawner (a class_name script
## CharacterController would need to reference), specifically so
## CharacterController._apply_perk_from_lobby_state() can read it
## without creating a circular class_name dependency between the two
## scripts -- confirmed as a real breakage, not a theoretical one: it
## broke a pre-existing `var x: CharacterController = ...instantiate()`
## typed assignment project-wide when first tried on PlayerSpawner
## (Godot silently fell back to treating instances as the untyped base
## CharacterBody2D). Autoload singleton access doesn't have this
## problem, same reason CharacterController already safely references
## NetworkManager/LobbyState/MatchState elsewhere.
const PERK_RESOURCES: Array[PerkResource] = [
	preload("res://data/perks/vitality.tres"),
	preload("res://data/perks/swift.tres"),
	preload("res://data/perks/adept.tres"),
	preload("res://data/perks/balanced.tres"),
]

## Team id -> display label. team_id itself stays a plain int (0/1)
## everywhere else -- this is a label-only change (Phase 14, the human
## owner's own request), not a data model change.
const TEAM_LABELS: Array[String] = ["Red", "Blue"]

## Phase 14: server-only countdown that starts once is_room_ready_to_
## start() goes true, and auto-triggers the match the same way the old
## host-only Start button used to. countdown_seconds_remaining (below)
## is the one client-visible piece of it -- -1.0 whenever nothing is
## counting down (either the room isn't ready yet, or it's still inside
## the silent PRE_DELAY_SECONDS grace window before the visible
## countdown appears). _countdown_generation is server-only bookkeeping:
## bumped by _cancel_countdown()/_run_countdown() so an in-flight
## coroutine can tell it's been superseded and exit cleanly instead of
## fighting a newer one or a cancellation.
const PRE_DELAY_SECONDS := 2.0
const COUNTDOWN_SECONDS := 5.0

## Set locally by CharacterSelect before ever connecting; read once,
## right after a successful host()/join(), by register_local_player().
## Not itself replicated -- only the registered outcome is.
var local_chosen_class_id: String = CLASS_IDS[0]

## Server-authoritative peer_id -> class_id. Mirrored to every client
## via full-dictionary broadcast on every change (not a delta) so a
## peer connecting after others already registered gets caught up for
## free, the same "no separate catch-up path needed" reasoning
## MatchState's team_status broadcast can't rely on (that one only
## fires once per transition, not once per registration).
var player_class_ids: Dictionary = {}

## Server-authoritative peer_id -> team id (0/1), Team mode only -- FFA
## ignores this entirely, since PlayerSpawner already assigns a unique
## team per player in FFA with no manual input needed. Defaulted on
## registration by alternating connection order (the same formula
## PlayerSpawner used before Phase 8), then each peer can move their
## OWN team with set_local_team() -- self-service, not host-assigned;
## the host has no authority over another peer's team.
var player_team_ids: Dictionary = {}

## Server-authoritative peer_id -> perk id, self-service (any peer,
## including the host, picks their OWN perk) -- same authority shape as
## player_team_ids, never host-assigned. Defaulted to PERK_IDS[0] on
## registration, same "always valid, never missing" treatment as team.
var player_perk_ids: Dictionary = {}

## Server-authoritative peer_id -> ready flag, for every registered
## peer INCLUDING the host (Phase 14: readying up is symmetric now --
## there is no more host-only Start button, see ui/lobby/lobby.gd).
var player_ready: Dictionary = {}

## Room-level settings, staged in Room Config and applied to
## MatchState.match_mode/friendly_fire_enabled the moment the room
## actually starts (see _start_match() below, now triggered
## automatically by the ready countdown rather than a host-only Start
## button press). Broadcast continuously so every peer's Room Config
## screen reflects the host's current choice live; only the host can
## change them (read-only on other clients). Stored as plain int (not
## MatchState.MatchMode) purely so the RPC payload's type stays a
## primitive -- callers compare against MatchState.MatchMode's own
## enum values.
var room_match_mode: int = MatchState.MatchMode.TEAM
var room_friendly_fire: bool = false

## Client-visible: seconds remaining in the countdown, or -1.0 when
## nothing is counting down. See PRE_DELAY_SECONDS/COUNTDOWN_SECONDS'
## own doc comment above.
var countdown_seconds_remaining: float = -1.0

## Overridable for live dev testing (--dev-countdown-pre-delay=/
## --dev-countdown-seconds=, see _apply_dev_countdown_overrides()) --
## same "const default + overridable var" shape net/player_spawner.gd
## already uses for GRACE_PERIOD_SECONDS/_grace_period_seconds, so a
## real 2s+5s wait doesn't have to be eaten by every live headless test.
var _pre_delay_seconds: float = PRE_DELAY_SECONDS
var _countdown_seconds_config: float = COUNTDOWN_SECONDS
var _countdown_generation: int = 0

var _next_team_index: int = 0


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_apply_dev_countdown_overrides()


## Same convention as net/player_spawner.gd's own --dev-grace-period=
## handling: read OS.get_cmdline_user_args() directly here rather than
## routing through net/dev_bootstrap.gd, and guard with is_valid_float()
## -- a malformed value silently falling back to the production default
## was a real bug found by /check on that exact flag (see
## memory/gotchas.md), not repeating it here.
func _apply_dev_countdown_overrides() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dev-countdown-pre-delay="):
			var value := arg.trim_prefix("--dev-countdown-pre-delay=")
			if value.is_valid_float():
				_pre_delay_seconds = value.to_float()
		elif arg.begins_with("--dev-countdown-seconds="):
			var value := arg.trim_prefix("--dev-countdown-seconds=")
			if value.is_valid_float():
				_countdown_seconds_config = value.to_float()


func team_label(team_id: int) -> String:
	return TEAM_LABELS[resolve_team_id(team_id)]


## Pure: maps an arbitrary requested class id to a valid one, falling
## back to the first canonical id for anything unrecognized (including
## empty string). Extracted as its own function so it's unit-testable
## without any Node/multiplayer context, matching this project's
## WinCondition-style "pure logic gets a GUT test" convention.
func resolve_class_id(requested: String) -> String:
	return _resolve_id(requested, CLASS_IDS)


## Pure, same validate-or-default rule as resolve_class_id() -- kept as
## its own named function (rather than callers using _resolve_id()
## directly) so both id kinds still read as one obvious call each, with
## the shared logic centralized in _resolve_id() instead of copied.
func resolve_perk_id(requested: String) -> String:
	return _resolve_id(requested, PERK_IDS)


## Shared by resolve_class_id()/resolve_perk_id() so the validate-or-
## default rule lives in exactly one place.
func _resolve_id(requested: String, valid_ids: Array[String]) -> String:
	return requested if requested in valid_ids else valid_ids[0]


func get_class_id(peer_id: int, fallback: String = "") -> String:
	return player_class_ids.get(peer_id, fallback)


func get_team_id(peer_id: int, fallback: int = 0) -> int:
	return player_team_ids.get(peer_id, fallback)


## Pure: clamps to {0, 1} -- the Room Config UI only ever toggles between
## the 2 teams it draws, but _rpc_set_team is any_peer over the network,
## so an out-of-range value (a modified client, or simple caller error)
## must not be trusted verbatim the way it briefly was (found via this
## phase's own review pass, not by the human owner -- see
## resolve_class_id()/resolve_perk_id() for the same validate-at-the-
## boundary pattern already used for the other 2 self-service fields).
func resolve_team_id(requested: int) -> int:
	return clampi(requested, 0, 1)


func get_perk_id(peer_id: int, fallback: String = "") -> String:
	return player_perk_ids.get(peer_id, fallback)


func is_ready(peer_id: int) -> bool:
	return player_ready.get(peer_id, false)


## Pure: true once every currently-registered peer, INCLUDING the host
## (Phase 14 -- replaces the old all_non_host_ready(), which
## deliberately skipped peer 1 back when only the host had a Start
## button instead of a ready toggle), has marked itself ready. A peer
## that has registered a class but not yet reported ready counts as not
## ready (a missing entry means false, never skipped). False with no
## one registered at all -- an empty room is never "ready."
func all_ready() -> bool:
	if player_class_ids.is_empty():
		return false
	for peer_id in player_class_ids:
		if not player_ready.get(peer_id, false):
			return false
	return true


## Pure: Team mode can only ever resolve a winner once at least 2
## distinct teams have members -- gameplay/match/win_condition.gd's own
## teams_ever_present guard returns NONE forever otherwise, so a match
## started with everyone manually assigned to the same team would hang
## in IN_PROGRESS permanently (a real bug found by /check, not
## theoretical -- confirmed live during this phase's own verification,
## see memory/gotchas.md). Trivially true with fewer than 2 players
## registered, so this never blocks the pre-existing solo-host
## convenience for quick manual testing.
func has_valid_team_split() -> bool:
	if player_team_ids.size() < 2:
		return true
	var distinct_teams: Dictionary = {}
	for team_id in player_team_ids.values():
		distinct_teams[team_id] = true
	return distinct_teams.size() >= 2


## Pure: the countdown's own start condition -- everyone ready, AND
## either the mode is free-for-all (no team-split concept applies) or
## the current team split is actually valid. Extracted as its own named
## predicate (rather than inlined in the countdown coroutine) so it's
## unit-testable without any Node/multiplayer context, same reasoning
## as has_valid_team_split()/all_ready() above.
func is_room_ready_to_start() -> bool:
	return (
		all_ready()
		and (room_match_mode == MatchState.MatchMode.FREE_FOR_ALL or has_valid_team_split())
	)


## Found by /check (Phase 14): LobbyState is an autoload, so every one
## of these registries used to survive across a Leave Room -> re-host/
## re-join cycle -- a stale player_ready[1] = true left over from a
## PREVIOUS room could let the new room's auto-countdown start
## immediately, with no Ready press ever happening in the new room at
## all. No RPC calls here (unlike _cancel_countdown()): this runs on
## EVERY peer, including a client, and _rpc_receive_countdown is
## "authority"-only -- a client calling it would be rejected.
func reset_room() -> void:
	player_class_ids.clear()
	player_team_ids.clear()
	player_perk_ids.clear()
	player_ready.clear()
	room_match_mode = MatchState.MatchMode.TEAM
	room_friendly_fire = false
	countdown_seconds_remaining = -1.0
	if NetworkManager.is_server():
		_next_team_index = 0
		_countdown_generation = 0


## Called locally by the connecting peer (host or client) right after
## NetworkManager.host()/join() succeeds, to register local_chosen_
## class_id under this peer's own id. Always the first thing a fresh
## room entry does -- see reset_room()'s own doc comment above for why.
func register_local_player() -> void:
	reset_room()
	var peer_id := multiplayer.get_unique_id()
	if NetworkManager.is_server():
		_apply_registration(peer_id, local_chosen_class_id)
		_broadcast_room_state()
	else:
		_rpc_register.rpc_id(1, local_chosen_class_id)


## Called locally by any peer, including the host, to set their OWN
## ready flag (Phase 14: symmetric now, see player_ready's own doc
## comment -- there is no more host-only Start button).
func set_local_ready(ready: bool) -> void:
	var peer_id := multiplayer.get_unique_id()
	if NetworkManager.is_server():
		_apply_ready(peer_id, ready)
		_broadcast_room_state()
	else:
		_rpc_set_ready.rpc_id(1, ready)


## Called locally by any peer to move their OWN team -- self-service,
## same shape as set_local_ready(). Corrected mid-Phase-9 (was
## host-only, letting the host move ANY peer's team; the human owner
## caught this as a real authority bug, not a design choice -- the host
## keeps mode/friendly-fire/Start authority, but never another
## player's team). ui/lobby/lobby.gd only ever draws this control on a
## peer's own row now, matching set_local_ready()'s own row-gating.
func set_local_team(team_id: int) -> void:
	var peer_id := multiplayer.get_unique_id()
	if NetworkManager.is_server():
		_apply_team(peer_id, team_id)
		_broadcast_room_state()
	else:
		_rpc_set_team.rpc_id(1, team_id)


## Called locally by any peer to set their OWN perk -- self-service,
## same shape as set_local_team()/set_local_ready(). Visible to every
## peer via the same room-state broadcast, per memory/plan.md's
## "Slices 8-10" Perks block ("visible live to the rest of the room").
func set_local_perk(perk_id: String) -> void:
	var peer_id := multiplayer.get_unique_id()
	if NetworkManager.is_server():
		_apply_perk(peer_id, perk_id)
		_broadcast_room_state()
	else:
		_rpc_set_perk.rpc_id(1, perk_id)


## Host-only -- called directly by the host's own Room Config controls,
## never over RPC (unlike set_local_team(), this really is host-only:
## mode/friendly-fire are match-wide settings, not a per-player choice).
func set_room_match_mode(mode: MatchState.MatchMode) -> void:
	if not NetworkManager.is_server():
		return
	room_match_mode = mode
	_broadcast_room_state()


func set_room_friendly_fire(value: bool) -> void:
	if not NetworkManager.is_server():
		return
	room_friendly_fire = value
	_broadcast_room_state()


func _on_peer_disconnected(peer_id: int) -> void:
	if not NetworkManager.is_server():
		return
	var changed := player_class_ids.erase(peer_id)
	player_team_ids.erase(peer_id)
	player_perk_ids.erase(peer_id)
	player_ready.erase(peer_id)
	if changed:
		_broadcast_room_state()


## any_peer, but never trusts a client-supplied peer id -- registers
## under multiplayer.get_remote_sender_id() instead, so one client
## can't register (or overwrite) a different peer's slot.
@rpc("any_peer", "reliable")
func _rpc_register(class_id: String) -> void:
	if not NetworkManager.is_server():
		return
	_apply_registration(multiplayer.get_remote_sender_id(), class_id)
	_broadcast_room_state()


## any_peer, same trust reasoning as _rpc_register.
@rpc("any_peer", "reliable")
func _rpc_set_ready(ready: bool) -> void:
	if not NetworkManager.is_server():
		return
	_apply_ready(multiplayer.get_remote_sender_id(), ready)
	_broadcast_room_state()


## any_peer, same trust reasoning as _rpc_register -- never receives a
## target peer id, only ever applies to the caller's own
## get_remote_sender_id(), which is what makes "each peer can only move
## their OWN team" a structural guarantee rather than a UI-only rule a
## modified client could bypass.
@rpc("any_peer", "reliable")
func _rpc_set_team(team_id: int) -> void:
	if not NetworkManager.is_server():
		return
	_apply_team(multiplayer.get_remote_sender_id(), team_id)
	_broadcast_room_state()


## any_peer, same trust reasoning as _rpc_set_team.
@rpc("any_peer", "reliable")
func _rpc_set_perk(perk_id: String) -> void:
	if not NetworkManager.is_server():
		return
	_apply_perk(multiplayer.get_remote_sender_id(), perk_id)
	_broadcast_room_state()


## Pure Dictionary mutation, no RPC -- callers are responsible for
## broadcasting afterward. Kept separate so it stays testable without
## a multiplayer peer (see test_get_class_id_returns_registered_choice).
## Also seeds a default alternating team assignment AND a default perk
## on first registration (same formula PlayerSpawner used before Phase
## 8 for team; PERK_IDS[0] for perk) -- re-registering an already-known
## peer (e.g. picking a class again) never resets either choice once
## the peer has already made it.
func _apply_registration(peer_id: int, class_id: String) -> void:
	player_class_ids[peer_id] = resolve_class_id(class_id)
	if not player_team_ids.has(peer_id):
		player_team_ids[peer_id] = _next_team_index % 2
		_next_team_index += 1
	if not player_perk_ids.has(peer_id):
		player_perk_ids[peer_id] = PERK_IDS[0]


func _apply_ready(peer_id: int, ready: bool) -> void:
	player_ready[peer_id] = ready


func _apply_team(peer_id: int, team_id: int) -> void:
	player_team_ids[peer_id] = resolve_team_id(team_id)


func _apply_perk(peer_id: int, perk_id: String) -> void:
	player_perk_ids[peer_id] = resolve_perk_id(perk_id)


## Server-only: every mutation above (registration, ready, team, perk,
## mode, friendly-fire, and disconnect) already funnels through this
## one function, so it's the single choke point to re-evaluate the
## countdown from -- no call site needs to remember to do it itself.
func _broadcast_room_state() -> void:
	_rpc_receive_room_state.rpc(
		player_class_ids,
		player_team_ids,
		player_perk_ids,
		player_ready,
		room_match_mode,
		room_friendly_fire
	)
	_recompute_countdown()


@rpc("authority", "reliable", "call_local")
func _rpc_receive_room_state(
	classes: Dictionary,
	teams: Dictionary,
	perks: Dictionary,
	ready: Dictionary,
	mode: int,
	friendly_fire: bool
) -> void:
	player_class_ids = classes
	player_team_ids = teams
	player_perk_ids = perks
	player_ready = ready
	room_match_mode = mode
	room_friendly_fire = friendly_fire
	room_state_changed.emit()


## Server-only. Starts a fresh countdown coroutine if the room just
## became ready and none is already running; cancels an in-flight one
## the instant the room stops being ready (someone un-readied, a new
## peer joined and hasn't readied yet, or the team split broke) --
## peers who were already ready never need to re-click anything, the
## countdown simply restarts from PRE_DELAY_SECONDS once the full
## ready-set re-forms. A no-op on a client (only the server ever calls
## _broadcast_room_state(), but this stays defensive in case that ever
## changes).
##
## Found by /check (Phase 14): _on_peer_disconnected() below (and
## _apply_registration()) can still run and call _broadcast_room_state()
## while MatchState.current_phase is already LOADING/IN_PROGRESS/
## POST_GAME -- e.g. a peer disconnecting mid-match, or a NEW peer
## direct-IP-joining mid-match (LAN advertising stops, but the port
## itself doesn't). Without this guard, is_room_ready_to_start() could
## still resolve true off leftover Room Config state and re-trigger
## _start_match() -> MatchState.enter_loading() mid-match, forcing
## every already-in-match peer back to LOADING. The countdown is only
## ever a Room Config (Phase.LOBBY) concern.
func _recompute_countdown() -> void:
	if not NetworkManager.is_server():
		return
	if MatchState.current_phase != MatchState.Phase.LOBBY or not is_room_ready_to_start():
		_cancel_countdown()
		return
	if _countdown_generation > 0:
		return
	_run_countdown()


func _cancel_countdown() -> void:
	if _countdown_generation == 0:
		return
	_countdown_generation = 0
	_set_countdown_remaining(-1.0)


## The 2s PRE_DELAY_SECONDS window is deliberately silent (no broadcast)
## -- only the visible COUNTDOWN_SECONDS phase is shown to players, per
## the human owner's own spec ("2s after all ready, inicia um countdown
## de 5s"). _countdown_generation is bumped once up front and captured
## locally so a later _cancel_countdown()/_run_countdown() call from a
## DIFFERENT ready-state change can't be confused with this one -- each
## `await` below re-checks _countdown_still_valid() before continuing,
## since the room's readiness, the match's own phase, or the generation
## itself can all change while suspended.
func _run_countdown() -> void:
	_countdown_generation += 1
	var my_generation := _countdown_generation
	await get_tree().create_timer(_pre_delay_seconds).timeout
	if not _countdown_still_valid(my_generation):
		return
	var remaining := _countdown_seconds_config
	while remaining > 0.0:
		_set_countdown_remaining(remaining)
		await get_tree().create_timer(1.0).timeout
		if not _countdown_still_valid(my_generation):
			return
		remaining -= 1.0
	_set_countdown_remaining(-1.0)
	_start_match()


func _countdown_still_valid(my_generation: int) -> bool:
	return (
		my_generation == _countdown_generation
		and MatchState.current_phase == MatchState.Phase.LOBBY
		and is_room_ready_to_start()
	)


## Relies purely on the RPC's own call_local to update the server's own
## countdown_seconds_remaining, same pattern as MatchState's
## broadcast_grace_period_count() -- no redundant direct assignment
## here before the call.
func _set_countdown_remaining(value: float) -> void:
	_rpc_receive_countdown.rpc(value)


@rpc("authority", "reliable", "call_local")
func _rpc_receive_countdown(value: float) -> void:
	countdown_seconds_remaining = value
	countdown_changed.emit()


## Replaces ui/lobby/lobby.gd's old host-only _on_start_pressed() --
## the countdown above is what decides WHEN to call this now, no button
## press involved.
func _start_match() -> void:
	LanDiscovery.stop_advertising()
	MatchState.friendly_fire_enabled = room_friendly_fire
	MatchState.enter_loading(room_match_mode as MatchState.MatchMode)
