extends SceneTree

## Collision/interaction playthrough with the real shared player controller.
## Defaults to the playable no-guard variant; --live-guards keeps all six guards
## and the scheduled reinforcement waves. --out=... captures actual milestones.
const SCENE := "res://maps/intelligence/scenes/intelligence_k17.tscn"
const Cleanup := preload("res://tests/test_utils.gd")
var failures: Array[String] = []
var out := ""
var level: Node3D
var player: FirstPersonPlayer
var mission: K17MissionController
var flow: GameFlow
var waypoints := 0
var live_guards := false
var crouched := false
var prepare_backdoor := false
var use_radio := false
var selected_route := ""
var entry_route := ""
var wait_for_radio := false
var sprint_yard := false
var settle_before_file := false
var stage_delay := 0.0
var yard_flank := false
var _route_failed := false
var background_play := false
var background_resumes := 0
var camera_off := false
var watch_patrol := false
var walk_exfil := false
var sprint_exfil := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--camera-off": camera_off=true
		if arg == "--watch-patrol": watch_patrol=true
		if arg == "--walk-exfil": walk_exfil=true
		if arg == "--sprint-exfil": sprint_exfil=true
		if arg == "--background": background_play=true
		if arg == "--live-guards": live_guards=true
		if arg == "--crouch": crouched=true
		if arg == "--prepare": prepare_backdoor=true
		if arg == "--radio": use_radio=true
		if arg == "--wait-radio": wait_for_radio=true
		if arg == "--sprint-yard": sprint_yard=true
		if arg == "--yard-flank": yard_flank=true
		if arg == "--settle-before-file": settle_before_file=true
		if arg.begins_with("--stage-delay="): stage_delay=float(arg.trim_prefix("--stage-delay="))
		if arg.begins_with("--route="): selected_route=arg.trim_prefix("--route=")
		if arg.begins_with("--entry="): entry_route=arg.trim_prefix("--entry=")
		if arg.begins_with("--out="): out=arg.trim_prefix("--out=")
	if out!="": DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var routes: Array=["courtyard","maintenance"] if selected_route=="" else [selected_route]
	for route in routes:
		_route_failed=false
		change_scene_to_file(SCENE if live_guards else "res://maps/intelligence/scenes/intelligence_k17_test.tscn")
		await _frames(45)
		if DisplayServer.get_name()!="headless": root.size=Vector2i(1280,720)
		level=current_scene
		player=level.get_node("Player")
		mission=level.get_node("Gameplay/Mission")
		flow=GameFlow.find(level)
		if OS.get_cmdline_user_args().has("--trace-guard"):
			var traced:=level.get_node("Guards/Guard3") as Guard
			traced.ai_state_changed.connect(func(from,to,why): print("[K17 Guard3] ",from," -> ",to," ",why," guard=",traced.position," player=",player.position))
		StealthDirector.find(level).player_caught.connect(func(by): print("[K17 caught] ",by.name," player=",player.global_position))
		if flow.state==GameStateMachine.State.PAUSED: flow.resume()
		if crouched: Input.action_press("crouch")
		await _shot(route+"_01_spawn")
		await _approach()
		if settle_before_file and not _route_failed:
			var quiet:=0
			for i in 3600:
				quiet=quiet+1 if StealthDirector.find(level).status in [StealthDirector.Status.NONE,StealthDirector.Status.HIDDEN] else 0
				if quiet>=180 or flow.state!=GameStateMachine.State.PLAYING: break
				await physics_frame
		if stage_delay>0: await _frames(ceili(stage_delay*60))
		await _use("Gameplay/DutyTable")
		await _route([Vector3(7,0,-20),Vector3(7,0,-23),Vector3(5.35,0,-22)])
		await _keypad()
		await _route([Vector3(4,0,-22.4)])
		await _route([Vector3(4,-4,-35),Vector3(4,-4,-48.5),Vector3(0,-4,-48.5)])
		await _use("Gameplay/IntelligenceFile")
		await _shot(route+"_02_file")
		if not mission.has_file: failures.append("Document not acquired: "+route)
		await _escape(route)
		await _frames(10)
		var director:=StealthDirector.find(level)
		if flow.state!=GameStateMachine.State.WIN: failures.append("Extraction failed: "+route)
		print("[K17 walking V4] route=",route," remaining=",snappedf(mission.time_left,.1)," state=",flow.state," catches=",director.catches," sensors=",mission.sensor_trips," reinforcements=",level.get_node("Gameplay/Reinforcements").spawned_count)
		await _frames(50)
		await _shot(route+"_03_victory")
		Input.action_release("crouch")
		Input.action_release("sprint")
		current_scene=null
		level.queue_free()
		await _frames(40)
	await Cleanup.settle_async_audio(self)
	for failure in failures: printerr(failure)
	print("K17 WALKING PASSED (%d waypoints, %d routes; NPC active=%s)"%[waypoints,routes.size(),str(live_guards)] if failures.is_empty() else "K17 WALKING FAILED")
	quit(0 if failures.is_empty() else 1)


