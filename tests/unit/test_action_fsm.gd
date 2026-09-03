extends GutTest


func _make_move(startup: int, active: int, recovery: int) -> MoveDefinition:
	var move := MoveDefinition.new()
	move.startup_frames = startup
	move.active_frames = active
	move.recovery_frames = recovery
	return move


func test_starts_neutral() -> void:
	var action_fsm := ActionFsm.new()
	assert_eq(action_fsm.state, ActionFsm.State.NEUTRAL)


func test_zero_startup_move_is_immediately_active() -> void:
	var action_fsm := ActionFsm.new()
	action_fsm.start_move(_make_move(0, 3, 5))
	assert_eq(action_fsm.state, ActionFsm.State.ACTIVE)


func test_nonzero_startup_move_starts_in_startup() -> void:
	var action_fsm := ActionFsm.new()
	action_fsm.start_move(_make_move(2, 3, 5))
	assert_eq(action_fsm.state, ActionFsm.State.STARTUP)


func test_advances_from_startup_to_active_to_recovery_to_neutral() -> void:
	var action_fsm := ActionFsm.new()
	action_fsm.start_move(_make_move(2, 2, 2))
	assert_eq(action_fsm.state, ActionFsm.State.STARTUP, "frame 0")
	action_fsm.advance_frame()
	assert_eq(action_fsm.state, ActionFsm.State.STARTUP, "frame 1")
	action_fsm.advance_frame()
	assert_eq(action_fsm.state, ActionFsm.State.ACTIVE, "frame 2")
	action_fsm.advance_frame()
	assert_eq(action_fsm.state, ActionFsm.State.ACTIVE, "frame 3")
	action_fsm.advance_frame()
	assert_eq(action_fsm.state, ActionFsm.State.RECOVERY, "frame 4")
	action_fsm.advance_frame()
	assert_eq(action_fsm.state, ActionFsm.State.RECOVERY, "frame 5")
	action_fsm.advance_frame()
	assert_eq(action_fsm.state, ActionFsm.State.NEUTRAL, "frame 6, move over")


func test_is_hitbox_active_only_true_during_active() -> void:
	var action_fsm := ActionFsm.new()
	action_fsm.start_move(_make_move(1, 1, 1))
	assert_false(action_fsm.is_hitbox_active(), "startup")
	action_fsm.advance_frame()
	assert_true(action_fsm.is_hitbox_active(), "active")
	action_fsm.advance_frame()
	assert_false(action_fsm.is_hitbox_active(), "recovery")


func test_advance_frame_is_a_noop_while_neutral() -> void:
	var action_fsm := ActionFsm.new()
	action_fsm.advance_frame()
	assert_eq(action_fsm.state, ActionFsm.State.NEUTRAL)


func test_already_hit_resets_on_a_fresh_start_move() -> void:
	var action_fsm := ActionFsm.new()
	action_fsm.start_move(_make_move(0, 1, 1))
	action_fsm.already_hit.append("some_defender")
	action_fsm.advance_frame()
	action_fsm.advance_frame()
	assert_eq(action_fsm.state, ActionFsm.State.NEUTRAL)
	action_fsm.start_move(_make_move(0, 1, 1))
	assert_eq(action_fsm.already_hit, [])
