extends SceneTree

## Development tool: where the Expanded Library's guards can see the player,
## over a long patrol run with no player in the level. For the balancing pass.
##
##   godot --headless --path . --script res://tools/expanded/coverage_map.gd -- --seconds=600 --scale=4 --out=docs/expanded/v3/coverage
##
## Samples every named area of the layout on a 1.5 m grid (points on the
## navmesh). Every 0.25 s of game time a sample counts as watched if a guard
## has it in view (GuardVision.is_in_view: its cone and range) with a clear
## line of sight on the world layer, for a standing (1.5 m) and a crouched
## (0.85 m) head. Per sample it records:
##   - exposure: the share of time watched;
##   - the longest stretch watched without a break, and the longest unwatched
##     window (how long a player can wait for a gap and then still have one).
## Per doorway (every opening in the layout's walls) it records how often a
## guard stands in it (within 1 m) and the longest time one stays: a doorway a
## guard occupies for long stretches blocks the route.
## Hearing: every second, a sample counts as "a sprint is heard" if a guard is
## within a running footstep's radius (12 m), halved when a wall or floor is
## between (the existing hearing rule): where nobody can ever hear a sprint,
## noisy play goes unpunished.
## The mission's access doors are opened first (open doors are the worst case
## for sight). Writes summary.json, report.md and heat maps (ground.png,
## upper.png: green = never watched → red = always watched; black = walls).

const Layout := preload("res://tools/expanded/expanded_layout.gd")
const SCENE := "res://scenes/level/expanded_library.tscn"
const GRID := 1.5
const SAMPLE_EVERY := 0.25
const HEAD_STANDING := 1.5
const HEAD_CROUCHED := 0.85
const DOORWAY_RADIUS := 1.0
const PX := 10   # heat map pixels per metre

