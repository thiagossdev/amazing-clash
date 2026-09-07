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

## Placeholder programmer art (human owner's own 2026-09-04 decision:
## no real weapon sprites exist yet in this project, unlike
## amazing-nauts' drawn part-based rig -- these describe a plain
## rectangle blade shape rebuilt at runtime by CharacterController._
## rebuild_weapon_visual(), swappable for a real Sprite2D texture later
## without redesigning the swing-angle system in character_controller.gd.
@export var visual_length: float = 40.0
@export var visual_width: float = 10.0
@export var visual_color: Color = Color.WHITE

## True only for Twin Daggers (2026-09-04, human owner's own
## clarification: "No caso da Twins Danger é uma arma, mas ambas as
## mãos" -- one weapon, held in both hands at once, unlike Iron
## Sword/Warhammer's single-hand grip). Draws a 2nd copy of the same
## blade shape at the off-hand position (CharacterController.
## _rebuild_weapon_visual()), mirrored, not a 2nd independent weapon.
@export var dual_wielded: bool = false
