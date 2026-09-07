extends GutTest
## Pure logic coverage for MatchState's Phase 17 round-tracking
## additions -- the Node-based countdown/RPC-broadcast machinery
## (mirrors net/lobby_state.gd's own ready-countdown) is verified
## tactilely instead, matching this project's established convention
## (see test_lobby_state.gd's own doc comment).

const MatchStateScript := preload("res://core/match_state.gd")
const LobbyStateScript := preload("res://net/lobby_state.gd")

## Phase 18: resolve_round_result() now calls GameLog.info() -- point
## every test in this file at a scratch dir so none of them ever touch
## the real user://logs/ location, even the ones below that don't
## themselves assert on log content.
const GAME_LOG_TEST_DIR := "user://test_game_log_match_state"
## Phase 19: resolve_round_result()/enter_post_game() now also call
## ReplayRecorder.record_round_end()/record_match_end() -- same
## scratch-dir isolation reasoning as GAME_LOG_TEST_DIR above.
const REPLAY_TEST_DIR := "user://test_replay_match_state"


func before_each() -> void:
	GameLog.reset_for_testing(GAME_LOG_TEST_DIR)
	ReplayRecorder.reset_for_testing(REPLAY_TEST_DIR)


func after_each() -> void:
	var dir := DirAccess.open(GAME_LOG_TEST_DIR)
	if dir:
		for file_name in dir.get_files():
			dir.remove(file_name)
	GameLog.reset_for_testing()
	DirAccess.remove_absolute(GAME_LOG_TEST_DIR)
	var replay_dir := DirAccess.open(REPLAY_TEST_DIR)
	if replay_dir:
		for file_name in replay_dir.get_files():
			replay_dir.remove(file_name)
	ReplayRecorder.reset_for_testing()
	DirAccess.remove_absolute(REPLAY_TEST_DIR)


func test_decide_round_outcome_draw_does_not_change_wins() -> void:
	var outcome := MatchState.decide_round_outcome(WinCondition.DRAW, {0: 1, 1: 0})
	assert_true(outcome["is_draw"])
	assert_false(outcome["is_match_end"])
	assert_eq(outcome["winner"], WinCondition.DRAW)
	assert_eq(outcome["wins"], {0: 1, 1: 0})


func test_decide_round_outcome_decisive_round_increments_winner() -> void:
	var outcome := MatchState.decide_round_outcome(0, {0: 0, 1: 0})
	assert_false(outcome["is_draw"])
	assert_eq(outcome["winner"], 0)
	assert_eq(outcome["wins"], {0: 1, 1: 0})


func test_decide_round_outcome_below_target_is_not_match_end() -> void:
	var outcome := MatchState.decide_round_outcome(0, {0: 0, 1: 1})
	assert_false(outcome["is_match_end"], "1 round win is below ROUND_TARGET (2)")


func test_decide_round_outcome_reaching_target_is_match_end() -> void:
	var outcome := MatchState.decide_round_outcome(0, {0: 1, 1: 1})
	assert_true(outcome["is_match_end"], "2nd round win reaches ROUND_TARGET (2)")
	assert_eq(outcome["wins"], {0: 2, 1: 1})


func test_decide_round_outcome_never_mutates_the_input_dictionary() -> void:
	var original := {0: 1, 1: 0}
	MatchState.decide_round_outcome(0, original)
	assert_eq(original, {0: 1, 1: 0}, "caller's own round_wins dict must not be mutated in place")


## all_loadout_confirmed() touches Node.multiplayer, which only
## resolves once a node is actually inside the SceneTree (nil
## otherwise) -- add_child_autofree() gives this instance a real,
## isolated-from-the-real-autoload place in the tree while still
## sharing the same default SceneMultiplayer every other node
## (including the real MatchState autoload) resolves to, matching
## test_network_stats_overlay_console.gd's own established pattern for
## a similar off-autoload multiplayer-touching test subject.
func test_all_loadout_confirmed_false_with_no_multiplayer_peer() -> void:
	var ms: Node = add_child_autofree(MatchStateScript.new())
	var original_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = null
	assert_false(ms.all_loadout_confirmed())
	multiplayer.multiplayer_peer = original_peer


func test_all_loadout_confirmed_false_when_local_peer_has_not_confirmed() -> void:
	var ms: Node = add_child_autofree(MatchStateScript.new())
	assert_false(ms.all_loadout_confirmed())


func test_all_loadout_confirmed_true_once_local_peer_confirms_with_no_remote_peers() -> void:
	var ms: Node = add_child_autofree(MatchStateScript.new())
	ms.player_loadout_confirmed[multiplayer.get_unique_id()] = true
	assert_true(ms.all_loadout_confirmed())


func test_is_early_confirm_true_below_the_threshold() -> void:
	var ms := MatchStateScript.new()
	assert_true(ms.is_early_confirm(5.0))
	ms.free()


func test_is_early_confirm_false_at_or_above_the_threshold() -> void:
	var ms := MatchStateScript.new()
	assert_false(ms.is_early_confirm(13.0))
	assert_false(ms.is_early_confirm(14.5))
	ms.free()


## Phase 18: a fresh instance, not the real MatchState autoload -- same
## isolation reasoning every other test above already uses, so this
## never touches shared singleton state other tests (in this file or
## elsewhere) might depend on.
func test_resolve_round_result_decisive_non_final_round_logs_round_ended() -> void:
	var ms: Node = add_child_autofree(MatchStateScript.new())
	ms.current_phase = MatchStateScript.Phase.IN_PROGRESS
	ms.resolve_round_result(0)
	var events := _logged_events()
	assert_true(events.has("round_ended"))
	assert_false(events.has("match_ended"), "1 round win is below ROUND_TARGET (2)")


