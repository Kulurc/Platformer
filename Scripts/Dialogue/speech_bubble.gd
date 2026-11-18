class_name SpeechBubble
extends Node2D
## A bubble that lives under a Character (so it always follows them), types a
## DialogueLine letter by letter with a blip per letter, holds for appear_time, then fades.
## Everything runs in _process, so pausing the tree freezes it mid-word (effects included).
##
## Messages support Godot BBCode, e.g. "I [shake]can't[/shake] [wave amp=30]breathe[/wave]",
## "[color=#ff6a6a]red[/color]", "[b]bold[/b]". Angle-bracket versions of the same tags also
## work ("<shake>can't</shake>"). Typing, blips and bubble size count visible letters only.

signal line_done(token: int)

const MAX_WIDTH := 220.0
const FONT_SIZE := 14
## Tags accepted in <angle> form and rewritten to [square] BBCode.
const ANGLE_TAGS := "shake|wave|tornado|rainbow|fade|pulse|b|i|u|s|code|color|bgcolor|fgcolor|outline_color|outline_size|font_size|center|right"
const TAIL := 8.0
const GAP := 14.0          ## space between the speaker's head and the tail tip
const FADE_TIME := 0.15

var _panel: PanelContainer
var _label: RichTextLabel
var _plain := ""           ## message with tags stripped (what actually gets typed)
static var _angle_re: RegEx
var _style: StyleBoxFlat
var _line: DialogueLine
var _tint := Color.WHITE
var _token := 0
var _shown := 0.0
var _hold := 0.0
var _state := 0            ## 0 hidden, 1 typing, 2 holding, 3 fading out
var _alpha := 0.0


## The bubble for this character (created on first use).
static func of(c: Character) -> SpeechBubble:
	var b := c.get_node_or_null("SpeechBubble") as SpeechBubble
	if b == null:
		b = SpeechBubble.new()
		b.name = "SpeechBubble"
		c.add_child(b)
	return b


func _ready() -> void:
	z_index = 50
	_style = StyleBoxFlat.new()
	_style.set_corner_radius_all(6)
	_style.content_margin_left = 9
	_style.content_margin_right = 9
	_style.content_margin_top = 5
	_style.content_margin_bottom = 6
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _style)
	add_child(_panel)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.clip_contents = false  # let [shake]/[wave] glyphs move past the edge instead of clipping
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for f in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		_label.add_theme_font_size_override(f, FONT_SIZE)
	_label.add_theme_color_override("default_color", Color(0.1, 0.1, 0.14))
	_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING  # layout fixed while typing
	_panel.add_child(_label)
	visible = false


## Show a line. Awaitable: returns once it has typed, held, and faded out
## (or right away if another line replaces it).
func say(line: DialogueLine, tint: Color) -> void:
	if _state != 0:
		line_done.emit(_token)  # release whoever was waiting on the old line
	_token += 1
	var my := _token
	_line = line
	_tint = tint
	_style.bg_color = Color(tint, 0.95)
	_label.text = to_bbcode(line.message)
	_plain = _label.get_parsed_text()
	var font := _label.get_theme_font("normal_font")
	var w := font.get_multiline_string_size(_plain, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	# Short lines size to their content on one line; long ones wrap at MAX_WIDTH.
	if w <= MAX_WIDTH:
		_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_label.custom_minimum_size = Vector2.ZERO
	else:
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.custom_minimum_size = Vector2(MAX_WIDTH, 0.0)
	_panel.reset_size()
	_shown = 0.0
	_label.visible_characters = 0
	_state = 1
	visible = true
	if line.text_speed <= 0.0:
		_finish_typing()
	while true:
		var t: int = await line_done
		if t == my:
			return


func _process(dt: float) -> void:
	if _state == 0:
		return
	var parent := get_parent() as Character
	if parent:
		position = Vector2(0.0, -parent.half_h() - GAP)
	_panel.reset_size()  # shrink-to-fit once the wrapped label has settled its width
	_panel.position = Vector2(-_panel.size.x * 0.5, -_panel.size.y - TAIL)

	match _state:
		1:
			_alpha = minf(1.0, _alpha + dt / FADE_TIME)
			var before := int(_shown)
			_shown += _line.text_speed * dt
			var total := _label.get_total_character_count()
			var now := mini(int(_shown), total)
			if now > before:
				_label.visible_characters = now
				var revealed := _plain.substr(before, now - before)
				var sm := get_node_or_null("/root/SoundManager")
				if sm and revealed.strip_edges() != "":
					sm.play_sound(_line.text_sound, _line.text_volume)  # one blip per frame max
			if now >= total:
				_finish_typing()
		2:
			_alpha = minf(1.0, _alpha + dt / FADE_TIME)
			_hold -= dt
			if _hold <= 0.0:
				_state = 3
		3:
			_alpha -= dt / FADE_TIME
			if _alpha <= 0.0:
				_alpha = 0.0
				_state = 0
				visible = false
				line_done.emit(_token)
	modulate.a = _alpha
	queue_redraw()


## Rewrites <tag>, <tag=value>, <tag key=value> and </tag> to [square] BBCode for known tags.
static func to_bbcode(msg: String) -> String:
	if _angle_re == null:
		_angle_re = RegEx.new()
		# <tag>, <tag=value>, <tag key=value key2=value> only - so "a<b and 3 > 2" stays plain text.
		_angle_re.compile("<(/?)(" + ANGLE_TAGS + ")((?:=[^<>\\s]+)?(?:\\s+\\w+=[^<>\\s]+)*)>")
	return _angle_re.sub(msg, "[$1$2$3]", true)


func _finish_typing() -> void:
	_label.visible_characters = -1
	_hold = _line.appear_time
	_state = 2


func _draw() -> void:
	if _state == 0:
		return
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6.0, -TAIL - 1.0), Vector2(6.0, -TAIL - 1.0), Vector2(0.0, 0.0)]), Color(_tint, 0.95))
