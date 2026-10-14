extends SceneTree

## Development tool: rebakes the library navigation mesh and saves it to
## res://scenes/level/library_navmesh.tres. Run from the project folder:
##   godot --headless --path . --script res://tools/bake_navigation.gd
## Exits with code 0 on success and 1 on failure.

const LEVEL_SCENE := "res://scenes/level/library_graybox.tscn"
const REGION_PATH := "NavigationRegion3D"


func _init() -> void:
	_bake.call_deferred()


func _bake() -> void:
	var level := (load(LEVEL_SCENE) as PackedScene).instantiate()
	root.add_child(level)
	var region := level.get_node(REGION_PATH) as NavigationRegion3D
	var nav_mesh := region.navigation_mesh
	region.bake_navigation_mesh(false)  # false = bake on this thread, so it is finished on return.
	var polygons := nav_mesh.get_polygon_count()
	if polygons == 0:
		push_error("Bake produced an empty navigation mesh.")
		quit(1)
		return
	var error := ResourceSaver.save(nav_mesh, nav_mesh.resource_path)
	if error != OK:
		push_error("Could not save %s (error %d)." % [nav_mesh.resource_path, error])
		quit(1)
		return
	print("Baked %d polygons, %d vertices -> %s" % [polygons, nav_mesh.get_vertices().size(), nav_mesh.resource_path])
	quit(0)
