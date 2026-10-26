extends SceneTree

## Collision/interaction playthrough with the real shared player controller.
## Guards are disabled ONLY in this QA tool to isolate geometry; the shipping
## scene keeps all four guards active. Use -- --out=res://... for screenshots.
const SCENE := "res://maps/intelligence/scenes/intelligence_k17.tscn"
var failures: Array[String] = []
var out := ""
var capture_only := false
var level: Node3D
var player: FirstPersonPlayer
var mission: K17MissionController
var flow: GameFlow
var waypoints := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
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
	for route in ["courtyard", "maintenance"]:
		change_scene_to_file(SCENE)
		await _frames(45)
		level = current_scene as Node3D
		player = level.get_node("Player") as FirstPersonPlayer
		mission = level.get_node("Gameplay/Mission") as K17MissionController
		flow = GameFlow.find(level)
		if flow.state == GameStateMachine.State.PAUSED:
			flow.resume()
		for guard in level.get_node("Guards").get_children():
			guard.process_mode = Node.PROCESS_MODE_DISABLED
		if route == "courtyard":
			await _shot("01_spawn")
			await _route([Vector3(-16, 0, 20), Vector3(-12, 0, 18), Vector3(-12, 0, 11), Vector3(-12, 0, 5.6)])
		else:
			await _route([Vector3(16, 0, 27), Vector3(16, 0, 18), Vector3(16, 0, 7), Vector3(4, 0, 7), Vector3(-12, 0, 7), Vector3(-12, 0, 5.6)])
		await _use("Gameplay/AccessPass")
		await _route([Vector3(-8, 0, 7), Vector3(4, 0, 7), Vector3(4, 0, 1.6)])
		await _use("Gameplay/ArchiveDoor")
		await _route([Vector3(4, 0, -1), Vector3(10.8, 0, -1), Vector3(10.8, 0, -6), Vector3(8, 0, -6)])
		await _route([Vector3(10, 0, -6), Vector3(10, 0, -20), Vector3(4, 0, -18.5)])
		await _use("Gameplay/IntelligenceFile")
		if not mission.has_file:
			failures.append(route + ": file was not acquired")
		if route == "courtyard":
			await _shot("02_archive_and_countdown")
		await _route([Vector3(10, 0, -20), Vector3(10.8, 0, -6), Vector3(10.8, 0, -1), Vector3(4, 0, -1), Vector3(4, 0, 7)])
		if route == "courtyard":
			await _route([Vector3(-12, 0, 7), Vector3(-12, 0, 18), Vector3(-16, 0, 20), Vector3(-16, 0, 25.7)])
		else:
			await _route([Vector3(16, 0, 7), Vector3(16, 0, 18), Vector3(16, 0, 25.7)])
		await _frames(5)
		if flow.state != GameStateMachine.State.WIN:
			failures.append(route + ": did not win after walking into extraction")
		print("  [K17 walking] ", route, ": ", waypoints, " waypoints so far; ", snappedf(mission.time_left, 0.1), " seconds left")
		if route == "courtyard":
			await _shot("03_victory")
		current_scene = null
		level.queue_free()
		await _frames(40)
	for failure in failures:
		printerr(failure)
	print("K17 WALKING PASSED (%d waypoints, 2 routes; guards disabled for collision QA)" % waypoints if failures.is_empty() else "K17 WALKING FAILED")
	quit(0 if failures.is_empty() else 1)


func _route(points: Array) -> void:
	for target in points:
		if not await _walk(target):
			return


func _walk(target: Vector3) -> bool:
	waypoints += 1
	player.get_node("Head").rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	Input.action_press("move_forward")
	var arrived := false
	for i in 900:
		if flow.state != GameStateMachine.State.PLAYING:
			break
		var delta := Vector2(target.x - player.global_position.x, target.z - player.global_position.z)
		if delta.length() < 0.38:
			arrived = true
			break
		player.rotation.y = atan2(-delta.x, -delta.y)
		await physics_frame
	Input.action_release("move_forward")
	await _frames(6)
	if not arrived and flow.state != GameStateMachine.State.WIN:
		failures.append("Blocked walking toward %s (actual %s, state %s)" % [target, player.global_position, flow.state])
		return false
	return true


func _use(path: String) -> void:
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
