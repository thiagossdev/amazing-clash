extends GutTest
## Pure logic coverage for MatchState's Phase 17 round-tracking
## additions -- the Node-based countdown/RPC-broadcast machinery
## (mirrors net/lobby_state.gd's own ready-countdown) is verified
## tactilely instead, matching this project's established convention
## (see test_lobby_state.gd's own doc comment).

const MatchStateScript := preload("res://core/match_state.gd")


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
