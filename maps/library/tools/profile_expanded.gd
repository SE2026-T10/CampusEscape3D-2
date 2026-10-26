extends SceneTree

## Development tool: a reproducible rendering profile of the Expanded Library,
## to compare builds (e.g. a visual pass against the graybox before it).
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x1000 \
##       --script res://maps/library/tools/profile_expanded.gd -- --out=maps/library/docs/v4/profile --label=v4
##
## What happens, the same way every run: the level loads (load time measured),
## the six guards patrol with their normal AI, and a free camera stops at each
## viewpoint of maps/library/tools/capture_views.gd (both floors, every zone) for a
## warm-up and then FRAMES measured frames. Vsync off, frame rate uncapped.
## Measured per frame: frame time, and the renderer's draw calls, objects and
## primitives (RenderingServer rendering info). Written: summary.md and
## frames.csv. The player stays at the spawn, outside the guards' view.
##
## Frame times depend on the machine: compare builds on the same machine only.
## The counts (draw calls, objects, primitives) do not.
## Diagnostics only: --disable=omni,shadows,books,roof switches parts off (all
## omni lights; the sun's shadows; the books; the roof and the ceilings of the
## double-height halls) to see what each costs.

const SCENE := "res://maps/library/scenes/expanded_library.tscn"
const Views := preload("res://maps/library/tools/capture_views.gd")
const FRAMES := 120
const WARMUP := 30
const EYE := 1.6

var _out := ""
var _label := ""
var _disable: PackedStringArray = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--label="):
			_label = a.trim_prefix("--label=")
		elif a.begins_with("--disable="):
			_disable = a.trim_prefix("--disable=").split(",")
	if DisplayServer.get_name() == "headless":
		push_error("profile_expanded needs a display (run under xvfb-run).")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var t0 := Time.get_ticks_usec()
	var level := (load(SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(level)
	await process_frame
	await process_frame
	var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
	GameFlow.find(level).change_scene = func(_path: String): pass
	for n in level.find_children("*", "OmniLight3D", true, false):
		if _disable.has("omni"):
			(n as OmniLight3D).visible = false
	if _disable.has("shadows"):
		(level.get_node("KeyLight") as DirectionalLight3D).shadow_enabled = false
	if _disable.has("roof") and level.has_node("Dressing/Ceilings"):
		(level.get_node("Dressing/Ceilings") as Node3D).visible = false
	if _disable.has("books"):
		for n in level.find_children("Books", "Node3D", true, false):
			(n as Node3D).visible = false
	var camera := Camera3D.new()
	camera.fov = 75.0
	level.add_child(camera)
	camera.make_current()
	var rows := PackedStringArray(["view,frame,ms,draw_calls,objects,primitives"])
	var per_view := []
	var all_ms: Array[float] = []
	var all_calls: Array[float] = []
	for v in Views.VIEWS:
		var at: Vector3 = v[1] + Vector3(0, EYE, 0)
		camera.global_position = at
		camera.look_at(v[2])
		for i in WARMUP:
			await process_frame
		var ms: Array[float] = []
		var calls: Array[float] = []
		var objects: Array[float] = []
		var prims: Array[float] = []
		var last := Time.get_ticks_usec()
		for i in FRAMES:
			await process_frame
			var now := Time.get_ticks_usec()
			var frame_ms := (now - last) / 1000.0
			last = now
			var c := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			var o := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
			var p := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			ms.append(frame_ms)
			calls.append(c)
			objects.append(o)
			prims.append(p)
			rows.append("%s,%d,%.3f,%d,%d,%d" % [v[0], i, frame_ms, c, o, p])
		all_ms.append_array(ms)
		all_calls.append_array(calls)
		per_view.append([v[0], _mean(ms), _pct(ms, 0.95), _mean(calls), calls.max(), _mean(objects), _mean(prims)])
	var md := PackedStringArray()
	md.append("# Expanded Library — rendering profile%s%s\n" % [(" (" + _label + ")") if _label != "" else "",
		(" — diagnostics: without " + ", ".join(_disable)) if not _disable.is_empty() else ""])
	md.append("`maps/library/tools/profile_expanded.gd`, %s, renderer %s, %s, window %s. Load time: %.0f ms. %d viewpoints × %d frames (after %d warm-up), guards patrolling.\n" % [
		Time.get_datetime_string_from_system(), RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name(), root.get_visible_rect().size, load_ms, Views.VIEWS.size(), FRAMES, WARMUP])
	md.append("**All views:** mean frame %.2f ms (%.0f FPS), 95th percentile %.2f ms; draw calls mean %.0f, max %.0f.\n" % [
		_mean(all_ms), 1000.0 / _mean(all_ms), _pct(all_ms, 0.95), _mean(all_calls), all_calls.max()])
	md.append("| View | Frame ms (mean) | Frame ms (p95) | Draw calls (mean) | Draw calls (max) | Objects | Primitives |\n|---|---|---|---|---|---|---|")
	for r in per_view:
		md.append("| %s | %.2f | %.2f | %.0f | %.0f | %.0f | %.0f |" % r)
	var text := "\n".join(md) + "\n"
	print(text)
	if _out != "":
		var dir := _out if _out.is_absolute_path() else ProjectSettings.globalize_path("res://" + _out)
		DirAccess.make_dir_recursive_absolute(dir)
		var f := FileAccess.open(dir.path_join("summary.md"), FileAccess.WRITE)
		f.store_string(text)
		f.close()
		f = FileAccess.open(dir.path_join("frames.csv"), FileAccess.WRITE)
		f.store_string("\n".join(rows) + "\n")
		f.close()
	level.queue_free()
	for i in 30:
		await process_frame
	quit(0)


func _mean(a: Array) -> float:
	var s := 0.0
	for x in a:
		s += x
	return s / maxf(1.0, a.size())


func _pct(a: Array, q: float) -> float:
	var b := a.duplicate()
	b.sort()
	return b[clampi(int(q * (b.size() - 1)), 0, b.size() - 1)]
