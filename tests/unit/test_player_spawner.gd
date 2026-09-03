extends GutTest
## Pure spawn-position computation (Phase 12): PlayerSpawner is a Node
## but these methods touch no scene tree, only the live MatchState
## autoload -- instantiated directly via .new(), same "pure logic gets
## a GUT test" convention as WinCondition/LobbyState. Team-mode tests
## save/restore MatchState.match_mode so a mutation here can't leak
## into any other test file sharing the same autoload instance.


func _spawner() -> PlayerSpawner:
	return autofree(PlayerSpawner.new())


func test_team_spawn_positions_are_distinct_within_a_team() -> void:
	var spawner := _spawner()
	var first := spawner._spawn_position_for(0)
	var second := spawner._spawn_position_for(0)
	var third := spawner._spawn_position_for(0)
	assert_ne(first.y, second.y, "teammates must not stack on the exact same y")
	assert_ne(second.y, third.y, "a 3rd teammate must not collide with the 2nd either")


func test_team_0_and_team_1_spawn_on_opposite_sides() -> void:
	var spawner := _spawner()
	var team0 := spawner._spawn_position_for(0)
	var team1 := spawner._spawn_position_for(1)
	assert_lt(team0.x, spawner.ARENA_CENTER.x, "team 0 clusters left of arena center")
	assert_gt(team1.x, spawner.ARENA_CENTER.x, "team 1 clusters right of arena center")


func test_ffa_mode_spawns_around_a_circle_not_stacked() -> void:
	var original_mode := MatchState.match_mode
	MatchState.match_mode = MatchState.MatchMode.FREE_FOR_ALL
	var spawner := _spawner()
	var positions: Array[Vector2] = [
		spawner._spawn_position_for(0),
		spawner._spawn_position_for(1),
		spawner._spawn_position_for(2)
	]
	MatchState.match_mode = original_mode
	for pos in positions:
		var distance_from_center := pos.distance_to(spawner.ARENA_CENTER)
		assert_almost_eq(
			distance_from_center,
			spawner.FFA_SPAWN_RADIUS,
			1.0,
			"every FFA spawn should sit on the same circle around the arena center"
		)
	assert_ne(positions[0], positions[1])
	assert_ne(positions[1], positions[2])


func test_ffa_cycles_after_max_slots_without_erroring() -> void:
	var original_mode := MatchState.match_mode
	MatchState.match_mode = MatchState.MatchMode.FREE_FOR_ALL
	var spawner := _spawner()
	var first_slot := spawner._spawn_position_for(0)
	var wrapped_slot := spawner._spawn_position_for(spawner.FFA_SPAWN_SLOTS)
	MatchState.match_mode = original_mode
	assert_eq(
		first_slot,
		wrapped_slot,
		"a 9th+ FFA player should cycle back to an existing slot, not error"
	)
