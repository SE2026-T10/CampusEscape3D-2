extends SceneTree
## Intentional fixture positioning; walking E2E is in playthrough_k17.gd.
const C:=preload("res://maps/intelligence/resources/layout/k17_projection.gd")
const M:=preload("res://maps/intelligence/scripts/mission_controller.gd")
var checks:=0
var failures: Array[String]=[]
var level: Node3D
var player: FirstPersonPlayer

func _init() -> void: _run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17.tscn")
	await frames(40)
	level=current_scene
	player=level.get_node("Player")
	player.set_physics_process(false)
	for guard in level.get_node("Guards").get_children():
		guard.set_physics_process(false)
		guard.vision.set_physics_process(false)
	var flow:=GameFlow.find(level)
	if flow.state==GameStateMachine.State.PAUSED: flow.resume()
	var objectives:=ObjectiveManager.find(level)
	for id in [M.ENTER,M.PASS,M.CODE,M.ARCHIVE,M.VAULT]: objectives.complete(id)
	var system:=level.get_node("Gameplay/B1Surveillance")
	system.set_physics_process(false)
	var mission:=level.get_node("Gameplay/Mission")
	var post:=level.get_node("Guards/Guard6")
	var rig:=level.get_node("Gameplay/ProjectionRig")
	_expect(not level.has_node("Gameplay/FileEscapeDoor") and not level.has_node("Gameplay/ProjectionAisleExit") and not level.has_node("Gameplay/MaintenanceShortcut"),"All file-gated shortcut/egress controls were removed")
	_expect(C.POST.distance_to(C.DOCK)>=9.9,"Final cart stop beyond doorway remains ten metres from post")
	_expect(C.DOCK.x< C.ROOM_DOOR.x-1.5,"Cart stops beyond the complete doorway")
	# Every navigable route must intersect both full-width sensor cross-sections.
	var nav:=level.get_world_3d().navigation_map
	for start in [Vector3(4,-4,-35.5),Vector3(30,-4,-38),Vector3(-3,-4,-36.3),Vector3(-10.2,-4,-36.3)]:
		var path:=NavigationServer3D.map_get_path(nav,start,C.PREP,true)
		for sensor in get_nodes_in_group("k17_sensors"):
			var crossing:=false
			for i in range(1,path.size()):
				var a: Vector3=path[i-1]
				var b: Vector3=path[i]
				if (a.z-sensor.position.z)*(b.z-sensor.position.z)<=0 and absf(a.z-b.z)>.001:
					var x:=lerpf(a.x,b.x,(sensor.position.z-a.z)/(b.z-a.z))
					if x>1.9 and x<6.1: crossing=true
			_expect(crossing,"Route from %s crosses %s"%[start,sensor.name])
	for sensor in get_nodes_in_group("k17_sensors"):
		sensor.set_physics_process(false)
		for x in [2.34,4.0,5.66]:
			player.position=Vector3(x,-4,sensor.position.z)
			await frames(2)
			var before: int=sensor.trips
			sensor.cooldown_left=0
			sensor.phase_clock=6.0-sensor.phase_offset
			sensor._physics_process(0)
			_expect(sensor.trips==before+1,"Red sensor detects actual actor at x=%s, %s"%[x,sensor.name])
	player.position=C.PREP
	# Test each final marked parking pose against both actual observation windows.
	rig._set_deployed(true)
	rig.powered=true
	var side:=level.get_node("Guards/Guard4") as Guard
	for bay in C.BAYS:
		rig.position=bay
		player.position=rig.to_global(C.GRIP_OFFSET)+Vector3(0,0,.31)
		for x in [-3.0,-10.2]:
			side.position=Vector3(x,-4,-43.2)
			side.rotation.y=atan2(-(player.position-side.position).x,-(player.position-side.position).z)
			await frames(2)
			_expect(not rig.hardware_visible_to(side),"Both windows are occluded at marked bay "+str(bay)+" / "+str(x))
			side.vision._physics_process(.1)
			_expect(not side.vision.can_see_target,"Wall hides actual body including grip offset at bay "+str(bay)+" / "+str(x))
	rig.restore_checkpoint_state({})
	player.position=C.PREP
	await frames(3)
	_expect(system.hack(),"Real preparation console can grant CCTV control")
	_expect(not system.hack(),"Hack completion is idempotent")
	post._clear_projection_memory()
	post.vision.reset()
	post.global_position=C.POST
	post.rotation.y=C.POST_YAW
	_expect(system.request_call(),"Valid post accepts pending request")
	_expect(not system.request_call(),"Only one call can be pending")
	_expect(post.check_left==0,"Sending is not instantly treated as looking away")
	var pending: float=system.pending
	flow.pause()
	system._physics_process(20)
	_expect(is_equal_approx(system.pending,pending),"Pause freezes pending call")
	flow.resume()
	system._physics_process(C.CALL_DELAY+.01)
	_expect(post.check_left>9 and system.calls.size()==1,"Acknowledged call begins terminal action and cooldown")
	_expect(not system.request_call(),"Cooldown cannot queue spam")
	post.machine.request_transition(GuardStateMachine.INVESTIGATE,"fixture",C.POST)
	post._physics_process(.1)
	_expect(post.check_left==0,"Investigation interrupts terminal attention")
	_expect(not post.begin_terminal_check(10),"An investigating post refuses terminal check")
	post.machine.request_transition(GuardStateMachine.PATROL,"fixture")
	post.global_position=C.POST
	post.vision.reset()
	post._hardware_exposed=false
	system.cooldown=0
	_expect(system.request_call(),"A recovered guard can be called again")
	system._physics_process(2)
	post.check_left=0
	system.cooldown=0
	_expect(not system.request_call() and system.lockout>0,"Third rapid accepted sequence triggers finite channel verification")
	system._physics_process(C.CALL_LOCKOUT+1)
	_expect(system.lockout==0,"Channel verification expires without locking mission")
	system.restore_checkpoint_state({})
	_expect(not system.hacked and system.pending==0 and system.calls.is_empty(),"Checkpoint clears rights/pending/history to safe baseline")
	var lock:=level.get_node("Gameplay/ArchiveLock") as Interactable
	player.position=Vector3(-14.4,-4,-47)
	player.camera.look_at(lock.global_position)
	await frames(4)
	_expect(player.get_node("Interactor").find_target()==lock,"Fixed reader is reachable by real interaction ray")
	var before_time: float=mission.time_left
	press(true)
	await frames(60)
	press(false)
	await frames(3)
	_expect(not lock.is_open,"Releasing before six seconds cancels archive unlock")
	press(true)
	await frames(365)
	press(false)
	await frames(55)
	_expect(lock.is_open and lock.opening==1,"Six-second E hold opens actual sliding door")
	_expect(not mission.has_file and is_equal_approx(before_time,mission.time_left),"Unlock does not start extraction clock")
	rig.global_position=C.DOCK
	rig._set_deployed(true)
	rig.powered=true
	player.global_position=rig.to_global(C.GRIP_OFFSET)
	await frames(3)
	_expect(not system.cctv_sees(player),"C1 cannot see through physical projection panel")
	player.global_position=rig.to_global(Vector3(0,0,-1))
	await frames(3)
	_expect(system.cctv_sees(player),"C1 sees actual actor who steps in front")
	_expect(StealthDirector.find(level).gather_flags(player,[]).seen,"Unhacked C1 contributes real visibility to the shared HUD")
	system.hacked=true
	_expect(not StealthDirector.find(level).gather_flags(player,[]).seen,"Spoofed enemy feed does not mark the exposed player as seen by C1")
	player.position=Vector3(-14,-4,-44)
	objectives.complete(M.FILE)
	system.hacked=true
	system.pending=1
	system._physics_process(.1)
	_expect(system.revoked and system.pending==0 and system.feed_mode==0,"Seal alarm revokes live feed and cancels pending calls")
	_expect(lock.is_open and not system.request_call(),"Alarm retains opened doorway but refuses forged requests")
	post.position=Vector3(C.DOCK.x-1.4,-4,-47)
	_expect(rig.clear_by_guard(post),"Nearby guard physically folds discovered obstacle after alarm")
	await frames(90)
	_expect(not rig.deployed and rig.collision_layer==1 and rig.position.z< -47.6,"Folded case is swept aside without losing physical collision")
	_expect(rig.get_node("HandleControl").can_interact(player),"Handle remains available after FILE instead of being mission-disabled")
	current_scene=null
	level.queue_free()
	await frames(30)
	change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17_test.tscn")
	await frames(35)
	level=current_scene
	system=level.get_node("Gameplay/B1Surveillance")
	_expect(get_nodes_in_group("guards").is_empty(),"No-guard variant adds no hidden calibration actors")
	_expect(system.hack() and not system.request_call(),"No-guard variant grants CCTV but honestly refuses nonexistent guard")
	current_scene=null
	level.queue_free()
	await frames(30)
	await preload("res://tests/test_utils.gd").settle_async_audio(self)
	for failure in failures: printerr(failure)
	print("K17 B1 REFINEMENT: %d checks; %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool,message: String) -> void:
	checks+=1
	print("[B1 ","OK" if ok else "FAIL","] ",message)
	if not ok: failures.append(message)

func frames(count: int) -> void:
	for i in count: await physics_frame

func press(down: bool) -> void:
	var event:=InputEventAction.new()
	event.action="interact"
	event.pressed=down
	root.push_input(event)
