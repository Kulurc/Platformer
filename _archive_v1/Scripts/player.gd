class_name Player
extends CharacterBody2D
## The small, nimble one. Movement is computed in pre_step(); main.gd then lets the
## tether add its pull before move_and_slide(), so the cord and the legs never fight.

@export_group("Run")
@export var run_speed := 250.0
@export var ground_accel := 2200.0     ## ~0.11s to full speed: responsive, not twitchy
@export var ground_decel := 2800.0
@export var air_accel := 1400.0
@export var air_decel := 500.0
@export var air_momentum_decay := 260.0  ## how slowly swing-launch speed above run_speed bleeds off

@export_group("Jump")
@export var jump_height := 104.0       ## px, ~3.25 tiles
@export var time_to_apex := 0.36
@export var fall_gravity_mult := 1.6   ## snappier falls; disabled while the cord is taut (clean pendulum)
@export var jump_cut_mult := 0.45      ## release jump early = short hop
@export var max_fall_speed := 900.0
@export var coyote_time := 0.10
@export var jump_buffer := 0.12

@export_group("Tether")
@export var mass := 1.0
@export var grip := 2.8                ## W. Standing still, you can hold a dangling companion (1.5W) and survive a jolt.
@export var swing_pump := 520.0        ## tangential accel from left/right while swinging
@export var swing_release_pop := 0.55  ## fraction of a jump given when jumping off a ring

@export_group("Unburdened (after sever)")
@export var free_speed_mult := 1.2
@export var free_jump_mult := 1.25     ## 1.25x velocity = ~1.56x height: reaches what two cannot

const SIZE := Vector2(20, 30)

var gravity := 0.0
var jump_velocity := 0.0
var tether: Tether
var tether_taut := false
var rope_dir := Vector2.ZERO
var slipping := false
var unburdened := false
var input_x := 0.0
var facing := 1.0

var _coyote := 0.0
var _buffer := 0.0
var _jumping := false
var _was_on_floor := false
var _pre_move_vy := 0.0
var _squash := Vector2.ONE


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 6.0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = SIZE
	cs.shape = r
	add_child(cs)
	add_to_group("tether_bodies")
	recompute_jump()


func recompute_jump() -> void:
	gravity = 2.0 * jump_height / (time_to_apex * time_to_apex)
	jump_velocity = -2.0 * jump_height / time_to_apex


func pre_step(dt: float) -> void:
	input_x = Input.get_axis("move_left", "move_right")
	if input_x != 0.0:
		facing = signf(input_x)
	var on_floor := is_on_floor()
	_coyote = coyote_time if on_floor else _coyote - dt
	if Input.is_action_just_pressed("jump"):
		_buffer = jump_buffer
	else:
		_buffer -= dt

	var speed := run_speed * (free_speed_mult if unburdened else 1.0)
	var swinging := tether_taut and not on_floor

	# Horizontal
	if swinging:
		# Pump along the swing arc instead of steering in x: keeps the pendulum honest.
		var t := Vector2(-rope_dir.y, rope_dir.x)
		if t.x < 0.0:
			t = -t
		velocity += t * input_x * swing_pump * dt
	elif on_floor:
		var a := ground_accel if absf(input_x) > 0.01 else ground_decel
		velocity.x = move_toward(velocity.x, input_x * speed, a * dt)
	else:
		if absf(velocity.x) > speed and (input_x == 0.0 or signf(input_x) == signf(velocity.x)):
			# Preserve launch momentum from a swing; decay gently toward run speed.
			velocity.x = move_toward(velocity.x, signf(velocity.x) * speed, air_momentum_decay * dt)
		else:
			var a := air_accel if absf(input_x) > 0.01 else air_decel
			velocity.x = move_toward(velocity.x, input_x * speed, a * dt)

	# Jump
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity * (free_jump_mult if unburdened else 1.0)
		_buffer = 0.0
		_coyote = 0.0
		_jumping = true
		_squash = Vector2(0.75, 1.3)
	elif _buffer > 0.0 and swinging and tether and tether.anchor:
		tether.release_anchor()
		velocity.y = minf(velocity.y, jump_velocity * swing_release_pop)
		velocity.x *= 1.1
		_buffer = 0.0
		_squash = Vector2(0.8, 1.2)
	if _jumping and velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y *= jump_cut_mult
		_jumping = false
	if velocity.y >= 0.0:
		_jumping = false

	# Gravity
	var g := gravity
	if velocity.y > 0.0 and not tether_taut:
		g *= fall_gravity_mult
	velocity.y = minf(velocity.y + g * dt, max_fall_speed)

	_was_on_floor = on_floor
	_pre_move_vy = velocity.y


func post_step(dt: float) -> void:
	if is_on_floor() and not _was_on_floor and _pre_move_vy > 200.0:
		var k := clampf(_pre_move_vy / 900.0, 0.15, 0.4)
		_squash = Vector2(1.0 + k, 1.0 - k)
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-14.0 * dt))
	queue_redraw()


## Standing on the ground and not pulling away from the cord = planted feet.
func can_brace(u: Vector2) -> bool:
	if not is_on_floor():
		return false
	return input_x == 0.0 or signf(input_x) == signf(u.x)


func _draw() -> void:
	var s := SIZE * _squash
	var top := SIZE.y * 0.5 - s.y  # squash around the feet, not the centre
	var body := Color(0.9, 0.94, 1.0) if not unburdened else Color(0.78, 0.84, 0.95)
	draw_rect(Rect2(Vector2(-s.x * 0.5, top), s), body)
	draw_rect(Rect2(Vector2(facing * 4.0 - 2.0, top + 8.0), Vector2(4, 4)), Color(0.1, 0.12, 0.18))
	if slipping:
		var y := SIZE.y * 0.5
		for i in 3:
			var x := -facing * (8.0 + i * 5.0)
			draw_line(Vector2(x, y), Vector2(x - facing * 4.0, y - 3.0), Color(1, 1, 1, 0.5), 1.0)
