extends Control
## Direct-IP host/join only -- LAN room discovery is Slice 10 (see
## memory/plan.md's "Slices 7-10"); manual IP entry stays available
## even once that lands.

@onready var _join_address_edit: LineEdit = $JoinAddressEdit
@onready var _status_label: Label = $StatusLabel


func _ready() -> void:
	$HostButton.pressed.connect(_on_host_pressed)
	$JoinButton.pressed.connect(_on_join_button_pressed)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	_maybe_dev_autoconnect()


func _on_host_pressed() -> void:
	var err := NetworkManager.host()
	if err != OK:
		_status_label.text = "Failed to host (error %s)" % err
		return
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
	LobbyState.register_local_player()
	get_tree().change_scene_to_file("res://ui/lobby/Lobby.tscn")


## Headless dev testing hook, same reasoning as CharacterSelect's own.
func _maybe_dev_autoconnect() -> void:
	var args := OS.get_cmdline_user_args()
	if "--dev-host" in args:
		_on_host_pressed()
		return
	for arg in args:
		if arg.begins_with("--dev-join="):
			_on_join_pressed(arg.trim_prefix("--dev-join="))
