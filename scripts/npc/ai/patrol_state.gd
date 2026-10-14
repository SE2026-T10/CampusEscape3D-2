class_name PatrolState
extends GuardState

## PATROL: walk the patrol route in order, waiting at each point.
## Waiting is part of patrolling, not a separate primary state. The current
## point is kept when leaving, so the guard resumes where it left off.

var current_point := 0
var waiting := false
var wait_left := 0.0
var route_finished := false
var has_route := false


func enter(actor, previous: int, _position: Vector3) -> void:
	waiting = false
	if previous != GuardStateMachine.NONE:
		# Coming back from investigating: old evidence must not trigger it again.
		actor.forget_suspicion()
	has_route = actor.patrol_route != null and actor.patrol_route.get_point_count() > 0
	if not has_route or route_finished:
		actor.stop_moving()
		return
	current_point = clampi(current_point, 0, actor.patrol_route.get_point_count() - 1)
	actor.navigate_to(actor.patrol_route.get_point_position(current_point), actor.patrol_speed)


func update(actor, _perception: GuardPerception, delta: float) -> void:
	if not has_route or route_finished:
		return
	if waiting:
		wait_left -= delta
		if wait_left <= 0.0:
			waiting = false
			actor.notify_patrol_wait(false, current_point)
			_advance(actor)
	elif actor.has_arrived():
		actor.notify_patrol_point_reached(current_point)
		waiting = true
		wait_left = actor.patrol_route.get_wait_time(current_point, actor.default_wait_time)
		actor.stop_moving()
		actor.notify_patrol_wait(true, current_point)
	elif actor.is_stuck():
		actor.notify_stuck(current_point)
		_advance(actor)


func exit(actor, _next: int) -> void:
	if waiting:
		waiting = false
		actor.notify_patrol_wait(false, current_point)


func _advance(actor) -> void:
	var next: int = actor.patrol_route.next_index(current_point)
	if next == -1:
		route_finished = true
		actor.stop_moving()
		return
	current_point = next
	actor.navigate_to(actor.patrol_route.get_point_position(current_point), actor.patrol_speed)


func get_debug_text() -> String:
	if not has_route:
		return "IDLE (no route)"
	if route_finished:
		return "waiting (route finished)"
	if waiting:
		return "waiting %.1fs at point %d" % [maxf(wait_left, 0.0), current_point + 1]
	return "→ point %d" % (current_point + 1)
