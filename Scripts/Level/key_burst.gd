class_name KeyBurst
extends Node2D
## A one-shot "mini explosion": a quick flash of the shape, then square fragments that fly out,
## spin, fall and fade. Spawned by KeyItem; frees itself when done. Pauses with the game.

const LIFE := 0.9
const GRAVITY := 900.0

var _rect: Rect2
var _cols: Array[Color] = []
var _t := 0.0
var _parts := []  # [pos, vel, rot, spin, size, colour, shape jitter]
var _power := 1.0
var _flash := true


## Spawn a burst over `rect` (world space) next to `near` in the scene tree.
## `sizes` = smallest/biggest fragment size in px.
static func spawn(near: Node, rect: Rect2, colors: Array[Color], count: int, power: float, sizes := Vector2(3.0, 9.0), flash := true) -> void:
	var b := KeyBurst.new()
	b._rect = rect
	b._cols = colors
	b._power = power
	b._flash = flash
	var r := RandomNumberGenerator.new()
	r.randomize()
	var center := rect.get_center()
	for i in count:
		var p := Vector2(r.randf_range(rect.position.x, rect.end.x), r.randf_range(rect.position.y, rect.end.y))
		var out := (p - center).normalized() if p.distance_to(center) > 1.0 else Vector2.UP
		var vel := (out * r.randf_range(120.0, 340.0) + Vector2(0, r.randf_range(-260.0, -80.0))) * power
		var sz := r.randf_range(sizes.x, sizes.y) * (0.6 + 0.4 * power)
		b._parts.append([p, vel, r.randf() * TAU, r.randf_range(-9.0, 9.0), sz, colors[r.randi() % colors.size()], r.randf_range(-0.6, 0.6)])
	var parent := near.get_parent() if near.get_parent() else near.get_tree().current_scene
	parent.add_child(b)


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 25  # over the level, under the black screen (40) and speech (50)


func _process(dt: float) -> void:
	_t += dt
	for p in _parts:
		var v: Vector2 = p[1]
		v.y += GRAVITY * dt
		v *= 1.0 - 1.5 * dt  # air drag
		p[1] = v
		p[0] = (p[0] as Vector2) + v * dt
		p[2] = float(p[2]) + float(p[3]) * dt
	queue_redraw()
	if _t >= LIFE:
		queue_free()


func _draw() -> void:
	# flash: the shape lights up and grows a little, very briefly
	var f := 1.0 - clampf(_t / 0.16, 0.0, 1.0)
	if f > 0.0 and _flash:
		var grow := (1.0 - f) * 10.0 * _power
		draw_rect(_rect.grow(grow), Color(1.0, 0.97, 0.85, 0.55 * f))
	var fade := 1.0 - clampf((_t - LIFE * 0.45) / (LIFE * 0.55), 0.0, 1.0)
	for p in _parts:
		var c: Color = p[5]
		var s: float = p[4] * (0.5 + 0.5 * fade)
		var rot: float = p[2]
		var pos: Vector2 = p[0]
		var pts := PackedVector2Array()
		var sh: float = p[6]
		for k in 4:  # an irregular shard, not a square
			var rr := s * (1.0 + sh * (0.55 if k % 2 == 0 else -0.35))
			pts.append(pos + Vector2(rr, 0).rotated(rot + k * PI * 0.5 + sh * 0.4 * (k - 1.5)))
		FastDraw.quad(self, pts, PackedColorArray([Color(c, c.a * fade)]))
