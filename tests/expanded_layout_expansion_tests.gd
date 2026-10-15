extends RefCounted

## Expanded Library expansion, Phase 2 (layout): the seven zones, the new
## basement / service network and electrical room, and their connections.
## Called from tests/test_scene.gd.
##
##   A. Zones and structure: zones A-F in the existing level, G and the D
##      extension in the Expansion sub-scene; both parts in the navmesh's bake
##      group; the reserved spaces and the three escape routes marked.
##   B. Navigation: every new area reachable from the spawn on the level's
##      navmesh; nothing reachable outside the building, beyond the storm
##      drain's grate or under the existing floors; no navmesh on roofs, walls
##      or under the ramps.
##   C. The main stacks are a hub: five routes (two arches, the S3 stair, the
##      west service door, the Study 1 door).
##   D. Doorways and stairs: the three new doorways are clear 2 m × 2.6 m;
##      both service stairs are 3 m+ wide, at most 25° and have headroom.
##   E. The player walks every new route with real input: down the west
##      service stair, along the tunnel into the bay, pump room and drain, up
##      the east service stair into the electrical room, through the card door
##      into book processing, and through the new stacks / Study 1 door.
##   F. A guard (the level's guard scene and AI) tours every new area and
##      both service stairs without getting stuck.
##   G. Zone D still needs the staff card: rebaked with the card doors closed
##      (the level's G2 and G4 and the new electrical room door), book
##      processing is cut off from the spawn even through the basement; with
##      the card it is reachable both through G4 and through the basement.

const SCENE := "res://scenes/level/expanded_library.tscn"
const GUARD_SCENE := "res://scenes/npc/guard.tscn"
const Layout := preload("res://tools/expanded/expanded_layout.gd")
const X := preload("res://tools/expanded/expansion/expansion_layout.gd")
const TestUtils := preload("res://tests/test_utils.gd")
const REACH := 0.8

var failures: Array[String] = []
var _host: Node
var _level: Node3D
var _map: RID
var _player: FirstPersonPlayer


func run(host: Node) -> Array[String]:
	_host = host
	_level = (load(SCENE) as PackedScene).instantiate()
	for g in _level.get_node("Guards").get_children():
		if g is Guard:
			g.get_parent().remove_child(g)
			g.free()
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, _level, Layout.SPAWN), "Navigation never became ready.")
	_map = _level.get_world_3d().navigation_map
	_player = _level.get_node("Player")
	GameFlow.find(_level).change_scene = func(_path: String): pass
	await _frames(10)
	_check_structure()
	_check_navigation()
	_check_hub()
	_check_doorways_and_stairs()
	await _check_card_rule()
	await _check_player_walk()
	await _check_guard_tour()
	Engine.time_scale = 1.0
	_level.queue_free()
	await _frames(30)
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[expansion-layout] " + message)


# --- A. Zones and structure ---------------------------------------------------------------------

func _check_structure() -> void:
	var zones := {}
	for n in _level.find_children("*", "Node3D", true, false):
		if n.has_meta("zone_id"):
			var id := String(n.get_meta("zone_id"))
			if not (n is Area3D):   # hiding spots carry their zone too
				zones[id] = zones.get(id, []) + [String(_level.get_path_to(n))]
	for id in ["A", "B", "C", "D", "E", "F", "G"]:
		_expect(zones.has(id), "Zone %s has no node." % id)
	var expansion := _level.get_node("Expansion")
	var geometry := expansion.get_node_or_null("Geometry")
	var region := _level.get_node("NavigationRegion3D") as NavigationRegion3D
	_expect(geometry != null and geometry.is_in_group(X.NAV_GROUP) and region.is_in_group(X.NAV_GROUP),
		"The NavigationRegion3D and Expansion/Geometry must both be in %s (the navmesh's bake group)." % X.NAV_GROUP)
	var nav := region.navigation_mesh
	_expect(nav.geometry_source_geometry_mode == NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN and nav.geometry_source_group_name == X.NAV_GROUP,
		"The navmesh must be baked from the group %s." % X.NAV_GROUP)
	_expect(expansion.get_node("Geometry/G_ServiceNetwork").get_meta("zone_id") == "G", "Expansion/Geometry/G_ServiceNetwork must be zone G.")
	_expect(expansion.get_node("Geometry/D_ElectricalAnnex").get_meta("zone_id") == "D", "Expansion/Geometry/D_ElectricalAnnex must extend zone D.")
	var reserved := expansion.find_children("*", "Label3D", true, false).filter(func(l): return l.has_meta("reserved"))
	_expect(reserved.size() == X.RESERVED.size(), "Expected %d reserved-space markers, found %d." % [X.RESERVED.size(), reserved.size()])
	var escapes := reserved.filter(func(l): return String(l.name).begins_with("Escape"))
	_expect(escapes.size() == 3, "The three escape routes must be marked (found %d)." % escapes.size())
	print("  [expansion-layout] zones: %s; G and the D extension in Expansion; navmesh baked from %s; %d reserved spaces (3 escapes)" % [
		" ".join(PackedStringArray(zones.keys())), X.NAV_GROUP, reserved.size()])


