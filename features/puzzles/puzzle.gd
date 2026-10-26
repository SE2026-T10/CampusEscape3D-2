class_name Puzzle
extends Node3D

## Base of the Expanded Library's puzzles (expansion Phase 4): CodeLock,
## BreakerPanel, PumpControl. Each is a Node3D holding its PuzzleControls and a
## display (Label3D "Display") that shows its state in the world.
##
## Shared rules:
##   - `feedback(text, good)` for the HUD (ObjectiveHud shows it as a message);
##     a wrong attempt says that it was wrong, never what the answer is.
##   - `objective_id`: completed when the puzzle is solved, or as soon as that
##     objective becomes ACTIVE if the puzzle was solved earlier.
##   - Persistence: every puzzle is part of the mission state (group
##     "checkpoint_state"). What it stores is listed in each script; attempt
##     counters, lockouts and alarms are never stored, so a respawn always
##     gives fresh attempts. Being caught therefore can only undo progress made
##     since the last checkpoint; it can never leave a puzzle unsolvable.

signal feedback(text: String, good: bool)
signal solved

@export var puzzle_name := "Puzzle"
## Objective completed by solving it (optional).
@export var objective_id: StringName = &""

var is_solved := false
## Wrong attempts since the level started (for tests; not stored).
var wrong_attempts := 0

var _display: Label3D


func _ready() -> void:
	add_to_group("puzzles")
	add_to_group("checkpoint_state")
	_display = get_node_or_null("Display")
	if _display == null:
		_display = Label3D.new()
		_display.name = "Display"
		_display.font_size = 30
		_display.pixel_size = 0.003
		_display.outline_size = 8
		_display.position = Vector3(0, 0.45, 0.06)
		add_child(_display)
	_connect_manager.call_deferred()


func _connect_manager() -> void:
	var manager := ObjectiveManager.find(self)
	if manager and not manager.objective_changed.is_connected(_on_objective_changed):
		manager.objective_changed.connect(_on_objective_changed)
	_refresh()


## The text on the puzzle's display.
func get_display_text() -> String:
	return _display.text if _display else ""


func _set_display(text: String, colour := Color(0.85, 0.95, 1.0)) -> void:
	if _display:
		_display.text = text
		_display.modulate = colour


func _mark_solved() -> void:
	is_solved = true
	_complete_objective()
	solved.emit()
	_refresh()


func _complete_objective() -> void:
	var manager := ObjectiveManager.find(self)
	if is_solved and manager and objective_id != &"":
		manager.try_complete(objective_id)


func _on_objective_changed(id: StringName, state: ObjectiveManager.State) -> void:
	if id == objective_id and state == ObjectiveManager.State.ACTIVE and is_solved:
		_complete_objective.call_deferred()


## Override: update controls and display from the current state.
func _refresh() -> void:
	pass


## A wrong attempt: counts it, raises the alarm (or a smaller noise) and tells the player.
func _wrong(text: String, alarm_radius: float) -> void:
	wrong_attempts += 1
	var alarm := SecurityAlarm.find(self)
	if alarm and alarm_radius > 0.0:
		alarm.raise_alarm(global_position, "%s: %s" % [puzzle_name, text], alarm_radius)
	feedback.emit(text, false)
