class_name ArenaCamera
extends Camera2D
## Fixed top-down follow, no zoom/shake yet -- both out of scope for
## Phase 1. Pattern inherited from amazing-nauts' camera/combat_camera.gd.

@export var target: Node2D


## The locally owned CharacterController claims this camera as its target
## in character_controller.gd's _ready().
func _ready() -> void:
	add_to_group(&"local_camera")


func _process(_delta: float) -> void:
	if target:
		global_position = target.global_position
