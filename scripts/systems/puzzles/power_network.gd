class_name PowerNetwork
extends Node

## Which circuits have power (Expanded Library, expansion Phase 4).
##
## A documented interface, not the full power system: puzzles switch circuits
## on (BreakerPanel) and devices ask whether they are powered (CodeLock). The
## later power phase is expected to extend this node (outages, generators,
## lights) while keeping these calls:
##   PowerNetwork.find(node)              the level's network, or null
##   is_powered(circuit) -> bool          unknown circuits are off
##   set_powered(circuit, on)             emits power_changed when it changes
##   signal power_changed(circuit, on)
## Circuit ids used so far: &"archive_vault" (the vault keypad).
##
## Persistence: part of the mission state (group "checkpoint_state"), so power
## switched on after the last checkpoint is off again when the player is caught.

signal power_changed(circuit: StringName, on: bool)

## Circuits and whether they start powered.
@export var circuits := {&"archive_vault": false}

var _powered := {}


func _ready() -> void:
	add_to_group("power_network")
	add_to_group("checkpoint_state")
	_powered = circuits.duplicate()


static func find(node: Node) -> PowerNetwork:
	if not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group("power_network") as PowerNetwork


func is_powered(circuit: StringName) -> bool:
	return bool(_powered.get(circuit, false))


func set_powered(circuit: StringName, on: bool) -> void:
	if is_powered(circuit) == on:
		return
	_powered[circuit] = on
	power_changed.emit(circuit, on)


func get_checkpoint_state() -> Dictionary:
	return {"powered": _powered.duplicate()}


func restore_checkpoint_state(state: Dictionary) -> void:
	var stored: Dictionary = state.get("powered", circuits)
	for circuit in _powered.keys() + stored.keys():
		set_powered(circuit, bool(stored.get(circuit, false)))
