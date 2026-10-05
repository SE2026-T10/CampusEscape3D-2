extends SceneTree

## Reproducible performance benchmark for the library level.
##
##   godot --path . --script res://tools/benchmark.gd -- --scenario=normal --out=docs/performance/runs/my_run
##   godot --headless --fixed-fps 60 --path . --script res://tools/benchmark.gd -- --scenario=stress
##
## Two ways to run it:
##   - rendering (a window): real-time physics, uncapped frame rate, vsync off;
##     measures what a player gets, including rendering
##   - headless with --fixed-fps 60: no rendering, and every frame is exactly one
##     physics tick, run as fast as the CPU allows; frame time is then the full
##     CPU cost of one game frame (scripts, physics, navigation, animation)
##
## Options (all optional):
##   --scenario=normal|several|stress   3, 8 or 24 guards (default normal)
##   --npcs=N         any guard count instead (the level's 3 plus N-3 extra)
##   --seconds=S      measured time in simulated seconds (default 30)
##   --warmup=S       simulated seconds before measuring (default 5)
##   --out=PATH       folder for frames.csv, summary.json, summary.md (+ screenshot)
##   --label=TEXT     a name for this run in the summary
##   --disable=a,b    diagnostics only: switch parts off to see what they cost:
##                    omni (omni lights), spot, shadows (sun shadows), books,
##                    ceilings, dressing (all decoration), hud (all UI layers),
##                    book_shadows (books stop casting shadows), shadow_splits
##                    (sun shadow 2 splits instead of 4), shadow_distance (40 m),
##                    shadow_size (sun shadow atlas 2048 instead of 4096)
##
## What happens, the same way every run:
##   - the real library scene loads; the player stands at the spawn (no input)
##   - extra guards are added on the level's three patrol routes, spread along them
##   - a benchmark camera flies a fixed loop through every room (driven by
##     simulated time, so every run sees the same path)
##   - every 4 s a RUN noise is emitted at the next point of a fixed list, so
##     guards investigate (navigation and AI work, not just patrolling)
## Measured every rendered frame: frame time; time in all physics-tick scripts
## and all process scripts (probes before and after every other node); render
## CPU and GPU time (when the renderer reports them); the rest of the frame
## ("other": physics engine step, navigation, scene tree, sync); Godot's own
## process / physics / navigation monitors (these are the slowest frame of
## the last second, so they are kept as a cross-check only); draw calls,
## objects, primitives, memory, object counts, physics and navigation counts,
## and the time spent in guard scripts (AI + vision + hearing) and in guard
## presentation (animation), using timing probes around them.
## Vsync is turned off and the frame rate uncapped. Headless runs measure the
## CPU side only (no rendering). Every time a guard gives up on a patrol point
## because it is stuck, it is recorded in summary.json (stuck_events).
## Nothing here changes the game itself.

const LEVEL := "res://scenes/level/library_graybox.tscn"
const GUARD := "res://scenes/npc/guard.tscn"
const SCENARIOS := {"normal": 3, "several": 8, "stress": 24}
const PHYSICS_HZ := 60.0
## Camera loop through the level (x, z at eye height 1.6).
const CAMERA_PATH := [
	Vector2(0, 19), Vector2(0, 8), Vector2(-6, 2), Vector2(-10.5, -6), Vector2(-10.5, -14),
	Vector2(-6, -20), Vector2(4, -22.5), Vector2(14, -22.5), Vector2(22.5, -16),
	Vector2(22.5, -2), Vector2(12, 4), Vector2(4, 10), Vector2(0, 19)]
const CAMERA_SPEED := 3.0
## Noise points (RUN), one every NOISE_EVERY seconds, cycling.
const NOISE_POINTS := [Vector3(6, 0, 4), Vector3(-6, 0, -2), Vector3(-9, 0, -20),
	Vector3(10, 0, -22.5), Vector3(22.5, 0, -10), Vector3(2, 0, -4)]
const NOISE_EVERY := 4.0
## Physics / process priorities used to time guard scripts in isolation.
const GUARD_BAND := 1000
## Priorities of the probes around all scripts.
const FIRST := -1000000
const LAST := 1000000


