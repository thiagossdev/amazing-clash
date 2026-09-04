extends Node
## Orchestrator autoload -- source of truth for the match phase.
## See docs/blueprint/03-networking-and-match-modes.md.
##
## RECONNECT is a sub-state of IN_PROGRESS conceptually, not its own
## Phase value here -- a disconnect just despawns that character
## (PlayerSpawner) and MatchRules' elimination check treats a team
## dropping to 0 current members the same whether by disconnect or
## defeat; a real reconnect/grace-period system is out of scope for
## Phase 5.
##
## Phase 7: dropped CHARACTER_SELECT from Phase -- it was never
## implemented (TestArena entered IN_PROGRESS directly), and character
## selection turned out to belong entirely outside networked match
## state (it happens locally, before ever connecting -- see
## ui/character_select/ and memory/plan.md's "Slices 7-10" section), so
## there was never a real use for a networked CHARACTER_SELECT phase.
## LOBBY now means "connected, in the Room Config waiting screen"
## (ui/lobby/). LOADING is now real, not dropped: Room Config's Start
## triggers enter_loading(), every peer scene-changes to TestArena.tscn
## locally, and only once every currently-connected peer's own
## TestArena tree has actually finished building (reported via
## report_loaded(), called from net/loading_reporter.gd -- the last
## child of TestArena.tscn, guaranteed to _ready() after every sibling
## including PlayerSpawner, the same ordering guarantee MatchRules
## already relies on) does the server call enter_in_progress(). This
## closes the same race net/dev_bootstrap.gd already hit once
## (memory/gotchas.md: PlayerSpawner._ready() running before host()/
## join() finished produced an "authority RPC not allowed" engine
## error) -- now a real risk here too, since Room Config -> TestArena
## is an actual scene change instead of the previous fixed main scene.
## Known narrow gap, not handled: a peer connecting mid-LOADING (rather
## than already being in the Lobby when Start is pressed) has no
## explicit catch-up RPC for LOADING itself, unlike IN_PROGRESS/
## POST_GAME below -- unlikely in this project's direct-connect,
## small-player-count flow, not worth the extra bookkeeping until it's
## a real problem.
##
## Phase 5: this file's phase is now client-visible for the first time
## (nothing before this phase read current_phase client-side), which
## surfaced a real gap -- enter_in_progress() used to just set a local
## var with no RPC, so a client's own copy never actually changed. Both
## phase-transition methods below now broadcast via RPC, and a peer
## connecting AFTER a transition already fired is caught up in
## _on_peer_connected() (mirroring PlayerSpawner's own "catch up a late
## joiner" pattern for already-spawned characters).
##
## Phase 6: match_mode picks how PlayerSpawner assigns team (2 fixed
## teams, or one unique team per player for free-for-all) -- set once
## at server startup (net/dev_bootstrap.gd's --free-for-all flag), same
## non-live-togglable pattern as friendly_fire_enabled. team_alive_counts
## grew from a fixed 2-element array to a variable-length one indexed by
## team id, so it reads correctly under either mode.

## Phase 17: ROUND_INTERMISSION sits between IN_PROGRESS and POST_GAME
## -- a round that doesn't decide the match (see resolve_round_result())
## enters it instead of POST_GAME, giving every peer a timed window to
## adjust weapon/boot/perk (never team/class -- those stay fixed for
## the whole match) before the next round's own LOADING->IN_PROGRESS
## cycle runs again.
enum Phase { LOBBY, LOADING, IN_PROGRESS, ROUND_INTERMISSION, POST_GAME }
enum MatchMode { TEAM, FREE_FOR_ALL }

## Phase 17: first to this many round wins takes the match (best of 3).
const ROUND_TARGET := 2
## Phase 17: exact timing confirmed by the human owner, 2026-09-04 --
## do not change without asking. A round-ending confirm-set completed
## with fewer than INTERMISSION_EARLY_THRESHOLD_SECONDS elapsed earns
## the short INTERMISSION_EARLY_COUNTDOWN_SECONDS "starting" countdown;
## otherwise the full INTERMISSION_WINDOW_SECONDS window always runs to
## completion first (even if the confirm-set finished at, say, 14s --
## the reward is specifically for finishing before the 13s mark, not
## "finished at all"), then the longer
## INTERMISSION_LATE_COUNTDOWN_SECONDS countdown runs regardless of
## whether everyone confirmed -- an unconfirmed peer's loadout is
## force-locked simply by never having changed (LobbyState always holds
## a current value for every registered peer already, so "force-lock"
## needs no separate action).
const INTERMISSION_WINDOW_SECONDS := 15.0
const INTERMISSION_EARLY_THRESHOLD_SECONDS := 13.0
const INTERMISSION_EARLY_COUNTDOWN_SECONDS := 5.0
const INTERMISSION_LATE_COUNTDOWN_SECONDS := 3.0

