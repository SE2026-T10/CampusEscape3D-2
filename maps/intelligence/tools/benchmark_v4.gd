extends SceneTree
## Real wall-clock renderer benchmark; this is not a walking E2E.
const L:=preload("res://maps/intelligence/resources/layout/k17_layout.gd")
const M:=preload("res://maps/intelligence/scripts/mission_controller.gd")
const Cleanup:=preload("res://tests/test_utils.gd")
var seconds:=30.0
var repeats:=1
var counts: Array[int]=[6,8,10]
var selected_views: PackedStringArray=[]
var power_modes: Array[bool]=[true,false]
var compare_occlusion := false
var resolution := Vector2i(1280, 720)
var render_size := Vector2i.ZERO
var output:="res://ci-logs/k17-v4-render.json"
var samples: Array[Dictionary]=[]

func _init() -> void:
	root.unfocusable = true
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="): seconds=float(arg.trim_prefix("--seconds="))
		if arg.begins_with("--repeats="): repeats=int(arg.trim_prefix("--repeats="))
		if arg.begins_with("--counts="):
			counts.clear()
			for value in arg.trim_prefix("--counts=").split(","): counts.append(int(value))
		if arg.begins_with("--views="): selected_views=arg.trim_prefix("--views=").split(",")
		if arg=="--power=on": power_modes=[true]
		if arg=="--power=off": power_modes=[false]
		if arg=="--1080p": resolution = Vector2i(1920, 1080)
		if arg=="--occlusion=compare": compare_occlusion = true
		if arg.begins_with("--out="): output=arg.trim_prefix("--out=")
	if DisplayServer.get_name() == "headless" or seconds <= 0.0 or repeats < 1:
		push_error("K17 benchmark requires a renderer, --seconds > 0, and --repeats >= 1.")
		quit(2)
		return
	root.size = resolution
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for repeat in repeats:
		var modes := ["before", "after"] if compare_occlusion else ["default"]
		if repeat % 2 == 1:
			modes.reverse()
		for count in counts:
			for cameras_on in power_modes:
				for mode in modes:
					if not await _sample_case(repeat + 1, count, cameras_on, mode):
						quit(2)
						return
	await Cleanup.settle_async_audio(self)
	quit()


func _sample_case(repeat: int, count: int, cameras_on: bool, mode: String) -> bool:
	change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17.tscn")
	for i in 45: await process_frame
	var player := current_scene.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	var flow := GameFlow.find(current_scene)
	if flow.state == GameStateMachine.State.PAUSED: flow.resume()
	StealthDirector.find(current_scene).catch_distance = 0
	var mission := current_scene.get_node("Gameplay/Mission") as K17MissionController
	mission.set_physics_process(false)
	var power := current_scene.get_node("Gameplay/PowerNetwork")
	power.set_physics_process(false)
	var team := current_scene.get_node("Gameplay/Reinforcements")
	team.set_physics_process(false)
	if count > 6:
		player.global_position = L.PREP
		player.camera.look_at(Vector3(8, 1, -30))
		for id in [M.ENTER, M.PASS, M.CODE, M.ARCHIVE, M.VAULT, M.FILE]:
			ObjectiveManager.find(current_scene).complete(id)
		mission.time_left = 110
		team._physics_process(0)
		if count == 10:
			mission.time_left = 75
			team._physics_process(0)
	power.set_powered(&"surveillance", cameras_on)
	if mode == "before":
		root.use_occlusion_culling = false
	elif mode == "after" and not root.use_occlusion_culling:
		push_error("K17 did not enable occlusion culling on scene entry.")
		return false
	for view in [["yard", Vector3(-36, .05, 44), Vector3(-20, 1.5, 18)],
		["command", Vector3(0, .05, 7), Vector3(6, 1.6, 2)],
		["vault", Vector3(8, -3.95, -48), Vector3(0, -2.4, -40)],
		["service", Vector3(26, .05, 35), Vector3(36, 1.6, 18)],
		["workshop", Vector3(37.6, .05, 15.25), Vector3(37.6, 1.3, 17.15)]]:
		if not selected_views.is_empty() and view[0] not in selected_views: continue
		player.global_position = view[1]
		player.rotation = Vector3.ZERO
		player.head.rotation = Vector3.ZERO
		player.camera.look_at(view[2])
		if not await _measure_view(repeat, count, cameras_on, mode, view[0], flow):
			return false
	current_scene.queue_free()
	for i in 40: await process_frame
	return true


func _measure_view(repeat: int, count: int, cameras_on: bool, mode: String, view: String, flow: GameFlow) -> bool:
	var until := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < until: await _next_frame(flow)
	if render_size == Vector2i.ZERO:
		await RenderingServer.frame_post_draw
		render_size = root.get_texture().get_image().get_size()
		if render_size != resolution:
			push_error("K17 expected %s renderer output, got %s." % [resolution, render_size])
			return false
	var times: Array[float] = []
	var draws: Array[int] = []
	until = Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		var started := Time.get_ticks_usec()
		await _next_frame(flow)
		times.append((Time.get_ticks_usec() - started) / 1000.0)
		draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	times.sort()
	var last_draws := draws.back() as int
	draws.sort()
	var actors := get_nodes_in_group("guards")
	var active_actors := actors.filter(func(guard): return guard.can_process()).size()
	if active_actors != count:
		push_error("K17 expected %d active NPC, got %d." % [count, active_actors])
		return false
	var entry := {
		"repeat": repeat, "actors": actors.size(), "active_actors": active_actors,
		"cameras_on": cameras_on, "occlusion": root.use_occlusion_culling, "mode": mode,
		"view": view, "seconds": seconds, "frames": times.size(),
		"median_fps": 1000 / _percentile(times, .50), "p50_ms": _percentile(times, .50),
		"p95_ms": _percentile(times, .95), "p99_ms": _percentile(times, .99),
		"draw_calls": last_draws, "draw_calls_p50": _percentile(draws, .50),
		"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
	}
	samples.append(entry)
	print("K17 V4 RENDER ", JSON.stringify(entry))
	_save()
	return true


func _next_frame(flow: GameFlow) -> void:
	if flow.state == GameStateMachine.State.PAUSED: flow.resume()
	await process_frame


func _percentile(sorted_values: Array, fraction: float) -> float:
	return sorted_values[ceili(sorted_values.size() * fraction) - 1]


func _save() -> void:
	var result:={"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":"%dx%d" % [render_size.x, render_size.y],"conditions":"VSync off, real wall clock, stationary views, 2s warm-up. Guard AI active; capture disabled, mission clock and power scheduling fixed to isolate 6/8/10 actors and camera power.","samples":samples}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
