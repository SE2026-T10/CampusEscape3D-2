extends SceneTree

## Integration checks for the T1/G6 empty-frame prototype.
## godot --headless --fixed-fps 60 --path . --script res://maps/isg_museum/tools/verify_empty_frame.gd
const SCENE := "res://maps/isg_museum/scenes/museum.tscn"
var level: Node3D
var inspector
var painting
var checks := 0
var failures := 0
var notices: Array[String] = []
var discoveries := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, caption: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", caption)
	else:
		failures += 1
		push_error(caption)


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func until(predicate: Callable, limit := 12000) -> bool:
	for tick in limit:
		if predicate.call():
			return true
		await physics_frame
	return predicate.call()


func phase() -> StringName:
	return inspector.get("inspection_phase")


func isolate() -> void:
	level.get_node("Player").set_physics_process(false)
	level.get_node("Player/Noise").set_physics_process(false)
	level.get_node("StealthDirector").set_physics_process(false)
	for actor: Guard in get_nodes_in_group("guards"):
		actor.set_physics_process(false)
		actor.agent.avoidance_enabled = false
		actor.velocity = Vector3.ZERO
		actor.vision.set_physics_process(false)
		actor.vision.reset()
		actor.hearing.set_physics_process(false)
		actor.get_node("Presentation").process_mode = Node.PROCESS_MODE_DISABLED


