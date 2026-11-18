class_name Hud
extends CanvasLayer
## Controls reminder, fades/messages, and a debug tension readout (F1) for tuning.

var _fade_rect: ColorRect
var _message: Label
var _controls: Label
var _debug: Label
var _show_debug := true
var _msg_tween: Tween


func _ready() -> void:
	layer = 10
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.03, 0.035, 0.06, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 26)
	_message.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	_message.modulate.a = 0.0
	add_child(_message)
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_controls = Label.new()
	_controls.text = "A/D move   SPACE jump   J hook/let go   K reel   L slack   hold Q sever   R restart   F1 debug"
	_controls.add_theme_font_size_override("font_size", 13)
	_controls.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 0.8))
	add_child(_controls)
	_controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_controls.position += Vector2(16, -30)

	_debug = Label.new()
	_debug.add_theme_font_size_override("font_size", 13)
	_debug.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9, 0.9))
	_debug.position = Vector2(16, 12)
	add_child(_debug)


func _process(_dt: float) -> void:
	if Input.is_action_just_pressed("debug"):
		_show_debug = not _show_debug
		_debug.visible = _show_debug


func update_debug(t: Tether, p: Player, c: Companion) -> void:
	if not _show_debug:
		return
	var w := t.tension_smooth / t.weight_unit
	var bar := ""
	var cells := 36
	var scale_max := 4.5
	for i in cells:
		var v := float(i) / cells * scale_max
		var next := float(i + 1) / cells * scale_max
		var mark := ""
		for g in [c.grip, p.grip, t.reel_max_force, t.break_force]:
			if g >= v and g < next:
				mark = "|"
		bar += mark if mark != "" else ("#" if v < w else "-")
	var state := "SEVERED" if t.severed else ("BROKEN" if t.broken else ("taut" if t.taut else "slack"))
	_debug.text = "tension %.2f W  [%s]\n" % [w, bar] \
		+ "marks: companion grip %.1f | your grip %.1f | reel max %.1f | break %.1f\n" % [c.grip, p.grip, t.reel_max_force, t.break_force] \
		+ "cord %d / %d px   %s%s%s   strain %d%%\n" % [t.length, t.max_length, state,
			"  hooked" if t.anchor else "", "  REEL" if t.reeling else ("  SLACK" if t.slacking else ""),
			roundi(t.strain * 100.0)] \
		+ "you: %s   companion: %s" % [
			"airborne" if not p.is_on_floor() else ("SLIPPING" if p.slipping else "planted"),
			"airborne" if not c.is_on_floor() else ("DRAGGED" if c.slipping else "planted")]


## Fade to black, run `mid` (the respawn), fade back.
func fade(msg: String, mid: Callable) -> void:
	_message.text = msg
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, 0.35)
	tw.parallel().tween_property(_message, "modulate:a", 1.0 if msg != "" else 0.0, 0.35)
	tw.tween_callback(mid)
	tw.tween_interval(0.7 if msg != "" else 0.1)
	tw.tween_property(_fade_rect, "color:a", 0.0, 0.35)
	tw.parallel().tween_property(_message, "modulate:a", 0.0, 0.35)


func show_message(msg: String, duration: float) -> void:
	if _msg_tween:
		_msg_tween.kill()
	_message.text = msg
	_msg_tween = create_tween()
	_msg_tween.tween_property(_message, "modulate:a", 1.0, 0.4)
	_msg_tween.tween_interval(duration)
	_msg_tween.tween_property(_message, "modulate:a", 0.0, 0.8)


func show_ending(msg: String) -> void:
	if _msg_tween:
		_msg_tween.kill()
	_message.text = msg
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 0.85, 2.0)
	tw.parallel().tween_property(_message, "modulate:a", 1.0, 2.0)