func test_resolve_round_result_reaching_round_target_logs_match_ended() -> void:
	var ms: Node = add_child_autofree(MatchStateScript.new())
	ms.current_phase = MatchStateScript.Phase.IN_PROGRESS
	ms.round_wins = {0: 1}
	ms.resolve_round_result(0)
	assert_true(_logged_events().has("match_ended"))


func _logged_events() -> Array:
	var events: Array = []
	var file := FileAccess.open(GameLog.current_log_path(), FileAccess.READ)
	while not file.eof_reached():
		var line := file.get_line()
		if not line.is_empty():
			events.append((JSON.parse_string(line) as Dictionary)["event"])
	file.close()
	return events


## Phase 19: a fresh instance, not the real MatchState autoload -- same
## isolation reasoning every test above already uses.
func test_resolve_round_result_records_round_end_for_a_decisive_non_final_round() -> void:
	ReplayRecorder.start_recording(MatchStateScript.MatchMode.TEAM, false, 2, [])
	var ms: Node = add_child_autofree(MatchStateScript.new())
	ms.current_phase = MatchStateScript.Phase.IN_PROGRESS
	ms.resolve_round_result(0)
	var types := _replay_record_types()
	assert_true(types.has("round_end"))
	assert_false(types.has("match_end"), "1 round win is below ROUND_TARGET (2)")


## Even the match-ending round gets its own round_end record (in
## addition to match_end) -- resolve_round_result() records it BEFORE
## branching on is_match_end, unlike GameLog's own "round_ended" event
## above, which only ever fires on the non-final branch.
func test_resolve_round_result_records_both_round_end_and_match_end_at_round_target() -> void:
	ReplayRecorder.start_recording(MatchStateScript.MatchMode.TEAM, false, 2, [])
	var ms: Node = add_child_autofree(MatchStateScript.new())
	ms.current_phase = MatchStateScript.Phase.IN_PROGRESS
	ms.round_wins = {0: 1}
	ms.resolve_round_result(0)
	var types := _replay_record_types()
	assert_true(types.has("round_end"))
	assert_true(types.has("match_end"))


func _replay_record_types() -> Array:
	var types: Array = []
	var file := FileAccess.open(ReplayRecorder.current_replay_path(), FileAccess.READ)
	while not file.eof_reached():
		var line := file.get_line()
		if not line.is_empty():
			types.append((JSON.parse_string(line) as Dictionary)["type"])
	file.close()
	return types


## Found live 2026-09-04 (human owner: "depois que abandonei uma
## partida não consegui criar outras partidas" / "dou ready e o
## countdown não inicia"): nothing ever reset current_phase back to
## LOBBY once a match reached IN_PROGRESS/ROUND_INTERMISSION/POST_GAME,
## so net/lobby_state.gd's own _recompute_countdown() -- which
## deliberately refuses to start a countdown while current_phase !=
## Phase.LOBBY -- silently blocked every Ready press in a freshly
## re-hosted/joined room. reset_for_new_room() is the fix; this locks
## in every field it must clear.
func test_reset_for_new_room_clears_every_previous_matchs_state() -> void:
	var ms: Node = add_child_autofree(MatchStateScript.new())
	ms.current_phase = MatchStateScript.Phase.ROUND_INTERMISSION
	ms.round_wins = {0: 1, 1: 1}
	ms.current_round = 2
	ms.player_loadout_confirmed = {1: true}
	ms.intermission_seconds_remaining = 3.0
	ms.team_alive_counts = [2, 1] as Array[int]
	ms.winning_team = 0
	ms.players_in_grace_period = 1
	ms._loaded_peer_ids = {1: true}
	ms._intermission_generation = 5
	ms.reset_for_new_room()
	assert_eq(ms.current_phase, MatchStateScript.Phase.LOBBY)
	assert_true(ms.round_wins.is_empty())
	assert_eq(ms.current_round, 1)
	assert_true(ms.player_loadout_confirmed.is_empty())
	assert_eq(ms.intermission_seconds_remaining, -1.0)
	assert_true(ms.team_alive_counts.is_empty())
	assert_eq(ms.winning_team, -1)
	assert_eq(ms.players_in_grace_period, 0)
	assert_true(ms._loaded_peer_ids.is_empty())
	assert_eq(ms._intermission_generation, 0)


## The actual reported symptom, reproduced directly against the real
## guard (net/lobby_state.gd's own _countdown_still_valid(), the same
## check test_lobby_state.gd's test_countdown_still_valid_false_once_
## the_match_has_left_lobby() locks in the OTHER direction for): a
## stale IN_PROGRESS phase (as if a previous match was abandoned/
## finished without a full app restart) made this false for every
## room, forever, until reset_for_new_room() ran.
func test_reset_for_new_room_unblocks_countdown_still_valid() -> void:
	var lobby := LobbyStateScript.new()
	lobby.player_class_ids[1] = "vanguard"
	lobby.player_ready[1] = true
	var original_phase := MatchState.current_phase
	MatchState.current_phase = MatchState.Phase.IN_PROGRESS
	assert_false(
		lobby._countdown_still_valid(0), "test setup: a stale non-LOBBY phase blocks the countdown"
	)
	MatchState.reset_for_new_room()
	assert_true(lobby._countdown_still_valid(0))
	MatchState.current_phase = original_phase
	lobby.free()
