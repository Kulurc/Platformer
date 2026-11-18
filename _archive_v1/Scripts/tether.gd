class_name Tether
extends Node2D
## The cord between the player and the companion. This is the core mechanic.
##
## Physics model
## - The cord runs along a path: player -> [anchor ring] -> companion.
## - It is a one-sided spring: it pulls when stretched past `length`, never pushes.
## - An anchor ring is a frictionless pulley, so the SAME tension acts on both ends.
##   That makes the companion a counterweight: drop down on your side and they rise.
## - Bracing: a body standing on the ground ignores the pull until tension exceeds its
##   `grip`. That one rule is what lets you hang from your companion off a ledge,
##   and what makes a hard swing yank them off their feet.
##
## All forces are measured in W = one player-weight (player.mass * player.gravity),
## so every threshold below reads as "how many of you is the cord pulling".

signal snapped(reason: StringName)  ## &"sever" (chosen) or &"strain" (failure)

@export_group("Length")
@export var rest_length := 180.0     ## length on spawn / respawn (px)
@export var min_length := 8.0       ## near-zero so you can be hauled fully over a lip
@export var max_length := 480.0
@export var reel_speed := 170.0      ## px/s while taut (2x while slack, to take up slack fast)
@export var slack_speed := 220.0
@export var relax_speed := 120.0     ## when both stand still-ish, a reeled-in cord eases back to rest_length
@export var reel_max_force := 3.2    ## W. Reeling stalls above this tension. Must beat companion grip.

@export_group("Elasticity")
@export var stiffness := 220.0       ## pull per px of stretch. Hanging player stretches ~7px.
@export var damping := 14.0          ## kills bounce along the cord
@export var hard_stretch := 40.0     ## beyond this stretch the cord becomes rigid (safety net)

@export_group("Strain")
@export var break_force := 4.2       ## W. Sustained tension above this snaps the cord.
@export var break_time := 0.35       ## s above break_force before it snaps (absorbs short jolts)
@export var tension_smoothing := 12.0

@export_group("Verbs")
@export var anchor_range := 180.0    ## how close the player must be to hook a ring
@export var sever_hold_time := 1.0   ## deliberately slow: severing should feel like a decision

@export_group("Look")
@export var rope_color := Color(1.0, 0.72, 0.3)
@export var strain_color := Color(1.0, 0.25, 0.2)
@export var segments := 28

var player: Player
var companion: Companion
var length := 0.0
var anchor: TetherAnchor = null
var hover_anchor: TetherAnchor = null
var tension := 0.0          ## raw force this frame
var tension_smooth := 0.0   ## what strain / UI reads
var strain := 0.0           ## 0..1, drives colour and thickness
var severed := false
var broken := false
var taut := false
var reeling := false
var slacking := false
var sever_hold := 0.0
var weight_unit := 1.0

var _strain_timer := 0.0
var _wedged_timer := 0.0
var _fail_flash := 0.0
var _p_braced := false
var _c_braced := false
var _rope := PackedVector2Array()
var _rope_prev := PackedVector2Array()
var _rope_alpha := 1.0
var _rope_free := false
var _free_seg := 8.0


func setup(p: Player, c: Companion) -> void:
	player = p
	companion = c
	weight_unit = p.mass * p.gravity
	reset(false)


func is_active() -> bool:
	return not severed and not broken


func reset(keep_severed: bool) -> void:
	broken = false
	if not keep_severed:
		severed = false
	anchor = null
	length = rest_length
	tension = 0.0
	tension_smooth = 0.0
	strain = 0.0
	_strain_timer = 0.0
	_wedged_timer = 0.0
	sever_hold = 0.0
	taut = false
	_rope_free = not is_active()
	_rope_alpha = 1.0 if is_active() else 0.0
	_init_rope()
	_update_anchor_states()


# ---------------------------------------------------------------- simulation

