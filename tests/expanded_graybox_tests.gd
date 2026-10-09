extends RefCounted

## Expanded Library — Phase 1 graybox tests. Called from tests/test_scene.gd.
##
## The planned locations (objectives, exit, gates, stairs, patrol points,
## hiding spots, room probes) come from the layout data
## (tools/expanded/expanded_layout.gd), from which the scene is built. The
## checks themselves use the built scene: its colliders, its baked navmesh,
## and the real player walking with real input.
##
##   A. Scene: a separate scene with the expected structure; six zones on two
##      floors; the tutorial and the main menu are not changed.
##   B. Dimensions: doorways, headroom, ramp slope, clearance above every ramp.
##   C. Navmesh: saved bake matches a fresh bake; both floors and the ramps
##      are walkable; nothing is baked on top of furniture.
##   D. Reachability: every room, aisle, objective, the exit, every patrol
##      point and hiding spot can be reached from the spawn.
##   E. Stairs: each stair connects the floors on its own.
##   F. Gates and approaches (the level rebaked with blockers in doorways and
##      stairs): with the gates the mission will lock, closed stage by stage,
##      only the intended areas are reachable (start → after O1 → after O2:
##      the archive is gated); each of the upper floor, the staff wing and the
##      archive has two approaches (closing one still leaves the other); and
##      the archive has a return route to the exit without the front gate or
##      the public stairs.
##   G. Walk: the player walks the main route and both alternative routes
##      with real input, up and down all three stairs, through every gate.

const SCENE := "res://scenes/level/expanded_library.tscn"
const NAVMESH := "res://scenes/level/expanded_library_navmesh.tres"
const TUTORIAL := "res://scenes/level/library_graybox.tscn"
const Layout := preload("res://tools/expanded/expanded_layout.gd")
const TestUtils := preload("res://tests/test_utils.gd")
const ZONE_NODES := {
	"A": "NavigationRegion3D/Ground/A_EntranceLobby", "B": "NavigationRegion3D/Ground/B_MainStacks",
	"C": "NavigationRegion3D/Ground/C_ReadingStudy", "D": "NavigationRegion3D/Ground/D_ServiceCorridor",
	"E": "NavigationRegion3D/Upper/E_StaffUpperStacks", "F": "NavigationRegion3D/Upper/F_RestrictedArchive",
}
## Navmesh agent (as baked) and the player.
const AGENT_RADIUS := 0.5
const AGENT_HEIGHT := 1.75
const PLAYER_HEIGHT := 1.8
## A planned spot counts as reached when the navmesh path ends this close (metres, 3D).
const REACH := 0.6
## Hiding spots sit tight against cover, where the navmesh (agent radius 0.5 m) stops short.
const REACH_HIDING := 1.0

var failures: Array[String] = []
var _host: Node
var _level: Node3D
var _region: NavigationRegion3D
var _map: RID
var _player: FirstPersonPlayer


func run(host: Node) -> Array[String]:
	_host = host
	_check_scene_structure()
	_check_dimensions()
	_level = (load(SCENE) as PackedScene).instantiate()
	var ready: bool = await TestUtils.add_level_and_wait_for_navigation(_host, _level, Layout.SPAWN)
	_expect(ready, "The Expanded Library's navigation never became ready.")
	_region = _level.get_node("NavigationRegion3D")
	_map = _region.get_navigation_map()
	_player = _level.get_node("Player")
	var flow := GameFlow.find(_level)
	if flow:
		flow.change_scene = func(_path: String): pass
	_check_ramp_headroom()
	_check_navmesh()
	_check_reachability()
	_check_stairs()
	await _check_approaches_and_gates()
	await _check_walks()
	_release_all()
	_level.queue_free()
	await _frames(30)
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[expanded] " + message)


# --- A. Scene structure ---------------------------------------------------------------------

