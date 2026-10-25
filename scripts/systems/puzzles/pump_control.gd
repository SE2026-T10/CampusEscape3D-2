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
##
## Polish (the pump room, `plant_style`): the valves are red handwheels, START
## is a starter's green lever (held down while the pump runs) with a RUN and a
## STALL lamp beside it, and the status shows on the starter's screen. Freeing
## the crank takes its chain and SEIZED tag off (children "Chain" and "Tag" of
## its Model) and turns its wheel ("Model/Wheel") once. When the pump starts:
## the gauge's needle (`gauge_path`) rises and the motor (`motor_path`) hums
## (shakes slightly); the storm drain's grille (`grille_path`, a visual only:
## the grate body is cleared at once) slides up into the ceiling, and the
## culvert water (`water_path`) drains away. A stall kicks the needle and jolts
## the motor. A checkpoint restore sets all of this without animating.

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
@export_group("Polish (pump room)")
@export var plant_style := false
@export var gauge_path: NodePath
@export var motor_path: NodePath
@export var grille_path: NodePath
@export var water_path: NodePath

const GRILLE_LIFT := 3.7      # metres the grille slides up (into the ceiling slot)
const GRILLE_TIME := 1.5
const WATER_DROP := 0.14      # the water layer sinks below the floor
const WATER_TIME := 6.0
const GAUGE_ZERO := 2.3       # needle angle (about the gauge's z) at 0 bar
const GAUGE_RUN := -0.5
const GAUGE_KICK := -1.7
const STALL_SHOWN := 4.0      # seconds the STALLED state shows (or until a valve turns)

var valves: Array[PuzzleControl] = []
var start_lever: PuzzleControl
var stalls := 0
## True while the STALLED state shows (polish).
var stalled := false

var _run_lamp: StandardMaterial3D
var _stall_lamp: StandardMaterial3D
var _stall_serial := 0
var _animate_solve := false
var _grille_rest := Vector3.ZERO
var _water_rest := Vector3.ZERO
var _motor_rest := Vector3.ZERO
var _plant_tween: Tween
var _gauge_tween: Tween
var _jolt := 0.0


func _ready() -> void:
	var n := valve_names.size()
	for i in n:
		var v := PuzzleControl.new()
		v.name = "Valve%d" % (i + 1)
		v.control_name = valve_names[i]
		v.values = PackedStringArray(["SHUT", "OPEN"])
		v.size = Vector3(0.22, 0.22, 0.12)
		v.position = Vector3((i - (n - 1) / 2.0) * valve_spacing, 0.0, 0.0)
		if plant_style:
			v.style = "handwheel"
			v.short_label = "V%d" % (i + 1)
		add_child(v)
		valves.append(v)
		v.changed.connect(_on_valve_changed.unbind(1))
	start_lever = PuzzleControl.new()
	start_lever.name = "Start"
	start_lever.control_name = "PUMP START"
	start_lever.values = PackedStringArray()
	start_lever.action_text = "Pull the start lever"
	start_lever.size = Vector3(0.12, 0.3, 0.1)
	start_lever.position = Vector3(-(n + 1) / 2.0 * valve_spacing, 0.0, 0.0)
	if plant_style:
		start_lever.style = "starter"
	add_child(start_lever)
	start_lever.pressed.connect(start)
	if plant_style:
		_run_lamp = _build_lamp("RunLamp", "RUN", Vector3(0.09, -0.25, -0.04))
		_stall_lamp = _build_lamp("StallLamp", "STALL", Vector3(-0.09, -0.25, -0.04))
	var grille := get_node_or_null(grille_path) as Node3D
	if grille:
		_grille_rest = grille.position
	var water := get_node_or_null(water_path) as Node3D
	if water:
		_water_rest = water.position
	var motor := get_node_or_null(motor_path) as Node3D
	if motor:
		_motor_rest = motor.position
	set_process(false)
	super()


