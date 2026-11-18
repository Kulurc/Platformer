@tool
class_name Block
extends StaticBody2D
## Placeholder solid geometry. Position = top-left corner; resize with `size` in the Inspector.

@export var size := Vector2(128, 32):
	set(v):
		size = v
		_sync()
@export var color := Color(0.2, 0.23, 0.3):
	set(v):
		color = v
		queue_redraw()

var _shape: CollisionShape2D


func _ready() -> void:
	_sync()


func _sync() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.shape = RectangleShape2D.new()
		add_child(_shape)  # no owner: rebuilt from `size`, never saved into the scene
	(_shape.shape as RectangleShape2D).size = size
	_shape.position = size * 0.5
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), color)
	draw_line(Vector2(0, 1), Vector2(size.x, 1), color.lightened(0.35), 2.0)
