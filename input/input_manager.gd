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
