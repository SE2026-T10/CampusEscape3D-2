extends SceneTree

## Development tool: a long patrol soak of the Expanded Library's six guards,
## with no player, to show that the patrols keep working and how much of the
## intended player route they watch.
##
##   godot --headless --path . --script res://tools/expanded/patrol_soak.gd -- --seconds=900 --scale=4 --out=docs/expanded/v1/soak
##
## --seconds is game time; --scale speeds time up (Engine.time_scale), as the
## test suite does. Writes summary.json and report.md, prints one line, exits
## 0 when no guard got stuck or left PATROL, 1 otherwise.
##
## Route exposure: the main route (spawn → O1 … O5) is sampled every metre
## along the navmesh. Every 0.25 s of game time, each sample counts as watched
## if a guard has it inside its 90° / 14 m view cone with a clear line of sight
## (the same geometry GuardVision uses) to a standing (1.5 m) or crouched
## (0.85 m) head. Exposure of a sample is the share of time it is watched.
## The mission's access doors are opened first (the route goes through them;
## open doors are the worst case for sight). The checkpoints' respawn points
## are sampled the same way (standing head).

const Layout := preload("res://tools/expanded/expanded_layout.gd")
const SCENE := "res://scenes/level/expanded_library.tscn"
const FOV := 90.0
const RANGE := 14.0
const EYE := 1.6
const HEAD_STANDING := 1.5
const HEAD_CROUCHED := 0.85
const SAMPLE_EVERY := 0.25

var _level: Node3D
var _space: PhysicsDirectSpaceState3D


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var seconds := 900.0
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
	var respawns := {}
	for cp in _level.get_tree().get_nodes_in_group("checkpoints"):
		respawns[cp.checkpoint_name] = {"at": (cp as Checkpoint).get_spawn_transform().origin, "watched": 0}
	var map := _level.get_world_3d().navigation_map
	var samples := _route_samples(map)
	var standing := PackedFloat32Array()
	var crouched := PackedFloat32Array()
	standing.resize(samples.size())
	crouched.resize(samples.size())
	var guards: Array[Guard] = []
	var stats := {}
	for g in _level.get_node("Guards").get_children():
		if g is Guard:
			guards.append(g)
			var entry := {"points": g.patrol_route.get_point_count(), "reached": 0, "stuck": 0, "state_changes": 0,
				"longest_between_points_s": 0.0, "_last": 0.0}
			stats[g.name] = entry
			g.patrol_point_reached.connect(func(_i):
				entry.reached += 1
				entry.longest_between_points_s = maxf(entry.longest_between_points_s, _now - entry._last)
				entry._last = _now)
			g.got_stuck.connect(func(_i): entry.stuck += 1)
			g.ai_state_changed.connect(func(_a, _b, _r): entry.state_changes += 1)
	Engine.time_scale = scale
	var next_sample := 0.0
	var ticks := 0
	var started := Time.get_ticks_msec()
	while _now < seconds:
		await physics_frame
		_now += scale / Engine.physics_ticks_per_second
		if _now >= next_sample:
			next_sample += SAMPLE_EVERY
			ticks += 1
			for i in samples.size():
				var p: Vector3 = samples[i]
				if _watched(guards, p + Vector3(0, HEAD_STANDING, 0)):
					standing[i] += 1.0
				if _watched(guards, p + Vector3(0, HEAD_CROUCHED, 0)):
					crouched[i] += 1.0
			for name in respawns:
				if _watched(guards, respawns[name].at + Vector3(0, HEAD_STANDING, 0)):
					respawns[name].watched += 1
	Engine.time_scale = 1.0
	var real := (Time.get_ticks_msec() - started) / 1000.0
	# Results.
	var guard_rows := {}
	var ok := true
	for name in stats:
		var e: Dictionary = stats[name]
		e.erase("_last")
		e["loops"] = floori(e.reached / float(e.points))
		guard_rows[name] = e
		ok = ok and e.stuck == 0 and e.state_changes == 0
	var checkpoint_rows := {}
	for name in respawns:
		checkpoint_rows[name] = {"respawn": [snappedf(respawns[name].at.x, 0.01), snappedf(respawns[name].at.y, 0.01), snappedf(respawns[name].at.z, 0.01)],
			"watched_pct": 100.0 * respawns[name].watched / maxf(ticks, 1)}
	var exposure := []
	for i in samples.size():
		exposure.append({"at": [snappedf(samples[i].x, 0.01), snappedf(samples[i].y, 0.01), snappedf(samples[i].z, 0.01)],
			"standing": standing[i] / ticks, "crouched": crouched[i] / ticks})
	var summary := {
		"date": Time.get_datetime_string_from_system(), "layout": Layout.VERSION, "engine": Engine.get_version_info().string,
		"game_seconds": seconds, "time_scale": scale, "real_seconds": real, "guards": guard_rows,
		"route": _route_stats(exposure), "checkpoints": checkpoint_rows, "samples": exposure,
	}
	print("Patrol soak %.0f s (×%.0f, %.0f s real): %s; route %d samples, ever seen standing %.0f%%, mean exposure %.1f%% (crouched %.1f%%), max %.0f%%, safe (<5%%) %.0f%%" % [
		seconds, scale, real, ", ".join(guard_rows.keys().map(func(k): return "%s %d loops %d stuck" % [k, guard_rows[k].loops, guard_rows[k].stuck])),
		samples.size(), summary.route.ever_seen_pct, summary.route.mean_standing_pct, summary.route.mean_crouched_pct,
		summary.route.max_standing_pct, summary.route.safe_pct])
	print("Checkpoint respawn points watched: %s" % ", ".join(checkpoint_rows.keys().map(func(k): return "%s %.1f%%" % [k, checkpoint_rows[k].watched_pct])))
	if out != "":
		var dir := ProjectSettings.globalize_path("res://" + out)
		DirAccess.make_dir_recursive_absolute(dir)
		var f := FileAccess.open(dir.path_join("summary.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(summary, "  "))
		f.close()
		_write_report(dir.path_join("report.md"), summary)
	# Free the level (its audio players hold streams) before exiting.
	_level.queue_free()
	for i in 30:
		OS.delay_msec(5)
		await process_frame
	quit(0 if ok else 1)


var _now := 0.0


## Is `head` inside some guard's view cone and range, with a clear line of sight (world layer)?
func _watched(guards: Array[Guard], head: Vector3) -> bool:
	for g in guards:
		var eye := g.global_position + Vector3(0, EYE, 0)
		var to := head - eye
		if to.length() > RANGE:
			continue
		var forward := -g.global_basis.z
		if rad_to_deg(forward.angle_to(to)) > FOV / 2.0:
			continue
		if _space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, head, 1)).is_empty():
			return true
	return false


