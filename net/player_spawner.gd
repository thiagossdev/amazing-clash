class_name PlayerSpawner
extends Node
## Server-side: mirrors connected peers into class-scene instances under
## a MultiplayerSpawner-watched container, so every peer sees the same
## characters replicated automatically. The server also spawns a
## character for itself (peer_connected never fires for your own id).
## PlayerSpawner does not track which peer_id previously held which
## team/class, so a (re)connecting peer (a new peer id -- Godot never
## reuses one) is assigned fresh, not restored to a prior slot -- a
## real reconnect system (Slice 13b) is a separate, not-yet-built
## phase; see memory/plan.md.
##
## Phase 13a: a disconnect no longer despawns immediately -- it starts
## a grace-period timer instead (_begin_grace_period()), despawning
## only once it expires unclaimed (_expire_grace_period()). No new
## "freeze in place" mechanism was needed: net/server_sim.gd's
## next_input() already degrades a starved input buffer to a neutral
## (no-movement) sample once STALE_INPUT_TIMEOUT_TICKS passes with no
## fresh input -- which a disconnected peer's character already never
## receives again, permanently. The character stays fully vulnerable
## during the grace period (can be damaged/eliminated normally) --
## disconnecting has a real cost, it is not a safe refuge, per the
## human owner's own confirmed decision. Pattern inherited from
## amazing-nauts' net/player_spawner.gd, scoped down. See
## docs/blueprint/03-networking-and-match-modes.md.
##
## Phase 4: alternates the real classes by connection order -- no
## lobby/character-select exists yet, so this is the simplest thing
## that lets every class fight in a live match.
##
## Phase 7: a peer registered in LobbyState (CharacterSelect's real
## pick) gets that class instead; an unregistered peer
## (net/dev_bootstrap.gd's headless test peers, which never go through
## CharacterSelect) still falls back to the original index-cycling
## behavior unchanged, so every prior phase's headless verification
## keeps working.
##
## Phase 5: also assigns team = index % 2 for 2v2 team mode, same
## connection-order auto-
## assignment, no lobby/character-select UI exists yet to pick team or
## class explicitly (deferred, see memory/plan.md). Phase 6: 3rd entry
## (Warden) added -- the 2-vs-3 modulus mismatch with team assignment's
## own index % 2 is intentional, not a bug: it's what makes team
## composition vary (not every team gets the exact same class pairing)
## as more players connect, with no extra logic needed for that.
##
## Phase 8: Team mode now prefers a peer's manually-assigned
## LobbyState.get_team_id() (Room Config), falling back to the
## original index % 2 for an unregistered peer -- see
## _resolve_team_id() below. FFA is unaffected, unchanged from Phase 6.
const CLASS_SCENES: Array[PackedScene] = [
	preload("res://gameplay/characters/vanguard/Vanguard.tscn"),
	preload("res://gameplay/characters/ranged_mage/RangedMage.tscn"),
	preload("res://gameplay/characters/warden/Warden.tscn"),
]

## Phase 12: replaced the original 4 hardcoded spawn points (tuned only
## for a fixed 2v2) with a computed layout, now that team size is
## confirmed configurable (2v2 through 5v5). Team mode: team 0 clusters
## left of arena center, team 1 clusters right -- unchanged x values
## from the original 4-point layout, but members now stack vertically
## per-team (TEAM_MEMBER_SPACING apart) instead of being limited to 2
## fixed slots each, so a 5th teammate gets a real spot instead of
## cycling back onto an earlier one. Free-for-all: no "left/right"
## concept applies to N individually-teamed players, so each spawns on
## a circle around the arena center instead (FFA_SPAWN_SLOTS evenly-
## spaced angles, cycling for a 9th+ player rather than erroring --
## same "never error, just cycle" guarantee the original 4-point
## layout already had). Never spawns exactly overlapping (a degenerate
## case where a melee hitbox and hurtbox can share an exact boundary
## with no true intersection -- found live, see memory/gotchas.md);
## every generated position differs from every other by construction
## (distinct index_within_team or distinct FFA angle), same invariant
## as before. Clear of TestArena.tscn's 4 wall colliders (interior
## roughly x:36-1164, y:36-764 for a 20-radius character against
## 32-thick walls) -- every constant below stays well inside that.
const ARENA_CENTER := Vector2(600.0, 400.0)
const TEAM_CLUSTER_X := {0: 300.0, 1: 900.0}
const TEAM_MEMBER_SPACING := 60.0
const FFA_SPAWN_RADIUS := 300.0
const FFA_SPAWN_SLOTS := 8

