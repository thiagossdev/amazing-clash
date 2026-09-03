class_name HitboxViewer
extends Node2D
## Dev-tool world-space overlay: draws every character's own hurtbox
## (always) and an active attacker's hitbox(es) (Phase 2a, melee only --
## Phase 2b adds projectile shapes), plus the arena walls' collision
## rects and each character's own physics CollisionShape2D circle.
## Pattern inherited from amazing-nauts' ui/debug/hitbox_viewer.gd,
## scoped down: no beams/armor-tinted hurtboxes -- neither exists in
## this project's design yet.
## Toggled via the debug_toggle_hitbox_viewer InputMap action (F1) or
## the Debug Overlay's `/hitbox` console command, which looks this node
## up via the "hitbox_viewer" group rather than a direct node
## reference -- same pattern ArenaCamera's "local_camera" group already
## established.

const CHARACTER_COLOR := Color(0.2, 1.0, 0.3, 0.8)
const WALL_COLOR := Color(1.0, 0.6, 0.2, 0.8)
const HURTBOX_COLOR := Color(0.2, 0.6, 1.0, 0.6)
const HITBOX_COLOR := Color(1.0, 0.2, 0.2, 0.6)
const LINE_WIDTH := 2.0

@export var characters_path: NodePath = ^"../Characters"
@export var walls_path: NodePath = ^"../Walls"


func _ready() -> void:
	visible = false
	add_to_group(&"hitbox_viewer")


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle_hitbox_viewer"):
		visible = not visible


func _draw() -> void:
	var characters := get_node_or_null(characters_path)
	if characters:
		for character in characters.get_children():
			if not character is CharacterController:
				continue
			_draw_character_shape(character)
			_draw_hurtbox(character)
			_draw_hitbox_if_active(character)
	var walls := get_node_or_null(walls_path)
	if walls:
		for shape_owner in walls.get_children():
			_draw_wall_shape(shape_owner)


func _draw_character_shape(character: CharacterController) -> void:
	var collision := character.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not collision or not collision.shape is CircleShape2D:
		return
	var circle := collision.shape as CircleShape2D
	draw_circle(
		to_local(character.global_position), circle.radius, CHARACTER_COLOR, false, LINE_WIDTH
	)


func _draw_hurtbox(character: CharacterController) -> void:
	var rect := HitDetection.hurtbox_rect(character.global_position, character.hurtbox_size)
	draw_rect(_to_local(rect), HURTBOX_COLOR, false, LINE_WIDTH)


func _draw_hitbox_if_active(character: CharacterController) -> void:
	if not character.action_fsm.is_hitbox_active() or not character.debug_attack_move:
		return
	for hit in character.debug_attack_move.hit_definitions:
		var rect := HitDetection.hitbox_rect(
			character.global_position, character.get_aim_direction(), hit
		)
		draw_rect(_to_local(rect), HITBOX_COLOR, false, LINE_WIDTH)


func _draw_wall_shape(collision: Node) -> void:
	if (
		not collision is CollisionShape2D
		or not (collision as CollisionShape2D).shape is RectangleShape2D
	):
		return
	var shape := (collision as CollisionShape2D).shape as RectangleShape2D
	var rect := Rect2(-shape.size / 2.0, shape.size)
	rect.position += to_local(collision.global_position)
	draw_rect(rect, WALL_COLOR, false, LINE_WIDTH)


func _to_local(world_rect: Rect2) -> Rect2:
	return Rect2(to_local(world_rect.position), world_rect.size)
