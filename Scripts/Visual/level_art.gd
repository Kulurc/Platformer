@tool
class_name LevelArt
extends Node2D
## Drop-in art direction for a level (Level1_Visual uses the midday-meadow settings).
## Purely visual: it never moves, resizes or adds collision to anything.
##
## What it adds:
##   - sky gradient with sun + soft rays, and see-through fog streaks for clouds
##   - three background layers (far hills, tree-lined hills, flower meadow) with gentle parallax
##   - dark earth below the level and shading down into the gaps between platforms
##   - slowly drifting dust, dark foreground grass passing in front, and a whole-screen finish
##   - silhouette characters (rim-lit in their own colour) and glowing hook rings
## Platforms only get the grassy look if their Block `look` is set to MEADOW.
## The sky/backdrop/dust only appear when the game runs; the ground shading shows in the editor too.

class Painter extends Node2D:
	var fn: Callable
	func _draw() -> void:
		fn.call(self)

@export_group("Sky")
@export var sky_top := Color("2a6fcc")
@export var sky_mid := Color("6fb0ec")
@export var sky_horizon := Color("dbeef7")
@export var sun_color := Color("fff2cc")
## Sun position on screen (0..1). It stays put as you move, like a real sun.
@export var sun_position := Vector2(0.8, 0.1)
@export_range(0.0, 2.0, 0.05) var sun_power := 0.85
@export_range(0.0, 1.0, 0.01) var sun_rays := 0.10

@export_group("Clouds (fog streaks)")
@export_range(0, 30) var cloud_count := 6
@export_range(0.0, 0.3, 0.005) var cloud_opacity := 0.05
@export_range(0.0, 0.3, 0.005) var cloud_parallax := 0.02

@export_group("Background hills")
@export var haze := Color("d3e6f0")
@export var far_hills := Color("93b6cf")
@export var mid_hills := Color("6f9f8a")
@export var meadow := Color("4e8559")
## Where the horizon sits on screen (0 = top, 1 = bottom) at the level's reference height.
@export_range(0.0, 1.0, 0.01) var horizon_height := 0.56
## How much the horizon drops as you climb (0 = never moves).
@export_range(0.0, 0.5, 0.01) var vertical_parallax := 0.10
## World height the horizon is measured from (roughly the level's middle height).
@export var reference_y := -300.0
## How fast each layer moves with the camera (0 = fixed to the screen, 1 = moves with the level).
@export_range(0.0, 1.0, 0.01) var far_parallax := 0.06
@export_range(0.0, 1.0, 0.01) var mid_parallax := 0.18
@export_range(0.0, 1.0, 0.01) var meadow_parallax := 0.35
@export_range(0, 120) var background_trees := 40

@export_group("Meadow flowers (background)")
@export_range(0, 2000) var flower_count := 260
@export_range(0.0, 1.0, 0.01) var flower_opacity := 0.10
@export var flower_colors: Array[Color] = [Color("ffe066"), Color("ffffff"), Color("ff9fb5"), Color("a8c8ff"), Color("ffb347")]

@export_group("Ground (Blocks with look = MEADOW)")
@export var ground_top := Color("3c6a3c"):
	set(v):
		ground_top = v
		_apply_ground()
@export var ground := Color("1d3a29"):
	set(v):
		ground = v
		_apply_ground()
@export var ground_deep := Color("0d1813"):
	set(v):
		ground_deep = v
		_apply_ground()
## Little flowers in the grass along platform tops.
@export var grass_flowers := true:
	set(v):
		grass_flowers = v
		_apply_ground()
## Darken the gaps between platforms toward the bottom, and fill dark earth below the level.
@export var shade_chasms := true:
	set(v):
		shade_chasms = v
		queue_redraw()

@export_group("Dust")
@export_range(0, 300) var dust_count := 34
## Fastest drift in px per second (it also wobbles gently). Real dust is slow.
@export_range(0.0, 40.0, 0.5) var dust_speed := 5.0
@export var dust_color := Color(1.0, 1.0, 0.9)

@export_group("Foreground grass")
@export var foreground_grass := true
## > 1 = passes in front faster than the level (sense of depth).
@export_range(1.0, 2.5, 0.05) var foreground_parallax := 1.3

@export_group("Characters & rings")
## Dark bodies with a rim of light in each character's own colour, glowing eyes.
@export var silhouette_characters := true
@export var silhouette_color := Color("15191c")
@export var eye_glow := Color(1.0, 0.97, 0.9)
@export var ring_color := Color("ffd000")
@export var ring_glow := true