## Phase 13a: default grace period before a disconnected peer's
## character is despawned as a forfeit. Overridable via
## --dev-grace-period=<seconds> (a real 30s is impractical to wait out
## in an automated live test) -- production default stays 30.0 with no
## flag, same "read OS.get_cmdline_user_args() directly, don't touch
## net/dev_bootstrap.gd" convention ui/lobby/lobby.gd's own dev flags
## already use.
const GRACE_PERIOD_SECONDS := 30.0

## KNOWN LIMITATION (not fully closed by this phase, see memory/
## gotchas.md and memory/plan.md's Slice 13b block): multiplayer.
## peer_connected fires -- spawning a fresh throwaway character for
## new_peer_id via the normal _spawn_for_peer() path -- the instant a
## reconnecting peer's raw ENet connection completes, unavoidably
## before its own reconnect-token RPC can possibly arrive (that RPC is
## itself a round trip over the connection peer_connected just
## reported as established; the server side of that race can't be
## reordered away). Found live: without ANY cleanup, that throwaway
## survives forever alongside the reclaimed original -- 2 characters
## permanently answering to the same controlling_peer_id, the
## reconnecting client fully predicting and driving both from 1 set of
## inputs. queue_free()-ing the throwaway INSTANTLY was tried first and
## made things worse -- found live, it raced MultiplayerSpawner's own
## initial state-sync burst to the just-connected peer and produced
## real engine errors ("Node not found", "Invalid packet received",
## despawning a node particular peers had never finished receiving the
## spawn for). This constant, used in _despawn_reconnect_duplicate()
## below, is a live-verified interim mitigation, not a real fix:
## waiting this long before freeing the throwaway let that sync burst
## settle with zero engine errors in every trial run here, shrinking
## the dual-control window from permanent down to about this delay's
## length -- still a real, if brief, window, and the delay is a guess
## calibrated against loopback, not a network-latency-derived bound
## (Godot's MultiplayerSpawner exposes no per-peer "initial sync
## complete" signal to key off instead). The correct fix is gating
## _spawn_for_peer() behind Godot's own SceneMultiplayer peer-
## authentication API (peer_authenticating / complete_authentication)
## so a reconnecting peer's token exchange resolves BEFORE it ever
## counts as newly connected -- out of scope for this phase, flagged
## for follow-up.
const RECONNECT_DUPLICATE_CLEANUP_DELAY_SECONDS := 1.0

@export var characters_path: NodePath = ^"../Characters"

var _next_spawn_index: int = 0
var _next_index_for_team: Dictionary = {}
## peer_id -> SceneTreeTimer, one entry per currently-disconnected
## peer still inside its grace period. Server-only.
var _grace_timers: Dictionary = {}
var _grace_period_seconds: float = GRACE_PERIOD_SECONDS
## Slice 13b: token (String) -> original peer_id, one entry per
## currently-connected OR currently-grace-period character. Server-
## only. Not cryptographically strong on purpose -- this is "the same
## running client reconnecting after a drop," not an account/security
## boundary (see memory/plan.md's Slice 13b block).
var _reconnect_tokens: Dictionary = {}


