class_name PlayerSpawner
extends Node
## Server-side: mirrors connected peers into class-scene instances under
## a MultiplayerSpawner-watched container, so every peer sees the same
## characters replicated automatically. The server also spawns a
## character for itself (peer_connected never fires for your own id).
## A disconnect despawns the character; PlayerSpawner does not track
## which peer_id previously held which team/class, so a (re)connecting
## peer (a new peer id -- Godot never reuses one) is assigned fresh,
## not restored to a prior slot -- a real reconnect system is out of
## scope, see memory/plan.md. Pattern inherited from amazing-nauts'
## net/player_spawner.gd, scoped down. See
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

@export var characters_path: NodePath = ^"../Characters"

var _next_spawn_index: int = 0
var _next_index_for_team: Dictionary = {}


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
	var characters := get_node(characters_path)
	multiplayer.peer_connected.connect(func(peer_id): _spawn_for_peer(peer_id, characters))
	multiplayer.peer_disconnected.connect(func(peer_id): _despawn_for_peer(peer_id, characters))
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


func _despawn_for_peer(peer_id: int, characters: Node) -> void:
	var character := characters.get_node_or_null(str(peer_id))
	if character:
		character.queue_free()
