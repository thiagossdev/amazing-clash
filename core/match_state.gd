extends Node
## Orchestrator autoload -- source of truth for the match phase.
## See docs/blueprint/03-networking-and-match-modes.md.
##
## Phase 1 has no Lobby/CharacterSelect UI yet: TestArena is the main
## scene and enters IN_PROGRESS directly once networking is up. RECONNECT
## is a sub-state of IN_PROGRESS conceptually, not its own Phase value
## here -- a disconnect just despawns that character (PlayerSpawner) and
## MatchRules' elimination check treats a team dropping to 0 current
## members the same whether by disconnect or defeat; a real
## reconnect/grace-period system is out of scope for Phase 5.
##
## Phase 5: this file's phase is now client-visible for the first time
## (nothing before this phase read current_phase client-side), which
## surfaced a real gap -- enter_in_progress() used to just set a local
## var with no RPC, so a client's own copy never actually changed. Both
## phase-transition methods below now broadcast via RPC, and a peer
## connecting AFTER a transition already fired is caught up in
## _on_peer_connected() (mirroring PlayerSpawner's own "catch up a late
## joiner" pattern for already-spawned characters).

enum Phase { LOBBY, CHARACTER_SELECT, LOADING, IN_PROGRESS, POST_GAME }

var current_phase: Phase = Phase.LOBBY
## Server-decided per match (see net/dev_bootstrap.gd's --friendly-fire
## flag), read every tick by CombatResolver -- never replicated to
## clients, since only the server's own combat resolution needs it; no
## client-facing friendly-fire indicator exists yet (deferred, see
## memory/plan.md).
var friendly_fire_enabled: bool = false
## Client-visible aggregate alive counts per team, kept in sync via
## broadcast_team_status()'s RPC -- individual characters' team
## assignments are never replicated (see CharacterController.team's own
## doc comment); this is the one aggregate view clients need for the
## minimal HUD, matching this project's "Event Bus restricted to
## ownerless events" convention (docs/blueprint/03).
var team_alive_counts: Array[int] = [0, 0]
## -1 until POST_GAME; then a team index, or WinCondition.DRAW (-1 is
## ambiguous with "no result yet" only in isolation -- callers always
## check current_phase == POST_GAME first, exactly like winning_team's
## only reader, MatchHud, already does).
var winning_team: int = -1


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)


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
		_rpc_receive_team_status.rpc_id(peer_id, team_alive_counts[0], team_alive_counts[1])


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


## Server-only: broadcasts the 2 teams' alive counts to every peer for
## the minimal HUD. unreliable_ordered like the position/health
## snapshot RPC -- a missed update is harmless, the next one supersedes
## it, and MatchRules only calls this on an actual change, so traffic
## stays minimal without needing a throttle.
func broadcast_team_status(team0_alive: int, team1_alive: int) -> void:
	_rpc_receive_team_status.rpc(team0_alive, team1_alive)


@rpc("authority", "unreliable_ordered", "call_local")
func _rpc_receive_team_status(team0_alive: int, team1_alive: int) -> void:
	team_alive_counts = [team0_alive, team1_alive]
	EventBus.team_status_changed.emit(team0_alive, team1_alive)
