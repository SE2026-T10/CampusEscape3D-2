extends "res://maps/intelligence/tools/playthrough_k17.gd"
## Partial-route QA from a defined decision point, not a full mission E2E.
## Stage the clock and preparation at the ground fork, then use real input,
## guards, cameras and gates. Getting caught during the locked hold is expected.
func _run() -> void:
	# The shared driver brakes before each waypoint. Reapply sprint on the next leg.
	sprint_exfil=true
	for elapsed in [70.0,90.0]:
		for prepared in [true,false]:
			await _check_redirect(elapsed,prepared)
	await Cleanup.settle_async_audio(self)
	for failure in failures: printerr(failure)
	print("K17 REDIRECT PASSED" if failures.is_empty() else "K17 REDIRECT FAILED")
	quit(0 if failures.is_empty() else 1)


func _check_redirect(elapsed: float,prepared: bool) -> void:
	change_scene_to_file(SCENE)
	await _frames(45)
	level=current_scene
	player=level.get_node("Player")
	mission=level.get_node("Gameplay/Mission")
	flow=GameFlow.find(level)
	player.set_physics_process(false)
	player.position=Vector3(4,.05,7)
	player.rotation=Vector3.ZERO
	player.get_node("Head").rotation=Vector3.ZERO
	mission.set_physics_process(false)
	PlayerInventory.find(level).add(ItemCatalog.STAFF_CARD)
	var objectives := ObjectiveManager.find(level)
	for id in [K17MissionController.ENTER,K17MissionController.PASS,K17MissionController.CODE,K17MissionController.ARCHIVE,K17MissionController.VAULT,K17MissionController.FILE]:
		objectives.complete(id)
	mission.backdoor_prepared=prepared
	if prepared: objectives.complete(K17MissionController.PREPARED)
	var team := level.get_node("Gameplay/Reinforcements")
	mission.time_left=110
	team._physics_process(0)
	mission.time_left=75
	team._physics_process(0)
	mission.time_left=mission.escape_duration-elapsed
	mission._physics_process(0)
	level.get_node("Gameplay/PowerNetwork")._physics_process(0)
	await _frames(3)

	var service := mission.get_security_node("MaintenanceGate") as K17LockdownGate
	var board := level.get_node("Gameplay/V7Presentation/GroundFork/Service") as Label3D
	var service_text := "Đã chuẩn bị · nhấn E" if prepared else "Khóa cơ · giữ E 8 giây"
	var sign_status := board.text.get_slice("\n",1)
	var sign_matches := sign_status==service_text
	var yard_state := K17MissionController.RouteState.LOCKED if elapsed>=90 else K17MissionController.RouteState.WARNING
	var hold := service.get_hold_duration(player)
	var cameras_on: bool=level.get_node("Gameplay/PowerNetwork").is_powered(&"surveillance")
	var count := level.get_node("Guards").get_child_count()
	var scenario := "T+%d prepared=%s" % [elapsed,str(prepared)]
	if mission.route_state(0)!=yard_state or not service.is_closed or hold!=(0.0 if prepared else 8.0) or not sign_matches or not cameras_on or count!=10:
		failures.append("Unexpected fork, gate or security state at "+scenario)

	var interactor := player.get_node("Interactor") as PlayerInteractor
	var director := StealthDirector.find(level)
	var caught := {"guard":"","hold_elapsed":0.0,"remaining":0.0}
	director.player_caught.connect(func(by: Guard):
		caught.guard=by.name
		caught.hold_elapsed=interactor.hold_elapsed if interactor.hold_target==service else 0.0
		caught.remaining=mission.time_left)
	player.set_physics_process(true)
	mission.set_physics_process(true)
	_route_failed=false
	await _route([Vector3(16,0,7),Vector3(16,0,18),Vector3(26,0,21),Vector3(26,0,28),Vector3(36,0,42),Vector3(36,0,44.35)])
	await _use("Gameplay/Security/MaintenanceGate")
	if prepared: await _route([Vector3(36,0,51)])
	Input.action_release("sprint")
	await _frames(5)
	if prepared:
		if _route_failed or flow.state!=GameStateMachine.State.WIN or service.is_closed or director.catches!=0:
			failures.append("Expected to open B and escape at "+scenario)
	else:
		if _route_failed or flow.state==GameStateMachine.State.WIN or director.catches!=1 or caught.guard!=&"Guard3" or caught.hold_elapsed<=0 or caught.hold_elapsed>=hold:
			failures.append("Expected to be caught during the mechanical hold at "+scenario)
	var remaining := float(caught.remaining) if director.catches>0 else mission.time_left
	print("K17 REDIRECT ",scenario," sign=",sign_matches," text=",sign_status," hold=",hold," cameras_on=",cameras_on," actors=",count," caught_by=",caught.guard," hold_at_catch=",snappedf(caught.hold_elapsed,.01)," remaining=",snappedf(remaining,.1)," catches=",director.catches)
	current_scene=null
	paused=false
	level.queue_free()
	await _frames(40)
