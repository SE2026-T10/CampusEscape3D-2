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
var output:="res://ci-logs/k17-v4-render.json"
var samples: Array[Dictionary]=[]

func _init() -> void: _run.call_deferred()

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
		if arg.begins_with("--out="): output=arg.trim_prefix("--out=")
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for repeat in repeats:
		for count in counts:
			for cameras_on in power_modes:
				change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17.tscn")
				for i in 45: await process_frame
				var player:=current_scene.get_node("Player") as FirstPersonPlayer
				player.set_physics_process(false)
				var flow:=GameFlow.find(current_scene)
				if flow.state==GameStateMachine.State.PAUSED: flow.resume()
				StealthDirector.find(current_scene).catch_distance=0
				var mission:=current_scene.get_node("Gameplay/Mission") as K17MissionController
				mission.set_physics_process(false)
				var power:=current_scene.get_node("Gameplay/PowerNetwork")
				power.set_physics_process(false)
				var team:=current_scene.get_node("Gameplay/Reinforcements")
				team.set_physics_process(false)
				if count>6:
					player.global_position=L.PREP
					player.camera.look_at(Vector3(8,1,-30))
					for id in [M.ENTER,M.PASS,M.CODE,M.ARCHIVE,M.VAULT,M.FILE]: ObjectiveManager.find(current_scene).complete(id)
					mission.time_left=110
					team._physics_process(0)
					if count==10:
						mission.time_left=75
						team._physics_process(0)
				power.set_powered(&"surveillance",cameras_on)
				for view in [["yard",Vector3(-36,.05,44),Vector3(-20,1.5,18)],["command",Vector3(0,.05,7),Vector3(6,1.6,2)],["vault",Vector3(8,-3.95,-48),Vector3(0,-2.4,-40)],["service",Vector3(26,.05,35),Vector3(36,1.6,18)]]:
					if not selected_views.is_empty() and view[0] not in selected_views: continue
					player.global_position=view[1]
					player.rotation=Vector3.ZERO
					player.get_node("Head").rotation=Vector3.ZERO
					player.camera.look_at(view[2])
					var warm_until:=Time.get_ticks_msec()+2000
					while Time.get_ticks_msec()<warm_until:
						if flow.state==GameStateMachine.State.PAUSED: flow.resume()
						await process_frame
					var times: Array[float]=[]
					var until:=Time.get_ticks_msec()+int(seconds*1000)
					while Time.get_ticks_msec()<until:
						if flow.state==GameStateMachine.State.PAUSED: flow.resume()
						var started:=Time.get_ticks_usec()
						await process_frame
						times.append((Time.get_ticks_usec()-started)/1000.0)
					times.sort()
					var median: float=times[times.size()/2]
					var entry:={"repeat":repeat+1,"actors":get_nodes_in_group("guards").size(),"active_actors":get_nodes_in_group("guards").filter(func(g): return g.can_process()).size(),"cameras_on":cameras_on,"view":view[0],"seconds":seconds,"frames":times.size(),"median_fps":1000/median,"p95_ms":times[int(times.size()*.95)],"p99_ms":times[int(times.size()*.99)],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
					samples.append(entry)
					print("K17 V4 RENDER ",JSON.stringify(entry))
					_save()
				current_scene.queue_free()
				for i in 40: await process_frame
	await Cleanup.settle_async_audio(self)
	quit()

func _save() -> void:
	var result:={"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":"1280x720","conditions":"VSync off, real wall clock, stationary views, 2s warm-up. All AI/cameras active; capture disabled, mission clock and power scheduling fixed to isolate 6/8/10 actors and camera power. Not a gameplay FPS guarantee.","samples":samples}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
