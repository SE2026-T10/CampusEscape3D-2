extends SceneTree
## Fixed gameplay-height views and a real rendered frame-time sample.
## NPC decisions are disabled only for these repeatable visual captures.
var output := "res://ci-logs/k17-art"
var level: Node3D
var player: FirstPersonPlayer
var samples: Array[float] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17.tscn")
	await _frames(40)
	level = current_scene as Node3D
	player = level.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	for guard in level.get_node("Guards").get_children(): guard.process_mode = Node.PROCESS_MODE_DISABLED
	var flow := GameFlow.find(level)
	if flow.state == GameStateMachine.State.PAUSED: flow.resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _view("01_spawn",Vector3(-16,.05,27),Vector3(-10,1.8,14),false)
	await _view("02_gate",Vector3(-20,.05,28),Vector3(-4,1.6,20),true)
	await _view("03_comms",Vector3(0,.05,13),Vector3(5,1.2,11.5),true)
	await _view("04_archive",Vector3(6.8,.05,-12),Vector3(-3,1.1,-17),true)
	await _view("05_guard",Vector3(-5,.05,19.2),Vector3(-8,1.15,18),true)
	await _view("06_checkpoint",Vector3(11,.05,-10),Vector3(8,1.2,-3.2),false)
	var mission := level.get_node("Gameplay/Mission") as K17MissionController
	mission.has_file = true
	mission._set_alarm_lights(true)
	await _view("07_alarm",Vector3(6.8,.05,-12),Vector3(4,1,-20),true)
	await _view("08_guardroom",Vector3(-8,.05,9),Vector3(-11,1.3,2),true)
	mission.has_file = false
	mission._set_alarm_lights(false)
	player.global_position = Vector3(-16,.05,27)
	player.camera.look_at(Vector3(0,1.5,14))
	await _frames(60)
	for i in 180:
		var start := Time.get_ticks_usec()
		await process_frame
		samples.append((Time.get_ticks_usec()-start)/1000.0)
	samples.sort()
	var report := {"renderer": RenderingServer.get_current_rendering_method(),
		"device": RenderingServer.get_video_adapter_name(), "resolution": root.size,
		"median_frame_ms": samples[samples.size()/2], "p95_frame_ms": samples[int(samples.size()*.95)],
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"visible_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"note": "Fixed camera; AI paused only for visual isolation. Not a live-gameplay FPS claim."}
	var file := FileAccess.open(output.path_join("render.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("K17 ART PREVIEW ",JSON.stringify(report))
	quit()

func _view(title: String,pos: Vector3,target: Vector3,beauty: bool) -> void:
	for child in level.get_children():
		if child is CanvasLayer: child.visible = not beauty
	player.global_position = pos
	player.get_node("Head").rotation = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.camera.look_at(target)
	await _frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output.path_join(title+".png")))

func _frames(count: int) -> void:
	for i in count: await process_frame
