@tool
class_name TetherAnchor
extends Node2D
## A ring the cord can be hooked over. Acts as a pulley between player and companion.
## The faint circle in the editor shows the default hook range (Tether.anchor_range).

@export var radius := 9.0
@export var editor_range_preview := 180.0

var state := 0:  ## 0 idle, 1 in range, 2 hooked
	set(v):
		if v != state:
			state = v
			queue_redraw()


func _ready() -> void:
	add_to_group("anchors")


func _draw() -> void:
	var c := Color(1.0, 0.72, 0.3)
	if state == 0:
		c.a = 0.55
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, c, 3.0, true)
	if state == 1:
		draw_arc(Vector2.ZERO, radius + 7.0, 0.0, TAU, 24, Color(c, 0.5), 1.5, true)
	if state == 2:
		draw_circle(Vector2.ZERO, 3.0, c)
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, editor_range_preview, 0.0, TAU, 64, Color(1, 0.7, 0.3, 0.15), 1.0)
