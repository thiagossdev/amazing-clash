extends GutTest
## ReplayRecorder: server-only structured replay recording (Phase 19,
## memory/plan.md's roadmap item 19). Pure sample serialization is
## unit-tested directly; the write path (file I/O, server-only gate,
## tick batching) uses a scratch user://test_replay_recorder/
## directory via reset_for_testing(), mirroring test_game_log.gd's own
## established pattern exactly.

const TEST_REPLAY_DIR := "user://test_replay_recorder"


func before_each() -> void:
	ReplayRecorder.reset_for_testing(TEST_REPLAY_DIR)


func after_each() -> void:
	var dir := DirAccess.open(TEST_REPLAY_DIR)
	if not dir:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)
	ReplayRecorder.reset_for_testing()
	DirAccess.remove_absolute(TEST_REPLAY_DIR)


func _read_all_lines(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	var lines := []
	while not file.eof_reached():
		var line := file.get_line()
		if not line.is_empty():
			lines.append(JSON.parse_string(line))
	file.close()
	return lines


func test_sample_to_dict_converts_vectors_to_arrays_and_keeps_every_field() -> void:
	var sample := InputBuffer.Sample.new()
	sample.sequence = 42
	sample.move_vector = Vector2(1.0, -1.0)
	sample.dash_pressed = true
	sample.attack_pressed = true
	sample.aim_direction = Vector2(0.5, 0.5)
	sample.skillshot_pressed = true
	sample.ability_q_pressed = true
	sample.ability_e_pressed = true
	sample.ability_r_pressed = true
	sample.ability_f_pressed = true
	sample.boot_active_pressed = true
	sample.delta = 0.016666

	var dict := ReplayRecorder.sample_to_dict(sample)

	assert_eq(dict["sequence"], 42)
	assert_eq(dict["move_vector"], [1.0, -1.0])
	assert_eq(dict["dash_pressed"], true)
	assert_eq(dict["attack_pressed"], true)
	assert_eq(dict["aim_direction"], [0.5, 0.5])
	assert_eq(dict["skillshot_pressed"], true)
	assert_eq(dict["ability_q_pressed"], true)
	assert_eq(dict["ability_e_pressed"], true)
	assert_eq(dict["ability_r_pressed"], true)
	assert_eq(dict["ability_f_pressed"], true)
	assert_eq(dict["boot_active_pressed"], true)
	assert_almost_eq(dict["delta"], 0.016666, 0.00001)


func test_start_recording_is_a_noop_when_not_server() -> void:
	var original_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = null
	ReplayRecorder.start_recording("TEAM", true, 2, [])
	assert_eq(ReplayRecorder.current_replay_path(), "", "no file should ever have been opened")
	multiplayer.multiplayer_peer = original_peer


func test_start_recording_writes_a_header_line() -> void:
	var loadouts := [{"peer_id": 1, "class": "vanguard", "weapon": "iron_sword"}]
	ReplayRecorder.start_recording("TEAM", true, 2, loadouts)
	var path := ReplayRecorder.current_replay_path()
	assert_ne(path, "", "a replay file should have been opened")
	var lines := _read_all_lines(path)
	assert_eq(lines.size(), 1)
	assert_eq(lines[0]["type"], "header")
	assert_eq(lines[0]["mode"], "TEAM")
	assert_eq(lines[0]["friendly_fire"], true)
	assert_eq(lines[0]["round_target"], 2)
	assert_true(lines[0].has("sim_seed"), "sim_seed must be reserved even though unused today")
	assert_eq(lines[0]["loadouts"][0]["class"], "vanguard")


func test_record_loadout_change_is_a_noop_before_start_recording() -> void:
	ReplayRecorder.record_loadout_change(1, "warhammer", "swift_boots", "vitality")
	assert_eq(ReplayRecorder.current_replay_path(), "", "nothing should have been written")


func test_record_loadout_change_writes_after_start_recording() -> void:
	ReplayRecorder.start_recording("TEAM", false, 2, [])
	ReplayRecorder.record_loadout_change(5, "twin_daggers", "tumbling_boots", "adept")
	var lines := _read_all_lines(ReplayRecorder.current_replay_path())
	assert_eq(lines.size(), 2, "header + 1 loadout_change")
	assert_eq(lines[1]["type"], "loadout_change")
	assert_eq(lines[1]["peer_id"], 5)
	assert_eq(lines[1]["weapon"], "twin_daggers")
	assert_eq(lines[1]["boot"], "tumbling_boots")
	assert_eq(lines[1]["perk"], "adept")


func test_tick_samples_for_the_same_tick_batch_into_one_record() -> void:
	ReplayRecorder.start_recording("TEAM", false, 2, [])
	var sample_a := InputBuffer.Sample.new()
	sample_a.sequence = 1
	var sample_b := InputBuffer.Sample.new()
	sample_b.sequence = 2
	ReplayRecorder.record_tick_sample(100, 1, sample_a)
	ReplayRecorder.record_tick_sample(100, 2, sample_b)
	# Not flushed yet -- still the same tick, nothing but the header on disk.
	var lines_before := _read_all_lines(ReplayRecorder.current_replay_path())
	assert_eq(lines_before.size(), 1, "tick 100 must not flush until a later tick starts")

	ReplayRecorder.record_tick_sample(101, 1, sample_a)
	var lines_after := _read_all_lines(ReplayRecorder.current_replay_path())
	assert_eq(lines_after.size(), 2, "header + the now-flushed tick 100 record")
	assert_eq(lines_after[1]["type"], "tick")
	assert_eq(lines_after[1]["tick"], 100)
	assert_eq(lines_after[1]["samples"].size(), 2, "both peers' samples for tick 100")


func test_record_match_end_flushes_the_final_pending_tick() -> void:
	ReplayRecorder.start_recording("TEAM", false, 2, [])
	var sample := InputBuffer.Sample.new()
	ReplayRecorder.record_tick_sample(50, 1, sample)
	ReplayRecorder.record_match_end(0, {"0": 2})
	var lines := _read_all_lines(ReplayRecorder.current_replay_path())
	assert_eq(lines.size(), 3, "header + the final pending tick 50 + match_end")
	assert_eq(lines[1]["type"], "tick")
	assert_eq(lines[1]["tick"], 50)
	assert_eq(lines[2]["type"], "match_end")
	assert_eq(lines[2]["winner"], 0)


func test_record_round_end_writes_a_line() -> void:
	ReplayRecorder.start_recording("TEAM", false, 2, [])
	ReplayRecorder.record_round_end(1, 0, false, {"0": 1})
	var lines := _read_all_lines(ReplayRecorder.current_replay_path())
	assert_eq(lines.size(), 2)
	assert_eq(lines[1]["type"], "round_end")
	assert_eq(lines[1]["completed_round"], 1)
	assert_eq(lines[1]["winner"], 0)
	assert_eq(lines[1]["is_draw"], false)


func test_record_match_end_stops_recording_further_calls() -> void:
	ReplayRecorder.start_recording("TEAM", false, 2, [])
	ReplayRecorder.record_match_end(0, {})
	var path_after_end := ReplayRecorder.current_replay_path()
	ReplayRecorder.record_round_end(2, 0, false, {})
	var lines := _read_all_lines(path_after_end)
	for line in lines:
		assert_ne(line["type"], "round_end", "no record should land after match_end")


func test_reset_for_testing_starts_a_fresh_file() -> void:
	ReplayRecorder.start_recording("TEAM", false, 2, [])
	var first_path := ReplayRecorder.current_replay_path()
	ReplayRecorder.reset_for_testing(TEST_REPLAY_DIR)
	ReplayRecorder.start_recording("TEAM", false, 2, [])
	assert_ne(ReplayRecorder.current_replay_path(), first_path, "reset must open a distinct file")
