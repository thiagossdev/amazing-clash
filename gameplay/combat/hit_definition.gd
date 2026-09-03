class_name HitDefinition
extends Resource
## One hitbox inside a move. A single MoveDefinition can hold multiple
## HitDefinitions. Pattern inherited from amazing-nauts'
## gameplay/combat/hit_definition.gd, scoped down to Phase 2: no
## knockback/causes_knockdown/applies_buff yet -- a defender freezes in
## place for hitstun_frames (no directional push) until knockback is
## actually designed and tuned, not copied in as unused data.

@export var damage: float = 0.0
@export var hitstun_frames: int = 0
## Offset from the attacker's position, rotated by aim_direction at
## query time -- see gameplay/combat/hit_detection.gd. Unlike
## amazing-nauts' side-view mirror-by-facing (a 1D flip), this project's
## top-down aim is a full 2D direction, so the offset is rotated, not
## mirrored.
@export var hitbox_offset: Vector2 = Vector2.ZERO
@export var hitbox_size: Vector2 = Vector2.ZERO
## Both characters freeze (no movement/action processing) for this many
## frames on a confirmed hit -- see CombatResolver.
@export var hitstop_frames: int = 0
