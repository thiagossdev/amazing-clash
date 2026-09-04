class_name BootResource
extends Resource
## Phase 16: a shared, class-independent boot pick (same "one pool of
## 3, any class can equip any of them" confirmed shape as
## WeaponResource). Grants a 5th ability-like slot bound to T
## (CharacterController.boot_active), owned by the player's loadout
## pick rather than the class -- unlike ability_q/e/r/f, which stay
## fixed per class. Wraps an existing AbilityResource rather than
## duplicating its move/cooldown_frames/is_projectile shape: a boot's
## active is mechanically identical to a class ability slot (its own
## ActionFsm, its own cooldown, melee- or projectile-style per
## is_projectile), just sourced from a different registry.
## boot_name is the boot's own display identity in Room Config,
## separate from active_ability.ability_name (the skill it grants) --
## e.g. "Tumbling Boots" granting "Rolling Strike".

@export var boot_name: String = ""
@export var active_ability: AbilityResource