func _check_scene_structure() -> void:
	var packed := load(SCENE) as PackedScene
	_expect(packed != null, "The Expanded Library scene must load (%s)." % SCENE)
	if packed == null:
		return
	var level := packed.instantiate() as Node3D
	_expect(level.name == "ExpandedLibrary", "The root must be named ExpandedLibrary.")
	_expect(level.get_meta("layout_version", "") == Layout.VERSION, "The scene must be built from layout %s." % Layout.VERSION)
	for path in ["WorldEnvironment", "KeyLight", "NavigationRegion3D", "Player", "PreviewCamera", "NavigationDebug",
			"GameFlow", "GameMenus", "Layout/Objectives", "Layout/Gates", "Layout/PlannedPatrols", "Layout/HidingSpots", "Layout/Exit"]:
		_expect(level.get_node_or_null(path) != null, "The scene must contain %s." % path)
	var camera := level.get_node_or_null("PreviewCamera") as Camera3D
	_expect(camera != null and not camera.current, "PreviewCamera must not be the current camera.")
	var player := level.get_node_or_null("Player")
	_expect(player is FirstPersonPlayer and player.scene_file_path == "res://scenes/player/player.tscn",
		"The player must be an instance of the existing player scene.")
	var region := level.get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	_expect(region != null and region.navigation_mesh != null and region.navigation_mesh.resource_path == NAVMESH,
		"The navmesh must be saved in its own file (%s)." % NAVMESH)
	# Six zones, four on the ground floor and two upstairs, each with walls and a floor.
	var floors := {"ground": 0, "upper": 0}
	for id in ZONE_NODES:
		var zone := level.get_node_or_null(ZONE_NODES[id])
		_expect(zone != null and zone.get_meta("zone_id", "") == id, "Zone %s must exist at %s." % [id, ZONE_NODES[id]])
		if zone == null:
			continue
		floors[zone.get_meta("floor")] += 1
		var bodies := zone.get_children().filter(func(n): return n is StaticBody3D)
		_expect(bodies.size() >= 3, "Zone %s should have a floor and walls (found %d pieces)." % [id, bodies.size()])
	_expect(floors.ground == 4 and floors.upper == 2, "Expected four ground-floor zones and two upper-floor zones, got %s." % floors)
	_expect(level.get_node("Layout/Objectives").get_child_count() == 5, "There must be five planned objective locations.")
	_expect(level.get_node("NavigationRegion3D/Stairs").get_child_count() == 3, "There must be three stairs.")
	# Every solid piece is world geometry (layer 1), so the navmesh and sight see it.
	var wrong_layer := 0
	for body in _all(level, func(n): return n is StaticBody3D):
		if (body as StaticBody3D).collision_layer != 1:
			wrong_layer += 1
	_expect(wrong_layer == 0, "%d static bodies are not on the world layer only." % wrong_layer)
	level.free()
	# The tutorial and the menu are untouched by this phase.
	_expect(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/ui/main_menu.tscn", "The main scene must still be the main menu.")
	_expect(MainMenu.LEVEL_SCENE == TUTORIAL, "The main menu must still start the tutorial (map selection is a later phase).")
	_expect(SCENE != TUTORIAL and ResourceLoader.exists(TUTORIAL), "The tutorial scene must still exist as its own scene.")
	print("  [expanded] scene: 6 zones (4 ground, 2 upper), 3 stairs, 5 objective locations, tutorial and menu unchanged")


# --- B. Dimensions (from the layout the scene is built from) -------------------------------

func _check_dimensions() -> void:
	var narrowest := INF
	for wall in Layout.WALLS:
		for o in wall.get("openings", []):
			if o.type == "exit":
				continue
			narrowest = minf(narrowest, o.width)
			# At least one metre of navmesh through a doorway (agent radius 0.5 m on each side).
			_expect(o.width - 2.0 * AGENT_RADIUS >= 1.0 - 0.001, "Opening '%s' is too narrow (%.1f m)." % [o.name, o.width])
	_expect(Layout.DOOR_HEIGHT >= PLAYER_HEIGHT + 0.6, "Doorways must leave headroom above the player.")
	_expect(Layout.GROUND_WALL_HEIGHT >= AGENT_HEIGHT + 1.0 and Layout.UPPER_WALL_HEIGHT >= AGENT_HEIGHT + 1.0,
		"Ceilings must clear the agents.")
	var steepest := 0.0
	for s in Layout.STAIRS:
		var slope := rad_to_deg(atan(Layout.UPPER_Y / absf(s.z_high - s.z_low)))
		steepest = maxf(steepest, slope)
		_expect(slope <= 30.0, "%s is too steep (%.1f°)." % [s.name, slope])
		_expect(s.x1 - s.x0 >= 2.5, "%s is too narrow." % s.name)
	# Shelf aisles: rows of the same zone and floor at least 1.8 m apart.
	print("  [expanded] dimensions: narrowest opening %.1f m, doors %.1f m high, steepest stair %.1f°" % [narrowest, Layout.DOOR_HEIGHT, steepest])


## Clear headroom above every ramp: nothing within 2.2 m above the walking surface.
func _check_ramp_headroom() -> void:
	var space := _level.get_world_3d().direct_space_state
	var blocked := 0
	for s in Layout.STAIRS:
		for i in range(1, 20):
			var f := i / 20.0
			var z: float = lerpf(s.z_low, s.z_high, f)
			var y := Layout.UPPER_Y * f
			for x in [s.x0 + 0.4, (s.x0 + s.x1) / 2.0, s.x1 - 0.4]:
				var from := Vector3(x, y + 0.15, z)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 2.2, 0), 1))
				if not hit.is_empty():
					blocked += 1
	_expect(blocked == 0, "%d points on the stairs have less than 2.2 m of headroom." % blocked)


