@tool
class_name Gate
extends Block
## A Block that is open only while its Plate is pressed (plus a short grace), and never
## closes on top of someone.

@export var plate_path: NodePath
@export var close_delay := 0.0   ## >0 lets a leader slip through while the partner merely walks over the plate

var _plate: Plate
var _open := false
var _close_timer := 0.0


func _ready() -> void:
	super()
	if not Engine.is_editor_hint() and plate_path:
		_plate = get_node(plate_path) as Plate


func _physics_process(dt: float) -> void:
	if Engine.is_editor_hint() or _plate == null:
		return
	if _plate.pressed:
		_close_timer = close_delay
		_set_open(true)
	elif _open:
		_close_timer -= dt
		if _close_timer <= 0.0 and not _occupied():
			_set_open(false)


func _set_open(v: bool) -> void:
	if v == _open:
		return
	_open = v
	_shape.set_deferred("disabled", v)
	queue_redraw()


func _occupied() -> bool:
	var r := Rect2(global_position - Vector2(14, 0), size + Vector2(28, 0))
	for body in get_tree().get_nodes_in_group("tether_bodies"):
		if r.has_point((body as Node2D).global_position):
			return true
	return false


func _draw() -> void:
	if _open:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.85, 1.0, 0.25), false, 1.0)
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.36, 0.46))
	var y := 12.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.2, 0.24, 0.32), 2.0)
		y += 24.0
