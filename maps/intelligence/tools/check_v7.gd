extends SceneTree
## Stages specific states for presentation checks. Walking E2E uses playthrough_k17.gd.
const M := preload("res://maps/intelligence/scripts/mission_controller.gd")
const Layout := preload("res://maps/intelligence/resources/layout/k17_layout.gd")
const B1 := preload("res://maps/intelligence/resources/layout/k17_projection.gd")
const Cleanup := preload("res://tests/test_utils.gd")
const MAP := "res://maps/intelligence/scenes/intelligence_k17%s.tscn"
var _checks := 0
var _failures: Array[String] = []
var _flow: GameFlow
var _out := ""


func _init() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _run() -> void:
	AudioServer.set_bus_mute(0,true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): _out=arg.trim_prefix("--out=")
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
	for test_mode in [false,true]:
		change_scene_to_file(MAP % ("_test" if test_mode else ""))
		await _frames(40)
		_flow=GameFlow.find(current_scene)
		if _flow.state==GameStateMachine.State.PAUSED:
			_flow.resume()
		var level := current_scene
		for guard in level.get_node("Guards").get_children():
			guard.process_mode=Node.PROCESS_MODE_DISABLED
		level.get_node("Gameplay/Reinforcements").set_physics_process(false)
		var hud := level.get_node("ObjectiveHud")
		var mission := level.get_node("Gameplay/Mission") as K17MissionController
		var player := level.get_node("Player") as FirstPersonPlayer
		var rig := level.get_node("Gameplay/ProjectionRig") as K17ProjectionRig
		var system := level.get_node("Gameplay/B1Surveillance")
		var objectives := ObjectiveManager.find(level)
		var suffix := "test" if test_mode else "normal"
		player.set_physics_process(false)
		for id in [M.ENTER,M.PASS,M.CODE,M.ARCHIVE,M.VAULT]:
			objectives.complete(id)
		rig.position=Vector3(-6,-4,-47)
		player.position=rig.to_global(B1.GRIP_OFFSET)
		player.camera.look_at(rig.global_position+Vector3(-4,1.2,0))
		rig._set_deployed(true)
		rig.powered=true
		_expect(system.hack(),"B1 console enables camera / "+suffix)
		_expect(rig.begin_grip(player),"Player can grip the opaque screen / "+suffix)
		await _frames(15)
		_expect(hud._projection_panel.visible and not hud._status_panel.visible and not hud._list.visible,"B1 uses one status column and a compact objective / "+suffix)
		_expect(hud._b1_hint.visible!=test_mode,"Side-patrol hint is present only with guards / "+suffix)
		_expect(hud._camera_status.text.contains("V xem C1") and hud._projection_status.text.contains("chốt"),"The panel names the current feed, next action and screen audience / "+suffix)
		if test_mode:
			_expect(not system.request_call() and system.call_status().contains("Không có chốt"),"No-guards R reports that there is no post")
		else:
			_expect(hud._b1_hint.text.contains("W1/W2") and not hud._call_status.text.begins_with("R"),"The corridor warns of the side patrol without prompting a stationary call")
			_expect(system.call_status(true).begins_with("R") and not system.call_status(false).begins_with("R"),"An available request is advertised only when the HUD allows it")
			_expect(system.request_call() and system.call_status().contains("đang chờ"),"R shows a request immediately")
			await _frames(95)
			var post: Node3D=system.post()
			_expect(system.call_status().contains("đang quay"),"The HUD distinguishes rotating from observing the terminal")
			post.rotation.y=0
			_expect(system.call_status().contains("nhìn máy"),"HUD confirms actual facing at the terminal")
			post.set("check_left",0.0)
			_expect(system.call_status().contains("Đang hồi"),"HUD displays the cooldown when the check ends")
		if system._panel:
			var controls: Dictionary=hud.get_layout_controls()
			var feed_rect: Rect2=system._panel.get_global_rect()
			var status_rect: Rect2=controls["projection_status"].get_global_rect()
			_expect(system._panel.visible and not feed_rect.intersects(status_rect),"Native video and alignment panels are visible with separate bounds / "+suffix)
			var view := root.get_visible_rect()
			var objective_rect: Rect2=hud._panel.get_global_rect()
			var prompt_rect: Rect2=hud._prompt_box.get_global_rect()
			_expect(view.encloses(feed_rect) and not feed_rect.intersects(objective_rect) and not feed_rect.intersects(prompt_rect),"Video fits without covering objective or interaction / %s %s in %s; objective %s; prompt %s" % [suffix,feed_rect,view,objective_rect,prompt_rect])
		await _shot("b1_"+suffix)
		system.cycle_feed()
		_expect(system.feed_status().contains("C1") and rig.holder==player,"C1 does not release the rig")
		system.cycle_feed()
		await _frames(3)
		_expect(system.feed_status().contains("Đã ẩn") and (not system._panel or not system._panel.visible),"Hidden feed retains its status without a video panel")
		system.restore_checkpoint_state(system.get_checkpoint_state())
		_expect(system.feed_mode==1,"Restoring B1 checkpoint opens the front feed")
		rig.release_grip()

		player.position=Vector3(-18.82,-4,-42.53)
		player.camera.look_at(B1.FILE)
		await _frames(55)
		var audio := AudioDirector.find(level)
		_expect(audio._ambience.volume_db < -23.0,"Archive room tone fades down before pickup / "+suffix)
		_expect(system.feed_mode==0,"Archive hides the feed while retaining access with V")
		await _shot("archive_"+suffix)
		objectives.complete(M.FILE)
		_expect(mission.has_file and is_equal_approx(mission.time_left,120.0),"Pickup starts 120 seconds without a cutscene")
		await _frames(25)
		_expect(system.revoked and system.feed_status().contains("Mất kết nối"),"File retrieval revokes camera access")
		_expect(audio._ambience.volume_db > -22.0 and audio.played.has("alarm"),"Alarm cues pickup and the ambient mix returns")
		_expect(not level.get_node("StealthHud")._banner.text.contains("guards"),"Lockdown has no misleading English guard banner")

		await _check_routes(level,player,mission,hud,suffix)
		current_scene=null
		level.queue_free()
		_flow=null
		await _frames(20)

	await Cleanup.settle_async_audio(self)
	for failure in _failures: printerr(failure)
	print("K17 V7: %d checks; %d failures" % [_checks,_failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _check_routes(level: Node,player: FirstPersonPlayer,mission: K17MissionController,hud: ObjectiveHud,suffix: String) -> void:
	var board := level.get_node("Gameplay/V7Presentation/B1Fork")
	var yard := mission.get_security_node("CourtyardGate") as K17LockdownGate
	var service := mission.get_security_node("MaintenanceGate") as K17LockdownGate
	for name_ in ["B1Fork","GroundFork"]:
		var stand := level.get_node("Gameplay/V7Presentation/"+name_) as Node3D
		for foot in [stand.get_node("WestFoot"),stand.get_node("EastFoot")]:
			var floor_check := PhysicsRayQueryParameters3D.create(foot.global_position+Vector3.UP*.1,foot.global_position-Vector3.UP*.2,17)
			_expect(not player.get_world_3d().direct_space_state.intersect_ray(floor_check).is_empty(),"Sign foot meets collision floor / "+name_)
	mission.set_physics_process(false)
	mission.time_left=50.0
	mission._physics_process(0.0)
	player.position=Vector3(4,-4,-39.5)
	player.camera.look_at(Vector3(4,-1.52,-36.3))
	await _frames(5)
	_expect(mission.route_state(0)==M.RouteState.WARNING and board.get_node("Yard").text.contains("20 giây"),"Board shows the actual scheduled warning")
	_expect(hud.get("minimap").get("_route_marks").x==M.RouteState.WARNING,"Minimap consumes the same warning")
	_expect(ObjectiveManager.find(level).get_hint(M.ESCAPE).contains("Theo biển A hoặc B"),"The shipped objective directs players to the new signs")
	await _shot("b1_fork_"+suffix)
	var yard_split := level.get_node("Gameplay/V7Presentation/YardSplit") as Node3D
	player.position=Vector3(16,0,17)
	player.camera.look_at(yard_split.global_position)
	await _frames(5)
	_expect(yard_split.get_node("Yard").text.contains("VÒNG MÉP NAM") and yard_split.get_node("Yard").text.contains("20 giây"),"The signed yard bypass shows its real closing time")
	_expect(yard_split.get_node("Service").text.begins_with("←") and mission.get_status_lines()[3].contains("phía đông"),"The sign and HUD point to eastern maintenance")
	await _shot("yard_split_"+suffix)
	player.position=Layout.GATES[0]-Vector3.UP*1.1
	await _frames(3)
	mission.time_left=30.0
	mission._physics_process(0.0)
	await _frames(5)
	_expect(yard.closing_pending and not yard.is_closed and board.get_node("Yard").text.contains("Đang đóng"),"Occupied gate has a pending state distinct from locked")
	player.position=Vector3(4,0,5.7)
	player.camera.look_at(Vector3(4,2.48,8.9))
	await _frames(5)
	_expect(yard.is_closed and board.get_node("Yard").text.contains("Đã khóa"),"Cleared yard gate closes and updates signs")
	_expect(service.is_closed and service.get_hold_duration(player)==8.0 and board.get_node("Service").text.contains("8 giây"),"Unprepared rear gate reports the real hold")
	await _shot("ground_fork_"+suffix)
	mission.backdoor_prepared=true
	await _frames(3)
	_expect(service.get_hold_duration(player)==0.0 and board.get_node("Service").text.contains("mở nhanh"),"Prepared rear gate has immediate interaction and matching text")


func _frames(count: int) -> void:
	for i in count:
		if is_instance_valid(_flow) and _flow.state==GameStateMachine.State.PAUSED:
			_flow.resume()
		await physics_frame


func _shot(name_: String) -> void:
	if _out.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join(name_+".png"))


func _expect(condition: bool,message: String) -> void:
	_checks+=1
	print("[V7 %s] %s" % ["OK" if condition else "FAIL",message])
	if not condition: _failures.append(message)
