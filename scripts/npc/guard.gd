class_name Guard
extends CharacterBody3D

## Reusable guard NPC.
##
## The guard is the "actor": it senses (Vision child, reported noises) and
## moves (NavigationAgent3D, avoidance, move_and_slide). All decisions are
## made by its GuardStateMachine, which has exactly three primary states:
## PATROL, INVESTIGATE and CHASE (see scripts/npc/ai/).
##
## Each physics frame: build a GuardPerception snapshot → machine.tick() →
## move toward the current navigation goal.

## Machine state changes: from/to are GuardStateMachine.PATROL/INVESTIGATE/CHASE.
signal ai_state_changed(from: int, to: int, reason: String)
signal patrol_point_reached(index: int)
## Emitted when the guard starts (waiting = true) or stops waiting at a patrol point.
signal patrol_wait_changed(waiting: bool, index: int)
## Emitted when the guard made no progress for stuck_timeout seconds and skipped a point.
signal got_stuck(index: int)

## The route to walk. Several guards may share one route.
@export var patrol_route: PatrolRoute

@export_group("Movement")
## Walking speed while patrolling, in metres per second.
@export var patrol_speed := 2.0
## Speed while walking to investigate something.
@export var investigate_speed := 2.6
## Running speed while chasing (the player walks at 3.5 and sprints at 5.5).
@export var chase_speed := 4.2
## How quickly the guard turns to face where it is walking (higher is snappier).
@export var turn_speed := 8.0
## Seconds without getting closer (along the path) before the current movement counts as stuck.
@export var stuck_timeout := 5.0

@export_group("Behaviour")
## Wait at points whose PatrolPoint.wait_time is -1 (or plain Marker3D points).
@export_range(0.0, 60.0, 0.1) var default_wait_time := 2.0
## Seconds spent searching at an investigated location before returning to patrol.
@export var investigate_search_duration := 6.0
## Seconds without seeing the player before a chase becomes an investigation.
@export var chase_lose_sight_time := 4.0
## A suspicious sighting counts as evidence for this many seconds after the player was last seen.
@export var suspicion_memory := 2.0

## Kept for compatibility with Phase 4 scenes and tests: same as patrol_speed.
var walk_speed: float:
	get:
		return patrol_speed
	set(value):
		patrol_speed = value

## Seconds of being blocked before steering right, and how far to steer (radians, about 35°).
const KEEP_RIGHT_AFTER := 0.6
const KEEP_RIGHT_ANGLE := 0.6
## The remaining path must shrink by this much (metres) to count as progress.
const PROGRESS_STEP := 0.5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## The guard's brain. Created in _ready.
var machine: GuardStateMachine

var _move_speed := 0.0
var _navigating := false
var _arrived := false
var _stuck_time := 0.0
var _blocked_time := 0.0
var _best_remaining := INF
var _face_yaw := NAN
var _pending_noise := {}

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var debug_label: Label3D = $DebugLabel
## Line-of-sight perception and detection meter (may be absent on custom guards).
@onready var vision: GuardVision = get_node_or_null("Vision")


## Patrol point the guard is walking to or waiting at.
var current_point: int:
	get:
		return (machine.get_state(GuardStateMachine.PATROL) as PatrolState).current_point if machine else 0


func _ready() -> void:
	add_to_group("guards")
	add_to_group("navigation_debug_agents")  # NavigationDebug draws this guard's path.
	if OS.is_debug_build():
		debug_label.add_to_group("debug_visuals")
	else:
		debug_label.queue_free()
		debug_label = null
	agent.navigation_finished.connect(func(): _arrived = true)
	agent.velocity_computed.connect(_on_velocity_computed)
	agent.max_speed = chase_speed  # Avoidance must never push the guard faster than it runs.

	machine = GuardStateMachine.new(self)
	machine.transitioned.connect(func(from, to, reason): ai_state_changed.emit(from, to, reason))
	if patrol_route == null or patrol_route.get_point_count() == 0:
		push_warning("%s has no patrol route with points, so it will stand still while patrolling." % name)
	if await NavigationUtils.wait_for_navigation(self):
		machine.start()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if machine.current != GuardStateMachine.NONE:
		machine.tick(build_perception(), delta)
	_pending_noise = {}

	var desired := _navigation_velocity(delta)
	if agent.avoidance_enabled:
		# The avoidance system adjusts the velocity and calls _on_velocity_computed.
		agent.max_speed = maxf(_move_speed, 0.1)
		agent.velocity = desired
	else:
		_move(desired, delta)
	_update_debug_label()


# --- Perception -----------------------------------------------------------------

