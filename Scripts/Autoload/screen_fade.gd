extends CanvasLayer
## Autoload "ScreenFade": a black cover that survives scene changes.
## Godot draws one empty frame between unloading a level and loading the next, which flashes
## the default grey background. TetherRig.go_to_scene() switches this cover on once the screen
## is already black; the next level's TetherRig switches it off after it has drawn its own black.

const COLOR := Color(0.02, 0.02, 0.035)  # same as the TetherRig's Blackout

var _rect: ColorRect


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = COLOR
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	visible = false


## Cover the screen (instant).
func hold() -> void:
	visible = true


func is_holding() -> bool:
	return visible


## Uncover after `frames` rendered frames, so whatever is underneath is already drawn.
func release_after(frames: int = 2) -> void:
	for i in frames:
		await RenderingServer.frame_post_draw
	visible = false
