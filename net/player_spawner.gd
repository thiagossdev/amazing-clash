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
## Phase 4: alternates the real classes by connection order (same
## array-cycling pattern SPAWN_POSITIONS already uses below) -- no
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

## 4 points (2v2's default team size): team 0 clusters on the left,
## team 1 clusters on the right -- index parity matches
## _spawn_for_peer's own `team = index % 2`, so index 0/2 (team 0) land
## near x=300 and index 1/3 (team 1) near x=900. Teammates are placed
## side by side, 60 units apart on the same y (the same spacing and
## axis Phase 2a already verified live puts a melee hitbox in reach of
## the other, since LocomotionFsm's default facing_direction is
## Vector2.RIGHT -- a vertical offset wouldn't be in a default-facing
## melee swing's path). The 2nd-spawned member of each team (index 2/3)
## is placed at a LOWER x than the 1st (index 0/1) -- with no move
## input yet, a fresh spawn faces right by default, so this is what
## puts the 1st member within the 2nd's default-facing melee reach
## (confirmed live: a 3rd peer's un-aimed --simulate-attack lands on
## peer 1 exactly when this ordering holds, misses when it doesn't).
## Clear of the 4 wall colliders in TestArena.tscn, and never spawn
## exactly overlapping (a degenerate case where a melee hitbox and
## hurtbox can share an exact boundary with no true intersection --
## found live, see memory/gotchas.md). Cycles for a 5th+ peer rather
## than erroring. Reused unchanged for free-for-all -- every player
## just cycles through the same 4 points regardless of mode; a
## dedicated spread-out FFA layout is a cosmetic refinement, not a
## correctness need (friendly fire and the win condition both already
## work correctly at any spawn distance).
const SPAWN_POSITIONS: Array[Vector2] = [
	Vector2(360, 400), Vector2(960, 400), Vector2(300, 400), Vector2(900, 400)
]

@export var characters_path: NodePath = ^"../Characters"

var _next_spawn_index: int = 0


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
	character.position = SPAWN_POSITIONS[_next_spawn_index % SPAWN_POSITIONS.size()]
	character.team = _resolve_team_id(peer_id)
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


func _despawn_for_peer(peer_id: int, characters: Node) -> void:
	var character := characters.get_node_or_null(str(peer_id))
	if character:
		character.queue_free()
