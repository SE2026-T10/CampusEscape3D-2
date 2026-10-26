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
var hold_target: Interactable
var hold_elapsed := 0.0
var hold_required := 0.0
var _button_down := false
var _waiting_release := false

@onready var _player: FirstPersonPlayer = get_parent()


func _ready() -> void:
	# Cancel even when the scene is paused or the actor is frozen by a capture.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(delta: float) -> void:
	if not _can_use():
		cancel_hold()
		_button_down = false
		_set_focus(null)
		return
	var target := find_target()
	_set_focus(target)
	var down := _button_down or Input.is_action_pressed("interact")
	if not down:
		_waiting_release = false
	if hold_target == null:
		return
	if not is_instance_valid(hold_target) or not down or target != hold_target or not hold_target.can_interact(_player):
		cancel_hold()
		return
	hold_elapsed += delta
	if hold_elapsed >= hold_required:
		var completed := hold_target
		cancel_hold()
		_waiting_release = true
		completed.interact(_player)


func _can_use() -> bool:
	if get_tree().paused or not _player.can_process():
		return false
	var flow := GameFlow.find(self)
	return flow == null or flow.state == GameStateMachine.State.PLAYING and not flow.is_leaving()


func _set_focus(target: Interactable) -> void:
	if target != focused:
		focused = target
		focus_changed.emit(target)


func cancel_hold() -> void:
	hold_target = null
	hold_elapsed = 0.0
	hold_required = 0.0


func get_hold_progress() -> float:
	return clampf(hold_elapsed / hold_required, 0.0, 1.0) if hold_required > 0.0 else 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_released("interact"):
		_button_down = false
		_waiting_release = false
		cancel_hold()
	if event.is_action_pressed("interact") and not event.is_echo() and focused != null:
		_button_down = true
		try_interact()
		get_viewport().set_input_as_handled()


## Instant use, or accept the start of a held use. Completion still calls interact().
func try_interact() -> bool:
	if not _can_use() or focused == null or not is_instance_valid(focused):
		return false
	var duration := focused.get_hold_duration(_player)
	if duration > 0.0:
		if hold_target != null or _waiting_release or find_target() != focused or not focused.can_interact(_player):
			return false
		hold_target = focused
		hold_elapsed = 0.0
		hold_required = duration
		return true
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
	if focused.can_interact(_player) and focused.get_hold_duration(_player) > 0.0:
		return "[E] Giữ %.1f giây · %s" % [focused.get_hold_duration(_player), focused.get_prompt(_player)]
	return "[E] %s" % focused.get_prompt(_player)
