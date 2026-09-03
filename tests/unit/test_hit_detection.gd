extends GutTest


func _make_hit(offset: Vector2, size: Vector2) -> HitDefinition:
	var hit := HitDefinition.new()
	hit.hitbox_offset = offset
	hit.hitbox_size = size
	return hit


func test_hitbox_rect_centers_on_attacker_plus_offset_when_facing_right() -> void:
	var hit := _make_hit(Vector2(50, 0), Vector2(20, 20))
	var rect := HitDetection.hitbox_rect(Vector2(100, 100), Vector2.RIGHT, hit)
	assert_eq(rect.get_center(), Vector2(150, 100))


func test_hitbox_rect_rotates_offset_by_aim_direction() -> void:
	var hit := _make_hit(Vector2(50, 0), Vector2(20, 20))
	var rect := HitDetection.hitbox_rect(Vector2(100, 100), Vector2.DOWN, hit)
	assert_almost_eq(rect.get_center().x, 100.0, 0.01)
	assert_almost_eq(rect.get_center().y, 150.0, 0.01)


func test_hurtbox_rect_centers_on_defender() -> void:
	var rect := HitDetection.hurtbox_rect(Vector2(200, 200), Vector2(40, 40))
	assert_eq(rect.get_center(), Vector2(200, 200))


func test_projectile_hitbox_rect_centers_on_projectile_position() -> void:
	var rect := HitDetection.projectile_hitbox_rect(Vector2(300, 300), Vector2(20, 20))
	assert_eq(rect.get_center(), Vector2(300, 300))


func test_query_true_when_boxes_overlap() -> void:
	var hitbox := Rect2(Vector2(0, 0), Vector2(50, 50))
	var hurtbox := Rect2(Vector2(25, 25), Vector2(50, 50))
	assert_true(HitDetection.query(hitbox, hurtbox))


func test_query_false_when_boxes_do_not_overlap() -> void:
	var hitbox := Rect2(Vector2(0, 0), Vector2(50, 50))
	var hurtbox := Rect2(Vector2(500, 500), Vector2(50, 50))
	assert_false(HitDetection.query(hitbox, hurtbox))


func _history(entries: Array) -> Array:
	var history: Array = []
	for entry in entries:
		history.append({"tick": entry[0], "position": entry[1]})
	return history


func test_position_at_or_before_returns_the_exact_tick_match() -> void:
	var history := _history([[10, Vector2(1, 1)], [11, Vector2(2, 2)], [12, Vector2(3, 3)]])
	assert_eq(HitDetection.position_at_or_before(history, 11, Vector2.ZERO), Vector2(2, 2))


func test_position_at_or_before_returns_the_latest_entry_strictly_before_target() -> void:
	var history := _history([[10, Vector2(1, 1)], [12, Vector2(3, 3)], [14, Vector2(5, 5)]])
	assert_eq(
		HitDetection.position_at_or_before(history, 13, Vector2.ZERO),
		Vector2(3, 3),
		"tick 13 has no exact entry -- should return tick 12's, not tick 14's"
	)


func test_position_at_or_before_falls_back_when_every_entry_is_newer() -> void:
	var history := _history([[20, Vector2(9, 9)]])
	assert_eq(HitDetection.position_at_or_before(history, 5, Vector2(-1, -1)), Vector2(-1, -1))


func test_position_at_or_before_falls_back_on_empty_history() -> void:
	assert_eq(HitDetection.position_at_or_before([], 5, Vector2(-1, -1)), Vector2(-1, -1))
