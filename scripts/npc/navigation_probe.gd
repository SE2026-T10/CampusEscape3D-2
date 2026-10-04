class_name NavigationProbe
extends CharacterBody3D

## Development tool: a stand-in NPC that walks a route of points using
## NavigationAgent3D, to show that the library navigation works.
## It has no AI states (no patrol/investigate/chase logic) and removes
## itself from release builds.

signal target_reached(point: Vector3)

## Walking speed in metres per second.
@export var speed := 3.0
## Points to visit in order. Leave empty to drive the probe from code with go_to().
@export var route: Array[NodePath] = []
## Start walking the route as soon as the scene runs.
@export var autostart := true

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _route_points: Array[Vector3] = []
var _route_index := 0
var _moving := false

@onready var agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	add_to_group("navigation_debug_agents")  # NavigationDebug draws the paths of this group.
	for path in route:
		var point := get_node_or_null(path) as Node3D
		if point:
			_route_points.append(point.global_position)
	agent.navigation_finished.connect(_on_navigation_finished)
	if autostart and not _route_points.is_empty():
		if await NavigationUtils.wait_for_navigation(self):
			go_to(_route_points[0])


## Starts walking to a point on the navigation mesh.
func go_to(point: Vector3) -> void:
	agent.target_position = point
	_moving = true


func is_moving() -> bool:
	return _moving


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var horizontal := Vector3.ZERO
	if _moving and not agent.is_navigation_finished():
		var to_next := agent.get_next_path_position() - global_position
		to_next.y = 0.0
		if to_next.length_squared() > 0.0001:
			horizontal = to_next.normalized() * speed
			look_at(global_position + horizontal, Vector3.UP)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()


func _on_navigation_finished() -> void:
	_moving = false
	target_reached.emit(agent.target_position)
	if _route_points.is_empty():
		return
	_route_index = (_route_index + 1) % _route_points.size()
	go_to(_route_points[_route_index])
