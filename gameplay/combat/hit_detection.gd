class_name HitDetection
extends RefCounted
## Custom, deterministic hitbox-vs-hurtbox query -- explicitly outside
## Godot's general physics (no Area2D/body_entered), because those
## callbacks don't guarantee ordering between multiple hits landing on
## the same frame. Pure functions, no node dependency -- CombatResolver
## calls these once per server tick. Pattern inherited from
## amazing-nauts' gameplay/combat/hit_detection.gd.


## The hitbox's world-space rect for one HitDefinition, rotated by the
## attacker's current aim direction. Unlike amazing-nauts' side-view
## mirror-by-facing (a 1D flip: offset.x * facing), this project is
## top-down with a full 2D aim direction, so the offset is rotated by
## aim_direction's angle instead. The resulting rect stays axis-aligned
## (a true rotated hitbox is out of scope for Phase 2's test move) --
## good enough to validate that hit detection registers correctly; a
## precisely-rotated hitbox is a later refinement, not a blocker.
static func hitbox_rect(
	attacker_position: Vector2, aim_direction: Vector2, hit: HitDefinition
) -> Rect2:
	var rotated_offset := hit.hitbox_offset.rotated(aim_direction.angle())
	var center := attacker_position + rotated_offset
	return Rect2(center - hit.hitbox_size / 2.0, hit.hitbox_size)


## The defender's world-space hurtbox rect, centered on its position.
static func hurtbox_rect(defender_position: Vector2, hurtbox_size: Vector2) -> Rect2:
	return Rect2(defender_position - hurtbox_size / 2.0, hurtbox_size)


## A projectile's own hitbox rect, centered on its current position --
## unlike hitbox_rect() above, there's no attacker to offset from: the
## projectile already IS the traveling hit source.
static func projectile_hitbox_rect(projectile_position: Vector2, hitbox_size: Vector2) -> Rect2:
	return Rect2(projectile_position - hitbox_size / 2.0, hitbox_size)


## Deterministic per-tick query: does this hitbox connect with this
## hurtbox right now?
static func query(hitbox: Rect2, hurtbox: Rect2) -> bool:
	return hitbox.intersects(hurtbox)


## Phase 11 (lag compensation): the latest recorded position at or
## before target_tick from `history` -- an Array of
## `{"tick": int, "position": Vector2}` entries in ascending tick order
## (CharacterController._position_history's own shape; see that file's
## position_at_tick()). Pure and history-shape-agnostic on purpose, so
## it's unit-testable without a live character/network. Falls back to
## `fallback` when every entry is newer than target_tick (a very fresh
## spawn) or history is empty.
static func position_at_or_before(history: Array, target_tick: int, fallback: Vector2) -> Vector2:
	var result := fallback
	for entry in history:
		if entry["tick"] > target_tick:
			break
		result = entry["position"]
	return result
