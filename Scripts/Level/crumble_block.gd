@tool
class_name CrumbleBlock
extends Block
## A branch that gives way shortly after anyone stands on it, then grows back.
## The companion walks slowly, so these are where you have to reel them across - or catch them.
##
## Feel: it shakes (harder and harder) and sheds bark while it's about to go, then snaps into
## splinters and leaves; it fades back in when it reforms. Collision is always exactly `size`.
## Use the prefab Scenes/Prefabs/crumble_branch.tscn: edit the prefab and every branch follows.

## Seconds between someone landing on it and it snapping.
@export var crumble_delay := 0.55
## Seconds it stays gone (it also waits until nobody is standing where it would reappear).
@export var respawn_delay := 3.0

@export_group("Look")
@export var bark_color := Color("5a4632"):
	set(v):
		bark_color = v
		queue_redraw()
@export var bark_dark := Color("2e231a"):
	set(v):
		bark_dark = v
		queue_redraw()
@export var leaf_color := Color("5d7a3e"):
	set(v):
		leaf_color = v
		queue_redraw()
## Little twigs/leaves sticking up from the branch.
@export var twigs := true:
	set(v):
		twigs = v
		queue_redraw()

@export_group("Feel")
## Shake (px) right before it snaps. It builds up over `crumble_delay`.
@export_range(0.0, 8.0, 0.1) var shake_strength := 2.6
## Splinters + leaves when it snaps.
@export_range(0, 60) var break_particles := 16
## Seconds to fade back in when it reforms.
@export_range(0.0, 2.0, 0.05) var regrow_fade := 0.45

@export_group("Sound")
## Plays when someone lands on it and it starts to give (a creak). Optional.
@export var creak_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var creak_volume_db := -12.0
## Plays when it snaps. Optional.
@export var break_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var break_volume_db := -8.0
## Plays when it grows back. Optional.
@export var regrow_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var regrow_volume_db := -16.0

var _timer := -1.0
var _gone := false
var _gone_timer := 0.0
var _fade := 1.0
var _sensor: Area2D
var _bits: Array = []  # bark specks shed while shaking: [pos, vel, life]


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
	_tick_bits(dt)
	if _gone:
		_gone_timer -= dt
		if _gone_timer <= 0.0 and not _occupied():
			_gone = false
			_timer = -1.0
			_fade = 0.0
			_shape.set_deferred("disabled", false)
			_play(regrow_sound, regrow_volume_db)
		queue_redraw()
		return
	if _fade < 1.0:
		_fade = minf(_fade + dt / maxf(regrow_fade, 0.001), 1.0)
		queue_redraw()
	if _timer < 0.0:
		if _sensor.has_overlapping_bodies():
			_timer = crumble_delay
			_play(creak_sound, creak_volume_db)
	else:
		_timer -= dt
		if randf() < 0.5:
			_shed()
		queue_redraw()
		if _timer <= 0.0:
			_snap()


func _snap() -> void:
	_gone = true
	_gone_timer = respawn_delay
	_shape.set_deferred("disabled", true)
	if break_particles > 0:
		var cols: Array[Color] = [bark_color, bark_color.lightened(0.2), bark_dark, leaf_color, leaf_color.lightened(0.15)]
		KeyBurst.spawn(self, Rect2(global_position, size), cols, break_particles, 0.5, Vector2(2.5, 7.0), false)
	_play(break_sound, break_volume_db)
	queue_redraw()


func _shed() -> void:
	_bits.append([Vector2(randf_range(4.0, size.x - 4.0), size.y * 0.7), Vector2(randf_range(-20, 20), randf_range(10, 60)), 0.6])


func _tick_bits(dt: float) -> void:
	if _bits.is_empty():
		return
	for b in _bits:
		var v: Vector2 = b[1]
		v.y += 600.0 * dt
		b[1] = v
		b[0] = (b[0] as Vector2) + v * dt
		b[2] = float(b[2]) - dt
	_bits = _bits.filter(func(b: Array) -> bool: return float(b[2]) > 0.0)
	queue_redraw()


func _occupied() -> bool:
	var r := Rect2(global_position - Vector2(24, 24), size + Vector2(48, 48))
	for b in get_tree().get_nodes_in_group("tether_bodies"):
		if r.has_point((b as Node2D).global_position):
			return true
	return false


