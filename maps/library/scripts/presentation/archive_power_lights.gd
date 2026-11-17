class_name ArchivePowerLights
extends Node3D

## The restricted archive's lighting follows its power (approved by the owner,
## 2026-10-31). The wiring chart says A1 ARCHIVE LIGHTS shares the vault lock's
## feed, so until the breaker puzzle powers `circuit` (archive_access) the
## archive's ceiling lamps are out and the emergency lights (this node's
## children named Beacon*: an OmniLight3D "Light" and a red lens) pulse slowly.
## When the circuit comes on, the lamps flicker back on with a clunk and the
## emergency lights go dark. Presentation only: guards see with physics rays and
## the player's visibility does not depend on light, so detection is unchanged.
## The state is never saved: it follows PowerNetwork, which is in the checkpoint
## state, and a restored "off" switches the lamps off again at once.
##
## Never more lights than before: the beacons are only visible while the lamps
## are hidden, so no mesh is reached by more omni lights than with the lamps on.

@export var circuit := &"archive_access"
## The archive's ceiling lamps (OmniLight3D), relative to this node.
@export var lamps: Array[NodePath] = []
## Seconds per emergency pulse.
@export var pulse_period := 2.4

## The lamps are lit (for tests).
var lit := true
## Times the lamps came on with the flicker (for tests).
var flickers := 0

var _lamps: Array[Light3D] = []
var _energy: Array[float] = []
var _beacons: Array[OmniLight3D] = []
var _beacon_energy: Array[float] = []
var _lenses: Array[Node3D] = []
var _clock := 0.0
var _flicker: Tween
var _clunk: AudioStreamPlayer3D


func _ready() -> void:
	for p in lamps:
		var l := get_node_or_null(p) as Light3D
		if l == null:
			push_warning("ArchivePowerLights: no lamp at %s" % p)
			continue
		_lamps.append(l)
		_energy.append(l.light_energy)
	for b in get_children():
		if b.name.begins_with("Beacon"):
			var light := b.get_node_or_null("Light") as OmniLight3D
			if light:
				_beacons.append(light)
				_beacon_energy.append(light.light_energy)
			var lens := b.get_node_or_null("Lens") as Node3D
			if lens:
				_lenses.append(lens)
	_clunk = AudioStreamPlayer3D.new()
	_clunk.name = "Clunk"
	_clunk.bus = &"SFX"
	_clunk.unit_size = 4.0
	_clunk.max_distance = 30.0
	add_child(_clunk)
	var network := PowerNetwork.find(self)
	if network:
		network.power_changed.connect(_on_power_changed)
		_set_lit(network.is_powered(circuit), false)
	else:
		_set_lit(true, false)


func _process(delta: float) -> void:
	if lit or _beacons.is_empty():
		return
	_clock += delta
	var k := 0.55 + 0.45 * sin(TAU * _clock / pulse_period)
	for i in _beacons.size():
		_beacons[i].light_energy = _beacon_energy[i] * k


func _on_power_changed(c: StringName, on: bool) -> void:
	if c == circuit:
		_set_lit(on, on)


func _set_lit(on: bool, flicker: bool) -> void:
	if _flicker:
		_flicker.kill()
		_flicker = null
	lit = on
	for b in _beacons:
		b.visible = not on
	for lens in _lenses:
		lens.visible = not on
	if not on or not flicker:
		_show_lamps(on)
		return
	# Back on: off, on, off, on over about 0.7 s, then steady; a clunk where it happens.
	flickers += 1
	_clunk.stream = SoundBank.pick("mech_clunk")
	_clunk.play()
	_show_lamps(false)
	_flicker = create_tween()
	for step in [[0.12, true], [0.08, false], [0.2, true], [0.1, false], [0.18, true]]:
		_flicker.tween_interval(step[0])
		_flicker.tween_callback(_show_lamps.bind(step[1]))


func _show_lamps(on: bool) -> void:
	for i in _lamps.size():
		_lamps[i].visible = on
		_lamps[i].light_energy = _energy[i]