class Probe extends Node:
	## Records Time.get_ticks_usec() when its physics or process callback runs.
	var stamp := 0
	var physics := true

	func _init(p_physics: bool, priority: int) -> void:
		physics = p_physics
		process_mode = Node.PROCESS_MODE_ALWAYS
		if physics:
			process_physics_priority = priority
		else:
			process_priority = priority

	func _ready() -> void:
		set_physics_process(physics)
		set_process(not physics)

	func _physics_process(_delta: float) -> void:
		stamp = Time.get_ticks_usec()

	func _process(_delta: float) -> void:
		stamp = Time.get_ticks_usec()


var _scenario := "normal"
var _npcs := 3
var _seconds := 30.0
var _warmup := 5.0
var _out := ""
var _label := ""
var _disable: PackedStringArray = []

var _level: Node3D
var _camera: Camera3D
var _sim_time := 0.0
var _ticks := 0
var _measuring := false
## Samples, one row of COLUMNS per frame, in one flat array allocated before
## measuring starts, so the benchmark's own storage doesn't show up as memory
## growth during the run.
var _data := PackedFloat64Array()
var _row_count := 0
const MAX_ROWS := 40000
var _last_frame_usec := 0
var _ai_usec_this_frame := 0
var _ai_ticks_this_frame := 0
var _phys_usec_this_frame := 0
var _phys_start: Probe
var _phys_end: Probe
var _proc_start: Probe
var _proc_end: Probe
var _ai_start: Probe
var _ai_end: Probe
var _pres_start: Probe
var _pres_end: Probe
var _next_noise := 0.0
var _noise_index := 0
var _status_changes := {}
var _caught := 0
## Every time a guard gave up on a patrol point because it was stuck.
var _stuck_events: Array = []
var _rendering := false
var _screenshot_taken := false
var _start_objects := 0
var _start_static := 0
var _vp: RID

const COLUMNS := ["frame_ms", "scripts_physics_ms", "scripts_process_ms", "guard_ai_ms", "guard_presentation_ms",
	"render_cpu_ms", "render_gpu_ms", "other_ms", "physics_ticks",
	"process_max1s_ms", "physics_max1s_ms", "navigation_max1s_ms", "draw_calls", "objects", "primitives",
	"static_mem_mb", "video_mem_mb", "object_count", "node_count", "orphan_nodes",
	"physics_active", "collision_pairs", "nav_agents", "guards_moving"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_parse_args()
	_rendering = DisplayServer.get_name() != "headless"
	Engine.max_fps = 0
	# Headless runs otherwise sleep 6.9 ms every frame (low-processor sleep).
	OS.low_processor_usage_mode_sleep_usec = 0
	if _rendering:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_vp = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)

	_level = (load(LEVEL) as PackedScene).instantiate()
	root.add_child(_level)
	_add_extra_guards()
	_apply_disable()
	_setup_probes()
	_camera = Camera3D.new()
	_camera.fov = 75.0
	_camera.near = 0.05
	_level.add_child(_camera)
	_camera.current = true
	var director := StealthDirector.find(_level)
	director.status_changed.connect(func(_a, b):
		var key: String = StealthDirector.Status.keys()[b]
		_status_changes[key] = _status_changes.get(key, 0) + 1)
	director.player_caught.connect(func(_g): _caught += 1)
	for g in _guards():
		g.got_stuck.connect(func(point: int): _stuck_events.append({"t": snappedf(_sim_time, 0.01), "guard": String(g.name),
			"point": point, "at": [snappedf(g.global_position.x, 0.01), snappedf(g.global_position.z, 0.01)],
			"state": g.machine.get_state_name() if g.machine else "-"}))
	physics_frame.connect(_on_physics_tick)
	process_frame.connect(_on_frame)

	# Wait for the guards to start, then spread the extra ones along their routes.
	for i in 120:
		await physics_frame
	_spread_extra_guards()
	print("benchmark: %s, %d guards, %s, %d s (+%d s warm-up)" % [_label, _guards().size(),
		"rendering" if _rendering else "headless", _seconds, _warmup])


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"scenario":
				_scenario = kv[1]
				_npcs = SCENARIOS.get(_scenario, 3)
			"npcs":
				_npcs = maxi(int(kv[1]), 0)
				_scenario = "custom"
			"seconds":
				_seconds = float(kv[1])
			"warmup":
				_warmup = float(kv[1])
			"out":
				_out = "res://" + kv[1].trim_prefix("res://")
			"label":
				_label = kv[1]
			"disable":
				_disable = kv[1].split(",", false)
	if _label == "":
		_label = "%s_%d" % [_scenario, _npcs]


