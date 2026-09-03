extends GutTest
## F1 toggle behavior for HitboxViewer. Pattern inherited from
## amazing-nauts' tests/unit/test_hitbox_viewer.gd equivalent.

const VIEWER_SCENE := preload("res://ui/debug/HitboxViewer.tscn")


func _f1_press(echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F1
	event.pressed = true
	event.device = -1
	event.echo = echo
	return event


func test_starts_hidden() -> void:
	var viewer: Node2D = add_child_autofree(VIEWER_SCENE.instantiate())
	assert_false(viewer.visible)


func test_f1_toggles_visibility() -> void:
	var viewer: Node2D = add_child_autofree(VIEWER_SCENE.instantiate())
	viewer._unhandled_input(_f1_press())
	assert_true(viewer.visible)
	viewer._unhandled_input(_f1_press())
	assert_false(viewer.visible)


func test_joins_the_hitbox_viewer_group() -> void:
	var viewer: Node2D = add_child_autofree(VIEWER_SCENE.instantiate())
	assert_true(viewer.is_in_group("hitbox_viewer"))
