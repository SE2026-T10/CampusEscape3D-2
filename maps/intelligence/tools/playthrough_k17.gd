extends SceneTree

## Collision/interaction playthrough with the real shared player controller.
## Guards are disabled ONLY in this QA tool to isolate geometry; the shipping
## scene keeps all four guards active. Use -- --out=res://... for screenshots.
const SCENE := "res://maps/intelligence/scenes/intelligence_k17.tscn"
const Cleanup := preload("res://tests/test_utils.gd")
var failures: Array[String] = []
var out := ""
var capture_only := false
var level: Node3D
var player: FirstPersonPlayer
var mission: K17MissionController
var flow: GameFlow
var waypoints := 0
var live_guards := false
var crouched := false
var prepare_backdoor := false
var use_radio := false
var walk_exit := false
var selected_route := ""
var entry_route := ""
var wait_for_radio := false
var sprint_yard := false
var settle_before_file := false
var stage_delay := 0.0
var yard_flank := false
var _route_failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--live-guards": live_guards = true
		if arg == "--crouch": crouched = true
		if arg == "--prepare": prepare_backdoor = true
		if arg == "--radio": use_radio = true
		if arg == "--walk-exit": walk_exit = true
		if arg == "--wait-radio": wait_for_radio = true
		if arg == "--sprint-yard": sprint_yard = true
		if arg == "--settle-before-file": settle_before_file = true
		if arg == "--yard-flank": yard_flank = true
		if arg.begins_with("--stage-delay="): stage_delay = float(arg.trim_prefix("--stage-delay="))
		if arg.begins_with("--entry="): entry_route = arg.trim_prefix("--entry=")
		if arg.begins_with("--route="): selected_route = arg.trim_prefix("--route=")
		if arg == "--capture-only":
			capture_only = true
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	if out != "" and DisplayServer.get_name() != "headless":
		change_scene_to_file(GameFlow.MAIN_MENU_SCENE)
		await _frames(30)
		await _shot("00_menu")
	if capture_only:
		await _capture_preview()
		quit(0)
		return
	var routes := ["courtyard", "maintenance"] if selected_route == "" else [selected_route]
	for route in routes:
		_route_failed = false
		change_scene_to_file(SCENE)
		await _frames(45)
		level = current_scene as Node3D
		player = level.get_node("Player") as FirstPersonPlayer
		mission = level.get_node("Gameplay/Mission") as K17MissionController
		flow = GameFlow.find(level)
		StealthDirector.find(level).player_caught.connect(func(by: Guard):
			print("  [K17 caught] ",by.name," at ",by.global_position," heard=",by.hearing.last_report_type," estimate=",by.hearing.last_estimate))
		if flow.state == GameStateMachine.State.PAUSED:
			flow.resume()
		if not live_guards:
			for guard in level.get_node("Guards").get_children(): guard.process_mode = Node.PROCESS_MODE_DISABLED
		if crouched: Input.action_press("crouch")
		if route == "courtyard":
			await _shot("01_spawn")
		if (route if entry_route == "" else entry_route) == "courtyard":
			await _route([Vector3(-16, 0, 20), Vector3(-12, 0, 18), Vector3(-12, 0, 11), Vector3(-12, 0, 5.6)])
		else:
			await _route([Vector3(16, 0, 27), Vector3(16, 0, 18), Vector3(16, 0, 7), Vector3(4, 0, 7), Vector3(-12, 0, 7), Vector3(-12, 0, 5.6)])
		await _use("Gameplay/AccessPass")
		if prepare_backdoor:
			await _route([Vector3(-8,0,7),Vector3(16,0,7),Vector3(17.2,0,5)])
			await _use("Gameplay/Security/PreparedLatch")
			await _route([Vector3(16,0,7)])
		if prepare_backdoor:
			await _route([Vector3(4,0,7),Vector3(4,0,1.6)])
		else:
			await _route([Vector3(-8, 0, 7), Vector3(4, 0, 7), Vector3(4, 0, 1.6)])
		await _use("Gameplay/ArchiveDoor")
		await _route([Vector3(4, 0, -1), Vector3(10.8, 0, -1), Vector3(10.8, 0, -6), Vector3(8, 0, -6)])
		if settle_before_file and not _route_failed:
			var quiet_frames := 0
			for i in 3600:
				if flow.state != GameStateMachine.State.PLAYING: break
				quiet_frames = quiet_frames+1 if StealthDirector.find(level).status == StealthDirector.Status.NONE else 0
				if quiet_frames >= 180: break
				await physics_frame
			print("  [K17 prepared] checkpoint=",CheckpointManager.find(level).active != null," quiet=",quiet_frames," status=",StealthDirector.find(level).status)
		if stage_delay > 0.0: await _frames(ceili(stage_delay*Engine.physics_ticks_per_second))
		await _route([Vector3(10, 0, -6), Vector3(10, 0, -20), Vector3(4, 0, -18.5)])
		await _use("Gameplay/IntelligenceFile")
		if walk_exit: Input.action_release("crouch")
		if not mission.has_file:
			failures.append(route + ": file was not acquired")
		if route == "courtyard":
			await _shot("02_archive_and_countdown")
		await _route([Vector3(10, 0, -20), Vector3(10.8, 0, -6), Vector3(10.8, 0, -1), Vector3(4, 0, -1), Vector3(4, 0, 7)])
		if use_radio:
			await _route([Vector3(0,0,7),Vector3(0,0,10.7),Vector3(1.9,0,11.5)])
			await _use("Gameplay/Security/Radio")
			if wait_for_radio: await _frames(480)
			await _route([Vector3(0,0,10.7),Vector3(0,0,7)])
		if route == "courtyard":
			if yard_flank:
				await _route([Vector3(16,0,7),Vector3(16,0,18),Vector3(16,0,20.5),Vector3(-16,0,20.5),Vector3(-16,0,25.7)])
			else:
				await _route([Vector3(-12, 0, 7), Vector3(-12, 0, 18), Vector3(-16, 0, 20), Vector3(-16, 0, 25.7)])
		else:
			await _route([Vector3(16, 0, 7), Vector3(16, 0, 18), Vector3(16,0,20.35)])
			await _use("Gameplay/Security/MaintenanceGate")
			await _route([Vector3(16,0,25.7)])
		await _frames(5)
		if flow.state != GameStateMachine.State.WIN:
			failures.append(route + ": did not win after walking into extraction")
		print("  [K17 walking] ", route, ": ", waypoints, " waypoints; remaining=",snappedf(mission.time_left,.1)," state=",flow.state," catches=",StealthDirector.find(level).catches," sensor_trips=",mission.sensor_trips," radio=",mission.radio_uses," prepared=",mission.backdoor_prepared)
		if route == "courtyard":
			await _shot("03_victory")
		else:
			await _shot("04_maintenance_victory")
		Input.action_release("crouch")
		Input.action_release("sprint")
		current_scene = null
		level.queue_free()
		await _frames(40)
	for failure in failures:
		printerr(failure)
	await Cleanup.settle_async_audio(self)
	print("K17 WALKING PASSED (%d waypoints, %d routes; NPC active=%s)" % [waypoints,routes.size(),str(live_guards)] if failures.is_empty() else "K17 WALKING FAILED")
	quit(0 if failures.is_empty() else 1)


