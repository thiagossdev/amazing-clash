extends GutTest
## GameLog: server-only JSONL match log (Phase 18, memory/plan.md's
## roadmap item 18). Pure line-formatting logic is unit-tested directly;
## the write path (file I/O, server-only gate) uses a scratch
## user://test_game_log/ directory via reset_for_testing() so tests
## never touch the real user://logs/ location. The RPC-free, no-peer
## default (multiplayer.has_multiplayer_peer() true, unique_id 1) means
## a bare test process already behaves like a server -- the "not
## server" case is tested by nulling multiplayer.multiplayer_peer,
## mirroring test_match_state.gd's own established pattern.

const TEST_LOG_DIR := "user://test_game_log"


func before_each() -> void:
	GameLog.reset_for_testing(TEST_LOG_DIR)


func after_each() -> void:
	var dir := DirAccess.open(TEST_LOG_DIR)
	if not dir:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)
	GameLog.reset_for_testing()
	DirAccess.remove_absolute(TEST_LOG_DIR)


func test_format_line_produces_valid_json_with_all_fields() -> void:
	var line := GameLog.format_line("info", "peer_connected", {"peer_id": 2}, "2026-09-04T10:00:00")
	var parsed: Dictionary = JSON.parse_string(line)
	assert_eq(parsed["level"], "info")
	assert_eq(parsed["event"], "peer_connected")
	# JSON has no int/float distinction -- JSON.parse_string() always
	# returns numbers as float, regardless of the source Dictionary's
	# own value type. Not a GameLog bug, just how Godot's parser works.
	assert_eq(parsed["data"], {"peer_id": 2.0})
	assert_eq(parsed["timestamp"], "2026-09-04T10:00:00")


func test_info_is_a_noop_when_not_server() -> void:
	var original_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = null
	GameLog.info("should_not_be_written")
	assert_eq(GameLog.current_log_path(), "", "no file should ever have been opened")
	multiplayer.multiplayer_peer = original_peer


func test_info_writes_a_line_to_disk_when_server() -> void:
	GameLog.info("peer_connected", {"peer_id": 7})
	var path := GameLog.current_log_path()
	assert_ne(path, "", "a log file should have been opened")
	var file := FileAccess.open(path, FileAccess.READ)
	var line := file.get_line()
	file.close()
	var parsed: Dictionary = JSON.parse_string(line)
	assert_eq(parsed["level"], "info")
	assert_eq(parsed["event"], "peer_connected")
	assert_eq(parsed["data"], {"peer_id": 7.0})


func test_warn_and_error_use_their_own_level() -> void:
	GameLog.warn("something_odd")
	GameLog.error("something_broke")
	var file := FileAccess.open(GameLog.current_log_path(), FileAccess.READ)
	var first: Dictionary = JSON.parse_string(file.get_line())
	var second: Dictionary = JSON.parse_string(file.get_line())
	file.close()
	assert_eq(first["level"], "warn")
	assert_eq(second["level"], "error")


func test_multiple_calls_append_to_the_same_file() -> void:
	GameLog.info("first")
	var path_after_first := GameLog.current_log_path()
	GameLog.info("second")
	assert_eq(
		GameLog.current_log_path(), path_after_first, "same file for the whole process lifetime"
	)
	var file := FileAccess.open(path_after_first, FileAccess.READ)
	var line_count := 0
	while not file.eof_reached():
		var line := file.get_line()
		if not line.is_empty():
			line_count += 1
	file.close()
	assert_eq(line_count, 2)


func test_reset_for_testing_starts_a_fresh_file() -> void:
	GameLog.info("before_reset")
	var first_path := GameLog.current_log_path()
	GameLog.reset_for_testing(TEST_LOG_DIR)
	GameLog.info("after_reset")
	assert_ne(GameLog.current_log_path(), first_path, "reset must open a distinct file")
