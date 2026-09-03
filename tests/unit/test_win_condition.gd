extends GutTest
## Pure logic coverage for WinCondition.determine() -- MatchRules'
## Node-based orchestration (scene tree traversal, RPC broadcast) is
## verified tactilely instead, matching this project's own convention
## for CombatResolver/PlayerSpawner. Covers both team mode (N=2) and
## free-for-all (N>2, one team per player) shapes.


func test_no_result_before_2_teams_have_connected() -> void:
	assert_eq(WinCondition.determine([], 0), WinCondition.NONE)
	assert_eq(WinCondition.determine([0], 1), WinCondition.NONE)


func test_team_mode_team1_wins_when_team0_eliminated() -> void:
	assert_eq(WinCondition.determine([1], 2), 1)


func test_team_mode_team0_wins_when_team1_eliminated() -> void:
	assert_eq(WinCondition.determine([0], 2), 0)


func test_team_mode_draw_when_both_teams_simultaneously_eliminated() -> void:
	assert_eq(WinCondition.determine([], 2), WinCondition.DRAW)


func test_team_mode_no_result_while_both_teams_still_have_survivors() -> void:
	assert_eq(WinCondition.determine([0, 1], 2), WinCondition.NONE)


func test_ffa_no_result_while_more_than_one_player_survives() -> void:
	assert_eq(WinCondition.determine([0, 1, 2, 3], 4), WinCondition.NONE)
	assert_eq(WinCondition.determine([2, 3], 4), WinCondition.NONE)


func test_ffa_last_surviving_player_wins() -> void:
	assert_eq(WinCondition.determine([2], 4), 2)


func test_ffa_draw_when_the_last_2_players_mutually_eliminate() -> void:
	assert_eq(WinCondition.determine([], 4), WinCondition.DRAW)
