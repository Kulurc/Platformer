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
		_drop_stray_shapes()
		_shape = CollisionShape2D.new()
		_shape.shape = RectangleShape2D.new()
		# Internal child: not shown in the Scene dock, not copied by Ctrl+D, never saved.
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
	(_shape.shape as RectangleShape2D).size = size
	_shape.position = size * 0.5
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), color)
	draw_line(Vector2(0, 1), Vector2(size.x, 1), color.lightened(0.35), 2.0)

## Older versions added this shape as a normal child, so Ctrl+D copied it and every
## duplicate kept a stale extra shape. Remove any unowned leftovers (never your own nodes).
func _drop_stray_shapes() -> void:
	for c in get_children():
		if c is CollisionShape2D and c.owner == null and c != _shape:
			remove_child(c)
			c.queue_free()
