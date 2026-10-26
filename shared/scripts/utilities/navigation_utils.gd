class_name NavigationUtils
extends RefCounted

## Small shared helpers for navigation.


## Waits until the navigation map around `node` is usable, then returns true.
## Right after a level loads, the first map sync is empty: closest-point and
## path queries return nothing for a few physics frames. Starting to move
## before then gives an empty path that looks like "already arrived".
## Returns false (with a warning) if no navigation appears near the node.
static func wait_for_navigation(node: Node3D, max_frames := 120) -> bool:
	var map := node.get_world_3d().navigation_map
	for i in max_frames:
		# An empty map answers every closest-point query with (0, 0, 0), so also
		# require at least one region; otherwise an NPC at the origin looks "ready".
		if NavigationServer3D.map_get_iteration_id(map) > 0 and not NavigationServer3D.map_get_regions(map).is_empty():
			var closest := NavigationServer3D.map_get_closest_point(map, node.global_position)
			if Vector2(closest.x - node.global_position.x, closest.z - node.global_position.z).length() < 2.0:
				return true
		await node.get_tree().physics_frame
	push_warning("%s: no navigation mesh found nearby after %d frames." % [node.name, max_frames])
	return false
