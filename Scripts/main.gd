extends Node2D
## The TetherRig (Scenes/Prefabs/tether_rig.tscn): both characters, the cord, camera, HUD,
## overlay and pause menu in one drop-in. Drag it into any level scene - where you place it
## is where the pair spawns. Owns input, swapping, phases, and the simulation order:
##   1. intents: you -> controlled body; PartnerAI -> the other (or your input, during control bleed)
##   2. both bodies compute their own velocity
##   3. tether adds its pull (and reads hook/reel/slack/sever)
##   4. both bodies move; tether enforces limits and animates

## The relationship's phases, in order (entry 0 = phase I). Each is a .tres in Data/Phases/ -
## double-click one to tune it. PHASE zones refer to these by number (1 = first entry).
@export var phase_profiles: Array[PhaseProfile] = []

@export_group("Camera")
@export var camera_lerp := 6.0
@export var partner_camera_weight := 0.35
@export var look_ahead := 0.18

@export_group("Rules")
@export var checkpoint_partner_radius := 220.0
## Safety net for levels without a KILL zone: falling this far below the lowest checkpoint
## (or the spawn point) respawns you.
@export var fall_respawn_depth := 1500.0
## After severing, both bodies move/jump this much better ("a good platformer again").
@export var sever_speed_mult := 1.2
@export var sever_jump_mult := 1.2

@export_group("Intro")
## Start this level on a black screen (speech bubbles still show). Reveal it with a
## DialogueFade step (FROM_BLACK) in an intro DialogueTrigger. Player input is ignored
## while the screen is black.
@export var start_black := false
## Settings for reveal_tether(): call it from a DialogueCall (target = TetherRig, method =
## reveal_tether, no args) after the last intro line. The cord appears alone on the black and
## holds. Follow it with a DialogueFade FROM_BLACK, then a DialogueCall tether_behind_characters.
@export var tether_reveal_sound: AudioStream            ## plays as the cord appears (empty = silent)
@export_range(-40.0, 12.0, 0.5) var tether_reveal_volume_db := -6.0
@export_range(0.0, 10.0, 0.05, "or_greater") var tether_reveal_time := 1.5    ## cord fade-in, seconds
@export_range(0.0, 10.0, 0.05, "or_greater") var tether_reveal_hold := 1.2    ## cord alone on black, seconds

@export_group("Debug")
## F1 readout, F2 next phase, F3 next checkpoint, F4 slow-motion, F5 reset cord memory.
## Turn off for builds you hand to other people.
@export var debug_tools := true
@export_range(0.05, 1.0, 0.05) var slow_motion_scale := 0.25
## On-screen debug readout at the top (tension, grips, cord length...). F1 toggles it in game.
@export var show_debug_text := false
## Controls reminder along the bottom. F1 toggles it too.
@export var show_controls := false

@onready var wisp: Character = $Wisp
@onready var ember: Character = $Ember
@onready var tether: Tether = $Tether
@onready var camera: Camera2D = $Camera
@onready var hud: Hud = $HUD
@onready var blackout: Blackout = $Blackout
@onready var overlay_mat: ShaderMaterial = ($Anxiety/Filter as ColorRect).material as ShaderMaterial

var controlled: Character
var partner: Character
var ai := PartnerAI.new()
var phase := 0
var profile: PhaseProfile
var separation := 0.0

var _checkpoint := Vector2.ZERO
var _busy := false
var _leaving := false
var _ended := false
var _zones: Array[Zone] = []
var _swap_lock := 0.0
var _control_bleed := 0.0
var _shake := 0.0
var _bleed := 0.0
var _anxiety := 0.0
var _pulse_time := 0.0
var _input_lock := 0.0
var _fall_limit_y := 0.0


