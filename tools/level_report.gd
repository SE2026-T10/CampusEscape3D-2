extends SceneTree

## Level-design report for the library: measures the level as it is now and
## writes metrics.json, report.md and (when a display is available) map.png.
## Re-run after every level change to compare versions.
##
##   godot --path . --script res://tools/level_report.gd -- --out=docs/level/v1 --version=v1
##
## --scene=res://path.tscn measures another copy of the level (e.g. a patrol experiment).
##
## Run without --headless (or under a virtual display) to also draw map.png;
## headless runs write only the numbers.
##
## What it measures (all from the real scene, navigation mesh and colliders):
##   - rooms: walkable area, cover nearby, how exposed the floor is to guard patrols
##   - exposure: each guard's patrol loop is replayed as a timeline (walking at
##     patrol speed, facing the way it walks, standing still at each point for its
##     wait). A walkable spot's exposure is the share of loop time during which
##     some guard has it inside its 90° view cone, within 14 m, with a clear line
##     of sight. 1 − Π(1 − e) combines guards. This is the chance a guard is
##     looking at that spot at a random moment. Standing uses head height 1.5 m,
##     crouched 0.85 m, so the difference is what low cover adds.
##   - "seen at some point": exposure above zero.
##   - "safe": exposure below 5%.
##   - patrols: points, waits, loop length along the navmesh, loop time
##   - player routes: navmesh paths between spawn, card and exit (shortest and
##     alternative), their length and how exposed they are
##   - stealth routes: the least-exposed walk between the same points (grid search
##     where each metre costs 1 + 20 × exposure), i.e. the route a careful
##     player would take, and how exposed even that route is
##   - landmarks / key points: positions of objectives, checkpoints and hiding spots

const LEVEL := "res://scenes/level/library_graybox.tscn"
const MapCanvas := preload("res://tools/level_map_canvas.gd")
const SAMPLE_STEP := 1.0
const SIGHT_RANGE := 14.0
const EYE := 1.6
const HEAD_STANDING := 1.5
const HEAD_CROUCHED := 0.85
const COVER_RADIUS := 1.5
const PATROL_STEP := 1.0
const FOV_DEGREES := 90.0
const SAFE_EXPOSURE := 0.05
const STEALTH_WEIGHT := 20.0

var _level: Node3D
var _map: RID
var _space: PhysicsDirectSpaceState3D


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := _args()
	var out: String = args.get("out", "user://level_report")
	var version: String = args.get("version", "current")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(out) if not out.begins_with("user://") else out)
	_level = (load(args.get("scene", LEVEL)) as PackedScene).instantiate()
	root.add_child(_level)
	_map = _level.get_world_3d().navigation_map
	if not await _wait_for_navigation():
		push_error("Navigation never became ready.")
		quit(1)
		return
	_space = _level.get_world_3d().direct_space_state
	var data := _measure(version)
	var dir := out if out.begins_with("user://") else "res://" + out
	_write_json(dir.path_join("metrics.json"), data)
	_write_report(dir.path_join("report.md"), data)
	print("Level report %s: %d walkable samples, mean exposure %.1f%% (crouched %.1f%%), safe %.0f%% → %s" % [
		version, data.totals.walkable, data.totals.exposure_pct, data.totals.exposure_crouched_pct, data.totals.safe_pct, dir])
	if DisplayServer.get_name() != "headless":
		await _draw_map(dir.path_join("map.png"), data)
	quit(0)


# --- Measuring --------------------------------------------------------------------------

