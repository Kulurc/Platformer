class_name DialogueSound
extends DialogueStep
## Play a one-shot sound effect through the SoundManager (play_sound). Use it in a
## DialogueTrigger (a bird flapping away as you walk past, a stinger before a line) or in the
## TetherRig's `on_sever` list.

@export var sound: AudioStream
@export_range(-40.0, 12.0, 0.5) var volume_db := 0.0
## Off = the SoundManager's usual small random pitch change. On = always the exact same pitch.
@export var exact_pitch := false
## On = the next step waits until the sound has finished playing.
@export var wait_until_done := false


func run(trigger: Node) -> void:
	var sm := trigger.get_node_or_null("/root/SoundManager")
	if sm == null or sound == null:
		return
	if exact_pitch:
		sm.play_sound_exact(sound, volume_db)
	else:
		sm.play_sound(sound, volume_db)
	if wait_until_done:
		await trigger.get_tree().create_timer(sound.get_length(), false).timeout
