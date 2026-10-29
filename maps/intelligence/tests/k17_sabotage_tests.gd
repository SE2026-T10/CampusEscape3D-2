extends RefCounted
## Isolated fixtures exercise real interaction/mission/reset code; walking E2E is separate.
const C := preload("res://maps/intelligence/resources/layout/k17_sabotage.gd")
const M := preload("res://maps/intelligence/scripts/mission_controller.gd")
const Utils := preload("res://tests/test_utils.gd")
const G := GameStateMachine.State
var host: Node
var level: Node3D
var player: FirstPersonPlayer
var mission: K17MissionController
var flow: GameFlow
var objectives: ObjectiveManager
var device: Node3D
var finale: Node3D
var checks := 0
var failures: Array[String] = []

func run(parent: Node) -> Array[String]:
	host = parent
	await _load()
	await _interaction_and_reset()
	await _finale_and_pause()
	await _unload()
	for route in [&"courtyard", &"maintenance"]:
		await _load()
		await _file()
		device.plant()
		_expect(mission.try_extract(route,"Tuyến thử"),"Both routes accept armed extraction: "+str(route))
		await _frames(34)
		var enter := InputEventAction.new()
		enter.action = &"ui_accept"
		enter.pressed = true
		host.get_viewport().push_input(enter)
		await _frames(3)
		_expect(flow.state==G.WIN and device.detonated,"Fresh Enter skips through the real finale completion path")
		_expect(not flow.is_leaving(),"Skip input never activates the focused Play again button")
		_expect(objectives.escape_route==route,"Cinematic keeps the actual escape route")
		await _unload()
	await _load()
	await _file()
	device.plant()
	finale.free()
	_expect(mission.try_extract(&"maintenance","Bảo trì") and flow.state==G.WIN and device.detonated,"Missing presentation falls back to authoritative detonation and WIN")
	await _unload()
	await _load()
	await _file()
	device.plant()
	mission.try_extract(&"maintenance","Bảo trì")
	finale.set_physics_process(false)
	mission._physics_process(C.FINALE_WATCHDOG+.1)
	_expect(flow.state==G.WIN and device.detonations==1 and not finale.active,"A stalled presentation cannot softlock extraction")
	await _unload()
	for leave in ["restart","menu"]:
		await _load()
		await _file()
		device.plant()
		mission.try_extract(&"maintenance","Bảo trì")
		var requests: Array[String]=[]
		flow.change_scene=func(path: String): requests.append(path)
		if leave=="restart": flow.restart()
		else: flow.go_to_main_menu()
		finale._physics_process(.1)
		mission.complete_finale(mission.run_id)
		_expect(requests.size()==1 and not finale.active and not device.detonated and flow.state!=G.WIN,"Leaving cancels finale without completing the abandoned run: "+leave)
		await _unload()
	await _load()
	await _file()
	device.plant()
	mission.time_left=0
	player.global_position=Vector3(36,.05,51)
	await _frames(3)
	_expect(flow.state==G.FAILED and not mission.escaped and not device.detonated,"Deadline wins the zero-second extraction tie, even when armed")
	_expect(flow.retry_checkpoint(),"Armed timeout can retry the checkpoint")
	await _frames(3)
	_expect(not device.armed and not device.detonated and not mission.has_file,"Timeout retry restores one unused mission device and pre-file state")
	await _unload()
	print("K17 V5 CHECKS: %d checks; %d failures"%[checks,failures.size()])
	return failures

func _load() -> void:
	level=(load("res://maps/intelligence/scenes/intelligence_k17.tscn") as PackedScene).instantiate()
	_expect(await Utils.add_level_and_wait_for_navigation(host,level,Vector3(-36,.05,51)),"V5 navigation ready")
	player=level.get_node("Player")
	player.set_physics_process(false)
	for actor in level.get_node("Guards").get_children(): actor.process_mode=Node.PROCESS_MODE_DISABLED
	for camera in host.get_tree().get_nodes_in_group("security_cameras"): camera.set_physics_process(false)
	level.get_node("Gameplay/Reinforcements").set_physics_process(false)
	level.get_node("Gameplay/PowerNetwork").set_physics_process(false)
	mission=level.get_node("Gameplay/Mission")
	flow=GameFlow.find(level)
	objectives=ObjectiveManager.find(level)
	device=level.get_node("Gameplay/Sabotage")
	finale=level.get_node("Gameplay/ExtractionFinale")
	if flow.state==G.PAUSED: flow.resume()

