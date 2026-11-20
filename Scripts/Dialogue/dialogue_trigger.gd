@tool
class_name DialogueTrigger
extends Area2D
## Attach to an Area2D. When either character walks in, runs `steps` in order.
## If the Area2D has no CollisionShape2D/CollisionPolygon2D of its own, one is made from `size`
## (position = top-left corner). Only one sequence plays at a time; others wait their turn.

enum ActivatedBy { EITHER, CONTROLLED, BOTH }

## Steps run in order. Add a slot and pick: DialogueLine (speech), DialogueCall (call a
## method), DialogueWait (pause), DialogueMusic (start/stop music or ambience).
## In the editor, pasted or duplicated steps are made unique automatically (no "Make Unique"
## needed): a step is never shared between two slots or two triggers.
@export var steps: Array[DialogueStep] = []:
	set(v):
		steps = v
		if Engine.is_editor_hint() and is_inside_tree():
			_make_steps_unique()
@export var one_shot := true
## EITHER: whichever character walks in. CONTROLLED: only the one you're playing.
## BOTH: fires once both characters are inside.
@export var activated_by := ActivatedBy.EITHER
@export var size := Vector2(96, 140):
	set(v):
		size = v
		_sync()
## Debug: tick to switch this trigger OFF so you can jump straight into play-testing.
## If it would have faded the screen in from black (an intro), the level starts uncovered
## instead. Shown in red in the editor. Untick before shipping.
@export var debug := false:
	set(v):
		debug = v
		queue_redraw()

static var _playing: DialogueTrigger = null

var _fired := false
var _auto_shape: CollisionShape2D


func _enter_tree() -> void:
	add_to_group(&"dialogue_triggers")
	if Engine.is_editor_hint():
		_make_steps_unique()  # catches Ctrl+D / copy-pasted trigger nodes


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_sync()
	if Engine.is_editor_hint():
		return
	if debug:
		monitoring = false
		if _reveals_from_black():
			_clear_black.call_deferred()  # after the TetherRig has set up its starting black
		return
	body_entered.connect(_on_body_entered)


## True if this sequence would lift a black screen (DialogueFade FROM_BLACK or reveal_tether).
func _reveals_from_black() -> bool:
	for st in steps:
		if st is DialogueFade and st.direction == DialogueFade.Direction.FROM_BLACK:
			return true
		if st is DialogueCall and st.method in [&"reveal_tether", &"fade_from_black"]:
			return true
	return false


func _clear_black() -> void:
	var b := get_tree().get_first_node_in_group("blackout") as Blackout
	if b:
		b.set_black(false)


func _sync() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c != _auto_shape and c.owner != null and (c is CollisionShape2D or c is CollisionPolygon2D):
			_drop_stray_shapes()
			if _auto_shape:
				remove_child(_auto_shape)
				_auto_shape.queue_free()
				_auto_shape = null
			return  # user-provided shape wins
	if _auto_shape == null:
		_drop_stray_shapes()
		_auto_shape = CollisionShape2D.new()
		_auto_shape.shape = RectangleShape2D.new()
		# Internal child: not shown in the Scene dock, not copied by Ctrl+D, never saved.
		add_child(_auto_shape, false, Node.INTERNAL_MODE_FRONT)
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
	if debug:
		return
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
		if debug:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.3, 0.3, 0.9), false, 2.0)
			draw_line(Vector2.ZERO, size, Color(1.0, 0.3, 0.3, 0.6), 1.5)
			draw_string(ThemeDB.fallback_font, Vector2(4, 28), "DEBUG: OFF",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.4, 0.4))


# ---------------------------------------------------------------- editor: no shared steps

## Replace any step that is also used by an earlier slot, or by another trigger in the
## scene, with its own copy. Pasting a step (or a whole array) shares the same resource,
## so editing one would silently edit the other.
func _make_steps_unique() -> void:
	if not is_inside_tree():
		return
	var used := {}
	for t in get_tree().get_nodes_in_group(&"dialogue_triggers"):
		if t != self and t is DialogueTrigger:
			for st in t.steps:
				if st:
					used[st] = true
	for i in steps.size():
		var st := steps[i]
		if st == null:
			continue
		if used.has(st):
			st = _copy_step(st)
			steps[i] = st
		used[st] = true


static func _copy_step(st: DialogueStep) -> DialogueStep:
	var c := st.duplicate() as DialogueStep  # sounds/streams stay shared (they're files)
	for prop in c.get_property_list():
		if prop.usage & PROPERTY_USAGE_STORAGE:
			var v = c.get(prop.name)
			if v is Array or v is Dictionary:
				c.set(prop.name, v.duplicate(true))  # e.g. DialogueCall.args
	return c

## Older versions added this shape as a normal child, so Ctrl+D copied it and every
## duplicate kept a stale extra shape. Remove any unowned leftovers (never your own nodes).
func _drop_stray_shapes() -> void:
	for c in get_children():
		if c is CollisionShape2D and c.owner == null and c != _auto_shape:
			remove_child(c)
			c.queue_free()