func _approach() -> void:
	if entry_route=="maintenance":
		await _route([Vector3(-36,0,53),Vector3(36,0,53),Vector3(36,0,42),Vector3(26,0,42),Vector3(26,0,21),Vector3(-26,0,21),Vector3(-26,0,7),Vector3(-36,0,7),Vector3(-36,0,5.6)])
	else:
		await _route([Vector3(-36,0,42),Vector3(-36,0,22),Vector3(-36,0,16),Vector3(-36,0,5.6)])
	await _use("Gameplay/AccessPass")
	if camera_off:
		await _route([Vector3(-36,0,8.2),Vector3(-26,0,8.2),Vector3(-26,0,16)])
		await _nav_walk(Vector3(16,0,18))
		await _utilities()
		await _route([Vector3(16,0,7),Vector3(0,0,7),Vector3(0,0,10.7),Vector3(6.2,0,10.2)])
	else:
		# Read from the west edge of the desk, outside the camera's scan cone.
		await _route([Vector3(-36,0,8.2),Vector3(-26,0,8.2),Vector3(-26,0,7),Vector3(-12,0,7),Vector3(0,0,7),Vector3(0,0,10.7),Vector3(2.3,0,10.7),Vector3(2.3,0,13),Vector3(4.2,0,12.3)])
	await _use("Gameplay/VaultCode")
	if camera_off: await _route([Vector3(0,0,10.7),Vector3(-2.5,0,10.7),Vector3(-2.5,0,13),Vector3(0,0,13)])
	else: await _route([Vector3(4.2,0,13),Vector3(2.3,0,13),Vector3(2.3,0,10.7),Vector3(-2.5,0,10.7),Vector3(-2.5,0,13),Vector3(0,0,13)])
	if live_guards and not _route_failed:
		var quiet:=0
		for i in 3600:
			quiet=quiet+1 if StealthDirector.find(level).status in [StealthDirector.Status.NONE,StealthDirector.Status.HIDDEN] else 0
			if quiet>=180 or flow.state!=GameStateMachine.State.PLAYING: break
			await physics_frame
	if use_radio:
		await _route([Vector3(-2.5,0,13),Vector3(-2.5,0,10.7),Vector3(2.3,0,10.7),Vector3(2.3,0,11.5)])
		await _use("Gameplay/Security/Radio")
		await _route([Vector3(2.3,0,10.7),Vector3(0,0,10.7),Vector3(-2.5,0,10.7),Vector3(-2.5,0,13),Vector3(0,0,13)])
		if wait_for_radio and not watch_patrol: await _frames(480)
		if watch_patrol and live_guards:
			# Observe the guard reaching the radio bay instead of assuming the
			# same eight-second window after every furniture/navmesh change.
			var comms_guard:=level.get_node("Guards/Guard3") as Guard
			var archive_guard:=level.get_node("Guards/Guard5") as Guard
			var waited:=0
			while waited<3600 and not (comms_guard.position.z>9.5 and comms_guard.position.x>6 and archive_guard.position.x< -9 and (archive_guard.velocity.x<-.2 or archive_guard.position.x< -13)):
				await _frames(1)
				waited+=1
			print("[K17 watch] communications guard clearance waited=",waited/60.0," position=",comms_guard.position)
	await _route([Vector3(-2.5,0,13),Vector3(-2.5,0,10.7),Vector3(0,0,10.7),Vector3(0,0,7)])
	if prepare_backdoor and not camera_off:
		await _route([Vector3(16,0,7),Vector3(16,0,18),Vector3(26,0,21),Vector3(36,0,21),Vector3(36,0,18),Vector3(32.2,0,15),Vector3(32.2,0,9),Vector3(42,0,8),Vector3(42,0,5),Vector3(41.2,0,5)])
		if prepare_backdoor: await _use("Gameplay/Security/PreparedLatch")
		await _route([Vector3(42,0,5),Vector3(42,0,8),Vector3(32.2,0,9),Vector3(32.2,0,15),Vector3(36,0,18),Vector3(36,0,21),Vector3(26,0,21),Vector3(16,0,18),Vector3(16,0,7),Vector3(4,0,7)])
	else: await _route([Vector3(4,0,7)])
	await _route([Vector3(4,0,1.6)])
	await _use("Gameplay/ArchiveDoor")
	await _route([Vector3(4,0,-1),Vector3(10.8,0,-1),Vector3(10.8,0,-20),Vector3(8,0,-20)])