var current_phase: Phase = Phase.LOBBY
## Phase 17: team_id (or player index in free-for-all) -> round win
## count, same key shape team_alive_counts already uses. Broadcast to
## every peer as part of _rpc_round_ended()/_rpc_enter_post_game() so
## the HUD can show a running/final score -- never reset mid-match
## (only reset_room()-adjacent state, i.e. a fresh LobbyState.
## register_local_player() call, clears it, via _on_peer_connected()
## catch-up reading it fresh like every other MatchState field).
var round_wins: Dictionary = {}
## Phase 17: which round is currently being played, starting at 1. A
## draw does NOT advance this (the same round is simply replayed); a
## decisive non-final round does. See decide_round_outcome().
var current_round: int = 1
## Phase 17: server-authoritative peer_id -> confirmed-their-round-
## loadout flag, scoped to the current ROUND_INTERMISSION window only
## -- cleared every time a new intermission begins. Same "missing entry
## means false" rule as net/lobby_state.gd's own player_ready.
var player_loadout_confirmed: Dictionary = {}
## Client-visible: seconds remaining in the current intermission's
## FINAL countdown (the 5s/3s one), or -1.0 whenever nothing is
## counting down -- including during the 15s pick/confirm window
## itself, which has no visible countdown of its own (same "silent
## window, then a visible countdown" shape as net/lobby_state.gd's own
## PRE_DELAY_SECONDS/COUNTDOWN_SECONDS).
var intermission_seconds_remaining: float = -1.0
## Server-decided per match (see net/dev_bootstrap.gd's --free-for-all
## flag). Read by PlayerSpawner to decide team assignment; never
## replicated to clients for the same reason friendly_fire_enabled
## isn't -- only server-side logic needs it, and MatchHud reads it
## purely to decide how to *format* the already-client-visible
## team_alive_counts, which is fine since match_mode itself never
## changes mid-match and is set before any client connects in every
## supported flow (server startup, no live mode-switch exists).
var match_mode: MatchMode = MatchMode.TEAM
## Server-decided per match (see net/dev_bootstrap.gd's --friendly-fire
## flag), read every tick by CombatResolver -- never replicated to
## clients, since only the server's own combat resolution needs it; no
## client-facing friendly-fire indicator exists yet (deferred, see
## memory/plan.md).
var friendly_fire_enabled: bool = false
## Client-visible aggregate alive counts, indexed by team id, kept in
## sync via broadcast_team_status()'s RPC -- individual characters'
## team assignments are never replicated (see CharacterController.
## team's own doc comment); this is the one aggregate view clients need
## for the minimal HUD, matching this project's "Event Bus restricted
## to ownerless events" convention (docs/blueprint/03). Variable length
## since Phase 6 -- team mode settles at length 2, free-for-all grows
## to however many distinct players have ever connected.
var team_alive_counts: Array[int] = []
## -1 until POST_GAME; then a team id (team mode) or player index (free-
## for-all, since PlayerSpawner assigns each FFA player their own unique
## team id), or WinCondition.DRAW (-1 is ambiguous with "no result yet"
## only in isolation -- callers always check current_phase == POST_GAME
## first, exactly like winning_team's only reader, MatchHud, already
## does).
var winning_team: int = -1
## Phase 13a: client-visible count of currently-disconnected-and-
## mid-grace-period players, kept in sync via
## broadcast_grace_period_count()'s RPC -- aggregate only, no
## per-player identity, same convention team_alive_counts above
## already uses.
var players_in_grace_period: int = 0

## Server-only bookkeeping for the LOADING handshake: which currently-
## connected peers have reported their own TestArena tree is actually
## ready. Cleared on every enter_loading() call.
var _loaded_peer_ids: Dictionary = {}

