@tool
class_name Zone
extends Area2D
## Trigger volume. Position = top-left corner. For checkpoints, put the bottom edge on the floor.
##   KILL        fall in = respawn
##   CHECKPOINT  banks progress (only if your partner is with you, or you've severed)
##   PHASE       entering escalates the relationship to `phase` (never goes back)
##   STAY        both of you inside, still tethered, for `stay_time` = the "stayed" ending
##   EXIT        reaching it severed = the "free" ending

enum Kind { KILL, CHECKPOINT, PHASE, STAY, EXIT }

@export var kind := Kind.CHECKPOINT:
	set(v):
		kind = v
		queue_redraw()
@export var size := Vector2(64, 140):
	set(v):
		size = v
		_sync()
@export_range(1, 9) var phase := 2   ## 1 = first entry in the TetherRig's phase_profiles
@export var stay_time := 3.0

var activated := false:
	set(v):
		activated = v
		queue_redraw()
var progress := 0.0  ## STAY fill, 0..1

var _shape: CollisionShape2D
var _time := 0.0


## Join the group on entering the tree (before any _ready), so the TetherRig finds every
## zone no matter where the Zones node sits in the scene tree (above or below the rig).
func _enter_tree() -> void:
	add_to_group("zones")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_sync()


func _process(dt: float) -> void:
	if (kind == Kind.STAY or kind == Kind.EXIT) and not Engine.is_editor_hint():
		_time += dt
		queue_redraw()


func _sync() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_drop_stray_shapes()
		_shape = CollisionShape2D.new()
		_shape.shape = RectangleShape2D.new()
		# Internal child: not shown in the Scene dock, not copied by Ctrl+D, never saved.
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
	(_shape.shape as RectangleShape2D).size = size
	_shape.position = size * 0.5
	queue_redraw()


func spawn_point() -> Vector2:
	return global_position + Vector2(size.x * 0.5, size.y - 22.0)


func _draw() -> void:
	var editor := Engine.is_editor_hint()
	match kind:
		Kind.KILL:
			if editor:
				draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.2, 0.2, 0.15))
		Kind.PHASE:
			if editor:
				draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.4, 1.0, 0.2))
				draw_string(ThemeDB.fallback_font, Vector2(4, 16), "Phase %d" % phase)
		Kind.CHECKPOINT:
			pass;
			#if editor:
				#draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 0.8, 1.0, 0.25), false, 1.0)
			#var base := Vector2(size.x * 0.5, size.y)
			#var c := Color(0.55, 0.85, 1.0, 0.9) if activated else Color(0.5, 0.55, 0.65, 0.5)
			#draw_line(base, base + Vector2(0, -44), c, 2.0)
			#draw_colored_polygon(PackedVector2Array([
				#base + Vector2(0, -44), base + Vector2(14, -38), base + Vector2(0, -32)]), c)
		Kind.STAY:
			var pulse := 0.5 + 0.5 * sin(_time * 1.7)
			for i in 4:
				var inset := Vector2(i * 8.0, i * 8.0)
				draw_rect(Rect2(inset, size - inset * 2.0), Color(1.0, 0.75, 0.45, 0.04 + 0.025 * pulse))
			if progress > 0.0:
				draw_rect(Rect2(Vector2(0, size.y - 3.0), Vector2(size.x * progress, 3.0)), Color(1.0, 0.8, 0.5, 0.7))
			if editor:
				draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.75, 0.45, 0.5), false, 1.0)
		Kind.EXIT:
			var flicker := 0.5 + 0.5 * sin(_time * 0.9)
			for i in 4:
				var inset := Vector2(i * 10.0, i * 10.0)
				draw_rect(Rect2(inset, size - inset * 2.0), Color(0.85, 0.92, 1.0, 0.04 + 0.02 * flicker))
			if editor:
				draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.92, 1.0, 0.5), false, 1.0)

## Older versions added this shape as a normal child, so Ctrl+D copied it and every
## duplicate kept a stale extra shape. Remove any unowned leftovers (never your own nodes).
func _drop_stray_shapes() -> void:
	for c in get_children():
		if c is CollisionShape2D and c.owner == null and c != _shape:
			remove_child(c)
			c.queue_free()
