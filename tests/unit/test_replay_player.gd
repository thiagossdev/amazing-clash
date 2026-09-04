extends GutTest
## ReplayPlayer's camera control (Tab cycles through replayed
## characters, arrow keys decouple into a freely-moved camera, Tab
## re-couples) and playback speed (1/2/4/8x number keys), added
## 2026-09-04 per the human owner's own request. Synthetic key-event
## pattern inherited from tests/unit/test_network_stats_overlay_console.gd
## (this project's own established way to test physical_keycode-bound
## InputMap actions without a real keyboard).

const REPLAY_PLAYER_SCENE := preload("res://ui/replay/ReplayPlayer.tscn")


func _key_press(physical_keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	event.pressed = true
	event.device = -1
	return event


func _tab_press() -> InputEventKey:
	return _key_press(KEY_TAB)


func _speed_press(digit_keycode: int) -> InputEventKey:
	return _key_press(digit_keycode)


## No replay is loaded in these tests (no user://-path plumbing needed
## just to test camera/speed input handling), so _ready()'s own
## no-replay-selected early return never runs the initial _refresh_ui()
## a real session gets -- call it here instead, to establish a known
## "Cam: Free | Speed: 1x" baseline before each test's own key presses.
func _player_with_characters(count: int) -> Node2D:
	var player: Node2D = add_child_autofree(REPLAY_PLAYER_SCENE.instantiate())
	var characters := player.get_node("Characters")
	for i in count:
		var character := Node2D.new()
		character.name = str(i + 1)
		character.global_position = Vector2(100.0 * (i + 1), 0.0)
		characters.add_child(character)
	player._refresh_ui()
	return player


func _status_text(player: Node2D) -> String:
	return (player.get_node("Controls/StatusLabel") as Label).text


func test_starts_with_a_free_camera() -> void:
	var player := _player_with_characters(2)
	assert_true(_status_text(player).contains("Cam: Free"))


func test_tab_couples_the_camera_to_the_first_character() -> void:
	var player := _player_with_characters(2)
	player._input(_tab_press())
	assert_true(_status_text(player).contains("Cam: Player 1"))


func test_tab_again_cycles_to_the_next_character() -> void:
	var player := _player_with_characters(2)
	player._input(_tab_press())
	player._input(_tab_press())
	assert_true(_status_text(player).contains("Cam: Player 2"))


func test_tab_wraps_back_to_the_first_character() -> void:
	var player := _player_with_characters(2)
	player._input(_tab_press())
	player._input(_tab_press())
	player._input(_tab_press())
	assert_true(_status_text(player).contains("Cam: Player 1"))


func test_camera_follows_the_coupled_characters_position() -> void:
	var player := _player_with_characters(2)
	player._input(_tab_press())
	player._process(0.016)
	var camera: Camera2D = player.get_node("ArenaCamera")
	assert_eq(camera.global_position, Vector2(100.0, 0.0))


func test_an_arrow_key_decouples_the_camera() -> void:
	var player := _player_with_characters(2)
	player._input(_tab_press())
	assert_true(_status_text(player).contains("Cam: Player 1"))
	player._input(_key_press(KEY_LEFT))
	assert_true(_status_text(player).contains("Cam: Free"))


func test_tab_with_no_characters_is_a_safe_noop() -> void:
	var player := _player_with_characters(0)
	player._input(_tab_press())
	assert_true(_status_text(player).contains("Cam: Free"))


func test_speed_keys_set_the_drivers_playback_speed() -> void:
	var player := _player_with_characters(1)
	var driver: ReplayDriver = player.get_node("ReplayDriver")
	assert_eq(driver.playback_speed, 1, "default speed before any key press")
	player._input(_speed_press(KEY_3))
	assert_eq(driver.playback_speed, 4, "'3' is the 3rd tier: 1x/2x/4x/8x")
	assert_true(_status_text(player).contains("Speed: 4x"))
	player._input(_speed_press(KEY_1))
	assert_eq(driver.playback_speed, 1)
