@tool
class_name LevelExit
extends Area2D
## Level exit: when a character walks in, the screen fades to black and `next_scene` loads.
## The next level fades in from black on its own (unless its TetherRig has start_black, in
## which case its intro takes over). Position = top-left corner; drag the orange handles to resize.
##
## `next_scene` is a scene NAME inside SCENES_FOLDER, without ".tscn":
##   "prototype"        -> res://Scenes/prototype.tscn
##   "Levels/Level2"    -> res://Scenes/Levels/Level2.tscn
##   "res://Other/x.tscn" also works (a full path is used as-is).

## Where scene names are looked up. Change this if you keep your levels somewhere else.
const SCENES_FOLDER := "res://Scenes/"

enum ActivatedBy { EITHER, CONTROLLED, BOTH }

## Scene to load, e.g. "prototype" or "Level2". Shown red in the editor if it can't be found.
@export var next_scene := "":
	set(v):
		next_scene = v
		queue_redraw()
## Seconds to fade to black before loading (the next scene fades in over the same time).
@export_range(0.0, 5.0, 0.05, "or_greater") var fade_time := 1.0
## EITHER: whichever character walks in. CONTROLLED: only the one you're playing.
## BOTH: only once both characters are inside.
@export var activated_by := ActivatedBy.EITHER
@export var size := Vector2(64, 160):
	set(v):
		size = v
		_sync()
## Debug: tick to switch this exit OFF while testing (drawn crossed out in the editor).
@export var debug := false:
	set(v):
		debug = v
		queue_redraw()

var _shape: CollisionShape2D
var _used := false


## Turns "prototype" into "res://Scenes/prototype.tscn". "" if empty.
static func resolve(scene: String) -> String:
	var s := scene.strip_edges()
	if s == "":
		return ""
	if not s.begins_with("res://"):
		s = SCENES_FOLDER.path_join(s)
	if not s.ends_with(".tscn") and not s.ends_with(".scn"):
		s += ".tscn"
	return s


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_sync()
	if Engine.is_editor_hint() or debug:
		return
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _used or not body is Character:
		return
	match activated_by:
		ActivatedBy.CONTROLLED:
			if not (body as Character).controlled:
				return
		ActivatedBy.BOTH:
			var inside := {}
			for b in get_overlapping_bodies():
				if b is Character:
					inside[b] = true
			inside[body] = true
			if inside.size() < 2:
				return
	var rig := get_tree().get_first_node_in_group(&"tether_rig")
	if rig == null:
		push_warning("LevelExit: no TetherRig in this level.")
		return
	_used = true
	rig.go_to_scene(next_scene, fade_time)


func _sync() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		for c in get_children():
			if c is CollisionShape2D and c.owner == null:
				remove_child(c)
				c.queue_free()
		_shape = CollisionShape2D.new()
		_shape.shape = RectangleShape2D.new()
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
	(_shape.shape as RectangleShape2D).size = size
	_shape.position = size * 0.5
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var path := resolve(next_scene)
	var ok := path != "" and ResourceLoader.exists(path)
	var col := Color(0.55, 0.95, 0.7) if ok else Color(1.0, 0.35, 0.35)
	draw_rect(Rect2(Vector2.ZERO, size), Color(col, 0.12))
	draw_rect(Rect2(Vector2.ZERO, size), Color(col, 0.7), false, 1.5)
	var label := "EXIT → " + next_scene if ok else ("EXIT: set next_scene" if path == "" else "EXIT: not found\n" + path)
	var y := 14.0
	for line in label.split("\n"):
		draw_string(ThemeDB.fallback_font, Vector2(4, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		y += 14.0
	if debug:
		draw_line(Vector2.ZERO, size, Color(1.0, 0.3, 0.3, 0.7), 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(4, y), "DEBUG: OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.4, 0.4))