var _intermission_generation: int = 0
var _intermission_start_ticks_msec: int = 0
## Overridable for live dev testing (--dev-intermission-window=/
## --dev-intermission-early-threshold=/--dev-intermission-early-seconds=/
## --dev-intermission-late-seconds=), same "const default + overridable
## var" shape net/lobby_state.gd's own countdown already uses.
var _intermission_window_seconds: float = INTERMISSION_WINDOW_SECONDS
var _intermission_early_threshold_seconds: float = INTERMISSION_EARLY_THRESHOLD_SECONDS
var _intermission_early_countdown_seconds: float = INTERMISSION_EARLY_COUNTDOWN_SECONDS
var _intermission_late_countdown_seconds: float = INTERMISSION_LATE_COUNTDOWN_SECONDS


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_apply_dev_intermission_overrides()


## Same convention as net/lobby_state.gd's own
## _apply_dev_countdown_overrides(): read OS.get_cmdline_user_args()
## directly here, guarded with is_valid_float() (a malformed value
## silently falling back to the production default was a real bug
## found by /check on a similar flag once, see memory/gotchas.md).
func _apply_dev_intermission_overrides() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dev-intermission-window="):
			var value := arg.trim_prefix("--dev-intermission-window=")
			if value.is_valid_float():
				_intermission_window_seconds = value.to_float()
		elif arg.begins_with("--dev-intermission-early-threshold="):
			var value := arg.trim_prefix("--dev-intermission-early-threshold=")
			if value.is_valid_float():
				_intermission_early_threshold_seconds = value.to_float()
		elif arg.begins_with("--dev-intermission-early-seconds="):
			var value := arg.trim_prefix("--dev-intermission-early-seconds=")
			if value.is_valid_float():
				_intermission_early_countdown_seconds = value.to_float()
		elif arg.begins_with("--dev-intermission-late-seconds="):
			var value := arg.trim_prefix("--dev-intermission-late-seconds=")
			if value.is_valid_float():
				_intermission_late_countdown_seconds = value.to_float()


## Server-only: brings a newly-connected peer's own MatchState copy up
## to date, since an RPC broadcast earlier in the match only reached
## peers that were already connected at the time it fired.
##
## Known narrow gap, not handled (same class of gap this file's own
## LOADING catch-up already accepts): a peer connecting DURING an
## active ROUND_INTERMISSION gets no catch-up RPC for it at all here --
## unlikely in this project's small-player-count flow, not worth the
## extra bookkeeping (round_wins/current_round themselves are still
## caught up via the POST_GAME/round_ended-adjacent broadcasts once the
## match actually reaches a new state) until it's a real problem.
func _on_peer_connected(peer_id: int) -> void:
	if not NetworkManager.is_server():
		return
	GameLog.info("peer_connected", {"peer_id": peer_id})
	if current_phase == Phase.IN_PROGRESS:
		_rpc_enter_in_progress.rpc_id(peer_id, match_mode)
	elif current_phase == Phase.POST_GAME:
		_rpc_enter_post_game.rpc_id(peer_id, winning_team, match_mode, round_wins)
	if current_phase != Phase.LOBBY:
		_rpc_receive_team_status.rpc_id(peer_id, team_alive_counts)
		_rpc_receive_grace_period_count.rpc_id(peer_id, players_in_grace_period)


## Server-only: a peer leaving mid-LOADING must not permanently block
## enter_in_progress() from ever firing -- re-check without them.
func _on_peer_disconnected(peer_id: int) -> void:
	if not NetworkManager.is_server():
		return
	GameLog.info("peer_disconnected", {"peer_id": peer_id})
	if current_phase != Phase.LOADING:
		return
	_loaded_peer_ids.erase(peer_id)
	if _all_connected_peers_loaded():
		enter_in_progress()


## Server-only: called by net/lobby_state.gd's own _start_match() (Phase
## 14: automatically, once the room's ready-countdown completes -- there
## is no more host-only Start button, see ui/lobby/lobby.gd) with the
## mode chosen in Room Config. Every peer reacts by scene-
## changing to TestArena.tscn; the actual match doesn't start until
## every one of them reports back ready, see report_loaded() below.
## Phase 8: broadcasts mode here (rather than leaving match_mode
## server-local, as it was when only dev_bootstrap.gd's --free-for-all
## flag set it identically on every process before anyone connected) --
## a real bug found by /check: without this, a non-host client's own
## match_mode silently stayed at the TEAM default even in an FFA match,
## since Room Config's choice previously only reached the server. See
## memory/gotchas.md.
func enter_loading(mode: MatchMode) -> void:
	current_phase = Phase.LOADING
	match_mode = mode
	_loaded_peer_ids.clear()
	GameLog.info("round_loading", {"round": current_round, "mode": mode})
	_rpc_enter_loading.rpc(mode)


