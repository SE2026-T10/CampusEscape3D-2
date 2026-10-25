extends SceneTree

## Development tool: compares the Expanded Library's navmesh with an older one
## inside the original building (x -36…36, z -28…34, above the basement), to
## show that the expansion keeps every walkable place the level had and adds
## only the new doorways. Samples points on each navmesh (vertices and points
## inside each triangle) and measures their distance to the other navmesh.
##   git show 7d73492:maps/library/resources/expanded_library_navmesh.tres > /tmp/old_nav.tres
##   godot --headless --path . --script res://maps/library/tools/expansion/compare_navmesh.gd -- --old=/tmp/old_nav.tres
## Prints the counts; points of the new navmesh not in the old one are grouped
## by the nearest cut doorway (within 2.5 m) or listed as "elsewhere".

const X := preload("res://maps/library/tools/expansion/expansion_layout.gd")
const NEW := "res://maps/library/resources/expanded_library_navmesh.tres"
const TOLERANCE := 0.3


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var old_path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--old="):
			old_path = a.trim_prefix("--old=")
	if old_path == "":
		push_error("Pass --old=<navmesh .tres>")
		quit(1)
		return
	var old := ResourceLoader.load(old_path) as NavigationMesh
	var new := load(NEW) as NavigationMesh
	var maps := []
	var regions := []
	for nav in [old, new]:
		var m := NavigationServer3D.map_create()
		NavigationServer3D.map_set_cell_size(m, nav.cell_size)
		NavigationServer3D.map_set_cell_height(m, nav.cell_height)
		var r := NavigationServer3D.region_create()
		NavigationServer3D.region_set_navigation_mesh(r, nav)
		NavigationServer3D.region_set_map(r, m)
		NavigationServer3D.map_set_active(m, true)
		maps.append(m)
		regions.append(r)
	for i in 10:
		await physics_frame
	var lost := _far(_samples(old), maps[1])
	var added := _far(_samples(new), maps[0])
	var groups := {}
	for q in added:
		var where := "elsewhere"
		for h in X.DOOR_HEADERS:
			if Vector2(q.x - h.x, q.z - h.z).length() < 2.5:
				where = h.name
		groups[where] = groups.get(where, 0) + 1
	print("Old navmesh %s: %d polygons; new: %d polygons" % [old_path.get_file(), old.get_polygon_count(), new.get_polygon_count()])
	print("Inside the original building: %d old places not in the new navmesh (> %.1f m away)" % [lost.size(), TOLERANCE])
	print("New places not in the old navmesh: %d, by doorway: %s" % [added.size(), groups])
	for q in lost:
		print("  lost: %s" % q)
	for q in added:
		var near_door := false
		for h in X.DOOR_HEADERS:
			if Vector2(q.x - h.x, q.z - h.z).length() < 2.5:
				near_door = true
		if not near_door:
			print("  added elsewhere: %s" % q)
	for r in regions:
		NavigationServer3D.free_rid(r)
	for m in maps:
		NavigationServer3D.free_rid(m)
	quit(0 if lost.is_empty() and not groups.has("elsewhere") else 1)


func _samples(nav: NavigationMesh) -> Array:
	var v := nav.get_vertices()
	var out := []
	for i in nav.get_polygon_count():
		var p := nav.get_polygon(i)
		for t in range(1, p.size() - 1):
			var a: Vector3 = v[p[0]]
			var b: Vector3 = v[p[t]]
			var c: Vector3 = v[p[t + 1]]
			for q in [a, b, c, (a + b + c) / 3.0, a + (b - a) * 0.6 + (c - a) * 0.2, a + (b - a) * 0.2 + (c - a) * 0.6, a + (b - a) * 0.2 + (c - a) * 0.2]:
				if q.y > -0.6 and q.x > -36.2 and q.x < 36.2 and q.z > -28.2 and q.z < 34.2:
					out.append(q)
	return out


func _far(points: Array, map: RID) -> Array:
	var out := []
	for q in points:
		if NavigationServer3D.map_get_closest_point(map, q).distance_to(q) > TOLERANCE:
			out.append(q)
	return out
