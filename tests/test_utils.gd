extends RefCounted

## Helpers shared by the test files.


## Adds `level` under `host` and waits until the navigation map has synced it.
## Several tests load copies of the same level into the same navigation map,
## so "the map has data" is not enough: the previous copy's data may still be
## there, and the map is briefly empty while it rebuilds. This waits for two
## new map iterations (removal of the old copy, then this one), then for
## navigation to answer near `probe_point`.
static func add_level_and_wait_for_navigation(host: Node, level: Node3D, probe_point: Vector3) -> bool:
	var map := host.get_viewport().world_3d.navigation_map
	var before := NavigationServer3D.map_get_iteration_id(map)
	host.add_child(level)
	for i in 180:
		await host.get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) < before + 1:
			continue
		var closest := NavigationServer3D.map_get_closest_point(map, probe_point)
		if closest != Vector3.ZERO and Vector2(closest.x - probe_point.x, closest.z - probe_point.z).length() < 1.0:
			return true
	return false
