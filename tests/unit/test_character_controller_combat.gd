extends GutTest
## Phase 2a's test attack move and Phase 3's 2 independent ability slots
## (Q/E) on CharacterController: starting via apply_input(), health/lock
## bookkeeping. Calls the public methods directly rather than simulating
## a live network round-trip -- simpler and just as exact for this logic.

const CHARACTER_SCENE := preload("res://gameplay/characters/character_base/Character.tscn")


func _spawn_character() -> CharacterController:
	return add_child_autofree(CHARACTER_SCENE.instantiate())


## Registers peer_id in the LIVE LobbyState autoload (not a fresh
## LobbyStateScript.new() instance -- _apply_perk_from_lobby_state()
## reads the real singleton, since that's what every peer does live)
## and un-registers it after the assertion, so this test can't leak
## state into any other test that also spawns a character.
func _spawn_character_with_perk(peer_id: int, perk_id: String) -> CharacterController:
	LobbyState.player_perk_ids[peer_id] = perk_id
	var character := CHARACTER_SCENE.instantiate()
	character.name = str(peer_id)
	add_child_autofree(character)
	LobbyState.player_perk_ids.erase(peer_id)
	return character


## Phase 16: same LIVE-singleton-registration pattern as
## _spawn_character_with_perk() above, for weapon/boot -- a fully
## independent loadout axis, not a substitute for it.
func _spawn_character_with_weapon(peer_id: int, weapon_id: String) -> CharacterController:
	LobbyState.player_weapon_ids[peer_id] = weapon_id
	var character := CHARACTER_SCENE.instantiate()
	character.name = str(peer_id)
	add_child_autofree(character)
	LobbyState.player_weapon_ids.erase(peer_id)
	return character


func _spawn_character_with_boot(peer_id: int, boot_id: String) -> CharacterController:
	LobbyState.player_boot_ids[peer_id] = boot_id
	var character := CHARACTER_SCENE.instantiate()
	character.name = str(peer_id)
	add_child_autofree(character)
	LobbyState.player_boot_ids.erase(peer_id)
	return character


func _sample(
	attack_pressed: bool = false,
	ability_q_pressed: bool = false,
	ability_e_pressed: bool = false,
	ability_r_pressed: bool = false,
	ability_f_pressed: bool = false,
	boot_active_pressed: bool = false
) -> InputBuffer.Sample:
	var sample := InputBuffer.Sample.new()
	sample.attack_pressed = attack_pressed
	sample.ability_q_pressed = ability_q_pressed
	sample.ability_e_pressed = ability_e_pressed
	sample.ability_r_pressed = ability_r_pressed
	sample.ability_f_pressed = ability_f_pressed
	sample.boot_active_pressed = boot_active_pressed
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


## attack_pressed reflects the HELD state at this layer (edge-vs-level
## detection happens one layer up, in _sample_local_input -- see its
## own doc comment); holding it across a full move (20 frames: 6
## startup + 4 active + 10 recovery for the debug attack move) should
## auto-restart a fresh cast the instant NEUTRAL is reached again,
## instead of idling until a brand-new press.
func test_holding_attack_auto_repeats_once_the_move_ends() -> void:
	var character := _spawn_character()
	for _tick in range(25):
		character.apply_input(_sample(true))
	assert_ne(
		character.action_fsm.state,
		ActionFsm.State.NEUTRAL,
		"holding attack through a full move+recovery cycle should auto-restart it, not stall in NEUTRAL"
	)
	assert_eq(character.action_fsm.current_move, character.attack_move)


func test_get_aim_direction_is_independent_of_movement() -> void:
	var character := _spawn_character()
	var sample := _sample()
	sample.move_vector = Vector2.UP
	sample.aim_direction = Vector2.DOWN
	character.apply_input(sample)
	assert_eq(
		character.get_aim_direction(),
		Vector2.DOWN,
		"melee's aim should follow the input sample's aim_direction, not movement"
	)
	assert_ne(
		character.get_aim_direction(),
		character.fsm.facing_direction,
		"moving one way while aiming another must not collapse aim into movement direction"
	)


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
		"a 0.5 cooldown_multiplier (e.g. Adept) should let Q recast after half its normal cooldown"
	)
	assert_ne(character.ability_q_fsm.state, ActionFsm.State.NEUTRAL)


