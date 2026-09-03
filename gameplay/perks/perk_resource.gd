class_name PerkResource
extends Resource
## Room Config's perk pick (Phase 9): a flat stat modifier applied once
## at spawn (net/player_spawner.gd) -- no DamagePipeline/HitDefinition
## changes, matching memory/plan.md's "Slices 8-10" Perks block. All 3
## multipliers default 1.0 (no-op), so an unregistered peer
## (net/dev_bootstrap.gd's headless test peers, which never touch
## LobbyState) spawns identically to before this phase.

@export var perk_name: String = ""
@export var max_health_multiplier: float = 1.0
@export var move_speed_multiplier: float = 1.0
@export var cooldown_multiplier: float = 1.0
