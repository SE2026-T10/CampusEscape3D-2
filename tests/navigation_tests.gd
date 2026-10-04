extends RefCounted

## Phase 3 library layout and navigation tests. Called from tests/test_scene.gd.
##
## Floor and obstacle footprints are read from the level's visible meshes
## (not its collision), so a prop that lost its collision still counts as an
## obstacle. The tests keep working as the layout changes. They check
## the requirements rather than exact polygon counts.

const LIBRARY_SCENE := "res://scenes/level/library_graybox.tscn"
const PROBE_SCENE := "res://scenes/npc/navigation_probe.tscn"
const REGION := "NavigationRegion3D"
const AREAS := ["Entrance", "MainRoom", "ReadingArea", "MainStacks", "HallwayWest",
		"RestrictedStacks", "BackCorridor", "HallwayEast", "ExitArea"]
## Navigation must never be baked above this height (table tops are 0.75 m, shelves 2.2 m).
const MAX_NAV_HEIGHT := 0.5
## Height of the line-of-sight checks along paths: above the floor, below table tops.
const RAY_HEIGHT := 0.5
## Grid spacing for the coverage check.
const SAMPLE_STEP := 1.0

var failures: Array[String] = []
var _host: Node
var _floors: Array[Rect2] = []      # walkable floor footprints (x, z)
var _obstacles: Array[AABB] = []    # walls and props


func run(host: Node) -> Array[String]:
	_host = host
	var level: Node3D = (load(LIBRARY_SCENE) as PackedScene).instantiate()
	# The level's own probe walks a route; tests drive their own probe instead.
	var level_probe := level.get_node_or_null("NavigationProbe")
	if level_probe:
		level.remove_child(level_probe)
		level_probe.free()
	_host.add_child(level)
	var region := level.get_node_or_null(REGION) as NavigationRegion3D
	_expect(region != null and region.navigation_mesh != null, "Level needs a NavigationRegion3D with a NavigationMesh.")
	if region == null or region.navigation_mesh == null:
		level.queue_free()
		return failures

	_check_layout(level)
	_collect_geometry(region)
	_check_navmesh_saved_and_current(region)
	_check_navmesh_inside_floors(region.navigation_mesh)
	# The navigation map picks up the region on the next physics frames.
	await _physics_frames(3)
	var map := region.get_navigation_map()
	_check_coverage(map)
	_check_outside_points_snap_inside(map)
	_check_paths_between_areas(level, map)
	_check_level_sealed(level)
	await _check_agent_walks_to_exit(level)

	level.queue_free()
	await _physics_frames(1)
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[navigation] " + message)


# --- Layout ------------------------------------------------------------------

func _check_layout(level: Node) -> void:
	for area in AREAS:
		var node := level.get_node_or_null("%s/Areas/%s" % [REGION, area])
		_expect(node != null, "Missing area '%s'." % area)
		if node:
			_expect(node.get_node_or_null("NavPoint") is Marker3D, "Area '%s' needs a NavPoint marker." % area)
	var debug := level.get_node_or_null("NavigationDebug")
	_expect(debug != null, "Level needs the NavigationDebug overlay.")
	if debug:
		var region := level.get_node(REGION) as NavigationRegion3D
		_expect(debug.region == region, "NavigationDebug must point at the NavigationRegion3D.")
		_expect(debug.drawn_polygon_count == region.navigation_mesh.get_polygon_count(),
			"NavigationDebug draws %d polygons, navmesh has %d." % [debug.drawn_polygon_count, region.navigation_mesh.get_polygon_count()])


func _collect_geometry(region: NavigationRegion3D) -> void:
	for body in region.find_children("*", "StaticBody3D", true, false):
		var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null:
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		if String(body.name).begins_with("Floor"):
			_floors.append(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))
		else:
			_obstacles.append(box)
	_expect(_floors.size() >= AREAS.size() - 2, "Expected a floor in every room, found %d." % _floors.size())