## Points every metre along the navmesh path of the main route.
func _route_samples(map: RID) -> PackedVector3Array:
	var out := PackedVector3Array()
	var points: Array = Layout.ROUTES[0].points
	for i in points.size() - 1:
		var path := NavigationServer3D.map_get_path(map, points[i], points[i + 1], true)
		for k in range(1, path.size()):
			var a := path[k - 1]
			var b := path[k]
			var n := maxi(1, int(a.distance_to(b)))
			for s in n:
				out.append(a.lerp(b, float(s) / n) - Vector3(0, 0.45, 0))   # navmesh surface → floor
	return out


func _route_stats(exposure: Array) -> Dictionary:
	var ever := 0
	var safe := 0
	var total := 0.0
	var total_c := 0.0
	var peak := 0.0
	for e in exposure:
		if e.standing > 0.0:
			ever += 1
		if e.standing < 0.05:
			safe += 1
		total += e.standing
		total_c += e.crouched
		peak = maxf(peak, e.standing)
	var n := maxf(exposure.size(), 1)
	return {"samples": exposure.size(), "ever_seen_pct": 100.0 * ever / n, "safe_pct": 100.0 * safe / n,
		"mean_standing_pct": 100.0 * total / n, "mean_crouched_pct": 100.0 * total_c / n, "max_standing_pct": 100.0 * peak}


func _write_report(path: String, s: Dictionary) -> void:
	var lines := ["# Patrol soak — Expanded Library layout %s" % s.layout, "",
		"%s · %s · %.0f s game time at ×%.0f (%.0f s real) · no player in the level" % [s.date, s.engine, s.game_seconds, s.time_scale, s.real_seconds], "",
		"| Guard | Points | Points reached | Full loops | Stuck events | State changes | Longest between points (s) |", "|---|---|---|---|---|---|---|"]
	for name in s.guards:
		var g: Dictionary = s.guards[name]
		lines.append("| %s | %d | %d | %d | %d | %d | %.1f |" % [name, g.points, g.reached, g.loops, g.stuck, g.state_changes, g.longest_between_points_s])
	var r: Dictionary = s.route
	lines.append_array(["", "**Main route exposure** (%d samples, one per metre along the navmesh):" % r.samples, "",
		"| Measure | Value |", "|---|---|",
		"| ever seen (standing) | %.0f%% of the route |" % r.ever_seen_pct,
		"| safe (watched < 5%% of the time) | %.0f%% of the route |" % r.safe_pct,
		"| mean exposure standing / crouched | %.1f%% / %.1f%% |" % [r.mean_standing_pct, r.mean_crouched_pct],
		"| most exposed metre (standing) | %.0f%% of the time |" % r.max_standing_pct, ""])
	if s.has("checkpoints"):
		lines.append_array(["**Checkpoint respawn points** (standing head):", "", "| Checkpoint | Respawn point | Watched |", "|---|---|---|"])
		for name in s.checkpoints:
			var c: Dictionary = s.checkpoints[name]
			lines.append("| %s | %s | %.1f%% of the time |" % [name, c.respawn, c.watched_pct])
		lines.append("")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
