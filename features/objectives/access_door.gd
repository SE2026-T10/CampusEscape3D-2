class_name AccessDoor
extends Interactable

## A closed door the player opens with the interact key (E), once allowed:
##   - KEY: needs `key_objective_id` COMPLETED (e.g. the staff access card),
##     or, if `key_item` is set, the player to be carrying that item
##     (PlayerInventory; the Expanded Library's staff card). The item is only
##     checked, never used up.
##   - ONE_WAY: opens only from the side `open_from` points to (a shortcut
##     that is unlocked from inside, then stays open both ways).
## Opening completes `complete_objective_id` if one is set: at once if that
## objective is ACTIVE, or as soon as it becomes ACTIVE if the door was opened
## earlier (so the player may unlock it before the objective comes up).
##
## The door blocks the player with its "Panel" child (a StaticBody3D on the
## world layer, 1). The panel is not under the NavigationRegion3D, so it is not
## baked into the navmesh: guards keep their routes through the doorway, and
## each guard gets a collision exception with the panel (staff have keys).
## While closed, the panel also blocks sight and muffles noise like a wall
## (both use the world layer). It is drawn open while a guard walks through,
## but stays solid for the player.
##
## Opening is undone by a checkpoint: CheckpointManager stores
## get_checkpoint_state() of every node in the "checkpoint_state" group when a
## checkpoint is activated and restores it when the player is caught.
##
## The optional NoiseMaker child "Noise" rattles when the door refuses the player.

signal rejected(reason: String)
signal opened

enum Mode { KEY, ONE_WAY }

@export var mode := Mode.KEY
## Name used in the prompt and the HUD messages, e.g. "Archive Front Gate".
@export var door_name := "Door"
## KEY mode: the objective that must be completed before the door opens.
@export var key_objective_id: StringName = ObjectiveManager.TAKE_CARD
## KEY mode: ItemCatalog id the player must be carrying instead of the objective (empty: use the objective).
@export var key_item: StringName = &""
## What the player is missing, for the prompt and the rejection message.
@export var key_name := "staff access card"
## ONE_WAY mode: world direction (horizontal) from the door to the side it opens from.
@export var open_from := Vector3.RIGHT
## Objective completed by opening the door (optional).
@export var complete_objective_id: StringName = &""
## How close (horizontally, metres) a guard must be for the door to be drawn open.
@export var guard_open_distance := 1.6
## Expansion Phase 6 (a hidden door): until the player has this clue document in
## the journal, the door looks like the wall around it (`hidden_colour`), shows
## no prompt and can't be used. A KEY door with neither key_objective_id nor
## key_item then opens with E (a hidden latch).
@export var hidden_until_document: StringName = &""
@export var hidden_colour := Color(0.55, 0.53, 0.5)
## Polish (the maintenance panel): once found, the panel shows this colour (alpha 0:
## the usual green / red) and its "Panel/Hatch" child (the hatch's frame, latch and
## stencil) appears; before, the hatch is hidden and the panel looks like the wall.
@export var found_colour := Color(0, 0, 0, 0)
## Polish (the electrical room door): door leaves on hinges (Node3Ds turning about y)
## drawn instead of the panel's mesh; they swing to `leaf_open_angles` (degrees) when
## the door opens (and while a guard walks through), back when it closes, at once on a
## checkpoint restore. The panel's collision is unchanged.
@export var leaf_paths: Array[NodePath] = []
@export var leaf_open_angles := PackedFloat32Array()
## Lamps (MeshInstance3Ds) showing what the panel's colour shows: green when the
## player could open the door from where they are, red otherwise.
@export var status_light_paths: Array[NodePath] = []

const LEAF_TIME := 0.6

## True once opened.
var is_open := false
## Times the door refused the player (for tests).
var rejections := 0

@onready var _panel: StaticBody3D = get_node_or_null("Panel")
@onready var _noise: NoiseMaker = get_node_or_null("Noise")
@onready var _sign: Label3D = get_node_or_null("Sign")
@onready var _hatch: Node3D = get_node_or_null("Panel/Hatch")

var _panel_material: StandardMaterial3D
var _leaves: Array[Node3D] = []
var _leaves_open := false
var _leaf_tween: Tween
var _animate_leaves := false
var _status_materials: Array[StandardMaterial3D] = []
var _status_colour := Color(0, 0, 0, 0)


