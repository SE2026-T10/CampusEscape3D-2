extends SceneTree

## Focused museum demo verification; intentionally run manually, not at startup.
## godot --headless --path . --script res://maps/museum/tools/verify_demo.gd

const SCENE := "res://maps/museum/scenes/museum.tscn"
const IDS := [&"take_t1", &"take_t2", &"take_t3", &"take_rope"]
const PICKUPS := ["Painting_T1", "Painting_T2", "Painting_T3", "Rope"]
const POSITIONS := [Vector3(-4, 0, 0), Vector3(4, 0, 0), Vector3(0, 0, -4), Vector3(-3.8, 0, 3.6)]
var failures := 0
var checks := 0
var level: Node3D


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		push_error(label)


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func isolate() -> void:
	var guard := level.get_node("Guard_Test") as Guard
	guard.set_physics_process(false)
	guard.agent.avoidance_enabled = false
	guard.velocity = Vector3.ZERO
	guard.vision.set_physics_process(false)
	guard.vision.reset()
	guard.hearing.set_physics_process(false)
	level.get_node("Player").set_physics_process(false)
	level.get_node("Player/Noise").set_physics_process(false)
	level.get_node("StealthDirector").set_physics_process(false)


func fresh(quiet := true) -> void:
	paused = false
	if is_instance_valid(level):
		current_scene = null
		root.remove_child(level)
		level.free()
		await frames(2)
	level = (load(SCENE) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	if quiet:
		isolate()
	await frames(8)


func clean_start() -> bool:
	var manager := level.get_node("ObjectiveManager") as ObjectiveManager
	if manager.completed_count() != 0 or manager.get_state(&"escape") != ObjectiveManager.State.LOCKED:
		return false
	for i in IDS.size():
		var pickup := level.get_node("Interactables/" + PICKUPS[i]) as Interactable
		if manager.get_state(IDS[i]) != ObjectiveManager.State.ACTIVE or not pickup.visible or not pickup.enabled or pickup.collision_layer != Interactable.LAYER:
			return false
	return level.get_node("GameFlow").state == GameStateMachine.State.PLAYING


func aim_at(target: Node3D, feet: Vector3) -> void:
	var player := level.get_node("Player") as FirstPersonPlayer
	player.position = feet
	player.velocity = Vector3.ZERO
	player.camera.look_at(target.global_position, Vector3.UP)
	await frames(3)


func press_e() -> void:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = &"interact"
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func reload_from(button: Button) -> void:
	var old_id := level.get_instance_id()
	button.pressed.emit()
	for i in 30:
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != old_id:
			level = current_scene as Node3D
			isolate()
			await frames(8)
			check(level.scene_file_path == SCENE and clean_start(), "Menu reload restores museum and all pickup states")
			return
	check(false, "Menu reload finishes within bounded frames")


func permutations(values: Array) -> Array:
	if values.is_empty():
		return [[]]
	var result := []
	for i in values.size():
		var rest := values.duplicate()
		var first = rest.pop_at(i)
		for tail in permutations(rest):
			result.append([first] + tail)
	return result


func _run() -> void:
	await fresh()
	var manager := level.get_node("ObjectiveManager") as ObjectiveManager
	check(clean_start() and manager.is_graph() and manager.get_mandatory_ids().size() == 5, "Scene initializes museum objectives before child readiness")
	check(level.get_node("ObjectiveHud").get_layout_controls().objectives.visible, "Objective HUD shows mission checklist")
	var exit := level.get_node("Interactables/EscapeWindow") as Interactable
	var player := level.get_node("Player") as FirstPersonPlayer
	for missing in IDS:
		manager.reset()
		for id in IDS:
			if id != missing:
				manager.complete(id)
		check(not exit.interact(player) and not manager.is_finished(), "Exit refuses missing requirement: " + str(missing))
	var orders := permutations(Array(IDS))
	var all_orders := orders.size() == 24
	for order in orders:
		manager.reset()
		for id in order:
			all_orders = manager.complete(id) and all_orders
		all_orders = all_orders and manager.get_state(&"escape") == ObjectiveManager.State.ACTIVE and not manager.is_finished()
	check(all_orders, "All 24 pickup orders activate escape without automatic WIN")
	await fresh()
	manager = level.get_node("ObjectiveManager") as ObjectiveManager
	exit = level.get_node("Interactables/EscapeWindow") as Interactable
	player = level.get_node("Player") as FirstPersonPlayer
	await aim_at(exit, Vector3(3.8, 0, 4))
	var interactor := player.get_node("Interactor") as PlayerInteractor
	check(interactor.find_target() == exit, "Escape Area is reachable by camera ray")
	await press_e()
	check(level.get_node("ObjectiveHud").get_layout_controls().message.text.contains("3 tác phẩm"), "Missing-items E interaction displays HUD rejection")
	# A ray within reach must still stop at the world collision.
	var target := level.get_node("Interactables/Painting_T3") as Interactable
	var original := target.position
	target.position = Vector3(0, 0.8, -0.9)
	await aim_at(target, Vector3(0, 0, 1.1))
	check(interactor.find_target() == null, "Central plinth blocks pickup interaction ray")
	target.position = Vector3(0, 0.8, 0.85)
	await aim_at(target, Vector3(0, 0, 1.1))
	check(interactor.find_target() == target, "Same nearby pickup is reachable in front of plinth")
	target.position = Vector3(0, 1.5, -6.2)
	await aim_at(target, Vector3(0, 0, -4.5))
	check(interactor.find_target() == null, "Room wall blocks interaction with pickup behind wall")
	target.position = original
	for i in PICKUPS.size():
		var pickup := level.get_node("Interactables/" + PICKUPS[i]) as Interactable
		await aim_at(pickup, POSITIONS[i])
		check(interactor.find_target() == pickup, "Camera ray finds " + PICKUPS[i])
		await press_e()
		check(manager.is_completed(IDS[i]) and not pickup.visible and not pickup.enabled and pickup.collision_layer == 0, "E collects and removes interaction collision: " + PICKUPS[i])
		check(not pickup.interact(player), "Pickup cannot be collected twice: " + PICKUPS[i])
	check(not manager.is_finished() and level.get_node("GameFlow").state == GameStateMachine.State.PLAYING, "All items collected still requires explicit escape")
	var director := level.get_node("StealthDirector") as StealthDirector
	var guard := level.get_node("Guard_Test") as Guard
	for status in [StealthDirector.Status.SPOTTED, StealthDirector.Status.CHASE, StealthDirector.Status.CAUGHT]:
		director.status = status
		check(not exit.interact(player), "Exit refuses director state " + str(status))
	director.status = StealthDirector.Status.NONE
	guard.vision.can_see_target = true
	check(not exit.interact(player), "Live guard sight blocks exit before director aggregate updates")
	guard.vision.can_see_target = false
	guard.machine.request_transition(GuardStateMachine.CHASE, "verification", player.position)
	check(not exit.interact(player), "Live guard CHASE blocks exit before director aggregate updates")
	guard.reset_to_start()
	guard.set_physics_process(false)
	await aim_at(exit, Vector3(3.8, 0, 4))
	await press_e()
	var flow := level.get_node("GameFlow") as GameFlow
	var menus := level.get_node("GameMenus") as GameMenus
	check(manager.is_finished() and flow.state == GameStateMachine.State.WIN and menus.win_panel.visible, "Successful camera-ray E escape shows WIN menu")
	check(director.status == StealthDirector.Status.ESCAPED and player.process_mode == Node.PROCESS_MODE_DISABLED and guard.process_mode == Node.PROCESS_MODE_DISABLED, "WIN freezes player and guard through StealthDirector")
	check(manager.escape_route == &"museum_rope", "Win records museum rope escape route")
	await reload_from(menus.play_again_button)
	# Restart with partial collection must likewise restore actual scene instances.
	level.get_node("Interactables/Painting_T1").interact(level.get_node("Player"))
	level.get_node("GameFlow").pause()
	await reload_from(level.get_node("GameMenus").restart_button)
	# Real perception, pursuit, capture and delayed full scene reload.
	await fresh(false)
	level.get_node("Interactables/Rope").interact(level.get_node("Player"))
	player = level.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	player.get_node("Noise").set_physics_process(false)
	player.position = Vector3(0, 0, -2)
	guard = level.get_node("Guard_Test") as Guard
	guard.position = Vector3(0, 0, -4.5)
	guard.rotation.y = PI
	guard.vision.reset()
	director = level.get_node("StealthDirector") as StealthDirector
	var previous_id := level.get_instance_id()
	var caught := false
	var reloaded := false
	for i in 600:
		await physics_frame
		if current_scene != null and current_scene.get_instance_id() != previous_id:
			level = current_scene as Node3D
			isolate()
			await frames(8)
			reloaded = true
			break
		if is_instance_valid(director) and director.status == StealthDirector.Status.CAUGHT:
			caught = level.get_node("GameFlow").state == GameStateMachine.State.CAUGHT
	check(caught, "Real guard catch shows CAUGHT state before reload")
	check(reloaded and clean_start(), "Caught delay reload restores all pickups and objective progress")
	if reloaded:
		check(level.get_node("Player").position.is_equal_approx(Vector3(0, 0.1, 4)) and level.get_node("Guard_Test").position.distance_to(Vector3(-3, 0.1, -3)) < 0.2, "Full reload restores actor spawn positions")
	paused = false
	current_scene = null
	root.remove_child(level)
	level.free()
	await frames(3)
	print("Museum demo verification: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
