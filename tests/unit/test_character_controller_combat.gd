extends GutTest
## Phase 2a's test attack move and Phase 3's 2 independent ability slots
## (Q/E) on CharacterController: starting via apply_input(), health/lock
## bookkeeping. Calls the public methods directly rather than simulating
## a live network round-trip -- simpler and just as exact for this logic.

const CHARACTER_SCENE := preload("res://gameplay/characters/character_base/Character.tscn")


func _spawn_character() -> CharacterController:
	return add_child_autofree(CHARACTER_SCENE.instantiate())


func _sample(
	attack_pressed: bool = false, ability_q_pressed: bool = false, ability_e_pressed: bool = false
) -> InputBuffer.Sample:
	var sample := InputBuffer.Sample.new()
	sample.attack_pressed = attack_pressed
	sample.ability_q_pressed = ability_q_pressed
	sample.ability_e_pressed = ability_e_pressed
	sample.delta = 1.0 / 60.0
	return sample


func test_attack_pressed_starts_the_attack_move() -> void:
	var character := _spawn_character()
	character.apply_input(_sample(true))
	assert_ne(character.action_fsm.state, ActionFsm.State.NEUTRAL)
	assert_eq(character.action_fsm.current_move, character.attack_move)


func test_attack_pressed_again_mid_move_does_not_restart_it() -> void:
	var character := _spawn_character()
	character.apply_input(_sample(true))
	character.apply_input(_sample())
	var move_frame_before := character.action_fsm.move_frame
	character.apply_input(_sample(true))
	assert_eq(
		character.action_fsm.move_frame,
		move_frame_before + 1,
		"a second attack press mid-move should just advance the frame, not restart it"
	)


func test_get_aim_direction_matches_facing_direction() -> void:
	var character := _spawn_character()
	character.apply_input(_sample())
	assert_eq(character.get_aim_direction(), character.fsm.facing_direction)


func test_take_damage_reduces_health() -> void:
	var character := _spawn_character()
	character.take_damage(30.0)
	assert_eq(character.current_health, 70.0)


func test_take_damage_clamps_at_zero() -> void:
	var character := _spawn_character()
	character.take_damage(9999.0)
	assert_eq(character.current_health, 0.0)


func test_apply_lock_never_shortens_a_longer_existing_lock() -> void:
	var character := _spawn_character()
	character.apply_lock(20)
	character.apply_lock(5)
	assert_eq(character._lock_frames, 20)


func test_ability_q_pressed_starts_its_own_move() -> void:
	var character := _spawn_character()
	character.apply_input(_sample(false, true))
	assert_ne(character.ability_q_fsm.state, ActionFsm.State.NEUTRAL)
	assert_eq(character.ability_q_fsm.current_move, character.ability_q.move)


func test_ability_e_pressed_starts_its_own_move() -> void:
	var character := _spawn_character()
	character.apply_input(_sample(false, false, true))
	assert_ne(character.ability_e_fsm.state, ActionFsm.State.NEUTRAL)
	assert_eq(character.ability_e_fsm.current_move, character.ability_e.move)


func test_ability_q_and_melee_attack_can_be_active_at_the_same_time() -> void:
	var character := _spawn_character()
	character.apply_input(_sample(true, true))
	assert_ne(character.action_fsm.state, ActionFsm.State.NEUTRAL)
	assert_ne(character.ability_q_fsm.state, ActionFsm.State.NEUTRAL)


func test_ability_q_pressed_again_mid_move_does_not_restart_it() -> void:
	var character := _spawn_character()
	character.apply_input(_sample(false, true))
	character.apply_input(_sample())
	var move_frame_before := character.ability_q_fsm.move_frame
	character.apply_input(_sample(false, true))
	assert_eq(
		character.ability_q_fsm.move_frame,
		move_frame_before + 1,
		"a second Q press mid-move should just advance the frame, not restart it"
	)


func test_ability_q_stays_on_cooldown_after_its_move_ends() -> void:
	var character := _spawn_character()
	character.apply_input(_sample(false, true))
	var move := character.ability_q.move
	var total_frames := move.startup_frames + move.active_frames + move.recovery_frames
	for _i in range(total_frames):
		character.apply_input(_sample())
	assert_eq(character.ability_q_fsm.state, ActionFsm.State.NEUTRAL)
	character.apply_input(_sample(false, true))
	assert_eq(
		character.ability_q_fsm.state,
		ActionFsm.State.NEUTRAL,
		"pressing Q again immediately after its move ends should be blocked by cooldown"
	)


func test_ability_q_can_be_cast_again_once_cooldown_elapses() -> void:
	var character := _spawn_character()
	character.apply_input(_sample(false, true))
	for _i in range(character.ability_q.cooldown_frames):
		character.apply_input(_sample())
	character.apply_input(_sample(false, true))
	assert_eq(character.ability_q_fsm.current_move, character.ability_q.move)
	assert_ne(character.ability_q_fsm.state, ActionFsm.State.NEUTRAL)


func test_cooldown_multiplier_shortens_ability_cooldown() -> void:
	var character := _spawn_character()
	character.cooldown_multiplier = 0.5
	character.apply_input(_sample(false, true))
	var halved_cooldown := int(character.ability_q.cooldown_frames * 0.5)
	for _i in range(halved_cooldown):
		character.apply_input(_sample())
	character.apply_input(_sample(false, true))
	assert_eq(
		character.ability_q_fsm.current_move,
		character.ability_q.move,
		"a 0.5 cooldown_multiplier (e.g. the Adept perk) should let Q recast after half its normal cooldown"
	)
	assert_ne(character.ability_q_fsm.state, ActionFsm.State.NEUTRAL)


func test_default_cooldown_multiplier_is_a_no_op() -> void:
	var character := _spawn_character()
	character.apply_input(_sample(false, true))
	var halved_cooldown := int(character.ability_q.cooldown_frames * 0.5)
	for _i in range(halved_cooldown):
		character.apply_input(_sample())
	character.apply_input(_sample(false, true))
	assert_eq(
		character.ability_q_fsm.state,
		ActionFsm.State.NEUTRAL,
		"without a perk (multiplier 1.0), half the normal cooldown must still be on cooldown"
	)
