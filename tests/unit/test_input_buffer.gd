extends GutTest
## Phase 15: pack_ability_flags/unpack_ability_flags round-trip, now
## covering all 6 flags (attack, skillshot, ability_q/e/r/f) -- not
## unit-tested before this phase, added alongside the R/F extension
## since a bit-order mistake here would silently swap which ability a
## remote peer's input actually re-triggers server-side.


func test_pack_and_unpack_round_trips_every_flag_independently() -> void:
	for flag_index in range(6):
		var sample := InputBuffer.Sample.new()
		match flag_index:
			0:
				sample.attack_pressed = true
			1:
				sample.skillshot_pressed = true
			2:
				sample.ability_q_pressed = true
			3:
				sample.ability_e_pressed = true
			4:
				sample.ability_r_pressed = true
			5:
				sample.ability_f_pressed = true
		var flags := InputBuffer.pack_ability_flags(sample)
		var restored := InputBuffer.Sample.new()
		InputBuffer.unpack_ability_flags(restored, flags)
		assert_eq(restored.attack_pressed, sample.attack_pressed, "flag_index %d" % flag_index)
		assert_eq(
			restored.skillshot_pressed, sample.skillshot_pressed, "flag_index %d" % flag_index
		)
		assert_eq(
			restored.ability_q_pressed, sample.ability_q_pressed, "flag_index %d" % flag_index
		)
		assert_eq(
			restored.ability_e_pressed, sample.ability_e_pressed, "flag_index %d" % flag_index
		)
		assert_eq(
			restored.ability_r_pressed, sample.ability_r_pressed, "flag_index %d" % flag_index
		)
		assert_eq(
			restored.ability_f_pressed, sample.ability_f_pressed, "flag_index %d" % flag_index
		)


func test_pack_with_no_flags_set_is_zero() -> void:
	assert_eq(InputBuffer.pack_ability_flags(InputBuffer.Sample.new()), 0)