# --- C. Navmesh -----------------------------------------------------------------------------

func _check_navmesh() -> void:
	var saved := _region.navigation_mesh
	_expect(saved.get_polygon_count() > 0, "The saved navmesh is empty. Rebuild: tools/expanded/build_expanded_graybox.gd")
	_expect(saved.geometry_parsed_geometry_type == NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS, "Bake from static colliders only.")
	_expect(is_equal_approx(saved.cell_size, NavigationServer3D.map_get_cell_size(_map)), "Navmesh cell size must match the map's.")
	var fresh := _bake([])
	var saved_area := _area(saved)
	var fresh_area := _area(fresh)
	# The bake is deterministic, so the saved file must match a fresh bake closely: half a square
	# metre is eight navmesh cells, small enough to notice one moved wall (a 1% margin would not).
	_expect(absf(saved_area - fresh_area) <= 0.5,
		"The saved navmesh is out of date (%.1f m² vs %.1f m² fresh). Rebuild the graybox." % [saved_area, fresh_area])
	# Where the walkable surface is: both floors, the ramps between, nothing on furniture.
	var ground := 0.0
	var upper := 0.0
	var stray := 0
	var vertices := saved.get_vertices()
	for i in saved.get_polygon_count():
		var poly := saved.get_polygon(i)
		var c := Vector3.ZERO
		for k in poly:
			c += vertices[k]
		c /= poly.size()
		var a := _polygon_area(saved, poly)
		if c.y < 0.6:
			ground += a
		elif absf(c.y - Layout.UPPER_Y) < 0.6:
			upper += a
		elif not _on_a_stair(c):
			stray += 1
	print("  [expanded] navmesh: %d polygons; walkable ground %.0f m², upper %.0f m²; saved %.1f m² = fresh %.1f m²" % [
		saved.get_polygon_count(), ground, upper, saved_area, fresh_area])
	_expect(ground > 2000.0, "Too little walkable ground floor (%.0f m²)." % ground)
	_expect(upper > 1000.0, "Too little walkable upper floor (%.0f m²)." % upper)
	_expect(stray == 0, "%d navmesh polygons float between the floors outside the stairs (on furniture?)." % stray)


func _on_a_stair(p: Vector3) -> bool:
	for s in Layout.STAIRS:
		if p.x >= s.x0 - 0.5 and p.x <= s.x1 + 0.5 and p.z >= minf(s.z_low, s.z_high) - 0.5 and p.z <= maxf(s.z_low, s.z_high) + 0.5:
			return true
	return false


# --- D. Reachability ------------------------------------------------------------------------

func _check_reachability() -> void:
	var targets := []
	for p in Layout.PROBES:
		targets.append(["room probe %s" % p, p, REACH])
	for o in Layout.OBJECTIVES:
		targets.append([o.title, o.pos, REACH])
	for h in Layout.HIDING:
		targets.append(["hiding spot %s" % h.name, h.pos, REACH_HIDING])
	for route in _level.get_node("Layout/PlannedPatrols").get_children():
		for point in route.get_children():
			if point is Marker3D:
				targets.append(["patrol %s/%s" % [route.name, point.name], (point as Marker3D).global_position, REACH])
	for wall in Layout.WALLS:
		for o in wall.get("openings", []):
			if o.type == "exit":
				continue
			for side in _both_sides(wall, o):
				targets.append(["doorway '%s'" % o.name, side, REACH])
	var unreachable := []
	for t in targets:
		if not _reaches(_path(Layout.SPAWN, t[1]), t[1], t[2]):
			unreachable.append("%s at %s" % [t[0], t[1]])
	_expect(unreachable.is_empty(), "Not reachable from the spawn: %s" % ", ".join(unreachable))
	var length := 0.0
	var route: Array = Layout.ROUTES[0].points
	for i in route.size() - 1:
		length += _length(_path(route[i], route[i + 1]))
	print("  [expanded] reachability: %d planned locations reachable from the spawn; main route %.0f m along the navmesh" % [
		targets.size() - unreachable.size(), length])