## A lamp on the starter's housing (beside the lever) with its name below; returns its lens material.
func _build_lamp(node_name: String, text: String, offset: Vector3) -> StandardMaterial3D:
	var lamp := MeshInstance3D.new()
	lamp.name = node_name
	var lens := CylinderMesh.new()
	lens.top_radius = 0.024
	lens.bottom_radius = 0.026
	lens.height = 0.02
	lens.radial_segments = 12
	lamp.mesh = lens
	lamp.rotation = Vector3(PI / 2.0, 0, 0)
	lamp.position = start_lever.position + offset
	var material := StandardMaterial3D.new()
	material.emission_enabled = true
	lamp.material_override = material
	add_child(lamp)
	var label := Label3D.new()
	label.name = node_name + "Text"
	label.text = text
	label.font_size = 14
	label.pixel_size = 0.0018
	label.outline_size = 0
	label.modulate = Color(0.9, 0.9, 0.88)
	label.position = start_lever.position + offset + Vector3(0, -0.045, 0.012)
	add_child(label)
	return material


func _connect_manager() -> void:
	super()
	var crank := _crank()
	if crank and not crank.operated.is_connected(_refresh):
		crank.operated.connect(_refresh)
		crank.operated.connect(_spin_crank)


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
		_animate_solve = true
		stalled = false
		_mark_solved()
		_animate_solve = false
		feedback.emit("The pump drains the culvert. The storm drain grate is clear.", true)
		return
	stalls += 1
	if plant_style:
		stalled = true
		_stall_serial += 1
		var serial := _stall_serial
		get_tree().create_timer(STALL_SHOWN).timeout.connect(func():
			if serial == _stall_serial and stalled:
				stalled = false
				_refresh())
		_stall_gauge()
		_jolt = 0.35
		set_process(true)
		_refresh()
	_wrong("The pump stalls with a loud bang: wrong valve setting.", 0.0)
	var system := NoiseSystem.find(self)
	if system:
		system.emit_noise(global_position, NoiseEvent.Type.INTERACTION, "environment", 1.0, stall_noise_radius, -1.0, "Pump stalls with a bang")


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
		_set_display("PUMP RUNNING\nCULVERT DRAINED", Color(0.4, 1.0, 0.55))
	elif not is_crank_free():
		_set_display("PUMP OFF\nCRANK SEIZED", Color(0.6, 0.6, 0.65))
	elif stalled:
		_set_display("PUMP STALLED\nCHECK VALVES", Color(1.0, 0.35, 0.25))
	else:
		_set_display("PUMP READY\nSET VALVES · START", Color(1.0, 0.85, 0.4))
	if plant_style:
		_apply_plant(_animate_solve)


# --- Polish (pump room) -----------------------------------------------------------------------

func _on_valve_changed() -> void:
	if stalled:
		stalled = false
		_refresh()


