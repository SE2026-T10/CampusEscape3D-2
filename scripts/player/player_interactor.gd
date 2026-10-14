class_name PlayerInteractor
extends Node

## Child of the player. Each physics frame it finds the Interactable the
## camera is pointing at within `reach` (walls and furniture block the ray)
## and uses it when the interact action is pressed.

signal focus_changed(target: Interactable)

## How far the player can reach, in metres from the camera.
@export var reach := 2.2

## The Interactable currently looked at, or null.
var focused: Interactable

@onready var _player: FirstPersonPlayer = get_parent()


func _physics_process(_delta: float) -> void:
	var target := find_target()
	if target != focused:
		focused = target
		focus_changed.emit(target)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and focused != null:
		try_interact()
		get_viewport().set_input_as_handled()


## Uses the focused Interactable. Returns true if the interaction succeeded.
func try_interact() -> bool:
	if focused == null or not is_instance_valid(focused):
		return false
	return focused.interact(_player)


## The enabled Interactable on the camera's centre line within reach, not behind
## anything solid, or null.
func find_target() -> Interactable:
	var camera := _player.camera
	var from := camera.global_position
	var to := from - camera.global_basis.z * reach
	var space := _player.get_world_3d().direct_space_state
	# Stop at the first wall or piece of furniture...
	var solid := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1, [_player.get_rid()]))
	if not solid.is_empty():
		to = solid.position
	# ...then look for an interactable before that point.
	var query := PhysicsRayQueryParameters3D.create(from, to, Interactable.LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	var target := hit.collider as Interactable
	return target if target != null and target.enabled else null


## Text for the HUD: "[E] <prompt>" for the focused object, or "".
func get_prompt_text() -> String:
	if focused == null or not is_instance_valid(focused):
		return ""
	return "[E] %s" % focused.get_prompt(_player)