# --- B. Navigation ------------------------------------------------------------------------------

func _check_navigation() -> void:
	var lengths := []
	for k in X.PROBES:
		var p: Vector3 = X.PROBES[k]
		var path := _path(Layout.SPAWN, p)
		_expect(_reaches(path, p), "%s %s is not reachable from the spawn (path ends %s)." % [k, p, path[path.size() - 1] if not path.is_empty() else "nowhere"])
		lengths.append("%s %.0f m" % [k, _length(path)])
	for k in X.SEALED:
		var p: Vector3 = X.SEALED[k]
		var path := _path(Layout.SPAWN, p)
		_expect(path.is_empty() or path[path.size() - 1].distance_to(p) > 1.5, "%s %s must not be reachable." % [k, p])
	var nav := (_level.get_node("NavigationRegion3D") as NavigationRegion3D).navigation_mesh
	var basement := 0.0
	var stray := 0
	var on_roof := 0
	var verts := nav.get_vertices()
	for i in nav.get_polygon_count():
		var poly := nav.get_polygon(i)
		var c := Vector3.ZERO
		for v in poly:
			c += verts[v]
		c /= poly.size()
		if c.y < X.BF + 0.6:
			basement += _polygon_area(nav, poly)
		elif c.y < -0.6 and not _on_new_ramp(c):
			stray += 1
		if (c.x < -36.0 or c.x > 36.0) and c.y > 1.0:
			on_roof += 1
	# The navmesh stays off the building's outer walls above the ground floor
	# (the S2 stair top runs along the east wall at its height; see SEALS). The
	# v4 navmesh comes no closer than 0.2 m (the top of S3, at the west wall).
	var at_outer_walls := 0
	for v in verts:
		if v.y > 0.6 and (absf(v.x) > 35.7 or v.z < -27.7) and v.x > -36.2 and v.x < 36.2:
			at_outer_walls += 1
	_expect(basement > 400.0, "Too little walkable basement (%.0f m²)." % basement)
	_expect(stray == 0, "%d navmesh polygons float between the basement and the ground floor outside the service stairs." % stray)
	_expect(on_roof == 0, "%d navmesh polygons on the annexes' roofs or walls." % on_roof)
	_expect(at_outer_walls == 0, "%d navmesh vertices above the ground within 0.15 m of the building's outer walls (on the wall top?)." % at_outer_walls)
	print("  [expansion-layout] navigation: %d new areas reachable from the spawn (%s); %d sealed points unreachable; basement %.0f m², nothing stray or on roofs" % [
		X.PROBES.size(), ", ".join(lengths), X.SEALED.size(), basement])


func _on_new_ramp(p: Vector3) -> bool:
	for r in X.RAMPS:
		if p.x >= r.x0 - 0.5 and p.x <= r.x1 + 0.5 and p.z >= minf(r.z_top, r.z_bottom) - 0.5 and p.z <= maxf(r.z_top, r.z_bottom) + 0.5:
			return true
	return false


# --- C. The stacks hub --------------------------------------------------------------------------

