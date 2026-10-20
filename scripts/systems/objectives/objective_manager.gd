class_name ObjectiveManager
extends Node

## The level's objective flow: an ordered list of objectives, each LOCKED,
## ACTIVE or COMPLETED. Two modes, chosen by the objectives' fields:
##
## Linear (the default; the tutorial and every level whose objectives have no
## "requires" or "optional" field):
##   - Exactly one objective is ACTIVE until the last one is completed.
##   - Objectives complete only in order, and only while ACTIVE.
##
## Graph (when any objective has "requires" or "optional"; the Expanded Library):
##   - "requires": ids that must be COMPLETED first. An objective is ACTIVE as
##     soon as all of them are, so several can be ACTIVE at once and be done in
##     any order; it completes only while ACTIVE.
##   - "optional": true for side objectives. They never block the mission:
##     the level is finished (level_completed) when every mandatory objective
##     is COMPLETED. A mandatory objective must not require an optional one
##     (tests check the Expanded Library's graph for this).
##   - "hidden": an optional objective stays out of the HUD until discover()
##     (e.g. reading a document) or until it is completed. Discovery is
##     knowledge: a checkpoint restore keeps it.
##   - current() is the first ACTIVE mandatory objective in list order.
##
## get_progress() / restore() save and load the flow for checkpoints.

signal objective_changed(id: StringName, state: State)
signal objective_completed(id: StringName)
## The last objective was completed.
signal level_completed
## A hidden optional objective was discovered (graph mode).
signal objective_discovered(id: StringName)

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

## This level's objectives, in order: dictionaries with id, title, hint and
## done (see MVP_OBJECTIVES). Empty (the default) means the MVP flow, so the
## tutorial needs no setting; the Expanded Library sets its own five.
@export var objectives: Array[Dictionary] = []

var _order: Array[StringName] = []
var _info := {}    # id -> {title, hint, done}
var _states := {}  # id -> State
var _graph := false
var _requires := {}    # id -> Array[StringName] (graph mode)
var _optional := {}    # id -> true (graph mode)
var _hidden := {}      # id -> true: hidden until discovered (graph mode)
var _discovered := {}  # id -> true


func _ready() -> void:
	add_to_group("objective_manager")
	if _order.is_empty():
		setup(objectives if not objectives.is_empty() else MVP_OBJECTIVES)


static func find(node: Node) -> ObjectiveManager:
	if not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group("objective_manager") as ObjectiveManager


## Replaces the flow with `objectives` (dictionaries with id, title, hint, done) and resets it.
func setup(objectives: Array) -> void:
	_order.clear()
	_info.clear()
	_requires.clear()
	_optional.clear()
	_hidden.clear()
	_discovered.clear()
	_states.clear()
	_graph = false
	for entry in objectives:
		var id := StringName(entry.id)
		_order.append(id)
		_info[id] = {"title": entry.get("title", String(id)), "hint": entry.get("hint", ""), "done": entry.get("done", "")}
		var needs: Array[StringName] = []
		for r in entry.get("requires", []):
			needs.append(StringName(r))
		_requires[id] = needs
		if entry.get("optional", false):
			_optional[id] = true
		if entry.get("hidden", false):
			_hidden[id] = true
		if entry.has("requires") or entry.has("optional"):
			_graph = true
	reset()


## Back to the start: linear, the first objective ACTIVE and the rest LOCKED;
## graph, every objective without prerequisites ACTIVE.
func reset() -> void:
	escape_route = &""
	escape_route_name = ""
	if _graph:
		_apply_graph({})
	else:
		_apply_completed_count(0)