@rpc("authority", "reliable", "call_local")
func _rpc_enter_loading(mode: int) -> void:
	current_phase = Phase.LOADING
	match_mode = mode
	EventBus.match_state_changed.emit(current_phase)


## Called locally by each peer once its own TestArena tree has finished
## building (net/loading_reporter.gd, TestArena.tscn's last child).
func report_loaded() -> void:
	if NetworkManager.is_server():
		_mark_loaded(multiplayer.get_unique_id())
	else:
		_rpc_report_loaded.rpc_id(1)


## any_peer, but trusts multiplayer.get_remote_sender_id() instead of
## a client-supplied id, same reasoning as LobbyState._rpc_register.
@rpc("any_peer", "reliable")
func _rpc_report_loaded() -> void:
	if not NetworkManager.is_server():
		return
	_mark_loaded(multiplayer.get_remote_sender_id())


func _mark_loaded(peer_id: int) -> void:
	if current_phase != Phase.LOADING:
		return
	_loaded_peer_ids[peer_id] = true
	if _all_connected_peers_loaded():
		enter_in_progress()


func _all_connected_peers_loaded() -> bool:
	if not _loaded_peer_ids.has(multiplayer.get_unique_id()):
		return false
	for peer_id in multiplayer.get_peers():
		if not _loaded_peer_ids.has(peer_id):
			return false
	return true


## No mode parameter -- broadcasts the current match_mode, already set
## either by enter_loading() (Room Config flow) or directly by
## dev_bootstrap.gd's --free-for-all flag before this is ever called
## (direct-connect flow, which skips LOADING entirely).
func enter_in_progress() -> void:
	current_phase = Phase.IN_PROGRESS
	GameLog.info("round_in_progress", {"round": current_round})
	_rpc_enter_in_progress.rpc(match_mode)


@rpc("authority", "reliable", "call_local")
func _rpc_enter_in_progress(mode: int) -> void:
	current_phase = Phase.IN_PROGRESS
	match_mode = mode
	EventBus.match_state_changed.emit(current_phase)


func is_in_progress() -> bool:
	return current_phase == Phase.IN_PROGRESS


## Server-only: called once by MatchRules when the win condition
## resolves. A no-op if the match already ended -- MatchRules checks
## every physics tick and must not re-broadcast on every subsequent
## tick once a result is already decided.
func enter_post_game(winning: int) -> void:
	if current_phase == Phase.POST_GAME:
		return
	current_phase = Phase.POST_GAME
	winning_team = winning
	GameLog.info("match_ended", {"winner": winning, "round_wins": round_wins})
	_rpc_enter_post_game.rpc(winning, match_mode, round_wins)


## round_wins parameter added Phase 17 -- the final POST_GAME screen
## shows the match's round score (e.g. "Red wins the match 2-1"), not
## just who won, see ui/hud/match_hud.gd's own _show_banner().
@rpc("authority", "reliable", "call_local")
func _rpc_enter_post_game(winning: int, mode: int, wins: Dictionary) -> void:
	current_phase = Phase.POST_GAME
	winning_team = winning
	match_mode = mode
	round_wins = wins
	EventBus.match_state_changed.emit(current_phase)


## Server-only: called by gameplay/match/match_rules.gd INSTEAD of
## enter_post_game() directly, now that a single WinCondition.determine()
## result might mean "this round is over" rather than "the match is
## over" -- see decide_round_outcome() for the pure branching logic
## this wraps with the actual RPC dispatch. A no-op once the match has
## already left IN_PROGRESS, same idempotency reasoning enter_post_game()
## itself already has (MatchRules checks every physics tick).
func resolve_round_result(result: int) -> void:
	if current_phase != Phase.IN_PROGRESS:
		return
	var outcome := decide_round_outcome(result, round_wins)
	round_wins = outcome["wins"]
	if outcome["is_match_end"]:
		enter_post_game(outcome["winner"])
		return
	var completed_round := current_round
	if not outcome["is_draw"]:
		current_round += 1
	(
		GameLog
		. info(
			"round_ended",
			{
				"completed_round": completed_round,
				"winner": outcome["winner"],
				"is_draw": outcome["is_draw"],
				"round_wins": round_wins,
			}
		)
	)
	_rpc_round_ended.rpc(outcome["winner"], round_wins, completed_round)
	_begin_round_intermission()


