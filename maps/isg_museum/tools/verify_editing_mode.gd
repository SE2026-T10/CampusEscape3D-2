extends "res://maps/isg_museum/tools/verify_blockout.gd"

## Real inherited-scene lifecycle and interaction checks; shared AI stays enabled
## on the normal scene. No key, ticket, rope or objective is granted by fixtures.
const EDITING := "res://maps/isg_museum/scenes/museum_editing.tscn"
var player: FirstPersonPlayer
var guard_entries := 0


func _guard_entered() -> void:
	guard_entries += 1


func _subtree_ids(node: Node, ids: Array[int]) -> void:
	ids.append(node.get_instance_id())
	for child in node.get_children():
		_subtree_ids(child, ids)


func _no_guards() -> bool:
	if not get_nodes_in_group("guards").is_empty() or not get_nodes_in_group("noise_listeners").is_empty():
		return false
	for body in level.find_children("*", "CollisionObject3D", true, false):
		if body.collision_layer & 4:
			return false
	return NavigationServer3D.map_get_agents(level.get_world_3d().navigation_map).is_empty()


func _bind() -> void:
	player = level.get_node("Player")
	player.set_physics_process(false)
	var flow := level.get_node("GameFlow") as GameFlow
	if flow.state == GameStateMachine.State.PAUSED:
		flow.resume()


func _pose(feet: Vector3, target: Node3D = null) -> void:
	player.position = feet
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	if target != null:
		player.camera.look_at(target.global_position)
	await frames(4)


func _fresh_progress() -> bool:
	var manager := level.get_node("ObjectiveManager") as ObjectiveManager
	var contract = get_first_node_in_group("museum_contract")
	return manager.completed_count() == 0 and not contract.accepted and not contract.has_ticket \
		and not contract.ticket_scanned and not manager.is_completed(&"take_key") \
		and not manager.is_completed(&"take_rope") and level.get_node("Interactables/Painting_T2").state == 0 \
		and not level.get_node("Interactables/Painting_T1").is_missing \
		and not level.get_node("NavigationRegion3D/Doors/Storage").unlocked


func _wait_reload(old_id: int, caption: String) -> void:
	var reloaded := false
	for tick in 120:
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != old_id:
			level = current_scene as Node3D
			await frames(10)
			_bind()
			reloaded = true
			break
	check(reloaded and level.scene_file_path == EDITING and level.disable_guards_for_editing,
		caption + " reloads the editing scene")
	check(_no_guards() and _fresh_progress(), caption + " restores progress without resurrecting guards")


