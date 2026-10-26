extends SceneTree

## Development tool: rebakes the Expanded Library's navmesh,
##   res://maps/library/resources/expanded_library_navmesh.tres,
## from the level's NavigationRegion3D and the expansion's Geometry (both in
## the group expanded_navigation_source), with the existing bake settings
## (static colliders on layer 1, agent height 1.75 m, region min size 8).
## The navmesh is set to bake from that group, so NavigationRegion3D's own
## bake (and the tests' in-memory rebakes) include the expansion too.
##   godot --headless --path . --script res://maps/library/tools/expansion/bake_navmesh.gd
## Run after maps/library/tools/expansion/build_expansion.gd or after any change to
## either part's geometry. Exits with 0 on success.

const Layout := preload("res://maps/library/tools/expansion/expansion_layout.gd")
const SCENE := "res://maps/library/scenes/expanded_library.tscn"
const NAVMESH := "res://maps/library/resources/expanded_library_navmesh.tres"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var level := (load(SCENE) as PackedScene).instantiate()
	# Only static colliders are baked: the actors (guards, player) and the
	# level's systems are not needed, and must not start running.
	for n in ["Guards", "Player", "GameFlow", "GameMenus", "StealthDirector", "AudioDirector", "NoiseSystem", "ObjectiveHud", "StealthHud", "DetectionDebugHud"]:
		var node := level.get_node_or_null(n)
		if node:
			level.remove_child(node)
			node.free()
	level.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(level)
	await process_frame
	var region := level.get_node("NavigationRegion3D") as NavigationRegion3D
	var sources := get_nodes_in_group(Layout.NAV_GROUP)
	if sources.size() != 2 or not region.is_in_group(Layout.NAV_GROUP) or not level.has_node("Expansion/Geometry"):
		push_error("Expected the NavigationRegion3D and Expansion/Geometry in %s, found %s." % [Layout.NAV_GROUP, sources])
		quit(1)
		return
	var nav := region.navigation_mesh
	var before := nav.get_polygon_count()
	nav.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav.geometry_source_group_name = Layout.NAV_GROUP
	region.bake_navigation_mesh(false)
	var err := ResourceSaver.save(nav, NAVMESH)
	print("Baked %s from %s: %d polygons (was %d), %d vertices; saved: %s" % [NAVMESH, Layout.NAV_GROUP, nav.get_polygon_count(), before,
		nav.get_vertices().size(), "ok" if err == OK else "error %d" % err])
	level.queue_free()
	await process_frame
	quit(0 if err == OK and nav.get_polygon_count() > 0 else 1)
