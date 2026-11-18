class_name DialogueCall
extends DialogueStep
## Calls `method` on `target` when the sequence reaches this step.
## Drag the node from the Scene dock onto `target`. If the method is a coroutine
## (uses await), the sequence waits for it to finish.

@export var target: NodePath
@export var method: StringName
@export var args: Array = []


func run(trigger: Node) -> void:
	var node := _resolve(trigger)
	if node == null:
		push_warning("DialogueCall: target '%s' not found from %s." % [target, trigger.name])
		return
	if not node.has_method(method):
		push_warning("DialogueCall: %s has no method '%s'." % [node.name, method])
		return
	await node.callv(method, args)


## Inspector paths may be relative to the trigger or to the scene root - accept either.
func _resolve(trigger: Node) -> Node:
	if target.is_empty():
		return null
	var n := trigger.get_node_or_null(target)
	if n == null and trigger.owner:
		n = trigger.owner.get_node_or_null(target)
	if n == null and trigger.get_tree().current_scene:
		n = trigger.get_tree().current_scene.get_node_or_null(target)
	return n
