class_name AbilityResource
extends Resource
## One equippable ability slot's data: a move (frame data + hit
## definitions, reusing MoveDefinition/HitDefinition from Phase 2
## unchanged) plus a cooldown independent of the shared melee/skillshot
## action layer -- ability_q and ability_e can each be on their own
## cooldown, cast independently of each other and of melee/skillshot.
## is_projectile picks which CombatResolver resolution path applies:
## false resolves as a melee hitbox (like debug_attack_move), true
## launches a Projectile (like debug_skillshot_move) using
## CombatResolver's existing PROJECTILE_SPEED/PROJECTILE_LIFETIME_FRAMES
## constants -- per-ability projectile speed/lifetime is a deferred
## refinement (see docs/blueprint/06-post-mvp-backlog.md), not needed
## to prove the framework with 2 test abilities.

@export var ability_name: String = ""
@export var move: MoveDefinition
@export var cooldown_frames: int = 0
@export var is_projectile: bool = false
