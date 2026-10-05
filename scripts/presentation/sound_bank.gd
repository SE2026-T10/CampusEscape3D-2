class_name SoundBank
extends RefCounted

## Names of the game's sounds and where they live. Every sound is synthesised
## by tools/generate_audio.gd into assets/audio/<name>.wav. Names with
## variations ("player_step") pick one of <name>_1.wav … <name>_N.wav.

const DIR := "res://assets/audio/"
## Sounds with numbered variations, and how many.
const VARIATIONS := {"player_step": 4, "guard_step": 4}
## Every single-file sound.
const SINGLE := ["guard_keys", "guard_radio", "card_pickup", "objective_complete", "checkpoint", "door_locked",
	"door_open", "notice", "suspicious", "alarm", "lost_track", "caught", "victory", "ui_hover", "ui_click",
	"ui_pause", "ui_resume", "amb_room_tone", "amb_clock_tick", "amb_page_turn", "amb_book_thud",
	"amb_chair_creak", "music_tension", "music_chase"]
## Sounds imported with forward looping.
const LOOPED := ["amb_room_tone", "amb_clock_tick", "music_tension", "music_chase"]

static var _rng := RandomNumberGenerator.new()


## The stream for `name`, a random variation if it has several, or null if unknown.
static func pick(name: String) -> AudioStream:
	if VARIATIONS.has(name):
		return load(DIR + "%s_%d.wav" % [name, _rng.randi_range(1, VARIATIONS[name])])
	if name in SINGLE:
		return load(DIR + name + ".wav")
	push_warning("Unknown sound '%s'." % name)
	return null


## Every file the game expects to find.
static func all_files() -> PackedStringArray:
	var files := PackedStringArray()
	for name in VARIATIONS:
		for i in VARIATIONS[name]:
			files.append(DIR + "%s_%d.wav" % [name, i + 1])
	for name in SINGLE:
		files.append(DIR + name + ".wav")
	return files
