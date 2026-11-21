@tool
class_name KeyItem
extends Area2D
## A key that clears the way. When a character touches it, it fires at each of its `targets`
## and each target is destroyed for good (it stays gone after deaths/respawns).
##   FIREWORK look: a little rocket. It launches, arcs over to the target leaving a trail of
##                  sparks, and explodes there in a firework burst.
##   GEM look:      a glowing diamond; a spark runs along the connection instead.
## Targets with a `break_apart()` method (e.g. Boulder) break in their own way; others burst
## into fragments in their own colours.
##
## HOW TO CONNECT: select the key, then drag obstacles from the Scene dock onto the `targets`
## list in the Inspector (add a slot first with "Add Element"). A dashed line in the editor
## shows each connection; red = the target is missing.
## Use the prefab Scenes/Prefabs/firework_key.tscn: edit the prefab and every key follows.

enum ActivatedBy { EITHER, CONTROLLED, BOTH }
enum Look { FIREWORK, GEM }

## Obstacles this key removes. Drag nodes from the Scene dock onto the slots.
@export var targets: Array[NodePath] = []:
	set(v):
		targets = v
		queue_redraw()
## EITHER: whichever character touches it. CONTROLLED: only the one you're playing.
## BOTH: only once both characters are touching it.
@export var activated_by := ActivatedBy.EITHER
## Debug: tick to switch this key OFF while testing (its targets stay solid).
@export var debug := false:
	set(v):
		debug = v
		queue_redraw()

@export_group("Look")
@export var look := Look.FIREWORK:
	set(v):
		look = v
		queue_redraw()
## FIREWORK: the rocket body - dark, like the characters' silhouettes.
@export var color := Color("1b1f1b"):
	set(v):
		color = v
		queue_redraw()
## The light colour: the fuse glow, the rim light, the spark trail (and the GEM look).
@export var accent := Color("ffc44d"):
	set(v):
		accent = v
		queue_redraw()
## Colours of the firework explosion.
## FIREWORK: the paper band around the rocket (kept dull so the glow does the talking).
@export var band_color := Color("5b2c26"):
	set(v):
		band_color = v
		queue_redraw()
@export var burst_colors: Array[Color] = [Color("ffd36b"), Color("fff1cf"), Color("ffad5c")]
@export_range(4.0, 40.0, 0.5) var radius := 9.0:
	set(v):
		radius = v
		_sync()
## Gentle hover: px up/down and speed.
@export_range(0.0, 12.0, 0.5) var bob_height := 3.0
@export_range(0.0, 6.0, 0.1) var bob_speed := 2.2

@export_group("Effect")
## Seconds for the rocket (or spark) to reach the obstacle. 0 = the obstacle breaks instantly.
@export_range(0.0, 3.0, 0.05) var travel_time := 0.7
## How high the rocket arcs on its way (px above the straight line).
@export_range(0.0, 600.0, 5.0) var arc_height := 170.0
## Screen shake when an obstacle breaks (px). Keep it small.
@export_range(0.0, 20.0, 0.5) var shake := 2.0
## Fragments per obstacle without its own break (bigger obstacles use up to this many).
@export_range(4, 120) var fragments := 36
## Streaks in the firework explosion.
@export_range(8, 160) var burst_sparks := 48

@export_group("Sound")
## Plays when a character touches (collects) the key.
@export var collect_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var collect_volume_db := -10.0
## Plays while the rocket flies (a whistle/fizz). Optional.
@export var launch_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var launch_volume_db := -12.0
## Plays when it hits and the obstacle is destroyed.
@export var impact_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var impact_volume_db := -6.0

var _shape: CollisionShape2D
var _t := 0.0
var _used := false
var _fly := -1.0  # 0..1 while the rocket/spark travels, else -1


func _ready() -> void:
	FastDraw.use_on(self)
	collision_layer = 0
	collision_mask = 2  # characters
	_sync()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _sync() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.shape = CircleShape2D.new()
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
	(_shape.shape as CircleShape2D).radius = radius * 1.8  # a forgiving touch area
	queue_redraw()


func _process(dt: float) -> void:
	_t += dt
	if _fly >= 0.0:
		_fly = minf(_fly + dt / maxf(travel_time, 0.001), 1.0)
	queue_redraw()


# ---------------------------------------------------------------- trigger

func _on_body_entered(body: Node2D) -> void:
	if _used or debug or not body is Character:
		return
	match activated_by:
		ActivatedBy.CONTROLLED:
			if not (body as Character).controlled:
				return
		ActivatedBy.BOTH:
			var inside := {body: true}
			for b in get_overlapping_bodies():
				if b is Character:
					inside[b] = true
			if inside.size() < 2:
				return
	_trigger()


## Fire the key from code or a DialogueCall (method: "trigger_key").
func trigger_key() -> void:
	if not _used:
		_trigger()