## Phase 15: ability_r/ability_f mirror ability_q/ability_e exactly --
## own FSM, own cooldown, independent of every other slot. Coverage
## here is deliberately a subset of Q/E's own (start, cooldown-blocks,
## cooldown-elapses), not the full set -- the underlying
## _advance_ability_slot() logic is already exhaustively covered by
## the Q/E tests above; these just confirm R/F are wired to it at all.
func test_ability_r_pressed_starts_its_own_move() -> void:
	var character := _spawn_character()
	character.apply_input(_sample(false, false, false, true))
	assert_ne(character.ability_r_fsm.state, ActionFsm.State.NEUTRAL)
	assert_eq(character.ability_r_fsm.current_move, character.ability_r.move)


func test_ability_f_pressed_starts_its_own_move() -> void:
	var character := _spawn_character()
	character.apply_input(_sample(false, false, false, false, true))
	assert_ne(character.ability_f_fsm.state, ActionFsm.State.NEUTRAL)
	assert_eq(character.ability_f_fsm.current_move, character.ability_f.move)


func test_ability_r_stays_on_cooldown_after_its_move_ends() -> void:
	var character := _spawn_character()
	character.apply_input(_sample(false, false, false, true))
	var move := character.ability_r.move
	var total_frames := move.startup_frames + move.active_frames + move.recovery_frames
	for _i in range(total_frames):
		character.apply_input(_sample())
	assert_eq(character.ability_r_fsm.state, ActionFsm.State.NEUTRAL)
	character.apply_input(_sample(false, false, false, true))
	assert_eq(
		character.ability_r_fsm.state,
		ActionFsm.State.NEUTRAL,
		"pressing R again immediately after its move ends should be blocked by cooldown"
	)


func test_ability_f_can_be_cast_again_once_cooldown_elapses() -> void:
	var character := _spawn_character()
	character.apply_input(_sample(false, false, false, false, true))
	for _i in range(character.ability_f.cooldown_frames):
		character.apply_input(_sample())
	character.apply_input(_sample(false, false, false, false, true))
	assert_eq(character.ability_f_fsm.current_move, character.ability_f.move)
	assert_ne(character.ability_f_fsm.state, ActionFsm.State.NEUTRAL)


func test_all_4_ability_slots_are_independent_of_each_other() -> void:
	var character := _spawn_character()
	character.apply_input(_sample(false, true, true, true, true))
	assert_ne(character.ability_q_fsm.state, ActionFsm.State.NEUTRAL)
	assert_ne(character.ability_e_fsm.state, ActionFsm.State.NEUTRAL)
	assert_ne(character.ability_r_fsm.state, ActionFsm.State.NEUTRAL)
	assert_ne(character.ability_f_fsm.state, ActionFsm.State.NEUTRAL)


func test_is_any_action_active_includes_ability_r_and_f() -> void:
	var character := _spawn_character()
	character.ability_r_fsm.state = ActionFsm.State.ACTIVE
	assert_true(character._is_any_action_active())
	character.ability_r_fsm.state = ActionFsm.State.NEUTRAL
	character.ability_f_fsm.state = ActionFsm.State.ACTIVE
	assert_true(character._is_any_action_active())


## Found live via Phase 15's own functional test (see memory/gotchas.md):
## _restore_predicted_state() restored ability_q/e/r/f's .state and
## .move_frame from their Checkpoint fields, but never .current_move --
## ActionFsm.advance_frame() dereferences current_move unconditionally
## whenever state isn't NEUTRAL, so a reconciliation replay landing on a
## restored non-NEUTRAL ability slot crashed with a real engine error
## ("Invalid access to property or key 'startup_frames' on a base
## object of type 'Nil'"). Pre-existing for Q/E too (this test would
## fail identically against ability_q); R/F's live test is what first
## exercised the reconciliation timing that triggers it.
func test_restoring_a_predicted_checkpoint_preserves_ability_r_current_move() -> void:
	var character := _spawn_character()
	character.apply_input(_sample(false, false, false, true))
	var checkpoint := character._capture_predicted_state(1)
	character.ability_r_fsm.current_move = null
	character._restore_predicted_state(checkpoint)
	assert_eq(
		character.ability_r_fsm.current_move,
		character.ability_r.move,
		"restoring a checkpoint must bring back the ability's current_move, not just state/move_frame"
	)
	character.ability_r_fsm.advance_frame()  # must not throw


