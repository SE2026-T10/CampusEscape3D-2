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

@export var exit_path: NodePath
@export var release_path: NodePath
@export var power_circuit: StringName = &"service_exit"
@export var noise_radius := 14.0

var button: PuzzleControl
## Presses refused (for tests).
var refusals := 0


func _ready() -> void:
	button = PuzzleControl.new()
	button.name = "OpenButton"
	button.control_name = "SHUTTER"
	button.values = PackedStringArray()
	button.action_text = "Open the loading dock shutter"
	button.short_label = "OPEN"
	add_child(button)
	button.pressed.connect(_on_pressed)
	super()


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


func _process(_delta: float) -> void:
	_refresh()


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
	_refresh.call_deferred()
