class_name PlayerSpawner
extends Node
## Server-side: mirrors connected peers into Character.tscn instances
## under a MultiplayerSpawner-watched container, so every peer sees the
## same characters replicated automatically. The server also spawns a
## character for itself (peer_connected never fires for your own id).
## Phase 1 has no persistent per-peer state (no health/team yet), so a
## disconnect just despawns the character and a (re)connecting peer
## (a new peer id -- Godot never reuses one) simply gets a fresh one;
## no reconnect-state bookkeeping is needed at this scope. Pattern
## inherited from amazing-nauts' net/player_spawner.gd, scoped down.
## See docs/blueprint/03-networking-and-match-modes.md.

const CHARACTER_SCENE := preload("res://gameplay/characters/character_base/Character.tscn")

## Room center, clear of the 4 wall colliders in TestArena.tscn.
const SPAWN_POSITION := Vector2(600, 400)

@export var characters_path: NodePath = ^"../Characters"


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
	var character := CHARACTER_SCENE.instantiate()
	character.name = str(peer_id)
	character.position = SPAWN_POSITION
	characters.add_child(character)


func _despawn_for_peer(peer_id: int, characters: Node) -> void:
	var character := characters.get_node_or_null(str(peer_id))
	if character:
		character.queue_free()