func _measure(version: String) -> Dictionary:
	var region: NavigationRegion3D = _level.get_node("NavigationRegion3D")
	var floors: Array = []      # {room, rect}
	var obstacles: Array = []   # {name, room, kind, rect, top}
	for body in region.find_children("*", "StaticBody3D", true, false):
		var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null:
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		var rect := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		var room := _room_of(body)
		if String(body.name).begins_with("Floor"):
			floors.append({"room": room, "rect": rect})
		else:
			obstacles.append({"name": String(body.name), "room": room, "kind": _kind(body, box), "rect": rect, "top": box.end.y})

	var patrols := _patrols()

	# Walkable samples and exposure.
	var samples: Array = []
	var rooms := {}
	for f in floors:
		var r: Rect2 = f.rect
		var x := floorf(r.position.x) + SAMPLE_STEP / 2.0
		while x < r.end.x:
			var z := floorf(r.position.y) + SAMPLE_STEP / 2.0
			while z < r.end.y:
				var p := Vector3(x, 0, z)
				if r.has_point(Vector2(x, z)) and _walkable(p, obstacles):
					var standing := _exposure(p, HEAD_STANDING, patrols)
					var crouched := _exposure(p, HEAD_CROUCHED, patrols) if standing > 0.0 else 0.0
					var near_cover := _near_cover(p, obstacles)
					samples.append({"x": x, "z": z, "room": f.room, "standing": snappedf(standing, 0.001), "crouched": snappedf(crouched, 0.001), "cover": near_cover})
					var stat: Dictionary = rooms.get(f.room, {"walkable": 0, "seen": 0, "exposure_sum": 0.0, "exposure_crouched_sum": 0.0, "safe": 0, "cover": 0})
					stat.walkable += 1
					stat.seen += int(standing > 0.0)
					stat.exposure_sum += standing
					stat.exposure_crouched_sum += crouched
					stat.safe += int(standing < SAFE_EXPOSURE)
					stat.cover += int(near_cover)
					rooms[f.room] = stat
				z += SAMPLE_STEP
			x += SAMPLE_STEP
	for room in rooms:
		var s: Dictionary = rooms[room]
		s.seen_pct = _pct(s.seen, s.walkable)
		s.exposure_pct = snappedf(100.0 * s.exposure_sum / s.walkable, 0.1)
		s.exposure_crouched_pct = snappedf(100.0 * s.exposure_crouched_sum / s.walkable, 0.1)
		s.safe_pct = _pct(s.safe, s.walkable)
		s.cover_pct = _pct(s.cover, s.walkable)
		s.erase("exposure_sum")
		s.erase("exposure_crouched_sum")

	var key := _key_points()
	var routes := _routes(key, patrols)
	_add_stealth_routes(routes, key, samples)
	var hiding: Array = []
	for spot in _level.find_children("*", "HidingSpot", true, false):
		var at: Vector3 = spot.global_position
		at.y = 0.0
		hiding.append({"name": String(spot.get_parent().name), "at": _v2(at),
			"exposure_crouched_pct": snappedf(100.0 * _exposure(at, HEAD_CROUCHED, patrols), 0.1),
			"exposure_standing_pct": snappedf(100.0 * _exposure(at, HEAD_STANDING, patrols), 0.1)})
	var total_exposure := 0.0
	var total_crouched := 0.0
	for smp in samples:
		total_exposure += smp.standing
		total_crouched += smp.crouched
	var totals := {"walkable": samples.size(),
		"seen_pct": _pct(samples.filter(func(s): return s.standing > 0.0).size(), samples.size()),
		"exposure_pct": snappedf(100.0 * total_exposure / maxi(samples.size(), 1), 0.1),
		"exposure_crouched_pct": snappedf(100.0 * total_crouched / maxi(samples.size(), 1), 0.1),
		"safe_pct": _pct(samples.filter(func(s): return s.standing < SAFE_EXPOSURE).size(), samples.size()),
		"near_cover_pct": _pct(samples.filter(func(s): return s.cover).size(), samples.size()),
		"obstacles": obstacles.size(),
		"cover_props": obstacles.filter(func(o): return o.kind != "wall").size(),
		"low_cover_props": obstacles.filter(func(o): return o.kind == "low").size(),
		"navmesh_polygons": region.navigation_mesh.get_polygon_count()}
	var safety: Array = []
	for cp in _level.find_children("*", "Checkpoint", true, false):
		var at: Vector3 = cp.get_spawn_transform().origin
		at.y = 0.0
		safety.append({"name": String(cp.name), "at": _v2(at), "exposure_standing_pct": snappedf(100.0 * _exposure(at, HEAD_STANDING, patrols), 0.1)})
	safety.append({"name": "Spawn", "at": key.spawn, "exposure_standing_pct": snappedf(100.0 * _exposure(_v3(key.spawn), HEAD_STANDING, patrols), 0.1)})
	return {"version": version, "date": Time.get_date_string_from_system(), "totals": totals, "rooms": rooms, "patrols": patrols.map(_patrol_summary),
		"routes": routes, "hiding_spots": hiding, "respawn_points": safety, "key_points": key, "samples": samples, "floors": floors.map(_rect_entry),
		"obstacles": obstacles.map(_rect_entry), "patrol_paths": patrols.map(func(p): return {"name": p.name, "points": p.points.map(_v2), "path": p.path.map(_v2), "waits": p.waits})}


