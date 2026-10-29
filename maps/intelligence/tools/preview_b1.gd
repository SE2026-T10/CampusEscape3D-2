extends SceneTree
## Deliberately staged renderer inspection, not walking proof.
const C:=preload("res://maps/intelligence/resources/layout/k17_projection.gd")
const OUT:="res://maps/intelligence/docs/b1-refinement/screens"
var player: FirstPersonPlayer
var flow: GameFlow
var layouts: Array[Dictionary]=[]
var failures: Array[String]=[]

func _init() -> void:
	root.unfocusable=true
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,720)
	change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17.tscn")
	await frames(45)
	flow=GameFlow.find(current_scene)
	player=current_scene.get_node("Player")
	player.set_physics_process(false)
	for guard in current_scene.get_node("Guards").get_children(): guard.process_mode=Node.PROCESS_MODE_DISABLED
	for id in [K17MissionController.ENTER,K17MissionController.PASS,K17MissionController.CODE,K17MissionController.ARCHIVE,K17MissionController.VAULT]: ObjectiveManager.find(current_scene).complete(id)
	var rig:=current_scene.get_node("Gameplay/ProjectionRig")
	var system:=current_scene.get_node("Gameplay/B1Surveillance")
	view(Vector3(4,-4,-36),Vector3(4,-2.8,-43))
	await shot("01_sensors")
	view(Vector3(4.05,-4,-50.6),C.HACK)
	await shot("02_hack_console")
	system.hack()
	rig.deploy()
	rig.position=Vector3(-6,-4,-47)
	system.feed_mode=1
	view(rig.to_global(C.GRIP_OFFSET),rig.to_global(Vector3(0,1.4,-4)))
	await shot("03_front_feed")
	system.feed_mode=2
	await shot("04_c1_feed")
	system.feed_mode=0
	view(C.POST+Vector3(.6,0,0),Vector3(-1,-2.4,-47))
	player.camera.cull_mask=5
	await shot("05_post_projection")
	player.camera.cull_mask=1048575
	rig.position=C.BAYS[0]
	view(Vector3(.2,-4,-50.7),rig.position+Vector3(0,1.1,0))
	await shot("06_bay_1")
	rig.position=C.DOCK
	view(Vector3(-14.4,-4,-47),C.ROOM_LOCK)
	system.feed_mode=2
	await shot("07_archive_lock")
	current_scene.get_node("Gameplay/ArchiveLock").interact(player)
	await frames(60)
	view(Vector3(-14,-4,-44),C.FILE)
	system.feed_mode=0
	await shot("08_archive_open")
	for window in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(1024,768)]:
		root.size=window
		for scale_ in [1.0,1.25]:
			root.content_scale_factor=scale_
			view(Vector3(-14.4,-4,-47),C.ROOM_LOCK)
			for i in 4: SoundCaptions.cue(current_scene,"b1_qa_"+str(i),["Bước chân bên hông","Máy trực xác nhận","Tiếng bánh xe","Vô tuyến tuần tra"][i],Vector3(-10,-2.4,-43),100)
			for feed in [1,2]:
				system.feed_mode=feed
				await frames(20)
				check_ui(window,scale_,feed)
			await shot("hud_%dx%d_%d"%[window.x,window.y,int(scale_*100)])
	FileAccess.open(OUT+"/layouts.json",FileAccess.WRITE).store_string(JSON.stringify({"layouts":layouts,"failures":failures},"\t"))
	root.size=Vector2i(1280,720)
	root.content_scale_factor=1.0
	system.feed_mode=0
	# Real eye positions through W1/W2, with the actor and cart in the bay.
	var inspection:=Camera3D.new()
	current_scene.add_child(inspection)
	inspection.current=true
	for i in 2:
		rig.position=C.BAYS[i]
		player.position=rig.to_global(C.GRIP_OFFSET)
		inspection.position=Vector3(-3 if i==0 else -10.2,-2.4,-43.2)
		inspection.look_at(rig.position+Vector3(0,1.1,0))
		await shot("10_w%d_hidden_bay"%(i+1))
	inspection.position=C.CCTV
	rig.position=C.DOCK
	player.position=rig.to_global(C.GRIP_OFFSET)
	inspection.look_at(Vector3(0,-2.7,-47))
	await shot("11_c1_actual_view")
	inspection.queue_free()
	# Orthographic plan from an actual camera; no fabricated representation.
	var top:=Camera3D.new()
	current_scene.add_child(top)
	top.position=Vector3(-5,8,-43)
	top.rotation_degrees=Vector3(-90,0,0)
	top.projection=Camera3D.PROJECTION_ORTHOGONAL
	top.size=47
	top.cull_mask=7
	top.current=true
	# Hide only the ceiling/roof meshes in this explicit plan inspection.
	for mesh in current_scene.find_children("*","MeshInstance3D",true,false):
		var bounds: AABB=mesh.global_transform*mesh.get_aabb()
		if bounds.position.y> -1.7: mesh.hide()
	await shot("09_floor_plan")
	current_scene.queue_free()
	await frames(25)
	await preload("res://tests/test_utils.gd").settle_async_audio(self)
	print("B1 RENDER CAPTURES COMPLETE / ",layouts.size()," feed/layout checks, ",failures.size()," overlaps")
	quit(0 if failures.is_empty() else 1)

func check_ui(window: Vector2i,scale_: float,feed: int) -> void:
	var hud:=current_scene.get_node("ObjectiveHud")
	var panel: Control=current_scene.get_node("Gameplay/B1Surveillance")._panel
	var bad: Array[String]=[]
	for control: Control in [hud._status_panel,hud._panel,hud.minimap,hud._projection_status,hud._slots,current_scene.get_node("StealthHud").captions]:
		if control.visible and panel.get_global_rect().intersects(control.get_global_rect()): bad.append(str(control.name))
	var view_:=root.get_visible_rect()
	if not view_.encloses(panel.get_global_rect()): bad.append("outside viewport")
	if not bad.is_empty(): failures.append("%s @%s / feed %d: %s"%[window,scale_,feed,bad])
	layouts.append({"window":str(window),"scale":scale_,"feed":feed,"logical_viewport":str(view_.size),"feed_rect":str(panel.get_global_rect()),"overlaps":bad})

func view(position_: Vector3,target: Vector3) -> void:
	player.position=position_
	player.rotation.y=0
	player.head.rotation=Vector3.ZERO
	player.camera.rotation=Vector3.ZERO
	player.camera.look_at(target)

func shot(title: String) -> void:
	await frames(24)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT.path_join(title+".png")))
	print("[B1 capture] ",title)

func frames(count: int) -> void:
	for i in count:
		if is_instance_valid(flow) and flow.state==GameStateMachine.State.PAUSED: flow.resume()
		await physics_frame