func _play(stream: AudioStream, db: float) -> void:
	if stream == null:
		return
	var sm := get_node_or_null("/root/SoundManager")
	if sm:
		sm.play_sound(stream, db)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	for b in _bits:
		draw_rect(Rect2(b[0] as Vector2, Vector2(2.5, 2.5)), Color(bark_dark, clampf(float(b[2]) * 2.0, 0.0, 1.0)))
	if _gone:
		if Engine.is_editor_hint():
			return
		# a faint ghost so you can tell where it will grow back
		draw_rect(Rect2(Vector2(0, size.y * 0.25), Vector2(size.x, size.y * 0.5)), Color(bark_color, 0.07))
		return
	var off := Vector2.ZERO
	var tilt := 0.0
	if _timer >= 0.0:
		var k := 1.0 - _timer / maxf(crumble_delay, 0.001)
		k = k * k
		off = Vector2(randf_range(-1.0, 1.0) * shake_strength * k, randf_range(0.0, 1.0) * shake_strength * 0.6 * k + k * 2.0)
		tilt = randf_range(-0.02, 0.02) * k
	draw_set_transform(off + size * 0.5, tilt, Vector2.ONE)
	_draw_branch(-size * 0.5, Color(1, 1, 1, _fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_branch(o: Vector2, m: Color) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(absf(global_position.x) * 7.0 + absf(global_position.y) * 3.0) if is_inside_tree() else 1
	var w := size.x
	var h := size.y
	var bark := bark_color * m
	var dark := bark_dark * m
	var lit := bark_color.lightened(0.28) * m
	# body: slightly uneven top/bottom edge so neighbouring pieces read as one rough branch
	var top := PackedVector2Array()
	var steps := maxi(int(w / 12.0), 2)
	for i in steps + 1:
		var x := w * i / float(steps)
		top.append(o + Vector2(x, r.randf_range(0.0, 2.0)))
	var bot := PackedVector2Array()
	for i in steps + 1:
		var x := w * (steps - i) / float(steps)
		bot.append(o + Vector2(x, h - r.randf_range(0.0, 3.0)))
	for i in steps:
		FastDraw.quad(self, PackedVector2Array([top[i], top[i + 1], bot[steps - i - 1], bot[steps - i]]),
			PackedColorArray([bark, bark, dark, dark]))
	# lit top edge
	for i in steps:
		draw_line(top[i] + Vector2(0, 1), top[i + 1] + Vector2(0, 1), lit, 2.0)
	# grain
	for g in 3:
		var y := h * (0.35 + 0.2 * g) + r.randf_range(-1.5, 1.5)
		var x0 := r.randf_range(0.0, w * 0.4)
		draw_line(o + Vector2(x0, y), o + Vector2(x0 + r.randf_range(w * 0.3, w * 0.6), y + r.randf_range(-1.5, 1.5)), Color(dark, 0.55 * m.a), 1.0)
	# a knot
	if r.randf() < 0.6:
		var kp := o + Vector2(r.randf_range(w * 0.2, w * 0.8), h * 0.55)
		draw_rect(Rect2(kp - Vector2(3, 2), Vector2(6, 4)), dark)
		draw_rect(Rect2(kp - Vector2(1.5, 1), Vector2(3, 2)), lit)
	# twigs + leaves
	if twigs and r.randf() < 0.75:
		var tx := r.randf_range(w * 0.15, w * 0.85)
		var tip := o + Vector2(tx + r.randf_range(-10, 10), -r.randf_range(9, 16))
		draw_line(o + Vector2(tx, 2), tip, dark, 2.0)
		var lc := leaf_color * m
		FastDraw.tri(self, tip, tip + Vector2(7, -3), tip + Vector2(3, 3), lc)
		FastDraw.tri(self, tip, tip + Vector2(-6, -4), tip + Vector2(-2, 3), lc.darkened(0.15))
	# moss specks on top
	for i in int(w / 20.0):
		FastDraw.circle(self, o + Vector2(r.randf_range(2.0, w - 2.0), r.randf_range(0.5, 2.5)), r.randf_range(1.5, 3.0), Color(leaf_color.darkened(0.1), 0.85 * m.a))