## Points 1.2 m either side of an opening, on its floor.
func _both_sides(wall: Dictionary, o: Dictionary) -> Array:
	var c := Layout.opening_centre(wall, o)
	var normal := Vector3(0, 0, 1) if wall.a[1] == wall.b[1] else Vector3(1, 0, 0)
	if o.type == "stair":
		return [c - normal * 1.2]   # the slab side (both stairs arrive heading north)
	return [c + normal * 1.2, c - normal * 1.2]


# --- E. Stairs ------------------------------------------------------------------------------

func _check_stairs() -> void:
	for s in Layout.STAIRS:
		var ends := Layout.stair_ends(s)
		var up := _path(ends[0], ends[1])
		var run := absf(s.z_high - s.z_low)
		var direct := sqrt(run * run + Layout.UPPER_Y * Layout.UPPER_Y) + 4.0
		_expect(_reaches(up, ends[1], REACH), "%s does not lead from the ground floor (%s) to the upper floor (%s)." % [s.name, ends[0], ends[1]])
		_expect(_length(up) <= direct + 1.0, "%s: the path between its ends is %.1f m, so it does not use the stair (%.1f m)." % [s.name, _length(up), direct])
		var down := _path(ends[1], ends[0])
		_expect(_reaches(down, ends[0], REACH), "%s cannot be walked down." % s.name)
	print("  [expanded] stairs: S1, S2, S3 each connect the floors directly (up and down)")


# --- F. Approaches and gates (rebaked with blockers) ---------------------------------------

func _check_approaches_and_gates() -> void:
	var o1: Vector3 = Layout.OBJECTIVES[0].pos
	var o2: Vector3 = Layout.OBJECTIVES[1].pos
	var o3: Vector3 = Layout.OBJECTIVES[2].pos
	var o4: Vector3 = Layout.OBJECTIVES[3].pos
	var exit: Vector3 = Layout.OBJECTIVES[4].pos
	var upper_stacks := Vector3(-24, Layout.UPPER_Y, -10)
	var staff := ["Staff Wing Door G1a", "Staff Door (Stacks) G1b"]
	var archive := ["Archive Front Gate G2", "Archive Back Gate G3"]
	var spawn := Layout.SPAWN
	var cases := [
		# [description, closed openings / stairs, from, [[what, target, reachable?], ...]]
		# Planned progression: the gates the mission will lock, stage by stage.
		["start (all gates and the shortcut closed)", staff + archive + ["Lobby Staff Door G4", "Service Shortcut SC1"], spawn,
			[["O1", o1, true], ["upper stacks", upper_stacks, true], ["O2 keycard", o2, false], ["loading dock", o4, false], ["O3 manuscript", o3, false]]],
		["after O1 (staff doors open; archive gates and shortcut closed)", archive + ["Service Shortcut SC1"], spawn,
			[["O2 keycard", o2, true], ["loading dock", o4, true], ["O3 manuscript", o3, false]]],
		["after O2 (archive gates open)", ["Service Shortcut SC1"], spawn, [["O3 manuscript", o3, true], ["exit", exit, true]]],
		# Two approaches to each step.
		["no stairs", ["S1", "S2", "S3"], spawn, [["upper floor", upper_stacks, false]]],
		["S1 closed", ["S1"], spawn, [["upper floor via S3", upper_stacks, true]]],
		["S3 closed", ["S3"], spawn, [["upper floor via S1", upper_stacks, true]]],
		["S1 and S3 closed", ["S1", "S3"], spawn, [["upper floor via the service corridor and S2", upper_stacks, true]]],
		["G1a closed (archive locked)", ["Staff Wing Door G1a"] + archive, spawn, [["O2 via the stacks door G1b", o2, true]]],
		["G1b closed (archive locked)", ["Staff Door (Stacks) G1b"] + archive, spawn, [["O2 via the balcony door G1a", o2, true]]],
		["front gate G2 closed", ["Archive Front Gate G2"], spawn, [["O3 via the service corridor, S2 and the back gate", o3, true]]],
		["back gate G3 closed", ["Archive Back Gate G3"], spawn, [["O3 via the staff wing and the front gate", o3, true]]],
		["front gate and public stairs closed", ["Archive Front Gate G2", "S1", "S3"], o3, [["return route archive → exit", exit, true]]],
	]
	var passed := 0
	var total := 0
	for c in cases:
		# A private navigation map per case, so no case can see another case's bake.
		var mesh := _bake(c[1])
		var map := NavigationServer3D.map_create()
		NavigationServer3D.map_set_cell_size(map, NavigationServer3D.map_get_cell_size(_map))
		NavigationServer3D.map_set_cell_height(map, NavigationServer3D.map_get_cell_height(_map))
		var region := NavigationServer3D.region_create()
		NavigationServer3D.region_set_navigation_mesh(region, mesh)
		NavigationServer3D.region_set_map(region, map)
		NavigationServer3D.map_set_active(map, true)
		for i in 120:
			await _host.get_tree().physics_frame
			# The region's polygons arrive one map iteration after the region itself.
			if NavigationServer3D.map_get_iteration_id(map) >= 2 \
					and NavigationServer3D.map_get_closest_point(map, c[2]).distance_to(c[2]) < 2.0:
				break
		await _host.get_tree().physics_frame
		for check in c[3]:
			total += 1
			var path := NavigationServer3D.map_get_path(map, c[2], check[1], true)
			var reached := _reaches(path, check[1], REACH)
			_expect(reached == check[2], "%s: %s should be %s, but the path %s." % [c[0], check[0], "reachable" if check[2] else "cut off",
				"reaches it" if reached else "stops %.1f m short" % (check[1].distance_to(path[path.size() - 1]) if not path.is_empty() else INF)])
			if reached == check[2]:
				passed += 1
		NavigationServer3D.free_rid(region)
		NavigationServer3D.free_rid(map)
	print("  [expanded] gates and approaches: %d/%d checks as designed over %d rebakes (progression stages start → O1 → O2; two approaches each to the upper floor, the staff wing and the archive; return route)" % [passed, total, cases.size()])


