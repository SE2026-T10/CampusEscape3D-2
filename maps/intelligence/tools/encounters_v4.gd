extends "res://maps/intelligence/tools/playthrough_k17.gd"
## Isolated pursuit scenarios on shipping geometry. Only the selected guard
## is active; full 6+4 perception is covered separately by mission E2E.
func _run() -> void:
	var cases: Array=[
		["yard_early_reaction",Vector3(-28,.05,44),Vector3(-41,.05,44),[Vector3(16,0,44)]],
		["west_flank_early_reaction",Vector3(-25,.05,-20),Vector3(-25,.05,-33),[Vector3(-25,0,21),Vector3(16,0,21)]],
		["radio_cover",Vector3(3,.05,10),Vector3(-3,.05,10),[Vector3(3,0,13),Vector3(1.2,0,13)],"RadioBay",Vector3(0,0,13),true],
		# Seen entry grants no concealment here: the physical divider must
		# break line of sight while the guard is still within detection range.
		["vault_wall_cover",Vector3(2.5,-3.95,-48.7),Vector3(-9.5,-3.95,-48.7),[Vector3(-1.3,-4,-48.7),Vector3(-1.7,-4,-46.9)],"Vault",Vector3(-1.7,-4,-46.0),false],
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
		var pursuit:={"lost":false}
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
		Input.action_press("sprint")
		_route_failed=false
		await _route(scenario[3])
		Input.action_release("sprint")
		var cover_ok:=true
		if scenario.size()>4:
			Input.action_press("crouch")
			await _route([scenario[5]])
			var spot:=level.get_node("Gameplay/HidingSpots/"+str(scenario[4])) as HidingSpot
			cover_ok=not guard.vision.can_see_target and spot.is_concealing()==scenario[6] and player.position.distance_to(guard.position)<guard.vision.detection_distance
			print("K17 COVER ",scenario[0]," concealed=",spot.is_concealing()," distance=",player.position.distance_to(guard.position)," guard_sees=",guard.vision.can_see_target)
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
