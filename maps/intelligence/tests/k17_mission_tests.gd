extends RefCounted

const SCENE := "res://maps/intelligence/scenes/intelligence_k17.tscn"
const TestUtils := preload("res://tests/test_utils.gd")
const M := preload("res://maps/intelligence/scripts/mission_controller.gd")
const G := GameStateMachine.State
var failures: Array[String] = []
var checks := 0
var host: Node
var level: Node3D
var player: FirstPersonPlayer
var mission: K17MissionController
var objectives: ObjectiveManager
var checkpoints: CheckpointManager
var flow: GameFlow
var director: StealthDirector


func run(parent: Node) -> Array[String]:
	host = parent
	await _load()
	_check_layout()
	_expect(not level.get_node("Gameplay/AccessPass").interact(player), "Pass cannot be taken before entering.")
	_expect(not level.get_node("Gameplay/IntelligenceFile").interact(player), "File cannot be taken before its prerequisites.")
	_expect(not mission.try_extract(&"courtyard", "Sân"), "Starting at extraction cannot win without the file.")
	# Being caught before the checkpoint restarts the entry objectives.
	director.reset_delay = 0.05
	director._catch(level.get_node("Guards/Guard1"))
	await _frames(12)
	_expect(objectives.current() == M.ENTER and checkpoints.active == null, "Caught before checkpoint returns to the entrance.")
	await _prepare_file()
	await _check_pause_timeout_retry()
	await _take_file()
	# Do not overwrite the pre-file snapshot when walking back across it.
	var before := checkpoints.saved_state.duplicate(true)
	player.global_position = Vector3(8, 0.05, -6)
	await _frames(3)
	_expect(checkpoints.saved_state == before, "Returning during extraction never overwrites the checkpoint.")
	director._catch(level.get_node("Guards/Guard1"))
	await _frames(12)
	_check_restored("Caught with file")
	await _take_file()
	player.global_position = Vector3(-16, 0.05, 27)
	await _frames(3)
	_expect(flow.state == G.WIN and mission.escaped, "Courtyard extraction with a live deadline wins.")
	_expect(objectives.escape_route == &"courtyard", "Courtyard extraction records its route.")
	_expect(not flow.fail("late failure") and not mission.try_extract(&"maintenance", "Bảo trì"), "A completed run cannot finish twice or fail later.")
	var menus := level.get_node("GameMenus") as GameMenus
	_expect(menus.get_win_text().contains("Còn lại:") and menus.get_win_text().contains("Sân tiếp vận"), "Shared results show time left and the actual route.")
	await _unload()
	# A fresh level: the other exit and its missing-file/deadline boundaries.
	await _load()
	await _prepare_file()
	await _take_file()
	mission.time_left = 0.0
	_expect(not mission.try_extract(&"maintenance", "Bảo trì"), "Zero seconds never counts as a successful extraction.")
	mission._physics_process(0.01)
	_expect(flow.state == G.FAILED and host.get_tree().paused, "Deadline wins a same-tick tie and freezes the simulation.")
	_expect(flow.retry_checkpoint(), "A deadline failure can retry the checkpoint.")
	await _frames(3)
	await _take_file()
	player.global_position = Vector3(16, 0.05, 27)
	await _frames(3)
	_expect(flow.state == G.WIN and objectives.escape_route == &"maintenance", "Maintenance extraction is independently playable.")
	await _unload()
	print("K17 MISSION CHECKS: ", checks, " checks; ", failures.size(), " failures")
	return failures


func _load() -> void:
	level = (load(SCENE) as PackedScene).instantiate()
	var ready := await TestUtils.add_level_and_wait_for_navigation(host, level, Vector3(-16, 0.05, 27))
	_expect(ready, "K17 navigation becomes ready.")
	await _frames(3)
	player = level.get_node("Player") as FirstPersonPlayer
	mission = level.get_node("Gameplay/Mission") as K17MissionController
	objectives = ObjectiveManager.find(level)
	checkpoints = CheckpointManager.find(level)
	flow = GameFlow.find(level)
	director = StealthDirector.find(level)
	# Mission unit/integration checks isolate actor decisions; the movement QA
	# tool separately exercises both routes with the real player controller.
	player.set_physics_process(false)
	for guard in level.get_node("Guards").get_children():
		guard.process_mode = Node.PROCESS_MODE_DISABLED


func _check_layout() -> void:
	_expect(level.get_node("Guards").get_child_count() == 4, "Four shared guards are placed.")
	_expect(player.scene_file_path == "res://shared/scenes/player/player.tscn", "Player remains an instance of the shared scene.")
	var map: RID = level.get_world_3d().navigation_map
	for guard in level.get_node("Guards").get_children():
		_expect(guard.scene_file_path == "res://shared/scenes/npc/guard.tscn", "Guard uses the shared NPC scene.")
		var route := guard.patrol_route as PatrolRoute
		var points := route.get_children()
		for i in points.size():
			var path := NavigationServer3D.map_get_path(map, points[i].global_position, points[(i + 1) % points.size()].global_position, true)
			_expect(not path.is_empty() and path[-1].distance_to(points[(i + 1) % points.size()].global_position) < 1.0, "Every patrol segment has a navigable path.")
	for target in [Vector3(-12, 0.05, 5.5), Vector3(8, 0.05, -6), Vector3(4, 0.05, -18.5), Vector3(16, 0.05, 27)]:
		var path := NavigationServer3D.map_get_path(map, player.global_position, target, true)
		_expect(not path.is_empty() and path[-1].distance_to(target) < 1.0, "Mission locations and both exits are connected to navigation.")


