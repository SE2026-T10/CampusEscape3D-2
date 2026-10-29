extends SceneTree
## Staged renderer captures. Full walking input is verified by playthrough_k17.gd.
const C := preload("res://maps/intelligence/resources/layout/k17_navigation.gd")
const M := preload("res://maps/intelligence/scripts/mission_controller.gd")
const OUT := "res://maps/intelligence/docs/keypad-minimap/screens"
var player: FirstPersonPlayer
var flow: GameFlow
var hud: ObjectiveHud
var report: Dictionary={"scope":"Staged real-renderer inspection; not a walking E2E","keys":[],"door_states":[],"map_snapshots":[]}

func _init() -> void:
	root.unfocusable=true
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,720)
	change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17_test.tscn")
	await _frames(40)
	player=current_scene.get_node("Player")
	player.set_physics_process(false)
	flow=GameFlow.find(current_scene)
	hud=current_scene.get_node("ObjectiveHud")
	var keypad: CodeLock=current_scene.get_node("Gameplay/VaultKeypad")
	var casing: MeshInstance3D=keypad.get_node("Housing/Case")
	var face: MeshInstance3D=keypad.get_node("Housing/KeyboardFace")
	var case_bounds: AABB=casing.global_transform*casing.get_aabb()
	var face_bounds: AABB=face.global_transform*face.get_aabb()
	for control in keypad.dials+[keypad.enter]:
		var cap: MeshInstance3D=control.get_node("Model/Cap")
		var bounds: AABB=cap.global_transform*cap.get_aabb()
		report.keys.append({"name":str(control.name),"cap_back_z":bounds.position.z,"case_front_z":case_bounds.end.z,"keyboard_face_z":face_bounds.end.z,"seating_overlap_m":face_bounds.end.z-bounds.position.z})
	report["case_back_z"]=case_bounds.position.z
	_door_sample("closed")
	await _shot("01_spawn_ground")
	player.position=C.KEYPAD_STAND
	player.camera.look_at(C.KEYPAD+Vector3(0,.2,0))
	await _frames(10)
	await _shot("02_keypad_closed")
	player.position=Vector3(7.35,0,-22.7)
	player.camera.look_at(C.KEYPAD+Vector3(0,.2,0))
	await _frames(10)
	await _shot("03_keypad_side")
	player.position=Vector3(4.4,0,-21.2)
	player.camera.look_at(Vector3(4.7,1.4,-24))
	current_scene.get_node("Gameplay/VaultDoor").open()
	await _frames(12)
	_door_sample("opening")
	await _shot("04_door_opening")
	await _frames(35)
	_door_sample("open")
	await _shot("05_door_open")
	PlayerInventory.find(current_scene).add(ItemCatalog.STAFF_CARD)
	for id in [M.ENTER,M.PASS,M.CODE,M.ARCHIVE]: ObjectiveManager.find(current_scene).complete(id)
	player.position=C.KEYPAD_STAND
	player.camera.look_at(C.KEYPAD+Vector3(0,.2,0))
	await _frames(10)
	await _shot("06_keypad_ready")
	player.position=Vector3(8,-4,-48.5)
	player.camera.look_at(Vector3(0,-2.4,-40))
	await _frames(12)
	await _shot("07_basement_position")
	player.position=Vector3(30,-2,-29)
	player.camera.look_at(Vector3(30,1.4,-22))
	await _frames(8)
	await _shot("08_stairs_position")
	player.position=C.KEYPAD_STAND
	player.camera.look_at(C.KEYPAD+Vector3(0,.2,0))
	var layouts: Array[Dictionary]=[]
	var old_scale:=GameSettings.hud_scale
	ObjectiveManager.find(current_scene).discover(M.SABOTAGE)
	for size_ in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(1920,1080)]:
		root.size=size_
		for scale_ in [1.0,1.25]:
			GameSettings.hud_scale=scale_
			GameSettings.apply(self)
			hud.show_message("Mục tiêu tùy chọn: đặt thiết bị, rồi rút tới tập kết trước khi hết 120 giây.")
			await _frames(10)
			var entry:={"window":str(root.size),"scale":scale_,"canvas":str(hud.get_viewport().get_visible_rect()),"panels":{}}
			for name in hud.get_layout_controls():
				entry.panels[name]=str(hud.get_layout_controls()[name].get_global_rect())
			layouts.append(entry)
			await _shot("hud_%dx%d_%d"%[size_.x,size_.y,roundi(scale_*100)])
	GameSettings.hud_scale=old_scale
	GameSettings.apply(self)
	FileAccess.open(OUT+"/layouts.json",FileAccess.WRITE).store_string(JSON.stringify(layouts,"\t"))
	FileAccess.open(OUT.get_base_dir()+"/AFTER.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	current_scene.queue_free()
	await _frames(40)
	await preload("res://tests/test_utils.gd").settle_async_audio(self)
	print("K17 NAVIGATION VISUAL CAPTURES COMPLETE")
	quit()

func _shot(title: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT.path_join(title+".png")))
	var map:=current_scene.get_node("ObjectiveHud/Minimap")
	report.map_snapshots.append({"name":title,"player_world":str(player.global_position),"player_map_local":str(map.marker_local),"floor":map.floor_id,"marker_pixel":str(map.marker.position),"heading_radians":map.marker_heading})

func _door_sample(title: String) -> void:
	var door:=current_scene.get_node("Gameplay/VaultDoor") as AccessDoor
	var hinge:=door.get_node("DoorHinge") as Node3D
	report.door_states.append({"name":title,"is_open":door.is_open,"leaf_visible":hinge.is_visible_in_tree(),"leaf_angle":hinge.rotation_degrees.y,"keypad_world":str(current_scene.get_node("Gameplay/VaultKeypad").global_position)})

func _frames(count: int) -> void:
	for i in count:
		if is_instance_valid(current_scene):
			var active_flow:=GameFlow.find(current_scene)
			if active_flow and active_flow.state==GameStateMachine.State.PAUSED: active_flow.resume()
		await physics_frame
