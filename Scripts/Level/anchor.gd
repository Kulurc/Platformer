@tool
class_name TetherAnchor
extends Node2D
## A ring the cord can be hooked over. Acts as a pulley between player and companion.
## Use the prefab Scenes/Prefabs/tether_anchor.tscn: edit the prefab (e.g. its hook sound) and
## every ring follows.
## The faint circle in the editor shows the default hook range (Tether.anchor_range).

@export var radius := 9.0
@export var editor_range_preview := 180.0
## Ring colour. Levels with a LevelArt node may set this (the meadow uses saturated yellow).
@export var color := Color(1.0, 0.72, 0.3):
	set(v):
		color = v
		queue_redraw()
## Soft glow behind the ring and full brightness while idle (easier to spot on bright skies).
@export var glow := false:
	set(v):
		glow = v
		queue_redraw()

@export_group("Sound")
## Plays when the cord hooks onto this ring. Optional.
@export var hook_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var hook_volume_db := -8.0
## Plays when the cord comes off this ring. Optional.
@export var release_sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var release_volume_db := -14.0

var state := 0:  ## 0 idle, 1 in range, 2 hooked
	set(v):
		if v != state:
			if v == 2:
				_play(hook_sound, hook_volume_db)
			elif state == 2:
				_play(release_sound, release_volume_db)
			state = v
			queue_redraw()


func _ready() -> void:
	add_to_group("anchors")


func _play(stream: AudioStream, db: float) -> void:
	if stream == null or Engine.is_editor_hint():
		return
	var sm := get_node_or_null("/root/SoundManager")
	if sm:
		sm.play_sound(stream, db)


func _draw() -> void:
	var c := color
	if state == 0 and not glow:
		c.a = 0.55
	if glow:
		draw_circle(Vector2.ZERO, radius * 2.0, Color(c, 0.16))
		draw_circle(Vector2.ZERO, radius * 1.4, Color(c, 0.14))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, c, 3.2 if glow else 3.0, true)
	if state == 1:
		draw_arc(Vector2.ZERO, radius + 7.0, 0.0, TAU, 24, Color(c, 0.5), 1.5, true)
	if state == 2:
		draw_circle(Vector2.ZERO, 3.0, c)
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, editor_range_preview, 0.0, TAU, 64, Color(1, 0.7, 0.3, 0.15), 1.0)
