@tool
class_name Hud
extends CanvasLayer
## Title cards, centered messages/fades, FPS counter, controls reminder and debug readout.
##
## The title card, message and FPS counter are real nodes under this HUD in
## Scenes/Prefabs/tether_rig.tscn (TitleCard → Title / Subtitle, Message, FPS). Select one and
## drag it in the 2D view (or edit Layout → Transform) to move it. With `editor_preview` on,
## the editor shows them with sample text in the TetherRig's fonts and sizes.
## F1 toggles the FPS counter; Shift+F1 toggles the debug readout + controls reminder.

## Editor only: show the title card, message and FPS counter with sample text so you can
## see and drag them. Has no effect in the game. Untick to hide them while editing levels.
@export var editor_preview := true:
	set(v):
		editor_preview = v
		if is_node_ready():
			_apply_editor_preview()

var _fade_rect: ColorRect
@onready var _title_card: Control = $TitleCard
@onready var _title: Label = $TitleCard/Title
@onready var _subtitle: Label = $TitleCard/Subtitle
@onready var _message: Label = $Message
@onready var _fps: Label = $FPS
var _controls: Label
var _debug: Label
var _show_debug := false
var _show_controls := false
var _show_fps := true
var _fps_refresh := 0.0
var _preview_poll := 0.0
var _msg_tween: Tween
var _title_tween: Tween
## Defaults set by the TetherRig (Fonts group) via set_fonts(). null = Godot's default font.
var _message_font: Font
var _title_font: Font
var _subtitle_font: Font


