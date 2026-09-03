extends Control
## Local, pre-connection class pick -- no duplicate-class check across
## players (confirmed by the human owner, see memory/plan.md's "Slices
## 7-10"). Stores the choice in LobbyState.local_chosen_class_id, read
## once by LobbyState.register_local_player() right after a successful
## host()/join() in ui/host_join/.

@onready var _class_buttons: Dictionary = {
	"vanguard": $VanguardButton,
	"ranged_mage": $RangedMageButton,
	"warden": $WardenButton,
}


func _ready() -> void:
	for class_id in _class_buttons:
		_class_buttons[class_id].pressed.connect(_select_class.bind(class_id))
	_maybe_dev_autoselect()


func _select_class(class_id: String) -> void:
	LobbyState.local_chosen_class_id = class_id
	get_tree().change_scene_to_file("res://ui/host_join/HostJoin.tscn")


## Headless dev testing hook -- there is no mouse/keyboard to click a
## real button in this environment, so a --dev-class=<id> arg drives
## the exact same _select_class() handler a click would call. See
## memory/verify.md's Phase 7 section for how this is used in the live
## 2-process test.
func _maybe_dev_autoselect() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dev-class="):
			_select_class(arg.trim_prefix("--dev-class="))
