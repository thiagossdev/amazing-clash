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


func test_query_true_when_boxes_overlap() -> void:
	var hitbox := Rect2(Vector2(0, 0), Vector2(50, 50))
	var hurtbox := Rect2(Vector2(25, 25), Vector2(50, 50))
	assert_true(HitDetection.query(hitbox, hurtbox))


func test_query_false_when_boxes_do_not_overlap() -> void:
	var hitbox := Rect2(Vector2(0, 0), Vector2(50, 50))
	var hurtbox := Rect2(Vector2(500, 500), Vector2(50, 50))
	assert_false(HitDetection.query(hitbox, hurtbox))
