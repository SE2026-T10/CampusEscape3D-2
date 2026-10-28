extends SceneTree
## Staged renderer evidence; this tool deliberately positions actors/camera.
## Full input-driven traversal is checked separately by playthrough_k17.gd.
const C := preload("res://maps/intelligence/resources/layout/k17_projection.gd")
const OUT := "res://maps/intelligence/docs/gameplay-v6/screens"
var player: FirstPersonPlayer
var rig: K17ProjectionRig
var flow: GameFlow
var ui_checks: Array[Dictionary]=[]
var failures: Array[String]=[]

func _init() -> void:
	root.unfocusable=true
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,720)
	change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17.tscn")
	await _frames(40)
	player=current_scene.get_node("Player")
	player.set_physics_process(false)
	rig=current_scene.get_node("Gameplay/ProjectionRig")
	flow=GameFlow.find(current_scene)
	for guard in current_scene.get_node("Guards").get_children(): guard.process_mode=Node.PROCESS_MODE_DISABLED
	var objectives := ObjectiveManager.find(current_scene)
	for id in [K17MissionController.ENTER,K17MissionController.PASS,K17MissionController.CODE,K17MissionController.ARCHIVE,K17MissionController.VAULT]: objectives.complete(id)
	_view(Vector3(4.1,-3.95,-49.3),Vector3(3,-2.9,-50.6))
	await _shot("01_preparation")
	rig.deploy()
	_view(Vector3(4.05,-3.95,-50.6),rig.to_global(Vector3(0,1.4,0)))
	await _shot("02_equipment_back")
	rig.global_position=Vector3(-4,-4,-47)
	_view(C.POST,Vector3(0,-2.4,-47))
	await _shot("03_guard_projection_on")
	rig.powered=false
	await _shot("04_guard_projection_off")
	rig.powered=true
	_view(Vector3(-5,-3.95,-43.5),rig.global_position+Vector3(0,1.1,0))
	await _shot("05_patrol_side")
	rig.global_position=C.BAYS[0]
	_view(Vector3(-.4,-3.95,-49.2),Vector3(-3,-2.9,-50.7))
	await _shot("06_bay_pocket")
	_view(Vector3(-9.7,-3.95,-43.5),C.FILE)
	await _shot("07_archive_room")
	_view(C.OBSERVATION,Vector3(-5,-2.5,-35.7))
	await _shot("07b_observation_window")
	rig.global_position=C.DOCK
	_view(Vector3(-9.95,-3.95,-47),Vector3(-9.7,-2.7,-43.5))
	await _shot("08_archive_entry")
	_view(Vector3(-10.5,-3.95,-36.5),Vector3(1,-2.3,-36.5))
	await _shot("09_return_corridor")
	for view in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(1024,768)]:
		root.size=view
		for scale in [1.0,1.25]:
			root.content_scale_factor=scale
			_view(Vector3(-9.95,-3.95,-47),Vector3(-14,-2.4,-47))
			for i in 4: SoundCaptions.cue(current_scene,"qa_caption_"+str(i),["Bước chân bên hông","Vô tuyến của đội tuần tra","Âm thanh thiết bị","Tiếng động trong hành lang"][i],Vector3(-5,-2.4,-43.5),100)
			current_scene.get_node("ObjectiveHud").show_message("Đã lưu checkpoint: B1 / trước màn chiếu",Color("72c5ac"))
			await _shot("hud_%dx%d_%d"%[view.x,view.y,int(scale*100)])
			_check_ui(view,scale)
	FileAccess.open(OUT+"/layouts.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":ui_checks,"failures":failures},"\t"))
	current_scene.queue_free()
	await _frames(20)
	await preload("res://tests/test_utils.gd").settle_async_audio(self)
	for failure in failures: printerr(failure)
	print("K17 V6 RENDER CAPTURES COMPLETE; HUD: ",ui_checks.size()," configurations; ",failures.size()," overlaps")
	quit(0 if failures.is_empty() else 1)

func _check_ui(view: Vector2i,scale: float) -> void:
	var hud := current_scene.get_node("ObjectiveHud") as ObjectiveHud
	var status: Control=hud.get("_projection_status")
	var message: Control=hud.get("_message")
	var slots: Control=hud.get("_slots")
	var map: Control=hud.get("minimap")
	var captions: Control=current_scene.get_node("StealthHud").captions
	var bad: Array[String]=[]
	for pair in [[status,map],[status,slots],[status,captions],[message,map],[message,status],[message,captions]]:
		if pair[0].get_global_rect().intersects(pair[1].get_global_rect()): bad.append(str(pair[0].name)+" / "+str(pair[1].name))
	if not bad.is_empty(): failures.append("HUD %s @%s: %s"%[view,scale,bad])
	ui_checks.append({"requested_window":str(view),"scale":scale,"viewport":str(root.get_visible_rect().size),"status":str(status.get_global_rect()),"message":str(message.get_global_rect()),"minimap":str(map.get_global_rect()),"caption_box":str(captions.get_global_rect()),"overlaps":bad})

func _view(p: Vector3,target: Vector3) -> void:
	player.position=p
	# Eye-level inspection must not photograph the guard's own helmet.
	player.camera.cull_mask=5 if p==C.POST else 1048575
	var forward := target-(p+Vector3(0,player.stand_eye_height,0))
	player.rotation.y=atan2(-forward.x,-forward.z)
	player.head.rotation=Vector3.ZERO
	player.camera.rotation=Vector3.ZERO
	player.camera.look_at(target)

func _shot(title: String) -> void:
	await _frames(18)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT.path_join(title+".png")))
	print("[K17 V6 capture] ",title)

func _frames(count: int) -> void:
	for i in count:
		if is_instance_valid(flow) and flow.state==GameStateMachine.State.PAUSED: flow.resume()
		await physics_frame
