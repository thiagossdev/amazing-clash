extends Node
## Server-authoritative room state: each connected peer's chosen
## character class (CharacterSelect, before ever connecting), team
## (Team mode only, manually assigned by the host in Room Config), and
## ready flag -- plus the room-level settings the host picks in Room
## Config (match mode, friendly fire). Read by PlayerSpawner instead of
## its old index-cycling default -- a peer with no registered choice
## (e.g. a net/dev_bootstrap.gd headless test peer, which never goes
## through CharacterSelect/Room Config) falls back to PlayerSpawner's
## original cycling behavior unchanged, so every prior phase's headless
## verification keeps working untouched. See memory/plan.md's "Slices
## 7-10" section.
##
## Phase 8: grew from a class-only registry to full room state (team,
## ready, mode, friendly fire) rather than adding a second parallel
## registry -- this node already *is* "the room's shared state," not
## just a class picker, so generalizing its existing name/shape fit
## better than inventing a sibling.

## Fired on every peer whenever any room state changes (class, team,
## ready, mode, or friendly fire) -- ui/lobby/lobby.gd's Room Config
## screen listens to this to redraw itself.
signal room_state_changed

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

## Server-authoritative peer_id -> team id (0/1), Team mode only -- FFA
## ignores this entirely, since PlayerSpawner already assigns a unique
## team per player in FFA with no manual input needed. Defaulted on
## registration by alternating connection order (the same formula
## PlayerSpawner used before Phase 8), then the host can move any peer
## with set_team().
var player_team_ids: Dictionary = {}

## Server-authoritative peer_id -> ready flag, for every peer EXCEPT
## the host. The host's own id is never a meaningful key here --
## pressing Start on the host's own client is the host's readiness
## signal, no separate checkbox for them (see ui/lobby/lobby.gd).
var player_ready: Dictionary = {}

## Room-level settings, staged in Room Config before Start and applied
## to MatchState.match_mode/friendly_fire_enabled the moment Start is
## pressed (see lobby.gd._on_start_pressed). Broadcast continuously so
## every peer's Room Config screen reflects the host's current choice
## live; only the host can change them (read-only on other clients).
## Stored as plain int (not MatchState.MatchMode) purely so the RPC
## payload's type stays a primitive -- callers compare against
## MatchState.MatchMode's own enum values.
var room_match_mode: int = MatchState.MatchMode.TEAM
var room_friendly_fire: bool = false

var _next_team_index: int = 0


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


func get_team_id(peer_id: int, fallback: int = 0) -> int:
	return player_team_ids.get(peer_id, fallback)


func is_ready(peer_id: int) -> bool:
	return player_ready.get(peer_id, false)


## Pure: true once every currently-registered peer other than the host
## has marked itself ready. A peer that has registered a class but not
## yet reported ready counts as not ready (a missing entry means
## false, it is never skipped).
func all_non_host_ready(host_peer_id: int) -> bool:
	for peer_id in player_class_ids:
		if peer_id == host_peer_id:
			continue
		if not player_ready.get(peer_id, false):
			return false
	return true


## Called locally by the connecting peer (host or client) right after
## NetworkManager.host()/join() succeeds, to register local_chosen_
## class_id under this peer's own id.
func register_local_player() -> void:
	var peer_id := multiplayer.get_unique_id()
	if NetworkManager.is_server():
		_apply_registration(peer_id, local_chosen_class_id)
		_broadcast_room_state()
	else:
		_rpc_register.rpc_id(1, local_chosen_class_id)


## Called locally by any peer to set their OWN ready flag. The host
## never needs to call this for itself (see player_ready's own doc
## comment) -- ui/lobby/lobby.gd simply never draws a ready control on
## the host's own row.
func set_local_ready(ready: bool) -> void:
	var peer_id := multiplayer.get_unique_id()
	if NetworkManager.is_server():
		_apply_ready(peer_id, ready)
		_broadcast_room_state()
	else:
		_rpc_set_ready.rpc_id(1, ready)


## Host-only: moves any connected peer (including the host itself)
## between teams. Not RPC'd -- only ever called by the host's own Room
## Config screen, which only draws team controls when
## NetworkManager.is_server() is true, so there is no remote-caller
## path to guard against here the way _rpc_register/_rpc_set_ready
## must.
func set_team(peer_id: int, team_id: int) -> void:
	if not NetworkManager.is_server():
		return
	player_team_ids[peer_id] = team_id
	_broadcast_room_state()


## Host-only, same reasoning as set_team() -- called directly by the
## host's own Room Config controls, never over RPC.
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


## Pure Dictionary mutation, no RPC -- callers are responsible for
## broadcasting afterward. Kept separate so it stays testable without
## a multiplayer peer (see test_get_class_id_returns_registered_choice).
## Also seeds a default alternating team assignment on first
## registration, same formula PlayerSpawner used before Phase 8 --
## re-registering an already-known peer (e.g. picking a class again)
## never resets a team the host may have already manually moved.
func _apply_registration(peer_id: int, class_id: String) -> void:
	player_class_ids[peer_id] = resolve_class_id(class_id)
	if not player_team_ids.has(peer_id):
		player_team_ids[peer_id] = _next_team_index % 2
		_next_team_index += 1


func _apply_ready(peer_id: int, ready: bool) -> void:
	player_ready[peer_id] = ready


func _broadcast_room_state() -> void:
	_rpc_receive_room_state.rpc(
		player_class_ids, player_team_ids, player_ready, room_match_mode, room_friendly_fire
	)


@rpc("authority", "reliable", "call_local")
func _rpc_receive_room_state(
	classes: Dictionary, teams: Dictionary, ready: Dictionary, mode: int, friendly_fire: bool
) -> void:
	player_class_ids = classes
	player_team_ids = teams
	player_ready = ready
	room_match_mode = mode
	room_friendly_fire = friendly_fire
	room_state_changed.emit()
