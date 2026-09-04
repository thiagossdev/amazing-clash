extends GutTest
## Every real class scene: confirms each wires its own distinct kit
## (ability_q/e/r/f, not Character.tscn's generic placeholder data) and
## stats. Behavioral coverage (cooldown gating, independent slots, etc.)
## is already exercised generically against Character.tscn in
## test_character_controller_combat.gd -- this file only guards against
## a wiring mistake in the .tscn/.tres content itself (e.g. an
## ExtResource pointing at the wrong move).
##
## Phase 16: attack_move/skillshot_move are NO LONGER asserted here --
## they stopped being class-owned .tscn wiring and became a runtime-
## resolved weapon pick (any class can equip any of the 3 shared
## weapons), so "each class wires its own distinct attack/skillshot" is
## no longer true by design. That resolution is covered generically in
## test_character_controller_combat.gd instead (same reasoning as the
## cooldown-gating behavior above); test_falls_back_to_the_same_weapon_
## default_regardless_of_class below only confirms all 3 classes share
## that same fallback, not that each has its own.

const VANGUARD_SCENE := preload("res://gameplay/characters/vanguard/Vanguard.tscn")
const RANGED_MAGE_SCENE := preload("res://gameplay/characters/ranged_mage/RangedMage.tscn")
const WARDEN_SCENE := preload("res://gameplay/characters/warden/Warden.tscn")


func test_vanguard_kit_is_wired() -> void:
	var character: CharacterController = add_child_autofree(VANGUARD_SCENE.instantiate())
	assert_eq(character.ability_q.ability_name, "Heavy Slam")
	assert_false(character.ability_q.is_projectile)
	assert_eq(character.ability_e.ability_name, "Bulwark Strike")
	assert_false(character.ability_e.is_projectile)
	assert_eq(character.ability_r.ability_name, "Shoulder Charge")
	assert_false(character.ability_r.is_projectile)
	assert_eq(character.ability_f.ability_name, "Execute")
	assert_false(character.ability_f.is_projectile)
	assert_eq(character.max_health, 120.0)
	assert_eq(character.current_health, 120.0)


func test_ranged_mage_kit_is_wired() -> void:
	var character: CharacterController = add_child_autofree(RANGED_MAGE_SCENE.instantiate())
	assert_eq(character.ability_q.ability_name, "Frost Shard")
	assert_true(character.ability_q.is_projectile)
	assert_eq(character.ability_e.ability_name, "Arcane Nova")
	assert_true(character.ability_e.is_projectile)
	assert_eq(character.ability_r.ability_name, "Mana Spike")
	assert_true(character.ability_r.is_projectile)
	assert_eq(character.ability_f.ability_name, "Meteor")
	assert_true(character.ability_f.is_projectile)
	assert_eq(character.max_health, 80.0)
	assert_eq(character.current_health, 80.0)


func test_warden_kit_is_wired() -> void:
	var character: CharacterController = add_child_autofree(WARDEN_SCENE.instantiate())
	assert_eq(character.ability_q.ability_name, "Stagger Strike")
	assert_false(character.ability_q.is_projectile)
	assert_eq(character.ability_e.ability_name, "Overwhelm")
	assert_true(character.ability_e.is_projectile)
	assert_eq(character.ability_r.ability_name, "Restraining Web")
	assert_true(character.ability_r.is_projectile)
	assert_eq(character.ability_f.ability_name, "Guardian's Grasp")
	assert_false(character.ability_f.is_projectile)
	assert_eq(character.max_health, 100.0)
	assert_eq(character.current_health, 100.0)


func test_warden_kit_has_the_longest_hitstun_in_the_game() -> void:
	# Warden's identity is control via oversized hitstun-to-damage
	# ratio, not raw damage -- assert that directly against its
	# closest analog on each other class, so a future balance pass
	# can't silently erode the archetype's whole reason to exist.
	var warden: CharacterController = add_child_autofree(WARDEN_SCENE.instantiate())
	var vanguard: CharacterController = add_child_autofree(VANGUARD_SCENE.instantiate())
	var mage: CharacterController = add_child_autofree(RANGED_MAGE_SCENE.instantiate())
	var warden_e_hitstun: int = warden.ability_e.move.hit_definitions[0].hitstun_frames
	var vanguard_e_hitstun: int = vanguard.ability_e.move.hit_definitions[0].hitstun_frames
	var mage_e_hitstun: int = mage.ability_e.move.hit_definitions[0].hitstun_frames
	assert_gt(warden_e_hitstun, vanguard_e_hitstun)
	assert_gt(warden_e_hitstun, mage_e_hitstun)


## Phase 16: confirms the weapon pool is genuinely class-independent --
## all 3 real classes fall back to the exact same weapon (index 0) when
## unregistered, not 3 different class-flavored defaults like before
## this phase.
func test_all_3_classes_fall_back_to_the_same_weapon_when_unregistered() -> void:
	var vanguard: CharacterController = add_child_autofree(VANGUARD_SCENE.instantiate())
	var mage: CharacterController = add_child_autofree(RANGED_MAGE_SCENE.instantiate())
	var warden: CharacterController = add_child_autofree(WARDEN_SCENE.instantiate())
	assert_eq(vanguard.attack_move.move_name, mage.attack_move.move_name)
	assert_eq(mage.attack_move.move_name, warden.attack_move.move_name)
	assert_eq(vanguard.skillshot_move.move_name, mage.skillshot_move.move_name)
	assert_eq(mage.skillshot_move.move_name, warden.skillshot_move.move_name)
