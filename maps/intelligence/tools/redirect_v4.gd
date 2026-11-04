extends "res://maps/intelligence/tools/playthrough_k17.gd"
## Partial-route QA from a defined decision point, not a full mission E2E.
## The fixture sets the elapsed clock and the previously prepared backdoor;
## player input, AI, cameras, gates and the remaining clock then run normally.
func _run() -> void:
	for elapsed in [70.0,90.0]:
		change_scene_to_file(SCENE)
		await _frames(45)
		level=current_scene
		player=level.get_node("Player")
		mission=level.get_node("Gameplay/Mission")
		flow=GameFlow.find(level)
		StealthDirector.find(level).player_caught.connect(func(by): print("[K17 redirect caught] ",by.name," at=",player.position))
		player.set_physics_process(false)
		player.position=Vector3(4,.05,7)
		player.rotation=Vector3.ZERO
		player.get_node("Head").rotation=Vector3.ZERO
		mission.set_physics_process(false)
		PlayerInventory.find(level).add(ItemCatalog.STAFF_CARD)
		for id in [K17MissionController.ENTER,K17MissionController.PASS,K17MissionController.CODE,K17MissionController.ARCHIVE,K17MissionController.VAULT,K17MissionController.FILE]:
			ObjectiveManager.find(level).complete(id)
		mission.backdoor_prepared=true
		ObjectiveManager.find(level).complete(K17MissionController.PREPARED)
		var team:=level.get_node("Gameplay/Reinforcements")
		mission.time_left=110
		team._physics_process(0)
		mission.time_left=75
		team._physics_process(0)
		mission.time_left=mission.escape_duration-elapsed
		mission._physics_process(0)
		level.get_node("Gameplay/PowerNetwork")._physics_process(0)
		await _frames(3)
		var main_gate:=mission.get_security_node("CourtyardGate") as K17LockdownGate
		var correct_gate: bool=mission.lockdown_warned and (main_gate.is_closed if elapsed>=90 else not main_gate.is_closed)
		player.set_physics_process(true)
		mission.set_physics_process(true)
		Input.action_press("sprint")
		_route_failed=false
		await _route([Vector3(16,0,7),Vector3(16,0,18),Vector3(26,0,21),Vector3(26,0,28),Vector3(36,0,42),Vector3(36,0,44.35)])
		await _use("Gameplay/Security/MaintenanceGate")
		await _route([Vector3(36,0,51)])
		Input.action_release("sprint")
		await _frames(5)
		var director:=StealthDirector.find(level)
		var count: int=level.get_node("Guards").get_child_count()
		var cameras_on: bool=level.get_node("Gameplay/PowerNetwork").is_powered(&"surveillance")
		print("K17 REDIRECT T+",elapsed," from=(4,0,7) main_gate_correct=",correct_gate," cameras_on=",cameras_on," actors=",count," prepared=",mission.backdoor_prepared," remaining=",snappedf(mission.time_left,.1)," catches=",director.catches," state=",flow.state)
		if not correct_gate or not cameras_on or count!=10 or not mission.backdoor_prepared or _route_failed or flow.state!=GameStateMachine.State.WIN or director.catches!=0:
			failures.append("Late maintenance redirect failed at T+"+str(elapsed))
		current_scene=null
		paused=false
		level.queue_free()
		await _frames(40)
	await Cleanup.settle_async_audio(self)
	for failure in failures: printerr(failure)
	print("K17 REDIRECT PASSED" if failures.is_empty() else "K17 REDIRECT FAILED")
	quit(0 if failures.is_empty() else 1)
