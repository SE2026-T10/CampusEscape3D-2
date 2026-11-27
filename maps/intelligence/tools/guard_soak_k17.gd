extends SceneTree

## Exercise the shipping NPC configuration; player stays at the safe entrance.
const SCENE := "res://maps/intelligence/scenes/intelligence_k17.tscn"
const Cleanup := preload("res://tests/test_utils.gd")
const ProjectionLayout := preload("res://maps/intelligence/resources/layout/k17_projection.gd")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file(SCENE)
	for i in 45:
		await physics_frame
	var guards := current_scene.get_node("Guards").get_children()
	var reinforced := OS.get_cmdline_user_args().has("--reinforced")
	if reinforced:
		var player:=current_scene.get_node("Player") as FirstPersonPlayer
		player.set_physics_process(false)
		player.global_position=preload("res://maps/intelligence/resources/layout/k17_layout.gd").PREP
		player.camera.look_at(Vector3(8,1,-30))
		var mission:=current_scene.get_node("Gameplay/Mission") as K17MissionController
		mission.set_physics_process(false)
		for id in [K17MissionController.ENTER,K17MissionController.PASS,K17MissionController.CODE,K17MissionController.ARCHIVE,K17MissionController.VAULT,K17MissionController.FILE]: ObjectiveManager.find(current_scene).complete(id)
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
	var post := get_first_node_in_group("k17_projection_post") as Guard
	var terminal_checks := false
	var left_post := false
	for guard in guards:
		var counter := {"name": guard.name, "posted": guard == post, "reached": 0, "stuck": 0,"missed":0}
		guard.patrol_point_reached.connect(func(index):
			counter.reached += 1
			if guard.global_position.distance_to(guard.patrol_route.get_point_position(index))>1.5: counter.missed+=1)
		guard.got_stuck.connect(func(_index): counter.stuck += 1)
		counters.append(counter)
	for i in 5400:
		await physics_frame
		if post != null:
			terminal_checks = terminal_checks or float(post.get("check_left")) > 0.0
			left_post = left_post or post.global_position.distance_to(ProjectionLayout.POST) > .7
	var post_ok := post != null and terminal_checks and left_post == reinforced
	print("  [K17 post] terminal_check=",terminal_checks," left_post=",left_post," expected_departure=",reinforced)
	var ok := GameFlow.find(current_scene).state == GameStateMachine.State.PLAYING and post_ok
	ok = ok and guards.size() == (10 if reinforced else 6)
	for counter in counters:
		print("  [K17 patrol] ", counter)
		ok = ok and counter.stuck == 0 and counter.missed==0 and (counter.posted or counter.reached >= 4)
	print("K17 PATROL PASSED (90 simulated seconds, %d live NPCs)"%guards.size() if ok else "K17 PATROL FAILED")
	current_scene.queue_free()
	for i in 40:
		await process_frame
	await Cleanup.settle_async_audio(self)
	quit(0 if ok else 1)
