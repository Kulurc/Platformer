class_name DialogueMusic
extends DialogueStep
## Start, change or stop the music or the ambience through the SoundManager autoload.
## Leave `stream` empty to stop that player. Use it in a DialogueTrigger's steps (an area the
## player walks into) or in the TetherRig's `on_sever` list.

@export var stream: AudioStream
## Off = music player, On = ambience player.
@export var ambience := false
## Seconds to fade. 0 = instant (a hard cut - e.g. kill the ambience the moment the cord snaps).
## Changing to a different track fades the old one out and the new one in.
@export_range(0.0, 10.0, 0.1, "or_greater") var fade := 1.5
## Volume of the new track in dB (0 = as imported).
@export_range(-40.0, 12.0, 0.5) var volume_db := 0.0
## On = only change the volume of what's already playing to `volume_db` (ducking), keep the track.
@export var volume_only := false


func run(trigger: Node) -> void:
	var sm := trigger.get_node_or_null("/root/SoundManager")
	if sm == null:
		push_warning("DialogueMusic: SoundManager autoload not found.")
		return
	if volume_only:
		if ambience:
			sm.set_ambience_volume(volume_db, fade)
		else:
			sm.set_music_volume(volume_db, fade)
	elif ambience:
		sm.play_ambience_fade(stream, fade, volume_db)
	else:
		sm.play_music_fade(stream, fade, volume_db)
