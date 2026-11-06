extends PatrolState

## Normal shared patrol except for one authored, repeatable painting check.
var _missing_seen_for := 0.0


func enter(actor, previous: int, position: Vector3) -> void:
	_missing_seen_for = 0.0
	actor.inspection_phase = &"patrol"
	if previous == GuardStateMachine.INVESTIGATE and actor.discovery_reported and actor.is_inspection_point(current_point):
		var next: int = actor.patrol_route.next_index(current_point)
		if next >= 0:
			current_point = next
	super(actor,previous,position)


func update(actor, perception: GuardPerception, delta: float) -> void:
	if not actor.is_inspection_point(current_point):
		super(actor,perception,delta)
		return
	if not waiting:
		if actor.has_arrived():
			actor.notify_patrol_point_reached(current_point)
			waiting = true
			wait_left = actor.inspection_duration
			actor.stop_moving()
			actor.inspection_phase = &"inspection"
			actor.inspection_visits += 1
			actor.notify_patrol_wait(true,current_point)
		elif actor.is_stuck():
			actor.notify_stuck(current_point)
			_advance(actor)
		return
	actor.face_frame()
	if actor.can_see_frame() and actor.painting.is_artwork_missing():
		_missing_seen_for += delta
		if _missing_seen_for >= actor.discovery_delay and actor.report_missing():
			return
	else:
		_missing_seen_for = 0.0
	wait_left -= delta
	if wait_left <= 0:
		waiting = false
		_missing_seen_for = 0.0
		actor.inspection_phase = &"patrol"
		actor.notify_patrol_wait(false,current_point)
		_advance(actor)


func exit(actor, next: int) -> void:
	_missing_seen_for = 0.0
	super(actor,next)