func _utilities() -> void:
	var north:=OS.get_cmdline_user_args().has("--utilities-north")
	if north:
		await _route([Vector3(26,0,21),Vector3(26,0,-5),Vector3(36,0,-5)])
		if live_guards:
			var utility_guard:=level.get_node("Guards/Guard4") as Guard
			var waited:=0
			while waited<3600 and not (utility_guard.position.z>12 and (utility_guard.velocity.x<-.2 or utility_guard.position.x<36)):
				await _frames(1)
				waited+=1
			print("[K17 watch] utility north clearance waited=",waited/60.0)
		await _route([Vector3(36,0,1),Vector3(42,0,1),Vector3(42,0,4),Vector3(41.2,0,5)])
	else:
		await _route([Vector3(26,0,21),Vector3(36,0,21),Vector3(36,0,18),Vector3(32.2,0,15),Vector3(32.2,0,9),Vector3(42,0,8),Vector3(42,0,5),Vector3(41.2,0,5)])
	if prepare_backdoor: await _use("Gameplay/Security/PreparedLatch")
	await _route([Vector3(41.2,0,3.2)])
	await _use("Gameplay/CameraSwitch")
	await _route([Vector3(41.2,0,1.7)])
	await _use("Gameplay/PowerMemo")
	if north: await _route([Vector3(41.2,0,5),Vector3(42,0,4),Vector3(42,0,1),Vector3(36,0,1),Vector3(36,0,-5),Vector3(26,0,-5),Vector3(26,0,21),Vector3(16,0,18)])
	else: await _route([Vector3(41.2,0,5),Vector3(42,0,5),Vector3(42,0,8),Vector3(32.2,0,9),Vector3(32.2,0,15),Vector3(36,0,18),Vector3(36,0,21),Vector3(26,0,21),Vector3(16,0,18)])


func _escape(route: String) -> void:
	if route=="maintenance":
		await _route([Vector3(8,-4,-48.5),Vector3(8.2,-4,-38)])
		await _use("Gameplay/MaintenanceShortcut")
		await _route([Vector3(12,-4,-38),Vector3(30,-4,-38),Vector3(30,0,-23),Vector3(42,0,-23),Vector3(42,0,-9),Vector3(36,0,-4),Vector3(36,0,1),Vector3(42,0,1),Vector3(42,0,4),Vector3(42,0,8),Vector3(32.2,0,9),Vector3(32.2,0,15),Vector3(36,0,18),Vector3(26,0,21),Vector3(26,0,28),Vector3(36,0,42),Vector3(36,0,44.35)])
		await _use("Gameplay/Security/MaintenanceGate")
		await _route([Vector3(36,0,51)])
	else:
		await _route([Vector3(4,-4,-48.5),Vector3(4,-4,-35)])
		if watch_patrol and live_guards:
			var archive_guard:=level.get_node("Guards/Guard5") as Guard
			var waited:=0
			while waited<900 and not (archive_guard.position.x< -9 and (archive_guard.velocity.x< -.2 or archive_guard.position.x< -13)):
				await _frames(1)
				waited+=1
			print("[K17 watch] archive patrol clearance waited=",waited/60.0)
		await _route([Vector3(4,0,-23),Vector3(7,0,-23),Vector3(7,0,-20),Vector3(10.8,0,-20),Vector3(10.8,0,-1),Vector3(4,0,-1),Vector3(4,0,7)])
		if use_radio and OS.get_cmdline_user_args().has("--repeat-radio"):
			await _route([Vector3(0,0,7),Vector3(0,0,10.7),Vector3(2.3,0,10.7),Vector3(2.3,0,11.5)])
			await _use("Gameplay/Security/Radio")
			if wait_for_radio: await _frames(480)
			await _route([Vector3(0,0,10.7),Vector3(0,0,7)])
		if yard_flank:
			await _route([Vector3(16,0,7),Vector3(16,0,18),Vector3(16,0,44)])
			await _route([Vector3(-24,0,44),Vector3(-36,0,44),Vector3(-36,0,51)])
		else:
			await _route([Vector3(-12,0,7),Vector3(-12,0,18),Vector3(-16,0,22),Vector3(-20,0,26),Vector3(-24,0,26),Vector3(-24,0,42),Vector3(-36,0,42),Vector3(-36,0,51)])