@export_group("Screen finish")
@export var screen_grade := true
@export_range(0.0, 1.0, 0.01) var vignette := 0.28
@export_range(0.0, 0.2, 0.005) var grain := 0.03
@export_range(0.0, 0.01, 0.0005) var color_fringe := 0.0015
@export var shadow_lift := Color(0.0, 0.01, 0.03)

var _t := 0.0
var _cam := Vector2.ZERO
var _zoom := 1.0
var _vs := Vector2(1280, 720)
var _backdrop: Painter
var _dust: Painter
var _fg: Painter


func _ready() -> void:
	z_as_relative = false
	z_index = -2  # earth + chasm shading sits behind the platforms
	_apply_ground()
	if Engine.is_editor_hint():
		return
	_build()
	_apply_bodies.call_deferred()  # characters/rings register themselves in their own _ready


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()  # follow block edits in the editor
		return
	_t += dt
	_vs = get_viewport_rect().size
	var cam := get_viewport().get_camera_2d()
	if cam:
		_cam = cam.get_screen_center_position()
		_zoom = cam.zoom.x
	_backdrop.queue_redraw()
	_dust.queue_redraw()
	if _fg:
		_fg.global_position = _cam
		_fg.queue_redraw()


# ---------------------------------------------------------------- setup

func _apply_ground() -> void:
	Block.meadow_top = ground_top
	Block.meadow_body = ground
	Block.meadow_deep = ground_deep
	var fl: Array[Color] = []
	if grass_flowers:
		fl = flower_colors.duplicate()
	Block.meadow_flowers = fl
	if is_inside_tree():
		Block.redraw_all(get_tree())
	queue_redraw()


func _apply_bodies() -> void:
	if silhouette_characters:
		for b in get_tree().get_nodes_in_group(&"tether_bodies"):
			if b is Character:
				var c := b as Character
				c.silhouette_color = silhouette_color
				c.eye_glow = eye_glow
				c.silhouette = true
	for a in get_tree().get_nodes_in_group(&"anchors"):
		if a is TetherAnchor:
			(a as TetherAnchor).color = ring_color
			(a as TetherAnchor).glow = ring_glow


func _painter(parent: Node, fn: Callable) -> Painter:
	var p := Painter.new()
	p.fn = fn
	parent.add_child(p)
	return p


func _full_rect(parent: Node, shader: Shader) -> ShaderMaterial:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = shader
	r.material = m
	parent.add_child(r)
	return m


func _build() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	var sm := _full_rect(sky_layer, preload("res://Shaders/sky.gdshader"))
	sm.set_shader_parameter("top_col", sky_top)
	sm.set_shader_parameter("mid_col", sky_mid)
	sm.set_shader_parameter("horizon_col", sky_horizon)
	sm.set_shader_parameter("sun_col", sun_color)
	sm.set_shader_parameter("sun", sun_position)
	sm.set_shader_parameter("sun_power", sun_power)
	sm.set_shader_parameter("rays", sun_rays)

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -9
	add_child(bg_layer)
	_backdrop = _painter(bg_layer, _paint_backdrop)

	_dust = _painter(self, _paint_dust)
	_dust.top_level = true
	_dust.z_as_relative = false
	_dust.z_index = 20      # in front of the level, under the black screen (40) and speech (50)

	if foreground_grass:
		_fg = _painter(self, _paint_foreground)
		_fg.top_level = true
		_fg.z_as_relative = false
		_fg.z_index = 30

	if screen_grade:
		var post_layer := CanvasLayer.new()
		post_layer.layer = 4  # under the anxiety filter (5) and the HUD (10)
		add_child(post_layer)
		var pm := _full_rect(post_layer, preload("res://Shaders/screen_grade.gdshader"))
		pm.set_shader_parameter("vignette", vignette)
		pm.set_shader_parameter("grain", grain)
		pm.set_shader_parameter("ca", color_fringe)
		pm.set_shader_parameter("lift", shadow_lift)


# ---------------------------------------------------------------- world: earth + chasms

