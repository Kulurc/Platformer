class_name Blackout
extends Node2D
## A black cover over the game world that sits UNDER speech bubbles, so conversations can
## play on a black screen (voices in the dark) before the scene is revealed.
## Part of the TetherRig. Drive it with a DialogueFade step, or TetherRig.fade_from_black().
## While it's mostly covering the screen, player input is ignored.

@export var color := Color(0.02, 0.02, 0.035)

var alpha := 0.0:
	set(v):
		alpha = clampf(v, 0.0, 1.0)
		queue_redraw()

var _tween: Tween
## Set by TetherRig.go_to_scene(): the next level starts black and fades in over this many seconds.
static var carry_in := 0.0


func _ready() -> void:
	top_level = true        # draw in world space, around the camera
	z_as_relative = false
	z_index = 40            # above the world (0), below speech bubbles (50)
	add_to_group("blackout")


func set_black(on: bool) -> void:
	if _tween:
		_tween.kill()
	alpha = 1.0 if on else 0.0


## Fade to `target` (0 = clear, 1 = black). Awaitable.
func fade_to(target: float, duration: float) -> void:
	if _tween:
		_tween.kill()
	if duration <= 0.0:
		alpha = target
		return
	_tween = create_tween()
	_tween.tween_property(self, "alpha", target, duration).set_trans(Tween.TRANS_SINE)
	await _tween.finished


func is_covering() -> bool:
	return alpha > 0.5


func _process(_dt: float) -> void:
	if alpha > 0.0:
		queue_redraw()  # follow the camera


func _draw() -> void:
	if alpha <= 0.0:
		return
	var center := Vector2.ZERO
	var view := get_viewport_rect().size
	var cam := get_viewport().get_camera_2d()
	if cam:
		center = cam.get_screen_center_position()
		view /= cam.zoom
	var sz := view * 1.6  # generous margin for camera shake / look-ahead
	draw_rect(Rect2(center - sz * 0.5, sz), Color(color, alpha))
