extends Node

## Rebuilds the Museum Heist navigation mesh from static colliders across the
## whole level (including MuseumDecor, which is outside NavigationRegion3D).
## Run from the project folder:
##   godot --headless --path . --script res://maps/museum/tools/bake_navigation.gd

const LEVEL_SCENE := "res://maps/museum/scenes/museum_heist.tscn"
const REGION_PATH := "NavigationRegion3D"


func _ready() -> void:
	_bake.call_deferred()


func _bake() -> void:
	var level := (load(LEVEL_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(level)
	var region := level.get_node(REGION_PATH) as NavigationRegion3D
	var nav_mesh := region.navigation_mesh.duplicate(true) as NavigationMesh
	nav_mesh.clear_polygons()
	nav_mesh.vertices = PackedVector3Array()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.geometry_source_group_name = &"museum_navmesh_sources"
	nav_mesh.filter_baking_aabb = AABB(Vector3(-20, -0.25, -15), Vector3(40, 0.65, 30))

	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, source, level)
	print("Parsed source geometry: %d vertices; bounds %s" % [
		source.get_vertices().size(), source.get_bounds()])
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source)

	var polygons := nav_mesh.get_polygon_count()
	if polygons == 0:
		push_error("Bake produced an empty navigation mesh.")
		level.free()
		source = null
		nav_mesh = null
		get_tree().quit(1)
		return
	var navmesh_path := region.navigation_mesh.resource_path
	var error := ResourceSaver.save(nav_mesh, navmesh_path)
	if error != OK:
		push_error("Could not save %s (error %d)." % [navmesh_path, error])
		level.free()
		source = null
		nav_mesh = null
		get_tree().quit(1)
		return
	print("Baked %d polygons, %d vertices -> %s" % [
		polygons, nav_mesh.get_vertices().size(), navmesh_path])
	level.free()
	source = null
	nav_mesh = null
	await get_tree().process_frame
	get_tree().quit(0)