func _room_of(node: Node) -> String:
	var areas := _level.get_node("NavigationRegion3D/Areas")
	var n := node
	while n and n.get_parent() != areas:
		n = n.get_parent()
	return String(n.name) if n else "Other"


func _kind(body: Node, box: AABB) -> String:
	var name := String(body.name)
	if name.begins_with("Wall"):
		return "wall"
	if box.end.y >= 1.6:
		return "full"
	return "low"


func _walkable(p: Vector3, obstacles: Array) -> bool:
	var closest := NavigationServer3D.map_get_closest_point(_map, p)
	if Vector2(closest.x - p.x, closest.z - p.z).length() > 0.3:
		return false
	for o in obstacles:
		if (o.rect as Rect2).has_point(Vector2(p.x, p.z)):
			return false
	return true


## Share of loop time (0–1) during which at least one guard sees `p` at head height `head`.
func _exposure(p: Vector3, head: float, patrols: Array) -> float:
	var target := p + Vector3(0, head, 0)
	var unseen := 1.0
	var cos_half := cos(deg_to_rad(FOV_DEGREES / 2.0))
	for patrol in patrols:
		var seen_time := 0.0
		for step in patrol.timeline:
			var eye: Vector3 = step.pos + Vector3(0, EYE, 0)
			var to := target - eye
			if to.length() > SIGHT_RANGE:
				continue
			var flat := Vector2(to.x, to.z)
			if flat.length() > 0.3 and flat.normalized().dot(step.dir) < cos_half:
				continue
			if _space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, target, 1)).is_empty():
				seen_time += step.dt
		unseen *= 1.0 - seen_time / maxf(patrol.loop_seconds, 0.001)
	return 1.0 - unseen


func _near_cover(p: Vector3, obstacles: Array) -> bool:
	for o in obstacles:
		if o.kind == "wall":
			continue
		if (o.rect as Rect2).grow(COVER_RADIUS).has_point(Vector2(p.x, p.z)):
			return true
	return false


func _patrols() -> Array:
	var result: Array = []
	for guard in _level.find_children("*", "Guard", true, false):
		var route: PatrolRoute = guard.patrol_route
		if route == null:
			continue
		var points: Array = []
		var waits: Array = []
		for child in route.get_children():
			if child is PatrolPoint:
				points.append(child.global_position)
				waits.append(child.wait_time if child.wait_time >= 0.0 else guard.default_wait_time)
		var path: Array = []
		var length := 0.0
		var legs := points.size() if route.loop else points.size() - 1
		for i in legs:
			var leg := NavigationServer3D.map_get_path(_map, points[i], points[(i + 1) % points.size()], true)
			for j in leg.size():
				if j > 0:
					length += leg[j - 1].distance_to(leg[j])
				path.append(leg[j])
		# Timeline: walking steps facing the direction of travel, then a stop at
		# each patrol point (facing the way the guard arrived) for its wait.
		var timeline: Array = []
		var dir := Vector2(0, -1)
		for i in legs:
			var leg := NavigationServer3D.map_get_path(_map, points[i], points[(i + 1) % points.size()], true)
			for j in range(1, leg.size()):
				var a: Vector3 = leg[j - 1]
				var b: Vector3 = leg[j]
				var d := a.distance_to(b)
				if d < 0.01:
					continue
				dir = Vector2(b.x - a.x, b.z - a.z).normalized()
				var n := maxi(1, int(d / PATROL_STEP))
				for k in n:
					timeline.append({"pos": a.lerp(b, float(k) / n), "dir": dir, "dt": d / n / guard.patrol_speed})
			timeline.append({"pos": points[(i + 1) % points.size()], "dir": dir, "dt": waits[(i + 1) % points.size()]})
		var wait_total := 0.0
		for w in waits:
			wait_total += w
		result.append({"name": String(guard.name), "points": points, "waits": waits, "path": path, "timeline": timeline,
			"length": length, "loop_seconds": length / guard.patrol_speed + wait_total, "loop": route.loop})
	return result