## Called by main after both bodies have computed their own velocity, before they move.
func step(dt: float) -> void:
	_fail_flash = maxf(0.0, _fail_flash - dt)
	hover_anchor = null
	if not is_active():
		taut = false
		tension = 0.0
		player.tether_taut = false
		_update_anchor_states()
		return

	_handle_verbs(dt)
	if not is_active():
		return  # severed this frame

	var pts := get_path_points()
	var s := _path_length(pts)
	var u_p := (pts[1] - pts[0]).normalized()
	var u_c := (pts[pts.size() - 2] - pts[pts.size() - 1]).normalized()
	var stretch := s - length
	taut = stretch > 0.0

	var force := 0.0
	if taut:
		# rate > 0 means the ends are separating along the cord
		var rate := -player.velocity.dot(u_p) - companion.velocity.dot(u_c)
		force = maxf(0.0, stiffness * stretch + damping * rate)
	tension = force
	tension_smooth = lerpf(tension_smooth, tension, 1.0 - exp(-tension_smoothing * dt))

	var W := weight_unit
	companion.slipping = _slip(companion.slipping, companion.is_on_floor(), force, companion.grip * W)
	_c_braced = companion.is_on_floor() and not companion.slipping
	var p_can := player.can_brace(u_p)
	player.slipping = _slip(player.slipping, p_can, force, player.grip * W)
	_p_braced = p_can and not player.slipping

	u_p = _lip_redirect(player, u_p)
	u_c = _lip_redirect(companion, u_c)
	if force > 0.0:
		if not _p_braced:
			player.velocity += u_p * (force / player.mass) * dt
		if not _c_braced:
			companion.velocity += u_c * (force / companion.mass) * dt

	player.tether_taut = taut and force > 0.0
	player.rope_dir = u_p
	_update_strain(dt)
	_update_anchor_states()


## Called by main after both bodies moved. Enforces the hard limit and animates the rope.
func post_step(dt: float) -> void:
	if is_active():
		var pts := get_path_points()
		var s := _path_length(pts)
		var over := s - length - hard_stretch
		if over > 0.0:
			var u_p := (pts[1] - pts[0]).normalized()
			var u_c := (pts[pts.size() - 2] - pts[pts.size() - 1]).normalized()
			var wp := 0.0 if _p_braced else 1.0 / player.mass
			var wc := 0.0 if _c_braced else 1.0 / companion.mass
			if wp + wc == 0.0:
				wp = 1.0 / player.mass
				wc = 1.0 / companion.mass
			var total := wp + wc
			player.move_and_collide(u_p * over * wp / total)
			companion.move_and_collide(u_c * over * wc / total)
			var vp := player.velocity.dot(u_p)
			if vp < 0.0:
				player.velocity -= u_p * vp
			var vc := companion.velocity.dot(u_c)
			if vc < 0.0:
				companion.velocity -= u_c * vc
			s = _path_length(get_path_points())
		# Cord wedged hard (e.g. bodies stuck either side of a wall): give way.
		if s - length > hard_stretch * 2.5:
			_wedged_timer += dt
			if _wedged_timer > 0.4:
				_snap(&"strain")
		else:
			_wedged_timer = 0.0
	_update_rope(dt)
	queue_redraw()


## Cheap stand-in for rope wrapping: a body hanging against a wall, with the cord leading
## up and over the lip, is pulled straight up the wall instead of into it.
func _lip_redirect(body: CharacterBody2D, u: Vector2) -> Vector2:
	if body.is_on_floor() or u.y > -0.05 or absf(u.x) < 0.01:
		return u
	var dir := signf(u.x)
	var reach := 22.0 if body is Companion else 14.0
	var q := PhysicsRayQueryParameters2D.create(
		body.global_position, body.global_position + Vector2(dir * reach, 0.0), 1, [body.get_rid()])
	if get_world_2d().direct_space_state.intersect_ray(q).is_empty():
		return u  # nothing to scrape against
	return Vector2(dir * 0.25, -1.0).normalized()


func _slip(slipping: bool, grounded: bool, force: float, grip: float) -> bool:
	if not grounded:
		return false
	if slipping:
		return force > grip * 0.6  # hysteresis: once dragged, stays dragged a while
	return force > grip