func _trigger() -> void:
	_used = true
	set_deferred("monitoring", false)
	_play(collect_sound, collect_volume_db)
	if look == Look.FIREWORK:
		FireworkBurst.spawn(self, global_position + Vector2(0, radius), [accent, Color(1, 0.95, 0.8)] as Array[Color], 12, 0.25, false)
	else:
		var pop: Array[Color] = [accent, accent.lightened(0.4)]
		KeyBurst.spawn(self, Rect2(global_position - Vector2(radius, radius), Vector2(radius, radius) * 2.0), pop, 10, 0.6)
	if travel_time > 0.0:
		_fly = 0.0
		_play(launch_sound, launch_volume_db)
		await get_tree().create_timer(travel_time, false).timeout
	for path in targets:
		var n := get_node_or_null(path)
		if n is Node2D:
			if look == Look.FIREWORK:
				FireworkBurst.spawn(self, _target_rect(n as Node2D).get_center(), burst_colors, burst_sparks, 1.0)
			_break(n as Node2D)
	var rig := get_tree().get_first_node_in_group(&"tether_rig")
	if rig and shake > 0.0:
		rig.shake_camera(shake)
	_play(impact_sound, impact_volume_db)
	queue_free()


func _break(n: Node2D) -> void:
	var was_block := n is Block
	var tree := n.get_tree()
	if n.has_method(&"break_apart"):
		n.call(&"break_apart")
	else:
		var rect := _target_rect(n)
		var cols: Array[Color] = [Color(0.25, 0.27, 0.32), Color(0.35, 0.37, 0.42)]
		if n is Block:
			var b := n as Block
			if b.look == Block.Look.MEADOW:
				cols = [Block.meadow_top, Block.meadow_body, Block.meadow_body.darkened(0.3)]
			else:
				cols = [b.color, b.color.lightened(0.25), b.color.darkened(0.2)]
		var count := clampi(int(rect.get_area() / 160.0), 8, fragments)
		KeyBurst.spawn(n, rect, cols, count, 1.0)
		n.queue_free()
	if was_block:
		(func() -> void: Block.redraw_all(tree)).call_deferred()  # neighbours redraw their exposed edges


func _play(stream: AudioStream, db: float) -> void:
	if stream == null:
		return
	var sm := get_node_or_null("/root/SoundManager")
	if sm:
		sm.play_sound(stream, db)


## World-space rectangle of a target (Blocks/Zones/etc. use `size`, others a small box).
func _target_rect(n: Node2D) -> Rect2:
	var sz = n.get("size")
	if sz is Vector2:
		return Rect2(n.global_position, sz)
	return Rect2(n.global_position - Vector2(16, 16), Vector2(32, 32))