func _ready() -> void:
	add_to_group(&"tether_rig")
	_ensure_input()
	wisp.partner = ember
	ember.partner = wisp
	controlled = wisp
	partner = ember
	wisp.controlled = true
	tether.setup(wisp, ember, controlled)
	tether.snapped.connect(_on_tether_snapped)
	tether.tugged.connect(_on_tugged)
	_checkpoint = controlled.global_position
	for n in get_tree().get_nodes_in_group("zones"):
		var z := n as Zone
		_zones.append(z)
		if z.kind == Zone.Kind.KILL:
			z.body_entered.connect(_on_kill_zone)
	_fall_limit_y = _checkpoint.y
	for z in _zones:
		if z.kind == Zone.Kind.CHECKPOINT:
			_fall_limit_y = maxf(_fall_limit_y, z.spawn_point().y)
	_fall_limit_y += fall_respawn_depth
	hud.set_overlays(show_debug_text, show_controls)
	if start_black:
		blackout.set_black(true)
	elif Blackout.carry_in > 0.0:
		# Arrived through a LevelExit: start black and fade in (an intro with start_black
		# handles its own reveal instead).
		blackout.set_black(true)
		blackout.fade_to(0.0, Blackout.carry_in)
	Blackout.carry_in = 0.0
	set_phase(1)
	_update_camera(1.0, true)
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
	if debug_tools:
		_debug_keys()
	var locked := _input_lock > 0.0 or blackout.is_covering()
	tether.input_enabled = not locked
	if Input.is_action_just_pressed("swap") and not _busy and not locked:
		swap()

	# --- intents
	var mv := Input.get_axis("move_left", "move_right")
	var jp := Input.is_action_just_pressed("jump")
	var jh := Input.is_action_pressed("jump")
	if locked:
		_input_lock = maxf(0.0, _input_lock - dt)
		controlled.set_intent(0.0, false, false)  # cutscene / black screen / scripted lock
	elif _swap_lock > 0.0:
		_swap_lock -= dt
		controlled.set_intent(0.0, false, false)  # the new body hesitates
	else:
		controlled.set_intent(mv, jp, jh)
	if _control_bleed > 0.0 and not tether.severed:
		_control_bleed -= dt
		partner.set_intent(mv, jp, jh)            # ...while the old one still answers you
	else:
		ai.think(partner, controlled, tether, dt)

	# --- modifiers
	_update_separation(dt)
	var free := tether.severed
	for c: Character in [wisp, ember]:
		c.speed_mult = sever_speed_mult if free else 1.0
		c.jump_mult = sever_jump_mult if free else 1.0
		c.floaty = separation * float(profile.floaty) if c == controlled and not free else 0.0
		c.bleed = _bleed
		c.left_behind = free and c != controlled
		var marker_target := 1.0 if c == controlled else 0.0
		if _swap_lock > 0.0 or (_bleed > 0.6 and _control_bleed > 0.0):
			marker_target = 0.0  # for a moment you can't tell which one is you
		c.marker_alpha = move_toward(c.marker_alpha, marker_target, dt * 6.0)

	# --- simulate
	wisp.pre_step(dt)
	ember.pre_step(dt)
	tether.step(dt)
	wisp.move_and_slide()
	ember.move_and_slide()
	tether.post_step(dt)
	wisp.post_step(dt)
	ember.post_step(dt)

	_check_zones(dt)
	if controlled.global_position.y > _fall_limit_y:
		_die("")
	elif partner.global_position.y > _fall_limit_y and not tether.severed:
		_die("You lost them.")
	_update_camera(dt)
	hud.update_debug(tether, controlled, phase, separation, debug_tools)


# ---------------------------------------------------------------- swap & phases

func swap() -> void:
	var old := controlled
	controlled = partner
	partner = old
	controlled.controlled = true
	partner.controlled = false
	tether.controller = controlled  # the hook stays: a swap mid-swing keeps the swing going
	ai.reset()
	_swap_lock = profile.swap_delay
	_control_bleed = profile.control_bleed
	if _bleed > 0.3:
		controlled.glitch(0.25 * _bleed)
		partner.glitch(0.25 * _bleed)


