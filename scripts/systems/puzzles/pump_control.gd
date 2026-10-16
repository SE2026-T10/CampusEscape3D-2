class_name PumpControl
extends Puzzle

## The pump room's controls (Expanded Library, expansion Phase 4): the
## optional pump puzzle, which opens escape 2 (the storm drain).
##   - The crank (`crank_path`, a ToolMechanism that needs the tool kit) is
##     seized: until it is freed, the valves and the start lever can't be used.
##   - Three valves (PuzzleControl SHUT / OPEN) and a START lever. Starting with
##     the valves as in `solution` drains the culvert: the storm drain grate
##     (`grate_path`, a StaticBody3D) is pulled clear and the objective
##     completes. Any other setting stalls the pump with a loud bang (guards
##     nearby hear it); the valves stay as set, so the player can adjust and
##     try again at once.
## The clue is the pump room log (which valves to open).
## Persistence: stores the valve positions and whether the culvert is drained
## (and so whether the grate is clear); the crank stores its own state.

@export var valve_names: PackedStringArray = PackedStringArray(["VALVE 1", "VALVE 2", "VALVE 3"])
## The OPEN (true) / SHUT (false) setting that works, one per valve.
@export var solution: Array[bool] = [true, false, true]
@export var crank_path: NodePath
@export var grate_path: NodePath
## Nodes hidden once the culvert is drained (e.g. the "STORM DRAIN · SEALED" sign).
@export var hide_on_solve: Array[NodePath] = []
## Noise of a stall (metres).
@export var stall_noise_radius := 16.0
@export var valve_spacing := 1.6

var valves: Array[PuzzleControl] = []
var start_lever: PuzzleControl
var stalls := 0


func _ready() -> void:
	var n := valve_names.size()
	for i in n:
		var v := PuzzleControl.new()
		v.name = "Valve%d" % (i + 1)
		v.control_name = valve_names[i]
		v.values = PackedStringArray(["SHUT", "OPEN"])
		v.size = Vector3(0.22, 0.22, 0.12)
		v.position = Vector3((i - (n - 1) / 2.0) * valve_spacing, 0.0, 0.0)
		add_child(v)
		valves.append(v)
	start_lever = PuzzleControl.new()
	start_lever.name = "Start"
	start_lever.control_name = "PUMP START"
	start_lever.values = PackedStringArray()
	start_lever.action_text = "Pull the start lever"
	start_lever.size = Vector3(0.12, 0.3, 0.1)
	start_lever.position = Vector3(-(n + 1) / 2.0 * valve_spacing, 0.0, 0.0)
	add_child(start_lever)
	start_lever.pressed.connect(start)
	super()


func _connect_manager() -> void:
	super()
	var crank := _crank()
	if crank and not crank.operated.is_connected(_refresh):
		crank.operated.connect(_refresh)


func _crank() -> ToolMechanism:
	return get_node_or_null(crank_path) as ToolMechanism


func is_crank_free() -> bool:
	var crank := _crank()
	return crank == null or crank.is_operated


func get_setting() -> Array[bool]:
	var setting: Array[bool] = []
	for v in valves:
		setting.append(v.index == 1)
	return setting


func set_setting(setting: Array) -> void:
	for i in mini(setting.size(), valves.size()):
		valves[i].set_index(1 if setting[i] else 0)


## START: checks the valves.
func start() -> void:
	if is_solved or not is_crank_free():
		return
	if get_setting() == solution:
		_mark_solved()
		feedback.emit("The pump drains the culvert. The storm drain grate is clear.", true)
		return
	stalls += 1
	_wrong("The pump stalls with a loud bang: wrong valve setting.", 0.0)
	var system := NoiseSystem.find(self)
	if system:
		system.emit_noise(global_position, NoiseEvent.Type.INTERACTION, "environment", 1.0, stall_noise_radius)


func _refresh() -> void:
	var blocked := ""
	if is_solved:
		blocked = "culvert drained"
	elif not is_crank_free():
		blocked = "the crank is seized"
	for v in valves:
		v.blocked_reason = blocked
	if start_lever:
		start_lever.blocked_reason = blocked
	var grate := get_node_or_null(grate_path) as StaticBody3D
	if grate:
		grate.visible = not is_solved
		grate.collision_layer = 0 if is_solved else 1
	for path in hide_on_solve:
		var node := get_node_or_null(path) as Node3D
		if node:
			node.visible = not is_solved
	if is_solved:
		_set_display("PUMP\nCULVERT DRAINED", Color(0.4, 1.0, 0.55))
	elif not is_crank_free():
		_set_display("PUMP\nCRANK SEIZED", Color(0.6, 0.6, 0.65))
	else:
		_set_display("PUMP\nSET VALVES · PULL START", Color(1.0, 0.85, 0.4))


func get_checkpoint_state() -> Dictionary:
	return {"valves": get_setting(), "solved": is_solved}


func restore_checkpoint_state(state: Dictionary) -> void:
	is_solved = bool(state.get("solved", false))
	if state.has("valves"):
		set_setting(state.valves)
	else:
		set_setting([false, false, false])
	_refresh()
	_refresh.call_deferred()   # after the cover / crank has restored too