func _route(points: Array) -> void:
	if _route_failed: return
	for target in points:
		if not await _walk(target):
			_route_failed = true
			return


func _nav_walk(target: Vector3) -> void:
	if _route_failed: return
	var path:=NavigationServer3D.map_get_path(level.get_world_3d().navigation_map,player.global_position,target,true)
	for point in path:
		if not await _walk(point):
			_route_failed=true
			return


func _walk(target: Vector3) -> bool:
	waypoints += 1
	player.get_node("Head").rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	Input.action_press("move_forward")
	var arrived := false
	var frame_budget:=maxi(1800,ceili(player.global_position.distance_to(target)/player.crouch_speed*Engine.physics_ticks_per_second)+600)
	for i in frame_budget:
		_resume_background()
		if flow.state != GameStateMachine.State.PLAYING:
			break
		var delta := Vector2(target.x - player.global_position.x, target.z - player.global_position.z)
		if delta.length() < 0.38 and absf(player.global_position.y-target.y)<.65:
			arrived = true
			break
		player.rotation.y = atan2(-delta.x, -delta.y)
		if walk_exfil and mission.has_file: Input.action_release("crouch")
		if sprint_exfil and mission.has_file:
			Input.action_release("crouch")
			Input.action_press("sprint")
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
		for c in player.get_slide_collision_count():
			var collision:=player.get_slide_collision(c)
			print("[K17 blocked collider] ",collision.get_collider().get_path()," normal=",collision.get_normal())
		failures.append("Blocked walking toward %s (actual %s, state %s)" % [target, player.global_position, flow.state])
		return false
	return true


func _should_wait_for_sensor(target: Vector3) -> bool:
	var p := player.global_position
	for sensor in get_nodes_in_group("k17_sensors"):
		var s: Vector3 = sensor.global_position
		if absf(p.y-(s.y-1.2))>1.0: continue
		if absf(p.x-s.x) > 2.0 or absf(p.z-s.z) > 1.4 or absf(p.z-s.z) < .55: continue
		if (target.z-s.z)*(p.z-s.z) >= 0.0: continue
		if sensor.get_phase() != 0 or sensor.seconds_until_change() < 1.6: return true
	return false


func _use(path: String,retry_after_focus_pause:=true) -> void:
	if _route_failed: return
	var target := level.get_node(path) as Interactable
	if path.ends_with("VaultCode") or path.ends_with("IntelligenceFile") or "VaultKeypad" in path:
		Input.action_release("crouch")
		await _frames(20)
	player.camera.look_at(target.global_position)
	await _frames(3)
	var interactor := player.get_node("Interactor") as PlayerInteractor
	if interactor.focused != target:
		failures.append("Cannot aim at " + path + " from " + str(player.global_position))
		_route_failed=true
		return
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	root.push_input(press)
	var pauses_before:=background_resumes
	var duration := target.get_hold_duration(player)
	if duration > 0.0: await _frames(ceili(duration*Engine.physics_ticks_per_second)+3)
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	root.push_input(release)
	await _frames(3)
	if duration>0 and retry_after_focus_pause and background_resumes!=pauses_before:
		await _use(path,false)
	var hud:=level.get_node("ObjectiveHud") as ObjectiveHud
	if hud.is_journal_open(): hud.close_journal()
	if crouched: Input.action_press("crouch")


func _keypad() -> void:
	if _route_failed: return
	Input.action_release("crouch")
	await _frames(20)
	var code: String=preload("res://maps/intelligence/resources/layout/k17_v4.gd").VAULT_CODE
	for i in code.length():
		for press in int(code[i]): await _use("Gameplay/VaultKeypad/Dial%d"%(i+1))
	print("[K17 keypad] entry=",level.get_node("Gameplay/VaultKeypad").get_entry()," powered=",level.get_node("Gameplay/VaultKeypad").has_power()," progress=",ObjectiveManager.find(level).get_progress())
	await _use("Gameplay/VaultKeypad/Enter")
	if not level.get_node("Gameplay/VaultKeypad").is_solved:
		failures.append("Keypad did not open after real input")
		_route_failed=true


func _shot(name: String) -> void:
	if out == "" or DisplayServer.get_name() == "headless":
		return
	await _frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out.path_join(name + ".png")))


func _frames(count: int) -> void:
	for i in count:
		_resume_background()
		await physics_frame


func _resume_background() -> void:
	if background_play and is_instance_valid(flow) and flow.state==GameStateMachine.State.PAUSED:
		flow.resume()
		background_resumes+=1
		print("[K17 batch] resumed after focus pause; count=",background_resumes)