func set_phase(p: int) -> void:
	if p <= phase:
		return  # phases only escalate
	if phase_profiles.is_empty():
		push_warning("No phase_profiles assigned on the root node; using defaults.")
		phase_profiles.append(PhaseProfile.new())
	p = mini(p, phase_profiles.size())
	if p <= phase:
		return
	phase = p
	profile = phase_profiles[p - 1]
	ai.configure(profile)
	tether.apply_phase(profile)
	var tw := create_tween()
	tw.tween_property(self, "_bleed", profile.bleed, 2.5)
	tw.parallel().tween_property(self, "_anxiety", profile.anxiety, 2.5)
	if profile.show_title:
		hud.show_title(profile.title, profile.subtitle)


# ---------------------------------------------------------------- helpers for DialogueCall
# Drag the TetherRig node onto a DialogueCall's Target and type one of these as the Method.
# Args go in order, e.g. show_message → ["Something's wrong.", 3.0]. Args with defaults can be left out.

## Centered text message: fades in, holds for `duration` seconds, fades out.
## When called from a DialogueCall, the next step waits until it has faded out.
func show_message(msg: String, duration: float = 2.5) -> void:
	hud.show_message(msg, duration)
	await get_tree().create_timer(0.4 + duration + 0.8, false).timeout


## Big title card with an optional subtitle (same as the phase titles).
## When called from a DialogueCall, the next step waits until it has faded out.
func show_title(title: String, subtitle: String = "") -> void:
	hud.show_title(title, subtitle)
	await get_tree().create_timer(0.8 + 2.5 + 1.2, false).timeout


## Darken the screen and show a final line of text. It stays up (use for custom endings).
func show_ending(msg: String) -> void:
	hud.show_ending(msg)


## Intro beat: on the black screen, the cord fades in by itself (with tether_reveal_sound)
## and holds. It stays drawn in front of the black (and the characters) until you call
## tether_behind_characters(), so a typical intro ends:
##   DialogueCall reveal_tether  ->  DialogueFade FROM_BLACK  ->  DialogueCall tether_behind_characters
## Settings are in the Intro group; args override them for one call (-1 = use the Intro setting).
func reveal_tether(rope_time: float = -1.0, hold: float = -1.0) -> void:
	if rope_time < 0.0: rope_time = tether_reveal_time
	if hold < 0.0: hold = tether_reveal_hold
	tether_in_front()
	if tether_reveal_sound:
		var sfx := AudioStreamPlayer.new()
		sfx.stream = tether_reveal_sound
		sfx.volume_db = tether_reveal_volume_db
		sfx.bus = &"Sfx"
		sfx.finished.connect(sfx.queue_free)
		add_child(sfx)
		sfx.play()
	if rope_time > 0.0:
		tether.reveal_alpha = 0.0
		var tw := create_tween()
		tw.tween_property(tether, "reveal_alpha", 1.0, rope_time).set_trans(Tween.TRANS_SINE)
		await tw.finished
	tether.reveal_alpha = 1.0
	if hold > 0.0:
		await get_tree().create_timer(hold, false).timeout


## Draw the cord in front of everything: the black screen and the characters
## (still under speech bubbles). reveal_tether() does this for you.
func tether_in_front() -> void:
	tether.z_as_relative = false
	tether.z_index = blackout.z_index + 1


## Put the cord back to its normal render order, behind the characters.
func tether_behind_characters() -> void:
	tether.z_as_relative = true
	tether.z_index = 0


## Fade to black, then load another scene. `scene` is a name like "prototype" (looked up in
## LevelExit.SCENES_FOLDER) or a full res:// path. The new scene fades in from black.
## Used by LevelExit; also callable from a DialogueCall (args: ["Level2"] or ["Level2", 2.0]).
func go_to_scene(scene: String, fade: float = 1.0) -> void:
	var path := LevelExit.resolve(scene)
	if path == "" or not ResourceLoader.exists(path):
		push_error("go_to_scene: can't find scene '%s' (looked for %s)." % [scene, path])
		return
	if _leaving:
		return
	_leaving = true
	_busy = true            # no deaths, restarts or swaps on the way out
	lock_input(1.0e6)
	Blackout.carry_in = maxf(fade, 0.05)
	await blackout.fade_to(1.0, fade)
	get_tree().change_scene_to_file(path)


