class_name Companion
extends CharacterBody2D
## The larger, slower one. It cannot jump. It follows you along the ground and stops
## at edges and walls it cannot cross - getting it over them is your job.
## It is heavier than you (mass 1.5), so on a pulley it out-weighs you.

@export var radius := 18.0
@export var mass := 1.5
@export var grip := 2.6               ## W. Walking (~1.4W) and normal swings won't move them; reeling (3.2W) or a hard pumped swing will.
@export var walk_speed := 100.0
@export var walk_accel := 600.0
@export var drag_friction := 700.0    ## ground friction while being dragged
@export var follow_distance := 64.0
@export var edge_margin := 14.0       ## how far back from a drop they stop (px beyond their radius)
@export var max_fall_speed := 900.0
@export var color := Color(1.0, 0.8, 0.5)

var gravity := 1600.0
var player: Node2D
var slipping := false        ## set by the tether: being dragged along the ground
var left_behind := false     ## after sever
var holding := false         ## you're on a ring: they plant their feet and become your counterweight

var _time := 0.0
var _look := Vector2.RIGHT
var _waiting := false
var _fade := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 6.0
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	add_child(cs)
	add_to_group("tether_bodies")


func pre_step(dt: float) -> void:
	velocity.y = minf(velocity.y + gravity * dt, max_fall_speed)
	_waiting = false
	if not is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 40.0 * dt)
		return
	if slipping:
		velocity.x = move_toward(velocity.x, 0.0, drag_friction * dt)
		return
	var target := 0.0
	if player and not left_behind and not holding:
		var dx := player.global_position.x - global_position.x
		if absf(dx) > follow_distance:
			var dir := signf(dx)
			if _ground_ahead(dir) and not _wall_ahead(dir):
				target = dir * walk_speed
			else:
				_waiting = true
	# Stopping is firmer than starting: planted feet shouldn't skate toward an edge.
	var a := walk_accel if target != 0.0 else walk_accel * 3.0
	velocity.x = move_toward(velocity.x, target, a * dt)


func _process(dt: float) -> void:
	_time += dt
	var want := Vector2.DOWN
	if player and not left_behind:
		want = (player.global_position - global_position).normalized()
	_look = _look.lerp(want, 1.0 - exp(-6.0 * dt))
	_fade = move_toward(_fade, 1.0 if left_behind else 0.0, dt / 2.5)
	queue_redraw()


func _probe(from: Vector2, to: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(from, to, 1, [get_rid()])
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _ground_ahead(dir: float) -> bool:
	var x := global_position.x + dir * (radius + edge_margin)
	return _probe(Vector2(x, global_position.y), Vector2(x, global_position.y + radius + 20.0))


func _wall_ahead(dir: float) -> bool:
	return _probe(global_position, global_position + Vector2(dir * (radius + 6.0), 0.0))


func _draw() -> void:
	var shake := Vector2.ZERO
	if slipping:
		shake = Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0))
	var squat := lerpf(1.0, 0.85, _fade)  # sits down when left behind
	draw_set_transform(shake + Vector2(0, radius * (1.0 - squat)), 0.0, Vector2(1.0 / squat, squat))
	var pulse := 1.0 + sin(_time * 2.2) * 0.04 * (1.0 - _fade)
	var base := color.lerp(Color(0.42, 0.44, 0.5), _fade)
	for i in 3:
		draw_circle(Vector2.ZERO, radius * pulse * (1.7 - i * 0.22), Color(base, 0.06 * (1.0 - _fade)))
	draw_circle(Vector2.ZERO, radius * pulse, base)
	var dark := Color(0.15, 0.1, 0.08)
	var eye := _look * 6.0
	draw_circle(eye + Vector2(-4.5, -3.0), 2.6, dark)
	draw_circle(eye + Vector2(4.5, -3.0), 2.6, dark)
	draw_set_transform(Vector2.ZERO)
	if _waiting:  # "...": stuck, waiting for you
		for i in 3:
			var a := clampf(sin(_time * 4.0 - i * 0.8) * 0.5 + 0.5, 0.2, 1.0)
			draw_circle(Vector2(-8.0 + i * 8.0, -radius - 12.0), 2.0, Color(1, 1, 1, a * 0.7))
