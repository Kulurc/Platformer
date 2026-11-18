@tool
class_name DialogueTrigger
extends Area2D
## Attach to an Area2D. When either character walks in, runs `steps` in order.
## If the Area2D has no CollisionShape2D/CollisionPolygon2D of its own, one is made from `size`
## (position = top-left corner). Only one sequence plays at a time; others wait their turn.

enum ActivatedBy { EITHER, CONTROLLED, BOTH }

## Steps run in order. Add a slot and pick: DialogueLine (speech), DialogueCall (call a
## method), DialogueWait (pause), DialogueMusic (start/stop music or ambience).
@export var steps: Array[DialogueStep] = []
@export var one_shot := true
## EITHER: whichever character walks in. CONTROLLED: only the one you're playing.
## BOTH: fires once both characters are inside.
@export var activated_by := ActivatedBy.EITHER
@export var size := Vector2(96, 140):
	set(v):
		size = v
		_sync()

static var _playing: DialogueTrigger = null

var _fired := false
var _auto_shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_sync()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _sync() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c != _auto_shape and (c is CollisionShape2D or c is CollisionPolygon2D):
			return  # user-provided shape wins
	if _auto_shape == null:
		_auto_shape = CollisionShape2D.new()
		_auto_shape.shape = RectangleShape2D.new()
		add_child(_auto_shape)
	(_auto_shape.shape as RectangleShape2D).size = size
	_auto_shape.position = size * 0.5
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if not body is Character or (one_shot and _fired):
		return
	match activated_by:
		ActivatedBy.CONTROLLED:
			if not (body as Character).controlled:
				return
		ActivatedBy.BOTH:
			var inside := {body: true}
			for b in get_overlapping_bodies():
				if b is Character:
					inside[b] = true
			if inside.size() < 2:
				return
	play()


## Runs the sequence. Also callable from code or from another DialogueCall.
func play() -> void:
	_fired = true
	while _playing != null and is_instance_valid(_playing):
		await get_tree().process_frame
	_playing = self
	for step in steps:
		if step:
			await step.run(self)
	_playing = null


func _draw() -> void:
	if Engine.is_editor_hint() and _auto_shape:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.9, 0.4, 0.12))
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.9, 0.4, 0.5), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(4, 14), "Dialogue (%d)" % steps.size(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.9, 0.4, 0.8))
