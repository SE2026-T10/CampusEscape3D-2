extends SceneTree

## Exercise the shipping NPC configuration; player stays at the safe entrance.
const SCENE := "res://maps/intelligence/scenes/intelligence_k17.tscn"
const Cleanup := preload("res://tests/test_utils.gd")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file(SCENE)
	for i in 45:
		await physics_frame
	var guards := current_scene.get_node("Guards").get_children()
	if OS.get_cmdline_user_args().has("--reinforced"):
		var player:=current_scene.get_node("Player") as FirstPersonPlayer
		player.set_physics_process(false)
		player.global_position=preload("res://maps/intelligence/resources/layout/k17_layout.gd").PREP
		player.camera.look_at(Vector3(8,1,-30))
		var mission:=current_scene.get_node("Gameplay/Mission") as K17MissionController
		mission.set_physics_process(false)
		for id in [K17MissionController.ENTER,K17MissionController.PASS,K17MissionController.CODE,K17MissionController.ARCHIVE,K17MissionController.FILE]: ObjectiveManager.find(current_scene).complete(id)
		var team:=current_scene.get_node("Gameplay/Reinforcements")
		mission.time_left=110
		team._physics_process(0)
		mission.time_left=75
		team._physics_process(0)
		player.global_position=preload("res://maps/intelligence/resources/layout/k17_layout.gd").SPAWN+Vector3(8,0,0)
		guards=current_scene.get_node("Guards").get_children()
		# This scenario isolates route geometry, including both B1 stairs.
		# Full perception remains active in the separate live walking E2E.
		for guard in guards:
			guard.vision.set_physics_process(false)
			guard.reset_to_start()
	var counters: Array[Dictionary] = []
	for guard in guards:
		var counter := {"name": guard.name, "reached": 0, "stuck": 0}
		guard.patrol_point_reached.connect(func(_index): counter.reached += 1)
		guard.got_stuck.connect(func(_index): counter.stuck += 1)
		counters.append(counter)
	for i in 5400:
		await physics_frame
	var ok := GameFlow.find(current_scene).state == GameStateMachine.State.PLAYING
	for counter in counters:
		print("  [K17 patrol] ", counter)
		ok = ok and counter.reached >= 4 and counter.stuck == 0
	print("K17 PATROL PASSED (90 simulated seconds, %d live NPCs)"%guards.size() if ok else "K17 PATROL FAILED")
	current_scene.queue_free()
	for i in 40:
		await process_frame
	await Cleanup.settle_async_audio(self)
	quit(0 if ok else 1)
