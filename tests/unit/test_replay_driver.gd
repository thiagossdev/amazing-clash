extends GutTest
## ReplayDriver: offline reconstruction of a net/replay_recorder.gd
## `.replay` file (Phase 20, memory/plan.md's roadmap item 20). Pure
## parsing/casting is unit-tested directly; load/seek/playback bookkeeping
## uses a real scratch file written by each test (small enough to be
## cheap, and exercises the actual FileAccess read path, not a mock).

const TEST_REPLAY_DIR := "user://test_replay_driver"


func after_each() -> void:
	var dir := DirAccess.open(TEST_REPLAY_DIR)
	if dir:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(TEST_REPLAY_DIR)


func _write_replay(filename: String, lines: Array) -> String:
	DirAccess.make_dir_recursive_absolute(TEST_REPLAY_DIR)
	var path := "%s/%s" % [TEST_REPLAY_DIR, filename]
	var file := FileAccess.open(path, FileAccess.WRITE)
	for line in lines:
		file.store_line(JSON.stringify(line))
	file.close()
	return path


func _driver_with_characters() -> ReplayDriver:
	var driver: ReplayDriver = autofree(ReplayDriver.new())
	var characters: Node2D = autofree(Node2D.new())
	characters.name = "Characters"
	add_child_autofree(characters)
	add_child_autofree(driver)
	driver.characters_path = characters.get_path()
	return driver


## --- parse_line(): pure, JSON float/int-casting round-trips ---


func test_parse_line_header_casts_every_numeric_field_to_int() -> void:
	var raw := (
		JSON
		. stringify(
			{
				"type": "header",
				"mode": 0,
				"friendly_fire": true,
				"round_target": 2,
				"sim_seed": 12345,
				"loadouts":
				[
					{
						"peer_id": 1,
						"class": "vanguard",
						"team": 0,
						"weapon": "iron_sword",
						"boot": "swift_boots",
						"perk": "vitality"
					}
				],
			}
		)
	)
	var record := ReplayDriver.parse_line(raw)
	assert_eq(record["type"], "header")
	assert_typeof(record["mode"], TYPE_INT)
	assert_typeof(record["round_target"], TYPE_INT)
	assert_typeof(record["sim_seed"], TYPE_INT)
	assert_eq(record["round_target"], 2)
	assert_eq(record["loadouts"][0]["peer_id"], 1)
	assert_typeof(record["loadouts"][0]["peer_id"], TYPE_INT)


func test_parse_line_tick_casts_tick_number_and_nested_peer_id_to_int() -> void:
	var raw := (
		JSON
		. stringify(
			{
				"type": "tick",
				"tick": 555,
				"samples": [{"peer_id": 7, "sample": {"sequence": 3, "dash_pressed": true}}],
			}
		)
	)
	var record := ReplayDriver.parse_line(raw)
	assert_eq(record["type"], "tick")
	assert_typeof(record["tick"], TYPE_INT)
	assert_eq(record["tick"], 555)
	assert_typeof(record["samples"][0]["peer_id"], TYPE_INT)
	assert_eq(record["samples"][0]["peer_id"], 7)


func test_parse_line_round_end_and_match_end_cast_round_wins_values_to_int() -> void:
	var round_end := (
		ReplayDriver
		. parse_line(
			(
				JSON
				. stringify(
					{
						"type": "round_end",
						"completed_round": 1,
						"winner": 0,
						"is_draw": false,
						"round_wins": {"0": 1, "1": 0},
					}
				)
			)
		)
	)
	assert_eq(round_end["type"], "round_end")
	assert_typeof(round_end["round_wins"][0], TYPE_INT)

	var match_end := ReplayDriver.parse_line(
		JSON.stringify({"type": "match_end", "winner": 0, "round_wins": {"0": 2, "1": 1}})
	)
	assert_eq(match_end["type"], "match_end")
	assert_eq(match_end["winner"], 0)


