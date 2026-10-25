class_name ChaseState
extends GuardState

## CHASE: pursue the player with NavigationAgent3D. While the player is in
## view, the target follows the sighting position (legitimate perception).
## After losing sight the guard keeps running to the last known position;
## when it gets there, gets stuck, or has not seen the player for
## actor.chase_lose_sight_time seconds, it asks to INVESTIGATE that spot.

## Re-plan the path only when the sighting moved at least this far (metres).
const REPATH_DISTANCE := 0.5

var target := Vector3.ZERO
var time_since_seen := 0.0


func enter(actor, _previous: int, position: Vector3) -> void:
	target = position
	time_since_seen = 0.0
	actor.navigate_to(target, actor.chase_speed)


func update(actor, perception: GuardPerception, delta: float) -> void:
	if perception.can_see_player and perception.has_sighting_position:
		time_since_seen = 0.0
		if perception.sighting_position.distance_to(target) > REPATH_DISTANCE:
			target = perception.sighting_position
			actor.navigate_to(target, actor.chase_speed)
		return

	time_since_seen += delta
	if actor.has_arrived() or actor.is_stuck() or time_since_seen >= actor.chase_lose_sight_time:
		machine.request_transition(GuardStateMachine.INVESTIGATE, "lost sight of the player", target)


func exit(actor, _next: int) -> void:
	actor.stop_moving()


func get_debug_text() -> String:
	if time_since_seen > 0.0:
		return "lost sight %.1fs → last known (%.1f, %.1f)" % [time_since_seen, target.x, target.z]
	return "pursuing"
