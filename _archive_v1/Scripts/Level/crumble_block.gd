@tool
class_name CrumbleBlock
extends Block
## Ground that gives way shortly after anyone stands on it, then reforms.
## The companion walks slowly, so these are where you have to reel them across - or catch them.

@export var crumble_delay := 0.55
@export var respawn_delay := 3.0

var _timer := -1.0
var _gone := false
var _gone_timer := 0.0
var _sensor: Area2D


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 2 | 4
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(size.x - 4.0, 8.0)
	cs.shape = r
	cs.position = Vector2(size.x * 0.5, -4.0)
	_sensor.add_child(cs)
	add_child(_sensor)


func _physics_process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	if _gone:
		_gone_timer -= dt
		if _gone_timer <= 0.0 and not _occupied():
			_gone = false
			_timer = -1.0
			_shape.set_deferred("disabled", false)
			queue_redraw()
		return
	if _timer < 0.0:
		if _sensor.has_overlapping_bodies():
			_timer = crumble_delay
	else:
		_timer -= dt
		queue_redraw()
		if _timer <= 0.0:
			_gone = true
			_gone_timer = respawn_delay
			_shape.set_deferred("disabled", true)
			queue_redraw()


func _occupied() -> bool:
	var r := Rect2(global_position - Vector2(24, 24), size + Vector2(48, 48))
	for b in get_tree().get_nodes_in_group("tether_bodies"):
		if r.has_point((b as Node2D).global_position):
			return true
	return false


func _draw() -> void:
	if _gone:
		draw_rect(Rect2(Vector2.ZERO, size), Color(color, 0.12), false, 1.0)
		return
	var shake := Vector2.ZERO
	if _timer >= 0.0:
		var k := 1.0 - _timer / crumble_delay
		shake = Vector2(randf_range(-2.0, 2.0) * k, randf_range(-1.0, 1.0) * k)
	var c := Color(0.36, 0.31, 0.29)
	draw_rect(Rect2(shake, size), c)
	draw_line(shake + Vector2(0, 1), shake + Vector2(size.x, 1), c.lightened(0.3), 2.0)
	var crack := c.darkened(0.45)
	draw_line(shake + Vector2(size.x * 0.3, 0), shake + Vector2(size.x * 0.4, size.y), crack, 1.5)
	draw_line(shake + Vector2(size.x * 0.7, 0), shake + Vector2(size.x * 0.6, size.y * 0.6), crack, 1.5)