func _ready() -> void:
	super()
	add_to_group("checkpoint_state")
	add_to_group("access_doors")
	if prompt == "Interact":
		prompt = "Open the %s" % door_name.to_lower()
	if _panel:
		var mesh := _panel.get_node_or_null("Mesh") as MeshInstance3D
		if mesh:
			_panel_material = StandardMaterial3D.new()
			mesh.material_override = _panel_material
	for path in leaf_paths:
		var leaf := get_node_or_null(path) as Node3D
		if leaf:
			_leaves.append(leaf)
	for path in status_light_paths:
		var lamp := get_node_or_null(path) as GeometryInstance3D
		if lamp:
			var m := StandardMaterial3D.new()
			m.emission_enabled = true
			m.emission_energy_multiplier = 0.9
			lamp.material_override = m
			_status_materials.append(m)
	_apply()
	get_tree().node_added.connect(_on_node_added)
	_connect_late.call_deferred()


func _connect_late() -> void:
	for guard in get_tree().get_nodes_in_group("guards"):
		_let_through(guard)
	var manager := _manager()
	if manager and not manager.objective_changed.is_connected(_on_objective_changed):
		manager.objective_changed.connect(_on_objective_changed)


func _on_node_added(node: Node) -> void:
	if node is Guard:
		_let_through.call_deferred(node)


func _let_through(guard: Node) -> void:
	if _panel and is_instance_valid(guard) and guard is PhysicsBody3D:
		(guard as PhysicsBody3D).add_collision_exception_with(_panel)


func _process(_delta: float) -> void:
	if _panel == null or is_open:
		return
	if hidden_until_document != &"":
		var found := is_discovered()
		enabled = found
		if _sign:
			_sign.visible = found
		if not found:
			if _panel_material:
				_panel_material.albedo_color = hidden_colour
			if _hatch and _hatch.visible:
				_hatch.visible = false
			return
	# Drawn open while a guard is in the doorway (it stays solid for the player).
	var mesh := _panel.get_node_or_null("Mesh") as Node3D
	var guard_through := _guard_in_doorway()
	if not _leaves.is_empty():
		_set_leaves(guard_through, true)
	elif mesh:
		mesh.visible = not guard_through
		if _hatch and _hatch.visible != mesh.visible:
			_hatch.visible = mesh.visible
	if _panel_material:
		# Green only when the player could open it from where they are (a one-way
		# door is red from its locked side).
		var player := get_tree().get_first_node_in_group("player")
		var colour := Color(0.3, 0.75, 0.4) if player and _refusal(player) == "" else Color(0.7, 0.2, 0.17)
		_set_status(colour)
		if found_colour.a > 0.0:
			colour = found_colour
		# Expansion Phase 9: the material is only touched when its colour changes.
		if _panel_material.albedo_color != colour:
			_panel_material.albedo_color = colour
	if _sign:
		var tint := _panel_material.albedo_color.lightened(0.3) if _panel_material else Color.WHITE
		if _sign.modulate != tint:
			_sign.modulate = tint


func get_prompt(by: Node) -> String:
	if is_open:
		return ""
	var reason := _refusal(by)
	if reason == "":
		return prompt
	if mode == Mode.KEY:
		return "%s · locked (%s needed)" % [door_name, key_name]
	return "%s · locked from this side" % door_name


## True if `by` could open the door right now.
func can_open(by: Node) -> bool:
	return not is_open and _refusal(by) == ""


func _on_interact(by: Node) -> bool:
	if is_open or not is_discovered():
		return false
	var reason := _refusal(by)
	if reason != "":
		rejections += 1
		if _noise:
			_noise.make_noise()
		rejected.emit(reason)
		return false
	open()
	return true


## Opens the door (also used by tests and checkpoint restores).
func open() -> void:
	if is_open:
		return
	is_open = true
	_animate_leaves = true
	_apply()
	_animate_leaves = false
	_complete_objective()
	opened.emit()