func test_parse_line_loadout_change_keeps_string_fields_as_strings() -> void:
	var record := ReplayDriver.parse_line(
		JSON.stringify(
			{"type": "loadout_change", "peer_id": 2, "weapon": "warhammer", "boot": "", "perk": ""}
		)
	)
	assert_eq(record["type"], "loadout_change")
	assert_typeof(record["peer_id"], TYPE_INT)
	assert_eq(record["weapon"], "warhammer")


func test_parse_line_unknown_type_returns_empty_dict() -> void:
	assert_eq(ReplayDriver.parse_line(JSON.stringify({"type": "something_new"})), {})


func test_parse_line_malformed_json_returns_empty_dict() -> void:
	assert_eq(ReplayDriver.parse_line("not json at all"), {})


## --- sample_from_dict(): inverse of ReplayRecorder.sample_to_dict() ---


func test_sample_from_dict_round_trips_through_replay_recorders_own_sample_to_dict() -> void:
	var original := InputBuffer.Sample.new()
	original.sequence = 42
	original.move_vector = Vector2(0.5, -0.5)
	original.dash_pressed = true
	original.attack_pressed = false
	original.aim_direction = Vector2(-1.0, 0.0)
	original.ability_r_pressed = true
	original.boot_active_pressed = true
	original.delta = 0.01667

	# Round-trip through JSON.stringify/parse_string, same as a real file.
	var as_json = JSON.parse_string(JSON.stringify(ReplayRecorder.sample_to_dict(original)))
	var restored := ReplayDriver.sample_from_dict(as_json)

	assert_typeof(restored.sequence, TYPE_INT)
	assert_eq(restored.sequence, 42)
	assert_eq(restored.move_vector, Vector2(0.5, -0.5))
	assert_true(restored.dash_pressed)
	assert_false(restored.attack_pressed)
	assert_eq(restored.aim_direction, Vector2(-1.0, 0.0))
	assert_true(restored.ability_r_pressed)
	assert_true(restored.boot_active_pressed)
	assert_almost_eq(restored.delta, 0.01667, 0.0001)


## --- load_replay() / total_ticks() / seek math ---


func test_load_replay_returns_false_for_a_missing_file() -> void:
	var driver := _driver_with_characters()
	assert_false(driver.load_replay("user://this_file_does_not_exist.replay"))
	assert_ne(driver.load_error(), "")


func test_load_replay_returns_false_when_the_first_line_is_not_a_header() -> void:
	var path := _write_replay("no_header.replay", [{"type": "tick", "tick": 1, "samples": []}])
	var driver := _driver_with_characters()
	assert_false(driver.load_replay(path))


func _sample_dict(sequence: int) -> Dictionary:
	var sample := InputBuffer.Sample.new()
	sample.sequence = sequence
	sample.delta = 1.0 / 60.0
	return ReplayRecorder.sample_to_dict(sample)


func test_load_replay_counts_only_tick_records_as_total_ticks() -> void:
	var path := _write_replay(
		"counts.replay",
		[
			{
				"type": "header",
				"mode": 0,
				"friendly_fire": false,
				"round_target": 2,
				"sim_seed": 1,
				"loadouts":
				[
					{
						"peer_id": 1,
						"class": "vanguard",
						"team": 0,
						"weapon": "iron_sword",
						"boot": "swift_boots",
						"perk": "vitality"
					}
				],
			},
			{"type": "tick", "tick": 100, "samples": [{"peer_id": 1, "sample": _sample_dict(1)}]},
			{"type": "tick", "tick": 101, "samples": [{"peer_id": 1, "sample": _sample_dict(2)}]},
			{
				"type": "round_end",
				"completed_round": 1,
				"winner": 0,
				"is_draw": false,
				"round_wins": {"0": 1}
			},
			{"type": "tick", "tick": 200, "samples": [{"peer_id": 1, "sample": _sample_dict(3)}]},
			{"type": "match_end", "winner": 0, "round_wins": {"0": 1}},
		]
	)
	var driver := _driver_with_characters()
	assert_true(driver.load_replay(path))
	assert_eq(driver.total_ticks(), 3, "round_end/match_end/header must not count as ticks")