func _ready() -> void:
	layer = 10
	if Engine.is_editor_hint():
		_apply_editor_preview()
		return
	# Full-screen fade, behind every label.
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.03, 0.035, 0.06, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)
	move_child(_fade_rect, 0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# The scene's labels hold sample text for the editor; start empty and invisible.
	for l in [_title, _subtitle, _message]:
		l.text = ""
		l.modulate.a = 0.0
	_title_card.visible = true
	_message.visible = true

	_controls = _make_label(13, Color(0.6, 0.65, 0.75, 0.8))
	_controls.text = "A/D move   SPACE jump   TAB swap   E hook   LMB reel   RMB slack   hold Q sever   R restart   F1 fps   Shift+F1 debug"
	_controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_controls.position += Vector2(16, -30)

	_debug = _make_label(13, Color(0.75, 0.8, 0.9, 0.9))
	_debug.position = _fps.position + Vector2(0.0, 24.0)  # just under the FPS counter
	set_overlays(_show_debug, _show_controls)
	set_fps_visible(_show_fps)


## Show/hide the debug readout (top) and controls reminder (bottom).
## Set from the TetherRig → Debug group (show_debug_text / show_controls).
func set_overlays(debug_text: bool, controls: bool) -> void:
	_show_debug = debug_text
	_show_controls = controls
	if _debug:
		_debug.visible = debug_text
	if _controls:
		_controls.visible = controls


## Show/hide the FPS counter. Set from TetherRig → Debug → show_fps; F1 toggles it in game.
func set_fps_visible(on: bool) -> void:
	_show_fps = on
	if _fps:
		_fps.visible = on
		_fps_refresh = 0.0


## Default fonts and sizes for messages, titles and subtitles. Called by the TetherRig
## from its Fonts group; per-call fonts (show_message / show_title args) override these.
func set_fonts(message: Font, message_size: int, title: Font, title_size: int,
		subtitle: Font, subtitle_size: int) -> void:
	_message_font = message
	_title_font = title
	_subtitle_font = subtitle
	_message.add_theme_font_size_override("font_size", message_size)
	_title.add_theme_font_size_override("font_size", title_size)
	_subtitle.add_theme_font_size_override("font_size", subtitle_size)
	_use_font(_message, null, _message_font)
	_use_font(_title, null, _title_font)
	_use_font(_subtitle, null, _subtitle_font)


## Put `override` on the label, or `fallback` when override is null (null both = theme font).
static func _use_font(l: Label, override: Font, fallback: Font) -> void:
	var f := override if override else fallback
	if f:
		l.add_theme_font_override("font", f)
	else:
		l.remove_theme_font_override("font")


func _make_label(font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		# Follow font changes made on the TetherRig while the scene is open.
		_preview_poll -= dt
		if _preview_poll <= 0.0:
			_preview_poll = 0.5
			_apply_editor_preview()
		return
	if Input.is_action_just_pressed("debug"):
		if Input.is_key_pressed(KEY_SHIFT):
			var on := not (_show_debug or _show_controls)
			set_overlays(on, on)
		else:
			set_fps_visible(not _show_fps)
	if _show_fps:
		_fps_refresh -= dt
		if _fps_refresh <= 0.0:
			_fps_refresh = 0.25
			_fps.text = "FPS: %d" % roundi(Engine.get_frames_per_second())


# ---------------------------------------------------------------- editor preview

## Editor only: show/hide the sample text and use the TetherRig's fonts and sizes on it.
func _apply_editor_preview() -> void:
	if not Engine.is_editor_hint() or not is_node_ready():
		return
	for c: CanvasItem in [_title_card, _message, _fps]:
		c.visible = editor_preview
	var rig := get_parent()
	if rig == null:
		return
	_preview_font(_title, rig.get("title_font"), rig.get("title_font_size"))
	_preview_font(_subtitle, rig.get("subtitle_font"), rig.get("subtitle_font_size"))
	_preview_font(_message, rig.get("message_font"), rig.get("message_font_size"))


static func _preview_font(l: Label, f: Variant, size: Variant) -> void:
	if f is Font and l.get_theme_font("font") != f:
		l.add_theme_font_override("font", f)
	if size is int and l.get_theme_font_size("font_size") != size:
		l.add_theme_font_size_override("font_size", size)


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


func show_title(title: String, subtitle: String, title_font: Font = null, subtitle_font: Font = null) -> void:
	if _title_tween:
		_title_tween.kill()
	_use_font(_title, title_font, _title_font)
	_use_font(_subtitle, subtitle_font, _subtitle_font)
	_title.text = title
	_subtitle.text = subtitle
	_title_tween = create_tween()
	_title_tween.tween_property(_title, "modulate:a", 1.0, 0.8)
	_title_tween.parallel().tween_property(_subtitle, "modulate:a", 1.0, 1.2)
	_title_tween.tween_interval(2.5)
	_title_tween.tween_property(_title, "modulate:a", 0.0, 1.2)
	_title_tween.parallel().tween_property(_subtitle, "modulate:a", 0.0, 1.2)


func fade(msg: String, mid: Callable) -> void:
	_use_font(_message, null, _message_font)
	_message.text = msg
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, 0.35)
	tw.parallel().tween_property(_message, "modulate:a", 1.0 if msg != "" else 0.0, 0.35)
	tw.tween_callback(mid)
	tw.tween_interval(0.7 if msg != "" else 0.1)
	tw.tween_property(_fade_rect, "color:a", 0.0, 0.35)
	tw.parallel().tween_property(_message, "modulate:a", 0.0, 0.35)


func show_message(msg: String, duration: float, font: Font = null) -> void:
	if _msg_tween:
		_msg_tween.kill()
	_use_font(_message, font, _message_font)
	_message.text = msg
	_msg_tween = create_tween()
	_msg_tween.tween_property(_message, "modulate:a", 1.0, 0.4)
	_msg_tween.tween_interval(duration)
	_msg_tween.tween_property(_message, "modulate:a", 0.0, 0.8)


func show_ending(msg: String, font: Font = null) -> void:
	if _msg_tween:
		_msg_tween.kill()
	_use_font(_message, font, _message_font)
	_message.text = msg
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 0.85, 2.0)
	tw.parallel().tween_property(_message, "modulate:a", 1.0, 2.0)