## Snapshot of what this guard legitimately perceives right now.
func build_perception() -> GuardPerception:
	var p := GuardPerception.new()
	if vision:
		p.can_see_player = vision.can_see_target
		p.has_sighting_position = vision.has_last_known_position
		p.sighting_position = vision.last_known_position
		p.confirmed_sighting = vision.can_see_target and vision.awareness == GuardVision.Awareness.ALERTED
		p.suspicious_sighting = vision.has_last_known_position \
			and vision.awareness >= GuardVision.Awareness.SUSPICIOUS \
			and vision.time_since_seen <= suspicion_memory
	if not _pending_noise.is_empty():
		p.noise_heard = true
		p.noise_position = _pending_noise.position
	return p


## Reports a noise at a world position. The hearing system (a later phase)
## will call this; it is processed on the next physics frame.
func hear_noise(position: Vector3, loudness := 1.0) -> void:
	if _pending_noise.is_empty() or loudness > _pending_noise.loudness:
		_pending_noise = {"position": position, "loudness": loudness}


# --- Actor interface used by the states ------------------------------------------

func navigate_to(point: Vector3, speed: float) -> void:
	agent.target_position = point
	_move_speed = speed
	_navigating = true
	_arrived = false
	_stuck_time = 0.0
	_blocked_time = 0.0
	_best_remaining = INF
	_face_yaw = NAN


func stop_moving() -> void:
	_navigating = false
	_move_speed = 0.0
	_stuck_time = 0.0


func has_arrived() -> bool:
	return _navigating and _arrived


func is_stuck() -> bool:
	return _navigating and not _arrived and _stuck_time >= stuck_timeout


## Turns the guard (while standing) to face a yaw angle in radians.
func face_yaw(yaw: float) -> void:
	_face_yaw = yaw


func get_yaw() -> float:
	return rotation.y


## Clears remembered evidence so it cannot trigger a new investigation.
func forget_suspicion() -> void:
	if vision:
		vision.forget_last_known_position()


func notify_patrol_point_reached(index: int) -> void:
	patrol_point_reached.emit(index)


func notify_patrol_wait(waiting: bool, index: int) -> void:
	patrol_wait_changed.emit(waiting, index)


func notify_stuck(index: int) -> void:
	push_warning("%s is stuck on the way to its target (patrol point %d); moving on." % [name, index])
	got_stuck.emit(index)


# --- Movement ----------------------------------------------------------------------

## Horizontal velocity toward the next corner of the navigation path.
func _navigation_velocity(delta: float) -> Vector3:
	if not _navigating or _arrived:
		return Vector3.ZERO
	if agent.is_navigation_finished():
		_arrived = true
		return Vector3.ZERO
	var to_next := agent.get_next_path_position() - global_position
	to_next.y = 0.0
	var desired := to_next.normalized() * _move_speed if to_next.length_squared() > 0.0001 else Vector3.ZERO
	# Stuck detection: the remaining path has not shrunk by PROGRESS_STEP for stuck_timeout seconds.
	var remaining := _remaining_path_length()
	if remaining < _best_remaining - PROGRESS_STEP:
		_best_remaining = remaining
		_stuck_time = 0.0
	else:
		_stuck_time += delta
	# Two guards meeting head-on can block each other symmetrically. After a
	# moment of moving far slower than intended, steer to the guard's own right
	# ("keep right"): guards facing each other then step apart in opposite directions.
	if Vector2(get_real_velocity().x, get_real_velocity().z).length() < _move_speed * 0.25:
		_blocked_time += delta
	else:
		_blocked_time = 0.0
	if _blocked_time > KEEP_RIGHT_AFTER:
		desired = desired.rotated(Vector3.UP, -KEEP_RIGHT_ANGLE)
	return desired


func _remaining_path_length() -> float:
	var path := agent.get_current_navigation_path()
	var index := agent.get_current_navigation_path_index()
	if path.is_empty() or index >= path.size():
		return global_position.distance_to(agent.target_position)
	var length := global_position.distance_to(path[index])
	for i in range(index, path.size() - 1):
		length += path[i].distance_to(path[i + 1])
	return length


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	_move(safe_velocity, get_physics_process_delta_time())


func _move(horizontal: Vector3, delta: float) -> void:
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	var weight := clampf(turn_speed * delta, 0.0, 1.0)
	if Vector2(horizontal.x, horizontal.z).length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-horizontal.x, -horizontal.z), weight)
	elif not is_nan(_face_yaw):
		rotation.y = lerp_angle(rotation.y, _face_yaw, weight * 0.5)
	move_and_slide()


# --- Debug -----------------------------------------------------------------------

## Text shown above the guard in debug builds, e.g.
## "GuardMain\nPATROL (→ point 2)\nUNAWARE [----------] 0".
func get_debug_text() -> String:
	var text := "%s\n%s" % [name, machine.get_debug_text() if machine else "NONE"]
	if vision:
		text += "\n" + vision.get_debug_text()
	return text


func _update_debug_label() -> void:
	if debug_label and debug_label.visible:
		debug_label.text = get_debug_text()
		debug_label.modulate = [Color.WHITE, Color(1.0, 0.85, 0.2), Color(1.0, 0.3, 0.25)][maxi(machine.current, 0)]
