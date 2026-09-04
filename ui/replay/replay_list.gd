extends Control
## Phase 20: scans user://replays/ (net/replay_recorder.gd's own
## write location) and lets the player pick one to watch. Filename
## alone is enough identification (timestamp is already baked into it,
## see that file's own _ensure_file_open()) -- parsing every header
## just to list them isn't worth the extra I/O for this MVP.

const REPLAY_DIR := "user://replays"

@export var list_path: NodePath = ^"ReplayItemList"
@export var play_button_path: NodePath = ^"PlayButton"
@export var back_button_path: NodePath = ^"BackButton"
@export var empty_label_path: NodePath = ^"EmptyLabel"

var _replay_paths: Array[String] = []


func _ready() -> void:
	var list: ItemList = get_node(list_path)
	var play_button: Button = get_node(play_button_path)
	list.item_selected.connect(func(_index): play_button.disabled = false)
	play_button.pressed.connect(_on_play_pressed)
	get_node(back_button_path).pressed.connect(_on_back_pressed)
	play_button.disabled = true
	_populate_list()


func _populate_list() -> void:
	var list: ItemList = get_node(list_path)
	list.clear()
	_replay_paths.clear()
	var dir := DirAccess.open(REPLAY_DIR)
	if not dir:
		get_node(empty_label_path).visible = true
		return
	var file_names := dir.get_files()
	file_names.sort()
	for file_name in file_names:
		if not file_name.ends_with(".replay"):
			continue
		_replay_paths.append("%s/%s" % [REPLAY_DIR, file_name])
		list.add_item(file_name)
	get_node(empty_label_path).visible = _replay_paths.is_empty()


func _on_play_pressed() -> void:
	var list: ItemList = get_node(list_path)
	var selected := list.get_selected_items()
	if selected.is_empty():
		return
	get_tree().set_meta("replay_path_to_play", _replay_paths[selected[0]])
	get_tree().change_scene_to_file("res://ui/replay/ReplayPlayer.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu/MainMenu.tscn")
