extends GutTest
## The "/" command syntax and console open/close lifecycle for
## NetworkStatsOverlay's debug console. Pattern inherited from
## amazing-nauts' tests/unit/test_network_stats_overlay_console.gd.

const OVERLAY_SCENE := preload("res://maps/test_arena/TestArena.tscn")


func _key_press(physical_keycode: int, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	event.pressed = true
	event.device = -1
	event.echo = echo
	return event


func _toggle_press(echo: bool = false) -> InputEventKey:
	return _key_press(KEY_SLASH, echo)


func test_parse_command_strips_a_single_leading_slash() -> void:
	var overlay := _console_overlay()
	var parsed: Dictionary = overlay.parse_command("/latency 50")
	assert_eq(parsed["command"], "latency")
	assert_eq(parsed["args"], ["50"])


func test_parse_command_without_a_leading_slash_still_works() -> void:
	var overlay := _console_overlay()
	var parsed: Dictionary = overlay.parse_command("help")
	assert_eq(parsed["command"], "help")
	assert_eq(parsed["args"], [])


func test_parse_command_blank_input_yields_empty_command() -> void:
	var overlay := _console_overlay()
	var parsed: Dictionary = overlay.parse_command("   ")
	assert_eq(parsed["command"], "")
	assert_eq(parsed["args"], [])


func test_slash_key_opens_the_console() -> void:
	var overlay := _console_overlay()
	overlay._input(_toggle_press())
	assert_true(overlay._console_input.visible)


func test_a_key_repeat_echo_does_not_re_toggle_the_console() -> void:
	var overlay := _console_overlay()
	overlay._input(_toggle_press())
	assert_true(overlay._console_input.visible, "the real press should open the console")
	overlay._input(_toggle_press(true))
	assert_true(
		overlay._console_input.visible,
		"an OS key-repeat of the same toggle key must not flip it back closed"
	)


func test_pressing_slash_again_while_open_does_not_close_it() -> void:
	var overlay := _console_overlay()
	overlay._input(_toggle_press())
	assert_true(overlay._console_input.visible, "test setup: console should be open")
	overlay._input(_toggle_press())
	assert_true(
		overlay._console_input.visible, "a second '/' while open must not close the console"
	)


func test_escape_closes_the_console_without_executing() -> void:
	var overlay := _console_overlay()
	overlay._input(_toggle_press())
	overlay._console_output.text = ""
	overlay._input(_key_press(KEY_ESCAPE))
	assert_false(overlay._console_input.visible, "Escape should close the console")
	assert_eq(
		overlay._console_output.text, "", "Escape must not run whatever was typed as a command"
	)


func test_latency_command_updates_network_manager() -> void:
	var overlay := _console_overlay()
	overlay._execute_command("/latency 75")
	assert_eq(NetworkManager.artificial_latency_ms, 75)
	NetworkManager.artificial_latency_ms = 0  # NetworkManager is a shared autoload; don't leak state


func _console_overlay() -> Node:
	var arena: Node = add_child_autofree(OVERLAY_SCENE.instantiate())
	return arena.get_node("NetworkStatsOverlay")
