@tool
class_name TetherAnchor
extends Node2D
## A ring the cord can be hooked over. Acts as a pulley between player and companion.
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

var state := 0:  ## 0 idle, 1 in range, 2 hooked
	set(v):
		if v != state:
			state = v
			queue_redraw()


func _ready() -> void:
	add_to_group("anchors")


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
