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


func _on_host_pressed() -> void:
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
func _maybe_dev_autoconnect() -> void:
	var args := OS.get_cmdline_user_args()
	if "--dev-host" in args:
		_on_host_pressed()
		return
	for arg in args:
		if arg.begins_with("--dev-join="):
			_on_join_pressed(arg.trim_prefix("--dev-join="))