func _route(points: Array) -> void:
	if _route_failed: return
	for target in points:
		if not await _walk(target):
			_route_failed = true
			return


func _walk(target: Vector3) -> bool:
	waypoints += 1
	player.get_node("Head").rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	Input.action_press("move_forward")
	var arrived := false
	for i in 1800:
		if flow.state != GameStateMachine.State.PLAYING:
			break
		var delta := Vector2(target.x - player.global_position.x, target.z - player.global_position.z)
		if delta.length() < 0.38:
			arrived = true
			break
		player.rotation.y = atan2(-delta.x, -delta.y)
		if sprint_yard and mission.has_file and player.global_position.z >= 14.0:
			Input.action_release("crouch")
			Input.action_press("sprint")
		if _should_wait_for_sensor(target):
			Input.action_release("move_forward")
			await physics_frame
			continue
		Input.action_press("move_forward")
		await physics_frame
	Input.action_release("move_forward")
	await _frames(6)
	if not arrived and flow.state != GameStateMachine.State.WIN:
		failures.append("Blocked walking toward %s (actual %s, state %s)" % [target, player.global_position, flow.state])
		return false
	return true


func _should_wait_for_sensor(target: Vector3) -> bool:
	var p := player.global_position
	for sensor in get_nodes_in_group("k17_sensors"):
		var s: Vector3 = sensor.global_position
		if absf(p.x-s.x) > 2.0 or absf(p.z-s.z) > 1.4 or absf(p.z-s.z) < .55: continue
		if (target.z-s.z)*(p.z-s.z) >= 0.0: continue
		if sensor.get_phase() != 0 or sensor.seconds_until_change() < 1.6: return true
	return false


func _use(path: String) -> void:
	if _route_failed: return
	var target := level.get_node(path) as Interactable
	player.camera.look_at(target.global_position)
	await _frames(3)
	var interactor := player.get_node("Interactor") as PlayerInteractor
	if interactor.focused != target:
		failures.append("Cannot aim at " + path + " from " + str(player.global_position))
		return
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	root.push_input(press)
	var duration := target.get_hold_duration(player)
	if duration > 0.0: await _frames(ceili(duration*Engine.physics_ticks_per_second)+3)
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	root.push_input(release)
	await _frames(3)


func _shot(name: String) -> void:
	if out == "" or DisplayServer.get_name() == "headless":
		return
	await _frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out.path_join(name + ".png")))


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


## Staged screenshots for visual QA, separate from the walking assertions.
func _capture_preview() -> void:
	change_scene_to_file(SCENE)
	await _frames(30)
	level = current_scene as Node3D
	player = level.get_node("Player") as FirstPersonPlayer
	mission = level.get_node("Gameplay/Mission") as K17MissionController
	flow = GameFlow.find(level)
	if flow.state == GameStateMachine.State.PAUSED:
		flow.resume()
	for guard in level.get_node("Guards").get_children():
		guard.process_mode = Node.PROCESS_MODE_DISABLED
	await _shot("01_spawn")
	var objectives := ObjectiveManager.find(level)
	objectives.complete(K17MissionController.ENTER)
	objectives.complete(K17MissionController.PASS)
	level.get_node("Gameplay/ArchiveDoor").open()
	player.global_position = Vector3(8, 0.05, -6)
	await _frames(3)
	player.global_position = Vector3(4, 0.05, -18.5)
	player.camera.look_at(Vector3(4, 1.15, -20))
	objectives.complete(K17MissionController.FILE)
	await _shot("02_archive_and_countdown")
	mission.time_left = 0.01
	await _frames(15)
	await _shot("04_failure")
	flow.retry_checkpoint()
	await _frames(3)
	objectives.complete(K17MissionController.FILE)
	mission.try_extract(&"courtyard", "Sân tiếp vận")
	await _frames(45)
	await _shot("03_victory")
	paused = false
	current_scene = null
	level.queue_free()
	await _frames(40)
	print("K17 VISUAL CAPTURED (staged states; use normal mode for walking QA)")