## Phase 16: boot_active mirrors ability_r/ability_f exactly -- own FSM,
## own cooldown, independent of every other slot -- except its
## AbilityResource comes from the player's boot pick (see
## test_boot_active_resolves_from_lobby_state_boot_pick below), not a
## fixed per-class @export. Coverage here is the same deliberate subset
## Phase 15 used for R/F, not the full Q/E set.
func test_boot_active_pressed_starts_its_own_move() -> void:
	var character := _spawn_character()
	character.apply_input(_sample(false, false, false, false, false, true))
	assert_ne(character.boot_active_fsm.state, ActionFsm.State.NEUTRAL)
	assert_eq(character.boot_active_fsm.current_move, character.boot_active.move)


func test_boot_active_stays_on_cooldown_after_its_move_ends() -> void:
	var character := _spawn_character()
	character.apply_input(_sample(false, false, false, false, false, true))
	var move := character.boot_active.move
	var total_frames := move.startup_frames + move.active_frames + move.recovery_frames
	for _i in range(total_frames):
		character.apply_input(_sample())
	assert_eq(character.boot_active_fsm.state, ActionFsm.State.NEUTRAL)
	character.apply_input(_sample(false, false, false, false, false, true))
	assert_eq(
		character.boot_active_fsm.state,
		ActionFsm.State.NEUTRAL,
		"pressing the boot's active again immediately after it ends should be blocked by cooldown"
	)


func test_boot_active_is_independent_of_the_4_class_ability_slots() -> void:
	var character := _spawn_character()
	character.apply_input(_sample(false, true, true, true, true, true))
	assert_ne(character.ability_q_fsm.state, ActionFsm.State.NEUTRAL)
	assert_ne(character.ability_e_fsm.state, ActionFsm.State.NEUTRAL)
	assert_ne(character.ability_r_fsm.state, ActionFsm.State.NEUTRAL)
	assert_ne(character.ability_f_fsm.state, ActionFsm.State.NEUTRAL)
	assert_ne(character.boot_active_fsm.state, ActionFsm.State.NEUTRAL)


func test_is_any_action_active_includes_boot_active() -> void:
	var character := _spawn_character()
	character.boot_active_fsm.state = ActionFsm.State.ACTIVE
	assert_true(character._is_any_action_active())


## Same live-found reconciliation gap as ability_r/e/q/f (see
## memory/gotchas.md) -- boot_active is new in Phase 16, so this
## confirms its own Checkpoint field was added correctly the first
## time, not found broken later.
func test_restoring_a_predicted_checkpoint_preserves_boot_active_current_move() -> void:
	var character := _spawn_character()
	character.apply_input(_sample(false, false, false, false, false, true))
	var checkpoint := character._capture_predicted_state(1)
	character.boot_active_fsm.current_move = null
	character._restore_predicted_state(checkpoint)
	assert_eq(
		character.boot_active_fsm.current_move,
		character.boot_active.move,
		"restoring a checkpoint must bring back boot_active's current_move too"
	)
	character.boot_active_fsm.advance_frame()  # must not throw


## Phase 16: attack_move/skillshot_move are no longer fixed per-class
## @export values -- resolved at runtime from the player's Room Config
## weapon pick, same "every peer's own _ready(), never PlayerSpawner"
## pattern as perk (see _apply_weapon_from_lobby_state()'s own doc
## comment).
func test_weapon_resolves_attack_and_skillshot_move_from_lobby_state() -> void:
	var character := _spawn_character_with_weapon(929292, "warhammer")
	assert_eq(character.attack_move.move_name, "Crushing Blow")
	assert_eq(character.skillshot_move.move_name, "Ground Slam Wave")


func test_unregistered_peer_falls_back_to_the_first_canonical_weapon() -> void:
	var character := _spawn_character()
	assert_eq(character.attack_move.move_name, "Debug Attack")
	assert_eq(character.skillshot_move.move_name, "Debug Skillshot")


func test_boot_active_resolves_from_lobby_state_boot_pick() -> void:
	var character := _spawn_character_with_boot(939393, "tumbling_boots")
	assert_eq(character.boot_active.ability_name, "Rolling Strike")
	assert_true(character.boot_active.is_projectile)


func test_unregistered_peer_falls_back_to_the_first_canonical_boot() -> void:
	var character := _spawn_character()
	assert_eq(character.boot_active.ability_name, "Quick Kick")