func _run() -> void:
	var normal := load(SCENE).instantiate() as Node3D
	var packed := load(EDITING) as PackedScene
	level = packed.instantiate()
	check(not normal.disable_guards_for_editing and level.disable_guards_for_editing,
		"Only the inherited editing scene enables the exported startup flag")
	check(level.get_script() == normal.get_script(), "Editing keeps museum_demo and objective initialization")
	var normal_guards := 0
	var source_guards := 0
	var guard_ids: Array[int] = []
	for child in normal.get_children():
		if child is Guard:
			normal_guards += 1
	for child in level.get_children():
		if child is Guard:
			source_guards += 1
			_subtree_ids(child, guard_ids)
			child.tree_entered.connect(_guard_entered)
			check(child.transform == normal.get_node(NodePath(child.name)).transform,
				"Inherited editor guard keeps its placement: " + str(child.name))
	check(normal_guards == 9 and source_guards == 9, "Both scene sources retain nine editable guards")
	var navigation: NavigationMesh = normal.get_node("NavigationRegion3D").navigation_mesh
	check(level.get_node("NavigationRegion3D").navigation_mesh == navigation \
		and level.get_node("NavigationRegion3D/Geometry").scene_file_path == normal.get_node("NavigationRegion3D/Geometry").scene_file_path,
		"Editing shares geometry and the original navmesh")
	normal.free()
	var detached := packed.instantiate()
	check(detached._remove_runtime_guards_for_editing() == 9 and detached._remove_runtime_guards_for_editing() == 0,
		"Removal helper returns nine, then zero when repeated")
	detached.free()
	root.add_child(level)
	current_scene = level
	await frames(10)
	_bind()
	check(guard_entries == 0 and guard_ids.all(func(id: int): return not is_instance_id_valid(id)),
		"Guard bodies, perception and agents are freed before entering SceneTree")
	check(_no_guards(), "Editing has no guard group, NPC collider, avoidance agent or noise listener")
	for path in ["Player", "GameFlow", "StealthDirector", "NoiseSystem", "ObjectiveManager", "ObjectiveHud",
		"NavigationRegion3D/Teammate", "NavigationRegion3D/ServiceExpansion/Receptionist", "EditingNotice"]:
		check(level.has_node(path), "Editing retains " + path)
	check(_fresh_progress(), "Editing starts without granting contracts, K, V, rope or objectives")
	var flow := level.get_node("GameFlow") as GameFlow
	check(flow.owner == level and flow.owner.scene_file_path == EDITING, "GameFlow resolves restart to the inherited scene")
	flow.pause()
	await process_frame
	check(paused and flow.state == GameStateMachine.State.PAUSED, "Editing pauses normally")
	check(flow.resume() and not paused, "Editing resumes normally")
	var old_id := level.get_instance_id()
	flow.pause()
	level.get_node("GameMenus").restart_button.pressed.emit()
	await _wait_reload(old_id, "Pause menu Restart")
	var contract = get_first_node_in_group("museum_contract")
	var manager := level.get_node("ObjectiveManager") as ObjectiveManager
	var director := level.get_node("StealthDirector") as StealthDirector
	var noise := level.get_node("NoiseSystem") as NoiseSystem
	var doors := level.get_node("NavigationRegion3D/Doors")
	var service := level.get_node("NavigationRegion3D/ServiceExpansion")
	var gate = service.get_node("TicketGate_A")
	check(not gate.interact(player) and not doors.get_node("GalleryB").interact(player),
		"Editing still enforces V and K door requirements")
	check(not level.get_node("Interactables/Painting_T2").interact(player) \
		and not level.get_node("Interactables/Rope").interact(player), "T2 and rope retain their prerequisites")
	check(not level.get_node("Interactables/EscapeWindow").interact(player), "Escape still requires rope")
	var teammate := level.get_node("NavigationRegion3D/Teammate") as Interactable
	await _pose(Vector3(20.5,0,33.3), teammate)
	check(teammate.interact(player), "N0 opens the normal contract sheet")
	var contract_ui = get_first_node_in_group("museum_contract_ui")
	check(contract_ui.visible and not contract.accepted, "Opening N0 does not silently accept the contract")
	contract_ui.accept_button.pressed.emit()
	contract_ui.close_sheet()
	check(contract.accepted, "Normal N0 acceptance button works without guards")
	var receptionist := service.get_node("Receptionist") as Interactable
	await _pose(Vector3(31.1,0,27), receptionist)
	check(player.get_node("Interactor").find_target() == receptionist and receptionist.interact(player),
		"Receptionist remains selectable by the real camera")
	var service_ui = service.get_node("ServiceUi")
	for question in 3:
		service_ui.answers.get_child(service_ui.questions[question].correct).pressed.emit()
	check(contract.has_ticket, "Answering the normal service quiz grants V")
	service_ui.close_panel()
	var staff = level.get_node("NavigationRegion3D/Geometry/StaffInterior")
	await _pose(Vector3(25.5,0,10))
	check(doors.get_node("Staff").interact(player), "Staff door still opens normally")
	var key := level.get_node("Interactables/Key") as Interactable
	await _pose(Vector3(34,0,10.2), key)
	check(player.get_node("Interactor").find_target() == key and key.interact(player) \
		and manager.is_completed(&"take_key"), "K is collected through its existing interaction")
	var calendar = staff.get_node("MaintenanceBoard")
	await _pose(Vector3(28.7,0,16), calendar)
	check(calendar.interact(player) and get_first_node_in_group("staff_reader").panel.visible,
		"Live calendar still opens")
	get_first_node_in_group("staff_reader").close_document()
	var bottle = staff.find_children("NoisyBottle*", "Area3D", false, false)[0]
	await _pose(bottle.global_position)
	await frames(8)
	check(bottle.triggers > 0, "Real player overlap still bumps the bottle and emits noise")
	var display = level.get_node("NavigationRegion3D/ExhibitsExpansion/S1")
	await _pose(Vector3(6.3,0,11.5), display)
	var emitted_before := noise.emitted_count
	check(display.interact(player) and display.broken and not display.get_node("Glass").visible,
		"Glass still breaks with no guard listener present")
	check(noise.emitted_count > emitted_before and display.get_node("Artifact").visible,
		"Glass produces real noise and keeps the separate artifact")
	var storage = doors.get_node("Storage")
	await _pose(Vector3(25.5,0,21))
	for attempt in 3:
		storage.submit_code("0000", player)
	check(storage.alarm_count == 1 and not storage.unlocked, "Three wrong codes still sound the storage alarm")
	check(storage.current_code() == calendar.get_code(), "Keypad still follows the live calendar")
	storage.interact(player)
	for digit in storage.current_code():
		storage.keypad._button(digit)
	storage.keypad._button("Mở")
	check(storage.unlocked and storage.is_open and not player.keypad_active,
		"Normal keypad unlocks storage and releases the input modal")
	check(await walk(player, [Vector3(28.5,0,21),Vector3(33.9,0,20.6)]), "Player walks into storage normally")
	var rope := level.get_node("Interactables/Rope") as Interactable
	player.camera.look_at(rope.global_position)
	await frames(4)
	check(player.get_node("Interactor").find_target() == rope and rope.interact(player) \
		and manager.is_completed(&"take_rope"), "Rope remains reachable and collectible")
	await _pose(Vector3(18,0,31.8))
	check(doors.get_node("Entrance").interact(player), "Main entrance keeps its normal interaction")
	emitted_before = noise.emitted_count
	Input.action_press("sprint")
	check(await walk(player, [Vector3(18,0,28.5)]), "Real player runs through the main entrance")
	Input.action_release("sprint")
	check(noise.emitted_count > emitted_before, "Running still emits normal footsteps")
	check(await walk(player, [Vector3(10.5,0,27),Vector3(8,0,27),Vector3(7.4,0,28.25),
		Vector3(1.2,2.25,28.25),Vector3(1.2,2.25,25.75),Vector3(7.5,4.5,25.75),Vector3(8,4.5,27)]),
		"Player climbs both flights to floor two with original collision")
	check(gate.interact(player) and await walk(player, [Vector3(10.5,4.5,27)]), "V opens the landing gate and player crosses")
	var painting := level.get_node("Interactables/Painting_T1") as Interactable
	await _pose(Vector3(1.7,4.5,11.5), painting)
	check(painting.interact(player) and not painting.get_node("Canvas").visible \
		and painting.get_node("Frame").visible, "T1 leaves its frame without a missing G6 reference")
	var t3 := level.get_node("Interactables/Painting_T3") as Interactable
	await _pose(Vector3(18,4.5,1.7), t3)
	check(t3.interact(player) and get_first_node_in_group("museum_gallery_alarm").alarm_count == 1,
		"Protected artwork still triggers the real room C alarm")
	await _pose(Vector3(25.5,4.5,27))
	check(doors.get_node("RestorationEntrance").interact(player), "Restoration door remains usable")
	await _pose(Vector3(25.5,4.5,10))
	check(doors.get_node("GalleryB").interact(player), "Collected K opens gallery B")
	var t2 = level.get_node("Interactables/Painting_T2")
	await _pose(Vector3(34.3,4.5,10), t2)
	check(t2.interact(player) and player.is_carrying() and t2.visual.get_parent() == player.camera,
		"T2 uses the original carry controller and visual reparenting")
	check(await walk(player, [Vector3(34.3,4.5,8.5),Vector3(28.7,4.5,8.5),Vector3(28.7,4.5,10),
		Vector3(25.5,4.5,10),Vector3(25.5,4.5,22.5),Vector3(18,4.5,22.5),Vector3(18,4.5,27),
		Vector3(25.5,4.5,27),Vector3(28.5,4.5,27),Vector3(32,4.5,27.5)]),
		"Player carries T2 along the original corridor and warehouse route")
	var depot := level.get_node("Interactables/T2Depot") as Interactable
	player.camera.look_at(depot.get_node("DepositPose").global_position)
	check(depot.interact(player) and manager.is_completed(&"take_t2") and not player.is_carrying(),
		"T2 delivers at the real depot")
	await frames(180)
	check(_no_guards() and director.catches == 0 and director.status == StealthDirector.Status.NONE \
		and contract.detections == 0 and GameFlow.find(level).state == GameStateMachine.State.PLAYING,
		"Running, glass, T1, bottles and alarms never investigate, chase or catch in editing")
	await _pose(Vector3(34.3,4.5,27), level.get_node("Interactables/EscapeWindow"))
	check(level.get_node("Interactables/EscapeWindow").interact(player) and contract_ui._is_result,
		"Existing rope escape and result sheet work with an empty guard group")
	old_id = level.get_instance_id()
	contract_ui.restart_button.pressed.emit()
	await _wait_reload(old_id, "Result Play Again")
	old_id = level.get_instance_id()
	level.get_node("StealthDirector").reset_level()
	await _wait_reload(old_id, "StealthDirector reset")
	current_scene = null
	level.free()
	await frames(3)
	level = load(SCENE).instantiate()
	root.add_child(level)
	current_scene = level
	await frames(12)
	check(not level.disable_guards_for_editing and get_nodes_in_group("guards").size() == 9,
		"Opening the main scene after editing restores all nine guards")
	check(get_nodes_in_group("noise_listeners").size() == 9 \
		and NavigationServer3D.map_get_agents(level.get_world_3d().navigation_map).size() == 9,
		"Main scene retains guard hearing and navigation agents")
	for name in ["Guard_G3", "Guard_G6"]:
		var guard := level.get_node(name) as Guard
		var sight_matches_state := not guard.vision.is_physics_processing() if name == "Guard_G3" else guard.vision.is_physics_processing()
		check(guard.is_physics_processing() and guard.machine != null \
			and guard.hearing.is_physics_processing() and sight_matches_state \
			and guard.is_connected(&"notice", Callable(level, "_on_guard_notice")),
			"Normal guard remains active and connected: " + name)
	var sleeper = level.get_node("Guard_G3")
	check(sleeper.phase == &"sleeping", "Main G3 still starts asleep, with sight off")
	level.get_node("NoiseSystem").emit_noise(sleeper.global_position+Vector3.UP*1.25,
		NoiseEvent.Type.INTERACTION, "environment", 1.0, 4.0, 1.0)
	await frames(15)
	check(sleeper.wake_count == 1 and sleeper.phase == &"observing" and sleeper.vision.is_physics_processing(),
		"Main G3 still wakes from real noise after visiting editing mode")
	check(not level.has_node("EditingNotice"), "Main gameplay has no editing overlay")
	for sound in level.find_children("*", "AudioStreamPlayer3D", true, false):
		sound.stop()
		sound.stream = null
	current_scene = null
	level.free()
	await process_frame
	print("Editing mode verification: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
