extends SceneTree
## Paired on/off renderer measurement of the minimap on identical stationary scenes.
const M := preload("res://maps/intelligence/scripts/mission_controller.gd")
const C := preload("res://maps/intelligence/resources/layout/k17_navigation.gd")
const OUT := "res://maps/intelligence/docs/keypad-minimap/performance.json"
var samples: Array[Dictionary]=[]

func _init() -> void:
	root.unfocusable=true
	_run.call_deferred()

func _run() -> void:
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17.tscn")
	for i in 45: await process_frame
	var player:=current_scene.get_node("Player") as FirstPersonPlayer
	var flow:=GameFlow.find(current_scene)
	if flow.state==GameStateMachine.State.PAUSED: flow.resume()
	var mission:=current_scene.get_node("Gameplay/Mission") as K17MissionController
	player.set_physics_process(false)
	player.position=Vector3(8,.05,-20)
	for id in [M.ENTER,M.PASS,M.CODE,M.ARCHIVE,M.VAULT,M.FILE]: ObjectiveManager.find(current_scene).complete(id)
	mission.set_physics_process(false)
	var team:=current_scene.get_node("Gameplay/Reinforcements")
	mission.time_left=75
	team._physics_process(0)
	# Freeze simulation identically in both conditions; only HUD/minimap still update.
	for node in current_scene.find_children("*","Node",true,false):
		if node==current_scene.get_node("ObjectiveHud") or current_scene.get_node("ObjectiveHud").is_ancestor_of(node): continue
		node.set_physics_process(false)
		node.set_process(false)
	var map:=current_scene.get_node("ObjectiveHud/Minimap")
	for view in [["yard",Vector3(-36,.05,44),Vector3(-20,1.5,18)],["keypad",C.KEYPAD_STAND,C.KEYPAD],["basement",Vector3(8,-3.95,-48),Vector3(0,-2.4,-40)]]:
		player.position=view[1]
		player.rotation=Vector3.ZERO
		player.head.rotation=Vector3.ZERO
		player.camera.look_at(view[2])
		for repeat in 4:
			var on: bool=repeat in [1,2]
			map.set_process(on)
			map.visible=on
			var warm_until:=Time.get_ticks_msec()+1000
			while Time.get_ticks_msec()<warm_until:
				if flow.state==GameStateMachine.State.PAUSED: flow.resume()
				await process_frame
			var times: Array[float]=[]
			var until:=Time.get_ticks_msec()+4000
			while Time.get_ticks_msec()<until:
				if flow.state==GameStateMachine.State.PAUSED: flow.resume()
				var started:=Time.get_ticks_usec()
				await process_frame
				times.append((Time.get_ticks_usec()-started)/1000.0)
			times.sort()
			var entry:={"view":view[0],"minimap":on,"repeat":repeat+1,"frames":times.size(),"median_ms":times[times.size()/2],"p95_ms":times[int(times.size()*.95)],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
			samples.append(entry)
			print("K17 MINIMAP RENDER ",JSON.stringify(entry))
	var report:={"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":"1280x720","conditions":"Real renderer, VSync off, 10 stationary actors, simulation frozen identically. Each view: OFF/ON/ON/OFF, 1s warm-up then 4s each. Compares minimap overhead only; not a gameplay FPS guarantee.","samples":samples}
	FileAccess.open(OUT,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	current_scene.queue_free()
	for i in 40: await process_frame
	await preload("res://tests/test_utils.gd").settle_async_audio(self)
	quit()
