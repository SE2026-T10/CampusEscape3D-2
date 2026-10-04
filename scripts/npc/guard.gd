class_name Guard
extends CharacterBody3D

## Reusable guard NPC. Walks the points of a PatrolRoute in order using
## NavigationAgent3D, waits at each point, and loops.
##
## Only patrolling exists so far. INVESTIGATE and CHASE will be added as new
## states in later phases; WAIT is the pause at a patrol point. The Vision
## child (GuardVision) already tracks detection, but nothing reacts to it yet.

signal state_changed(previous: State, current: State)
signal patrol_point_reached(index: int)
## Emitted when the guard made no progress for stuck_timeout seconds and skipped a point.
signal got_stuck(index: int)

enum State { PATROL, WAIT }

## The route to walk. Several guards may share one route.
@export var patrol_route: PatrolRoute
## Walking speed while patrolling, in metres per second.
@export var walk_speed := 2.0
## How quickly the guard turns to face where it is walking (higher is snappier).
@export var turn_speed := 8.0
## Wait at points whose PatrolPoint.wait_time is -1 (or plain Marker3D points).
@export_range(0.0, 60.0, 0.1) var default_wait_time := 2.0
## Seconds without progress before the guard gives up on a point and moves on.
@export var stuck_timeout := 5.0

var state: State = State.WAIT
## Index of the patrol point the guard is walking to or waiting at.
var current_point := 0
## Seconds left at the current point while waiting.
var wait_time_left := 0.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _stuck_time := 0.0
var _route_finished := false

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var debug_label: Label3D = $DebugLabel
## Line-of-sight perception and detection meter (may be absent on custom guards).
@onready var vision: GuardVision = get_node_or_null("Vision")


func _ready() -> void:
	add_to_group("guards")
	add_to_group("navigation_debug_agents")  # NavigationDebug draws this guard's path.
	if OS.is_debug_build():
		debug_label.add_to_group("debug_visuals")
	else:
		debug_label.queue_free()
		debug_label = null
	agent.navigation_finished.connect(_on_navigation_finished)
	agent.velocity_computed.connect(_on_velocity_computed)
	agent.max_speed = walk_speed  # Avoidance must never push the guard faster than it walks.

	if patrol_route == null or patrol_route.get_point_count() == 0:
		push_warning("%s has no patrol route with points, so it will stand still." % name)
		_route_finished = true
		return
	if await NavigationUtils.wait_for_navigation(self):
		_walk_to(0)
	else:
		_route_finished = true


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var desired := Vector3.ZERO
	match state:
		State.PATROL:
			desired = _patrol_velocity(delta)
		State.WAIT:
			_update_wait(delta)

	if agent.avoidance_enabled:
		# The avoidance system adjusts the velocity and calls _on_velocity_computed.
		agent.velocity = desired
	else:
		_move(desired, delta)
	_update_debug_label()


## Horizontal velocity toward the next corner of the navigation path.
func _patrol_velocity(delta: float) -> Vector3:
	if agent.is_navigation_finished():
		return Vector3.ZERO
	var to_next := agent.get_next_path_position() - global_position
	to_next.y = 0.0
	var desired := to_next.normalized() * walk_speed if to_next.length_squared() > 0.0001 else Vector3.ZERO

	# Stuck detection: real movement far below the intended speed.
	if Vector2(get_real_velocity().x, get_real_velocity().z).length() < walk_speed * 0.1:
		_stuck_time += delta
		if _stuck_time >= stuck_timeout:
			push_warning("%s is stuck on the way to patrol point %d; skipping it." % [name, current_point])
			got_stuck.emit(current_point)
			_advance()
	else:
		_stuck_time = 0.0
	return desired


func _update_wait(delta: float) -> void:
	if _route_finished:
		return
	wait_time_left -= delta
	if wait_time_left <= 0.0:
		_advance()


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	_move(safe_velocity, get_physics_process_delta_time())


func _move(horizontal: Vector3, delta: float) -> void:
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if Vector2(horizontal.x, horizontal.z).length() > 0.1:
		var target_yaw := atan2(-horizontal.x, -horizontal.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))
	move_and_slide()


func _on_navigation_finished() -> void:
	if state != State.PATROL:
		return
	patrol_point_reached.emit(current_point)
	wait_time_left = patrol_route.get_wait_time(current_point, default_wait_time)
	_set_state(State.WAIT)


func _advance() -> void:
	var next := patrol_route.next_index(current_point)
	if next == -1:
		_route_finished = true
		_set_state(State.WAIT)
		return
	_walk_to(next)


func _walk_to(index: int) -> void:
	current_point = index
	_stuck_time = 0.0
	agent.target_position = patrol_route.get_point_position(index)
	_set_state(State.PATROL)


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	var previous := state
	state = new_state
	state_changed.emit(previous, new_state)


## Text shown above the guard in debug builds, e.g. "GuardMain\nPATROL → point 2/4".
func get_debug_text() -> String:
	var total := patrol_route.get_point_count() if patrol_route else 0
	var line := ""
	if _route_finished:
		line = "IDLE (no route)" if total == 0 else "WAIT (route finished)"
	elif state == State.PATROL:
		line = "PATROL → point %d/%d" % [current_point + 1, total]
	else:
		line = "WAIT %.1fs at point %d/%d" % [maxf(wait_time_left, 0.0), current_point + 1, total]
	if vision:
		line += "\n" + vision.get_debug_text()
	return "%s\n%s" % [name, line]


func _update_debug_label() -> void:
	if debug_label and debug_label.visible:
		debug_label.text = get_debug_text()
