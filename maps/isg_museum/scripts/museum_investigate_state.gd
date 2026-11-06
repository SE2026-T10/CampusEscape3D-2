extends InvestigateState

## A missing frame starts a stationary check, then an authored room sweep.
## New legitimate player evidence hands control back to shared investigation.
var _frame_search := false
var _checking_left := 0.0
var _points: Array[Vector3] = []
var _point_index := -1
var _at_stop := false
var _stop_left := 0.0


func enter(actor, previous: int, position: Vector3) -> void:
	_frame_search = machine.last_reason == "missing artwork T1"
	actor.inspection_phase = &"searching"
	if not _frame_search:
		super(actor,previous,position)
		return
	actor.inspection_phase = &"checking"
	_checking_left = actor.inspection_duration
	_points = actor.room_search_points()
	_point_index = -1
	target = position
	searching = true
	actor.stop_moving()
	actor.face_frame()


func update(actor, perception: GuardPerception, delta: float) -> void:
	if not _frame_search:
		super(actor,perception,delta)
		return
	if (perception.suspicious_sighting and perception.has_sighting_position) or perception.noise_heard:
		_frame_search = false
		actor.inspection_phase = &"searching"
		var evidence: Vector3 = perception.sighting_position if perception.suspicious_sighting and perception.has_sighting_position else perception.noise_position
		super.enter(actor,GuardStateMachine.INVESTIGATE,evidence)
		super(actor,perception,delta)
		return
	if _checking_left > 0:
		actor.face_frame()
		_checking_left -= delta
		if _checking_left <= 0:
			_next_stop(actor)
		return
	if _at_stop:
		_stop_left -= delta
		actor.face_yaw(_base_yaw+sin(machine.time_in_state*1.5)*PI/3)
		if _stop_left <= 0:
			_next_stop(actor)
		return
	travel_time += delta
	if actor.has_arrived() or actor.is_stuck() or travel_time >= MAX_TRAVEL_TIME:
		actor.stop_moving()
		_at_stop = true
		searching = true
		_stop_left = actor.search_stop_duration
		_base_yaw = actor.get_yaw()


func _next_stop(actor) -> void:
	_point_index += 1
	if _point_index >= _points.size():
		machine.request_transition(GuardStateMachine.PATROL,"room A search completed")
		return
	actor.inspection_phase = &"searching"
	_at_stop = false
	searching = false
	travel_time = 0
	target = _points[_point_index]
	actor.navigate_to(target,actor.investigate_speed)


func exit(actor, next: int) -> void:
	_frame_search = false
	_points.clear()
	super(actor,next)
