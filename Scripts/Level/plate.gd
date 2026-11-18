@tool
class_name Plate
extends Area2D
## Pressure plate. Pressed while either body stands on it. Position = top-left of the
## trigger area; the plate itself is drawn on the bottom edge (put that on the floor).

@export var size := Vector2(64, 24):
	set(v):
		size = v
		_sync()

var pressed := false:
	set(v):
		if v != pressed:
			pressed = v
			queue_redraw()

var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_sync()


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


func _physics_process(_dt: float) -> void:
	if not Engine.is_editor_hint():
		pressed = has_overlapping_bodies()


func _draw() -> void:
	var h := 3.0 if pressed else 6.0
	var c := Color(0.55, 0.85, 1.0) if pressed else Color(0.45, 0.5, 0.6)
	draw_rect(Rect2(Vector2(0, size.y - h), Vector2(size.x, h)), c)
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.85, 1.0, 0.3), false, 1.0)