func _patrol_summary(p: Dictionary) -> Dictionary:
	return {"name": p.name, "points": p.points.map(_v2), "waits": p.waits, "length_m": snappedf(p.length, 0.1),
		"loop_seconds": snappedf(p.loop_seconds, 0.1), "loop": p.loop}


func _key_points() -> Dictionary:
	var g := _level.get_node("Gameplay")
	var key := {"spawn": _v2(_level.get_node("Player").global_position),
		"card": _v2(g.get_node("AccessCard").global_position),
		"exit_door": _v2(g.get_node("ExitDoor").global_position)}
	for cp in _level.find_children("*", "Checkpoint", true, false):
		key["checkpoint_" + String(cp.name).trim_prefix("Checkpoint").to_snake_case()] = _v2(cp.get_spawn_transform().origin)
	var i := 0
	for spot in _level.find_children("*", "HidingSpot", true, false):
		i += 1
		key["hiding_%d" % i] = _v2(spot.global_position)
	return key


func _routes(key: Dictionary, patrols: Array) -> Dictionary:
	var spawn := _v3(key.spawn)
	var card := _v3(key.card) + Vector3(1.2, -0.9, 0)    # where the player stands to take it
	var door := _v3(key.exit_door) + Vector3(-1.2, -1.2, 0)
	var main_room := Vector3(0, 0, 4)
	var exit_area := Vector3(23, 0, -21)
	var routes := {
		"spawn_to_card_shortest": [spawn, card],
		"spawn_to_card_east_loop": [spawn, exit_area, card],
		"card_to_exit_shortest": [card, door],
		"card_to_exit_via_main_room": [card, main_room, door],
	}
	var result := {}
	for name in routes:
		var waypoints: Array = routes[name]
		var path: Array = []
		for i in range(1, waypoints.size()):
			var leg := NavigationServer3D.map_get_path(_map, waypoints[i - 1], waypoints[i], true)
			path.append_array(leg)
		var length := 0.0
		var samples := 0
		var exposure_sum := 0.0
		var peak := 0.0
		var peak_at := Vector3.ZERO
		var hot := 0
		for i in range(1, path.size()):
			var a: Vector3 = path[i - 1]
			var b: Vector3 = path[i]
			length += a.distance_to(b)
			var n := maxi(1, int(a.distance_to(b) / SAMPLE_STEP))
			for k in n:
				var at := a.lerp(b, float(k) / n)
				var e := _exposure(at, HEAD_STANDING, patrols)
				samples += 1
				exposure_sum += e
				if e > peak:
					peak = e
					peak_at = at
				hot += int(e >= 0.25)
		var reached := not path.is_empty() and Vector2(path[-1].x - waypoints[-1].x, path[-1].z - waypoints[-1].z).length() < 0.8
		result[name] = {"length_m": snappedf(length, 0.1), "mean_exposure_pct": snappedf(100.0 * exposure_sum / maxi(samples, 1), 0.1),
			"peak_exposure_pct": snappedf(100.0 * peak, 0.1), "peak_at": _v2(peak_at), "hot_metres": hot, "reached": reached, "path": path.map(_v2)}
	return result


## Least-exposed paths on the 1 m sample grid (Dijkstra, cost = metres × (1 + 20 × exposure)).
func _add_stealth_routes(routes: Dictionary, key: Dictionary, samples: Array) -> void:
	var index := {}
	for i in samples.size():
		index[Vector2i(roundi(samples[i].x - 0.5), roundi(samples[i].z - 0.5))] = i
	var spawn := _v3(key.spawn)
	var card := _v3(key.card) + Vector3(1.2, -0.9, 0)
	var door := _v3(key.exit_door) + Vector3(-1.2, -1.2, 0)
	var jobs := {"stealth_spawn_to_card": [spawn, card], "stealth_spawn_to_card_east": [spawn, Vector3(23, 0, -21), card],
		"stealth_card_to_exit": [card, door]}
	for name in jobs:
		var waypoints: Array = jobs[name]
		var cells: Array = []
		for i in range(1, waypoints.size()):
			var leg := _dijkstra(samples, index, _nearest(samples, waypoints[i - 1]), _nearest(samples, waypoints[i]))
			if not cells.is_empty() and not leg.is_empty():
				leg.remove_at(0)
			cells.append_array(leg)
		var length := 0.0
		var sum := 0.0
		var sum_crouched := 0.0
		var peak := 0.0
		var peak_at := [0.0, 0.0]
		for i in cells.size():
			var smp: Dictionary = samples[cells[i]]
			if i > 0:
				var prev: Dictionary = samples[cells[i - 1]]
				length += Vector2(smp.x - prev.x, smp.z - prev.z).length()
			sum += smp.standing
			sum_crouched += smp.crouched
			if smp.standing > peak:
				peak = smp.standing
				peak_at = [smp.x, smp.z]
		var n := maxi(cells.size(), 1)
		routes[name] = {"length_m": snappedf(length, 0.1), "mean_exposure_pct": snappedf(100.0 * sum / n, 0.1),
			"mean_exposure_crouched_pct": snappedf(100.0 * sum_crouched / n, 0.1), "peak_exposure_pct": snappedf(100.0 * peak, 0.1),
			"peak_at": peak_at, "hot_metres": cells.filter(func(c): return samples[c].standing >= 0.25).size(),
			"reached": not cells.is_empty(), "path": cells.map(func(c): return [samples[c].x, samples[c].z])}