func _check_hub() -> void:
	var routes := {}
	# The existing routes out of the main stacks (B): its two arches and the S3 stair.
	for wall in Layout.WALLS:
		if wall.zone == "B":
			for o in wall.get("openings", []):
				if o.type == "arch":
					routes[o.name] = true
	for s in Layout.STAIRS:
		if s.zone == "B":
			routes[s.name] = true
	# The new ones: a short walk through each new doorway.
	var west := _length(_path(X.PROBES.stacks_cross_aisle, X.PROBES.west_landing))
	var study := _length(_path(X.PROBES.stacks_by_study, X.PROBES.study_1))
	_expect(west < 12.0, "Main stacks → west service stair should be a short walk through the new doorway (%.1f m)." % west)
	_expect(study < 8.0, "Main stacks → Study 1 should be a short walk through the new doorway (%.1f m)." % study)
	if west < 12.0:
		routes["West service door"] = true
	if study < 8.0:
		routes["Study 1 door"] = true
	_expect(routes.size() >= 5, "The main stacks should have at least 5 routes (found %s)." % [routes.keys()])
	print("  [expansion-layout] main stacks hub: %d routes (%s); cross aisle → service stair %.1f m, stacks → Study 1 %.1f m" % [
		routes.size(), ", ".join(PackedStringArray(routes.keys())), west, study])


# --- D. Doorways and stairs ---------------------------------------------------------------------

func _check_doorways_and_stairs() -> void:
	var space := _level.get_world_3d().direct_space_state
	var door := _level.get_node_or_null("Expansion/Gameplay/ElectricalRoomDoor")
	# Keyed to the carried staff card since Phase 3 (key_item); take_card stays as its objective key.
	_expect(door is AccessDoor and door.mode == AccessDoor.Mode.KEY and door.key_objective_id == &"take_card" and door.key_item == &"staff_card",
		"The electrical room needs its staff-card door (Expansion/Gameplay/ElectricalRoomDoor, an AccessDoor keyed to the carried staff card).")
	if not door is AccessDoor:
		return
	var was_open: bool = door.is_open
	door.open()
	var report := []
	for h in X.DOOR_HEADERS:
		var c := Vector3(h.x, 0, h.z)
		# Clear 2 m wide (less the agent's margin) and up to the door height.
		var probe := BoxShape3D.new()
		probe.size = Vector3(0.8, X.DOOR_HEIGHT - 0.15, h.width - 0.1)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = probe
		q.transform = Transform3D(Basis(), c + Vector3(0, X.DOOR_HEIGHT / 2.0 + 0.05, 0))
		q.collision_mask = 1
		var hits := space.intersect_shape(q, 8)
		_expect(hits.is_empty(), "Doorway %s is not clear (%d colliders in it)." % [h.name, hits.size()])
		var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3(0, 1.0, 0), c + Vector3(0, 5.0, 0), 1))
		var clear_height: float = up.position.y if not up.is_empty() else INF
		_expect(clear_height >= X.DOOR_HEIGHT - 0.01 and clear_height < X.GROUND_WALL_TOP, "Doorway %s: header at %.2f m (expected %.1f m)." % [h.name, clear_height, X.DOOR_HEIGHT])
		report.append("%s %.1f × %.2f m" % [h.name, h.width, clear_height])
	if not was_open:
		door.restore_checkpoint_state({"open": false})
	for r in X.RAMPS:
		var width: float = r.x1 - r.x0
		var angle := rad_to_deg(atan2(-X.BF, absf(r.z_bottom - r.z_top)))
		_expect(width >= 3.0 and angle <= 25.0, "%s: %.2f m wide at %.1f° (need ≥ 3 m and ≤ 25°)." % [r.name, width, angle])
		var blocked := 0
		for i in range(1, 20):
			var f := i / 20.0
			var z: float = lerpf(r.z_top, r.z_bottom, f)
			var y := lerpf(0.0, X.BF, f)
			for x in [r.x0 + 0.4, (r.x0 + r.x1) / 2.0, r.x1 - 0.4]:
				var from := Vector3(x, y + 0.15, z)
				if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 2.2, 0), 1)).is_empty():
					blocked += 1
		_expect(blocked == 0, "%s: %d points with less than 2.2 m of headroom." % [r.name, blocked])
		report.append("%s %.2f m wide, %.1f°" % [r.name, width, angle])
	print("  [expansion-layout] doorways and stairs: %s; headroom ≥ 2.2 m on both stairs" % ", ".join(report))


# --- E. The player walks every new route --------------------------------------------------------

