extends RefCounted

const NORMAL_SCENE := "res://maps/intelligence/scenes/intelligence_k17.tscn"
const TEST_SCENE := "res://maps/intelligence/scenes/intelligence_k17_test.tscn"
const Utils := preload("res://tests/test_utils.gd")
var failures: Array[String] = []
var checks := 0
var host: Node
var level: Node3D
var player: FirstPersonPlayer
var mission: K17MissionController


func run(parent: Node) -> Array[String]:
	host = parent
	await _load(TEST_SCENE)
	_expect(level.get_node("Guards").get_child_count() == 0, "Test mode removes guard bodies instead of just hiding them.")
	_expect(host.get_tree().get_nodes_in_group("guards").is_empty() and host.get_tree().get_nodes_in_group("checkpoint_guards").is_empty(), "No guard or guard checkpoint participant enters the tree.")
	_expect(host.get_tree().get_nodes_in_group("navigation_debug_agents").is_empty(), "No guard navigation agent survives in test mode.")
	_expect(mission.is_test_mode() and mission.get_status_lines()[0].contains("KHÔNG LÍNH GÁC"), "The HUD identifies test mode.")
	var initial := player.global_position
	Input.action_press("move_forward")
	await _frames(15)
	Input.action_release("move_forward")
	_expect(player.global_position.distance_to(initial) > .3, "The player still moves through the real shared controller.")
	player.set_physics_process(false)
	var objectives := ObjectiveManager.find(level)
	var flow := GameFlow.find(level)
	_expect(not mission.try_extract(&"maintenance", "Bảo trì"), "Test mode still requires the mission document to escape.")
	player.global_position = Vector3(-12, .05, 11)
	await _frames(3)
	_expect(objectives.current() == K17MissionController.PASS, "The entry trigger still advances the mission.")
	await _use("Gameplay/AccessPass", Vector3(-12, .05, 5.6))
	_expect(objectives.is_completed(K17MissionController.PASS), "The access pass is collected normally.")
	await _use("Gameplay/Security/PreparedLatch", Vector3(17.2, .05, 5))
	_expect(mission.backdoor_prepared, "The backdoor preparation hold still works.")
	await _use("Gameplay/ArchiveDoor", Vector3(4, .05, 1.6))
	_expect(level.get_node("Gameplay/ArchiveDoor").is_open, "The pass opens the real archive door.")
	player.global_position = Vector3(8, .05, -6)
	await _frames(4)
	_expect(CheckpointManager.find(level).active != null, "The normal pre-document checkpoint is saved.")
	var sensor := host.get_tree().get_first_node_in_group("k17_sensors") as K17SensorLane
	sensor.phase_clock = 5.5 - sensor.phase_offset
	player.global_position = Vector3(10, .05, -12)
	await _frames(4)
	_expect(mission.sensor_trips == 1, "Crossing a live red sensor still raises its alarm.")
	_expect(flow.state == GameStateMachine.State.PLAYING and StealthDirector.find(level).catches == 0, "A sensor alarm cannot invent a guard catch in an empty map.")
	await _use("Gameplay/IntelligenceFile", Vector3(4, .05, -18.5))
	_expect(mission.has_file and mission.time_left > 119 and mission.time_left <= 120, "Holding E collects the file and starts the real 120-second deadline.")
	_expect(level.get_node("Gameplay/Security/MaintenanceGate").is_closed, "The backdoor still locks on document pickup.")
	mission.time_left = .01
	mission._physics_process(.02)
	_expect(flow.state == GameStateMachine.State.FAILED and host.get_tree().paused, "The deadline still fails and pauses a test run.")
	_expect(flow.retry_checkpoint(), "The test run can retry its checkpoint.")
	await _frames(4)
	_expect(not mission.has_file and mission.backdoor_prepared and objectives.current() == K17MissionController.FILE, "Retry restores the document and prepared backdoor state.")
	_expect(mission.is_test_mode() and host.get_tree().get_nodes_in_group("guards").is_empty(), "Checkpoint retry never brings guards back.")
	await _use("Gameplay/IntelligenceFile", Vector3(4, .05, -18.5))
	player.global_position = Vector3(16, .05, 27)
	await _frames(3)
	_expect(flow.state == GameStateMachine.State.WIN and mission.escaped, "The real maintenance extraction can finish a test run.")
	_expect(mission.get_result_lines()[0].contains("TEST MAP"), "Results explicitly identify a test run.")
	var requests: Array[String] = []
	flow.change_scene = func(path: String): requests.append(path)
	_expect(flow.restart() and requests == [TEST_SCENE], "Play again restarts the test scene, preserving the mode.")
	await _unload()
	await _load(NORMAL_SCENE)
	_expect(level.get_node("Guards").get_child_count() == 4 and host.get_tree().get_nodes_in_group("guards").size() == 4, "A subsequent normal map still has all four guards.")
	_expect(level.get_node("Guards").get_children().all(func(g): return g.can_process()), "The four guards in the normal map remain active.")
	_expect(not mission.is_test_mode() and not mission.get_status_lines()[0].contains("TEST MAP"), "Test mode never leaks into a normal mission.")
	requests.clear()
	flow = GameFlow.find(level)
	flow.change_scene = func(path: String): requests.append(path)
	_expect(flow.restart() and requests == [NORMAL_SCENE], "Normal Restart keeps the normal scene.")
	await _unload()
	print("K17 TEST MODE CHECKS: %d checks; %d failures" % [checks, failures.size()])
	return failures


func _load(path: String) -> void:
	level = (load(path) as PackedScene).instantiate() as Node3D
	_expect(await Utils.add_level_and_wait_for_navigation(host, level, Vector3(-16, .05, 27)), "Navigation becomes ready for " + path.get_file())
	await _frames(3)
	player = level.get_node("Player") as FirstPersonPlayer
	mission = level.get_node("Gameplay/Mission") as K17MissionController


func _use(path: String, stand: Vector3) -> void:
	var target := level.get_node(path) as Interactable
	player.global_position = stand
	player.camera.look_at(target.global_position)
	await _frames(3)
	_expect(player.get_node("Interactor").focused == target, "The interaction ray reaches " + path)
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	host.get_tree().root.push_input(press)
	await _frames(ceili(target.get_hold_duration(player) * Engine.physics_ticks_per_second) + 3)
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	host.get_tree().root.push_input(release)
	await _frames(3)


func _unload() -> void:
	host.get_tree().paused = false
	level.queue_free()
	await _frames(40)
	_expect(host.get_tree().get_nodes_in_group("k17_no_guards").is_empty(), "Leaving the scene releases its test mode.")


func _frames(count: int) -> void:
	for i in count:
		await host.get_tree().physics_frame


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append("[K17 test mode] " + message)