func _prepare_file() -> void:
	player.global_position = Vector3(-12, 0.05, 11)
	await _frames(3)
	_expect(objectives.current() == M.PASS, "Entering activates the pass objective.")
	await _use("Gameplay/AccessPass", Vector3(-12, 0.05, 5.6))
	_expect(objectives.is_completed(M.PASS), "Pass is collected through the shared interactor ray.")
	await _use("Gameplay/ArchiveDoor", Vector3(4, 0.05, 1.6))
	_expect(level.get_node("Gameplay/ArchiveDoor").is_open, "Pass opens the controlled archive door.")
	player.global_position = Vector3(8, 0.05, -6)
	await _frames(4)
	_expect(checkpoints.active != null and objectives.current() == M.FILE, "Preparation area saves progress before taking the file.")
	_expect(not mission.has_file and mission.time_left == mission.escape_duration, "Pre-file clock is inactive.")


func _take_file() -> void:
	await _use("Gameplay/IntelligenceFile", Vector3(4, 0.05, -18.5))
	_expect(mission.has_file and objectives.current() == M.ESCAPE, "File pickup starts extraction.")
	_expect(mission.time_left > 119.0 and mission.time_left <= 120.0, "Exactly one 120-second deadline starts on pickup.")
	var remaining := mission.time_left
	_expect(not level.get_node("Gameplay/IntelligenceFile").interact(player) and mission.time_left == remaining, "Duplicate pickup cannot restart the clock.")


func _check_pause_timeout_retry() -> void:
	await _take_file()
	var remaining := mission.time_left
	_expect(flow.pause(), "Pause is accepted during extraction.")
	await _frames(12)
	_expect(mission.time_left == remaining, "Pause freezes the mission deadline.")
	_expect(not flow.fail("paused"), "A failure request cannot replace a paused state.")
	flow.resume()
	mission.time_left = 0.025
	var catches := director.catches
	await _frames(8)
	_expect(flow.state == G.FAILED and host.get_tree().paused, "Running out of time opens the failure state and freezes the world.")
	var menus := level.get_node("GameMenus") as GameMenus
	_expect(menus.failure_panel.visible and flow.applied_mouse_mode == Input.MOUSE_MODE_VISIBLE, "Failure screen shows retry controls and frees the pointer.")
	_expect(director.catches == catches and mission.timeouts == 1, "Timeout is recorded once without inventing a guard catch.")
	menus.retry_checkpoint_button.pressed.emit()
	await _frames(3)
	_check_restored("Retry from failure menu")


func _check_restored(label: String) -> void:
	_expect(flow.state == G.PLAYING and not host.get_tree().paused, label + ": playing and unpaused.")
	_expect(not mission.has_file and not mission.escaped and mission.time_left == mission.escape_duration, label + ": file and clock restored.")
	_expect(objectives.current() == M.FILE and objectives.is_completed(M.PASS), label + ": pass retained, file objective active.")
	_expect(level.get_node("Gameplay/IntelligenceFile").visible and not level.get_node("Gameplay/AccessPass").visible, label + ": correct pickups are visible.")
	_expect(level.get_node("Gameplay/ArchiveDoor").is_open, label + ": door matches the checkpoint snapshot.")
	_expect(player.global_position.distance_to(Vector3(8, 0.05, -6)) < 0.2, label + ": correct respawn position.")


func _use(path: String, stand: Vector3) -> void:
	var target := level.get_node(path) as Interactable
	player.global_position = stand
	player.camera.look_at(target.global_position)
	await _frames(3)
	var interactor := player.get_node("Interactor") as PlayerInteractor
	_expect(interactor.focused == target, "Interaction ray reaches " + path)
	var duration := target.get_hold_duration(player)
	if duration > 0.0: Input.action_press("interact")
	_expect(interactor.try_interact(), "Interaction succeeds for " + path)
	if duration > 0.0:
		await _frames(ceili(duration * Engine.physics_ticks_per_second)+2)
		Input.action_release("interact")
	await _frames(2)


func _unload() -> void:
	host.get_tree().paused = false
	level.queue_free()
	for i in 40:
		await host.get_tree().process_frame
	_expect(host.get_tree().get_nodes_in_group("k17_mission").is_empty(), "K17 state is released after leaving.")


func _frames(count: int) -> void:
	for i in count:
		await host.get_tree().physics_frame


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append("[K17] " + message)