func _file() -> void:
	for id in [M.ENTER,M.PASS,M.CODE,M.ARCHIVE,M.VAULT]: objectives.complete(id)
	player.global_position=Vector3(8,.05,-20)
	await _frames(4)
	_expect(CheckpointManager.find(level).active!=null,"Fixture saves a real pre-file checkpoint")
	objectives.complete(M.FILE)
	await _frames(2)

func _aim() -> Interactable:
	player.global_position=C.STAND
	player.camera.look_at(device.get_node("Target").global_position)
	await _frames(4)
	var target := device.get_node("Target") as Interactable
	_expect(player.get_node("Interactor").focused==target,"Real ray reaches the device face without crossing the cabinet collider")
	return target

func _interaction_and_reset() -> void:
	var target: Interactable=await _aim()
	_expect(not target.can_interact(player) and target.get_prompt(player).contains("thu hồi hồ sơ"),"Locked target explains the missing file")
	_expect(not target.interact(player),"Cannot plant before file")
	var path := NavigationServer3D.map_get_path(level.get_world_3d().navigation_map,Vector3(32.2,.05,15),C.STAND,true)
	_expect(not path.is_empty() and path[-1].distance_to(C.STAND)<.7,"Planting stand is connected to the real maintenance navigation")
	var space := level.get_world_3d().direct_space_state
	var support := space.intersect_ray(PhysicsRayQueryParameters3D.create(C.TARGET+Vector3(0,.05,0),C.TARGET-Vector3(0,.15,0),1))
	_expect(not support.is_empty(),"Cabinet plinth rests on the workshop floor")
	var guard := level.get_node("Guards/Guard4") as Guard
	var guard_pose := guard.transform
	guard.global_position=Vector3(36,.05,14)
	var direction := player.global_position-guard.global_position
	guard.rotation.y=atan2(-direction.x,-direction.z)
	guard.vision.reset()
	guard.vision._physics_process(.2)
	_expect(guard.vision._check_sight(),"The open workshop approach exposes the planting stand to a real guard")
	guard.transform=guard_pose
	await _file()
	target=await _aim()
	var inventory := PlayerInventory.find(level)
	var before: Dictionary = inventory.get_checkpoint_state().duplicate(true)
	_expect(objectives.get_mandatory_ids().size()==7 and objectives.get_optional_ids().size()==3 and objectives.is_optional(M.SABOTAGE),"Seven mandatory and three optional objectives")
	_expect(objectives.get_requires(M.ESCAPE)==[M.FILE],"Sabotage never becomes a dependency of escape")
	_expect(is_equal_approx(target.hold_duration,5.0),"Planting uses a five-second shared hold")
	var interactor := player.get_node("Interactor") as PlayerInteractor
	Input.action_press("interact")
	_expect(interactor.try_interact(),"Actual interactor starts planting")
	await _frames(120)
	Input.action_release("interact")
	await _frames(2)
	_expect(not device.armed and interactor.hold_target==null,"Releasing E cancels without consuming the device")
	Input.action_press("interact")
	interactor.try_interact()
	await _frames(25)
	player.camera.look_at(C.TARGET+Vector3(5,1,0))
	await _frames(2)
	Input.action_release("interact")
	_expect(not device.armed and interactor.hold_target==null,"Looking away cancels the real hold")
	target=await _aim()
	Input.action_press("interact")
	interactor.try_interact()
	await _frames(25)
	flow.pause()
	var remaining := mission.time_left
	await _frames(15)
	_expect(not device.armed and interactor.hold_target==null and mission.time_left==remaining,"Pause cancels hold and freezes the deadline")
	Input.action_release("interact")
	flow.resume()
	await _frames(3)
	Input.action_press("interact")
	_expect(interactor.try_interact(),"Canceled planting can restart")
	remaining=mission.time_left
	await _frames(304)
	Input.action_release("interact")
	_expect(device.armed and device.placements==1 and mission.time_left<remaining-4.9,"Five seconds elapse on the same escape clock while planting")
	_expect(not objectives.is_completed(M.SABOTAGE),"Planting alone is not sabotage completion")
	_expect(not target.interact(player) and device.placements==1,"Repeated interaction cannot create a second device")
	_expect(inventory.get_checkpoint_state()==before,"Mission equipment leaves the three-slot inventory untouched")
	var old_run := mission.run_id
	StealthDirector.find(level)._catch(level.get_node("Guards/Guard1"))
	_expect(not device.can_plant(),"Caught players cannot plant")
	StealthDirector.find(level).reset_level()
	await _frames(4)
	for actor in level.get_node("Guards").get_children(): actor.process_mode=Node.PROCESS_MODE_DISABLED
	_expect(not mission.has_file and not device.armed and not device.detonated and device.placements==0,"Real checkpoint reset removes the planted device")
	mission.complete_finale(old_run)
	_expect(flow.state==G.PLAYING and not device.detonated,"An old run token cannot finish a restored attempt")

