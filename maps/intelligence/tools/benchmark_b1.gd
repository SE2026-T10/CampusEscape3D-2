extends SceneTree
## Real-renderer paired frame-time measurements and an eye-position image test.
const C := preload("res://maps/intelligence/resources/layout/k17_projection.gd")
const OUT := "res://maps/intelligence/docs/b1-refinement"
var rig: K17ProjectionRig
var player: FirstPersonPlayer
var flow: GameFlow
var samples: Array[Dictionary]=[]

func _init() -> void:
	root.unfocusable=true
	_run.call_deferred()

func _run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17.tscn")
	await _frames(35)
	player=current_scene.get_node("Player")
	root.content_scale_factor=1.0
	player.set_physics_process(false)
	rig=current_scene.get_node("Gameplay/ProjectionRig")
	flow=GameFlow.find(current_scene)
	for guard in current_scene.get_node("Guards").get_children(): guard.process_mode=Node.PROCESS_MODE_DISABLED
	for id in [K17MissionController.ENTER,K17MissionController.PASS,K17MissionController.CODE,K17MissionController.ARCHIVE,K17MissionController.VAULT]: ObjectiveManager.find(current_scene).complete(id)
	rig.deploy()
	rig.position=Vector3(-5,-4,-47)
	player.position=C.POST
	player.camera.cull_mask=5
	player.camera.look_at(Vector3(0,-2.4,-47))
	rig.get_node("Upright").visible=false
	await _frames(20)
	var reference := await _image()
	rig.get_node("Upright").visible=true
	rig.powered=true
	await _frames(20)
	var projected := await _image()
	rig.powered=false
	await _frames(20)
	var off := await _image()
	var corners: Array[Vector2]=[]
	for x in [-C.SCREEN_SIZE.x/2,C.SCREEN_SIZE.x/2]:
		for y in [-C.SCREEN_SIZE.y/2,C.SCREEN_SIZE.y/2]: corners.append(player.camera.unproject_position(rig.to_global(C.SCREEN_CENTER+Vector3(x,y,0))))
	var bounds := Rect2(corners[0],Vector2.ZERO)
	for point in corners: bounds=bounds.expand(point)
	var roi := Rect2i(bounds.grow(-4))
	var errors := _compare(reference,projected,off,roi)
	reference.save_png(ProjectSettings.globalize_path(OUT+"/screens/projection_reference.png"))
	projected.save_png(ProjectSettings.globalize_path(OUT+"/screens/projection_matched.png"))
	var comparison := {"scope":"Staged images at the same guard eye, actors excluded, no walking claim","region":str(roi),"metrics":errors,"passed":errors.mean_error<.06 and errors.on_off_change>.03}
	FileAccess.open(OUT+"/projection-comparison.json",FileAccess.WRITE).store_string(JSON.stringify(comparison,"\t"))
	print("K17 V6 PROJECTION IMAGE ",JSON.stringify(comparison))
	for view in [["guard_eye",C.POST,Vector3(0,-2.4,-47)],["operator",Vector3(-3.95,-3.95,-47),Vector3(-5,-2.6,-47)]]:
		player.position=view[1]
		player.camera.cull_mask=5 if view[0]=="guard_eye" else 1048575
		player.camera.look_at(view[2])
		for repeat in 4:
			var on := repeat in [1,2]
			rig.powered=on
			var warm_until := Time.get_ticks_msec()+1000
			while Time.get_ticks_msec()<warm_until: await process_frame
			var times: Array[float]=[]
			var draw_sum := 0.0
			var until := Time.get_ticks_msec()+2500
			while Time.get_ticks_msec()<until:
				if flow.state==GameStateMachine.State.PAUSED: flow.resume()
				var started := Time.get_ticks_usec()
				await process_frame
				times.append((Time.get_ticks_usec()-started)/1000.0)
				draw_sum+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			times.sort()
			var sample := {"view":view[0],"projection":on,"repeat":repeat+1,"frames":times.size(),"median_ms":times[times.size()/2],"p95_ms":times[int(times.size()*.95)],"mean_draw_calls":draw_sum/times.size()}
			samples.append(sample)
			print("K17 V6 RENDER ",JSON.stringify(sample))
	rig.powered=true
	await _frames(20)
	var mission := current_scene.get_node("Gameplay/Mission") as K17MissionController
	mission.has_file=true
	var before := rig.projection_updates
	await _frames(20)
	var idle_after_file := rig.projection_updates==before
	mission.has_file=false
	player.position=Vector3(30,0,30)
	before=rig.projection_updates
	await _frames(20)
	var idle_far_away := rig.projection_updates==before
	player.position=Vector3(-3.95,-3.95,-47)
	await _frames(20)
	flow.pause()
	before=rig.projection_updates
	for i in 20: await process_frame
	var idle_paused := rig.projection_updates==before
	flow.resume()
	var report := {"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":"1280x720","conditions":"Six actors frozen. OFF/ON/ON/OFF, 1s warmup + 2.5s sample. One 512x512 projection viewport at 12.5Hz. Frame intervals include CPU and renderer, not an isolated GPU timing or gameplay FPS guarantee.","idle_after_file":idle_after_file,"idle_far_away":idle_far_away,"idle_paused":idle_paused,"samples":samples}
	var system:=current_scene.get_node("Gameplay/B1Surveillance")
	system.hack()
	player.position=rig.to_global(C.GRIP_OFFSET)
	player.camera.cull_mask=1048575
	player.camera.look_at(rig.to_global(Vector3(0,1.3,-4)))
	var feed_samples: Array[Dictionary]=[]
	for mode in [0,1,2,0]:
		system.feed_mode=mode
		var warm_until:=Time.get_ticks_msec()+1000
		while Time.get_ticks_msec()<warm_until: await process_frame
		var times: Array[float]=[]
		var until:=Time.get_ticks_msec()+2500
		while Time.get_ticks_msec()<until:
			if flow.state==GameStateMachine.State.PAUSED: flow.resume()
			var began:=Time.get_ticks_usec()
			await process_frame
			times.append((Time.get_ticks_usec()-began)/1000.0)
		times.sort()
		feed_samples.append({"mode":mode,"frames":times.size(),"median_ms":times[times.size()/2],"p95_ms":times[int(times.size()*.95)]})
	report["feed_samples"]=feed_samples
	report["feed_conditions"]="One actual 480x270 observation viewport at 10Hz; OFF/front/C1/OFF. Six actors frozen. Separate from the projection viewport."
	FileAccess.open(OUT+"/performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	current_scene.queue_free()
	await _frames(25)
	await preload("res://tests/test_utils.gd").settle_async_audio(self)
	quit(0 if comparison.passed and idle_after_file and idle_far_away and idle_paused else 1)

func _compare(reference: Image,on: Image,off: Image,region: Rect2i) -> Dictionary:
	var error := 0.0
	var change := 0.0
	var count := 0
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var a := reference.get_pixel(x,y)
			var b := on.get_pixel(x,y)
			var c := off.get_pixel(x,y)
			error+=(absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3.0
			change+=(absf(c.r-b.r)+absf(c.g-b.g)+absf(c.b-b.b))/3.0
			count+=1
	return {"pixels":count,"mean_error":error/maxi(1,count),"on_off_change":change/maxi(1,count)}

func _image() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _frames(count: int) -> void:
	for i in count:
		if is_instance_valid(flow) and flow.state==GameStateMachine.State.PAUSED: flow.resume()
		await physics_frame