func _add_extra_guards() -> void:
	var guards_node := _level.get_node("Guards")
	var routes: Array[PatrolRoute] = []
	for child in guards_node.get_children():
		if child is PatrolRoute:
			routes.append(child)
	var existing := 0
	for child in guards_node.get_children():
		if child is Guard:
			existing += 1
	if _npcs < existing:
		# Fewer guards than the level has: remove from the end.
		var guards: Array = guards_node.get_children().filter(func(c): return c is Guard)
		for i in range(_npcs, existing):
			guards_node.remove_child(guards[i])
			guards[i].free()
		return
	var scene := load(GUARD) as PackedScene
	for i in _npcs - existing:
		var route := routes[i % routes.size()]
		var guard := scene.instantiate() as Guard
		guard.name = "BenchGuard%02d" % (i + 1)
		guard.patrol_route = route
		var count := route.get_point_count()
		# Start slots along the route at quarter steps: ¼ of the way from point 0
		# to 1, ½, ¾, point 1, … — never point 0, where the level's own guard
		# starts. Each extra guard on a route takes the next free slot (4 × points
		# − 1 slots per route), so no two guards start in the same place.
		var lap := i / routes.size()
		var slots := count * 4 - 1
		if lap >= slots:
			push_warning("benchmark: more guards than start slots on %s; some start together." % route.name)
		var slot := lap % slots + 1
		var a := (slot / 4) % count
		var t := 0.25 * float(slot % 4)
		var start := route.get_point_position(a).lerp(route.get_point_position((a + 1) % count), t)
		guard.position = start + Vector3(0, 0.05, 0)  # the Guards node sits at the origin
		guard.set_meta("bench_start_point", (a + 1) % count if t > 0.0 else a)  # walk on to the next point
		guards_node.add_child(guard)


func _apply_disable() -> void:
	for what in _disable:
		match what:
			"omni":
				for n in _level.find_children("*", "OmniLight3D", true, false):
					n.visible = false
			"spot":
				for n in _level.find_children("*", "SpotLight3D", true, false):
					n.visible = false
			"shadows":
				for n in _level.find_children("*", "Light3D", true, false):
					n.shadow_enabled = false
			"books":
				for n in _level.find_children("*", "ShelfBooks", true, false):
					n.visible = false
			"ceilings":
				var c := _level.get_node_or_null("Dressing/Ceilings")
				if c:
					c.visible = false
			"dressing":
				_level.get_node("Dressing").visible = false
			"book_shadows":
				for n in _level.find_children("*", "MultiMeshInstance3D", true, false):
					n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			"shadow_splits":
				for n in _level.find_children("*", "DirectionalLight3D", true, false):
					n.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			"shadow_distance":
				for n in _level.find_children("*", "DirectionalLight3D", true, false):
					n.directional_shadow_max_distance = 40.0
			"shadow_size":
				RenderingServer.directional_shadow_atlas_set_size(2048, true)
			"hud":
				for n in _level.get_children():
					if n is CanvasLayer:
						n.visible = false
			_:
				push_warning("benchmark: unknown --disable item '%s'" % what)


func _spread_extra_guards() -> void:
	for guard in _guards():
		if not guard.has_meta("bench_start_point") or guard.machine == null:
			continue
		var patrol := guard.machine.get_state(GuardStateMachine.PATROL) as PatrolState
		patrol.current_point = guard.get_meta("bench_start_point")
		guard.navigate_to(guard.patrol_route.get_point_position(patrol.current_point), guard.patrol_speed)


func _setup_probes() -> void:
	# Guard scripts (Guard, Vision, Hearing) run in their own priority band,
	# with a probe just before and just after it.
	for guard in _guards():
		guard.process_physics_priority = GUARD_BAND
		for child in guard.get_children():
			child.process_physics_priority = GUARD_BAND
			child.process_priority = GUARD_BAND
		var pres := guard.get_node_or_null("Presentation")
		if pres:
			for c in pres.get_children():
				c.process_priority = GUARD_BAND
	_phys_start = Probe.new(true, FIRST)
	_phys_end = Probe.new(true, LAST)
	_proc_start = Probe.new(false, FIRST)
	_proc_end = Probe.new(false, LAST)
	_ai_start = Probe.new(true, GUARD_BAND - 1)
	_ai_end = Probe.new(true, GUARD_BAND + 1)
	_pres_start = Probe.new(false, GUARD_BAND - 1)
	_pres_end = Probe.new(false, GUARD_BAND + 1)
	for p in [_phys_start, _phys_end, _proc_start, _proc_end, _ai_start, _ai_end, _pres_start, _pres_end]:
		root.add_child(p)