## Completes `id` if it is the ACTIVE objective, then activates the next one.
## Returns false (and changes nothing) for any other objective.
func complete(id: StringName) -> bool:
	if get_state(id) != State.ACTIVE:
		return false
	_set_state(id, State.COMPLETED)
	objective_completed.emit(id)
	if _graph:
		if _hidden.has(id):
			discover(id)
		var finished := is_finished()
		_apply_graph(_completed_set())
		if finished and not _optional.has(id):
			level_completed.emit()
		return true
	var next := _order.find(id) + 1
	if next < _order.size():
		_set_state(_order[next], State.ACTIVE)
	else:
		level_completed.emit()
	return true


## Expansion Phase 6: the escape route used (set by the exit just before it
## completes the escape objective); empty until the player escapes. Reset by
## reset() and restore() (an escape ends the level, so it is never restored).
var escape_route: StringName = &""
var escape_route_name := ""


func record_escape_route(id: StringName, route_name: String) -> void:
	escape_route = id
	escape_route_name = route_name


func get_state(id: StringName) -> State:
	return _states.get(id, State.LOCKED)


func is_completed(id: StringName) -> bool:
	return get_state(id) == State.COMPLETED


## The ACTIVE objective (graph mode: the first ACTIVE mandatory one), or &""
## once everything (every mandatory objective) is completed.
func current() -> StringName:
	for id in _order:
		if _states[id] == State.ACTIVE and not _optional.has(id):
			return id
	return &""


func is_finished() -> bool:
	if _graph:
		return not _order.is_empty() and get_mandatory_ids().all(func(id): return _states[id] == State.COMPLETED)
	return not _order.is_empty() and completed_count() == _order.size()


## True in graph mode (prerequisites / optional objectives).
func is_graph() -> bool:
	return _graph


func is_optional(id: StringName) -> bool:
	return _optional.has(id)


## The objectives `id` needs completed first (graph mode; empty in linear mode).
func get_requires(id: StringName) -> Array[StringName]:
	var needs: Array[StringName] = []
	needs.assign(_requires.get(id, []))
	return needs


func get_mandatory_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_order.filter(func(id): return not _optional.has(id)))
	return ids


func get_optional_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_order.filter(func(id): return _optional.has(id)))
	return ids


## False only for a hidden optional objective not yet discovered or completed.
func is_visible(id: StringName) -> bool:
	return not _hidden.has(id) or _discovered.has(id) or get_state(id) == State.COMPLETED


func is_discovered(id: StringName) -> bool:
	return _discovered.has(id)


## Reveals a hidden optional objective. Returns true the first time.
func discover(id: StringName) -> bool:
	if not _order.has(id) or _discovered.has(id):
		return false
	_discovered[id] = true
	objective_discovered.emit(id)
	return true


## Completes `id` if it is ACTIVE; does nothing otherwise. For puzzles and
## pickups that may be solved before their objective comes up: they call this
## when solved and again whenever their objective becomes ACTIVE.
func try_complete(id: StringName) -> bool:
	return id != &"" and get_state(id) == State.ACTIVE and complete(id)


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
	escape_route = &""
	escape_route_name = ""
	if _graph:
		# Keep the snapshot's COMPLETED objectives whose prerequisites are kept too.
		var kept := {}
		var changed := true
		while changed:
			changed = false
			for id in _order:
				if kept.has(id) or progress.get(id, State.LOCKED) != State.COMPLETED:
					continue
				if _requires[id].all(func(r): return kept.has(r)):
					kept[id] = true
					changed = true
		_apply_graph(kept)
		return
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


func _completed_set() -> Dictionary:
	var done := {}
	for id in _order:
		if _states.get(id, State.LOCKED) == State.COMPLETED:
			done[id] = true
	return done


func _apply_graph(completed: Dictionary) -> void:
	for id in _order:
		var state := State.LOCKED
		if completed.has(id):
			state = State.COMPLETED
		elif _requires[id].all(func(r): return completed.has(r)):
			state = State.ACTIVE
		_set_state(id, state)


func _set_state(id: StringName, state: State) -> void:
	if _states.get(id, -1) == state:
		return
	_states[id] = state
	objective_changed.emit(id, state)