func _update_strain(dt: float) -> void:
	var W := weight_unit
	strain = clampf((tension_smooth / W - 1.0) / (break_force - 1.0), 0.0, 1.0)
	if tension_smooth > break_force * W:
		_strain_timer += dt
	else:
		_strain_timer = maxf(0.0, _strain_timer - dt * 2.0)
	if _strain_timer >= break_time:
		_snap(&"strain")


# ---------------------------------------------------------------- verbs

func _handle_verbs(dt: float) -> void:
	if anchor == null:
		hover_anchor = _find_anchor()

	# ANCHOR & SWING
	if Input.is_action_just_pressed("anchor"):
		if anchor:
			release_anchor()
		else:
			try_hook()

	# REEL & PULL / SLACK & DRIFT
	reeling = Input.is_action_pressed("reel") and not Input.is_action_pressed("slack")
	slacking = Input.is_action_pressed("slack") and not reeling
	if reeling:
		var can_reel := length > min_length and tension_smooth < reel_max_force * weight_unit
		if anchor:
			can_reel = can_reel \
				and player.global_position.distance_to(anchor.global_position) > 28.0 \
				and companion.global_position.distance_to(anchor.global_position) > 28.0
		if can_reel:
			var spd := reel_speed if taut else reel_speed * 2.0
			length = maxf(min_length, length - spd * dt)
	elif slacking:
		length = minf(max_length, length + slack_speed * dt)
	elif anchor and not player.is_on_floor():
		# Hooked + airborne: the cord takes up its own slack, so swings are smooth arcs
		# instead of a free-fall followed by a jolt. Paying out is always deliberate (L).
		length = minf(length, _path_length(get_path_points()))
	elif anchor == null and length < rest_length and player.is_on_floor() and companion.is_on_floor():
		# Both on solid ground: a reeled-in cord eases back to a comfortable length, so
		# walking together doesn't drag. A cord you slackened (> rest) stays as you left it.
		length = minf(rest_length, length + relax_speed * dt)

	# SEVER (hold)
	if Input.is_action_pressed("sever"):
		sever_hold += dt
		if sever_hold >= sever_hold_time:
			_snap(&"sever")
	else:
		sever_hold = maxf(0.0, sever_hold - dt * 3.0)


func try_hook() -> bool:
	var a := _find_anchor()
	if a == null:
		_fail_flash = 0.3
		return false
	var s := player.global_position.distance_to(a.global_position) \
		+ a.global_position.distance_to(companion.global_position)
	if s > max_length:
		_fail_flash = 0.3
		return false
	anchor = a
	# Snap the cord to the current path length so the hook "catches" immediately.
	# (Keeping the old length would mean a free-fall drop first - feels unresponsive.)
	length = s
	return true


func release_anchor() -> void:
	anchor = null  # length is kept, so the direct path is now slack: a clean release


func _find_anchor() -> TetherAnchor:
	var best: TetherAnchor = null
	var best_d := anchor_range
	for n in get_tree().get_nodes_in_group("anchors"):
		var a := n as TetherAnchor
		var d := player.global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


func _snap(reason: StringName) -> void:
	if reason == &"sever":
		severed = true
	else:
		broken = true
	anchor = null
	taut = false
	tension = 0.0
	tension_smooth = 0.0
	strain = 0.0
	sever_hold = 0.0
	player.tether_taut = false
	player.slipping = false
	companion.slipping = false
	_rope_free = true
	_free_seg = maxf(length, _path_length(get_path_points())) / float(segments - 1)
	_update_anchor_states()
	snapped.emit(reason)


func _update_anchor_states() -> void:
	for n in get_tree().get_nodes_in_group("anchors"):
		var a := n as TetherAnchor
		a.state = 2 if a == anchor else (1 if a == hover_anchor else 0)


# ---------------------------------------------------------------- geometry

func get_path_points() -> PackedVector2Array:
	var pts := PackedVector2Array([player.global_position])
	if anchor:
		pts.append(anchor.global_position)
	pts.append(companion.global_position)
	return pts


func _path_length(pts: PackedVector2Array) -> float:
	var s := 0.0
	for i in pts.size() - 1:
		s += pts[i].distance_to(pts[i + 1])
	return s


