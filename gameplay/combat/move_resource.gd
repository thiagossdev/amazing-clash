class_name MoveDefinition
extends Resource
## One per attack/ability, holds frame data. Pattern inherited from
## amazing-nauts' gameplay/combat/move_resource.gd, scoped down to
## Phase 2: no movement_lock/armor/cancel_options yet -- this project's
## combat has no blocking, armor, or cancel-chain mechanic in its
## confirmed design; add these fields only when a real need for them
## exists, not speculatively.

@export var move_name: String = ""
@export var startup_frames: int = 0
@export var active_frames: int = 0
@export var recovery_frames: int = 0
@export var hit_definitions: Array[HitDefinition] = []
