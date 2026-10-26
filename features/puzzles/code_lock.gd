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
## Looks (polish, `lock_style`): "box" (the coloured boxes), "keypad" (an
## electronic keypad: a ▲ key per digit with the digits on a screen above,
## a green ENTER key, three lamps for the tries left, a status lamp, a NO
## POWER lamp) or "wheels" (a combination lock: a wheel per digit and a lever
## as ENTER). With `door_visual_path` (a Node3D hinge) the right code swings
## that door open by `door_open_angle`, the lock moving with it.
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
## "box", "keypad" or "wheels" (see above).
@export var lock_style := "box"
## A hinge (Node3D) swung open by the right code, with the lock (optional).
@export var door_visual_path: NodePath
@export var door_open_angle := -100.0
@export var door_open_time := 0.6

var attempts_left := 3
var lockout_left := 0.0
var dials: Array[PuzzleControl] = []
var enter: PuzzleControl
## "keypad": the lamps (try lamps, status, no power), set only when they change.
var _lamps: Array[StandardMaterial3D] = []
var _lamp_state := ""
## The door: how far open (0…1), and the lock's pose relative to the hinge when shut.
var _door_open := 0.0
var _door: Node3D
var _lock_in_hinge := Transform3D.IDENTITY
var _door_rest := Transform3D.IDENTITY
var _door_tween: Tween


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
		dial.size = Vector3(0.06, 0.1, 0.06) if lock_style == "wheels" else Vector3(0.11, 0.13, 0.06)
		dial.position = Vector3((i - (n - 1) / 2.0) * dial_spacing, 0.12, 0.0)
		if lock_style == "keypad":
			dial.style = "key"
			dial.value_offset = Vector3(0, 0.295, 0.012)   # on the screen, above the key
		elif lock_style == "wheels":
			dial.style = "wheel"
		add_child(dial)
		dials.append(dial)
	enter = PuzzleControl.new()
	enter.name = "Enter"
	enter.control_name = "ENTER"
	enter.values = PackedStringArray()
	enter.action_text = "Enter the code"
	enter.size = Vector3(n * dial_spacing * 0.8, 0.08, 0.06)
	enter.position = Vector3(0, -0.08, 0.0)
	if lock_style == "keypad":
		enter.style = "key"
	elif lock_style == "wheels":
		enter.style = "lever"
	add_child(enter)
	enter.pressed.connect(submit)
	if lock_style == "keypad":
		_build_lamps()
	_door = get_node_or_null(door_visual_path) as Node3D
	if _door:
		_door_rest = _door.transform
		_lock_in_hinge = _door_rest.affine_inverse() * transform
	super()


## "keypad": three try lamps on the left, the NO POWER and status lamps on the right.
func _build_lamps() -> void:
	var xs := [-0.29, -0.25, -0.21, 0.2, 0.29]
	for i in xs.size():
		var lamp := MeshInstance3D.new()
		lamp.name = ["Try1", "Try2", "Try3", "NoPower", "Status"][i]
		var lens := CylinderMesh.new()
		lens.top_radius = 0.011
		lens.bottom_radius = 0.012
		lens.height = 0.01
		lens.radial_segments = 10
		lamp.mesh = lens
		lamp.rotation = Vector3(PI / 2.0, 0, 0)
		lamp.position = Vector3(xs[i], -0.15, 0.008)
		var m := StandardMaterial3D.new()
		m.emission_enabled = true
		lamp.material_override = m
		add_child(lamp)
		_lamps.append(m)
	var tag := Label3D.new()
	tag.name = "NoPowerTag"
	tag.text = "NO POWER"
	tag.font_size = 12
	tag.pixel_size = 0.0016
	tag.outline_size = 0
	tag.modulate = Color(0.75, 0.76, 0.78)
	tag.position = Vector3(0.2, -0.172, 0.006)
	add_child(tag)


func _set_lamps() -> void:
	if _lamps.is_empty():
		return
	var powered := has_power()
	var state := "%s %s %d %s" % [powered, is_solved, attempts_left, lockout_left > 0.0]
	if state == _lamp_state:
		return
	_lamp_state = state
	var off := Color(0.12, 0.12, 0.13)
	for i in 3:
		_lamp(i, Color(1.0, 0.7, 0.15) if powered and not is_solved and i < attempts_left else off)
	_lamp(3, off if powered else Color(0.9, 0.12, 0.08))
	_lamp(4, off if not powered else (Color(0.25, 0.95, 0.4) if is_solved else Color(0.9, 0.12, 0.08)))
	for dial in dials:
		dial.set_value_lit(powered)


func _lamp(i: int, colour: Color) -> void:
	var m := _lamps[i]
	m.albedo_color = colour
	m.emission = colour
	m.emission_energy_multiplier = 0.0 if colour.v < 0.2 else 0.9


## The door follows `is_solved`: swung open on the right code, shut or open at once on a restore.
func _set_door(animate: bool) -> void:
	if _door == null:
		return
	var target := 1.0 if is_solved else 0.0
	if is_equal_approx(_door_open, target):
		return
	if _door_tween:
		_door_tween.kill()
	if animate and is_inside_tree():
		_door_tween = create_tween()
		_door_tween.tween_method(_pose_door, _door_open, target, door_open_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_pose_door(target)


func _pose_door(open: float) -> void:
	_door_open = open
	var hinge := Transform3D(Basis(Vector3.UP, deg_to_rad(door_open_angle * open)) * _door_rest.basis, _door_rest.origin)
	_door.transform = hinge
	transform = hinge * _lock_in_hinge


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
			system.emit_noise(global_position, NoiseEvent.Type.INTERACTION, "environment", 0.6, wrong_noise_radius, -1.0, "Keypad buzzes")
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
	_set_lamps()
	_set_door(not _restoring)
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


var _restoring := false


func restore_checkpoint_state(state: Dictionary) -> void:
	is_solved = bool(state.get("solved", false))
	attempts_left = max_attempts
	lockout_left = 0.0
	if not is_solved:
		for dial in dials:
			dial.set_index(0)
	_restoring = true
	_refresh()
	_restoring = false
