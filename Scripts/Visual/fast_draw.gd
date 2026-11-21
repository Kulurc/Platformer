class_name FastDraw
extends RefCounted
## Batch-friendly replacements for draw_circle / small draw_colored_polygon calls in _draw().
##
## Why: Godot's Compatibility renderer (used by web builds, and by low-end desktop GPUs) can
## merge many rects / textured rects / 3-4 point primitives into one draw call, but every
## draw_circle and draw_colored_polygon is its own draw call. The meadow art drew thousands of
## circles, which made the browser build choppy. These helpers draw the same shapes in a
## form the renderer can merge:
##   circle(...)  -> a tinted, anti-aliased white disc texture drawn as a rect
##   tri(...)     -> draw_primitive with 3 points
##   quad(...)    -> draw_primitive with 4 points (points in order around the shape)
## Nodes using circle() should set `texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`
## (see use_on()) so tiny circles stay smooth instead of shimmering.

const _DISC_SIZE := 64

static var _disc: Texture2D


## The shared white disc (alpha-antialiased edge, with mipmaps).
static func disc() -> Texture2D:
	if _disc == null:
		var img := Image.create(_DISC_SIZE, _DISC_SIZE, false, Image.FORMAT_RGBA8)
		var c := (_DISC_SIZE - 1) * 0.5
		var r := _DISC_SIZE * 0.5
		for y in _DISC_SIZE:
			for x in _DISC_SIZE:
				var d := Vector2(x - c, y - c).length()
				img.set_pixel(x, y, Color(1, 1, 1, clampf(r - d, 0.0, 1.0)))
		img.generate_mipmaps()
		_disc = ImageTexture.create_from_image(img)
	return _disc


## Call once on a node (e.g. in _ready) that draws circles with circle().
static func use_on(ci: CanvasItem) -> void:
	ci.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


static func circle(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var r := Vector2(radius, radius)
	ci.draw_texture_rect(disc(), Rect2(center - r, r * 2.0), false, color)


static func tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	ci.draw_primitive(PackedVector2Array([a, b, c]), PackedColorArray([color, color, color]), PackedVector2Array())


## 4 points in order around the quad; `colors` = 1 colour for all, or 4 (one per point).
static func quad(ci: CanvasItem, pts: PackedVector2Array, colors: PackedColorArray) -> void:
	if colors.size() == 1:
		colors = PackedColorArray([colors[0], colors[0], colors[0], colors[0]])
	ci.draw_primitive(pts, colors, PackedVector2Array())