## The lamps, the starter lever, the crank's chain, the gauge, the grille and the water.
func _apply_plant(animate: bool) -> void:
	_lamp(_run_lamp, Color(0.2, 0.9, 0.35), is_solved)
	_lamp(_stall_lamp, Color(0.95, 0.15, 0.08), stalled and not is_solved)
	if start_lever:
		start_lever.set_lever(is_solved, false)
	var crank := _crank()
	if crank:
		for part in ["Model/Chain", "Model/Tag"]:
			var node := crank.get_node_or_null(part) as Node3D
			if node:
				node.visible = not crank.is_operated
	var grille := get_node_or_null(grille_path) as Node3D
	var water := get_node_or_null(water_path) as Node3D
	if animate:
		if _plant_tween:
			_plant_tween.kill()
		_plant_tween = create_tween().set_parallel(true)
		if grille:
			_plant_tween.tween_property(grille, "position:y", _grille_rest.y + GRILLE_LIFT, GRILLE_TIME) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.4)
			_plant_tween.tween_callback(grille.hide).set_delay(0.4 + GRILLE_TIME)
		if water:
			_plant_tween.tween_property(water, "position:y", _water_rest.y - WATER_DROP, WATER_TIME) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_plant_tween.tween_callback(water.hide).set_delay(WATER_TIME)
		_set_gauge(GAUGE_RUN, 1.5)
		set_process(true)
		return
	if _plant_tween and _plant_tween.is_running():
		if is_solved:
			return   # the start animation finishes by itself
		_plant_tween.kill()
	if grille:
		grille.position = _grille_rest + (Vector3(0, GRILLE_LIFT, 0) if is_solved else Vector3.ZERO)
		grille.visible = not is_solved
	if water:
		water.position = _water_rest - (Vector3(0, WATER_DROP, 0) if is_solved else Vector3.ZERO)
		water.visible = not is_solved
	if not stalled:
		_set_gauge(GAUGE_RUN if is_solved else GAUGE_ZERO, 0.0)
	var motor := get_node_or_null(motor_path) as Node3D
	if motor and not is_solved and _jolt <= 0.0:
		motor.position = _motor_rest
	set_process(is_solved or _jolt > 0.0)


func _lamp(material: StandardMaterial3D, colour: Color, lit: bool) -> void:
	if material == null:
		return
	var shown := colour if lit else colour.darkened(0.75)
	material.albedo_color = shown
	material.emission = shown
	material.emission_energy_multiplier = 0.9 if lit else 0.0


func _set_gauge(angle: float, time: float) -> void:
	var needle := get_node_or_null(gauge_path) as Node3D
	if needle == null:
		return
	if _gauge_tween:
		_gauge_tween.kill()
	if time <= 0.0 or not is_inside_tree():
		needle.rotation.z = angle
		return
	_gauge_tween = create_tween()
	_gauge_tween.tween_property(needle, "rotation:z", angle, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## A stall: the needle kicks up and falls back to zero.
func _stall_gauge() -> void:
	var needle := get_node_or_null(gauge_path) as Node3D
	if needle == null:
		return
	if _gauge_tween:
		_gauge_tween.kill()
	_gauge_tween = create_tween()
	_gauge_tween.tween_property(needle, "rotation:z", GAUGE_KICK, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_gauge_tween.tween_property(needle, "rotation:z", GAUGE_ZERO, 1.0).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## The freed crank's wheel turns once.
func _spin_crank() -> void:
	var crank := _crank()
	var wheel := crank.get_node_or_null("Model/Wheel") as Node3D if crank else null
	if wheel == null or not is_inside_tree():
		return
	var t := create_tween()
	t.tween_property(wheel, "rotation:z", wheel.rotation.z - TAU, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The motor's hum while it runs (a slight shake), a jolt after a stall.
func _process(delta: float) -> void:
	var motor := get_node_or_null(motor_path) as Node3D
	_jolt = maxf(_jolt - delta, 0.0)
	var amplitude := 0.006 * (_jolt / 0.35) if _jolt > 0.0 else (0.0012 if is_solved else 0.0)
	if motor:
		motor.position = _motor_rest + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amplitude
	if is_solved and not (_gauge_tween and _gauge_tween.is_running()):
		var needle := get_node_or_null(gauge_path) as Node3D
		if needle:
			needle.rotation.z = GAUGE_RUN + sin(Time.get_ticks_msec() * 0.011) * 0.03
	if amplitude == 0.0:
		if motor:
			motor.position = _motor_rest
		set_process(false)


func get_checkpoint_state() -> Dictionary:
	return {"valves": get_setting(), "solved": is_solved}


func restore_checkpoint_state(state: Dictionary) -> void:
	is_solved = bool(state.get("solved", false))
	stalled = false
	_jolt = 0.0
	if state.has("valves"):
		set_setting(state.valves)
	else:
		set_setting([false, false, false])
	_refresh()
	_refresh.call_deferred()   # after the cover / crank has restored too
