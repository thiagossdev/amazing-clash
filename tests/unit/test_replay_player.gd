extends GutTest
## ReplayPlayer's camera control (Tab cycles through replayed
## characters, arrow keys decouple into a freely-moved camera, Tab
## re-couples) and playback speed (1/2/4/8x number keys), added
## 2026-09-04 per the human owner's own request. Synthetic key-event
## pattern inherited from tests/unit/test_network_stats_overlay_console.gd
## (this project's own established way to test physical_keycode-bound
## InputMap actions without a real keyboard).

const REPLAY_PLAYER_SCENE := preload("res://ui/replay/ReplayPlayer.tscn")
const TEST_REPLAY_DIR := "user://test_replay_player"


func after_each() -> void:
	var dir := DirAccess.open(TEST_REPLAY_DIR)
	if dir:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(TEST_REPLAY_DIR)
	# get_tree() is shared across every test in this run -- a leftover
	# meta key here would make a LATER test's own _player_with_characters()
	# (which relies on no replay being selected) silently try to load
	# this test's already-deleted scratch file instead.
	if get_tree().has_meta("replay_path_to_play"):
		get_tree().remove_meta("replay_path_to_play")


func _write_replay(filename: String, lines: Array) -> String:
	DirAccess.make_dir_recursive_absolute(TEST_REPLAY_DIR)
	var path := "%s/%s" % [TEST_REPLAY_DIR, filename]
	var file := FileAccess.open(path, FileAccess.WRITE)
	for line in lines:
		file.store_line(JSON.stringify(line))
	file.close()
	return path


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


## Human owner's own follow-up request: an obvious way back to the
## replay list once playback reaches the end. Loads a real 1-tick
## replay and seeks past its end (same technique test_replay_driver.gd's
## own test_seek_to_frame_clamps_past_the_end_and_marks_finished uses)
## rather than reaching into ReplayDriver's private _is_finished field.
func _finished_player() -> Node2D:
	var path := _write_replay(
		"finished.replay",
		[
			{
				"type": "header",
				"mode": 0,
				"friendly_fire": false,
				"round_target": 2,
				"sim_seed": 1,
				"loadouts": [],
			},
			{"type": "tick", "tick": 1, "samples": []},
			{"type": "match_end", "winner": 0, "round_wins": {"0": 2}},
		]
	)
	get_tree().set_meta("replay_path_to_play", path)
	# _ready() (the real one, wiring signals/buttons and calling
	# load_replay()) fires exactly once here, on entering the tree --
	# the meta must already be set before this, not after.
	var player: Node2D = add_child_autofree(REPLAY_PLAYER_SCENE.instantiate())
	var driver: ReplayDriver = player.get_node("ReplayDriver")
	# seek_to_frame()'s own state_changed emission drives _refresh_ui()
	# through the real signal connection _ready() just made -- no need
	# to call it again by hand.
	driver.seek_to_frame(999)
	return player


func test_play_pause_button_relabels_to_back_to_list_once_finished() -> void:
	var player := _finished_player()
	var button: Button = player.get_node("Controls/PlayPauseButton")
	assert_eq(button.text, "Back to List")


func test_play_pause_button_grabs_focus_once_finished() -> void:
	var player := _finished_player()
	var button: Button = player.get_node("Controls/PlayPauseButton")
	assert_true(button.has_focus())