var _level: Node3D
var _space: PhysicsDirectSpaceState3D
var _guards: Array[Guard] = []
var _now := 0.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var seconds := 600.0
	var scale := 4.0
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seconds="):
			seconds = float(a.trim_prefix("--seconds="))
		elif a.begins_with("--scale="):
			scale = float(a.trim_prefix("--scale="))
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	_level = (load(SCENE) as PackedScene).instantiate()
	var player := _level.get_node("Player")
	_level.remove_child(player)
	player.free()
	root.add_child(_level)
	for i in 30:
		await physics_frame
	_space = _level.get_world_3d().direct_space_state
	for door in _level.get_tree().get_nodes_in_group("access_doors"):
		door.open()
	for g in _level.get_node("Guards").get_children():
		if g is Guard:
			_guards.append(g)
	var map := _level.get_world_3d().navigation_map
	# Samples per area.
	var samples: Array[Dictionary] = []
	for z in Layout.ZONES:
		var y := Layout.floor_y(z.floor)
		for area in z.areas:
			var r: Array = area.rect
			var x: float = r[0] + GRID / 2.0
			while x < r[2]:
				var zz: float = r[1] + GRID / 2.0
				while zz < r[3]:
					var want := Vector3(x, y, zz)
					var p := NavigationServer3D.map_get_closest_point(map, want)
					if Vector2(p.x - x, p.z - zz).length() < 0.4 and absf(p.y - y) < 0.8:
						samples.append({"zone": z.id, "area": area.name, "floor": z.floor, "at": Vector3(x, y, zz),
							"s": 0, "c": 0, "run": 0.0, "max_run": 0.0, "gap": 0.0, "max_gap": 0.0, "heard": 0})
					zz += GRID
				x += GRID
	# Routes (the layout's ROUTES, sampled every metre along the navmesh).
	var routes: Array[Dictionary] = []
	for route in Layout.ROUTES:
		var pts: Array = route.points
		var rs := {"name": route.name, "length": 0.0, "points": PackedVector3Array(), "watched": PackedInt32Array()}
		for i in pts.size() - 1:
			var path := NavigationServer3D.map_get_path(map, pts[i], pts[i + 1], true)
			for k in range(1, path.size()):
				var a := path[k - 1]
				var b := path[k]
				rs.length += a.distance_to(b)
				var n := maxi(1, int(a.distance_to(b)))
				for j in n:
					rs.points.append(a.lerp(b, float(j) / n) - Vector3(0, 0.45, 0))
		rs.watched.resize(rs.points.size())
		routes.append(rs)
	# Doorways.
	var doorways: Array[Dictionary] = []
	for wall in Layout.WALLS:
		for o in wall.get("openings", []):
			if o.type == "exit":
				continue
			var c := Layout.opening_centre(wall, o)
			if o.type == "stair":
				c += Vector3(0, 0, -1.2)   # stair tops: the slab side
			doorways.append({"name": o.name, "type": o.type, "at": c, "busy": 0, "run": 0.0, "max_run": 0.0})
	Engine.time_scale = scale
	var next_sample := 0.0
	var next_hear := 0.0
	var hear_ticks := 0
	var ticks := 0
	var started := Time.get_ticks_msec()
	while _now < seconds:
		await physics_frame
		_now += scale / Engine.physics_ticks_per_second
		if _now >= next_hear:
			next_hear += 1.0
			hear_ticks += 1
			for s in samples:
				if _heard(s.at):
					s.heard += 1
		if _now < next_sample:
			continue
		next_sample += SAMPLE_EVERY
		ticks += 1
		for s in samples:
			var watched := _watched(s.at + Vector3(0, HEAD_STANDING, 0))
			if watched:
				s.s += 1
				s.run += SAMPLE_EVERY
				s.max_run = maxf(s.max_run, s.run)
				s.gap = 0.0
			else:
				s.run = 0.0
				s.gap += SAMPLE_EVERY
				s.max_gap = maxf(s.max_gap, s.gap)
			if _watched(s.at + Vector3(0, HEAD_CROUCHED, 0)):
				s.c += 1
		for rs in routes:
			for i in rs.points.size():
				if _watched(rs.points[i] + Vector3(0, HEAD_STANDING, 0)):
					rs.watched[i] += 1
		for d in doorways:
			var busy := false
			for g in _guards:
				var off: Vector3 = g.global_position - d.at
				if absf(off.y) < 1.5 and Vector2(off.x, off.z).length() < DOORWAY_RADIUS:
					busy = true
					break
			if busy:
				d.busy += 1
				d.run += SAMPLE_EVERY
				d.max_run = maxf(d.max_run, d.run)
			else:
				d.run = 0.0
	Engine.time_scale = 1.0
	var real := (Time.get_ticks_msec() - started) / 1000.0
	# Per area.
	var areas := {}
	for s in samples:
		var key := "%s · %s" % [s.zone, s.area]
		if not areas.has(key):
			areas[key] = {"zone": s.zone, "area": s.area, "floor": s.floor, "samples": 0, "ever": 0, "safe": 0,
				"sum_s": 0.0, "sum_c": 0.0, "max_s": 0.0, "max_run": 0.0, "min_max_gap": INF, "sum_h": 0.0, "never_heard": 0}
		var a: Dictionary = areas[key]
		var e: float = s.s / float(ticks)
		a.samples += 1
		a.ever += 1 if s.s > 0 else 0
		a.safe += 1 if e < 0.05 else 0
		a.sum_s += e
		a.sum_c += s.c / float(ticks)
		a.max_s = maxf(a.max_s, e)
		a.max_run = maxf(a.max_run, s.max_run)
		a.min_max_gap = minf(a.min_max_gap, s.max_gap if s.s > 0 else seconds)
		a.sum_h += s.heard / float(maxi(hear_ticks, 1))
		a.never_heard += 1 if s.heard == 0 else 0
	var area_rows := []
	for key in areas:
		var a: Dictionary = areas[key]
		area_rows.append({"area": key, "floor": a.floor, "samples": a.samples,
			"ever_seen_pct": 100.0 * a.ever / a.samples, "safe_pct": 100.0 * a.safe / a.samples,
			"mean_standing_pct": 100.0 * a.sum_s / a.samples, "mean_crouched_pct": 100.0 * a.sum_c / a.samples,
			"peak_standing_pct": 100.0 * a.max_s, "longest_watch_s": a.max_run, "worst_spot_longest_gap_s": a.min_max_gap,
			"sprint_heard_pct": 100.0 * a.sum_h / a.samples, "never_heard_pct": 100.0 * a.never_heard / a.samples})
	var door_rows := []
	for d in doorways:
		door_rows.append({"doorway": d.name, "type": d.type, "occupied_pct": 100.0 * d.busy / float(ticks), "longest_occupied_s": d.max_run})
	var route_rows := []
	for rs in routes:
		var total := 0.0
		var peak := 0.0
		var ever := 0
		for w in rs.watched:
			var e: float = w / float(ticks)
			total += e
			peak = maxf(peak, e)
			ever += 1 if w > 0 else 0
		var n := maxi(rs.points.size(), 1)
		# Expected watched metres when walking it once at 3.5 m/s: sum of per-metre exposure.
		route_rows.append({"route": rs.name, "length_m": rs.length, "mean_exposure_pct": 100.0 * total / n,
			"peak_pct": 100.0 * peak, "ever_seen_pct": 100.0 * ever / n, "exposed_metres": total})
	var summary := {"date": Time.get_datetime_string_from_system(), "layout": Layout.VERSION, "engine": Engine.get_version_info().string,
		"game_seconds": seconds, "time_scale": scale, "real_seconds": real, "guards": _guards.size(), "samples": samples.size(),
		"areas": area_rows, "doorways": door_rows, "routes": route_rows}
	print("Coverage %.0f s (×%.0f, %.0f s real), %d guards, %d samples in %d areas" % [seconds, scale, real, _guards.size(), samples.size(), area_rows.size()])
	for r in area_rows:
		print("  %-28s ever %3.0f%%  safe %3.0f%%  mean %4.1f%% (crouched %4.1f%%)  peak %3.0f%%  longest watch %5.1f s  sprint heard %3.0f%%" % [
			r.area, r.ever_seen_pct, r.safe_pct, r.mean_standing_pct, r.mean_crouched_pct, r.peak_standing_pct, r.longest_watch_s, r.sprint_heard_pct])
	for r in route_rows:
		print("  route %-60s %4.0f m, mean exposure %4.1f%%, peak %3.0f%%, exposed metres %4.1f" % [r.route, r.length_m, r.mean_exposure_pct, r.peak_pct, r.exposed_metres])
	for r in door_rows:
		if r.occupied_pct > 0.0:
			print("  doorway %-34s occupied %4.1f%%, longest %4.1f s" % [r.doorway, r.occupied_pct, r.longest_occupied_s])
	if out != "":
		var dir := ProjectSettings.globalize_path("res://" + out)
		DirAccess.make_dir_recursive_absolute(dir)
		var f := FileAccess.open(dir.path_join("summary.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(summary, "  "))
		f.close()
		_write_report(dir.path_join("report.md"), summary)
		for floor_name in ["ground", "upper"]:
			_heat_map(samples, ticks, floor_name).save_png(dir.path_join(floor_name + ".png"))
	_level.queue_free()
	for i in 30:
		OS.delay_msec(5)
		await process_frame
	quit(0)


func _watched(head: Vector3) -> bool:
	for g in _guards:
		if not g.vision.is_in_view(head):
			continue
		if _space.intersect_ray(PhysicsRayQueryParameters3D.create(g.vision.global_position, head, 1)).is_empty():
			return true
	return false


func _heard(p: Vector3) -> bool:
	for g in _guards:
		var d := g.global_position.distance_to(p)
		if d > 12.0:
			continue
		if d < 6.0:
			return true
		var q := PhysicsRayQueryParameters3D.create(g.global_position + Vector3(0, 1.0, 0), p + Vector3(0, 1.0, 0), 1)
		if _space.intersect_ray(q).is_empty():
			return true
	return false


func _heat_map(samples: Array[Dictionary], ticks: int, floor_name: String) -> Image:
	var w := 72 * PX + 2 * PX
	var h := 62 * PX + 2 * PX
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.12, 0.12, 0.14))
	for s in samples:
		if s.floor != floor_name:
			continue
		var e: float = s.s / float(ticks)
		var colour := Color(0.2, 0.75, 0.3).lerp(Color(1.0, 0.85, 0.1), clampf(e / 0.15, 0.0, 1.0))
		if e > 0.15:
			colour = Color(1.0, 0.85, 0.1).lerp(Color(0.9, 0.1, 0.1), clampf((e - 0.15) / 0.35, 0.0, 1.0))
		if s.s == 0:
			colour = Color(0.15, 0.45, 0.25)
		var p := _px(s.at.x - GRID / 2.0, s.at.z - GRID / 2.0)
		img.fill_rect(Rect2i(p, Vector2i(int(GRID * PX) - 1, int(GRID * PX) - 1)), colour)
	for wall in Layout.WALLS:
		if wall.floor != floor_name:
			continue
		var a := _px(wall.a[0], wall.a[1])
		var b := _px(wall.b[0], wall.b[1])
		var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
		for i in steps + 1:
			var p := Vector2i(a) + Vector2i(roundi((b.x - a.x) * i / float(maxi(steps, 1))), roundi((b.y - a.y) * i / float(maxi(steps, 1))))
			var blocked := true
			for o in wall.get("openings", []):
				var along: float = (p.x / float(PX) - 37.0) if wall.a[1] == wall.b[1] else (p.y / float(PX) - 29.0)
				if absf(along - o.at) < o.width / 2.0:
					blocked = false
			var colour := Color.BLACK if blocked else Color(0.6, 0.6, 0.65)
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var q := p + Vector2i(dx, dy)
					if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h:
						img.set_pixelv(q, colour)
	return img


