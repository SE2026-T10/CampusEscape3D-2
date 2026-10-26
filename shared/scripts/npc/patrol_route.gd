class_name PatrolRoute
extends Node3D

## An ordered list of patrol points: this node's Marker3D children (usually
## PatrolPoints), in scene-tree order. Several guards can share one route.
## In debug builds the route is drawn as a coloured line (toggle with F3).

## After the last point, go back to the first. If false, the guard stops at the last point.
@export var loop := true
## Colour of the route line in the debug view.
@export var debug_color := Color(1.0, 0.45, 0.1)

var _debug_mesh: MeshInstance3D


func _ready() -> void:
	if OS.is_debug_build():
		_build_debug_mesh()


func get_point_count() -> int:
	return _points().size()


func get_point_position(index: int) -> Vector3:
	return _points()[index].global_position


## Wait time for a point: the PatrolPoint's own value, or fallback when it has none.
func get_wait_time(index: int, fallback: float) -> float:
	var point := _points()[index]
	if point is PatrolPoint and point.wait_time >= 0.0:
		return point.wait_time
	return fallback


## Index of the point after `index`, or -1 when a non-looping route has ended.
func next_index(index: int) -> int:
	var count := get_point_count()
	if count == 0:
		return -1
	if index + 1 < count:
		return index + 1
	return 0 if loop else -1


func _points() -> Array[Marker3D]:
	var points: Array[Marker3D] = []
	for child in get_children():
		if child is Marker3D:
			points.append(child)
	return points


func _build_debug_mesh() -> void:
	var points := _points()
	if points.size() < 2:
		return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var segments := points.size() if loop else points.size() - 1
	for i in segments:
		var a := to_local(points[i].global_position) + Vector3(0, 0.15, 0)
		var b := to_local(points[(i + 1) % points.size()].global_position) + Vector3(0, 0.15, 0)
		mesh.surface_add_vertex(a)
		mesh.surface_add_vertex(b)
		# Small vertical post at each point.
		mesh.surface_add_vertex(a)
		mesh.surface_add_vertex(a + Vector3(0, 0.6, 0))
	mesh.surface_end()
	var material := StandardMaterial3D.new()
	material.albedo_color = debug_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debug_mesh = MeshInstance3D.new()
	_debug_mesh.mesh = mesh
	_debug_mesh.material_override = material
	_debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debug_mesh.add_to_group("debug_visuals")
	add_child(_debug_mesh)
