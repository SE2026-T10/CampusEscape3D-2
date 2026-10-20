class_name BreakerPanel
extends Puzzle

## The electrical room's breaker panel (Expanded Library, expansion Phase 4):
## the power puzzle.
##   - Behind a cover (`cover_path`, a ToolMechanism that needs the tool kit):
##     until the cover is off, the breakers and the main switch can't be used.
##   - Four breakers (PuzzleControl OFF / ON), labelled with their circuits,
##     and a MAIN switch. Engaging MAIN with the breakers as in `solution`
##     powers `circuit` in the PowerNetwork and completes the objective.
##   - Any other setting trips the main: a bang and a short alarm (guards
##     nearby investigate), the breakers drop back to OFF; try again at once.
## The clue is the wiring chart in Book Processing (which circuits the vault
## lock needs) plus the circuit labels on the breakers themselves.
## Persistence: stores the breaker positions and whether the power is on (the
## cover and the PowerNetwork store their own state, from the same snapshot).

@export var breaker_names: PackedStringArray = PackedStringArray(["A1 ARCHIVE LIGHTS", "A2 SUMP PUMP", "A3 VAULT LOCK", "A4 SECURITY GRID"])
## The ON / OFF setting that works, one per breaker.
@export var solution: Array[bool] = [true, false, true, true]
@export var circuit: StringName = &"archive_access"
## ToolMechanism covering the panel (optional).
@export var cover_path: NodePath
## Alarm radius when the main trips (metres).
@export var trip_alarm_radius := 14.0
@export var breaker_spacing := 0.22

var breakers: Array[PuzzleControl] = []
var main_switch: PuzzleControl
## Times the main has tripped (for tests; not stored).
var trips := 0


func _ready() -> void:
	var n := breaker_names.size()
	for i in n:
		var b := PuzzleControl.new()
		b.name = "Breaker%d" % (i + 1)
		b.control_name = breaker_names[i]
		b.short_label = breaker_names[i].get_slice(" ", 0)
		b.values = PackedStringArray(["OFF", "ON"])
		b.size = Vector3(0.1, 0.18, 0.07)
		b.position = Vector3((i - (n - 1) / 2.0) * breaker_spacing, 0.05, 0.0)
		add_child(b)
		breakers.append(b)
	main_switch = PuzzleControl.new()
	main_switch.name = "Main"
	main_switch.control_name = "MAIN SWITCH"
	main_switch.values = PackedStringArray()
	main_switch.action_text = "Engage the main switch"
	main_switch.size = Vector3(0.5, 0.1, 0.08)
	main_switch.position = Vector3(0, -0.22, 0.0)
	add_child(main_switch)
	main_switch.pressed.connect(engage)
	super()


func _connect_manager() -> void:
	super()
	var cover := _cover()
	if cover and not cover.operated.is_connected(_refresh):
		cover.operated.connect(_refresh)


func _cover() -> ToolMechanism:
	return get_node_or_null(cover_path) as ToolMechanism


func is_cover_open() -> bool:
	var cover := _cover()
	return cover == null or cover.is_operated


## Breaker settings as ON (true) / OFF (false).
func get_setting() -> Array[bool]:
	var setting: Array[bool] = []
	for b in breakers:
		setting.append(b.index == 1)
	return setting


## Sets the breakers (tests and tools; players flip them with E).
func set_setting(setting: Array) -> void:
	for i in mini(setting.size(), breakers.size()):
		breakers[i].set_index(1 if setting[i] else 0)


## MAIN: checks the breakers.
func engage() -> void:
	if is_solved or not is_cover_open():
		return
	if get_setting() == solution:
		var network := PowerNetwork.find(self)
		if network:
			network.set_powered(circuit, true)
		_mark_solved()
		feedback.emit("Power restored: the archive vault has power.", true)
		return
	trips += 1
	for b in breakers:
		b.set_index(0)
	_wrong("The main breaker tripped: that circuit setting is wrong. The breakers dropped back to OFF.", trip_alarm_radius)
	_refresh()


func _refresh() -> void:
	var blocked := ""
	if is_solved:
		blocked = "power on"
	elif not is_cover_open():
		blocked = "behind the panel cover"
	for b in breakers:
		b.blocked_reason = blocked
	if main_switch:
		main_switch.blocked_reason = blocked
	if is_solved:
		_set_display("BREAKER PANEL\nPOWER ON", Color(0.4, 1.0, 0.55))
	elif not is_cover_open():
		_set_display("BREAKER PANEL\nCOVER SCREWED SHUT", Color(0.6, 0.6, 0.65))
	else:
		_set_display("BREAKER PANEL\nSET BREAKERS · ENGAGE MAIN", Color(1.0, 0.85, 0.4))


func get_checkpoint_state() -> Dictionary:
	return {"breakers": get_setting(), "solved": is_solved}


func restore_checkpoint_state(state: Dictionary) -> void:
	is_solved = bool(state.get("solved", false))
	set_setting(state.get("breakers", []))
	if not state.has("breakers"):
		for b in breakers:
			b.set_index(0)
	_refresh()
	_refresh.call_deferred()   # after the cover / crank has restored too
