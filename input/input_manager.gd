extends Node
## Device-agnostic input abstraction. Gameplay code queries actions
## through here, never Input directly. See docs/blueprint/04-architecture
## conventions inherited from amazing-nauts.

var suppress_gameplay_input: bool = false


func is_action_just_pressed(action: StringName) -> bool:
	return false if suppress_gameplay_input else Input.is_action_just_pressed(action)


## Held state (not just the press edge) -- used for actions that should
## auto-repeat while the button stays down, gated only by their own
## cooldown/recovery (attack/skillshot/ability_q/ability_e via
## CharacterController.apply_input()'s existing can_start_move/
## cooldown checks, unchanged by this). Not used for dash, which stays
## edge-triggered (is_action_just_pressed) -- auto-repeating an evasive
## burst on hold is a separate balance question, not asked for here.
func is_action_pressed(action: StringName) -> bool:
	return false if suppress_gameplay_input else Input.is_action_pressed(action)


func get_axis(negative_action: StringName, positive_action: StringName) -> float:
	return 0.0 if suppress_gameplay_input else Input.get_axis(negative_action, positive_action)


func get_move_vector() -> Vector2:
	if suppress_gameplay_input:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## Direction from `character_position` to the mouse cursor's current
## world position, normalized. Sampled every tick into every
## InputBuffer.Sample regardless of action (see
## CharacterController._sample_local_input()), so it's the shared real-
## mouse-aim source for the skillshot, both ability slots, and melee
## alike (CharacterController.current_aim_direction) -- aim is always
## independent of movement, never derived from it.
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
