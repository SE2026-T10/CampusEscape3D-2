class_name AmbientEmitter
extends AudioStreamPlayer3D

## A positional environmental sound. With `loop_sound` set it plays that loop
## continuously (the clock's tick). Otherwise it plays a random one of `sounds`
## every `interval_min`–`interval_max` seconds (page turns, a book being put
## down, a chair creaking), so the library sounds occupied. Decoration only:
## these are not NoiseSystem events and guards don't react to them.

@export var sounds: PackedStringArray = []
@export var loop_sound := ""
@export var interval_min := 8.0
@export var interval_max := 20.0

## Sounds played so far (for tests).
var played_count := 0

var _wait := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	bus = &"Ambience"
	_rng.seed = hash(name)
	if loop_sound != "":
		stream = SoundBank.pick(loop_sound)
		play()
		played_count += 1
	_wait = _rng.randf_range(interval_min * 0.3, interval_max)


func _process(delta: float) -> void:
	if loop_sound != "" or sounds.is_empty():
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = _rng.randf_range(interval_min, interval_max)
		stream = SoundBank.pick(sounds[_rng.randi() % sounds.size()])
		pitch_scale = _rng.randf_range(0.9, 1.1)
		play()
		played_count += 1