## Point along the rocket's arc (local space), t = 0..1.
func _arc(to: Vector2, t: float) -> Vector2:
	var ctrl := to * 0.5 + Vector2(0, -arc_height)
	return (1.0 - t) * (1.0 - t) * Vector2.ZERO + 2.0 * (1.0 - t) * t * ctrl + t * t * to


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var editor := Engine.is_editor_hint()
	for path in targets:
		var n := get_node_or_null(path) as Node2D
		if n == null:
			if editor:
				draw_line(Vector2(-6, -6), Vector2(6, 6), Color(1, 0.3, 0.3), 2.0)
				draw_line(Vector2(-6, 6), Vector2(6, -6), Color(1, 0.3, 0.3), 2.0)
				draw_string(ThemeDB.fallback_font, Vector2(10, -10), "missing target", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.4, 0.4))
			continue
		var to := _target_rect(n).get_center() - global_position
		if editor:
			_dashed(Vector2.ZERO, to, Color(accent, 0.8))
			var r := _target_rect(n)
			draw_rect(Rect2(r.position - global_position, r.size), Color(accent, 0.7), false, 1.5)
		elif _fly >= 0.0:
			if look == Look.FIREWORK:
				_draw_flight(to)
			else:
				var p := to * _fly
				draw_line(Vector2.ZERO, p, Color(accent, 0.35 * (1.0 - _fly * 0.5)), 2.0)
				FastDraw.circle(self, p, 9.0, Color(accent, 0.25))
				FastDraw.circle(self, p, 3.5, Color(1, 1, 0.9, 0.95))
	if _used:
		return
	var y := sin(_t * bob_speed) * bob_height
	if look == Look.FIREWORK:
		_draw_rocket(Vector2(0, y), 0.0, true)
	else:
		_draw_gem(Vector2(0, y))
	if editor and debug:
		draw_string(ThemeDB.fallback_font, Vector2(-30, -radius * 2.6 - 6), "DEBUG: OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.4, 0.4))


func _draw_flight(to: Vector2) -> void:
	# sparkly trail behind the rocket
	var steps := 18
	for i in steps:
		var tt := _fly - 0.3 * i / float(steps)
		if tt < 0.0:
			break
		var p := _arc(to, tt)
		var k := 1.0 - i / float(steps)
		var jitter := Vector2(sin(_t * 50.0 + i * 1.7), cos(_t * 43.0 + i * 2.3)) * 3.0 * (1.0 - k)
		FastDraw.circle(self, p + jitter, 6.0 * k + 1.0, Color(accent, 0.08 * k))
		FastDraw.circle(self, p + jitter, 1.3 * k + 0.5, Color(1, 0.93, 0.75, 0.75 * k))
	var p0 := _arc(to, _fly)
	var p1 := _arc(to, minf(_fly + 0.02, 1.0))
	var ang := (p1 - p0).angle() + PI * 0.5 if p1 != p0 else 0.0
	_draw_rocket(p0, ang, false)


## The rocket, pointing up (rot 0): a dark silhouette, lit only by its own fuse/flame and a
## faint rim of light - the same language as the characters (dark bodies, glowing eyes).
func _draw_rocket(c: Vector2, rot: float, idle: bool) -> void:
	var s := radius / 9.0
	draw_set_transform(c, rot, Vector2(s, s))
	var g := 0.6 + 0.4 * sin(_t * 17.0) * sin(_t * 5.3)  # fuse flicker
	var glow_at := Vector2(-1.5, 13.0) if idle else Vector2(0, 11.0)
	var glow := 1.0 if not idle else 0.55 + 0.25 * g
	# warm light the fuse/flame throws around it
	FastDraw.circle(self, glow_at, 26.0, Color(accent, 0.07 * glow))
	FastDraw.circle(self, glow_at, 13.0, Color(accent, 0.12 * glow))
	if idle:
		# guide stick, planted in the grass
		draw_rect(Rect2(Vector2(2.5, 4.0), Vector2(1.6, 20.0)), color)
	# body + cone, one dark shape
	draw_rect(Rect2(Vector2(-4.0, -8.0), Vector2(8.0, 16.0)), color)
	FastDraw.tri(self, Vector2(-4.6, -8.0), Vector2(4.6, -8.0), Vector2(0, -16.0), color)
	# dull paper band
	draw_rect(Rect2(Vector2(-4.0, -2.0), Vector2(8.0, 4.0)), band_color)
	# rim light on the side facing the glow below, and a hint on the cone
	draw_rect(Rect2(Vector2(-4.0, -8.0), Vector2(1.2, 16.0)), Color(accent, 0.22 + 0.15 * glow))
	draw_line(Vector2(-4.4, -8.2), Vector2(-0.3, -15.6), Color(accent, 0.18), 1.0)
	if idle:
		# fuse and its spark
		draw_line(Vector2(0, 8.0), Vector2(-1.5, 12.5), color, 1.2)
		FastDraw.circle(self, Vector2(-1.5, 13.0), 2.2 * g + 1.0, Color(1.0, 0.92, 0.7, 0.9))
		if sin(_t * 9.0) > 0.3:
			var a := _t * 7.0
			FastDraw.circle(self, Vector2(-1.5, 13.0) + Vector2(cos(a), sin(a) * 0.6 - 0.8) * 5.0, 0.9, Color(1, 0.9, 0.6, 0.8))
	else:
		# exhaust flame
		var fl := 7.0 + 3.0 * sin(_t * 60.0)
		FastDraw.tri(self, Vector2(-2.6, 8.0), Vector2(2.6, 8.0), Vector2(0, 8.0 + fl), Color(1.0, 0.9, 0.6, 0.95))
		FastDraw.circle(self, Vector2(0, 10.0), 3.0, Color(1, 0.97, 0.85))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_gem(c: Vector2) -> void:
	var pulse := 0.85 + 0.15 * sin(_t * 3.0)
	FastDraw.circle(self, c, radius * 2.4, Color(accent, 0.10 * pulse))
	FastDraw.circle(self, c, radius * 1.6, Color(accent, 0.16 * pulse))
	var r := radius
	FastDraw.quad(self, PackedVector2Array([c + Vector2(0, -r * 1.25), c + Vector2(r, 0), c + Vector2(0, r * 1.25), c + Vector2(-r, 0)]),
		PackedColorArray([accent]))
	FastDraw.quad(self, PackedVector2Array([c + Vector2(0, -r * 0.7), c + Vector2(r * 0.45, 0), c + Vector2(0, r * 0.2), c + Vector2(-r * 0.45, 0)]),
		PackedColorArray([accent.lightened(0.55)]))


func _dashed(a: Vector2, b: Vector2, c: Color) -> void:
	var length := a.distance_to(b)
	if length < 1.0:
		return
	var d := (b - a) / length
	var s := 0.0
	while s < length:
		draw_line(a + d * s, a + d * minf(s + 8.0, length), c, 1.5)
		s += 14.0