## Phase 7: no longer spawns unconditionally at _ready() -- doing so
## raced the LOADING handshake (core/match_state.gd): the server's own
## TestArena tree (and this node) can finish _ready() before a remote
## peer's own TestArena/MultiplayerSpawner has finished building on
## their machine, so an immediate spawn here replicated to a node path
## that didn't exist there yet ("Node not found: TestArena/
## MultiplayerSpawner", confirmed live). Spawning now waits for
## MatchState to actually reach IN_PROGRESS -- which only happens once
## every connected peer's own LoadingReporter has reported ready --
## except when it's already IN_PROGRESS at _ready() time (net/
## dev_bootstrap.gd's direct-connect flow, which skips LOADING
## entirely and calls enter_in_progress() immediately: unaffected).
func _ready() -> void:
	if not NetworkManager.is_server():
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dev-grace-period="):
			var raw_value := arg.trim_prefix("--dev-grace-period=")
			if raw_value.is_valid_float():
				_grace_period_seconds = raw_value.to_float()
			else:
				var message := (
					"--dev-grace-period=%s is not a valid number -- ignoring, keeping the %s default"
					% [raw_value, GRACE_PERIOD_SECONDS]
				)
				push_error(message)
				GameLog.error(
					"invalid_dev_flag", {"flag": "--dev-grace-period", "value": raw_value}
				)
	add_to_group(&"player_spawner")
	var characters := get_node(characters_path)
	multiplayer.peer_connected.connect(func(peer_id): _spawn_for_peer(peer_id, characters))
	multiplayer.peer_disconnected.connect(func(peer_id): _begin_grace_period(peer_id, characters))
	if MatchState.current_phase == MatchState.Phase.IN_PROGRESS:
		_spawn_all_connected(characters)
	else:
		EventBus.match_state_changed.connect(
			func(new_phase):
				if new_phase == MatchState.Phase.IN_PROGRESS:
					_spawn_all_connected(characters)
		)


func _spawn_all_connected(characters: Node) -> void:
	_spawn_for_peer(multiplayer.get_unique_id(), characters)
	for peer_id in multiplayer.get_peers():
		_spawn_for_peer(peer_id, characters)


func _spawn_for_peer(peer_id: int, characters: Node) -> void:
	if characters.has_node(str(peer_id)):
		return
	var class_scene := _resolve_class_scene(peer_id)
	var character: CharacterController = class_scene.instantiate()
	character.name = str(peer_id)
	character.team = _resolve_team_id(peer_id)
	character.position = _spawn_position_for(character.team)
	_next_spawn_index += 1
	characters.add_child(character)
	_issue_reconnect_token(peer_id)
	# Perk multipliers are NOT applied here, deliberately -- this method
	# only ever runs on the server (see _ready()'s own early return
	# above). A perk's move_speed_multiplier/cooldown_multiplier are
	# read during client-side PREDICTION (CharacterController.
	# apply_input(), the same code path AUTHORITATIVE uses), not just
	# server simulation -- unlike `team`, which only ever matters to
	# server-only logic (CombatResolver/MatchRules). Applying the perk
	# here would leave every owning CLIENT's own local mirror at the
	# default 1.0 multiplier (MultiplayerSpawner replicates the spawn,
	# not arbitrary script properties set before add_child -- the same
	# reason `team` itself is documented as never replicated), causing
	# a visible, permanent misprediction/reconciliation-snap for anyone
	# who picked Swift/Adept. See CharacterController._ready()'s own
	# _apply_perk_from_lobby_state(), which runs on every peer's own
	# instance instead, reading the already-replicated LobbyState
	# registry directly.


