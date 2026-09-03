extends GutTest


func test_base_damage_only() -> void:
	assert_eq(DamagePipeline.compute(10.0), 10.0)


func test_combo_scaling_multiplies_damage() -> void:
	assert_eq(DamagePipeline.compute(10.0, 0.5), 5.0)


func test_buff_modifier_multiplies_damage() -> void:
	assert_eq(DamagePipeline.compute(10.0, 1.0, 1.5), 15.0)


func test_combo_scaling_and_buff_modifier_compose() -> void:
	assert_eq(DamagePipeline.compute(10.0, 0.5, 2.0), 10.0)
