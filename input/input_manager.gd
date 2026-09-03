extends Node
## Device-agnostic input abstraction. Gameplay code queries actions
## through here, never Input directly. See docs/blueprint/04-architecture
## conventions inherited from amazing-nauts.

var suppress_gameplay_input: bool = false


func is_action_just_pressed(action: StringName) -> bool:
	return false if suppress_gameplay_input else Input.is_action_just_pressed(action)


func get_axis(negative_action: StringName, positive_action: StringName) -> float:
	return 0.0 if suppress_gameplay_input else Input.get_axis(negative_action, positive_action)


func get_move_vector() -> Vector2:
	if suppress_gameplay_input:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## Direction from `character_position` to the mouse cursor's current
## world position, normalized. This is the skillshot's real mouse-aim
## (Phase 2b) -- unlike melee's LocomotionFsm.facing_direction (last
## movement direction), which is Phase 2a's simpler, unaimed swing.
## InputManager is a plain Node autoload, not a Node2D/CanvasItem, so it
## can't call get_global_mouse_position() directly -- the viewport's own
## canvas_transform (which already accounts for the active Camera2D) is
## used instead, the same transform CanvasItem.get_global_mouse_position()
## applies internally.
func get_aim_direction(character_position: Vector2) -> Vector2:
	if suppress_gameplay_input:
		return Vector2.RIGHT
	var viewport := get_viewport()
	if not viewport:
		return Vector2.RIGHT
	var mouse_world_position := (
		viewport.canvas_transform.affine_inverse() * viewport.get_mouse_position()
	)
	var to_mouse := mouse_world_position - character_position
	return to_mouse.normalized() if not to_mouse.is_zero_approx() else Vector2.RIGHT
