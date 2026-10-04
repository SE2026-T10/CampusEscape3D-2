class_name GuardState
extends RefCounted

## Base class for the guard's three primary states. Each state keeps its own
## data and acts only through the `actor` it is given, which must provide:
##   global_position, patrol_speed, investigate_speed, chase_speed,
##   navigate_to(point, speed), stop_moving(), has_arrived(), is_stuck(),
##   face_yaw(yaw), get_yaw(), forget_suspicion(),
##   patrol_route (or null), default_wait_time,
##   notify_patrol_point_reached(index), notify_patrol_wait(waiting, index), notify_stuck(index),
##   investigate_search_duration, chase_lose_sight_time.
## The real actor is Guard; tests use a fake one.

## Set by GuardStateMachine. States ask it for transitions with
## machine.request_transition(); they never switch state themselves.
## Stored as a weak reference: the machine owns its states, so a strong
## reference back would form a cycle and neither would ever be freed.
var machine: GuardStateMachine:
	get:
		return _machine_ref.get_ref() if _machine_ref else null
	set(value):
		_machine_ref = weakref(value) if value else null

var _machine_ref: WeakRef


## Called once when the state becomes current. `position` is the point the
## transition is about (investigation target, chase start), if any.
func enter(_actor, _previous: int, _position: Vector3) -> void:
	pass


## Called every tick while current, unless a higher-priority transition happened first.
func update(_actor, _perception: GuardPerception, _delta: float) -> void:
	pass


## Called once when the state stops being current.
func exit(_actor, _next: int) -> void:
	pass


## Short description of what the state is doing, for the debug label.
func get_debug_text() -> String:
	return ""
