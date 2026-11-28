extends SceneTree
## Fixed camera B, real render intervals, from extraction through the first victory frame.
const M := preload("res://maps/intelligence/scripts/mission_controller.gd")
var output := "res://maps/intelligence/docs/sabotage-v5/render-finale.json"
var resolution := Vector2i(1280, 720)
var repeats := 3
var samples: Array[Dictionary] = []

func _init() -> void:
	root.unfocusable = true
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--1080p": resolution = Vector2i(1920, 1080)
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg.begins_with("--repeats="): repeats = arg.trim_prefix("--repeats=").to_int()
	if repeats < 1 or DisplayServer.get_name() == "headless":
		printerr("Finale benchmark requires a real renderer and a positive repeat count.")
		quit(2)
		return
	root.size = resolution
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for repeat in repeats:
		if not await _sample(repeat + 1):
			printerr("Invalid render size, event state, or interrupted sample.")
			quit(2)
			return
	var result := {"device": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"resolution": "%dx%d" % [resolution.x, resolution.y],
		"conditions": "VSync off, 2s warm-up, ten NPC before extraction via B. Includes first WIN frame. Next 750ms measured separately.",
		"samples": samples}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output, FileAccess.WRITE)
	if not file:
		printerr("Cannot write ", output)
		quit(2)
		return
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	await preload("res://tests/test_utils.gd").settle_async_audio(self)
	quit()

func _sample(repeat: int) -> bool:
	change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17.tscn")
	for i in 50: await process_frame
	var player := current_scene.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	player.position = Vector3(8, .05, -20)
	player.camera.look_at(Vector3(8, 1, -30))
	var flow := GameFlow.find(current_scene)
	if flow.state == GameStateMachine.State.PAUSED: flow.resume()
	StealthDirector.find(current_scene).catch_distance = 0
	var mission := current_scene.get_node("Gameplay/Mission") as K17MissionController
	for id in [M.ENTER, M.PASS, M.CODE, M.ARCHIVE, M.VAULT, M.FILE]:
		ObjectiveManager.find(current_scene).complete(id)
	var team := current_scene.get_node("Gameplay/Reinforcements")
	for remaining in [110, 75]:
		mission.time_left = remaining
		team._physics_process(0)
	var device := current_scene.get_node("Gameplay/Sabotage")
	if not device.plant(): return false
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().get_size() != resolution: return false
	var warm_until := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < warm_until:
		if flow.state == GameStateMachine.State.PAUSED: flow.resume()
		await process_frame
	var actors := get_nodes_in_group("guards").size()
	if actors != 10: return false
	await RenderingServer.frame_post_draw
	var start := Time.get_ticks_usec()
	var previous := start
	var first_pre_draw := [0]
	RenderingServer.frame_pre_draw.connect(func(): first_pre_draw[0] = Time.get_ticks_usec(), Object.CONNECT_ONE_SHOT)
	if not mission.try_extract(&"maintenance", "Bảo trì"): return false
	var trigger_ms := (Time.get_ticks_usec() - start) / 1000.0
	var first_render_ms := 0.0
	var frames: Array[float] = []
	var peak_ms := 0.0
	var peak_at := 0.0
	var peak_draws := 0
	while flow.state != GameStateMachine.State.WIN:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		var ms := (now - previous) / 1000.0
		previous = now
		if frames.is_empty() and first_pre_draw[0] > start:
			first_render_ms = (now - first_pre_draw[0]) / 1000.0
		frames.append(ms)
		if ms > peak_ms:
			peak_ms = ms
			peak_at = (now - start) / 1000000.0
		peak_draws = maxi(peak_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		if now - start > 8000000 or flow.state == GameStateMachine.State.PAUSED: return false
	if frames.is_empty(): return false
	var first_ms: float = frames.front()
	var win_ms: float = frames.back()
	var post_until := previous + 750000
	var post_frames: Array[float] = []
	# Keep validation, sorting, device queries, and file I/O outside this window.
	while previous < post_until:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		post_frames.append((now - previous) / 1000.0)
		previous = now
	if device.detonations != 1: return false
	frames.sort()
	post_frames.sort()
	var entry := {"repeat": repeat, "frames": frames.size(), "actors": actors,
		"median_ms": frames[ceili(frames.size() * .5) - 1], "p95_ms": frames[ceili(frames.size() * .95) - 1],
		"p99_ms": frames[ceili(frames.size() * .99) - 1], "max_ms": peak_ms,
		"max_at_finale_seconds": peak_at, "peak_draw_calls": peak_draws,
		"first_ms": first_ms, "trigger_ms": trigger_ms, "first_render_ms": first_render_ms,
		"win_ms": win_ms, "after_win_p95_ms": post_frames[ceili(post_frames.size() * .95) - 1],
		"after_win_peak_ms": post_frames.back()}
	samples.append(entry)
	print("K17 V5 FINALE RENDER ", JSON.stringify(entry))
	current_scene.queue_free()
	for i in 40: await process_frame
	return true
