extends Node3D

## Development tool: draws the baked navigation mesh as a translucent cyan
## overlay with outlined polygons, and draws the current path of every
## NavigationProbe in the scene in yellow. Toggle with the
## "toggle_navigation_debug" action (F3). Removed from release builds.

## The NavigationRegion3D whose navigation mesh is drawn.
@export var region: NavigationRegion3D
## Show the overlay when the scene starts.
@export var visible_on_start := true
## Height above the navigation mesh at which the overlay is drawn.
@export var height_offset := 0.06

## Number of navigation polygons in the overlay (read by tests).
var drawn_polygon_count := 0

var _fill: MeshInstance3D
var _edges: MeshInstance3D
var _paths: MeshInstance3D
var _path_mesh := ImmediateMesh.new()


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	# Created here, not at declaration, so a level that never enters the tree leaks nothing.
	_fill = MeshInstance3D.new()
	_edges = MeshInstance3D.new()
	_paths = MeshInstance3D.new()
	for child in [_fill, _edges, _paths]:
		child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(child)
	_fill.material_override = _make_material(Color(0.0, 0.9, 1.0, 0.4))
	_edges.material_override = _make_material(Color(0.6, 1.0, 1.0, 1.0))
	_paths.material_override = _make_material(Color(1.0, 0.85, 0.1, 1.0))
	_paths.mesh = _path_mesh
	if region:
		region.bake_finished.connect(rebuild)
	rebuild()
	visible = visible_on_start


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_navigation_debug"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		_draw_probe_paths()


## Rebuilds the overlay from the region's navigation mesh. Called again after a rebake.
func rebuild() -> void:
	var nav_mesh := region.navigation_mesh if region else null
	drawn_polygon_count = 0
	if nav_mesh == null or nav_mesh.get_polygon_count() == 0:
		push_warning("NavigationDebug: no baked navigation mesh to draw.")
		_fill.mesh = null
		_edges.mesh = null
		return
	var vertices := nav_mesh.get_vertices()
	var lift := Vector3(0, height_offset, 0)
	var fill := ImmediateMesh.new()
	var edges := ImmediateMesh.new()
	fill.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	edges.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in nav_mesh.get_polygon_count():
		var polygon := nav_mesh.get_polygon(i)
		for j in range(1, polygon.size() - 1):
			# Fan triangulation of the convex polygon.
			fill.surface_add_vertex(vertices[polygon[0]] + lift)
			fill.surface_add_vertex(vertices[polygon[j]] + lift)
			fill.surface_add_vertex(vertices[polygon[j + 1]] + lift)
		for j in polygon.size():
			edges.surface_add_vertex(vertices[polygon[j]] + lift)
			edges.surface_add_vertex(vertices[polygon[(j + 1) % polygon.size()]] + lift)
	fill.surface_end()
	edges.surface_end()
	_fill.mesh = fill
	_edges.mesh = edges
	drawn_polygon_count = nav_mesh.get_polygon_count()


func _draw_probe_paths() -> void:
	_path_mesh.clear_surfaces()
	for probe in get_tree().get_nodes_in_group("navigation_probes"):
		var path: PackedVector3Array = probe.agent.get_current_navigation_path()
		if path.size() < 2:
			continue
		_path_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for point in path:
			_path_mesh.surface_add_vertex(point + Vector3(0, height_offset * 2.0, 0))
		_path_mesh.surface_end()


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	return material