func _on_physics_tick() -> void:
	# Runs after every physics tick's callbacks (SceneTree.physics_frame).
	_ticks += 1
	_sim_time = _ticks / PHYSICS_HZ
	if _measuring or _sim_time >= _warmup:
		_ai_usec_this_frame += maxi(_ai_end.stamp - _ai_start.stamp, 0)
		_phys_usec_this_frame += maxi(_phys_end.stamp - _phys_start.stamp, 0)
		_ai_ticks_this_frame += 1
	_update_camera()
	if _sim_time >= _next_noise and _sim_time > 2.0:
		_next_noise = _sim_time + NOISE_EVERY
		var system := NoiseSystem.find(_level)
		if system:
			system.emit_noise(NOISE_POINTS[_noise_index % NOISE_POINTS.size()], NoiseEvent.Type.RUN, "benchmark")
		_noise_index += 1


func _on_frame() -> void:
	var now := Time.get_ticks_usec()
	var frame_usec := now - _last_frame_usec
	_last_frame_usec = now
	if not _measuring:
		if _sim_time >= _warmup:
			_measuring = true
			_data.resize(MAX_ROWS * COLUMNS.size())
			_start_objects = int(Performance.get_monitor(Performance.OBJECT_COUNT))
			_start_static = int(Performance.get_monitor(Performance.MEMORY_STATIC))
			_ai_usec_this_frame = 0
			_phys_usec_this_frame = 0
			_ai_ticks_this_frame = 0
		return
	var moving := 0
	for g in _guards():
		if Vector2(g.velocity.x, g.velocity.z).length() > 0.3:
			moving += 1
	var render_cpu := RenderingServer.viewport_get_measured_render_time_cpu(_vp) + RenderingServer.get_frame_setup_time_cpu()
	var scripts_physics := _phys_usec_this_frame / 1000.0
	var scripts_process := maxi(_proc_end.stamp - _proc_start.stamp, 0) / 1000.0
	var frame_ms := frame_usec / 1000.0
	var row := PackedFloat64Array([
		frame_ms, scripts_physics, scripts_process,
		_ai_usec_this_frame / 1000.0,
		maxi(_pres_end.stamp - _pres_start.stamp, 0) / 1000.0,
		render_cpu,
		RenderingServer.viewport_get_measured_render_time_gpu(_vp),
		maxf(frame_ms - scripts_physics - scripts_process - render_cpu, 0.0),
		_ai_ticks_this_frame,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
		Performance.get_monitor(Performance.NAVIGATION_AGENT_COUNT),
		moving])
	if _row_count < MAX_ROWS:
		for i in row.size():
			_data[_row_count * COLUMNS.size() + i] = row[i]
		_row_count += 1
	_ai_usec_this_frame = 0
	_phys_usec_this_frame = 0
	_ai_ticks_this_frame = 0
	if _rendering and not _screenshot_taken and _sim_time >= _warmup + _seconds * 0.5:
		_screenshot_taken = true
		_save_screenshot()
	if _sim_time >= _warmup + _seconds:
		process_frame.disconnect(_on_frame)
		_finish()


func _update_camera() -> void:
	var total := 0.0
	for i in CAMERA_PATH.size() - 1:
		total += (CAMERA_PATH[i] as Vector2).distance_to(CAMERA_PATH[i + 1])
	var d := fmod(_sim_time * CAMERA_SPEED, total)
	for i in CAMERA_PATH.size() - 1:
		var a: Vector2 = CAMERA_PATH[i]
		var b: Vector2 = CAMERA_PATH[i + 1]
		var seg := a.distance_to(b)
		if d <= seg:
			var p := a.lerp(b, d / seg)
			_camera.global_position = Vector3(p.x, 1.6, p.y)
			var ahead := a.lerp(b, minf((d + 1.0) / seg, 1.0)) if seg - d > 0.5 else b + (b - a).normalized()
			_camera.look_at(Vector3(ahead.x, 1.5, ahead.y), Vector3.UP)
			return
		d -= seg


func _guards() -> Array[Guard]:
	var result: Array[Guard] = []
	for g in _level.get_node("Guards").get_children():
		if g is Guard:
			result.append(g)
	return result


