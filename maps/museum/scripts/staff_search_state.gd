extends InvestigateState

var time_left := 0.0
var stops: Array[Vector3] = []
var index := 0
var wait_left := 0.0
var sweep := 0.0
var on_route := true


func enter(actor, _previous: int, _position: Vector3) -> void:
	actor.stand_up()
	actor.set_phase(&"searching")
	time_left = actor.room_search_duration
	stops = []
	for i in actor.patrol_route.get_point_count():
		stops.append(actor.patrol_route.get_point_position(i))
	index = 0
	_go(actor,stops[0])
	actor.notice.emit("G3 đang kiểm tra theo vòng H. Hãy cúi sau bàn A hoặc rời phòng.")


func update(actor, perception: GuardPerception, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		machine.request_transition(GuardStateMachine.PATROL,"staff search finished")
		return
	if perception.suspicious_sighting and perception.can_see_player:
		var evidence: Vector3 = actor.room_point(perception.sighting_position)
		if evidence.distance_to(target) > 1.0:
			_go(actor,evidence,false)
	elif perception.noise_heard:
		var evidence: Vector3 = actor.room_point(perception.noise_position)
		if evidence.distance_to(target) > 1.0:
			_go(actor,evidence,false)
	if wait_left > 0.0:
		wait_left -= delta
		sweep += delta
		actor.face_yaw(actor.get_yaw()+sin(sweep*2.0)*delta)
		if wait_left <= 0.0:
			if on_route:
				index += 1
			if index >= stops.size():
				machine.request_transition(GuardStateMachine.PATROL,"H inspection loop completed")
				return
			_go(actor,stops[index])
	elif actor.has_arrived() or actor.is_stuck():
		if on_route and actor.has_arrived():
			actor.notify_patrol_point_reached(index)
		actor.stop_moving()
		wait_left = 1.0


func _go(actor, at: Vector3, route_target := true) -> void:
	target = at
	on_route = route_target
	wait_left = 0.0
	actor.navigate_to(at,actor.investigate_speed)


func exit(actor, _next: int) -> void:
	actor.stop_moving()
