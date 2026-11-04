extends SceneTree
## Real renderer frame times of the four-second finale, including first effect activation.
const M := preload("res://maps/intelligence/scripts/mission_controller.gd")
var output := "res://maps/intelligence/docs/sabotage-v5/render-finale.json"
var samples: Array[Dictionary] = []
func _init() -> void: _run.call_deferred()
func _run() -> void:
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for repeat in 3:
		change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17.tscn")
		for i in 45: await process_frame
		var player := current_scene.get_node("Player") as FirstPersonPlayer
		player.set_physics_process(false)
		player.position=Vector3(8,.05,-20)
		player.camera.look_at(Vector3(8,1,-30))
		var flow := GameFlow.find(current_scene)
		if flow.state==GameStateMachine.State.PAUSED: flow.resume()
		StealthDirector.find(current_scene).catch_distance=0
		var mission := current_scene.get_node("Gameplay/Mission") as K17MissionController
		mission.set_physics_process(false)
		for id in [M.ENTER,M.PASS,M.CODE,M.ARCHIVE,M.VAULT,M.FILE]: ObjectiveManager.find(current_scene).complete(id)
		var team := current_scene.get_node("Gameplay/Reinforcements")
		team.set_physics_process(false)
		mission.time_left=75
		team._physics_process(0)
		current_scene.get_node("Gameplay/Sabotage").plant()
		mission.set_physics_process(true)
		mission.try_extract(&"maintenance","Bảo trì")
		var frames: Array[float]=[]
		var previous := Time.get_ticks_usec()
		var peak_draws := 0
		var worst_ms := 0.0
		var worst_at := 0.0
		while flow.state!=GameStateMachine.State.WIN:
			if flow.state==GameStateMachine.State.PAUSED: flow.resume()
			await process_frame
			var now := Time.get_ticks_usec()
			var frame_ms := (now-previous)/1000.0
			frames.append(frame_ms)
			if frame_ms>worst_ms:
				worst_ms=frame_ms
				worst_at=current_scene.get_node("Gameplay/ExtractionFinale").elapsed
			previous=now
			peak_draws=maxi(peak_draws,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		frames.sort()
		var entry := {"repeat":repeat+1,"frames":frames.size(),"median_ms":frames[frames.size()/2],"p95_ms":frames[mini(frames.size()-1,int(frames.size()*.95))],"p99_ms":frames[mini(frames.size()-1,int(frames.size()*.99))],"max_ms":frames[-1],"max_at_finale_seconds":worst_at,"peak_draw_calls":peak_draws,"actors":current_scene.get_node("Guards").get_child_count()}
		samples.append(entry)
		print("K17 V5 FINALE RENDER ",JSON.stringify(entry))
		current_scene.queue_free()
		for i in 40: await process_frame
	var result := {"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":"1280x720","conditions":"Real wall clock, VSync off. Three staged four-second finales, ten actors frozen at valid extraction. First effect activation included; no fixed-fps/headless. Not a walking E2E or gameplay FPS guarantee.","samples":samples}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	await preload("res://tests/test_utils.gd").settle_async_audio(self)
	quit()
