extends Node
## Server-authoritative registry of each connected peer's chosen
## character class, set in CharacterSelect before ever connecting to a
## match. Read by PlayerSpawner instead of its old index-cycling
## default -- a peer with no registered choice (e.g. a
## net/dev_bootstrap.gd headless test peer, which never goes through
## CharacterSelect) falls back to PlayerSpawner's original cycling
## behavior unchanged, so every prior phase's headless verification
## keeps working untouched. See memory/plan.md's "Slices 7-10" section.

## Fired on every peer whenever the registry changes (a peer
## registered, re-registered, or disconnected) -- Lobby.gd's waiting-
## room screen listens to this to redraw its player list.
signal registry_changed

## Canonical class id strings, in the same order as
## net/player_spawner.gd's CLASS_SCENES -- CharacterSelect and
## PlayerSpawner both key off these, never a raw index, so adding a
## 4th class later only touches this list plus CLASS_SCENES.
const CLASS_IDS: Array[String] = ["vanguard", "ranged_mage", "warden"]

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


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


## Pure: maps an arbitrary requested class id to a valid one, falling
## back to the first canonical id for anything unrecognized (including
## empty string). Extracted as its own function so it's unit-testable
## without any Node/multiplayer context, matching this project's
## WinCondition-style "pure logic gets a GUT test" convention.
func resolve_class_id(requested: String) -> String:
	return requested if requested in CLASS_IDS else CLASS_IDS[0]


func get_class_id(peer_id: int, fallback: String = "") -> String:
	return player_class_ids.get(peer_id, fallback)


## Called locally by the connecting peer (host or client) right after
## NetworkManager.host()/join() succeeds, to register local_chosen_
## class_id under this peer's own id.
func register_local_player() -> void:
	var peer_id := multiplayer.get_unique_id()
	if NetworkManager.is_server():
		_apply_registration(peer_id, local_chosen_class_id)
		_broadcast()
	else:
		_rpc_register.rpc_id(1, local_chosen_class_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if not NetworkManager.is_server():
		return
	if player_class_ids.erase(peer_id):
		_broadcast()


## any_peer, but never trusts a client-supplied peer id -- registers
## under multiplayer.get_remote_sender_id() instead, so one client
## can't register (or overwrite) a different peer's slot.
@rpc("any_peer", "reliable")
func _rpc_register(class_id: String) -> void:
	if not NetworkManager.is_server():
		return
	_apply_registration(multiplayer.get_remote_sender_id(), class_id)
	_broadcast()


## Pure Dictionary mutation, no RPC -- callers are responsible for
## broadcasting afterward. Kept separate so it stays testable without
## a multiplayer peer (see test_get_class_id_returns_registered_choice).
func _apply_registration(peer_id: int, class_id: String) -> void:
	player_class_ids[peer_id] = resolve_class_id(class_id)


func _broadcast() -> void:
	_rpc_receive_registry.rpc(player_class_ids)


@rpc("authority", "reliable", "call_local")
func _rpc_receive_registry(registry: Dictionary) -> void:
	player_class_ids = registry
	registry_changed.emit()