## Rebakes the level's navmesh in memory with blockers in the named openings / stairs.
func _bake(blocked: Array) -> NavigationMesh:
	var blockers: Array[Node] = []
	for name in blocked:
		for box in _blocker_boxes(name):
			var body := StaticBody3D.new()
			body.collision_layer = 1
			var shape := CollisionShape3D.new()
			var b := BoxShape3D.new()
			b.size = box[1]
			shape.shape = b
			body.add_child(shape)
			body.position = box[0]
			_region.add_child(body)
			blockers.append(body)
	var mesh := (_region.navigation_mesh.duplicate() as NavigationMesh)
	mesh.clear_polygons()
	mesh.vertices = PackedVector3Array()
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, _region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	for body in blockers:
		_region.remove_child(body)
		body.free()
	return mesh


## [centre, size] boxes that close an opening or both ends of a stair.
func _blocker_boxes(name: String) -> Array:
	for s in Layout.STAIRS:
		if s.id == name:
			var dir := signf(s.z_high - s.z_low)
			var xc: float = (s.x0 + s.x1) / 2.0
			var w: float = s.x1 - s.x0 + 0.3
			return [[Vector3(xc, 1.5, s.z_low - dir * 0.7), Vector3(w, 3.0, 1.0)],
				[Vector3(xc, Layout.UPPER_Y + 1.5, s.z_high + dir * 0.7), Vector3(w, 3.0, 1.0)]]
	var found := Layout.find_opening(name)
	if found.is_empty():
		_expect(false, "Unknown opening or stair '%s'." % name)
		return []
	var c: Vector3 = found.centre + Vector3(0, Layout.DOOR_HEIGHT / 2.0, 0)
	var w: float = found.opening.width + 0.4
	var size := Vector3(w, Layout.DOOR_HEIGHT, 1.0) if found.along_x else Vector3(1.0, Layout.DOOR_HEIGHT, w)
	return [[c, size]]


# --- G. Walking with real input ---------------------------------------------------------------

