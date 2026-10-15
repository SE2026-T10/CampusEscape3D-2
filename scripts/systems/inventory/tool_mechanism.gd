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

signal operated
signal rejected(reason: String)

@export var mechanism_name := "Mechanism"
## ItemCatalog id of the tool needed.
@export var required_item: StringName = ItemCatalog.TOOLKIT
## What using it does, for the prompt, e.g. "Unscrew the panel".
@export var action_text := "Use the tool kit"

var is_operated := false
## Times it refused the player (for tests).
var rejections := 0

@onready var _noise: NoiseMaker = get_node_or_null("Noise")


func _ready() -> void:
	super()
	add_to_group("checkpoint_state")
	add_to_group("tool_mechanisms")
	_apply()


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
	operated.emit()
	return true


func _has_tool() -> bool:
	var inventory := PlayerInventory.find(self)
	return inventory != null and inventory.enabled and inventory.has(required_item)


func _apply() -> void:
	enabled = not is_operated


func get_checkpoint_state() -> Dictionary:
	return {"operated": is_operated}


func restore_checkpoint_state(state: Dictionary) -> void:
	is_operated = bool(state.get("operated", false))
	_apply()