## Why `by` can't open the door right now, or "" if it can.
func _refusal(by: Node) -> String:
	match mode:
		Mode.KEY:
			if not _allowed_by_key(by):
				return "%s is locked. You need the %s." % [door_name, key_name]
		Mode.ONE_WAY:
			var node := by as Node3D
			if node == null:
				return "%s only opens from the other side." % door_name
			var offset := node.global_position - global_position
			offset.y = 0.0
			var side := Vector3(open_from.x, 0.0, open_from.z).normalized()
			if offset.dot(side) <= 0.0:
				return "%s only opens from the other side." % door_name
	return ""


## A hidden door: whether its clue document is in the journal (always true for other doors).
func is_discovered() -> bool:
	if hidden_until_document == &"":
		return true
	var inventory := PlayerInventory.find(self)
	return inventory != null and inventory.has_document(hidden_until_document)


func _allowed_by_key(by: Node = null) -> bool:
	if mode != Mode.KEY:
		return true
	if key_item == &"" and key_objective_id == &"":
		return true   # a latch: anyone who knows where it is
	if key_item != &"":
		var inventory := by.get_node_or_null("Inventory") as PlayerInventory if by else null
		if inventory == null:
			inventory = PlayerInventory.find(self)
		return inventory != null and inventory.enabled and inventory.has(key_item)
	var manager := _manager()
	return manager != null and manager.is_completed(key_objective_id)


func _guard_in_doorway() -> bool:
	for guard in get_tree().get_nodes_in_group("guards"):
		var g := guard as Node3D
		if g == null:
			continue
		var offset := g.global_position - global_position
		if absf(offset.y + 1.2) < 1.5 and Vector2(offset.x, offset.z).length() < guard_open_distance:
			return true
	return false


func _on_objective_changed(id: StringName, state: ObjectiveManager.State) -> void:
	# Deferred: this runs while ObjectiveManager is still changing states (a
	# completion, or a checkpoint restore rebuilding the whole flow).
	if id == complete_objective_id and state == ObjectiveManager.State.ACTIVE and is_open:
		_complete_objective.call_deferred()


func _complete_objective() -> void:
	var manager := _manager()
	if is_open and manager and complete_objective_id != &"" \
			and manager.get_state(complete_objective_id) == ObjectiveManager.State.ACTIVE:
		manager.complete(complete_objective_id)


## Shows or hides the panel and switches its collision to match is_open.
func _apply() -> void:
	enabled = not is_open and (hidden_until_document == &"" or is_inside_tree() and is_discovered())
	if _panel:
		_panel.visible = not is_open
		# Only the layer changes (allowed at any time, also mid physics step).
		_panel.collision_layer = 0 if is_open else 1
		var mesh := _panel.get_node_or_null("Mesh") as Node3D
		if mesh:
			mesh.visible = _leaves.is_empty()   # with leaves (their own nodes), the panel draws nothing
	_set_leaves(is_open, _animate_leaves)
	if _sign:
		_sign.visible = not is_open


## Polish: the leaves open or shut (animated, or at once).
func _set_leaves(open_now: bool, animate: bool) -> void:
	if _leaves.is_empty() or (open_now == _leaves_open and animate):
		return
	_leaves_open = open_now
	if _leaf_tween:
		_leaf_tween.kill()
	if animate and is_inside_tree():
		_leaf_tween = create_tween().set_parallel(true)
	for i in _leaves.size():
		var angle := deg_to_rad(leaf_open_angles[i] if open_now and i < leaf_open_angles.size() else 0.0)
		if animate and is_inside_tree():
			_leaf_tween.tween_property(_leaves[i], "rotation:y", angle, LEAF_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			_leaves[i].rotation.y = angle


## Polish: the status lamps' colour (only touched when it changes).
func _set_status(colour: Color) -> void:
	if _status_materials.is_empty() or colour == _status_colour:
		return
	_status_colour = colour
	for m in _status_materials:
		m.albedo_color = colour
		m.emission = colour


# --- Checkpoints -------------------------------------------------------------------------------

func get_checkpoint_state() -> Dictionary:
	return {"open": is_open}


## Puts the door back as stored. Restoring never completes objectives: the
## objective flow is restored separately, from the same snapshot.
func restore_checkpoint_state(state: Dictionary) -> void:
	is_open = bool(state.get("open", false))
	_apply()


func _manager() -> ObjectiveManager:
	return ObjectiveManager.find(self)
