class_name CollisionShapeViewer
extends Node2D
## Dev-tool world-space overlay: draws every character's own
## CollisionShape2D (read live off the node, not a hardcoded radius, so
## it can't drift from Character.tscn) and the arena walls' collision
## rects. This is Phase 1's honest scope -- the analog of
## amazing-nauts' own Hitbox Viewer, which draws combat hitboxes/
## hurtboxes/beams that don't exist here yet. Expand or rename into a
## real Hitbox Viewer once Phase 2 ships hit detection; don't pretend
## Phase 1 already has one.
## Toggled via the debug_toggle_collision_viewer InputMap action (F1) or
## the Debug Overlay's `/collision` console command, which looks this
## node up via the "collision_viewer" group rather than a direct node
## reference -- same pattern CombatCamera/ArenaCamera's "local_camera"
## group already established.

const CHARACTER_COLOR := Color(0.2, 1.0, 0.3, 0.8)
const WALL_COLOR := Color(1.0, 0.6, 0.2, 0.8)
const LINE_WIDTH := 2.0

@export var characters_path: NodePath = ^"../Characters"
@export var walls_path: NodePath = ^"../Walls"


func _ready() -> void:
	visible = false
	add_to_group(&"collision_viewer")


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle_collision_viewer"):
		visible = not visible


func _draw() -> void:
	var characters := get_node_or_null(characters_path)
	if characters:
		for character in characters.get_children():
			_draw_character_shape(character)
	var walls := get_node_or_null(walls_path)
	if walls:
		for shape_owner in walls.get_children():
			_draw_wall_shape(shape_owner)


func _draw_character_shape(character: Node) -> void:
	var collision := character.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not collision or not collision.shape is CircleShape2D:
		return
	var circle := collision.shape as CircleShape2D
	draw_circle(
		to_local(character.global_position), circle.radius, CHARACTER_COLOR, false, LINE_WIDTH
	)


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
