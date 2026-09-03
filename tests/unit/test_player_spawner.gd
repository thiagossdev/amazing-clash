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


## Phase 13a (grace-period freeze). PlayerSpawner._ready() reaches
## get_node(characters_path) whenever NetworkManager.is_server() reads
## true in this test run's own SceneTree (observed live -- a bare
## offline SceneTree defaults to server-like), which would error on a
## missing "../Characters" sibling and, worse, could auto-spawn into
## `characters` if some earlier test left MatchState.current_phase at
## IN_PROGRESS. _spawner_and_characters() below builds the real
## sibling shape _ready() expects and pins the phase to LOBBY (saved/
## restored) so these tests stay isolated regardless of suite order --
## same isolation discipline test_lobby_state.gd's own live-singleton
## tests already established.
func _spawner_and_characters() -> Array:
	var original_phase := MatchState.current_phase
	MatchState.current_phase = MatchState.Phase.LOBBY
	var root: Node = add_child_autofree(Node.new())
	var characters := Node.new()
	characters.name = "Characters"
	root.add_child(characters)
	var spawner := PlayerSpawner.new()
	spawner.characters_path = ^"../Characters"
	root.add_child(spawner)
	MatchState.current_phase = original_phase
	return [spawner, characters]


func test_begin_grace_period_tracks_the_disconnecting_peer() -> void:
	var spawner_and_characters := _spawner_and_characters()
	var spawner: PlayerSpawner = spawner_and_characters[0]
	var characters: Node = spawner_and_characters[1]
	var character := Node2D.new()
	character.name = "555"
	characters.add_child(character)
	spawner._begin_grace_period(555, characters)
	assert_true(spawner._grace_timers.has(555))


func test_begin_grace_period_is_a_noop_if_the_character_is_already_gone() -> void:
	# No get_tree() dependency here -- the early return (no matching
	# character) happens before _begin_grace_period ever calls
	# create_timer(), so a plain .new() without add_child is enough.
	var spawner: PlayerSpawner = autofree(PlayerSpawner.new())
	var characters: Node = autofree(Node.new())
	spawner._begin_grace_period(999, characters)
	assert_false(
		spawner._grace_timers.has(999), "nothing to grace-period if the character never existed"
	)


func test_expire_grace_period_despawns_and_clears_tracking() -> void:
	var spawner: PlayerSpawner = autofree(PlayerSpawner.new())
	var characters: Node = autofree(Node.new())
	var character := Node2D.new()
	character.name = "777"
	characters.add_child(character)
	spawner._grace_timers[777] = null
	spawner._expire_grace_period(777, characters)
	assert_false(spawner._grace_timers.has(777))
	await get_tree().process_frame
	assert_eq(characters.get_child_count(), 0, "queue_free() is deferred -- 1 frame to actually go")


func test_expire_grace_period_is_a_noop_when_not_tracked() -> void:
	var spawner: PlayerSpawner = autofree(PlayerSpawner.new())
	var characters: Node = autofree(Node.new())
	spawner._expire_grace_period(424242, characters)
	assert_eq(characters.get_child_count(), 0)
