class_name CircuitSwitch
extends PuzzleControl

## A power switch for one circuit of the level's PowerNetwork (Expanded
## Library, expansion Phase 5): E turns it ON / OFF; the switch always shows
## the circuit's real state.
##   - `reboots_circuit`: switching this one ON also switches that circuit ON
##     and locks its switch for `reboot_lock_time` seconds (the service power
##     reboots the security system: the cameras come back on).
##   - Every change says what it did (`feedback`, shown by ObjectiveHud) and
##     makes a breaker clunk guards nearby can hear.
## No switch is ever one-way, so no combination can block the mission.
## Its position is the PowerNetwork's state (stored at checkpoints); the lock
## is not stored (a respawn unlocks it).

signal feedback(text: String, good: bool)

@export var circuit: StringName = &"surveillance"
@export var circuit_title := "SURVEILLANCE"
## Messages when switched on / off.
@export_multiline var on_text := ""
@export_multiline var off_text := ""
## Circuit forced ON (and its switch locked) when this one is switched ON;
## the message is then `reboot_text` (instead of on_text), kept short for the HUD.
@export var reboots_circuit: StringName = &""
@export var reboot_lock_time := 30.0
@export_multiline var reboot_text := ""
## Breaker clunk heard by guards (metres).
@export var noise_radius := 9.0

var lock_left := 0.0
## Times switched (for tests).
var switches := 0


func _ready() -> void:
	values = PackedStringArray(["OFF", "ON"])
	control_name = circuit_title
	size = Vector3(0.14, 0.24, 0.08)
	add_to_group("puzzles")
	add_to_group("circuit_switches")
	super()
	_sync.call_deferred()


func _sync() -> void:
	var network := PowerNetwork.find(self)
	if network and not network.power_changed.is_connected(_on_power_changed):
		network.power_changed.connect(_on_power_changed)
	var checkpoints := CheckpointManager.find(self)
	if checkpoints and not checkpoints.respawned.is_connected(_on_respawned):
		checkpoints.respawned.connect(_on_respawned)
	_on_power_changed(circuit, network != null and network.is_powered(circuit))


func _on_power_changed(changed: StringName, _on: bool) -> void:
	if changed != circuit:
		return
	var network := PowerNetwork.find(self)
	set_index(1 if network and network.is_powered(circuit) else 0)


## A respawn ends a reboot lock (the lock is not part of the checkpoint).
func _on_respawned(_checkpoint: Checkpoint) -> void:
	lock(0.0)


func lock(seconds: float) -> void:
	lock_left = seconds
	_update_block()


func _process(delta: float) -> void:
	if lock_left > 0.0:
		lock_left = maxf(lock_left - delta, 0.0)
		_update_block()


func _update_block() -> void:
	blocked_reason = "security system rebooting (%d s)" % ceili(lock_left) if lock_left > 0.0 else ""


func _on_interact(by: Node) -> bool:
	if blocked_reason != "":
		feedback.emit("%s: the security system is rebooting. Try again in %d s." % [circuit_title, ceili(lock_left)], false)
		return false
	var network := PowerNetwork.find(self)
	if network == null:
		return false
	var on := not network.is_powered(circuit)
	network.set_powered(circuit, on)
	switches += 1
	var system := NoiseSystem.find(self)
	if system:
		system.emit_noise(global_position, NoiseEvent.Type.INTERACTION, "environment", 0.6, noise_radius)
	var text := on_text if on else off_text
	if on and reboots_circuit != &"":
		network.set_powered(reboots_circuit, true)
		for s in get_tree().get_nodes_in_group("circuit_switches"):
			if s.circuit == reboots_circuit:
				s.lock(reboot_lock_time)
		if reboot_text != "":
			text = reboot_text
	feedback.emit(text, true)
	return true


func get_prompt(by: Node) -> String:
	if blocked_reason != "":
		return "%s · %s" % [control_name, blocked_reason]
	return "%s power: %s → %s" % [control_name, values[index], values[(index + 1) % 2]]