func _draw() -> void:
	if not shade_chasms or not is_inside_tree():
		return
	var rects: Array[Rect2] = []
	for b in get_tree().get_nodes_in_group(&"blocks"):
		if b is Block and (b as Block).look == Block.Look.MEADOW:
			rects.append(Rect2((b as Block).global_position - global_position, (b as Block).size))
	if rects.is_empty():
		return
	rects.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	var deep := -INF
	var left := INF
	var right := -INF
	for r in rects:
		deep = maxf(deep, r.end.y)
		left = minf(left, r.position.x)
		right = maxf(right, r.end.x)
	draw_rect(Rect2(left - 4000.0, deep - 2.0, right - left + 8000.0, 6000.0), ground_deep)
	var clear := Color(ground_deep, 0.0)
	var reach := rects[0].end.x
	for i in range(1, rects.size()):
		var r := rects[i]
		if r.position.x > reach + 1.0:
			var top := maxf(rects[i - 1].position.y, r.position.y)
			draw_polygon(PackedVector2Array([Vector2(reach, top), Vector2(r.position.x, top), Vector2(r.position.x, deep), Vector2(reach, deep)]),
				PackedColorArray([clear, clear, ground_deep, ground_deep]))
		reach = maxf(reach, r.end.x)


# ---------------------------------------------------------------- backdrop (screen space)

func _horizon() -> float:
	return _vs.y * horizon_height - (_cam.y - reference_y) * vertical_parallax * _zoom


func _ridge(n: Node2D, f: float, base: float, amp: float, freq: float, ph: float, col: Color) -> PackedFloat32Array:
	var zl := lerpf(1.0, _zoom, 0.6)
	var hy := _horizon() - (_cam.y - reference_y) * f * _zoom * 0.5
	var ys := PackedFloat32Array()
	var pts := PackedVector2Array()
	var sx := -10.0
	while sx <= _vs.x + 10.0:
		var u := (sx - _vs.x * 0.5) / zl + _cam.x * f
		var h := sin(u * freq + ph) * amp + sin(u * freq * 2.3 + ph * 1.7) * amp * 0.45 + sin(u * freq * 5.3 + ph * 0.3) * amp * 0.15
		var y := minf(hy + (base + h) * zl, _vs.y + 8.0)  # never below the screen (keeps the shape valid)
		pts.append(Vector2(sx, y))
		ys.append(y)
		sx += 6.0
	pts.append(Vector2(_vs.x + 10.0, _vs.y + 10.0))
	pts.append(Vector2(-10.0, _vs.y + 10.0))
	n.draw_colored_polygon(pts, col)
	return ys


func _haze_band(n: Node2D, y: float, h: float, a: float) -> void:
	var c0 := Color(haze, 0.0)
	var c1 := Color(haze, a)
	n.draw_polygon(PackedVector2Array([Vector2(0, y - h), Vector2(_vs.x, y - h), Vector2(_vs.x, y), Vector2(0, y)]), PackedColorArray([c0, c0, c1, c1]))
	n.draw_polygon(PackedVector2Array([Vector2(0, y), Vector2(_vs.x, y), Vector2(_vs.x, y + h * 0.5), Vector2(0, y + h * 0.5)]), PackedColorArray([c1, c1, c0, c0]))


func _paint_backdrop(n: Node2D) -> void:
	_paint_clouds(n)
	var zl := lerpf(1.0, _zoom, 0.6)
	var hy := _horizon()
	_ridge(n, far_parallax, -40.0, 30.0, 0.0022, 1.0, far_hills)
	_haze_band(n, hy, 70.0 * zl, 0.6)
	# tree-lined hills
	var mid_ys := _ridge(n, mid_parallax, 10.0, 24.0, 0.0035, 4.0, mid_hills)
	var r := RandomNumberGenerator.new()
	r.seed = 8
	var tree_col := mid_hills.darkened(0.12)
	for i in background_trees:
		var u := r.randf_range(-4000.0, 8000.0)
		var sx := fposmod((u - _cam.x * mid_parallax) * zl + _vs.x * 0.5, _vs.x + 200.0) - 100.0
		var by := mid_ys[clampi(int((sx + 10.0) / 6.0), 0, mid_ys.size() - 1)]
		var s := r.randf_range(0.7, 1.3) * zl
		n.draw_line(Vector2(sx, by + 4.0), Vector2(sx, by - 14.0 * s), tree_col, 2.0 * s)
		for j in 6:
			n.draw_circle(Vector2(sx + r.randf_range(-9, 9) * s, by - 18.0 * s - r.randf_range(0, 12) * s), r.randf_range(5, 9) * s, tree_col)
	_haze_band(n, hy + 40.0 * zl, 60.0 * zl, 0.35)
	# flower meadow - flowers are placed ON the meadow layer, so they move with it
	var near_ys := _ridge(n, meadow_parallax, 70.0, 16.0, 0.0045, 2.0, meadow)
	if flower_count > 0 and not flower_colors.is_empty():
		r.seed = 3
		var period := 2400.0
		for i in flower_count:
			var u := r.randf_range(0.0, period)
			var depth := r.randf_range(3.0, 70.0)
			var c: Color = flower_colors[r.randi() % flower_colors.size()]
			var rad := r.randf_range(0.8, 1.9)
			var sx := fposmod((u - _cam.x * meadow_parallax) * zl, period * zl)
			while sx <= _vs.x + 10.0:
				if sx >= -10.0:
					var y := near_ys[clampi(int((sx + 10.0) / 6.0), 0, near_ys.size() - 1)] + depth * zl
					n.draw_circle(Vector2(sx, y), rad * zl, Color(c, flower_opacity))
				sx += period * zl
	_haze_band(n, hy + 90.0 * zl, 50.0 * zl, 0.18)