## FFA is unaffected by Phase 8 -- every player still gets a unique
## team id off the same spawn-order counter Phase 6 already used, no
## manual assignment exists or is needed for it. Team mode now prefers
## Room Config's manually-assigned team_id for any peer that went
## through it; an unregistered peer (net/dev_bootstrap.gd's headless
## test peers, which never touch LobbyState) falls back to the
## original index % 2 alternation unchanged.
func _resolve_team_id(peer_id: int) -> int:
	if MatchState.match_mode == MatchState.MatchMode.FREE_FOR_ALL:
		return _next_spawn_index
	if LobbyState.get_class_id(peer_id, "") == "":
		return _next_spawn_index % 2
	return LobbyState.get_team_id(peer_id, _next_spawn_index % 2)


## Uses LobbyState's registered choice for peer_id if one exists (the
## real CharacterSelect flow, Phase 7+); otherwise falls back to the
## original index-cycling default (net/dev_bootstrap.gd's headless
## test peers, which never register).
func _resolve_class_scene(peer_id: int) -> PackedScene:
	var class_id := LobbyState.get_class_id(peer_id, "")
	var registered_index := LobbyState.CLASS_IDS.find(class_id)
	var scene_index := (
		registered_index if registered_index != -1 else _next_spawn_index % CLASS_SCENES.size()
	)
	return CLASS_SCENES[scene_index]


## Team mode: stacks this team's Nth member vertically around arena-
## center height, TEAM_MEMBER_SPACING apart -- unbounded in practice
## (no cap on team size here), but every confirmed team size (2v2
## through 5v5) stays comfortably inside the arena's safe interior.
## Free-for-all: places this (uniquely-teamed) player on a fixed circle
## around the arena center instead, since "left/right of center" has
## no meaning once every player is their own team.
func _spawn_position_for(team_id: int) -> Vector2:
	if MatchState.match_mode == MatchState.MatchMode.FREE_FOR_ALL:
		return _ffa_spawn_position(team_id)
	return _team_spawn_position(team_id)


func _team_spawn_position(team_id: int) -> Vector2:
	var index_within_team: int = _next_index_for_team.get(team_id, 0)
	_next_index_for_team[team_id] = index_within_team + 1
	var x: float = TEAM_CLUSTER_X.get(team_id, ARENA_CENTER.x)
	var y := ARENA_CENTER.y - TEAM_MEMBER_SPACING * 2.0 + index_within_team * TEAM_MEMBER_SPACING
	return Vector2(x, y)


func _ffa_spawn_position(team_id: int) -> Vector2:
	var slot := team_id % FFA_SPAWN_SLOTS
	var angle := TAU * float(slot) / float(FFA_SPAWN_SLOTS)
	return ARENA_CENTER + Vector2(FFA_SPAWN_RADIUS, 0.0).rotated(angle)


## A no-op if this peer's character is already gone (defensive -- in
## practice PlayerSpawner always spawned one). Otherwise starts a
## _grace_period_seconds timer; the character itself needs no explicit
## freezing (see this file's own header comment), it simply stops
## receiving input forever, which ServerSim already turns into
## standing still. broadcast_grace_period_count() tells every client
## how many players are currently mid-grace-period, for a minimal HUD
## indicator -- no per-player identity, matching this project's
## existing "aggregate only" client-visible-state convention
## (MatchState.team_alive_counts).
func _begin_grace_period(peer_id: int, characters: Node) -> void:
	if not characters.has_node(str(peer_id)):
		return
	var timer := get_tree().create_timer(_grace_period_seconds)
	_grace_timers[peer_id] = timer
	timer.timeout.connect(func(): _expire_grace_period(peer_id, characters))
	MatchState.broadcast_grace_period_count(_grace_timers.size())
	GameLog.info("disconnect_grace_period_started", {"peer_id": peer_id})


## Called once the grace-period timer actually elapses. A no-op if
## peer_id isn't tracked (Slice 13b will make this reachable via a
## successful reconnect canceling the grace period early; today it can
## only happen if this is somehow called twice for the same peer_id,
## which _grace_timers.erase() below already guards against).
func _expire_grace_period(peer_id: int, characters: Node) -> void:
	if not _grace_timers.has(peer_id):
		return
	_grace_timers.erase(peer_id)
	_invalidate_token_for(peer_id)
	_despawn_for_peer(peer_id, characters)
	MatchState.broadcast_grace_period_count(_grace_timers.size())
	GameLog.info("disconnect_grace_period_expired_forfeit", {"peer_id": peer_id})