func fresh() -> void:
	paused = false
	if is_instance_valid(level):
		current_scene = null
		level.free()
		await frames(3)
	level = (load(SCENE) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	isolate()
	inspector = level.get_node("Guard_G6")
	painting = level.get_node("Interactables/Painting_T1")
	notices.clear()
	discoveries = 0
	inspector.artwork_discovered.connect(func(): discoveries += 1)
	inspector.notice.connect(func(caption: String): notices.append(caption))
	await frames(12)


func pose(at: Vector3, facing_frame := true) -> void:
	inspector.position = at
	inspector.velocity = Vector3.ZERO
	var offset: Vector3 = painting.position-at
	inspector.rotation.y = atan2(-offset.x,-offset.z) + (0.0 if facing_frame else PI)
	await frames(3)


func press_e() -> void:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = &"interact"
	Input.parse_input_event(event)
	await process_frame


func collect_t1() -> void:
	var player := level.get_node("Player") as FirstPersonPlayer
	player.position = painting.global_position+Vector3(1.47,-1.5,0)
	player.camera.look_at(painting.global_position)
	await frames(3)
	check(player.get_node("Interactor").find_target() == painting, "Camera ray reaches T1 on its wall")
	await press_e()
	player.position = player.get_spawn_transform().origin


func start_at_inspection() -> void:
	var actor := inspector as Guard
	actor.reset_to_start()
	var route := actor.patrol_route
	var index := -1
	for i in route.get_point_count():
		if route.get_child(i).name == "Inspect_T1":
			index = i
			break
	check(index >= 0, "G6 route contains a real Inspect_T1 patrol stop")
	if index < 0:
		return
	var at := route.get_point_position(index)
	await pose(Vector3(at.x,4.5,at.z))
	var patrol := actor.machine.get_state(GuardStateMachine.PATROL) as PatrolState
	patrol.current_point = index
	patrol.waiting = false
	actor.navigate_to(at,actor.patrol_speed)
	actor.set_physics_process(true)


func _run() -> void:
	await fresh()
	check(not painting.is_artwork_missing() and painting.get_node("Canvas").visible
		and painting.get_node("Frame").visible, "T1 initially contains a canvas and persistent frame")
	await pose(Vector3(2.25,4.5,12))
	check(inspector.can_see_frame(), "G6 can see the frame from the west gallery aisle")
	await pose(Vector3(2.25,4.5,12),false)
	check(not inspector.can_see_frame(), "A frame behind G6 is outside its vision cone")
	await pose(Vector3(2.25,4.5,21))
	check(not inspector.can_see_frame(), "A frame beyond inspection sight range is not visible")
	await pose(Vector3(2.25,0,12))
	check(not inspector.can_see_frame(), "G6 cannot inspect the upper frame from the lower floor")
	await pose(Vector3(2.25,4.5,12))
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	blocker.position = Vector3(1.3,6,12)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2,3,3)
	collision.shape = shape
	blocker.add_child(collision)
	level.add_child(blocker)
	await frames(3)
	check(not inspector.can_see_frame(), "World collision blocks G6's line of sight to the frame")
	blocker.free()
	await frames(3)
	check(inspector.can_see_frame(), "Removing an occluder restores actual frame line of sight")
	# An intact painting is inspected during the normal patrol, without an alarm.
	await fresh()
	inspector.set_physics_process(true)
	check(await until(func(): return phase() == &"inspection"), "G6 naturally reaches its scheduled intact-painting inspection")
	check(inspector.inspection_visits >= 1 and not inspector.discovery_reported
		and inspector.machine.current == GuardStateMachine.PATROL, "Intact-frame inspection stays on PATROL and reports no missing art")
	var flow := level.get_node("GameFlow") as GameFlow
	var held_position: Vector3 = inspector.position
	var held_time: float = inspector.machine.time_in_state
	flow.pause()
	await frames(180)
	check(phase() == &"inspection" and inspector.position.distance_to(held_position) < 0.01
		and is_equal_approx(inspector.machine.time_in_state,held_time), "Pause freezes inspection timers and guard movement")
	flow.resume()
	check(await until(func(): return phase() == &"patrol",300), "Intact inspection finishes and patrol resumes after unpausing")
	await collect_t1()
	check(painting.is_artwork_missing() and painting.visible and painting.get_node("Frame").visible
		and not painting.get_node("Canvas").visible and painting.collision_layer == 0,
		"Taking T1 removes only canvas and interaction while leaving a visible empty frame")
	check(level.get_node("ObjectiveManager").is_completed(&"take_t1")
		and not painting.interact(level.get_node("Player")), "T1 completes once and cannot be collected twice")
	check(not inspector.discovery_reported and discoveries == 0, "Taking T1 does not remotely notify G6")
	await frames(240)
	check(not inspector.discovery_reported, "Taking T1 just after inspection leaves time to withdraw before next visit")
	check(await until(func(): return phase() == &"checking"), "Next patrol inspection detects the missing canvas after real visual confirmation")
	check(inspector.discovery_reported and inspector.discovery_count == 1 and discoveries == 1,
		"Missing T1 is reported exactly once")
	check(inspector.machine.current == GuardStateMachine.INVESTIGATE
		and not inspector.vision.has_last_known_position and is_zero_approx(inspector.vision.detection),
		"Frame evidence starts investigation without inventing a player sighting or CHASE")
	check(notices.any(func(text: String): return text.contains("G6") and text.contains("thiếu"))
		and level.get_node("ObjectiveHud").get_layout_controls().message.text.contains("G6"),
		"Discovery feedback names G6 and reaches the mission HUD")
	check(inspector.get_node("Speech").visible and inspector.get_node("Speech").text.contains("T1"),
		"G6 displays a readable spoken line about missing T1")
	held_position = inspector.position
	await frames(30)
	check(phase() == &"checking" and inspector.position.distance_to(held_position) < 0.05,
		"G6 stops to examine missing artwork before searching the room")
	flow.pause()
	await frames(180)
	check(phase() == &"checking", "Pause also freezes the missing-art examination")
	flow.resume()
	check(await until(func(): return phase() == &"searching",300), "Missing-art examination leads to a room search")
	var visited := {}
	var room_points := level.get_node("RoomSearch_T1").get_children()
	var legitimate_targets := true
	for tick in 6000:
		if phase() == &"patrol":
			break
		var target: Vector3 = inspector.agent.target_position
		legitimate_targets = legitimate_targets and target.x < 9 and target.z >= 6 and target.z <= 24
		for point in room_points:
			if inspector.position.distance_to(point.global_position) < 0.75:
				visited[point.name] = true
		await physics_frame
	check(legitimate_targets and visited.size() >= 3,
		"G6 physically searches predefined gallery locations, never the unseen player's position")
	check(phase() == &"patrol" and inspector.machine.current == GuardStateMachine.PATROL,
		"Room search ends and G6 returns to its patrol route")
	var visits: int = inspector.inspection_visits
	check(await until(func(): return inspector.inspection_visits > visits), "G6 checks T1 again on a later patrol loop")
	await frames(240)
	check(inspector.discovery_count == 1 and discoveries == 1, "Already-discovered empty frame does not repeatedly alarm or restart search")
	# A missing canvas still cannot be discovered through a world occluder,
	# including during the scheduled inspection that would normally find it.
	await fresh()
	await collect_t1()
	blocker = StaticBody3D.new()
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	blocker.position = Vector3(1.3,6,12)
	collision = CollisionShape3D.new()
	shape = BoxShape3D.new()
	shape.size = Vector3(0.2,3,3)
	collision.shape = shape
	blocker.add_child(collision)
	level.add_child(blocker)
	await frames(3)
	await start_at_inspection()
	check(await until(func(): return phase() == &"inspection",300), "G6 reaches inspection while the empty frame is physically occluded")
	await frames(180)
	check(not inspector.discovery_reported and discoveries == 0,
		"Even a scheduled inspection cannot discover a missing canvas through a wall")
	blocker.free()
	await frames(3)
	await start_at_inspection()
	check(await until(func(): return phase() == &"checking",600),
		"A later unoccluded inspection can legitimately discover the same missing canvas")
	# Real sight of the player takes priority over either stage of frame investigation.
	for interrupt_phase in [&"checking",&"searching"]:
		await fresh()
		await collect_t1()
		await start_at_inspection()
		check(await until(func(): return phase() == interrupt_phase,1200), "Fixture reaches frame phase " + str(interrupt_phase))
		var player := level.get_node("Player") as FirstPersonPlayer
		if interrupt_phase == &"checking":
			player.position = Vector3(1,4.5,12)
		else:
			inspector.rotation.y = 0
			player.position = inspector.position+Vector3(0,0,-1.7)
			player.position.y = 4.5
		inspector.vision.reset()
		inspector.vision.set_physics_process(true)
		check(await until(func(): return inspector.machine.current == GuardStateMachine.CHASE,360),
			"Actual player sight interrupts " + str(interrupt_phase) + " with CHASE")
		check(inspector.vision.has_last_known_position and inspector.vision.can_see_target,
			"CHASE is backed by real player line of sight, not the empty-frame event")
		await frames(90)
		check(inspector.machine.current == GuardStateMachine.CHASE,
			"Frame logic does not override an active chase after " + str(interrupt_phase))
	# Restart the real scene after a discovered frame and active chase.
	var old_id := level.get_instance_id()
	level.get_node("GameFlow").pause()
	level.get_node("GameMenus").restart_button.pressed.emit()
	var reloaded := false
	for tick in 60:
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != old_id:
			level = current_scene as Node3D
			isolate()
			inspector = level.get_node("Guard_G6")
			painting = level.get_node("Interactables/Painting_T1")
			await frames(12)
			reloaded = true
			break
	check(reloaded and not painting.is_artwork_missing() and painting.get_node("Canvas").visible
		and not inspector.discovery_reported and inspector.discovery_count == 0,
		"Restart restores canvas and clears frame discovery/search state")
	check(level.get_node("ObjectiveManager").get_state(&"take_t1") == ObjectiveManager.State.ACTIVE
		and level.get_node("Player").get_spawn_transform().origin.is_equal_approx(Vector3(18,0.1,35))
		and not level.get_node("NavigationRegion3D/Doors/Entrance").is_open,
		"Restart also restores mission, exterior spawn and main entrance")
	paused = false
	current_scene = null
	level.free()
	await frames(3)
	print("Museum empty-frame verification: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
