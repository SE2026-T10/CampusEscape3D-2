extends SceneTree

## Rebake after changing the museum's floor, walls or cover.
## godot --headless --path . --script res://maps/museum/tools/bake_navigation.gd

const SCENE := "res://maps/museum/scenes/museum.tscn"
const NAVMESH := "res://maps/museum/resources/museum_navigation.tres"


func _initialize() -> void:
	_bake.call_deferred()


func _bake() -> void:
	var level := (load(SCENE) as PackedScene).instantiate()
	# Bake only the region's static geometry; actors and HUD must not run.
	for child in level.get_children():
		if not child is NavigationRegion3D:
			level.remove_child(child)
			child.free()
	level.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(level)
	await process_frame
	await physics_frame
	var region := level.get_node("NavigationRegion3D") as NavigationRegion3D
	region.bake_navigation_mesh(false)
	var count := region.navigation_mesh.get_polygon_count()
	if count == 0:
		push_error("Museum navigation bake produced no polygons.")
		quit(1)
		return
	var error := ResourceSaver.save(region.navigation_mesh, NAVMESH)
	if error != OK:
		push_error("Could not save museum navigation mesh: %d" % error)
		quit(1)
		return
	print("Museum navigation baked: %d polygons -> %s" % [count, NAVMESH])
	quit(0)
