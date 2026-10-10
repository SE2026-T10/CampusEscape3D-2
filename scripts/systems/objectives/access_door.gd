class_name AccessDoor
extends Interactable

## A closed door the player opens with the interact key (E), once allowed:
##   - KEY: needs `key_objective_id` COMPLETED (e.g. the staff access card).
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
## What the player is missing, for the prompt and the rejection message.
@export var key_name := "staff access card"
## ONE_WAY mode: world direction (horizontal) from the door to the side it opens from.
@export var open_from := Vector3.RIGHT
## Objective completed by opening the door (optional).
@export var complete_objective_id: StringName = &""
## How close (horizontally, metres) a guard must be for the door to be drawn open.
@export var guard_open_distance := 1.6

## True once opened.
var is_open := false
## Times the door refused the player (for tests).
var rejections := 0

@onready var _panel: StaticBody3D = get_node_or_null("Panel")
@onready var _noise: NoiseMaker = get_node_or_null("Noise")
@onready var _sign: Label3D = get_node_or_null("Sign")

var _panel_material: StandardMaterial3D


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
	# Drawn open while a guard is in the doorway (it stays solid for the player).
	var mesh := _panel.get_node_or_null("Mesh") as Node3D
	if mesh:
		mesh.visible = not _guard_in_doorway()
	if _panel_material:
		_panel_material.albedo_color = Color(0.3, 0.75, 0.4) if _allowed_by_key() else Color(0.7, 0.2, 0.17)
	if _sign:
		_sign.modulate = _panel_material.albedo_color.lightened(0.3) if _panel_material else Color.WHITE


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
	if is_open:
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
	_apply()
	_complete_objective()
	opened.emit()


## Why `by` can't open the door right now, or "" if it can.
func _refusal(by: Node) -> String:
	match mode:
		Mode.KEY:
			if not _allowed_by_key():
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


func _allowed_by_key() -> bool:
	if mode != Mode.KEY:
		return true
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
	enabled = not is_open
	if _panel:
		_panel.visible = not is_open
		# Only the layer changes (allowed at any time, also mid physics step).
		_panel.collision_layer = 0 if is_open else 1
		var mesh := _panel.get_node_or_null("Mesh") as Node3D
		if mesh:
			mesh.visible = true
	if _sign:
		_sign.visible = not is_open


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
