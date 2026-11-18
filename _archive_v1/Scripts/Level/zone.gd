@tool
class_name Zone
extends Area2D
## Trigger volume. Position = top-left corner. Bottom edge should sit on the floor
## for checkpoints (the spawn point is just above it).

enum Kind { KILL, CHECKPOINT, GOAL }

@export var kind := Kind.CHECKPOINT:
	set(v):
		kind = v
		queue_redraw()
@export var size := Vector2(64, 140):
	set(v):
		size = v
		_sync()

var activated := false:
	set(v):
		activated = v
		queue_redraw()

var _shape: CollisionShape2D
var _time := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 | 4
	add_to_group("zones")
	_sync()


func _process(dt: float) -> void:
	if kind == Kind.GOAL and not Engine.is_editor_hint():
		_time += dt
		queue_redraw()


func _sync() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.shape = RectangleShape2D.new()
		add_child(_shape)
	(_shape.shape as RectangleShape2D).size = size
	_shape.position = size * 0.5
	queue_redraw()


func spawn_point() -> Vector2:
	return global_position + Vector2(size.x * 0.5, size.y - 22.0)


func _draw() -> void:
	var editor := Engine.is_editor_hint()
	match kind:
		Kind.KILL:
			if editor:
				draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.2, 0.2, 0.15))
		Kind.CHECKPOINT:
			if editor:
				draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 0.8, 1.0, 0.25), false, 1.0)
			var base := Vector2(size.x * 0.5, size.y)
			var c := Color(0.55, 0.85, 1.0, 0.9) if activated else Color(0.5, 0.55, 0.65, 0.5)
			draw_line(base, base + Vector2(0, -44), c, 2.0)
			draw_colored_polygon(PackedVector2Array([
				base + Vector2(0, -44), base + Vector2(14, -38), base + Vector2(0, -32)]), c)
		Kind.GOAL:
			var pulse := 0.5 + 0.5 * sin(_time * 1.5)
			for i in 4:
				var inset := Vector2(i * 10.0, i * 10.0)
				draw_rect(Rect2(inset, size - inset * 2.0), Color(0.85, 0.9, 1.0, 0.035 + 0.02 * pulse))
			if editor:
				draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.9, 1.0, 0.4), false, 1.0)
