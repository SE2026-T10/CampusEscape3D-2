class_name Interactable
extends Area3D

## Something the player can use with the interact key (E) while looking at it
## within reach. PlayerInteractor finds it with a ray on the "interactable"
## physics layer, so the object needs a CollisionShape3D child.
## Subclasses override get_prompt(), can_interact() and _on_interact().

signal interacted(by: Node)

## Physics layer 4, "interactable".
const LAYER := 8

## Text shown under the crosshair while the player looks at this, e.g. "Take the access card".
@export var prompt := "Interact"
## Disabled interactables are ignored by the player's interaction ray.
@export var enabled := true


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactables")


func get_prompt(_by: Node) -> String:
	return prompt


func can_interact(_by: Node) -> bool:
	return enabled


## Uses the object. Returns true if the interaction succeeded.
func interact(by: Node) -> bool:
	if not can_interact(by):
		return false
	var ok := _on_interact(by)
	interacted.emit(by)
	return ok


## Override: what using the object does. Return false if it was refused.
func _on_interact(_by: Node) -> bool:
	return true
