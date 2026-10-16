class_name EscapeRoutes
extends Node

## What the player knows about the Expanded Library's three ways out
## (expansion Phase 7), for the HUD's WAYS OUT list and the exits' messages.
##
## It keeps no state of its own:
##   - whether a requirement is met is read from the game itself every time
##     (the manuscript objective, the carried badge, the exits' `unlocked`, the
##     PowerNetwork, the hidden panel, the drained culvert);
##   - what the player knows is the journal (PlayerInventory documents): the
##     culvert access plan, plus short clues this node adds when the player
##     meets something (the lockdown on entering, the locker opening, the
##     dock's control, the shutter release, the electrical switches). Like
##     every journal entry these survive a capture, so knowledge is never lost.
## Undiscovered things stay off the list: the hidden passage appears only once
## its plan is read, and a requirement only once it has been met in the world.
## Exits ask refusal_for() so their messages name only known requirements.

## Journal clue ids (kind "clue").
const CLUE_MAIN := &"route_main_entrance"
const CLUE_BADGE := &"route_badge_location"
const CLUE_DOCK := &"route_loading_dock"
const CLUE_DOCK_POWER := &"route_dock_power"
const CLUE_DOCK_CONTROL := &"route_dock_control"
const CLUE_DOCK_RELEASE := &"route_dock_release"
const CLUE_POWER_BOARD := &"power_switch_board"
## The document that reveals the hidden passage.
const PASSAGE_DOCUMENT := &"culvert_access_plan"

const CLUES := {
	CLUE_MAIN: ["Main entrance", "Locked down at night. Security can override it at the lobby badge reader with the master badge; the override takes a few seconds."],
	CLUE_BADGE: ["Master badge", "Kept in the Office 1 security locker."],
	CLUE_DOCK: ["Loading dock", "Its shutter needs power."],
	CLUE_DOCK_POWER: ["Dock power", "The shutter runs on the SERVICE EXIT circuit (electrical room)."],
	CLUE_DOCK_CONTROL: ["Dock shutter control", "The control box beside the dock door opens the shutter."],
	CLUE_DOCK_RELEASE: ["Shutter release", "The shutter release beside the dock door is jammed: it needs the tool kit."],
	CLUE_POWER_BOARD: ["Electrical room", "Switches for SURVEILLANCE and SERVICE EXIT; the ARCHIVE breakers are behind the panel cover."],
}

@export var main_exit_path: NodePath
@export var dock_exit_path: NodePath
@export var drain_exit_path: NodePath
@export var shutter_path: NodePath
@export var release_path: NodePath
@export var panel_path: NodePath
@export var locker_path: NodePath


func _ready() -> void:
	add_to_group("escape_routes")
	_connect.call_deferred()


static func find(node: Node) -> EscapeRoutes:
	if not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group("escape_routes") as EscapeRoutes


func _connect() -> void:
	var objectives := ObjectiveManager.find(self)
	if objectives:
		objectives.objective_completed.connect(_on_objective_completed)
		if objectives.is_completed(&"enter_library"):
			_on_objective_completed(&"enter_library")
	var locker := get_node_or_null(locker_path)
	if locker and locker.has_signal("solved"):
		locker.solved.connect(func(): learn(CLUE_BADGE))
	var shutter := get_node_or_null(shutter_path)
	if shutter:
		shutter.feedback.connect(_on_shutter_feedback)
	var release := get_node_or_null(release_path)
	if release:
		release.operated.connect(func(): learn(CLUE_DOCK_RELEASE))
		release.rejected.connect(func(_r): learn(CLUE_DOCK_RELEASE))
	var dock := get_node_or_null(dock_exit_path)
	if dock:
		dock.rejected.connect(func(_r): learn(CLUE_DOCK_CONTROL))
	for node in get_tree().get_nodes_in_group("circuit_switches"):
		node.feedback.connect(func(_t, _g):
			learn(CLUE_POWER_BOARD)
			if node.circuit == &"service_exit":
				learn(CLUE_DOCK_POWER))
	for node in get_tree().get_nodes_in_group("puzzles"):
		if node is BreakerPanel:
			node.feedback.connect(func(_t, _g): learn(CLUE_POWER_BOARD))


