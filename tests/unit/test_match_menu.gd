extends GutTest
## ui/hud/match_menu.gd's ESC-toggle lifecycle (human owner's own
## 2026-09-04 request: "Implementar um menu in game, ao apertar ESC,
## com opção de abandonar a partida e voltar ao main menu"). Follows
## `tests/unit/test_network_stats_overlay_console.gd`'s own established
## pattern for testing an in-scene `_input()` consumer of `ui_cancel`:
## instantiate the full TestArena scene (DevBootstrap no-ops without
## cmdline args, already proven safe by that file's own tests), call
## `_input()` directly with a synthetic InputEventKey, assert on the
## resulting state. Does NOT exercise `_on_abandon_pressed()`'s full
## body -- calling `get_tree().change_scene_to_file()` from a test would
## trigger a real scene change and leak orphan nodes into the shared
## test SceneTree (this project's own established convention: verify
## the button is wired, not that a 1-line scene-navigation delegation
## actually navigates).

const TEST_ARENA_SCENE := preload("res://maps/test_arena/TestArena.tscn")


func after_each() -> void:
	InputManager.suppress_gameplay_input = false


func _menu() -> Node:
	var arena: Node = add_child_autofree(TEST_ARENA_SCENE.instantiate())
	return arena.get_node("MatchMenu")


func _escape_press() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	event.device = -1
	return event


func test_menu_starts_hidden() -> void:
	assert_false(_menu().visible)


func test_escape_opens_the_menu_and_suppresses_gameplay_input() -> void:
	var menu := _menu()
	menu._input(_escape_press())
	assert_true(menu.visible)
	assert_true(InputManager.suppress_gameplay_input)


func test_escape_again_closes_the_menu_and_restores_gameplay_input() -> void:
	var menu := _menu()
	menu._input(_escape_press())
	assert_true(menu.visible, "test setup: menu should be open")
	menu._input(_escape_press())
	assert_false(menu.visible)
	assert_false(InputManager.suppress_gameplay_input)


## The debug console (ui/hud/network_stats_overlay.gd) sets this same
## flag true while it's open -- this menu must not also pop open on top
## of it just because the player happens to press Escape while typing
## a console command.
func test_escape_does_not_open_while_gameplay_input_is_already_suppressed() -> void:
	var menu := _menu()
	InputManager.suppress_gameplay_input = true
	menu._input(_escape_press())
	assert_false(menu.visible)


func test_resume_button_closes_the_menu() -> void:
	var menu := _menu()
	menu._input(_escape_press())
	assert_true(menu.visible, "test setup: menu should be open")
	menu.get_node("ResumeButton").pressed.emit()
	assert_false(menu.visible)
	assert_false(InputManager.suppress_gameplay_input)


func test_abandon_button_is_wired() -> void:
	var menu := _menu()
	var abandon_button: Button = menu.get_node("AbandonMatchButton")
	assert_eq(abandon_button.pressed.get_connections().size(), 1)
