extends GutTest
## Phase 4's 2 real classes: confirms each scene wires its own distinct
## kit (not Character.tscn's generic placeholder data) and stats.
## Behavioral coverage (cooldown gating, independent slots, etc.) is
## already exercised generically against Character.tscn in
## test_character_controller_combat.gd -- this file only guards against
## a wiring mistake in the .tscn/.tres content itself (e.g. an
## ExtResource pointing at the wrong move).

const VANGUARD_SCENE := preload("res://gameplay/characters/vanguard/Vanguard.tscn")
const RANGED_MAGE_SCENE := preload("res://gameplay/characters/ranged_mage/RangedMage.tscn")


func test_vanguard_kit_is_wired() -> void:
	var character: CharacterController = add_child_autofree(VANGUARD_SCENE.instantiate())
	assert_eq(character.attack_move.move_name, "Quick Slash")
	assert_eq(character.skillshot_move.move_name, "Piercing Thrust")
	assert_eq(character.ability_q.ability_name, "Heavy Slam")
	assert_false(character.ability_q.is_projectile)
	assert_eq(character.ability_e.ability_name, "Bulwark Strike")
	assert_false(character.ability_e.is_projectile)
	assert_eq(character.max_health, 120.0)
	assert_eq(character.current_health, 120.0)


func test_ranged_mage_kit_is_wired() -> void:
	var character: CharacterController = add_child_autofree(RANGED_MAGE_SCENE.instantiate())
	assert_eq(character.attack_move.move_name, "Arcane Jab")
	assert_eq(character.skillshot_move.move_name, "Arcane Bolt")
	assert_eq(character.ability_q.ability_name, "Frost Shard")
	assert_true(character.ability_q.is_projectile)
	assert_eq(character.ability_e.ability_name, "Arcane Nova")
	assert_true(character.ability_e.is_projectile)
	assert_eq(character.max_health, 80.0)
	assert_eq(character.current_health, 80.0)
