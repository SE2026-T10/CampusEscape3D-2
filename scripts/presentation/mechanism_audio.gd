class_name MechanismAudio
extends Node3D

## Sounds for the Expanded Library's mechanisms (expansion Phase 9), placed
## where they happen (3D, on the SFX bus, paused with the game). It only
## listens; no mechanism script changes:
##   - every puzzle control (keypad dials and ENTER, breakers, valves, pump
##     start): a click; a puzzle solved: a rising chime; a wrong attempt: a buzz
##     (not for the pump, whose wrong setting is the stall bang below);
##   - circuit switches and tool mechanisms (panel cover, pump crank, shutter
##     release): a clunk;
##   - an item taken from the floor or a shelf (the inventory's "… taken"
##     notice): a soft pickup chime;
##   - captioned noises that have no signal of their own here (badge reader,
##     door bolts, shutter, pump stall, thrown items): their sound.
## Refusals (door_locked) and doors opening are already played by AudioDirector.

const POOL := 6
## Caption (NoiseSystem) → sound, for noises without a dedicated hook above.
const CAPTION_SOUNDS := {
	"Badge reader beeps": "reader_beep",
	"Door bolts bang open": "mech_clunk",
	"Shutter rattles up": "shutter_rattle",
	"Pump stalls with a bang": "pump_stall",
	"Glass smashes": "glass_smash",
	"Heavy thud": "item_thud",
	"Something crashes": "item_thud",
}

## Sounds played so far (for tests).
var played: Array[String] = []
var _players: Array[AudioStreamPlayer3D] = []
var _next := 0


func _ready() -> void:
	for i in POOL:
		var p := AudioStreamPlayer3D.new()
		p.name = "Player%d" % i
		p.bus = &"SFX"
		p.unit_size = 4.0
		p.max_distance = 30.0
		add_child(p)
		_players.append(p)
	_connect.call_deferred()


func _connect() -> void:
	for node in get_tree().get_nodes_in_group("interactables"):
		if node is PuzzleControl:
			node.changed.connect(func(_i): play_at("mech_click", node.global_position, -6.0))
			node.pressed.connect(func(): play_at("mech_click", node.global_position, -6.0))
		elif node is ToolMechanism:
			node.operated.connect(func(): play_at("mech_clunk", node.global_position, -2.0))
	for node in get_tree().get_nodes_in_group("puzzles"):
		if node is Puzzle:
			node.solved.connect(func(): play_at("puzzle_solved", node.global_position, -3.0))
			node.feedback.connect(func(_t, good: bool):
				# The pump's wrong setting already sounds as a stall bang (its caption).
				if not good and not node is PumpControl:
					play_at("puzzle_wrong", node.global_position, -2.0))
	for node in get_tree().get_nodes_in_group("circuit_switches"):
		node.feedback.connect(func(_t, good: bool): play_at("mech_clunk" if good else "puzzle_wrong", node.global_position, -2.0))
	var inventory := PlayerInventory.find(self)
	if inventory:
		inventory.notice.connect(_on_notice)
	var noise := NoiseSystem.find(self)
	if noise:
		noise.noise_emitted.connect(_on_noise)


## "<item> taken" (a floor or shelf pickup that worked; refusals are not good).
func _on_notice(text: String, good: bool) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if good and text.ends_with(" taken") and player:
		play_at("item_pickup", player.global_position + Vector3(0, 1.0, 0), -8.0)


func _on_noise(event: NoiseEvent) -> void:
	if CAPTION_SOUNDS.has(event.caption):
		play_at(CAPTION_SOUNDS[event.caption], event.position, 0.0)


func play_at(sound: String, at: Vector3, volume_db := 0.0) -> void:
	played.append(sound)
	var stream := SoundBank.pick(sound)
	if stream == null or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.global_position = at
	p.volume_db = volume_db
	p.play()
