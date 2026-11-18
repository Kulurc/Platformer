class_name DialogueStep
extends Resource
## One item in a DialogueTrigger's `steps` array. In the Inspector, click an empty slot
## and pick "New DialogueLine" (someone speaks) or "New DialogueCall" (call a method).

## Run this step. Awaitable: the trigger waits for it before moving to the next step.
func run(_trigger: Node) -> void:
	pass
