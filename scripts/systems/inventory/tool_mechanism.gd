class_name ToolMechanism
extends Interactable

## A designated mechanism that needs a carried tool (by default the tool kit):
## a panel to unscrew, a valve to free, a jammed hatch. Using it while carrying
## the tool operates it once (`operated`); the tool is only checked, never used
## up. Without the tool it refuses, like a locked AccessDoor (`rejected`, which
## ObjectiveHud shows).
##
## Puzzles connect to `operated` (Phase 4 places the real mechanisms). Operated
## or not is part of the mission state (group "checkpoint_state").
## The optional NoiseMaker child "Noise" makes a noise when it is operated.
## `objective_id` (optional) completes when it is operated, or as soon as that
## objective becomes ACTIVE if it was operated earlier. With
## `hide_model_when_operated`, its "Model" child disappears once operated (a
## cover that comes off).

signal operated
signal rejected(reason: String)
## Emitted after a checkpoint restore (puzzles behind it refresh).
signal operated_restored

@export var mechanism_name := "Mechanism"
## ItemCatalog id of the tool needed.
@export var required_item: StringName = ItemCatalog.TOOLKIT
## What using it does, for the prompt, e.g. "Unscrew the panel".
@export var action_text := "Use the tool kit"
## Objective completed by operating it (optional).
@export var objective_id: StringName = &""
## Hide the "Model" child once operated (e.g. a panel cover).
@export var hide_model_when_operated := false

var is_operated := false
## Times it refused the player (for tests).
var rejections := 0

@onready var _noise: NoiseMaker = get_node_or_null("Noise")


func _ready() -> void:
	super()
	add_to_group("checkpoint_state")
	add_to_group("tool_mechanisms")
	_apply()
	_connect_manager.call_deferred()


func _connect_manager() -> void:
	var manager := ObjectiveManager.find(self)
	if manager and objective_id != &"" and not manager.objective_changed.is_connected(_on_objective_changed):
		manager.objective_changed.connect(_on_objective_changed)


func _on_objective_changed(id: StringName, state: ObjectiveManager.State) -> void:
	if id == objective_id and state == ObjectiveManager.State.ACTIVE and is_operated:
		_complete_objective.call_deferred()


func _complete_objective() -> void:
	var manager := ObjectiveManager.find(self)
	if is_operated and manager and objective_id != &"":
		manager.try_complete(objective_id)


func get_prompt(by: Node) -> String:
	if is_operated:
		return ""
	if _has_tool():
		return "%s: %s" % [mechanism_name, action_text.to_lower()]
	return "%s · locked (%s needed)" % [mechanism_name, ItemCatalog.item_name(required_item).to_lower()]


func _on_interact(_by: Node) -> bool:
	if is_operated:
		return false
	if not _has_tool():
		rejections += 1
		rejected.emit("%s: you need the %s." % [mechanism_name, ItemCatalog.item_name(required_item).to_lower()])
		return false
	is_operated = true
	_apply()
	if _noise:
		_noise.make_noise()
	_complete_objective()
	operated.emit()
	return true


func _has_tool() -> bool:
	var inventory := PlayerInventory.find(self)
	return inventory != null and inventory.enabled and inventory.has(required_item)


func _apply() -> void:
	enabled = not is_operated
	var model := get_node_or_null("Model") as Node3D
	if model and hide_model_when_operated:
		model.visible = not is_operated
		# A removed cover no longer catches the interaction ray (what was behind it can be used).
		collision_layer = 0 if is_operated else LAYER


func get_checkpoint_state() -> Dictionary:
	return {"operated": is_operated}


func restore_checkpoint_state(state: Dictionary) -> void:
	is_operated = bool(state.get("operated", false))
	_apply()
	operated_restored.emit()
