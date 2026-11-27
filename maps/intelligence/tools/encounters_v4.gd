extends "res://maps/intelligence/tools/playthrough_k17.gd"
## Isolated pursuit scenarios on shipping geometry. Only the selected guard
## is active; full 6+4 perception is covered separately by mission E2E.
func _run() -> void:
	var first_bay_entry: Vector3 = ProjectionConfig.BAY_ENTRIES[0]
	var first_bay: Vector3 = ProjectionConfig.BAYS[0]
	var cases: Array=[
		["yard_early_reaction",Vector3(-28,.05,44),Vector3(-41,.05,44),[Vector3(16,0,44)]],
		["west_flank_early_reaction",Vector3(-25,.05,-20),Vector3(-25,.05,-33),[Vector3(-25,0,21),Vector3(16,0,21)]],
		["radio_cover",Vector3(3,.05,10),Vector3(9,.05,10),[Vector3(0,0,10.7),Vector3(-2.5,0,10.7),Vector3(-2.5,0,13),Vector3(-1.3,0,13)],"RadioBay",Vector3(0,0,13),true],
		# Run from the current B1 corridor into the first L-shaped bay.
		# Its return wall must block sight without granting the HIDDEN state.
		["vault_wall_cover",Vector3(-6,-3.95,ProjectionConfig.HALL_Z),Vector3(-19,-3.95,ProjectionConfig.HALL_Z),
			[Vector3(first_bay_entry.x,-4,ProjectionConfig.HALL_Z),first_bay_entry,first_bay],
			"Vault",first_bay+Vector3(-1.7,0,-1),false],
	]
	for scenario in cases:
		change_scene_to_file(SCENE)
		await _frames(45)
		level=current_scene
		player=level.get_node("Player")
		mission=level.get_node("Gameplay/Mission")
		flow=GameFlow.find(level)
		for camera in get_nodes_in_group("security_cameras"): camera.set_physics_process(false)
		for other in level.get_node("Guards").get_children(): other.process_mode=Node.PROCESS_MODE_DISABLED
		var guard:=level.get_node("Guards/Guard1") as Guard
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--speed="): guard.chase_speed=float(arg.trim_prefix("--speed="))
		var pursuit:={"lost":false,"cut_by_wall":false}
		guard.ai_state_changed.connect(func(from,to,why):
			if from==GuardStateMachine.CHASE and to==GuardStateMachine.INVESTIGATE: pursuit.lost=true
			if from==GuardStateMachine.CHASE or to==GuardStateMachine.CHASE: print("K17 PURSUIT TRANSITION ",from," -> ",to," reason=",why," player=",player.position))
		guard.process_mode=Node.PROCESS_MODE_INHERIT
		guard.set_physics_process(false)
		guard.position=scenario[2]
		player.position=scenario[1]
		guard.rotation.y=atan2(-(player.position.x-guard.position.x),-(player.position.z-guard.position.z))
		var saw_chase:=false
		for i in 1200:
			await physics_frame
			if guard.vision.detection>=100: break
		guard.set_physics_process(true)
		await _frames(2)
		saw_chase=guard.machine.current==GuardStateMachine.CHASE
		var b1_case: bool = scenario[0]=="vault_wall_cover"
		var check_wall := func() -> void:
			if not pursuit.cut_by_wall and not guard.vision.can_see_target:
				pursuit.cut_by_wall = _wall_blocks_player(guard)
		if b1_case: physics_frame.connect(check_wall)
		Input.action_press("sprint")
		_route_failed=false
		await _route(scenario[3])
		Input.action_release("sprint")
		var cover_ok:=true
		if scenario.size()>4:
			Input.action_press("crouch")
			await _route([scenario[5]])
			var spot:=level.get_node("Gameplay/HidingSpots/"+str(scenario[4])) as HidingSpot
			var broke_sight: bool = pursuit.cut_by_wall if b1_case else not guard.vision.can_see_target
			cover_ok=broke_sight and spot.is_concealing()==scenario[6] and player.position.distance_to(guard.position)<guard.vision.detection_distance
			print("K17 COVER ",scenario[0]," concealed=",spot.is_concealing()," distance=",player.position.distance_to(guard.position)," broke_sight=",broke_sight)
		if b1_case: physics_frame.disconnect(check_wall)
		var lost:=false
		for i in 720:
			await physics_frame
			if flow.state!=GameStateMachine.State.PLAYING: break
			if pursuit.lost and guard.machine.current!=GuardStateMachine.CHASE:
				lost=true
				break
		var catches:=StealthDirector.find(level).catches
		print("K17 ENCOUNTER ",scenario[0]," actual_sight_to_chase=",saw_chase," lost=",lost," catches=",catches," player=",player.position," guard=",guard.position)
		if not saw_chase or not lost or catches!=0 or not cover_ok or _route_failed: failures.append("Pursuit encounter failed: "+str(scenario[0]))
		Input.action_release("crouch")
		current_scene=null
		paused=false
		level.queue_free()
		await _frames(40)
	await Cleanup.settle_async_audio(self)
	for failure in failures: printerr(failure)
	print("K17 ENCOUNTERS PASSED" if failures.is_empty() else "K17 ENCOUNTERS FAILED")
	quit(0 if failures.is_empty() else 1)

func _wall_blocks_player(guard: Guard) -> bool:
	var eye := guard.vision.global_position
	if eye.distance_to(player.global_position) >= guard.vision.detection_distance:
		return false
	var space := player.get_world_3d().direct_space_state
	for point in player.get_visibility_points():
		var query := PhysicsRayQueryParameters3D.create(eye,point,guard.vision.sight_mask,[guard.get_rid()])
		var hit := space.intersect_ray(query)
		if not hit.get("collider") is StaticBody3D:
			return false
	return true
