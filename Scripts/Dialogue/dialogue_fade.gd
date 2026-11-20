class_name DialogueFade
extends DialogueStep
## Fade the screen from black (reveal) or to black (hide). Speech bubbles stay visible on
## the black, so you can run a conversation in the dark and reveal the scene afterwards.
## Start a level black with the TetherRig's `start_black` option.

enum Direction { FROM_BLACK, TO_BLACK }

@export var direction := Direction.FROM_BLACK
@export_range(0.0, 10.0, 0.05, "or_greater") var duration := 1.5
## On: the next step waits for the fade to finish. Off: the fade runs alongside the next steps.
@export var wait_until_done := true


func run(trigger: Node) -> void:
	var b := trigger.get_tree().get_first_node_in_group("blackout") as Blackout
	if b == null:
		push_warning("DialogueFade: no Blackout found (is there a TetherRig in the level?).")
		return
	var target := 0.0 if direction == Direction.FROM_BLACK else 1.0
	if wait_until_done:
		await b.fade_to(target, duration)
	else:
		b.fade_to(target, duration)
