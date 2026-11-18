class_name DialogueLine
extends DialogueStep
## A speech bubble over whoever is speaking. Speakers are matched by Character.speaker
## (Wisp = GIRL, Ember = BOY), and the bubble uses that character's bubble_tint.

enum Speaker { GIRL, BOY }

@export var speaker := Speaker.GIRL
## Supports BBCode: [shake], [wave], [tornado], [rainbow], [pulse], [fade], [color=...], [b], [i] ...
## (angle-bracket form like <shake>...</shake> works too).
@export_multiline var message := ""
## Letters revealed per second. 0 = whole message at once.
@export_range(0.0, 120.0, 1.0, "or_greater") var text_speed := 30.0
## dB added to the blip (default -10). 0 = as recorded, -100 = silent, +10 = louder.
@export_range(-100.0, 24.0, 0.5) var text_volume := -10.0
## Played on every revealed letter (spaces skipped), pitch-randomised by SoundManager.
@export var text_sound: AudioStream
## Seconds the finished message stays up before the next step.
@export_range(0.0, 30.0, 0.1, "or_greater") var appear_time := 5.0


func run(trigger: Node) -> void:
	var who := find_speaker(trigger.get_tree(), speaker)
	if who == null:
		push_warning("DialogueLine: no Character with speaker %s in the scene." % Speaker.keys()[speaker])
		return
	await SpeechBubble.of(who).say(self, who.bubble_tint)


static func find_speaker(tree: SceneTree, s: Speaker) -> Character:
	for n in tree.get_nodes_in_group("tether_bodies"):
		var c := n as Character
		if c and c.speaker == s:
			return c
	return null
