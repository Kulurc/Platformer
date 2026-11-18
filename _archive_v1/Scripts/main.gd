extends Node2D
## Prototype root. Owns the simulation order so the cord and the bodies never disagree:
##   1. player + companion compute their own velocity (legs, gravity, AI)
##   2. tether adds its pull (and reads verb input)
##   3. both bodies move
##   4. tether enforces the hard limit and animates the rope

@export var camera_lerp := 6.0
@export var companion_camera_weight := 0.3  ## camera leans toward the companion while tethered
@export var look_ahead := 0.18
@export var checkpoint_companion_radius := 220.0  ## companion must be this close to bank a checkpoint

@onready var player: Player = $Player
@onready var companion: Companion = $Companion
@onready var tether: Tether = $Tether
@onready var camera: Camera2D = $Camera
@onready var hud: Hud = $HUD

var _checkpoint := Vector2.ZERO
var _busy := false
var _ended := false
var _zones: Array[Zone] = []


func _ready() -> void:
	_ensure_input()
	companion.player = player
	companion.gravity = player.gravity
	player.tether = tether
	tether.setup(player, companion)
	tether.snapped.connect(_on_tether_snapped)
	_checkpoint = player.global_position
	for n in get_tree().get_nodes_in_group("zones"):
		var z := n as Zone
		_zones.append(z)
		if z.kind == Zone.Kind.KILL:
			z.body_entered.connect(_on_kill_zone)
	camera.global_position = player.global_position
	camera.make_current()


func _physics_process(dt: float) -> void:
	if Input.is_action_just_pressed("restart"):
		if _ended:
			get_tree().reload_current_scene()
		elif not _busy:
			_die("")
		return
	if _ended:
		return

	player.unburdened = tether.severed
	companion.left_behind = tether.severed
	companion.holding = tether.anchor != null

	player.pre_step(dt)
	companion.pre_step(dt)
	tether.step(dt)
	player.move_and_slide()
	companion.move_and_slide()
	tether.post_step(dt)
	player.post_step(dt)

	_check_zones()
	_update_camera(dt)
	hud.update_debug(tether, player, companion)


func _check_zones() -> void:
	for z in _zones:
		if z.kind == Zone.Kind.CHECKPOINT and not z.activated and z.overlaps_body(player):
			# Only bank progress you actually made together - no dying to teleport them forward.
			if tether.severed or companion.global_position.distance_to(z.spawn_point()) < checkpoint_companion_radius:
				for other in _zones:
					if other.kind == Zone.Kind.CHECKPOINT:
						other.activated = false
				z.activated = true
				_checkpoint = z.spawn_point()
		elif z.kind == Zone.Kind.GOAL and z.overlaps_body(player):
			if tether.severed:
				_end("You arrived alone.\nIt is very quiet here.\n\n\nR  -  begin again")
			elif z.overlaps_body(companion):
				_end("You arrived together.\n\n\nR  -  begin again")


func _on_kill_zone(body: Node2D) -> void:
	if body == player:
		_die("")
	elif body == companion and not tether.severed:
		_die("You lost them.")


func _on_tether_snapped(reason: StringName) -> void:
	if reason == &"strain":
		_die("The tether gave way.")
	else:
		hud.show_message("You let go.", 1.5)


func _die(msg: String) -> void:
	if _busy or _ended:
		return
	_busy = true
	hud.fade(msg, func():
		_respawn()
		_busy = false)


func _respawn() -> void:
	player.global_position = _checkpoint
	player.velocity = Vector2.ZERO
	if not tether.severed:
		companion.global_position = _checkpoint + Vector2(-56, -2)
		companion.velocity = Vector2.ZERO
	tether.reset(true)
	_update_camera(1.0, true)


func _end(msg: String) -> void:
	_ended = true
	hud.show_ending(msg)


func _update_camera(dt: float, snap := false) -> void:
	var target := player.global_position
	if tether.is_active():
		target = target.lerp(companion.global_position, companion_camera_weight)
	target.x += clampf(player.velocity.x * look_ahead, -120.0, 120.0)
	target.y -= 40.0
	if snap:
		camera.global_position = target
	else:
		camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-camera_lerp * dt))


## Input is registered in code so the prototype runs out of the box. Any action you
## define in Project Settings > Input Map takes precedence (we skip existing actions).
func _ensure_input() -> void:
	_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_action("jump", [KEY_SPACE, KEY_W, KEY_UP], [JOY_BUTTON_A])
	_action("anchor", [KEY_J], [JOY_BUTTON_RIGHT_SHOULDER])
	_action("reel", [KEY_K], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_action("slack", [KEY_L], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_action("sever", [KEY_Q], [JOY_BUTTON_Y])
	_action("restart", [KEY_R], [JOY_BUTTON_START])
	_action("debug", [KEY_F1], [])


func _action(name: StringName, keys: Array, buttons: Array, axes: Array = []) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name, 0.25)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(name, e)
	for b in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		InputMap.action_add_event(name, e)
	for a in axes:
		var e := InputEventJoypadMotion.new()
		e.axis = a[0]
		e.axis_value = a[1]
		InputMap.action_add_event(name, e)