func _nearest(samples: Array, p: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in samples.size():
		var d := Vector2(samples[i].x - p.x, samples[i].z - p.z).length_squared()
		if d < best_d:
			best_d = d
			best = i
	return best


func _dijkstra(samples: Array, index: Dictionary, start: int, goal: int) -> Array:
	var dist := {start: 0.0}
	var prev := {}
	var open := [start]
	var done := {}
	while not open.is_empty():
		var best_i := 0
		for i in open.size():
			if dist[open[i]] < dist[open[best_i]]:
				best_i = i
		var cur: int = open[best_i]
		open.remove_at(best_i)
		if cur == goal:
			break
		if done.has(cur):
			continue
		done[cur] = true
		var c: Dictionary = samples[cur]
		var cell := Vector2i(roundi(c.x - 0.5), roundi(c.z - 0.5))
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var nb = index.get(cell + Vector2i(dx, dz))
				if nb == null or done.has(nb):
					continue
				var n: Dictionary = samples[nb]
				var from := Vector3(c.x, 0.5, c.z)
				var to := Vector3(n.x, 0.5, n.z)
				if not _space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1)).is_empty():
					continue
				var step: float = from.distance_to(to) * (1.0 + STEALTH_WEIGHT * (c.standing + n.standing) / 2.0)
				var nd: float = dist[cur] + step
				if nd < dist.get(nb, INF):
					dist[nb] = nd
					prev[nb] = cur
					open.append(nb)
	if not dist.has(goal):
		return []
	var path := [goal]
	while path[0] != start:
		path.push_front(prev[path[0]])
	return path


# --- Output ----------------------------------------------------------------------------

func _write_json(path: String, data: Dictionary) -> void:
	var copy := data.duplicate(true)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(copy, "  ", false))