## Random, not cryptographic (see _reconnect_tokens' own doc comment).
## Sent to the owning peer only -- never broadcast, never logged. The
## host's own character is spawned locally (peer_id == our own unique
## id), and Godot's RPC layer rejects a non-call_local @rpc targeted at
## yourself ("RPC on yourself is not allowed by selected mode", found
## live) -- a direct call sidesteps that without changing the RPC's
## authorization mode for the real network case. The get_peers() guard
## on the remote branch only ever matters for unit tests that call
## try_reclaim() directly with a fabricated peer_id and no real ENet
## connection behind it (see tests/unit/test_player_spawner.gd) --
## every real caller (_spawn_for_peer() on an actual peer_connected,
## try_reclaim() on an actual multiplayer.get_remote_sender_id()) only
## ever passes a peer_id that's already in this list.
func _issue_reconnect_token(peer_id: int) -> void:
	var token := "%d-%d" % [Time.get_ticks_usec(), randi()]
	_reconnect_tokens[token] = peer_id
	if peer_id == multiplayer.get_unique_id():
		ReconnectManager._rpc_receive_token(token)
	elif multiplayer.get_peers().has(peer_id):
		ReconnectManager._rpc_receive_token.rpc_id(peer_id, token)


func _invalidate_token_for(peer_id: int) -> void:
	for token in _reconnect_tokens.keys():
		if _reconnect_tokens[token] == peer_id:
			_reconnect_tokens.erase(token)
			return


## Slice 13b: called by net/reconnect_manager.gd's own RPC handler
## (server-only) when a peer presents a token. Server-authoritative --
## the caller passes the RPC's own multiplayer.get_remote_sender_id(),
## never a client-supplied id, so a peer can only ever reclaim
## whichever character its OWN presented token actually maps to. A
## valid token whose character has already fully despawned (grace
## expired, or the token is simply unknown/reused) fails closed. See
## _despawn_reconnect_duplicate()'s own doc comment for a known,
## live-confirmed limitation of the cleanup this triggers.
func try_reclaim(token: String, new_peer_id: int) -> bool:
	if not _reconnect_tokens.has(token):
		return false
	var original_peer_id: int = _reconnect_tokens[token]
	if not _grace_timers.has(original_peer_id):
		return false
	var characters := get_node(characters_path)
	var character := characters.get_node_or_null(str(original_peer_id)) as CharacterController
	if not character:
		return false
	_grace_timers.erase(original_peer_id)
	_reconnect_tokens.erase(token)
	_despawn_reconnect_duplicate(new_peer_id, characters)
	character._rpc_reassign_controller.rpc(new_peer_id)
	MatchState.broadcast_grace_period_count(_grace_timers.size())
	_issue_reconnect_token(new_peer_id)
	GameLog.info(
		"reconnect_reclaimed", {"original_peer_id": original_peer_id, "new_peer_id": new_peer_id}
	)
	return true


## See RECONNECT_DUPLICATE_CLEANUP_DELAY_SECONDS' own doc comment above
## for why this waits before freeing, and what that leaves unresolved.
func _despawn_reconnect_duplicate(new_peer_id: int, characters: Node) -> void:
	var duplicate := characters.get_node_or_null(str(new_peer_id))
	if not duplicate:
		return
	_invalidate_token_for(new_peer_id)
	await get_tree().create_timer(RECONNECT_DUPLICATE_CLEANUP_DELAY_SECONDS).timeout
	duplicate.queue_free()


func _despawn_for_peer(peer_id: int, characters: Node) -> void:
	var character := characters.get_node_or_null(str(peer_id))
	if character:
		character.queue_free()
