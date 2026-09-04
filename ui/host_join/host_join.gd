extends Control
## Host/Join, either by manual IP entry (always available) or by
## picking a room LanDiscovery found on the LAN (Slice 10, see
## memory/plan.md's "Slice 10" -- broadcast reliability across a real
## router/Wi-Fi setup is unverified, which is exactly why manual IP
## entry never goes away).

@onready var _join_address_edit: LineEdit = $JoinAddressEdit
@onready var _status_label: Label = $StatusLabel
@onready var _lan_rooms_list: ItemList = $LanRoomsList


func _ready() -> void:
	$HostButton.pressed.connect(_on_host_pressed)
	$JoinButton.pressed.connect(_on_join_button_pressed)
	_lan_rooms_list.item_activated.connect(_on_lan_room_activated)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	LanDiscovery.rooms_updated.connect(_redraw_lan_rooms)
	LanDiscovery.start_listening()
	_maybe_dev_autoconnect()


## Releases our own listen-socket bind on DISCOVERY_PORT (via
## stop_listening()) BEFORE anything else -- including before
## NetworkManager.host() -- so a sibling process on the same machine
## trying to bind that same port to listen (this project's own
## 2-headless-process local-verification convention) isn't held up any
## longer than necessary. PacketPeerUDP.bind() has no SO_REUSEPORT
## option in Godot's GDScript API, so 2 real processes briefly racing
## for the same port is a genuine, if narrow, possibility here -- never
## a concern for 2 real players, who are always on separate machines
## with separate network stacks.
func _on_host_pressed() -> void:
	LanDiscovery.stop_listening()
	var err := NetworkManager.host()
	if err != OK:
		_status_label.text = "Failed to host (error %s)" % err
		return
	LanDiscovery.start_advertising()
	_enter_lobby()


func _on_join_button_pressed() -> void:
	_on_join_pressed(_join_address_edit.text)


func _on_join_pressed(address: String) -> void:
	var target := address if not address.is_empty() else "127.0.0.1"
	# Slice 13b: remembered even for a first-time join, not just a
	# reconnect -- ReconnectManager only ever *acts* on this after a
	# real disconnect (see its own _on_disconnected()), so recording it
	# unconditionally here is simpler than threading a "is this a
	# reconnect" flag through every join call site.
	ReconnectManager.remember_join_target(target, NetworkManager.DEFAULT_PORT)
	var err := NetworkManager.join(target)
	if err != OK:
		_status_label.text = "Failed to join (error %s)" % err
		return
	_status_label.text = "Connecting..."


func _on_connected() -> void:
	_enter_lobby()


func _on_connection_failed() -> void:
	_status_label.text = "Connection failed."
	NetworkManager.close()


func _enter_lobby() -> void:
	LanDiscovery.stop_listening()
	LobbyState.register_local_player()
	get_tree().change_scene_to_file("res://ui/lobby/Lobby.tscn")


## Redraws the discovered-rooms list from LanDiscovery.discovered_rooms
## -- each row stores its room's IP as item metadata so
## _on_lan_room_activated() never has to re-parse the label text.
func _redraw_lan_rooms() -> void:
	_lan_rooms_list.clear()
	for ip in LanDiscovery.discovered_rooms:
		var room: Dictionary = LanDiscovery.discovered_rooms[ip]
		var index := _lan_rooms_list.add_item(
			"%s -- %d/%d players" % [ip, room["player_count"], room["max_players"]]
		)
		_lan_rooms_list.set_item_metadata(index, ip)


func _on_lan_room_activated(index: int) -> void:
	_on_join_pressed(_lan_rooms_list.get_item_metadata(index))


## Headless dev testing hook, same reasoning as CharacterSelect's own.
## --dev-join-discovered proves the LanDiscovery pipeline specifically
## (not just direct-IP join, which --dev-join=<ip> already covers) --
## there is no real mouse to double-click a LanRoomsList row in this
## environment.
func _maybe_dev_autoconnect() -> void:
	var args := OS.get_cmdline_user_args()
	if "--dev-host" in args:
		_on_host_pressed()
		return
	if "--dev-join-discovered" in args:
		_await_and_join_discovered_room()
		return
	for arg in args:
		if arg.begins_with("--dev-join="):
			_on_join_pressed(arg.trim_prefix("--dev-join="))


## Polls LanDiscovery.discovered_rooms (rather than a fixed delay --
## proved unreliable across independent OS processes in Phase 7's own
## live testing) for the host's beacon to arrive, up to a bounded wait.
func _await_and_join_discovered_room() -> void:
	var max_wait_ticks := 40
	for _i in max_wait_ticks:
		if not LanDiscovery.discovered_rooms.is_empty():
			var ip: String = LanDiscovery.discovered_rooms.keys()[0]
			_on_join_pressed(ip)
			return
		await get_tree().create_timer(0.5).timeout
	_status_label.text = "No LAN rooms found -- try Join by IP."
