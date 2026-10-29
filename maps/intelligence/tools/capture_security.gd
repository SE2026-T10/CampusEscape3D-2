extends SceneTree
## Staged render evidence for the actual shipped controls, sensors and gates.
var output := "res://ci-logs/k17-security"
var level: Node3D
var player: FirstPersonPlayer

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17.tscn")
	await _frames(45)
	level = current_scene
	player = level.get_node("Player")
	player.set_physics_process(false)
	for guard in level.get_node("Guards").get_children(): guard.process_mode = Node.PROCESS_MODE_DISABLED
	var flow := GameFlow.find(level)
	if flow.state == GameStateMachine.State.PAUSED: flow.resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var mission := level.get_node("Gameplay/Mission") as K17MissionController
	var objectives := ObjectiveManager.find(level)
	for id in [K17MissionController.ENTER,K17MissionController.PASS,K17MissionController.ARCHIVE]: objectives.complete(id)
	level.get_node("Gameplay/ArchiveDoor").open()
	for sensor in get_nodes_in_group("k17_sensors"): sensor.set_physics_process(false)
	var sensor := mission.get_security_node("Sensor0") as K17SensorLane
	sensor.phase_clock = 5.2
	_view(Vector3(10,.05,-9.2),Vector3(10,1.2,-12))
	sensor._physics_process(0.0)
	await _shot("01_sensor")
	var file := level.get_node("Gameplay/IntelligenceFile") as Interactable
	_view(Vector3(4,.05,-18.5),file.global_position)
	await _frames(4)
	_press(true)
	await _frames(100)
	await _shot("02_hold_progress")
	_press(false)
	var radio := mission.get_security_node("Radio")
	_view(Vector3(1.9,.05,11.5),radio.global_position)
	await _frames(4)
	_press(true)
	_press(false)
	await _shot("03_radio")
	_view(Vector3(4,.05,-18.5),file.global_position)
	await _frames(4)
	_press(true)
	await _frames(215)
	_press(false)
	mission._physics_process(56.0)
	_view(Vector3(16,.05,20.25),Vector3(16,1.4,22))
	await _frames(40)
	await _shot("04_lockdown")
	current_scene = null
	level.queue_free()
	await _frames(60)
	print("K17 SECURITY CAPTURED (staged states, real hold input and renderer)")
	quit()

func _view(position: Vector3,target: Vector3) -> void:
	player.global_position = position
	player.get_node("Head").rotation = Vector3.ZERO
	player.camera.look_at(target)

func _press(down: bool) -> void:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = down
	root.push_input(event)

func _shot(title: String) -> void:
	await _frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output.path_join(title+".png")))

func _frames(count: int) -> void:
	for i in count: await physics_frame
