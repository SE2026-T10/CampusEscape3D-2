extends SceneTree
## Real renderer/real wall-clock samples with all four NPC brains active.
## Only player movement and capture are disabled for stable camera comparisons.
var output := "res://ci-logs/k17-art-live.json"
var report: Array[Dictionary] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg.begins_with("--viewport="):
			var dimensions := arg.trim_prefix("--viewport=").split("x")
			if dimensions.size() == 2 and int(dimensions[0]) > 0 and int(dimensions[1]) > 0:
				# Windows may clamp the initial CLI size to its work area.
				root.size = Vector2i(int(dimensions[0]),int(dimensions[1]))
	change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17.tscn")
	for i in 60: await process_frame
	var level := current_scene as Node3D
	var player := level.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	var flow := GameFlow.find(level)
	if flow.state == GameStateMachine.State.PAUSED: flow.resume()
	StealthDirector.find(level).catch_distance = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for state in ["yard","corridor","archive","alarm"]:
		player.rotation = Vector3.ZERO
		player.get_node("Head").rotation = Vector3.ZERO
		player.global_position = Vector3(-16,.05,27) if state == "yard" else (Vector3(-1,.05,7) if state == "corridor" else Vector3(6.8,.05,-12))
		player.camera.look_at(Vector3(-6,1.5,17) if state == "yard" else (Vector3(6,1.6,7) if state == "corridor" else Vector3(-2,1.2,-19)))
		level.get_node("Gameplay/Mission")._set_alarm_lights(state == "alarm")
		for i in 60: await process_frame
		var samples: Array[float] = []
		var deadline := Time.get_ticks_msec()+5000
		while Time.get_ticks_msec()<deadline:
			var start := Time.get_ticks_usec()
			await process_frame
			samples.append((Time.get_ticks_usec()-start)/1000.0)
		samples.sort()
		var frame_ms := samples[samples.size()/2]
		var entry := {"view":state,"median_ms":frame_ms,"median_fps":1000.0/frame_ms,
			"p95_ms":samples[int(samples.size()*.95)],"frames":samples.size(),
			"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
		report.append(entry)
		print("K17 LIVE RENDER ",JSON.stringify(entry))
	var result := {"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),
		"resolution":root.size,"npc_count":get_nodes_in_group("guards").size(),"samples":report,
		"conditions":"VSync off. Real wall clock, four active NPCs; stationary camera, capture disabled. Not a full human playthrough."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	quit()
