class_name InvestigateState
extends GuardState

## INVESTIGATE: walk to the suspicious location, then search there (turning
## to look around) for actor.investigate_search_duration seconds. Fresh
## evidence moves the target and restarts the search. When the search runs
## out, it asks to return to PATROL. Seeing the player for certain is
## handled by the state machine's priority rules (→ CHASE).

## Seconds of travel after which the guard gives up reaching the target and searches where it is.
const MAX_TRAVEL_TIME := 20.0
## Seconds between looking left and right while searching.
const SWEEP_INTERVAL := 1.5
## How far to each side the guard looks while searching, in radians (60°).
const SWEEP_ANGLE := PI / 3.0

var target := Vector3.ZERO
var searching := false
var search_left := 0.0
var travel_time := 0.0
var retargets := 0

var _sweep_timer := 0.0
var _sweep_side := 1.0
var _base_yaw := 0.0


func enter(actor, _previous: int, position: Vector3) -> void:
	retargets = 0
	_go_to(actor, position)


func update(actor, perception: GuardPerception, delta: float) -> void:
	# New evidence (sighting beats noise) moves the investigation.
	if perception.suspicious_sighting and perception.has_sighting_position:
		if perception.sighting_position.distance_to(target) > 1.0:
			retargets += 1
			_go_to(actor, perception.sighting_position)
	elif perception.noise_heard and perception.noise_position.distance_to(target) > 1.0:
		retargets += 1
		_go_to(actor, perception.noise_position)

	if searching:
		search_left -= delta
		_sweep_timer -= delta
		if _sweep_timer <= 0.0:
			_sweep_timer = SWEEP_INTERVAL
			_sweep_side = -_sweep_side
			actor.face_yaw(_base_yaw + SWEEP_ANGLE * _sweep_side)
		if search_left <= 0.0:
			machine.request_transition(GuardStateMachine.PATROL, "investigation timed out")
		return

	travel_time += delta
	if actor.has_arrived() or actor.is_stuck() or travel_time >= MAX_TRAVEL_TIME:
		_start_search(actor)


func exit(actor, _next: int) -> void:
	searching = false
	actor.stop_moving()


func _go_to(actor, position: Vector3) -> void:
	target = position
	searching = false
	travel_time = 0.0
	actor.navigate_to(target, actor.investigate_speed)


func _start_search(actor) -> void:
	searching = true
	search_left = actor.investigate_search_duration
	_sweep_timer = 0.0
	_base_yaw = actor.get_yaw()
	actor.stop_moving()


func get_debug_text() -> String:
	if searching:
		return "searching %.1fs" % maxf(search_left, 0.0)
	return "→ (%.1f, %.1f)" % [target.x, target.z]
