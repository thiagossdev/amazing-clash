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

enum Phase { LOBBY, LOADING, IN_PROGRESS, POST_GAME }
enum MatchMode { TEAM, FREE_FOR_ALL }

var current_phase: Phase = Phase.LOBBY
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

## Server-only bookkeeping for the LOADING handshake: which currently-
## connected peers have reported their own TestArena tree is actually
## ready. Cleared on every enter_loading() call.
var _loaded_peer_ids: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


## Server-only: brings a newly-connected peer's own MatchState copy up
## to date, since an RPC broadcast earlier in the match only reached
## peers that were already connected at the time it fired.
func _on_peer_connected(peer_id: int) -> void:
	if not NetworkManager.is_server():
		return
	if current_phase == Phase.IN_PROGRESS:
		_rpc_enter_in_progress.rpc_id(peer_id)
	elif current_phase == Phase.POST_GAME:
		_rpc_enter_post_game.rpc_id(peer_id, winning_team)
	if current_phase != Phase.LOBBY:
		_rpc_receive_team_status.rpc_id(peer_id, team_alive_counts)


## Server-only: a peer leaving mid-LOADING must not permanently block
## enter_in_progress() from ever firing -- re-check without them.
func _on_peer_disconnected(peer_id: int) -> void:
	if not NetworkManager.is_server():
		return
	if current_phase != Phase.LOADING:
		return
	_loaded_peer_ids.erase(peer_id)
	if _all_connected_peers_loaded():
		enter_in_progress()


## Server-only: called by ui/lobby/lobby.gd's host-only Start button.
## Every peer reacts by scene-changing to TestArena.tscn; the actual
## match doesn't start until every one of them reports back ready, see
## report_loaded() below.
func enter_loading() -> void:
	current_phase = Phase.LOADING
	_loaded_peer_ids.clear()
	_rpc_enter_loading.rpc()


@rpc("authority", "reliable", "call_local")
func _rpc_enter_loading() -> void:
	current_phase = Phase.LOADING
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


func enter_in_progress() -> void:
	current_phase = Phase.IN_PROGRESS
	_rpc_enter_in_progress.rpc()


@rpc("authority", "reliable", "call_local")
func _rpc_enter_in_progress() -> void:
	current_phase = Phase.IN_PROGRESS
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
	_rpc_enter_post_game.rpc(winning)


@rpc("authority", "reliable", "call_local")
func _rpc_enter_post_game(winning: int) -> void:
	current_phase = Phase.POST_GAME
	winning_team = winning
	EventBus.match_state_changed.emit(current_phase)


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
