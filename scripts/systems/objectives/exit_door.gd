class_name ExitDoor
extends Interactable

## The library's exit. Using it escapes only when the escape objective is
## ACTIVE, which means every earlier objective (including the access card) is
## done. Otherwise the door rejects the player: it rattles (an INTERACTION
## noise guards can hear, from the optional NoiseMaker child "Noise") and
## emits `rejected` with the reason for the HUD.

signal rejected(reason: String)
signal escaped

@export var objective_id: StringName = ObjectiveManager.ESCAPE
## The objective that unlocks the door (shown as the reason when it is missing).
@export var key_objective_id: StringName = ObjectiveManager.TAKE_CARD

## Sign text while the key objective is not done, and the HUD message when the
## door refuses the player for that reason. "%s" in locked_reason is replaced by
## the current objective's title (lower case).
@export var locked_sign := "LOCKED · ACCESS CARD"
@export var locked_reason := "The exit is locked. You need the access card."
## Prompt while the door would not open.
@export var locked_prompt := "Exit locked (access card needed)"

## The visible door. It is tinted red while locked and green once the card is taken.
@export var door_mesh: MeshInstance3D

## Times the door has refused the player (for tests).
var rejections := 0

@onready var _noise: NoiseMaker = get_node_or_null("Noise")
@onready var _sign: Label3D = get_node_or_null("Sign")


var _door_material: StandardMaterial3D


func _ready() -> void:
	super()
	prompt = "Escape"
	if door_mesh:
		_door_material = StandardMaterial3D.new()
		door_mesh.material_override = _door_material


func _process(_delta: float) -> void:
	var has_key := _manager() != null and _manager().is_completed(key_objective_id)
	var colour := Color(0.3, 0.9, 0.45) if has_key else Color(0.8, 0.18, 0.15)
	if _door_material:
		_door_material.albedo_color = colour
	if _sign:
		_sign.text = "EXIT · UNLOCKED" if has_key else locked_sign
		_sign.modulate = colour.lightened(0.2)


func get_prompt(_by: Node) -> String:
	return "Escape" if is_unlocked() else locked_prompt


## True when using the door would escape.
func is_unlocked() -> bool:
	var manager := _manager()
	return manager != null and manager.get_state(objective_id) == ObjectiveManager.State.ACTIVE


func _on_interact(_by: Node) -> bool:
	if is_unlocked():
		_manager().complete(objective_id)
		var director := StealthDirector.find(self)
		if director:
			director.finish_level()
		escaped.emit()
		return true
	rejections += 1
	if _noise:
		_noise.make_noise()
	rejected.emit(rejection_reason())
	return false


## Why the door won't open right now.
func rejection_reason() -> String:
	var manager := _manager()
	if manager == null:
		return "The exit is locked."
	if not manager.is_completed(key_objective_id):
		return locked_reason % manager.get_title(manager.current()).to_lower() if locked_reason.contains("%s") else locked_reason
	return "The exit won't open yet: %s first." % manager.get_title(manager.current()).to_lower()


func _manager() -> ObjectiveManager:
	return ObjectiveManager.find(self)