func _on_objective_completed(id: StringName) -> void:
	if id == &"enter_library":
		learn(CLUE_MAIN)
		learn(CLUE_DOCK)


func _on_shutter_feedback(text: String, _good: bool) -> void:
	learn(CLUE_DOCK_CONTROL)
	if text.contains("no power"):
		learn(CLUE_DOCK_POWER)
	if text.contains("jammed"):
		learn(CLUE_DOCK_RELEASE)


## Adds a clue to the journal once. Returns true if it is new.
func learn(id: StringName) -> bool:
	var inventory := PlayerInventory.find(self)
	if inventory == null or not CLUES.has(id):
		return false
	return inventory.add_document(id, CLUES[id][0], CLUES[id][1], "clue")


func knows(id: StringName) -> bool:
	var inventory := PlayerInventory.find(self)
	return inventory != null and inventory.has_document(id)


## The routes the player knows, in order, each {id, name, open, requirements:
## [{text, met}]} with only the requirements the player knows.
func get_known_routes() -> Array[Dictionary]:
	var routes: Array[Dictionary] = []
	var objectives := ObjectiveManager.find(self)
	var manuscript := {"text": "manuscript", "met": objectives != null and objectives.is_completed(&"take_manuscript")}
	var main := get_node_or_null(main_exit_path) as ExitDoor
	if main and knows(CLUE_MAIN):
		var inventory := PlayerInventory.find(self)
		var badge_text := "master badge" + (" (Office 1 locker)" if knows(CLUE_BADGE) else "")
		routes.append({"id": &"main_entrance", "name": "Main entrance", "exit": main, "requirements": [manuscript,
			{"text": badge_text, "met": inventory != null and inventory.has(ItemCatalog.SECURITY_BADGE)},
			{"text": "override at the lobby reader", "met": main.unlocked}]})
	var dock := get_node_or_null(dock_exit_path) as ExitDoor
	if dock and knows(CLUE_DOCK):
		var network := PowerNetwork.find(self)
		var reqs: Array = [manuscript,
			{"text": "SERVICE EXIT power" if knows(CLUE_DOCK_POWER) else "shutter power", "met": network != null and network.is_powered(&"service_exit")}]
		var release := get_node_or_null(release_path) as ToolMechanism
		if knows(CLUE_DOCK_RELEASE):
			reqs.append({"text": "free the release (tool kit)", "met": release != null and release.is_operated})
		if knows(CLUE_DOCK_CONTROL):
			reqs.append({"text": "OPEN on the shutter control", "met": dock.unlocked})
		routes.append({"id": &"loading_dock", "name": "Loading dock", "exit": dock, "requirements": reqs})
	var drain := get_node_or_null(drain_exit_path) as ExitDoor
	if drain and knows(PASSAGE_DOCUMENT):
		var panel := get_node_or_null(panel_path) as AccessDoor
		routes.append({"id": &"maintenance_passage", "name": "Hidden maintenance passage", "exit": drain, "requirements": [manuscript,
			{"text": "open the false panel (tunnel)", "met": panel != null and panel.is_open},
			{"text": "drain the culvert (pump room)", "met": objectives != null and objectives.is_completed(&"drain_culvert")}]})
	for r in routes:
		r.open = r.requirements.all(func(q): return q.met)
	return routes


## What `exit` should say when it refuses: the first known requirement still
## missing, or a hint that something else is needed (never naming it).
func refusal_for(exit: ExitDoor) -> String:
	for r in get_known_routes():
		if r.exit != exit:
			continue
		for q in r.requirements:
			if not q.met:
				return "%s: %s needed." % [r.name, q.text] if q.text != "manuscript" else "You can't leave without the rare manuscript."
	if exit.route_name != "":
		return "The %s won't open yet. Look around it for a way." % exit.route_name.to_lower()
	return "This way out won't open yet."


## The electrical circuits, once the player has seen the switch board: [[name, on], ...].
func get_known_power() -> Array:
	if not knows(CLUE_POWER_BOARD):
		return []
	var network := PowerNetwork.find(self)
	if network == null:
		return []
	return [["Archive", network.is_powered(&"archive_access")], ["Cameras", network.is_powered(&"surveillance")],
		["Service exit", network.is_powered(&"service_exit")]]
