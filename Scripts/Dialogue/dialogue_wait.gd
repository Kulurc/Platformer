class_name DialogueWait
extends DialogueStep
## Pause the sequence for a while (e.g. a beat of silence between lines). Respects the pause menu.

@export_range(0.0, 30.0, 0.05, "or_greater") var seconds := 1.0


func run(trigger: Node) -> void:
	await trigger.get_tree().create_timer(seconds, false).timeout
