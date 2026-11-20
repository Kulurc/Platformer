@tool
extends EditorPlugin
## Resize handles for every node with a top-left `size` box: Block (and CrumbleBlock, Gate),
## Zone, Plate, DialogueTrigger, LevelExit.
##   Drag an edge or corner square to resize. The opposite edge stays put.
##   Snaps to SNAP pixels; hold Ctrl while dragging to resize freely.
##   Ctrl+Z undoes a resize like any other edit.

const SNAP := 8.0
const MIN_SIZE := 8.0
const HANDLE := 7.0        # half-size of a handle square, in screen pixels
const COLOR := Color(1.0, 0.72, 0.25)

var _target: Node2D
var _drag := -1            # handle index while dragging, else -1
var _start_size: Vector2
var _start_pos: Vector2
var _start_xf: Transform2D    # node's local transform at drag start
var _start_screen: Transform2D  # local -> screen at drag start


func _handles(object: Object) -> bool:
	return object is Block or object is Zone or object is Plate or object is DialogueTrigger or object is LevelExit


func _edit(object: Object) -> void:
	_target = object as Node2D
	_drag = -1
	update_overlays()


func _make_visible(visible: bool) -> void:
	if not visible:
		_target = null
		_drag = -1
	update_overlays()


# Handles 0..7: corners TL, TR, BR, BL, then edges T, R, B, L.
# Each is (x, y) in box fractions, so (0, 0.5) = middle of the left edge.
const POINTS := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
		Vector2(0.5, 0), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0, 0.5)]


func _screen_xf() -> Transform2D:
	return _target.get_viewport_transform() * _target.get_global_transform()


func _valid() -> bool:
	return is_instance_valid(_target) and _target.is_inside_tree() and _target.is_visible_in_tree()


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if not _valid():
		return
	var size: Vector2 = _target.size
	var xf := _screen_xf()
	var corners := PackedVector2Array()
	for i in 4:
		corners.append(xf * (POINTS[i] * size))
	corners.append(corners[0])
	overlay.draw_polyline(corners, COLOR, 1.5)
	for p in POINTS:
		var c: Vector2 = xf * (p * size)
		var r := Rect2(c - Vector2(HANDLE, HANDLE), Vector2(HANDLE, HANDLE) * 2.0)
		overlay.draw_rect(r, Color(0.1, 0.1, 0.12))
		overlay.draw_rect(r.grow(-1.5), COLOR)
	if _drag >= 0:
		overlay.draw_string(ThemeDB.fallback_font, corners[0] + Vector2(0, -8),
				"%d × %d" % [roundi(size.x), roundi(size.y)], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR)


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not _valid():
		return false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hit := _handle_at(event.position)
			if hit < 0:
				return false
			_drag = hit
			_start_size = _target.size
			_start_pos = _target.position
			_start_xf = _target.transform
			_start_screen = _screen_xf()
			return true
		elif _drag >= 0:
			_finish()
			return true

	if event is InputEventMouseMotion:
		if _drag >= 0:
			_resize_to(event.position, event.ctrl_pressed)
			return true
		# show the resize cursor when hovering a handle
		var h := _handle_at(event.position)
		if h >= 0:
			var shapes := [Control.CURSOR_FDIAGSIZE, Control.CURSOR_BDIAGSIZE,
					Control.CURSOR_FDIAGSIZE, Control.CURSOR_BDIAGSIZE,
					Control.CURSOR_VSIZE, Control.CURSOR_HSIZE, Control.CURSOR_VSIZE, Control.CURSOR_HSIZE]
			DisplayServer.cursor_set_shape(shapes[h])
	return false


func _handle_at(screen_pos: Vector2) -> int:
	var xf := _screen_xf()
	for i in POINTS.size():
		var c: Vector2 = xf * (POINTS[i] * _target.size)
		if absf(screen_pos.x - c.x) <= HANDLE + 2.0 and absf(screen_pos.y - c.y) <= HANDLE + 2.0:
			return i
	return -1


func _snap(v: float, free: bool) -> float:
	return v if free else roundf(v / SNAP) * SNAP


func _resize_to(screen_pos: Vector2, free: bool) -> void:
	# Work in the node's local space as it was when the drag began.
	var m: Vector2 = _start_screen.affine_inverse() * screen_pos
	var p: Vector2 = POINTS[_drag]
	var left := 0.0
	var top := 0.0
	var right := _start_size.x
	var bottom := _start_size.y
	# Snap edges in world space so boxes line up with each other, not just with themselves.
	var origin := _start_pos
	if p.x == 0.0:
		left = minf(_snap(m.x + origin.x, free) - origin.x, right - MIN_SIZE)
	elif p.x == 1.0:
		right = maxf(_snap(m.x + origin.x, free) - origin.x, MIN_SIZE)
	if p.y == 0.0:
		top = minf(_snap(m.y + origin.y, free) - origin.y, bottom - MIN_SIZE)
	elif p.y == 1.0:
		bottom = maxf(_snap(m.y + origin.y, free) - origin.y, MIN_SIZE)
	_target.size = Vector2(right - left, bottom - top)
	_target.position = _start_xf * Vector2(left, top)
	update_overlays()


func _finish() -> void:
	var new_size: Vector2 = _target.size
	var new_pos: Vector2 = _target.position
	_drag = -1
	if new_size == _start_size and new_pos == _start_pos:
		update_overlays()
		return
	var ur := get_undo_redo()
	ur.create_action("Resize %s" % _target.name)
	ur.add_do_property(_target, "size", new_size)
	ur.add_do_property(_target, "position", new_pos)
	ur.add_do_method(self, "update_overlays")
	ur.add_undo_property(_target, "size", _start_size)
	ur.add_undo_property(_target, "position", _start_pos)
	ur.add_undo_method(self, "update_overlays")
	ur.commit_action(false)  # already applied while dragging
