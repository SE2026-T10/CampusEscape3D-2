class_name CodeLock
extends Puzzle

## A keypad or combination lock (Expanded Library, expansion Phase 4): one
## dial per digit (PuzzleControl, E turns it 0 → 9) and an ENTER button.
##   - Needs power when `power_circuit` is set (PowerNetwork); without it the
##     keypad shows NO POWER and ENTER does nothing else.
##   - A wrong code: "CODE REJECTED" with the tries left (no hint about which
##     digits are wrong), the alarm (`alarm_on_wrong`) or a small noise; after
##     `max_attempts` wrong codes, a lockout of `lockout_time` seconds, then
##     fresh tries. Never permanent.
##   - The right code: the door (`door_path`, an AccessDoor) opens, the
##     `reveal_paths` nodes (ItemPickup / DocumentPickup) become available,
##     the objective completes.
## Persistence: stores whether it is solved (and so whether its reveals are
## available). Not stored: the dials, tries and lockout (fresh after a respawn).
## The door it opens stores its own state, from the same snapshot.

@export var code := "0000"
## Circuit that must be powered (empty: none).
@export var power_circuit: StringName = &""
@export var max_attempts := 3
@export var lockout_time := 20.0
## Wrong codes raise the security alarm (radius alarm_radius); otherwise a small noise (wrong_noise_radius).
@export var alarm_on_wrong := true
@export var alarm_radius := 22.0
@export var wrong_noise_radius := 6.0
## AccessDoor opened by the right code (optional).
@export var door_path: NodePath
## Nodes with set_available() made available by the right code (optional).
@export var reveal_paths: Array[NodePath] = []
## Spacing of the dials along local X (metres).
@export var dial_spacing := 0.16

var attempts_left := 3
var lockout_left := 0.0
var dials: Array[PuzzleControl] = []
var enter: PuzzleControl


func _ready() -> void:
	attempts_left = max_attempts
	var digits := PackedStringArray()
	for d in 10:
		digits.append(str(d))
	var n := code.length()
	for i in n:
		var dial := PuzzleControl.new()
		dial.name = "Dial%d" % (i + 1)
		dial.control_name = "Dial %d" % (i + 1)
		dial.values = digits
		dial.size = Vector3(0.11, 0.13, 0.06)
		dial.position = Vector3((i - (n - 1) / 2.0) * dial_spacing, 0.12, 0.0)
		add_child(dial)
		dials.append(dial)
	enter = PuzzleControl.new()
	enter.name = "Enter"
	enter.control_name = "ENTER"
	enter.values = PackedStringArray()
	enter.action_text = "Enter the code"
	enter.size = Vector3(n * dial_spacing * 0.8, 0.08, 0.06)
	enter.position = Vector3(0, -0.08, 0.0)
	add_child(enter)
	enter.pressed.connect(submit)
	super()


func _connect_manager() -> void:
	super()
	var network := PowerNetwork.find(self)
	if network and not network.power_changed.is_connected(_on_power_changed):
		network.power_changed.connect(_on_power_changed)


func _on_power_changed(_circuit: StringName, _on: bool) -> void:
	_refresh()


## The digits currently set on the dials.
func get_entry() -> String:
	var entry := ""
	for dial in dials:
		entry += dial.get_value()
	return entry


## Sets the dials (tests and tools; players turn them with E).
func set_entry(entry: String) -> void:
	for i in mini(entry.length(), dials.size()):
		dials[i].set_index(int(entry[i]))


func has_power() -> bool:
	if power_circuit == &"":
		return true
	var network := PowerNetwork.find(self)
	return network != null and network.is_powered(power_circuit)


## ENTER: checks the dials.
func submit() -> void:
	if is_solved:
		return
	if not has_power():
		feedback.emit("%s has no power." % puzzle_name, false)
		_refresh()
		return
	if lockout_left > 0.0:
		feedback.emit("%s is locked out. Try again in %d s." % [puzzle_name, ceili(lockout_left)], false)
		return
	if get_entry() == code:
		var door := get_node_or_null(door_path) as AccessDoor
		if door:
			door.open()
		_mark_solved()
		feedback.emit("%s: code accepted." % puzzle_name, true)
		return
	attempts_left -= 1
	var text := "%s: code rejected. %d %s left." % [puzzle_name, attempts_left, "try" if attempts_left == 1 else "tries"]
	if attempts_left <= 0:
		lockout_left = lockout_time
		text = "%s: code rejected. Locked out for %d s." % [puzzle_name, int(lockout_time)]
	if alarm_on_wrong:
		_wrong(text + " The alarm is sounding!", alarm_radius)
	else:
		_wrong(text, 0.0)
		var system := NoiseSystem.find(self)
		if system:
			system.emit_noise(global_position, NoiseEvent.Type.INTERACTION, "environment", 0.6, wrong_noise_radius)
	_refresh()


func _process(delta: float) -> void:
	if lockout_left > 0.0:
		lockout_left = maxf(lockout_left - delta, 0.0)
		if lockout_left == 0.0:
			attempts_left = max_attempts
		_refresh()


func _refresh() -> void:
	var blocked := ""
	if is_solved:
		blocked = "unlocked"
	elif lockout_left > 0.0:
		blocked = "locked out (%d s)" % ceili(lockout_left)
	elif not has_power():
		blocked = "no power"
	for dial in dials:
		dial.blocked_reason = blocked
	if enter:
		enter.blocked_reason = blocked if blocked != "no power" else ""
	for path in reveal_paths:
		var node := get_node_or_null(path)
		if node and node.has_method("set_available"):
			node.set_available(is_solved)
	if is_solved:
		_set_display("%s\nACCEPTED" % puzzle_name.to_upper(), Color(0.4, 1.0, 0.55))
	elif not has_power():
		_set_display("%s\nNO POWER" % puzzle_name.to_upper(), Color(0.6, 0.6, 0.65))
	elif lockout_left > 0.0:
		_set_display("%s\nLOCKED OUT %d s" % [puzzle_name.to_upper(), ceili(lockout_left)], Color(1.0, 0.35, 0.3))
	else:
		_set_display("%s\nENTER CODE · %d %s" % [puzzle_name.to_upper(), attempts_left, "TRY" if attempts_left == 1 else "TRIES"], Color(0.85, 0.95, 1.0))


func get_checkpoint_state() -> Dictionary:
	return {"solved": is_solved}


func restore_checkpoint_state(state: Dictionary) -> void:
	is_solved = bool(state.get("solved", false))
	attempts_left = max_attempts
	lockout_left = 0.0
	if not is_solved:
		for dial in dials:
			dial.set_index(0)
	_refresh()
