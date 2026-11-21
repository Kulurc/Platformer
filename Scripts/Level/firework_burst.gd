class_name FireworkBurst
extends Node2D
## A one-shot firework explosion: a bright flash, then glowing streaks that fly out in a ring,
## droop, twinkle and fade. Spawned by KeyItem (firework look); frees itself when done.

const LIFE := 1.2

var _parts := []  # [pos, vel, colour, twinkle phase]
var _t := 0.0
var _flash := Color.WHITE
var _bloom := true
var _power := 1.0


## `flash` = the bright bloom at the centre (off for small pops).
static func spawn(near: Node, at: Vector2, colors: Array[Color], count: int, power: float, flash := true) -> void:
	var b := FireworkBurst.new()
	b._flash = colors[0] if not colors.is_empty() else Color.WHITE
	b._bloom = flash
	b._power = power
	var r := RandomNumberGenerator.new()
	r.randomize()
	for i in count:
		var a := TAU * i / float(count) + r.randf_range(-0.08, 0.08)
		var sp := r.randf_range(260.0, 420.0) * power
		if i % 3 == 0:
			sp *= 0.55  # an inner ring
		b._parts.append([at, Vector2(cos(a), sin(a)) * sp, colors[r.randi() % colors.size()], r.randf() * TAU])
	b.global_position = Vector2.ZERO
	var parent := near.get_parent() if near.get_parent() else near.get_tree().current_scene
	parent.add_child(b)
	b.set_meta(&"at", at)


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 26  # over the level and rock chunks, under the black screen (40) and speech (50)
	FastDraw.use_on(self)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func _process(dt: float) -> void:
	_t += dt
	for p in _parts:
		var v: Vector2 = p[1]
		v *= 1.0 - 2.6 * dt
		v.y += 160.0 * dt
		p[1] = v
		p[0] = (p[0] as Vector2) + v * dt
	queue_redraw()
	if _t >= LIFE:
		queue_free()


func _draw() -> void:
	var at: Vector2 = get_meta(&"at", Vector2.ZERO)
	var f := 1.0 - clampf(_t / 0.18, 0.0, 1.0)
	if f > 0.0 and _bloom:
		# a soft bloom of light rather than a hard disc
		for j in 4:
			FastDraw.circle(self, at, (40.0 + 30.0 * j) * (1.1 - f * 0.4), Color(_flash, 0.07 * f))
		FastDraw.circle(self, at, 14.0, Color(1, 1, 0.95, 0.5 * f))
	var fade := 1.0 - clampf((_t - LIFE * 0.4) / (LIFE * 0.6), 0.0, 1.0)
	for p in _parts:
		var c: Color = p[2]
		var pos: Vector2 = p[0]
		var v: Vector2 = p[1]
		var tw := 1.0
		if _t > LIFE * 0.45:
			tw = 0.5 + 0.5 * sin(_t * 40.0 + float(p[3]))  # twinkle as it dies
		var a := fade * tw
		draw_line(pos - v * 0.05, pos, Color(c, 0.45 * a), 1.2)
		FastDraw.circle(self, pos, 4.0 * _power + 1.0, Color(c, 0.12 * a))
		FastDraw.circle(self, pos, 1.4, Color(c.lightened(0.3), 0.9 * a))
