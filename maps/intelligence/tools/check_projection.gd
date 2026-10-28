extends SceneTree
## Isolated real-scene geometry/input fixtures, separate from walking E2E.
const C := preload("res://maps/intelligence/resources/layout/k17_projection.gd")
const M := preload("res://maps/intelligence/scripts/mission_controller.gd")
var level: Node3D
var player: FirstPersonPlayer
var rig: K17ProjectionRig
var checks := 0
var failures: Array[String]=[]

func _init() -> void: _run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17.tscn")
	await _frames(40)
	level=current_scene
	player=level.get_node("Player")
	rig=level.get_node("Gameplay/ProjectionRig")
	var flow := GameFlow.find(level)
	if flow.state==GameStateMachine.State.PAUSED: flow.resume()
	for guard in level.get_node("Guards").get_children():
		guard.set_physics_process(false)
		guard.vision.set_physics_process(false)
	player.set_physics_process(false)
	var objectives := ObjectiveManager.find(level)
	for id in [M.ENTER,M.PASS,M.CODE,M.ARCHIVE,M.VAULT]: objectives.complete(id)
	player.global_position=C.HOME+Vector3(1.05,.05,0)
	player.camera.look_at(rig.get_node("HandleControl").global_position)
	await _frames(4)
	var interactor := player.get_node("Interactor") as PlayerInteractor
	_expect(interactor.find_target()==rig.get_node("HandleControl"),"Handle is reachable with the real camera ray")
	_expect(rig.deploy(),"Raised screen has physical deployment clearance")
	_expect(rig.deployed and rig.powered,"Deployment activates calibrated image")
	_expect(rig.begin_grip(player),"Player can grip from the actual handle position")
	var before := rig.position
	var movement := rig.drive(Vector2(0,-1),.05)
	_expect(movement.length()>.1 and rig.position.distance_to(before)>.01,"Input drives the solid cart")
	player.position+=movement*.05
	player.camera.look_at(player.camera.global_position+Vector3(0,0,-3))
	_press(true)
	await _frames(2)
	_press(false)
	await _frames(2)
	_expect(rig.holder==null and player.get("projection_rig")==null,"E releases while looking away from the handle")
	player.position=rig.to_global(C.GRIP_OFFSET)+Vector3(0,.05,0)
	_expect(rig.begin_grip(player),"Regrip remains available")
	flow.pause()
	_expect(rig.holder==null,"Pause atomically releases cart and player")
	flow.resume()
	rig.restore_checkpoint_state({})
	_expect(not rig.deployed and not rig.powered and rig.position.distance_to(C.HOME)<.001,"Restore resets equipment to safe folded home pose")
	_expect(rig.get_checkpoint_state()=={"equipment_issued":true},"Checkpoint state has no continuously changing pose or clock")
	var observation_from := C.OBSERVATION+Vector3(0,1.6,0)
	var observation_to := Vector3(-5,-2.4,-35.7)
	var sight := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(observation_from,observation_to,1))
	var solid := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(observation_from,observation_to,17))
	_expect(sight.is_empty(),"Observation pane gives a real view of the north return patrol")
	_expect(not solid.is_empty() and solid.collider.name=="ObservationGlass","The same transparent pane physically blocks actors")
	# Vision fixtures use deliberately positioned actors; these are not E2E.
	rig.global_position=Vector3(-5,-4,-47)
	rig._set_deployed(true)
	rig.powered=true
	var post := level.get_node("Guards/Guard6") as Guard
	post.global_position=C.POST
	post.rotation.y=C.POST_YAW
	player.global_position=rig.to_global(C.GRIP_OFFSET)
	await _frames(3)
	_expect(rig.hardware_visible_to(post),"Main observer has a true sightline to the screen")
	_expect(rig.camouflages_observer(post),"Active screen covers hardware from calibrated main observer")
	post.vision._physics_process(.2)
	_expect(not post.vision.can_see_target,"Solid panel physically covers player in main sightline")
	player.global_position=rig.to_global(Vector3(0,0,-1))
	await _frames(2)
	post.vision._physics_process(.2)
	_expect(post.vision.can_see_target,"Active projection cannot hide a player who steps in front of it")
	player.global_position=rig.to_global(C.GRIP_OFFSET)
	await _frames(2)
	post.vision.reset()
	post.vision._physics_process(.1)
	rig.powered=false
	post._observe_rig(.8)
	_expect(post.rig_evidence and not post.vision.can_see_target,"Unpowered screen is visual evidence, not a fake player sighting")
	var decision: Dictionary=post.machine.choose_priority_transition(post.build_perception())
	_expect(decision.get("to",-1)==GuardStateMachine.INVESTIGATE and decision.get("reason","")=="thiết bị đáng ngờ","Visual evidence feeds the real investigate transition")
	_expect(post.rig_evidence_position.distance_to(rig.global_position)>1,"Inspection aims outside the solid cart")
	rig.powered=true
	var side := level.get_node("Guards/Guard4") as Guard
	side.global_position=Vector3(-5,-4,-43.5)
	side.rotation.y=atan2(-(rig.global_position-side.global_position).x,-(rig.global_position-side.global_position).z)
	await _frames(2)
	_expect(rig.hardware_visible_to(side) and not rig.camouflages_observer(side),"Side observer sees suspicious hardware despite active projection")
	for bay in C.BAYS:
		rig.global_position=bay
		player.global_position=rig.to_global(C.GRIP_OFFSET)
		side.rotation.y=atan2(-(rig.global_position-side.global_position).x,-(rig.global_position-side.global_position).z)
		await _frames(3)
		_expect(not rig.hardware_visible_to(side),"L-shaped bay physically hides all hardware: "+str(bay))
		side.vision._physics_process(.1)
		_expect(not side.vision.can_see_target,"L-shaped bay physically hides actual player: "+str(bay))
		for p in [bay,rig.to_global(C.GRIP_OFFSET)]:
			var nav := NavigationServer3D.map_get_closest_point(level.get_world_3d().navigation_map,p)
			_expect(Vector2(nav.x-p.x,nav.z-p.z).length()<.6,"Bay parking point has walkable navigation: "+str(p))
	# Test the transition, not only a parked pose: a visible cart corner must
	# regain valid projection before it emerges from the physical cover.
	for entry in C.BAY_ENTRIES:
		for sample in 20:
			rig.position=Vector3(entry.x,-4,lerpf(entry.z,C.HALL_Z,float(sample)/19.0))
			player.position=rig.to_global(C.GRIP_OFFSET)
			await _frames(1)
			_expect(not rig.hardware_visible_to(post) or rig.camouflages_observer(post),"Bay exit preserves main-observer cover at "+str(rig.position))
			post.vision._physics_process(.05)
			_expect(not post.vision.can_see_target,"Bay exit physically covers the actual body at "+str(player.position))
	rig.restore_checkpoint_state({})
	player.global_position=C.PREP
	await _frames(4)
	_expect(CheckpointManager.find(level).active==level.get_node("Gameplay/ProjectionCheckpoint"),"New B1 checkpoint activates only after vault access")
	objectives.complete(M.FILE)
	await _frames(2)
	_expect(not rig.get_node("HandleControl").can_interact(player),"File pickup cannot start cart handling during extraction")
	_expect(CheckpointManager.find(level).saved_progress.get(M.FILE,-1)!=ObjectiveManager.State.COMPLETED,"Post-file overlap never overwrites pre-file checkpoint")
	flow.fail("projection fixture")
	_expect(flow.retry_checkpoint(),"Real failure can retry the B1 checkpoint")
	await _frames(8)
	_expect(not rig.deployed and rig.position.distance_to(C.HOME)<.001 and player.get("projection_rig")==null,"Retry restores equipment and releases grip")
	_expect(not (MapHudProvider.find_for(level) as K17MissionController).has_file,"Retry restores pre-document mission")
	current_scene=null
	level.queue_free()
	await _frames(20)
	change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17_test.tscn")
	await _frames(30)
	level=current_scene
	rig=level.get_node("Gameplay/ProjectionRig")
	_expect(get_nodes_in_group("guards").is_empty(),"No-guard variant contains no hidden calibration NPC")
	_expect(rig.observer_eye().distance_to(C.POST_EYE)<.001,"No-guard projection has an explicit reference eye")
	_expect(level.has_node("Gameplay/ProjectionCheckpoint") and level.has_node("Gameplay/FileEscapeDoor"),"No-guard variant inherits all V6 gameplay")
	current_scene=null
	level.queue_free()
	await _frames(20)
	await preload("res://tests/test_utils.gd").settle_async_audio(self)
	for failure in failures: printerr(failure)
	print("K17 V6 PROJECTION: %d checks; %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message)
	print("[V6 ","OK" if ok else "FAIL","] ",message)

func _frames(count: int) -> void:
	for i in count: await physics_frame

func _press(down: bool) -> void:
	var event := InputEventAction.new()
	event.action="interact"
	event.pressed=down
	root.push_input(event)