func _paint_clouds(n: Node2D) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 17
	var zl := lerpf(1.0, _zoom, 0.5)
	for i in cloud_count:
		var cx := fposmod(r.randf_range(0.0, _vs.x + 800.0) - _cam.x * cloud_parallax * _zoom, _vs.x + 800.0) - 400.0
		var cy := r.randf_range(_vs.y * 0.08, _vs.y * 0.42)
		var s := r.randf_range(0.8, 1.6) * zl
		for j in 16:
			var off := Vector2(r.randf_range(-160, 160), r.randf_range(-14, 10)) * s
			var rad := r.randf_range(18, 40) * s
			var stretch := r.randf_range(2.8, 4.5)
			n.draw_set_transform(Vector2(cx, cy) + off, 0.0, Vector2(stretch, 0.55))
			n.draw_circle(Vector2.ZERO, rad * 1.4, Color(1, 1, 1, cloud_opacity * 0.7))
			n.draw_circle(Vector2.ZERO, rad, Color(1, 1, 1, cloud_opacity))
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- dust (world space)

func _paint_dust(n: Node2D) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 33
	var tile := Vector2(1600, 1000) / maxf(_zoom, 0.25)
	var origin := _cam - tile * 0.5
	for i in dust_count:
		var base := Vector2(r.randf_range(0, tile.x), r.randf_range(0, tile.y))
		var vel := Vector2(r.randf_range(-dust_speed, dust_speed), r.randf_range(-dust_speed * 0.6, dust_speed * 0.3))
		var wob := r.randf_range(4.0, 10.0)
		var f := r.randf_range(0.15, 0.4)
		var ph := r.randf() * TAU
		var p := base + vel * _t + Vector2(sin(_t * f + ph), cos(_t * f * 0.8 + ph)) * wob
		p = Vector2(fposmod(p.x - origin.x, tile.x), fposmod(p.y - origin.y, tile.y)) + origin
		var s := r.randf_range(0.8, 1.8)
		var a := 0.32 + 0.12 * sin(_t * 0.7 + ph)
		n.draw_circle(p, s * 3.0, Color(dust_color, 0.05))
		n.draw_circle(p, s, Color(dust_color, a))


# ---------------------------------------------------------------- foreground grass

func _paint_foreground(n: Node2D) -> void:
	# drawn in screen units around the camera centre
	n.draw_set_transform(-_vs * 0.5 / _zoom, 0.0, Vector2.ONE / _zoom)
	var c := ground_deep
	var period := 1700.0
	var k := _vs.x / 1280.0
	for pass_ in 2:
		var rr := RandomNumberGenerator.new()
		rr.seed = 77
		for clump in 3:
			var cu := rr.randf_range(0.0, period)
			for i in 22:
				var u := cu + rr.randf_range(-130.0, 130.0)
				var hgt := rr.randf_range(40.0, 150.0)
				var lean := rr.randf_range(-25.0, 25.0)
				var w := rr.randf_range(4.0, 8.0) * (2.4 if pass_ == 0 else 1.0)
				var col := Color(c, 0.35) if pass_ == 0 else c
				var sx := fposmod(u - _cam.x * foreground_parallax, period) * k
				for rep in [-period * k, 0.0, period * k]:
					var x: float = sx + rep
					if x < -60.0 or x > _vs.x + 60.0:
						continue
					n.draw_colored_polygon(PackedVector2Array([Vector2(x - w, _vs.y + 5.0), Vector2(x + w, _vs.y + 5.0), Vector2(x + lean, _vs.y - hgt)]), col)
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