## Pure: given a just-finished round's WinCondition.determine() result
## and the round_wins tally BEFORE this round, decides what happens
## next -- same separation-of-concerns WinCondition.determine() itself
## already gets from MatchRules' own Node orchestration, so this is
## unit-testable with no RPC/multiplayer context at all. Never mutates
## the input dict (duplicate()s before writing), since resolve_round_
## result() above still needs its own pre-round copy for the completed_
## round/is_draw branching.
static func decide_round_outcome(result: int, wins: Dictionary) -> Dictionary:
	if result == WinCondition.DRAW:
		return {"is_match_end": false, "is_draw": true, "winner": WinCondition.DRAW, "wins": wins}
	var new_wins: Dictionary = wins.duplicate()
	new_wins[result] = new_wins.get(result, 0) + 1
	return {
		"is_match_end": new_wins[result] >= ROUND_TARGET,
		"is_draw": false,
		"winner": result,
		"wins": new_wins,
	}


## winner is WinCondition.DRAW for a drawn round, otherwise the round's
## winning team_id/player index. completed_round is the round number
## that JUST ended (never the upcoming one) -- current_round below is
## only advanced here for a DECISIVE round, since a draw simply
## replays the same round number.
@rpc("authority", "reliable", "call_local")
func _rpc_round_ended(winner: int, wins: Dictionary, completed_round: int) -> void:
	round_wins = wins
	if winner != WinCondition.DRAW:
		current_round = completed_round + 1
	EventBus.round_ended.emit(winner, wins, completed_round)


## Server-only: enters the inter-round loadout-adjustment phase and
## starts its own 15s pick/confirm window. See the class-level
## INTERMISSION_* constants' own doc comment for the exact timing.
func _begin_round_intermission() -> void:
	current_phase = Phase.ROUND_INTERMISSION
	player_loadout_confirmed.clear()
	GameLog.info("round_intermission_started", {"next_round": current_round})
	_rpc_enter_round_intermission.rpc()
	_intermission_generation += 1
	_intermission_start_ticks_msec = Time.get_ticks_msec()
	_run_intermission_window(_intermission_generation)


@rpc("authority", "reliable", "call_local")
func _rpc_enter_round_intermission() -> void:
	current_phase = Phase.ROUND_INTERMISSION
	player_loadout_confirmed.clear()
	EventBus.match_state_changed.emit(current_phase)


## Called locally by any peer to confirm (or un-confirm, symmetric to
## net/lobby_state.gd's own set_local_ready()) their OWN round loadout
## -- self-service, same authority shape as every other per-peer choice
## in this project.
func set_local_loadout_confirmed(confirmed: bool) -> void:
	var peer_id := multiplayer.get_unique_id()
	if NetworkManager.is_server():
		_apply_loadout_confirmed(peer_id, confirmed)
	else:
		_rpc_set_loadout_confirmed.rpc_id(1, confirmed)


## any_peer, but never trusts a client-supplied peer id -- same trust
## reasoning as net/lobby_state.gd's own _rpc_set_ready.
@rpc("any_peer", "reliable")
func _rpc_set_loadout_confirmed(confirmed: bool) -> void:
	if not NetworkManager.is_server():
		return
	_apply_loadout_confirmed(multiplayer.get_remote_sender_id(), confirmed)


func _apply_loadout_confirmed(peer_id: int, confirmed: bool) -> void:
	player_loadout_confirmed[peer_id] = confirmed
	_rpc_receive_loadout_confirmed.rpc(player_loadout_confirmed)
	_maybe_finish_intermission_early()


@rpc("authority", "reliable", "call_local")
func _rpc_receive_loadout_confirmed(confirmed: Dictionary) -> void:
	player_loadout_confirmed = confirmed
	EventBus.loadout_confirmed_changed.emit(confirmed)


## Pure-ish (touches multiplayer, like net/match_state.gd's own
## _all_connected_peers_loaded() and net/lobby_state.gd's own
## all_ready() already do) -- true once every currently-connected peer,
## including this instance's own unique id, has confirmed. Same
## "missing entry means false" rule as all_ready().
func all_loadout_confirmed() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return false
	if not player_loadout_confirmed.get(multiplayer.get_unique_id(), false):
		return false
	for peer_id in multiplayer.get_peers():
		if not player_loadout_confirmed.get(peer_id, false):
			return false
	return true