func _finish() -> void:
	physics_frame.disconnect(_on_physics_tick)
	var summary := _summarise()
	print(JSON.stringify(summary, "  "))
	if _out != "":
		var dir := ProjectSettings.globalize_path(_out)
		DirAccess.make_dir_recursive_absolute(dir)
		var csv := FileAccess.open(dir.path_join("frames.csv"), FileAccess.WRITE)
		csv.store_line(",".join(COLUMNS))
		for r in _row_count:
			var cells := PackedStringArray()
			for i in COLUMNS.size():
				cells.append("%.4f" % _data[r * COLUMNS.size() + i])
			csv.store_line(",".join(cells))
		csv.close()
		var js := FileAccess.open(dir.path_join("summary.json"), FileAccess.WRITE)
		js.store_string(JSON.stringify(summary, "  "))
		js.close()
		print("benchmark: wrote ", dir)
	_level.queue_free()
	# Give the audio server time to release the stopped sounds.
	for i in 60:
		OS.delay_msec(5)
		await process_frame
	quit(0)


func _summarise() -> Dictionary:
	var frame := _column(0)
	var s := {
		"label": _label, "scenario": _scenario, "guards": _guards().size(), "disabled": ",".join(_disable),
		"mode": "rendering" if _rendering else "headless",
		"godot": Engine.get_version_info().string, "debug_build": OS.is_debug_build(),
		"os": "%s %s" % [OS.get_name(), OS.get_version()], "cpu": OS.get_processor_name(),
		"cpu_threads": OS.get_processor_count(),
		"gpu": "%s / %s" % [RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_name()],
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"resolution": "%dx%d" % [root.size.x, root.size.y] if _rendering else "none (headless)",
		"seconds": _seconds, "warmup": _warmup, "frames": _row_count,
		"physics_ticks_per_frame": _sum(_column(COLUMNS.find("physics_ticks"))) / maxf(_row_count, 1),
		"fps_avg": _row_count / (_sum(frame) / 1000.0) if not frame.is_empty() else 0.0,
		"fps_1pct_low": 1000.0 / _percentile(frame, 99.0) if not frame.is_empty() else 0.0,
		"caught": _caught, "status_changes": _status_changes, "stuck_events": _stuck_events,
		"object_count_growth": int(Performance.get_monitor(Performance.OBJECT_COUNT)) - _start_objects,
		"static_mem_growth_mb": (Performance.get_monitor(Performance.MEMORY_STATIC) - _start_static) / 1048576.0,
		"metrics": {},
	}
	for i in COLUMNS.size():
		var col := _column(i)
		s.metrics[COLUMNS[i]] = {"mean": _mean(col), "p50": _percentile(col, 50.0), "p95": _percentile(col, 95.0),
			"p99": _percentile(col, 99.0), "max": _max(col)}
	# Guard script time per physics tick (per frame sums several ticks when frames are slow).
	var ai := _column(COLUMNS.find("guard_ai_ms"))
	var ticks := _column(COLUMNS.find("physics_ticks"))
	s["guard_ai_ms_per_tick"] = _sum(ai) / maxf(_sum(ticks), 1.0)
	s["guard_ai_ms_per_tick_per_guard"] = s["guard_ai_ms_per_tick"] / maxf(s.guards, 1)
	return s


func _save_screenshot() -> void:
	if _out == "":
		return
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(_out)
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png(dir.path_join("screenshot.png"))


func _column(i: int) -> PackedFloat64Array:
	var c := PackedFloat64Array()
	for r in _row_count:
		c.append(_data[r * COLUMNS.size() + i])
	return c


static func _sum(c: PackedFloat64Array) -> float:
	var t := 0.0
	for v in c:
		t += v
	return t


static func _mean(c: PackedFloat64Array) -> float:
	return _sum(c) / c.size() if not c.is_empty() else 0.0


static func _max(c: PackedFloat64Array) -> float:
	var m := -INF
	for v in c:
		m = maxf(m, v)
	return m if not c.is_empty() else 0.0


static func _percentile(c: PackedFloat64Array, p: float) -> float:
	if c.is_empty():
		return 0.0
	var sorted := c.duplicate()
	sorted.sort()
	return sorted[clampi(int(ceil(p / 100.0 * sorted.size())) - 1, 0, sorted.size() - 1)]