func _check_player_walk() -> void:
	var door := _level.get_node_or_null("Expansion/Gameplay/ElectricalRoomDoor")
	if door:
		door.open()   # the card door (closed doors are tested in G and in the mission tests)
	await _frames(3)
	var legs := [
		["stacks_cross_aisle", ["west_landing", "west_basement", "basement_alcove", "maintenance_bay", "tunnel_middle", "pump_room",
			"storm_drain", "east_tunnel_end", "cable_bay", "east_basement", "electrical_room", "book_processing"]],
		["stacks_by_study", ["study_1", "stacks_by_study"]],
	]
	var walked := 0.0
	var lowest := INF
	var reached := 0
	var total := 0
	for leg in legs:
		_teleport(X.PROBES[leg[0]])
		await _frames(5)
		for k in leg[1]:
			total += 1
			var target: Vector3 = X.PROBES[k]
			var result: Dictionary = await _walk_to(target)
			walked += result.distance
			lowest = minf(lowest, result.lowest)
			if not result.arrived:
				_expect(false, "Walk: the player got stuck on the way to %s %s, at %s." % [k, target, _player.global_position])
				break
			reached += 1
	_expect(lowest > X.BF - 0.3, "Walk: the player fell below the basement floor (lowest y %.2f)." % lowest)
	if door:
		door.restore_checkpoint_state({"open": false})
	print("  [expansion-layout] walk: %d/%d new places reached with real input, %.0f m, down the west service stair, along the tunnel, up the east service stair; lowest y %.2f" % [
		reached, total, walked, lowest])


## Walks to `target` with real input (W held, turned toward the next path corner).
## Stuck = moved less than 0.3 m in 1.5 s. (As in expanded_graybox_tests.)
func _walk_to(target: Vector3) -> Dictionary:
	var result := {"arrived": false, "distance": 0.0, "lowest": INF}
	var path := _path(_player.global_position, target)
	if path.is_empty():
		return result
	var index := 0
	var anchor := _player.global_position
	var anchor_frame := 0
	var last := _player.global_position
	Input.action_press("move_forward")
	for frame in 60 * 90:
		var here := _player.global_position
		result.distance += here.distance_to(last)
		last = here
		result.lowest = minf(result.lowest, here.y)
		while index < path.size() - 1 and Vector2(path[index].x - here.x, path[index].z - here.z).length() < 0.45:
			index += 1
		if Vector2(target.x - here.x, target.z - here.z).length() < 0.5 and absf(target.y - here.y) < 0.8:
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
	Input.action_release("move_forward")
	await _frames(6)
	return result


func _teleport(at: Vector3) -> void:
	_player.global_position = at + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO


# --- F. A guard tours the new areas -------------------------------------------------------------

func _check_guard_tour() -> void:
	_teleport(Layout.SPAWN)
	var tour: Array[Vector3] = []
	for k in ["west_landing", "west_basement", "maintenance_bay", "pump_room", "storm_drain", "east_basement", "electrical_room",
			"book_processing", "east_tunnel_end", "basement_alcove", "stacks_cross_aisle", "stacks_by_study", "study_1"]:
		tour.append(X.PROBES[k])
	var route := PatrolRoute.new()
	route.name = "ExpansionTourRoute"
	route.loop = false
	for p in tour:
		var marker := PatrolPoint.new()
		marker.position = p
		marker.wait_time = 0.2
		route.add_child(marker)
	_level.add_child(route)
	var guard: Guard = (load(GUARD_SCENE) as PackedScene).instantiate()
	guard.name = "ExpansionTourGuard"
	guard.patrol_route = route
	guard.position = X.PROBES.stacks_cross_aisle + Vector3(0, 0.05, 0)
	guard.patrol_speed = 3.5
	_level.add_child(guard)
	var reached := []
	var stuck := [0]
	guard.patrol_point_reached.connect(func(i): reached.append(i))
	guard.got_stuck.connect(func(_i): stuck[0] += 1)
	var lowest := INF
	Engine.time_scale = 2.0
	for i in 60 * 150:
		await _host.get_tree().physics_frame
		lowest = minf(lowest, guard.global_position.y)
		if reached.size() == tour.size():
			break
	Engine.time_scale = 1.0
	var door := _level.get_node_or_null("Expansion/Gameplay/ElectricalRoomDoor")
	_expect(reached.size() == tour.size() and stuck[0] == 0, "Tour: the guard should reach all %d points without getting stuck (reached %d, stuck %d, at %s)." % [
		tour.size(), reached.size(), stuck[0], guard.global_position])
	_expect(lowest > X.BF - 0.3, "Tour: the guard fell below the basement (lowest y %.2f)." % lowest)
	_expect(door == null or not door.is_open, "Tour: the guard passes the electrical room door but must not open it.")
	guard.queue_free()
	route.queue_free()
	await _frames(3)
	print("  [expansion-layout] guard tour: %d/%d points (both service stairs, tunnel, bay, pump room, drain, electrical room through the closed card door, Study 1 door), stuck %d" % [
		reached.size(), tour.size(), stuck[0]])


