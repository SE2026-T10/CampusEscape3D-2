class_name DockShutter
extends Puzzle

## The loading dock shutter's control box (Expanded Library, expansion Phase 6,
## escape route B). Pressing OPEN unlocks the dock exit (`exit_path`, the
## level's loading dock ExitDoor) once:
##   - its circuit has power (SERVICE EXIT, from the electrical room), and
##   - the jammed shutter release beside the door (`release_path`, a
##     ToolMechanism) has been freed with the tool kit.
## Otherwise it says which one is missing. Opening rattles the shutter up (a
## noise guards hear). The exit stores whether it is unlocked (checkpoints);
## this box only shows it.
##
## Polish (the loading dock): OPEN is a green push button on a yellow station
## with a POWER lamp, the status on its screen. The roller shutter's curtain
## (`curtain_path`: its "Slat*" children and bottom bar) rolls up into the coil
## box while the exit is open (and down again if it closes, e.g. power off);
## each slat is hidden once it is above the opening. The release's model has a
## "Bolt" and a "Tag" (gone once freed) and a "Handle" that drops when freed.
## A checkpoint restore (and the level start) sets them at once.

@export var exit_path: NodePath
@export var release_path: NodePath
@export var power_circuit: StringName = &"service_exit"
@export var noise_radius := 14.0
@export_group("Polish (loading dock)")
@export var curtain_path: NodePath
## How far the curtain rolls up (metres) and how long it takes.
@export var curtain_lift := 2.6
@export var curtain_time := 2.5
## Curtain-local height above which a slat is inside the coil box (hidden).
@export var opening_top := 2.62

const HANDLE_DROP := 0.2

var button: PuzzleControl
## Presses refused (for tests).
var refusals := 0
## Polish: how far the shutter is rolled up (0 down … 1 up).
var curtain_open := 0.0

var _snap := true
var _curtain_rest := Vector3.ZERO
var _slats: Array[Node3D] = []
var _power_lamp: StandardMaterial3D
var _lamp_on := false
var _release_freed := false
var _handle_rest := Vector3.ZERO
var _connected_release := false


func _ready() -> void:
	button = PuzzleControl.new()
	button.name = "OpenButton"
	button.control_name = "SHUTTER"
	button.values = PackedStringArray()
	button.action_text = "Open the loading dock shutter"
	button.short_label = "OPEN"
	if curtain_path != NodePath():
		button.style = "push"
	add_child(button)
	button.pressed.connect(_on_pressed)
	var curtain := get_node_or_null(curtain_path) as Node3D
	if curtain:
		_curtain_rest = curtain.position
		for child in curtain.get_children():
			if child is Node3D:
				_slats.append(child)
		_power_lamp = _build_lamp()
	super()


## The POWER lamp on the station, above the button (lens material).
func _build_lamp() -> StandardMaterial3D:
	var lamp := MeshInstance3D.new()
	lamp.name = "PowerLamp"
	var lens := CylinderMesh.new()
	lens.top_radius = 0.018
	lens.bottom_radius = 0.02
	lens.height = 0.02
	lens.radial_segments = 12
	lamp.mesh = lens
	lamp.rotation = Vector3(PI / 2.0, 0, 0)
	lamp.position = Vector3(-0.08, 0.1, 0.05)
	var material := StandardMaterial3D.new()
	material.emission_enabled = true
	lamp.material_override = material
	add_child(lamp)
	var label := Label3D.new()
	label.name = "PowerLampText"
	label.text = "POWER"
	label.font_size = 14
	label.pixel_size = 0.0016
	label.outline_size = 0
	label.modulate = Color(0.08, 0.08, 0.08)
	label.position = Vector3(-0.08, 0.065, 0.042)
	add_child(label)
	return material


func get_exit() -> ExitDoor:
	return get_node_or_null(exit_path) as ExitDoor


func get_release() -> ToolMechanism:
	return get_node_or_null(release_path) as ToolMechanism


func has_power() -> bool:
	var network := PowerNetwork.find(self)
	return power_circuit == &"" or (network != null and network.is_powered(power_circuit))


func _on_pressed() -> void:
	var exit := get_exit()
	if exit == null:
		return
	if exit.unlocked:
		feedback.emit("The shutter is already open.", true)
		return
	if not has_power():
		refusals += 1
		feedback.emit("Dock shutter: no power. SERVICE EXIT is off (electrical room).", false)
		return
	var release := get_release()
	if release and not release.is_operated:
		refusals += 1
		feedback.emit("Dock shutter: the release beside the door is jammed. Free it with the tool kit.", false)
		return
	exit.unlock()
	var system := NoiseSystem.find(self)
	if system:
		system.emit_noise(global_position, NoiseEvent.Type.INTERACTION, "environment", 0.8, noise_radius, -1.0, "Shutter rattles up")
	_mark_solved()
	feedback.emit("Shutter open: the loading dock is clear.", true)


func _process(delta: float) -> void:
	_refresh()
	_animate(delta)


## Polish: the curtain toward open / shut, the release's handle, bolt and tag, the POWER lamp.
func _animate(delta: float) -> void:
	var exit := get_exit()
	var curtain := get_node_or_null(curtain_path) as Node3D
	if curtain and exit:
		var target := 1.0 if exit.is_open() else 0.0
		var before := curtain_open
		curtain_open = target if _snap else move_toward(curtain_open, target, delta / maxf(curtain_time, 0.01))
		if curtain_open != before or _snap:
			var lift := curtain_open * curtain_lift
			curtain.position = _curtain_rest + Vector3(0, lift, 0)
			for slat in _slats:
				slat.visible = slat.position.y + lift < opening_top
	var release := get_release()
	if release:
		if not _connected_release:
			_connected_release = true
			var handle := release.get_node_or_null("Model/Handle") as Node3D
			if handle:
				_handle_rest = handle.position
		if release.is_operated != _release_freed or _snap:
			_release_freed = release.is_operated
			for part in ["Model/Bolt", "Model/Tag"]:
				var node := release.get_node_or_null(part) as Node3D
				if node:
					node.visible = not _release_freed
			var handle := release.get_node_or_null("Model/Handle") as Node3D
			if handle:
				var to := _handle_rest - Vector3(0, HANDLE_DROP if _release_freed else 0.0, 0)
				if _snap or not is_inside_tree():
					handle.position = to
				else:
					var t := create_tween()
					t.tween_property(handle, "position", to, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var on := has_power()
	if _power_lamp and (on != _lamp_on or _snap):
		_lamp_on = on
		var colour := Color(0.2, 0.9, 0.35) if on else Color(0.2, 0.9, 0.35).darkened(0.75)
		_power_lamp.albedo_color = colour
		_power_lamp.emission = colour
		_power_lamp.emission_energy_multiplier = 0.9 if on else 0.0
	_snap = false


func _refresh() -> void:
	var exit := get_exit()
	is_solved = exit != null and exit.unlocked
	if is_solved:
		_set_display("SHUTTER · OPEN", Color(0.3, 0.9, 0.45))
	elif not has_power():
		_set_display("SHUTTER · NO POWER", Color(0.85, 0.3, 0.25))
	elif get_release() and not get_release().is_operated:
		_set_display("SHUTTER · RELEASE JAMMED", Color(1.0, 0.75, 0.25))
	else:
		_set_display("SHUTTER · READY", Color(0.85, 0.95, 1.0))


## Nothing of its own to store: the exit stores whether it is unlocked.
func get_checkpoint_state() -> Dictionary:
	return {}


func restore_checkpoint_state(_state: Dictionary) -> void:
	_snap = true   # the curtain, the release and the lamp, at once
	_refresh.call_deferred()