## Pure: true if elapsed_seconds (time since the 15s window opened) is
## still under the "early" bonus threshold -- see the class-level
## INTERMISSION_* constants' own doc comment for the exact reasoning.
func is_early_confirm(elapsed_seconds: float) -> bool:
	return elapsed_seconds < _intermission_early_threshold_seconds


## Server-only: checked after every confirm change. Only the EARLY path
## is event-driven like this -- the LATE path always waits for
## _run_intermission_window()'s own 15s timer instead, per this
## constant's own doc comment (a late-but-complete confirm-set still
## waits out the full window, it doesn't jump the queue).
func _maybe_finish_intermission_early() -> void:
	if not NetworkManager.is_server():
		return
	if current_phase != Phase.ROUND_INTERMISSION:
		return
	if not all_loadout_confirmed():
		return
	var elapsed := (Time.get_ticks_msec() - _intermission_start_ticks_msec) / 1000.0
	if is_early_confirm(elapsed):
		_run_final_countdown(_intermission_early_countdown_seconds)


## Fires once, INTERMISSION_WINDOW_SECONDS after the window opened. A
## no-op if the early path (above) already handled this intermission --
## detected via the generation bump _run_final_countdown() itself does.
func _run_intermission_window(my_generation: int) -> void:
	await get_tree().create_timer(_intermission_window_seconds).timeout
	if my_generation != _intermission_generation or current_phase != Phase.ROUND_INTERMISSION:
		return
	_run_final_countdown(_intermission_late_countdown_seconds)


## Bumps _intermission_generation itself (not just reads it) so
## whichever of _maybe_finish_intermission_early()/
## _run_intermission_window() calls this first is the only one that
## ever runs a final countdown for a given intermission -- the other
## path's own generation check then fails harmlessly.
func _run_final_countdown(seconds: float) -> void:
	_intermission_generation += 1
	var my_generation := _intermission_generation
	var remaining := seconds
	while remaining > 0.0:
		_set_intermission_remaining(remaining)
		await get_tree().create_timer(1.0).timeout
		if my_generation != _intermission_generation or current_phase != Phase.ROUND_INTERMISSION:
			return
		remaining -= 1.0
	_set_intermission_remaining(-1.0)
	_start_next_round()


func _set_intermission_remaining(value: float) -> void:
	_rpc_receive_intermission_countdown.rpc(value)


@rpc("authority", "reliable", "call_local")
func _rpc_receive_intermission_countdown(value: float) -> void:
	intermission_seconds_remaining = value
	EventBus.intermission_countdown_changed.emit(value)


## Reuses enter_loading() outright -- the exact same LOADING->
## IN_PROGRESS cycle Room Config's own first round start already
## triggers, which gives every character a full, already-proven reset
## (health/position/cooldowns/action-FSM state) via TestArena.tscn's
## own fresh scene load, and re-resolves each peer's CURRENT weapon/
## boot/perk/class/team from LobbyState on respawn for free (see
## Phase 9/16's own "every peer's own _ready() reads LobbyState, never
## PlayerSpawner" pattern) -- no separate "reset stats in place" path
## needed.
func _start_next_round() -> void:
	enter_loading(match_mode)


## Server-only: broadcasts alive counts (indexed by team id) to every
## peer for the minimal HUD. unreliable_ordered like the position/
## health snapshot RPC -- a missed update is harmless, the next one
## supersedes it, and MatchRules only calls this on an actual change,
## so traffic stays minimal without needing a throttle.
func broadcast_team_status(alive_counts: Array[int]) -> void:
	_rpc_receive_team_status.rpc(alive_counts)


@rpc("authority", "unreliable_ordered", "call_local")
func _rpc_receive_team_status(alive_counts: Array[int]) -> void:
	team_alive_counts = alive_counts
	EventBus.team_status_changed.emit(alive_counts)


## Server-only: called by net/player_spawner.gd whenever a grace period
## starts or ends. reliable, unlike broadcast_team_status()'s own
## unreliable_ordered -- a missed "count went up" update here would
## leave a stale "N players disconnected" indicator on-screen instead
## of just a stale number, worth the (rare, low-frequency) extra
## guarantee.
func broadcast_grace_period_count(count: int) -> void:
	_rpc_receive_grace_period_count.rpc(count)


@rpc("authority", "reliable", "call_local")
func _rpc_receive_grace_period_count(count: int) -> void:
	players_in_grace_period = count
	EventBus.grace_period_count_changed.emit(count)