func _write_report(path: String, data: Dictionary) -> void:
	var t: Dictionary = data.totals
	var lines: Array[String] = []
	lines.append("# Level report — %s" % data.version)
	lines.append("")
	lines.append("Generated by `tools/level_report.gd` from the scene, navigation mesh and colliders (Godot %s)." % Engine.get_version_info().string)
	lines.append("Exposure = share of patrol-loop time a guard has the spot inside its 90° view cone, within %d m, with clear line of sight (standing head 1.5 m; crouched 0.85 m). Safe = exposure under 5%%." % SIGHT_RANGE)
	lines.append("")
	lines.append("## Totals")
	lines.append("")
	lines.append("| Walkable samples (1 m) | Mean exposure standing | Mean exposure crouched | Safe floor | Seen at some point | Near cover (≤ %.1f m) | Cover props | Low-cover props | Navmesh polygons |" % COVER_RADIUS)
	lines.append("|---|---|---|---|---|---|---|---|---|")
	lines.append("| %d | %.1f%% | %.1f%% | %.0f%% | %.0f%% | %.0f%% | %d | %d | %d |" % [t.walkable, t.exposure_pct, t.exposure_crouched_pct, t.safe_pct, t.seen_pct, t.near_cover_pct, t.cover_props, t.low_cover_props, t.navmesh_polygons])
	lines.append("")
	lines.append("## Rooms")
	lines.append("")
	lines.append("| Room | Walkable | Mean exposure standing | Mean exposure crouched | Safe floor | Seen at some point | Near cover |")
	lines.append("|---|---|---|---|---|---|---|")
	var names: Array = data.rooms.keys()
	names.sort()
	for room in names:
		var r: Dictionary = data.rooms[room]
		lines.append("| %s | %d | %.1f%% | %.1f%% | %.0f%% | %.0f%% | %.0f%% |" % [room, r.walkable, r.exposure_pct, r.exposure_crouched_pct, r.safe_pct, r.seen_pct, r.cover_pct])
	lines.append("")
	lines.append("## Patrols")
	lines.append("")
	lines.append("| Guard | Points (x, z) | Waits (s) | Loop length | Loop time |")
	lines.append("|---|---|---|---|---|")
	for p in data.patrols:
		lines.append("| %s | %s | %s | %.1f m | %.1f s |" % [p.name, ", ".join(p.points.map(func(v): return "(%.1f, %.1f)" % [v[0], v[1]])),
			", ".join(p.waits.map(func(w): return "%.0f" % w)), p.length_m, p.loop_seconds])
	lines.append("")
	lines.append("## Player routes")
	lines.append("")
	lines.append("| Route | Length | Mean exposure | Peak exposure (at x, z) | Metres at ≥ 25% exposure | Reachable |")
	lines.append("|---|---|---|---|---|---|")
	for name in data.routes:
		var r: Dictionary = data.routes[name]
		lines.append("| %s | %.1f m | %.1f%% | %.0f%% (%.1f, %.1f) | %d | %s |" % [name, r.length_m, r.mean_exposure_pct, r.peak_exposure_pct, r.peak_at[0], r.peak_at[1], r.hot_metres, "yes" if r.reached else "**no**"])
	lines.append("")
	lines.append("## Hiding spots (study carrels)")
	lines.append("")
	lines.append("| Carrel | At (x, z) | Exposure crouched inside | Standing inside |")
	lines.append("|---|---|---|---|")
	for h in data.hiding_spots:
		lines.append("| %s | (%.1f, %.1f) | %.1f%% | %.1f%% |" % [h.name, h.at[0], h.at[1], h.exposure_crouched_pct, h.exposure_standing_pct])
	lines.append("")
	lines.append("## Respawn points (should be 0% exposure)")
	lines.append("")
	lines.append("| Point | At (x, z) | Exposure standing |")
	lines.append("|---|---|---|")
	for r in data.respawn_points:
		lines.append("| %s | (%.1f, %.1f) | %.1f%% |" % [r.name, r.at[0], r.at[1], r.exposure_standing_pct])
	lines.append("")
	lines.append("## Key points (x, z)")
	lines.append("")
	for k in data.key_points:
		var v: Array = data.key_points[k]
		lines.append("- %s: (%.1f, %.1f)" % [k, v[0], v[1]])
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")


func _draw_map(path: String, data: Dictionary) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1500, 1200)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var canvas: Node2D = MapCanvas.new()
	canvas.data = data
	canvas.canvas_size = Vector2(viewport.size)
	viewport.add_child(canvas)
	root.add_child(viewport)
	for i in 4:
		await process_frame
	viewport.get_texture().get_image().save_png(path)
	print("Map → %s" % path)


# --- Helpers ---------------------------------------------------------------------------

func _wait_for_navigation() -> bool:
	for i in 240:
		await physics_frame
		if NavigationServer3D.map_get_iteration_id(_map) == 0:
			continue
		var p := NavigationServer3D.map_get_closest_point(_map, Vector3(0, 0, 18))
		if Vector2(p.x, p.z - 18).length() < 1.0:
			return true
	return false


func _args() -> Dictionary:
	var result := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			result[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	return result


func _rect_entry(e: Dictionary) -> Dictionary:
	var r: Rect2 = e.rect
	var out := e.duplicate()
	out.rect = [snappedf(r.position.x, 0.01), snappedf(r.position.y, 0.01), snappedf(r.size.x, 0.01), snappedf(r.size.y, 0.01)]
	if out.has("top"):
		out.top = snappedf(out.top, 0.01)
	return out


static func _v2(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.z, 0.01)]


static func _v3(a: Array) -> Vector3:
	return Vector3(a[0], 0, a[1])


static func _pct(n: int, total: int) -> float:
	return snappedf(100.0 * n / maxi(total, 1), 0.1)
