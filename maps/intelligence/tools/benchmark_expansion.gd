extends SceneTree
## Wall-clock renderer samples. Not a full-playthrough performance guarantee.
const L := preload("res://maps/intelligence/resources/layout/k17_layout.gd")
const Cleanup := preload("res://tests/test_utils.gd")
var output:="res://ci-logs/k17-v3-render.json"
func _init() -> void: _run.call_deferred()
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output=arg.trim_prefix("--out=")
	change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17.tscn")
	for i in 60: await process_frame
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var player:=current_scene.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	var flow:=GameFlow.find(current_scene)
	if flow.state==GameStateMachine.State.PAUSED: flow.resume()
	StealthDirector.find(current_scene).catch_distance=0
	var mission:=current_scene.get_node("Gameplay/Mission") as K17MissionController
	mission.set_physics_process(false)
	var samples: Array[Dictionary]=[]
	for alert in [false,true]:
		if alert:
			player.global_position=L.PREP
			player.camera.look_at(Vector3(8,1,-30))
			for id in [K17MissionController.ENTER,K17MissionController.PASS,K17MissionController.CODE,K17MissionController.ARCHIVE,K17MissionController.FILE]: ObjectiveManager.find(current_scene).complete(id)
			var team:=current_scene.get_node("Gameplay/Reinforcements")
			mission.time_left=110
			team._physics_process(0)
			mission.time_left=75
			team._physics_process(0)
		for view in [["yard",Vector3(-36,.05,44),Vector3(-20,1.5,18)],["command",Vector3(0,.05,7),Vector3(6,1.6,2)],["vault",Vector3(8,-3.95,-48),Vector3(0,-2.4,-40)]]:
			player.global_position=view[1]
			player.rotation=Vector3.ZERO
			player.get_node("Head").rotation=Vector3.ZERO
			player.camera.look_at(view[2])
			for i in 60: await process_frame
			var times: Array[float]=[]
			var until:=Time.get_ticks_msec()+3000
			while Time.get_ticks_msec()<until:
				if flow.state==GameStateMachine.State.PAUSED: flow.resume()
				var started:=Time.get_ticks_usec()
				await process_frame
				times.append((Time.get_ticks_usec()-started)/1000.0)
			times.sort()
			var median: float=times[times.size()/2]
			var entry:={"view":view[0],"alert":alert,"actors":get_nodes_in_group("guards").size(),"active_actors":get_nodes_in_group("guards").filter(func(g): return g.can_process()).size(),"median_ms":median,"median_fps":1000/median,"p95_ms":times[int(times.size()*.95)],"frames":times.size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
			samples.append(entry)
			print("K17 V3 RENDER ",JSON.stringify(entry))
	var result:={"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":"1280x720","conditions":"VSync off; real wall clock; 3s per view after warm-up; stationary camera; capture disabled; AI active, mission clock fixed for 6/10-actor comparisons. Not a complete gameplay benchmark.","samples":samples}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	current_scene.queue_free()
	for i in 40: await process_frame
	await Cleanup.settle_async_audio(self)
	quit()
