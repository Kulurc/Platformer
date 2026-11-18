class_name Hud
extends CanvasLayer
## Controls reminder, phase titles, fades/messages, and a debug readout (F1).

var _fade_rect: ColorRect
var _message: Label
var _title: Label
var _subtitle: Label
var _controls: Label
var _debug: Label
var _show_debug := true
var _msg_tween: Tween
var _title_tween: Tween


func _ready() -> void:
	layer = 10
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.03, 0.035, 0.06, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_message = _make_label(26, Color(0.9, 0.92, 1.0))
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0

	_title = _make_label(30, Color(0.92, 0.9, 0.96))
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position.y = 56
	_title.modulate.a = 0.0
	_subtitle = _make_label(15, Color(0.75, 0.78, 0.88))
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.position.y = 96
	_subtitle.modulate.a = 0.0

	_controls = _make_label(13, Color(0.6, 0.65, 0.75, 0.8))
	_controls.text = "A/D move   SPACE jump   R swap   E hook   LMB reel   RMB slack   hold Q sever   BACKSPACE restart   F1 debug"
	_controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_controls.position += Vector2(16, -30)

	_debug = _make_label(13, Color(0.75, 0.8, 0.9, 0.9))
	_debug.position = Vector2(16, 12)


func _make_label(font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _process(_dt: float) -> void:
	if Input.is_action_just_pressed("debug"):
		_show_debug = not _show_debug
		_debug.visible = _show_debug


func update_debug(t: Tether, you: Character, phase: int, separation: float, tools := false) -> void:
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
		for g in [t.a.grip, t.b.grip, t.reel_max_force, t.break_force]:
			if g >= v and g < next:
				mark = "|"
		bar += mark if mark != "" else ("#" if v < w else "-")
	var state := "SEVERED" if t.severed else ("BROKEN" if t.broken else ("taut" if t.taut else "slack"))
	_debug.text = "phase %d   tension %.2f W  [%s]\n" % [phase, w, bar] \
		+ "marks: %s grip %.1f | %s grip %.1f | reel max %.1f | break %.1f\n" % [
			t.a.display_name, t.a.grip, t.b.display_name, t.b.grip, t.reel_max_force, t.break_force] \
		+ "cord %d / cap %d px   %s%s%s   strain %d%%   apart %.1fs   separation %d%%\n" % [
			t.length, t.leash_cap, state, "  hooked" if t.anchor else "",
			"  REEL" if t.reeling else ("  SLACK" if t.slacking else ""),
			roundi(t.strain * 100.0), t.apart_time, roundi(separation * 100.0)] \
		+ "%s   |   %s" % [_body_state(t.a, you), _body_state(t.b, you)]
	if tools:
		_debug.text += "\nF2 next phase   F3 next checkpoint   F4 slow-motion   F5 reset cord memory"


func _body_state(c: Character, you: Character) -> String:
	var s := "airborne"
	if c.is_grounded():
		s = "DRAGGED" if c.slipping else ("PLANTED" if c.is_planted() else "moving")
	return "%s%s: %s" % [c.display_name, " (you)" if c == you else " (ai)", s]


func show_title(title: String, subtitle: String) -> void:
	if _title_tween:
		_title_tween.kill()
	_title.text = title
	_subtitle.text = subtitle
	_title_tween = create_tween()
	_title_tween.tween_property(_title, "modulate:a", 1.0, 0.8)
	_title_tween.parallel().tween_property(_subtitle, "modulate:a", 1.0, 1.2)
	_title_tween.tween_interval(2.5)
	_title_tween.tween_property(_title, "modulate:a", 0.0, 1.2)
	_title_tween.parallel().tween_property(_subtitle, "modulate:a", 0.0, 1.2)


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
