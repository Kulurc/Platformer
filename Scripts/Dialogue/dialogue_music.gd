class_name DialogueMusic
extends DialogueStep
## Start (or stop) music or ambience through the SoundManager autoload.
## Leave `stream` empty to stop that player.

@export var stream: AudioStream
## Off = music player, On = ambience player.
@export var ambience := false


func run(trigger: Node) -> void:
	var sm := trigger.get_node_or_null("/root/SoundManager")
	if sm == null:
		push_warning("DialogueMusic: SoundManager autoload not found.")
		return
	var player: AudioStreamPlayer = sm.AMB_PLAYER if ambience else sm.MUSIC_PLAYER
	if stream == null:
		player.stop()
		player.stream = null
	elif ambience:
		sm.play_ambience(stream)
	else:
		sm.play_music(stream)