func test_apply_perk_from_lobby_state_scales_stats_on_ready() -> void:
	var character := _spawn_character_with_perk(919191, "swift")
	assert_eq(
		character.fsm.move_speed_multiplier,
		1.1,
		"a character whose peer_id is registered with a perk in LobbyState should be scaled on _ready()"
	)


func test_apply_perk_from_lobby_state_is_a_no_op_for_an_unregistered_peer() -> void:
	var character := CHARACTER_SCENE.instantiate()
	character.name = "424242"
	add_child_autofree(character)
	assert_eq(character.max_health, 100.0)
	assert_eq(character.fsm.move_speed_multiplier, 1.0)
	assert_eq(character.cooldown_multiplier, 1.0)


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


func test_taking_damage_triggers_a_hit_flash() -> void:
	var character := _spawn_character()
	character.take_damage(10.0)
	character._update_visual_feedback()
	assert_eq(character.get_node(character.visual_path).modulate, character.HIT_FLASH_MODULATE)


func test_hit_flash_fades_after_its_own_frame_count() -> void:
	var character := _spawn_character()
	character.take_damage(10.0)
	# +1: the call that detects the drop also spends the first flash
	# frame, so HIT_FLASH_FRAMES total frames of flash need
	# HIT_FLASH_FRAMES + 1 calls to fully decay to 0.
	for _i in range(character.HIT_FLASH_FRAMES + 1):
		character._update_visual_feedback()
	assert_eq(character.get_node(character.visual_path).modulate, character.NEUTRAL_MODULATE)


func test_active_action_triggers_a_swing_pulse() -> void:
	var character := _spawn_character()
	character.action_fsm.state = ActionFsm.State.ACTIVE
	character._update_visual_feedback()
	assert_eq(character.get_node(character.visual_path).modulate, character.ACTIVE_SWING_MODULATE)


func test_hit_flash_takes_priority_over_swing_pulse() -> void:
	var character := _spawn_character()
	character.action_fsm.state = ActionFsm.State.ACTIVE
	character.take_damage(10.0)
	character._update_visual_feedback()
	assert_eq(character.get_node(character.visual_path).modulate, character.HIT_FLASH_MODULATE)


func test_no_action_and_no_recent_hit_is_neutral_modulate() -> void:
	var character := _spawn_character()
	character._update_visual_feedback()
	assert_eq(character.get_node(character.visual_path).modulate, character.NEUTRAL_MODULATE)


func test_position_at_tick_reads_from_recorded_history() -> void:
	var character := _spawn_character()
	character._position_history = [
		{"tick": 100, "position": Vector2(10, 10)}, {"tick": 105, "position": Vector2(20, 20)}
	]
	assert_eq(character.position_at_tick(102), Vector2(10, 10))


func test_position_at_tick_falls_back_to_live_position_when_history_is_empty() -> void:
	var character := _spawn_character()
	character.global_position = Vector2(50, 50)
	assert_eq(character.position_at_tick(5), Vector2(50, 50))


## Slice 13b: is_owned_by_me() compares controlling_peer_id, resolved
## from the node's own name in _ready() when never set explicitly by a
## spawner -- this keeps every OTHER test in this file (which never
## touches controlling_peer_id at all) working unchanged.
func test_controlling_peer_id_resolves_from_node_name_by_default() -> void:
	var character := CHARACTER_SCENE.instantiate()
	character.name = "777"
	add_child_autofree(character)
	assert_eq(character.controlling_peer_id, 777)


func test_controlling_peer_id_can_be_set_explicitly_before_ready() -> void:
	var character := CHARACTER_SCENE.instantiate()
	character.name = "111"
	character.controlling_peer_id = 111
	add_child_autofree(character)
	assert_eq(character.controlling_peer_id, 111)
	assert_true(character.is_owned_by_me() == (111 == multiplayer.get_unique_id()))


## Slice 13b reconnect: reassigning control updates controlling_peer_id
## regardless of network role. Called directly (not via .rpc()) --
## an @rpc-annotated function is still a normal callable function, and
## this project's own convention is to unit-test the pure decision
## logic this way rather than exercise the RPC transport itself in GUT
## (see e.g. test_lobby_state.gd's own RPC handler tests).
func test_rpc_reassign_controller_updates_controlling_peer_id() -> void:
	var character := _spawn_character()
	character._rpc_reassign_controller(424242)
	assert_eq(character.controlling_peer_id, 424242)