# --- G. Zone D still needs the staff card -------------------------------------------------------

func _check_card_rule() -> void:
	var card_doors := [_opening_box("Archive Front Gate G2"), _opening_box("Lobby Staff Door G4"), _expansion_door_box()]
	var g3 := _opening_box("Archive Back Gate G3")
	var sc1 := _opening_box("Service Shortcut SC1")
	var processing: Vector3 = X.PROBES.book_processing
	var cases := [
		["without the card", card_doors + [g3, sc1], [["book processing", processing, false], ["the dock", Vector3(27, 0, 20), false],
			["the east basement (via the west stair and the tunnel)", X.PROBES.east_basement, true], ["the electrical room (from below)", X.PROBES.electrical_room, true]]],
		["with the card", [g3, sc1], [["book processing", processing, true]]],
		["with the card, G4 closed", [g3, sc1, _opening_box("Lobby Staff Door G4")], [["book processing through the basement", processing, true]]],
	]
	var lines := []
	for c in cases:
		var map: Array = await _private_map(c[1])   # [map, region]
		for check in c[2]:
			var path := NavigationServer3D.map_get_path(map[0], Layout.SPAWN, check[1], true)
			var ok := _reaches(path, check[1])
			_expect(ok == check[2], "Card rule, %s: %s should be %s." % [c[0], check[0], "reachable" if check[2] else "cut off"])
			lines.append("%s: %s %s" % [c[0], check[0], "reachable" if ok else "cut off"])
		NavigationServer3D.free_rid(map[1])
		NavigationServer3D.free_rid(map[0])
	print("  [expansion-layout] card rule (rebaked with doors closed): %s" % "; ".join(lines))


func _opening_box(opening_name: String) -> Array:
	var found := Layout.find_opening(opening_name)
	var w: float = found.opening.width + 0.4
	return [found.centre + Vector3(0, 1.3, 0), Vector3(w, 2.6, 1.0) if found.along_x else Vector3(1.0, 2.6, w)]


func _expansion_door_box() -> Array:
	var d: Dictionary = X.DOORS[0]
	var w: float = d.width + 0.4
	return [d.centre + Vector3(0, 1.3, 0), Vector3(w, 2.6, 1.0) if d.along_x else Vector3(1.0, 2.6, w)]


## The level's navmesh rebaked in memory with blockers (boxes [centre, size]) in a
## private map. Returns [map, region]; the caller frees both.
func _private_map(blocked: Array) -> Array:
	var region := _level.get_node("NavigationRegion3D") as NavigationRegion3D
	var bodies: Array[Node] = []
	for box in blocked:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var shape := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = box[1]
		shape.shape = b
		body.add_child(shape)
		body.position = box[0]
		region.add_child(body)
		bodies.append(body)
	var mesh := region.navigation_mesh.duplicate() as NavigationMesh
	mesh.clear_polygons()
	mesh.vertices = PackedVector3Array()
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, region)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	for body in bodies:
		region.remove_child(body)
		body.free()
	var map := NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(map, NavigationServer3D.map_get_cell_size(_map))
	NavigationServer3D.map_set_cell_height(map, NavigationServer3D.map_get_cell_height(_map))
	var rid := NavigationServer3D.region_create()
	NavigationServer3D.region_set_navigation_mesh(rid, mesh)
	NavigationServer3D.region_set_map(rid, map)
	NavigationServer3D.map_set_active(map, true)
	for i in 120:
		await _host.get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) >= 2 and NavigationServer3D.map_get_closest_point(map, Layout.SPAWN).distance_to(Layout.SPAWN) < 2.0:
			break
	await _host.get_tree().physics_frame
	return [map, rid]


# --- Helpers ------------------------------------------------------------------------------------

func _path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(_map, from, to, true)


func _reaches(path: PackedVector3Array, target: Vector3) -> bool:
	return not path.is_empty() and path[path.size() - 1].distance_to(target) <= REACH


func _length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


func _polygon_area(mesh: NavigationMesh, poly: PackedInt32Array) -> float:
	var v := mesh.get_vertices()
	var a := 0.0
	for i in range(1, poly.size() - 1):
		a += (v[poly[i]] - v[poly[0]]).cross(v[poly[i + 1]] - v[poly[0]]).length() / 2.0
	return a


func _frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
