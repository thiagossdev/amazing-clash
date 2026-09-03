extends GutTest
## Pure logic coverage for WinCondition.determine() -- MatchRules'
## Node-based orchestration (scene tree traversal, RPC broadcast) is
## verified tactilely instead, matching this project's own convention
## for CombatResolver/PlayerSpawner.


func test_no_result_before_both_teams_have_connected() -> void:
	assert_eq(WinCondition.determine(0, 0, false, false), WinCondition.NONE)
	assert_eq(WinCondition.determine(1, 0, true, false), WinCondition.NONE)
	assert_eq(WinCondition.determine(0, 1, false, true), WinCondition.NONE)


func test_team1_wins_when_team0_eliminated() -> void:
	assert_eq(WinCondition.determine(0, 2, true, true), 1)


func test_team0_wins_when_team1_eliminated() -> void:
	assert_eq(WinCondition.determine(2, 0, true, true), 0)


func test_draw_when_both_teams_simultaneously_eliminated() -> void:
	assert_eq(WinCondition.determine(0, 0, true, true), WinCondition.DRAW)


func test_no_result_while_both_teams_still_have_survivors() -> void:
	assert_eq(WinCondition.determine(1, 1, true, true), WinCondition.NONE)
	assert_eq(WinCondition.determine(2, 3, true, true), WinCondition.NONE)