func _finale_and_pause() -> void:
	await _file()
	device.plant()
	mission.time_left=.1
	var remaining := mission.time_left
	var play_time := flow.play_time
	_expect(mission.try_extract(&"maintenance","Hành lang bảo trì"),"Positive deadline accepts armed extraction")
	_expect(flow.state==G.PLAYING and finale.active and mission.finale_pending,"WIN waits for the finale")
	_expect(not mission.try_extract(&"courtyard","Sân") and finale.starts==1,"Repeated extraction creates one finale")
	var team := level.get_node("Gameplay/Reinforcements")
	team.wave_times=Vector2.ZERO
	team._physics_process(0)
	var power := level.get_node("Gameplay/PowerNetwork")
	power.backup_active=false
	power._physics_process(0)
	_expect(team.spawned_count==0 and not power.backup_active,"Dispatch and backup stop at extraction commit")
	flow.pause()
	var elapsed: float=finale.elapsed
	await _frames(30)
	finale.finish()
	_expect(finale.elapsed==elapsed and finale.active and not device.detonated,"Paused finale cannot progress or skip")
	flow.resume()
	await _frames(62)
	_expect(device.detonated and device.detonations==1 and objectives.is_completed(M.SABOTAGE),"Logical detonation completes the optional objective once")
	_expect(flow.state==G.PLAYING and mission.time_left==remaining,"Committed escape never times out during the scene")
	_expect(not device.get_node("Intact").visible and device.get_node("Damaged").visible,"Destroyed equipment replaces the intact visual")
	flow._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(3)
	_expect(flow.state==G.PAUSED and finale._sound.stream_paused,"Focus loss pauses cinematic sound and gameplay")
	flow.resume()
	await _frames(200)
	_expect(flow.state==G.WIN and not finale.active and device.detonations==1,"Natural finale reaches WIN once")
	_expect(is_equal_approx(mission.extraction_play_time,play_time),"Results preserve the gameplay time captured at extraction")
	_expect(level.get_node("GameMenus").get_win_text().contains("phá hủy") and mission.time_left==remaining,"Vietnamese result includes sabotage and frozen remaining time")
	mission.complete_finale(mission.run_id)
	_expect(device.detonations==1 and flow.state==G.WIN,"Late finish callbacks are harmless")
	var menus := level.get_node("GameMenus") as GameMenus
	var window := host.get_window()
	var previous_scale := GameSettings.hud_scale
	var previous_size := window.size
	for size in [Vector2i(1280,720),Vector2i(1024,768)]:
		window.size=size
		GameSettings.hud_scale=1.25
		GameSettings.apply(host.get_tree())
		for i in 6: await host.get_tree().process_frame
		var view := menus.get_viewport().get_visible_rect().grow(1)
		_expect(view.encloses(menus.play_again_button.get_global_rect()) and view.encloses(menus.win_title.get_global_rect()) and view.encloses(menus._win_stats.get_global_rect()),"V5 result fits at enlarged HUD scale: "+str(size))
	window.size=previous_size
	GameSettings.hud_scale=previous_scale
	GameSettings.apply(host.get_tree())

func _unload() -> void:
	Input.action_release("interact")
	host.get_tree().paused=false
	level.queue_free()
	await _frames(40)
	_expect(host.get_tree().get_nodes_in_group("k17_mission").is_empty(),"Leaving releases mission state")

func _frames(count: int) -> void:
	for i in count: await host.get_tree().physics_frame

func _expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append("[K17 V5] "+message)
