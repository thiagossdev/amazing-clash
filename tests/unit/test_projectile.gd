extends GutTest
## Projectile extends Node2D (not RefCounted), so every instance created
## in these tests is wrapped in autofree() -- otherwise it leaks as an
## orphan node GUT's own summary flags at the end of the run.


func _make_projectile() -> Projectile:
	return autofree(Projectile.new())


func test_configure_sets_spawn_position() -> void:
	var projectile := _make_projectile()
	projectile.configure(1, null, Vector2(100, 100), Vector2.RIGHT, 500.0, 60, [])
	assert_eq(projectile.global_position, Vector2(100, 100))


func test_advance_frame_moves_in_direction_at_speed() -> void:
	var projectile := _make_projectile()
	projectile.configure(1, null, Vector2.ZERO, Vector2.RIGHT, 100.0, 60, [])
	projectile.advance_frame(1.0)
	assert_eq(projectile.global_position, Vector2(100, 0))


func test_zero_direction_defaults_to_right() -> void:
	var projectile := _make_projectile()
	projectile.configure(1, null, Vector2.ZERO, Vector2.ZERO, 100.0, 60, [])
	projectile.advance_frame(1.0)
	assert_eq(projectile.global_position, Vector2(100, 0))


func test_direction_is_normalized() -> void:
	var projectile := _make_projectile()
	projectile.configure(1, null, Vector2.ZERO, Vector2(10, 0), 100.0, 60, [])
	projectile.advance_frame(1.0)
	assert_eq(
		projectile.global_position, Vector2(100, 0), "a 10x direction must not act like 10x speed"
	)


func test_advance_frame_returns_true_while_lifetime_remains() -> void:
	var projectile := _make_projectile()
	projectile.configure(1, null, Vector2.ZERO, Vector2.RIGHT, 100.0, 2, [])
	assert_true(projectile.advance_frame(1.0 / 60.0))


func test_advance_frame_returns_false_once_lifetime_expires() -> void:
	var projectile := _make_projectile()
	projectile.configure(1, null, Vector2.ZERO, Vector2.RIGHT, 100.0, 2, [])
	projectile.advance_frame(1.0 / 60.0)
	assert_false(projectile.advance_frame(1.0 / 60.0))


func test_configure_resets_already_hit() -> void:
	var projectile := _make_projectile()
	projectile.configure(1, null, Vector2.ZERO, Vector2.RIGHT, 100.0, 60, [])
	projectile.already_hit.append("stale_defender")
	projectile.configure(2, null, Vector2.ZERO, Vector2.RIGHT, 100.0, 60, [])
	assert_eq(projectile.already_hit, [])