# ---------------------------------------------------------------- rope visual (verlet)

func _init_rope() -> void:
	if player == null:
		return
	_rope.resize(segments)
	_rope_prev.resize(segments)
	var a := player.global_position
	var b := companion.global_position
	for i in segments:
		var p := a.lerp(b, float(i) / float(segments - 1))
		_rope[i] = p
		_rope_prev[i] = p


func _update_rope(dt: float) -> void:
	if _rope_free:
		_rope_alpha = maxf(0.0, _rope_alpha - dt / 1.5)
		if _rope_alpha <= 0.0:
			return
	var n := segments
	var pts := get_path_points()
	var s := _path_length(pts)
	var seg_len := _free_seg if _rope_free else maxf(length, s) / float(n - 1)
	var g := Vector2(0.0, 900.0) * dt * dt
	for i in n:
		var cur := _rope[i]
		var vel := (cur - _rope_prev[i]) * 0.985
		_rope_prev[i] = cur
		_rope[i] = cur + vel + g

	var anchor_idx := -1
	if not _rope_free and anchor and s > 0.0:
		anchor_idx = clampi(roundi(float(n - 1) * pts[0].distance_to(pts[1]) / s), 1, n - 2)

	for _it in 12:
		if not _rope_free:
			_rope[0] = pts[0]
			_rope[n - 1] = pts[pts.size() - 1]
			if anchor_idx >= 0:
				_rope[anchor_idx] = pts[1]
		for i in n - 1:
			var d := _rope[i + 1] - _rope[i]
			var dist := d.length()
			if dist < 0.0001:
				continue
			var corr := d * ((dist - seg_len) / dist)
			var pin_a := not _rope_free and (i == 0 or i == anchor_idx)
			var pin_b := not _rope_free and (i + 1 == n - 1 or i + 1 == anchor_idx)
			if pin_a and pin_b:
				continue
			elif pin_a:
				_rope[i + 1] -= corr
			elif pin_b:
				_rope[i] += corr
			else:
				_rope[i] += corr * 0.5
				_rope[i + 1] -= corr * 0.5
	if not _rope_free:
		# Taut cord should LOOK taut: straighten toward the true path as stretch builds.
		var k := clampf((s - length) / 6.0, 0.0, 1.0)
		if k > 0.0:
			for i in range(1, n - 1):
				_rope[i] = _rope[i].lerp(_point_along(pts, s * float(i) / float(n - 1)), k)
		_rope[0] = pts[0]
		_rope[n - 1] = pts[pts.size() - 1]
		if anchor_idx >= 0:
			_rope[anchor_idx] = pts[1]


func _point_along(pts: PackedVector2Array, d: float) -> Vector2:
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if d <= seg or i == pts.size() - 2:
			return pts[i].lerp(pts[i + 1], clampf(d / maxf(seg, 0.001), 0.0, 1.0))
		d -= seg
	return pts[pts.size() - 1]


func _draw() -> void:
	if _rope_alpha > 0.0 and _rope.size() > 1:
		var col := rope_color.lerp(strain_color, strain)
		if not is_active():
			col = col.darkened(0.35)
		col.a = _rope_alpha
		var width := lerpf(3.0, 1.5, strain)  # the cord thins as it strains
		var line := _rope
		if strain > 0.5:  # and trembles near breaking
			line = _rope.duplicate()
			var amp := (strain - 0.5) * 4.0
			for i in range(1, line.size() - 1):
				line[i] += Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		draw_polyline(line, Color(col, col.a * 0.18), width + 6.0, true)
		draw_polyline(line, col, width, true)

	if is_active() and sever_hold > 0.0:
		var t := clampf(sever_hold / sever_hold_time, 0.0, 1.0)
		draw_arc(player.global_position, 26.0, -PI / 2.0, -PI / 2.0 + TAU * t, 40,
			Color(0.85, 0.9, 1.0, 0.9), 2.0, true)

	if _fail_flash > 0.0:
		draw_arc(player.global_position + Vector2(0, -30), 5.0, 0.0, TAU, 16,
			Color(1, 0.35, 0.3, _fail_flash / 0.3), 2.0, true)
