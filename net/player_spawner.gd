class_name PlayerSpawner
extends Node
## Server-side: mirrors connected peers into class-scene instances under
## a MultiplayerSpawner-watched container, so every peer sees the same
## characters replicated automatically. The server also spawns a
## character for itself (peer_connected never fires for your own id).
## Phase 1 has no persistent per-peer state (no health/team yet), so a
## disconnect just despawns the character and a (re)connecting peer
## (a new peer id -- Godot never reuses one) simply gets a fresh one;
## no reconnect-state bookkeeping is needed at this scope. Pattern
## inherited from amazing-nauts' net/player_spawner.gd, scoped down.
## See docs/blueprint/03-networking-and-match-modes.md.
##
## Phase 4: alternates the 2 real classes by connection order (same
## array-cycling pattern SPAWN_POSITIONS already uses below) -- no
## lobby/character-select exists yet (that's Phase 5's job), so this is
## the simplest thing that lets both classes exist and fight each other
## in a live match today, without requiring Phase 5 to land first.
const CLASS_SCENES: Array[PackedScene] = [
	preload("res://gameplay/characters/vanguard/Vanguard.tscn"),
	preload("res://gameplay/characters/ranged_mage/RangedMage.tscn"),
]

## Distinct points, clear of the 4 wall colliders in TestArena.tscn and
## far enough apart that two characters never spawn overlapping (a
## degenerate case where a melee hitbox and hurtbox can share an exact
## boundary with no true intersection -- found live, see
## memory/gotchas.md). Cycles for a 3rd+ peer rather than erroring; a
## real spawn-point system per match mode is a later phase's concern.
const SPAWN_POSITIONS: Array[Vector2] = [Vector2(570, 400), Vector2(630, 400)]

@export var characters_path: NodePath = ^"../Characters"

var _next_spawn_index: int = 0


func _ready() -> void:
	if not NetworkManager.is_server():
		return
	var characters := get_node(characters_path)
	_spawn_for_peer(multiplayer.get_unique_id(), characters)
	for peer_id in multiplayer.get_peers():
		_spawn_for_peer(peer_id, characters)
	multiplayer.peer_connected.connect(func(peer_id): _spawn_for_peer(peer_id, characters))
	multiplayer.peer_disconnected.connect(func(peer_id): _despawn_for_peer(peer_id, characters))


func _spawn_for_peer(peer_id: int, characters: Node) -> void:
	if characters.has_node(str(peer_id)):
		return
	var class_scene := CLASS_SCENES[_next_spawn_index % CLASS_SCENES.size()]
	var character := class_scene.instantiate()
	character.name = str(peer_id)
	character.position = SPAWN_POSITIONS[_next_spawn_index % SPAWN_POSITIONS.size()]
	_next_spawn_index += 1
	characters.add_child(character)


func _despawn_for_peer(peer_id: int, characters: Node) -> void:
	var character := characters.get_node_or_null(str(peer_id))
	if character:
		character.queue_free()