## World x/z → heat map pixel (x −37…37, z −29…35).
func _px(x: float, z: float) -> Vector2i:
	return Vector2i(int((x + 37.0) * PX), int((z + 29.0) * PX))


func _write_report(path: String, s: Dictionary) -> void:
	var lines := ["# Coverage — Expanded Library layout %s" % s.layout, "",
		"%s · %s · %.0f s game time at ×%.0f · %d guards · %d samples on a %.1f m grid · access doors open · no player" % [
			s.date, s.engine, s.game_seconds, s.time_scale, s.guards, s.samples, GRID], "",
		"Watched = inside a guard's view cone and range with a clear line of sight to a standing (1.5 m) or crouched (0.85 m) head.", "",
		"| Area | Floor | Samples | Ever seen | Safe (<5%) | Mean standing | Mean crouched | Peak | Longest watch (s) | Worst spot's longest gap (s) | Sprint heard |",
		"|---|---|---|---|---|---|---|---|---|---|---|"]
	for r in s.areas:
		lines.append("| %s | %s | %d | %.0f%% | %.0f%% | %.1f%% | %.1f%% | %.0f%% | %.1f | %.1f | %.0f%% |" % [r.area, r.floor, r.samples,
			r.ever_seen_pct, r.safe_pct, r.mean_standing_pct, r.mean_crouched_pct, r.peak_standing_pct, r.longest_watch_s, r.worst_spot_longest_gap_s, r.sprint_heard_pct])
	lines.append_array(["", "**Routes** (sampled every metre along the navmesh; 'exposed metres' = the sum of each metre's exposure, the expected number of watched metres on one pass):", "",
		"| Route | Length | Mean exposure | Peak | Ever seen | Exposed metres |", "|---|---|---|---|---|---|"])
	for r in s.routes:
		lines.append("| %s | %.0f m | %.1f%% | %.0f%% | %.0f%% | %.1f |" % [r.route, r.length_m, r.mean_exposure_pct, r.peak_pct, r.ever_seen_pct, r.exposed_metres])
	lines.append_array(["", "**Doorways guards stand in** (within %.0f m of the centre):" % DOORWAY_RADIUS, "",
		"| Doorway | Type | Occupied | Longest stay (s) |", "|---|---|---|---|"])
	for r in s.doorways:
		if r.occupied_pct > 0.0:
			lines.append("| %s | %s | %.1f%% | %.1f |" % [r.doorway, r.type, r.occupied_pct, r.longest_occupied_s])
	lines.append_array(["", "Heat maps: `ground.png`, `upper.png` (dark green: never watched; green → yellow: up to 15%% of the time; yellow → red: 15–50%%+; black: walls, grey: openings)." % [], ""])
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