func test_seek_to_frame_zero_after_playing_resets_ticks_processed() -> void:
	var path := _write_replay(
		"seek.replay",
		[
			{
				"type": "header",
				"mode": 0,
				"friendly_fire": false,
				"round_target": 2,
				"sim_seed": 1,
				"loadouts":
				[
					{
						"peer_id": 1,
						"class": "vanguard",
						"team": 0,
						"weapon": "iron_sword",
						"boot": "swift_boots",
						"perk": "vitality"
					}
				],
			},
			{"type": "tick", "tick": 10, "samples": [{"peer_id": 1, "sample": _sample_dict(1)}]},
			{"type": "tick", "tick": 11, "samples": [{"peer_id": 1, "sample": _sample_dict(2)}]},
			{"type": "tick", "tick": 12, "samples": [{"peer_id": 1, "sample": _sample_dict(3)}]},
		]
	)
	var driver := _driver_with_characters()
	driver.load_replay(path)
	driver.seek_to_frame(2)
	assert_eq(driver.ticks_processed(), 2)
	driver.seek_to_frame(0)
	assert_eq(driver.ticks_processed(), 0, "seeking back to 0 must re-simulate from scratch")


func test_seek_to_frame_clamps_past_the_end_and_marks_finished() -> void:
	var path := _write_replay(
		"clamp.replay",
		[
			{
				"type": "header",
				"mode": 0,
				"friendly_fire": false,
				"round_target": 2,
				"sim_seed": 1,
				"loadouts":
				[
					{
						"peer_id": 1,
						"class": "vanguard",
						"team": 0,
						"weapon": "iron_sword",
						"boot": "swift_boots",
						"perk": "vitality"
					}
				],
			},
			{"type": "tick", "tick": 10, "samples": [{"peer_id": 1, "sample": _sample_dict(1)}]},
			{"type": "match_end", "winner": 0, "round_wins": {"0": 2}},
		]
	)
	var driver := _driver_with_characters()
	driver.load_replay(path)
	driver.seek_to_frame(999)
	assert_eq(driver.ticks_processed(), 1)
	assert_true(driver.is_finished())
	assert_eq(driver.final_winner(), 0)


func test_round_end_advances_current_round_and_updates_round_wins() -> void:
	var path := _write_replay(
		"rounds.replay",
		[
			{
				"type": "header",
				"mode": 0,
				"friendly_fire": false,
				"round_target": 2,
				"sim_seed": 1,
				"loadouts":
				[
					{
						"peer_id": 1,
						"class": "vanguard",
						"team": 0,
						"weapon": "iron_sword",
						"boot": "swift_boots",
						"perk": "vitality"
					}
				],
			},
			{"type": "tick", "tick": 10, "samples": [{"peer_id": 1, "sample": _sample_dict(1)}]},
			{
				"type": "round_end",
				"completed_round": 1,
				"winner": 0,
				"is_draw": false,
				"round_wins": {"0": 1, "1": 0}
			},
			{"type": "tick", "tick": 20, "samples": [{"peer_id": 1, "sample": _sample_dict(2)}]},
		]
	)
	var driver := _driver_with_characters()
	driver.load_replay(path)
	assert_eq(driver.current_round(), 1)
	driver.seek_to_frame(2)
	assert_eq(driver.current_round(), 2)
	assert_eq(driver.round_wins()[0], 1)


func test_play_is_a_noop_once_finished() -> void:
	var path := _write_replay(
		"finished.replay",
		[
			{
				"type": "header",
				"mode": 0,
				"friendly_fire": false,
				"round_target": 2,
				"sim_seed": 1,
				"loadouts":
				[
					{
						"peer_id": 1,
						"class": "vanguard",
						"team": 0,
						"weapon": "iron_sword",
						"boot": "swift_boots",
						"perk": "vitality"
					}
				],
			},
			{"type": "match_end", "winner": -1, "round_wins": {}},
		]
	)
	var driver := _driver_with_characters()
	driver.load_replay(path)
	driver.seek_to_frame(0)
	assert_true(driver.is_finished())
	driver.play()
	assert_false(driver.is_playing(), "a finished replay must not be playable again")