# --- Baked navigation mesh ---------------------------------------------------

func _check_navmesh_saved_and_current(region: NavigationRegion3D) -> void:
	var saved := region.navigation_mesh
	_expect(saved.resource_path == "res://scenes/level/library_navmesh.tres",
		"The navigation mesh should be saved in its own file (library_navmesh.tres).")
	_expect(saved.get_polygon_count() > 0, "The saved navigation mesh is empty. Bake it.")
	_expect(saved.geometry_parsed_geometry_type == NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS,
		"Navigation should be baked from static colliders only.")
	_expect(is_equal_approx(saved.cell_size, NavigationServer3D.map_get_cell_size(region.get_navigation_map())),
		"Navigation mesh cell size must match the navigation map cell size.")

	# Rebake in memory from the current level and compare with the saved file.
	var fresh := saved.duplicate() as NavigationMesh
	fresh.clear_polygons()
	fresh.vertices = PackedVector3Array()
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(fresh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(fresh, source)
	var saved_area := _nav_area(saved)
	var fresh_area := _nav_area(fresh)
	print("  [navigation] saved navmesh: %d polygons, %.1f m²; fresh bake: %d polygons, %.1f m²" % [
		saved.get_polygon_count(), saved_area, fresh.get_polygon_count(), fresh_area])
	_expect(absf(saved_area - fresh_area) <= 0.01 * maxf(fresh_area, 1.0),
		"The saved navigation mesh is out of date (%.1f m² saved vs %.1f m² from the current level). " % [saved_area, fresh_area]
		+ "Rebake: select NavigationRegion3D → Bake NavigationMesh, or run tools/bake_navigation.gd.")


func _check_navmesh_inside_floors(nav_mesh: NavigationMesh) -> void:
	var outside := 0
	var too_high := 0
	for v in nav_mesh.get_vertices():
		if v.y > MAX_NAV_HEIGHT:
			too_high += 1
		if not _on_floor(Vector2(v.x, v.z), 0.01):
			outside += 1
	_expect(too_high == 0, "%d navmesh vertices are above %.1f m (baked onto furniture?)." % [too_high, MAX_NAV_HEIGHT])
	_expect(outside == 0, "%d navmesh vertices are outside the rooms' floors." % outside)


func _nav_area(nav_mesh: NavigationMesh) -> float:
	var area := 0.0
	var v := nav_mesh.get_vertices()
	for i in nav_mesh.get_polygon_count():
		var p := nav_mesh.get_polygon(i)
		for j in range(1, p.size() - 1):
			var a := Vector2(v[p[0]].x, v[p[0]].z)
			var b := Vector2(v[p[j]].x, v[p[j]].z)
			var c := Vector2(v[p[j + 1]].x, v[p[j + 1]].z)
			area += absf((b - a).cross(c - a)) / 2.0
	return area


# --- Navigation map queries --------------------------------------------------

## Every floor point well clear of walls and furniture must be walkable;
## every point inside a wall or piece of furniture must not be.
func _check_coverage(map: RID) -> void:
	var clear_margin := 0.5 + 0.35  # agent radius + rasterisation slack
	var missing := 0
	var blocked_but_walkable := 0
	var blocked_samples := 0
	var samples := 0
	for floor in _floors:
		var x := floor.position.x + SAMPLE_STEP / 2.0
		while x < floor.end.x:
			var z := floor.position.y + SAMPLE_STEP / 2.0
			while z < floor.end.y:
				var point := Vector3(x, 0.0, z)
				var distance := _horizontal_distance_to_navmesh(map, point)
				var obstacle_distance := _distance_to_obstacles(point)
				if obstacle_distance > clear_margin and _on_floor(Vector2(x, z), -clear_margin):
					samples += 1
					if distance > 0.05:
						missing += 1
				elif obstacle_distance == 0.0:
					blocked_samples += 1
					if distance < 0.2:
						blocked_but_walkable += 1
				z += SAMPLE_STEP
			x += SAMPLE_STEP
	print("  [navigation] coverage: %d open floor samples (%d missing), %d samples inside obstacles (%d walkable)" % [
		samples, missing, blocked_samples, blocked_but_walkable])
	_expect(samples > 200, "Coverage check found too few open floor samples (%d)." % samples)
	_expect(blocked_samples > 20, "Coverage check found too few samples inside obstacles (%d)." % blocked_samples)
	_expect(missing == 0, "%d open floor points are not covered by navigation." % missing)
	_expect(blocked_but_walkable == 0, "%d points inside walls or furniture are walkable." % blocked_but_walkable)


func _check_outside_points_snap_inside(map: RID) -> void:
	# Points outside the building and in the gaps between rooms.
	for point in [Vector3(40, 0, 40), Vector3(-30, 0, 0), Vector3(6, 0, -40), Vector3(5, 0, -15), Vector3(16, 0, -10)]:
		var closest := NavigationServer3D.map_get_closest_point(map, point)
		_expect(_on_floor(Vector2(closest.x, closest.z), 0.01),
			"Closest navigation point to %s is outside the rooms (%s)." % [point, closest])


func _check_paths_between_areas(level: Node, map: RID) -> void:
	var space := (level as Node3D).get_world_3d().direct_space_state
	var start := _nav_point(level, "Entrance")
	var total := 0.0
	for area in AREAS:
		var target := _nav_point(level, area)
		var path := NavigationServer3D.map_get_path(map, start, target, true)
		_expect(path.size() >= 2 or area == "Entrance", "No path from Entrance to %s." % area)
		if path.size() < 2:
			continue
		_expect(_horizontal(path[path.size() - 1]).distance_to(_horizontal(target)) < 0.5,
			"Path from Entrance to %s stops short of the target." % area)
		for i in path.size() - 1:
			var hit := _ray_hit(space, path[i], path[i + 1])
			_expect(hit.is_empty(), "Path from Entrance to %s passes through %s." % [area, hit.get("collider", "")])
		total += _path_length(path)

	# A wall separates the main room from the east hallway: the direct line is
	# blocked, so the path has to detour through the doorway.
	var a := _nav_point(level, "MainRoom")
	var b := _nav_point(level, "HallwayEast")
	_expect(not _ray_hit(space, a, b).is_empty(), "Expected a wall between MainRoom and HallwayEast.")
	var detour := _path_length(NavigationServer3D.map_get_path(map, a, b, true))
	_expect(detour > a.distance_to(b) + 2.0, "Path MainRoom→HallwayEast should detour around walls.")
	print("  [navigation] paths from Entrance to all %d areas found; MainRoom→HallwayEast %.1f m (straight %.1f m)" % [
		AREAS.size(), detour, a.distance_to(b)])


## Every floor edge must be closed by a solid collider (checked with physics
## rays, so a wall that lost its collision is caught) unless another room's
## floor continues on the other side (a doorway). Keeps the player inside too.
func _check_level_sealed(level: Node) -> void:
	var space := (level as Node3D).get_world_3d().direct_space_state
	var leaks: Array[String] = []
	var checked := 0
	for floor in _floors:
		var corners := [floor.position, Vector2(floor.end.x, floor.position.y), floor.end, Vector2(floor.position.x, floor.end.y)]
		for side in 4:
			var a: Vector2 = corners[side]
			var b: Vector2 = corners[(side + 1) % 4]
			var along := (b - a).normalized()
			var outward := Vector2(along.y, -along.x)  # corners run clockwise in x/z, so this points out
			var t := 0.25
			while t < a.distance_to(b) - 0.2:
				var edge := a + along * t
				t += 0.5
				if _on_floor(edge + outward * 0.4, 0.0):
					continue  # another room continues here: doorway or seam
				checked += 1
				var from := edge - outward * 0.4
				var to := edge + outward * 0.4
				var query := PhysicsRayQueryParameters3D.create(Vector3(from.x, 1.0, from.y), Vector3(to.x, 1.0, to.y), 1)
				if space.intersect_ray(query).is_empty():
					leaks.append("(%.2f, %.2f)" % [edge.x, edge.y])
	print("  [navigation] sealed: %d floor-edge points checked, %d open" % [checked, leaks.size()])
	_expect(checked > 100, "Seal check found too few floor edges (%d)." % checked)
	_expect(leaks.is_empty(), "%d floor edges have no wall, so the player could walk off the floor, e.g. at %s." % [
		leaks.size(), ", ".join(leaks.slice(0, 3))])


## A NavigationAgent3D-driven probe must walk from the entrance to the exit
## without leaving the rooms.
func _check_agent_walks_to_exit(level: Node) -> void:
	var probe: NavigationProbe = (load(PROBE_SCENE) as PackedScene).instantiate()
	probe.autostart = false
	probe.speed = 6.0
	level.add_child(probe)
	var start := _nav_point(level, "Entrance")
	var exit := _nav_point(level, "ExitArea")
	probe.global_position = start + Vector3(0, 0.05, 0)
	await _physics_frames(2)
	probe.go_to(exit)

	var previous_scale := Engine.time_scale
	Engine.time_scale = 2.0  # Faster test; steps stay small (0.2 m) relative to 0.3 m walls.
	var left_rooms := 0
	var frames := 0
	var travelled := 0.0
	var last := probe.global_position
	while probe.is_moving() and frames < 900:
		await _host.get_tree().physics_frame
		frames += 1
		travelled += _horizontal(probe.global_position).distance_to(_horizontal(last))
		last = probe.global_position
		if not _on_floor(_horizontal(probe.global_position), 0.0) or probe.global_position.y < -0.5:
			left_rooms += 1
	Engine.time_scale = previous_scale

	var remaining := _horizontal(probe.global_position).distance_to(_horizontal(exit))
	print("  [navigation] probe walked Entrance→Exit: %.1f m in %d frames, %.2f m from target" % [travelled, frames, remaining])
	_expect(not probe.is_moving() and remaining < 1.0,
		"NavigationAgent3D probe did not reach the exit (%.2f m away after %d frames)." % [remaining, frames])
	_expect(left_rooms == 0, "Probe left the playable floor on %d frames." % left_rooms)
	probe.queue_free()


# --- Helpers -----------------------------------------------------------------

func _on_floor(point: Vector2, margin: float) -> bool:
	for floor in _floors:
		if floor.grow(margin).has_point(point):
			return true
	return false


func _distance_to_obstacles(point: Vector3) -> float:
	var best := INF
	for box in _obstacles:
		var dx := maxf(maxf(box.position.x - point.x, 0.0), point.x - box.end.x)
		var dz := maxf(maxf(box.position.z - point.z, 0.0), point.z - box.end.z)
		best = minf(best, Vector2(dx, dz).length())
	return best


func _horizontal_distance_to_navmesh(map: RID, point: Vector3) -> float:
	var closest := NavigationServer3D.map_get_closest_point(map, point)
	return _horizontal(closest).distance_to(_horizontal(point))


func _ray_hit(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(from.x, RAY_HEIGHT, from.z), Vector3(to.x, RAY_HEIGHT, to.z), 1)
	return space.intersect_ray(query)


func _nav_point(level: Node, area: String) -> Vector3:
	return (level.get_node("%s/Areas/%s/NavPoint" % [REGION, area]) as Node3D).global_position


func _path_length(path: PackedVector3Array) -> float:
	var length := 0.0
	for i in path.size() - 1:
		length += path[i].distance_to(path[i + 1])
	return length


func _horizontal(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _physics_frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
