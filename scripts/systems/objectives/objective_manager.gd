class_name ObjectiveManager
extends Node

## The level's objective flow: an ordered list of objectives, each LOCKED,
## ACTIVE or COMPLETED.
##   - Exactly one objective is ACTIVE until the last one is completed.
##   - Objectives complete only in order, and only while ACTIVE.
##   - get_progress() / restore() save and load the flow for checkpoints.

signal objective_changed(id: StringName, state: State)
signal objective_completed(id: StringName)
## The last objective was completed.
signal level_completed

enum State { LOCKED, ACTIVE, COMPLETED }

const ENTER_LIBRARY := &"enter_library"
const REACH_RESTRICTED := &"reach_restricted"
const TAKE_CARD := &"take_card"
const REACH_EXIT := &"reach_exit"
const ESCAPE := &"escape"

## The MVP flow, in order: title for the HUD, hint shown under the current objective,
## and the message shown when it is completed.
const MVP_OBJECTIVES := [
	{"id": ENTER_LIBRARY, "title": "Enter the library",
		"hint": "Go through the doors into the main room.", "done": "You're inside the library"},
	{"id": REACH_RESTRICTED, "title": "Reach the Restricted Stacks",
		"hint": "North-west of the main room, through Hallway West.", "done": "Restricted Stacks reached"},
	{"id": TAKE_CARD, "title": "Take the access card",
		"hint": "It's on the archive desk at the back of the stacks.", "done": "Access card taken"},
	{"id": REACH_EXIT, "title": "Reach the exit",
		"hint": "North-east: through the back corridor or Hallway East.", "done": "Exit reached"},
	{"id": ESCAPE, "title": "Escape through the exit door",
		"hint": "Use the door with the access card.", "done": "Escaped"},
]

var _order: Array[StringName] = []
var _info := {}    # id -> {title, hint, done}
var _states := {}  # id -> State


func _ready() -> void:
	add_to_group("objective_manager")
	if _order.is_empty():
		setup(MVP_OBJECTIVES)


static func find(node: Node) -> ObjectiveManager:
	if not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group("objective_manager") as ObjectiveManager


## Replaces the flow with `objectives` (dictionaries with id, title, hint, done) and resets it.
func setup(objectives: Array) -> void:
	_order.clear()
	_info.clear()
	for entry in objectives:
		var id := StringName(entry.id)
		_order.append(id)
		_info[id] = {"title": entry.get("title", String(id)), "hint": entry.get("hint", ""), "done": entry.get("done", "")}
	reset()


## Back to the start: the first objective ACTIVE, the rest LOCKED.
func reset() -> void:
	_apply_completed_count(0)


## Completes `id` if it is the ACTIVE objective, then activates the next one.
## Returns false (and changes nothing) for any other objective.
func complete(id: StringName) -> bool:
	if get_state(id) != State.ACTIVE:
		return false
	_set_state(id, State.COMPLETED)
	objective_completed.emit(id)
	var next := _order.find(id) + 1
	if next < _order.size():
		_set_state(_order[next], State.ACTIVE)
	else:
		level_completed.emit()
	return true


func get_state(id: StringName) -> State:
	return _states.get(id, State.LOCKED)


func is_completed(id: StringName) -> bool:
	return get_state(id) == State.COMPLETED


## The ACTIVE objective, or &"" once everything is completed.
func current() -> StringName:
	for id in _order:
		if _states[id] == State.ACTIVE:
			return id
	return &""


func is_finished() -> bool:
	return not _order.is_empty() and completed_count() == _order.size()


func completed_count() -> int:
	var count := 0
	for id in _order:
		if _states[id] == State.COMPLETED:
			count += 1
	return count


func get_ids() -> Array[StringName]:
	return _order.duplicate()


func get_title(id: StringName) -> String:
	return _info.get(id, {}).get("title", "")


func get_hint(id: StringName) -> String:
	return _info.get(id, {}).get("hint", "")


func get_done_message(id: StringName) -> String:
	return _info.get(id, {}).get("done", "")


## Snapshot of the flow (state per objective), for checkpoints.
func get_progress() -> Dictionary:
	return _states.duplicate()


## Loads a snapshot from get_progress(). The leading run of COMPLETED
## objectives is kept and everything after it is rebuilt, so the flow stays
## valid even if the snapshot is not.
func restore(progress: Dictionary) -> void:
	var count := 0
	for id in _order:
		if progress.get(id, State.LOCKED) != State.COMPLETED:
			break
		count += 1
	_apply_completed_count(count)


func _apply_completed_count(count: int) -> void:
	for i in _order.size():
		var state := State.LOCKED
		if i < count:
			state = State.COMPLETED
		elif i == count:
			state = State.ACTIVE
		_set_state(_order[i], state)


func _set_state(id: StringName, state: State) -> void:
	if _states.get(id, -1) == state:
		return
	_states[id] = state
	objective_changed.emit(id, state)