## Fade the screen in from black (awaitable from a DialogueCall).
func fade_from_black(duration: float = 1.5) -> void:
	await blackout.fade_to(0.0, duration)


## Fade the screen out to black (awaitable from a DialogueCall).
func fade_to_black(duration: float = 1.5) -> void:
	await blackout.fade_to(1.0, duration)


## Ignore player input for `seconds` (cutscenes). The partner AI keeps running.
func lock_input(seconds: float) -> void:
	_input_lock = maxf(_input_lock, seconds)


func shake_camera(amount: float = 6.0) -> void:
	_shake = maxf(_shake, amount)


## Cut the cord from a script (same as holding Q).
func sever_tether() -> void:
	if tether.is_active():
		tether._snap(&"sever")


## Jump straight to a phase (phases still never go backwards).
func go_to_phase(p: int) -> void:
	set_phase(p)


# ---------------------------------------------------------------- debug tools

func _debug_keys() -> void:
	if Input.is_action_just_pressed("debug_next_phase"):
		set_phase(phase + 1)
		hud.show_message("[debug] phase %d" % phase, 0.6)
	if Input.is_action_just_pressed("debug_next_checkpoint"):
		_debug_next_checkpoint()
	if Input.is_action_just_pressed("debug_slow_motion"):
		Engine.time_scale = 1.0 if Engine.time_scale < 1.0 else slow_motion_scale
		hud.show_message("[debug] time x%.2f" % Engine.time_scale, 0.6)
	if Input.is_action_just_pressed("debug_reset_memory"):
		tether.leash_cap = tether.phase_max
		hud.show_message("[debug] cord memory reset", 0.6)


func _debug_next_checkpoint() -> void:
	var cps: Array[Zone] = []
	for z in _zones:
		if z.kind == Zone.Kind.CHECKPOINT:
			cps.append(z)
	if cps.is_empty():
		return
	cps.sort_custom(func(x: Zone, y: Zone): return x.global_position.x < y.global_position.x)
	var target: Zone = cps[0]
	for z in cps:
		if z.spawn_point().x > controlled.global_position.x + 40.0:
			target = z
			break
	for z in cps:
		z.activated = z == target
	_checkpoint = target.spawn_point()
	_respawn()


func _exit_tree() -> void:
	Engine.time_scale = 1.0  # never leave slow-motion on after the scene ends


func _update_separation(dt: float) -> void:
	var target := 0.0
	var warm := 0.0
	if tether.severed:
		target = 1.0
	else:
		var d := controlled.global_position.distance_to(partner.global_position)
		target = clampf(inverse_lerp(tether.comfort, tether.leash_cap + 20.0, d), 0.0, 1.0)
		warm = (1.0 - target) * (1.0 if tether.taut else 0.6)
	separation = lerpf(separation, target, 1.0 - exp(-4.0 * dt))
	var strength := 1.0 if tether.severed else _anxiety
	overlay_mat.set_shader_parameter("separation", separation * strength)
	overlay_mat.set_shader_parameter("warmth", warm * strength * 0.8)
	_pulse_time += dt  # game time, not wall time: the warm pulse freezes with the pause
	overlay_mat.set_shader_parameter("pulse_time", _pulse_time)


# ---------------------------------------------------------------- zones & flow

