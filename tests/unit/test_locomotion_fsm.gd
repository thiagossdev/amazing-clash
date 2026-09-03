extends GutTest


func test_starts_idle() -> void:
	var fsm := LocomotionFsm.new()
	assert_eq(fsm.state, LocomotionFsm.State.IDLE)


func test_no_input_stays_idle() -> void:
	var fsm := LocomotionFsm.new()
	fsm.advance(Vector2.ZERO, false, 1.0 / 60.0)
	assert_eq(fsm.state, LocomotionFsm.State.IDLE)
	assert_eq(fsm.velocity, Vector2.ZERO)


func test_move_input_walks_at_move_speed() -> void:
	var fsm := LocomotionFsm.new()
	fsm.advance(Vector2.RIGHT, false, 1.0 / 60.0)
	assert_eq(fsm.state, LocomotionFsm.State.WALK)
	assert_eq(fsm.velocity, Vector2.RIGHT * LocomotionFsm.MOVE_SPEED)


func test_oversized_move_vector_is_clamped_to_move_speed() -> void:
	var fsm := LocomotionFsm.new()
	fsm.advance(Vector2.RIGHT * 10.0, false, 1.0 / 60.0)
	assert_eq(
		fsm.velocity,
		Vector2.RIGHT * LocomotionFsm.MOVE_SPEED,
		"a move_vector longer than 1.0 (e.g. from a modified client) must not exceed MOVE_SPEED"
	)


func test_dash_pressed_with_move_input_starts_dash() -> void:
	var fsm := LocomotionFsm.new()
	fsm.advance(Vector2.RIGHT, true, 1.0 / 60.0)
	assert_eq(fsm.state, LocomotionFsm.State.DASHING)
	assert_eq(fsm.velocity, Vector2.RIGHT * LocomotionFsm.DASH_SPEED)


func test_dash_pressed_with_no_move_input_is_ignored() -> void:
	var fsm := LocomotionFsm.new()
	fsm.advance(Vector2.ZERO, true, 1.0 / 60.0)
	assert_eq(fsm.state, LocomotionFsm.State.IDLE)


func test_dash_locks_out_new_input_direction_until_it_ends() -> void:
	var fsm := LocomotionFsm.new()
	fsm.advance(Vector2.RIGHT, true, 1.0 / 60.0)
	fsm.advance(Vector2.UP, false, 1.0 / 60.0)
	assert_eq(fsm.state, LocomotionFsm.State.DASHING)
	assert_eq(fsm.velocity, Vector2.RIGHT * LocomotionFsm.DASH_SPEED)


func test_dash_ends_after_its_duration_and_returns_to_walk() -> void:
	var fsm := LocomotionFsm.new()
	fsm.advance(Vector2.RIGHT, true, 1.0 / 60.0)
	fsm.advance(Vector2.RIGHT, false, LocomotionFsm.DASH_DURATION)
	assert_eq(fsm.state, LocomotionFsm.State.WALK)


func test_dash_ends_after_its_duration_and_returns_to_idle_with_no_input() -> void:
	var fsm := LocomotionFsm.new()
	fsm.advance(Vector2.RIGHT, true, 1.0 / 60.0)
	fsm.advance(Vector2.ZERO, false, LocomotionFsm.DASH_DURATION)
	assert_eq(fsm.state, LocomotionFsm.State.IDLE)


func test_cannot_dash_again_during_cooldown() -> void:
	var fsm := LocomotionFsm.new()
	fsm.advance(Vector2.RIGHT, true, 1.0 / 60.0)
	fsm.advance(Vector2.RIGHT, false, LocomotionFsm.DASH_DURATION)
	assert_false(fsm.can_dash())
	fsm.advance(Vector2.RIGHT, true, 1.0 / 60.0)
	assert_eq(
		fsm.state, LocomotionFsm.State.WALK, "a dash press during cooldown must not re-trigger dash"
	)


func test_move_speed_multiplier_scales_walk_velocity() -> void:
	var fsm := LocomotionFsm.new()
	fsm.move_speed_multiplier = 1.1
	fsm.advance(Vector2.RIGHT, false, 1.0 / 60.0)
	assert_eq(fsm.velocity, Vector2.RIGHT * LocomotionFsm.MOVE_SPEED * 1.1)


func test_default_move_speed_multiplier_is_a_no_op() -> void:
	var fsm := LocomotionFsm.new()
	fsm.advance(Vector2.RIGHT, false, 1.0 / 60.0)
	assert_eq(fsm.velocity, Vector2.RIGHT * LocomotionFsm.MOVE_SPEED)


func test_move_speed_multiplier_does_not_affect_dash_speed() -> void:
	var fsm := LocomotionFsm.new()
	fsm.move_speed_multiplier = 1.1
	fsm.advance(Vector2.RIGHT, true, 1.0 / 60.0)
	assert_eq(
		fsm.velocity,
		Vector2.RIGHT * LocomotionFsm.DASH_SPEED,
		"a perk's move-speed multiplier is scoped to walk speed, not dash"
	)


func test_can_dash_again_once_cooldown_elapses() -> void:
	var fsm := LocomotionFsm.new()
	fsm.advance(Vector2.RIGHT, true, 1.0 / 60.0)
	fsm.advance(Vector2.RIGHT, false, LocomotionFsm.DASH_DURATION)
	fsm.advance(Vector2.RIGHT, false, LocomotionFsm.DASH_COOLDOWN)
	assert_true(fsm.can_dash())
	fsm.advance(Vector2.RIGHT, true, 1.0 / 60.0)
	assert_eq(fsm.state, LocomotionFsm.State.DASHING)
