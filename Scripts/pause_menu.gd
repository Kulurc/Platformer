class_name PauseMenu
extends CanvasLayer
## Esc (or Start) toggles. Pausing the SceneTree freezes everything that is pausable:
## bodies keep their exact position AND velocity because nothing integrates them, and
## tweens, timers, speech bubbles and crumbling blocks stop where they are.
## This node runs with PROCESS_MODE_ALWAYS so it can still react while paused.
## Volumes are saved to user://settings.cfg.

const SETTINGS_PATH := "user://settings.cfg"
const BUSES := [["Master", "Master"], ["Music", "Music"], ["SFX", "Sfx"]]  # [label, bus name]

var _root: Control
var _resume: Button
var _sliders := {}  # bus name -> HSlider


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_load_settings()
	_root.visible = false


func _process(_dt: float) -> void:
	if Input.is_action_just_pressed("pause"):
		set_paused(not get_tree().paused)


func set_paused(p: bool) -> void:
	get_tree().paused = p
	_root.visible = p
	if p:
		_resume.grab_focus()
	else:
		_save_settings()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.05, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.16, 0.96)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)

	for entry in BUSES:
		box.add_child(_make_row(entry[0], entry[1]))

	_resume = Button.new()
	_resume.text = "Resume"
	_resume.custom_minimum_size = Vector2(0, 36)
	_resume.pressed.connect(func(): set_paused(false))
	box.add_child(_resume)


func _make_row(label_text: String, bus: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(70, 0)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(240, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var pct := Label.new()
	pct.custom_minimum_size = Vector2(44, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pct)
	slider.value_changed.connect(func(v: float):
		_apply(bus, v)
		pct.text = "%d%%" % roundi(v * 100.0))
	var idx := AudioServer.get_bus_index(bus)
	slider.value = db_to_linear(AudioServer.get_bus_volume_db(idx)) if idx >= 0 else 1.0
	pct.text = "%d%%" % roundi(slider.value * 100.0)
	_sliders[bus] = slider
	return row


func _apply(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		push_warning("PauseMenu: audio bus '%s' not found." % bus)
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for bus in _sliders:
		(_sliders[bus] as HSlider).value = float(cfg.get_value("audio", bus, 1.0))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus in _sliders:
		cfg.set_value("audio", bus, (_sliders[bus] as HSlider).value)
	cfg.save(SETTINGS_PATH)
