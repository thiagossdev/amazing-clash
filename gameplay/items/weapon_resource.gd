class_name WeaponResource
extends Resource
## Phase 16: a shared, class-independent weapon pick (confirmed
## 2026-09-03: one pool of 3, any class can equip any of them). Defines
## LMB (attack_move) and RMB (skillshot_move) -- fields that used to be
## fixed per-class @export values on CharacterController, now resolved
## at runtime from the player's Room Config weapon pick (see
## CharacterController._apply_weapon_from_lobby_state()), same
## "resolved on every peer's own _ready(), never set once by
## PlayerSpawner" pattern Phase 9's perk multipliers already
## established -- MultiplayerSpawner replication creates SEPARATE node
## instances for the AUTHORITATIVE/PREDICTED/INTERPOLATED copies of a
## character, so a value set only server-side would never reach the
## other 2. No is_projectile field like AbilityResource: attack is
## always melee (CombatResolver._resolve_melee) and skillshot is always
## a projectile (CombatResolver._maybe_launch_projectile), an
## unconditional dispatch this project has used since Phase 2b, not a
## per-weapon choice.

@export var weapon_name: String = ""
@export var attack_move: MoveDefinition
@export var skillshot_move: MoveDefinition