func _check_zones(dt: float) -> void:
	for z in _zones:
		match z.kind:
			Zone.Kind.PHASE:
				if z.overlaps_body(controlled):
					set_phase(z.phase)
			Zone.Kind.CHECKPOINT:
				if not z.activated and z.overlaps_body(controlled) and (tether.severed \
						or partner.global_position.distance_to(z.spawn_point()) < checkpoint_partner_radius):
					for other in _zones:
						if other.kind == Zone.Kind.CHECKPOINT:
							other.activated = false
					z.activated = true
					_checkpoint = z.spawn_point()
			Zone.Kind.STAY:
				if tether.is_active() and z.overlaps_body(wisp) and z.overlaps_body(ember):
					z.progress = minf(1.0, z.progress + dt / z.stay_time)
					if z.progress >= 1.0:
						_end("You stayed.\nThere was nowhere else to be.")
				else:
					z.progress = maxf(0.0, z.progress - dt)
			Zone.Kind.EXIT:
				if z.overlaps_body(controlled):
					if tether.severed:
						_end("You are free.\nIt is unbearable.")
					elif z.overlaps_body(partner):
						_end("You left together.")


func _on_kill_zone(body: Node2D) -> void:
	if body == controlled:
		_die("")
	elif body == partner and not tether.severed:
		_die("You lost them.")


func _on_tether_snapped(reason: StringName) -> void:
	if reason == &"strain":
		_die("The tether gave way.")
	else:
		hud.show_message("You let go.", 1.5)


func _on_tugged(_body: Character) -> void:
	ai.panic(profile.panic_time)
	_shake = profile.tug_camera_shake


func _die(msg: String) -> void:
	if _busy or _ended:
		return
	_busy = true
	hud.fade(msg, func():
		_respawn()
		_busy = false)


func _respawn() -> void:
	controlled.global_position = _checkpoint
	controlled.velocity = Vector2.ZERO
	if not tether.severed:
		partner.global_position = _checkpoint + Vector2(-50, -4)
		partner.velocity = Vector2.ZERO
	ai.reset()
	tether.reset(true)
	_update_camera(1.0, true)


func _end(msg: String) -> void:
	if _ended:
		return
	_ended = true
	hud.show_ending(msg + "\n\n\nBACKSPACE  -  begin again")


func _update_camera(dt: float, snap := false) -> void:
	var target := controlled.global_position
	if tether.is_active():
		target = target.lerp(partner.global_position, partner_camera_weight)
	target.x += clampf(controlled.velocity.x * look_ahead, -120.0, 120.0)
	target.y -= 40.0
	if snap:
		camera.global_position = target
	else:
		camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-camera_lerp * dt))
	_shake = maxf(0.0, _shake - dt * 30.0)
	camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))


## Input is registered in code so the prototype runs out of the box. Actions you define in
## Project Settings > Input Map take precedence (existing actions are skipped).
func _ensure_input() -> void:
	_action("move_left", [KEY_A, KEY_LEFT], [], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_action("move_right", [KEY_D, KEY_RIGHT], [], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_action("jump", [KEY_SPACE], [], [JOY_BUTTON_A])
	_action("swap", [KEY_TAB], [], [JOY_BUTTON_X])
	_action("hook", [KEY_E], [], [JOY_BUTTON_RIGHT_SHOULDER])
	_action("reel", [], [MOUSE_BUTTON_LEFT], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_action("slack", [], [MOUSE_BUTTON_RIGHT], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_action("sever", [KEY_Q], [], [JOY_BUTTON_Y])
	_action("restart", [KEY_R], [], [JOY_BUTTON_BACK])
	_action("debug", [KEY_F1], [], [])
	_action("pause", [KEY_ESCAPE], [], [JOY_BUTTON_START])
	_action("debug_next_phase", [KEY_F2], [], [])
	_action("debug_next_checkpoint", [KEY_F3], [], [])
	_action("debug_slow_motion", [KEY_F4], [], [])
	_action("debug_reset_memory", [KEY_F5], [], [])


func _action(name: StringName, keys: Array, mouse: Array, buttons: Array, axes: Array = []) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name, 0.25)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(name, e)
	for m in mouse:
		var e := InputEventMouseButton.new()
		e.button_index = m
		InputMap.action_add_event(name, e)
	for btn in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = btn
		InputMap.action_add_event(name, e)
	for ax in axes:
		var e := InputEventJoypadMotion.new()
		e.axis = ax[0]
		e.axis_value = ax[1]
		InputMap.action_add_event(name, e)
