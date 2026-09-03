class_name Projectile
extends Node2D
## Deterministic traveling entity for the skillshot: movement is
## `position += direction * speed * delta`, entirely derivable from the
## parameters given at configure() time -- so replication only needs one
## spawn broadcast (see gameplay/combat/combat_resolver.gd), no per-tick
## position sync. Every peer's own local instance advances identically;
## only the server resolves hits (the client never predicts damage
## taken). Pattern inherited from amazing-nauts'
## gameplay/projectiles/projectile.gd, scoped down to Phase 2b: no
## pooling, no piercing -- a single test skillshot doesn't yet justify
## either, see docs/blueprint/06-post-mvp-backlog.md.

## Stable id assigned by whoever spawns this instance, shared across
## peers via the spawn RPC.
var network_id: int = 0
var caster: CharacterController
var direction: Vector2 = Vector2.RIGHT
var speed: float = 0.0
var remaining_lifetime_frames: int = 0
var hit_definitions: Array[HitDefinition] = []
## Server-only bookkeeping: defenders this instance has already hit.
## Non-piercing in this first pass -- a hit ends the instance
## immediately (see CombatResolver), so this only ever holds at most
## one entry, but it's still checked before applying a hit so the same
## instance can never double-hit the same defender within one tick's
## multi-defender scan.
var already_hit: Array = []


## Resets this instance to a fresh cast's parameters.
func configure(
	new_network_id: int,
	new_caster: CharacterController,
	spawn_position: Vector2,
	new_direction: Vector2,
	new_speed: float,
	lifetime_frames: int,
	new_hit_definitions: Array[HitDefinition]
) -> void:
	network_id = new_network_id
	caster = new_caster
	global_position = spawn_position
	direction = new_direction.normalized() if not new_direction.is_zero_approx() else Vector2.RIGHT
	speed = new_speed
	remaining_lifetime_frames = lifetime_frames
	hit_definitions = new_hit_definitions
	already_hit.clear()


## Advances by one physics tick. Returns false once lifetime has
## expired (the caller should free this instance), true while still
## alive. Pure with respect to delta -- no scene-tree dependency beyond
## the position/global_position Node2D already provides, so it's
## directly testable via Projectile.new() with no live tree.
func advance_frame(delta: float) -> bool:
	global_position += direction * speed * delta
	remaining_lifetime_frames -= 1
	return remaining_lifetime_frames > 0