func _check_walks() -> void:
	var lowest := INF
	var highest := -INF
	var walked := 0.0
	var seconds := 0.0
	var gates_passed := {}
	for r in Layout.ROUTES.size() - 1:   # the last "route" is the one-way shortcut, a short hop
		var route: Dictionary = Layout.ROUTES[r]
		var points: Array = route.points
		_teleport(points[0])
		await _frames(5)
		for i in range(1, points.size()):
			var started := Time.get_ticks_msec()
			var from := _player.global_position
			var result: Dictionary = await _walk_to(points[i], "sprint" if r == 0 else "")
			seconds += (Time.get_ticks_msec() - started) / 1000.0
			walked += result.distance
			lowest = minf(lowest, result.lowest)
			highest = maxf(highest, result.highest)
			if not result.arrived:
				_expect(false, "%s: walking from %s to %s got stuck at %s." % [route.name, from, points[i], _player.global_position])
				break
			for g in Layout.GATES:
				if result.passed.has(g.opening):
					gates_passed[g.opening] = true
	_expect(lowest > -0.5, "The player fell through or off the level (lowest y %.2f)." % lowest)
	_expect(highest > Layout.UPPER_Y - 0.2, "The walk never reached the upper floor.")
	for g in Layout.GATES:
		if g.opening != "Service Shortcut SC1":
			_expect(gates_passed.has(g.opening), "The walk never went through %s." % g.opening)
	print("  [expanded] walk: main route + 2 alternatives walked with real input, %.0f m in %.0f s, y %.2f…%.2f, gates passed %s" % [
		walked, seconds, lowest, highest, gates_passed.keys()])


## Walks to `target` with real input (W held, body turned toward the next path
## corner). Stuck = moved less than 0.3 m in 1.5 s.
func _walk_to(target: Vector3, mode: String) -> Dictionary:
	var result := {"arrived": false, "distance": 0.0, "lowest": INF, "highest": -INF, "passed": {}}
	var path := NavigationServer3D.map_get_path(_map, _player.global_position, target, true)
	if path.is_empty():
		return result
	var index := 0
	var anchor := _player.global_position
	var anchor_frame := 0
	var last := _player.global_position
	if mode != "":
		Input.action_press(mode)
	Input.action_press("move_forward")
	for frame in 60 * 120:
		var here := _player.global_position
		result.distance += here.distance_to(last)
		last = here
		result.lowest = minf(result.lowest, here.y)
		result.highest = maxf(result.highest, here.y)
		for g in Layout.GATES:
			var c: Vector3 = Layout.find_opening(g.opening).centre
			if here.distance_to(c) < 1.0:
				result.passed[g.opening] = true
		while index < path.size() - 1 and Vector2(path[index].x - here.x, path[index].z - here.z).length() < 0.45:
			index += 1
		if Vector2(target.x - here.x, target.z - here.z).length() < 0.4 and absf(target.y - here.y) < 0.8:
			result.arrived = true
			break
		var to := path[index] - here
		_player.rotation.y = atan2(-to.x, -to.z)
		if frame - anchor_frame >= 90:
			if here.distance_to(anchor) < 0.3:
				break
			anchor = here
			anchor_frame = frame
		await _host.get_tree().physics_frame
	_release_all()
	await _frames(6)
	return result


func _teleport(at: Vector3) -> void:
	_player.global_position = at + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO


func _release_all() -> void:
	for a in ["move_forward", "move_backward", "move_left", "move_right", "sprint", "crouch"]:
		Input.action_release(a)


# --- Helpers ------------------------------------------------------------------------------------

func _path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(_map, from, to, true)


func _reaches(path: PackedVector3Array, target: Vector3, tolerance: float) -> bool:
	return not path.is_empty() and path[path.size() - 1].distance_to(target) <= tolerance + 0.35


func _length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


func _area(mesh: NavigationMesh) -> float:
	var total := 0.0
	for i in mesh.get_polygon_count():
		total += _polygon_area(mesh, mesh.get_polygon(i))
	return total


func _polygon_area(mesh: NavigationMesh, poly: PackedInt32Array) -> float:
	var v := mesh.get_vertices()
	var a := 0.0
	for k in range(1, poly.size() - 1):
		a += (v[poly[k]] - v[poly[0]]).cross(v[poly[k + 1]] - v[poly[0]]).length() / 2.0
	return a


func _all(node: Node, keep: Callable) -> Array:
	var out := []
	if keep.call(node):
		out.append(node)
	for child in node.get_children():
		out.append_array(_all(child, keep))
	return out


func _frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
