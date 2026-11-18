extends Node

@onready var MUSIC_PLAYER: AudioStreamPlayer = $MusicPlayer;
@onready var AMB_PLAYER:AudioStreamPlayer = $AmbiencePlayer;

func play_sound(sound: AudioStream, volume: float = 0.3):
	if !sound: return;

	var stream = AudioStreamPlayer.new();

	stream.bus = "Sfx";
	stream.stream = sound;
	stream.connect("finished", stream.queue_free);
	stream.pitch_scale = randf_range(0.8,1.1);

	stream.volume_db = volume;

	stream.tree_entered.connect(stream.play);
	#original - just in case something goes wrong can reference
	#get_tree().current_scene.add_child(stream);

	add_child(stream);

func play_music(music: AudioStream):
	if MUSIC_PLAYER.stream == music:
		#if same music is already playing...
		return;

	MUSIC_PLAYER.stream = null;
	MUSIC_PLAYER.stream = music;

	MUSIC_PLAYER.play();

func is_music_playing()->bool:
	return MUSIC_PLAYER.playing

func play_ambience(amb: AudioStream):
	if(AMB_PLAYER.stream == amb):
		return;

	AMB_PLAYER.stream = null;
	AMB_PLAYER.stream = amb;

	AMB_PLAYER.play();

func is_amb_playing()->bool:
	return AMB_PLAYER.playing;
