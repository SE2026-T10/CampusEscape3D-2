extends SceneTree

const SCENE := "res://maps/isg_museum/scenes/museum.tscn"
var level: Node3D
var guard
var player: FirstPersonPlayer
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool,text: String) -> void:
	checks += 1
	if ok:
		print("PASS: ",text)
	else:
		failures += 1
		push_error(text)


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func until(predicate: Callable,count := 2400) -> bool:
	for i in count:
		if predicate.call():
			return true
		await physics_frame
	return predicate.call()


func fresh() -> void:
	paused = false
	if is_instance_valid(level):
		current_scene = null
		level.free()
		await frames(3)
	level = (load(SCENE) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	guard = level.get_node("Guard_G3")
	player = level.get_node("Player")
	player.set_physics_process(false)
	player.get_node("Noise").set_physics_process(false)
	for actor: Guard in get_nodes_in_group("guards"):
		if actor == guard:
			continue
		actor.set_physics_process(false)
		actor.agent.avoidance_enabled = false
		actor.vision.set_physics_process(false)
		actor.vision.reset()
		actor.hearing.set_physics_process(false)
		actor.get_node("Presentation").process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("StealthDirector").set_physics_process(false)
	await frames(20)


func noise(kind: NoiseEvent.Type,at: Vector3,intensity := -1.0,radius := -1.0) -> void:
	level.get_node("NoiseSystem").emit_noise(at,kind,"environment",intensity,radius)
	await frames(8)


func aim(target: Node3D,feet: Vector3) -> void:
	player.position = feet
	player.velocity = Vector3.ZERO
	player.camera.look_at(target.global_position)
	await frames(4)


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
	await frames(3)


func walk(points: Array) -> bool:
	player.set_physics_process(true)
	for destination: Vector3 in points:
		var reached := false
		for i in 500:
			var offset := destination-player.position
			offset.y = 0
			if offset.length() < 0.15:
				reached = true
				break
			player.rotation.y = atan2(-offset.x,-offset.z)
			Input.action_press("move_forward")
			await physics_frame
		Input.action_release("move_forward")
		if not reached:
			player.set_physics_process(false)
			return false
	await frames(12)
	player.set_physics_process(false)
	return true


func _run() -> void:
	await fresh()
	check(guard.phase == &"sleeping" and guard.is_seated(),"G3 starts asleep and seated")
	check(not guard.vision.is_physics_processing() and not guard._cone.visible,"Sleeping guard has no active sight or visible cone")
	await frames(20)
	check(guard.get_node("Model/Hips").position.y < 0.7,"Guard model actually uses a seated pose")
	player.position = Vector3(33.3,0,12.2)
	await frames(200)
	check(guard.phase == &"sleeping" and not guard.vision.can_see_target,"Player in front of sleeping G3 is not visually detected")
	await noise(NoiseEvent.Type.WALK,Vector3(34,0,11))
	check(guard.phase == &"sleeping","Ordinary walking noise does not wake G3")
	await noise(NoiseEvent.Type.RUN,Vector3(18,0,35))
	check(guard.phase == &"sleeping","Out-of-range loud noise cannot wake G3")
	player.position = Vector3(18,0.1,35)
	await noise(NoiseEvent.Type.RUN,Vector3(33,0,12))
	check(guard.phase == &"observing" and guard.is_seated() and guard.wake_count == 1,"Nearby loud noise wakes G3 without standing or instantly searching")
	check(guard.vision.is_physics_processing() and guard._cone.visible,"Awake guard enables real vision and visible cone")
	check(not guard.vision.has_last_known_position and guard.machine.current == GuardStateMachine.PATROL,"Noise does not invent a player sighting or immediate chase")
	level.get_node("GameFlow").pause()
	var held_timer: float = guard._rest_left
	await frames(120)
	check(is_equal_approx(held_timer,guard._rest_left),"Pause freezes G3 observation timer")
	level.get_node("GameFlow").resume()
	check(await until(func(): return guard.phase == &"sleeping",600),"No sighting after wake leads back to sleep")
	var interior := level.get_node("NavigationRegion3D/Geometry/StaffInterior")
	check(not interior.has_node("FilingCabinet"),"Obsolete tall cabinet is removed from room centre")
	check(interior.get_node("Desk").position.is_equal_approx(Vector3(32.2,0.55,12)),"Desk A is north-south in right half of room")
	check(level.get_node("Interactables/Key").position.is_equal_approx(Vector3(34.95,1.2,10.2)),"Key is on locker D instead of desk A")
	await noise(NoiseEvent.Type.RUN,Vector3(33.8,0,10.6))
	check(guard.phase == &"observing","Desk visibility fixture wakes G3 through a clear sound path")
	player.position = Vector3(30.5,0,12)
	player.set_crouching(true)
	player.head.position.y = player.crouch_eye_height
	guard.face_yaw(PI/2)
	await frames(30)
	check(not guard.vision.can_see_target,"Solid desk A actually hides crouched player from awake G3")
	player.set_crouching(false)
	player.head.position.y = player.stand_eye_height
	await frames(6)
	check(guard.vision.can_see_target,"Standing behind the same desk exposes player head")
	player.position = Vector3(18,0.1,35)
	await until(func(): return guard.phase == &"sleeping",600)
	# Safe route follows E -> C -> north end of A -> D, avoiding F.
	level.get_node("NavigationRegion3D/Doors/Staff").interact(player)
	player.position = Vector3(25.5,0,10)
	check(await walk([Vector3(28.5,0,10),Vector3(28.5,0,16),Vector3(29,0,16),Vector3(29,0,8),Vector3(34,0,8),Vector3(34,0,10.2)]),"Actual Player follows safe A-H concept route to locker D")
	check(guard.phase == &"sleeping","Safe route does not wake G3")
	var key := level.get_node("Interactables/Key") as Interactable
	await aim(key,Vector3(34,0,10.2))
	check(player.get_node("Interactor").find_target() == key,"New key position is reachable by camera")
	await press_e()
	check(level.get_node("ObjectiveManager").is_completed(&"take_key") and guard.phase == &"sleeping","Taking K quietly completes objective without waking G3")
	var board := level.get_node("NavigationRegion3D/Geometry/StaffInterior/MaintenanceBoard")
	await aim(board,Vector3(28.7,0,16))
	await press_e()
	var reader := level.get_node("StaffReader")
	check(reader.panel.visible and reader.body.text.contains("14/03"),"E opens readable maintenance dates")
	check(not paused,"Reading keeps world running")
	var real_clock: Callable = board.time_provider
	var fake_now := {"day":31,"month":12,"year":2026,"hour":23,"minute":59,"second":59,"weekday":4}
	board.time_provider = func(): return fake_now
	board.refresh_clock()
	await frames(65)
	check(reader.body.text.contains("31/12/2026") and reader.body.text.contains("23:59:59"),"Calendar sheet shows live clock while remaining open")
	fake_now.merge({"day":1,"month":1,"year":2027,"hour":0,"minute":0,"second":0,"weekday":5},true)
	await frames(65)
	check(reader.body.text.contains("01/01/2027") and reader.body.text.contains("00:00:00")
		and board.get_node("Text").text.contains("01/01/2027"),"Live calendar rolls over day, month and year on wall and reading sheet")
	check(reader.body.text.contains("14/03"),"Real-time calendar never changes maintenance date used by puzzle")
	board.time_provider = real_clock
	board.refresh_clock()
	await press_e()
	check(not reader.panel.visible,"E closes document without immediately reopening it")
	var note := level.get_node("NavigationRegion3D/Geometry/StaffInterior/CodeNote")
	check(note.position.is_equal_approx(Vector3(32.2,1.112,11)) and note.scale.x < 0.3,"G is a small loose paper on desk instead of wall")
	await aim(note,Vector3(30.6,0,11))
	await press_e()
	check(reader.panel.visible and reader.body.text.contains("DDMM"),"Code note explains day/month puzzle")
	check(reader.panel.get_global_rect().get_center().distance_to(root.get_visible_rect().get_center()) < 2
		and root.get_visible_rect().encloses(reader.panel.get_global_rect()),
		"Paper reading sheet is centred on viewport")
	await press_e()
	var logbook := level.get_node("NavigationRegion3D/Geometry/StaffInterior/ShiftLog")
	await aim(logbook,Vector3(30.6,0,12.4))
	await press_e()
	check(reader.panel.visible and reader.heading.text.contains("Sổ"),"Desk logbook is reachable and readable")
	var close_event := InputEventAction.new()
	close_event.action = &"pause"
	close_event.pressed = true
	Input.parse_input_event(close_event)
	await process_frame
	close_event = InputEventAction.new()
	close_event.action = &"pause"
	Input.parse_input_event(close_event)
	await process_frame
	check(not reader.panel.visible and not paused,"Escape closes document before opening pause menu")
	# Real trigger contact and NoiseSystem/GuardHearing delivery, not a direct wake call.
	var wakes_before: int = guard.wake_count
	player.position = Vector3(34.7,0,14.9)
	await frames(12)
	check(guard.phase == &"observing" and guard.wake_count == wakes_before+1,"Bumping a visible bottle emits a noise that wakes G3")
	check(level.get_node("NoiseSystem").get_active_events().any(func(e): return e.caption.contains("Chai")),"Bottle noise supplies player-facing sound caption")
	player.position = Vector3(18,0.1,35)
	await until(func(): return guard.phase == &"sleeping",600)
	# A brief genuine sighting becomes investigation rather than instant capture.
	var visited_h: Array[int] = []
	guard.patrol_point_reached.connect(func(index: int): visited_h.append(index))
	await noise(NoiseEvent.Type.RUN,Vector3(33.8,0,13.6))
	player.position = Vector3(33.8,0,13.6)
	guard.face_yaw(3.0)
	check(await until(func(): return guard.phase == &"searching",180),"Actual suspicious sight causes G3 to stand and search")
	check(guard.machine.current == GuardStateMachine.INVESTIGATE and not guard.is_seated(),"Suspicion uses investigation, not immediate red chase")
	player.position = Vector3(18,0.1,35)
	var search_positions: Array[Vector3] = []
	for tick in 1500:
		await physics_frame
		if tick%60 == 0:
			search_positions.append(guard.position)
		if guard.phase == &"sleeping":
			break
	check(search_positions.any(func(p): return p.x < 31),"H search physically passes west side of A")
	check(visited_h == [0,1,2,3,4,5],"G3 physically visits all six H waypoints in order")
	check(guard.phase == &"sleeping" and guard.position.distance_to(Vector3(34.1,0,12)) < 0.15,"Unsuccessful H inspection returns to chair B and sleeps")
	# Fully visible player legitimately raises red alert and can be caught.
	await noise(NoiseEvent.Type.RUN,Vector3(33.8,0,13.6))
	player.position = Vector3(33.8,0,13.6)
	guard.face_yaw(3.0)
	check(await until(func(): return guard.machine.current == GuardStateMachine.CHASE,360),"Confirmed real sight triggers red pursuit")
	check(guard.vision.has_last_known_position,"Chase is backed by an actual last sighting")
	var director := level.get_node("StealthDirector") as StealthDirector
	director.set_physics_process(true)
	var old_id := level.get_instance_id()
	var caught := false
	var reloaded := false
	for tick in 700:
		await physics_frame
		if current_scene != null and current_scene.get_instance_id() != old_id:
			level = current_scene
			guard = level.get_node("Guard_G3")
			reloaded = true
			break
		if director.status == StealthDirector.Status.CAUGHT:
			caught = true
			break
	check(caught,"G3 pursuit can actually catch player")
	# Contract mode keeps the caught summary until the player chooses Restart.
	var result_ui := level.get_node("ContractUI")
	var contract := get_first_node_in_group("museum_contract")
	if caught and contract.last_report.get("rating","") == "caught":
		result_ui.restart_button.pressed.emit()
		for tick in 60:
			await process_frame
			if current_scene != null and current_scene.get_instance_id() != old_id:
				level = current_scene
				guard = level.get_node("Guard_G3")
				reloaded = true
				break
	await frames(12)
	check(reloaded and guard.phase == &"sleeping" and level.get_node("Interactables/Key").visible
		and not level.get_node("ObjectiveManager").is_completed(&"take_key"),"Caught reload restores sleeping G3, key and room state")
	await fresh()
	player.position = Vector3(33.8,0,13.5)
	player.rotation.y = PI
	player.get_node("Noise").set_physics_process(true)
	player.set_physics_process(true)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await frames(40)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	player.set_physics_process(false)
	player.get_node("Noise").set_physics_process(false)
	check(guard.wake_count >= 1 and guard.phase != &"sleeping","Actual sprint footsteps from PlayerNoise wake G3")
	player.position = Vector3(18,0.1,35)
	check(await until(func(): return guard.phase == &"sleeping",2400),"G3 settles back to sleep after runner withdraws")
	await noise(NoiseEvent.Type.RUN,Vector3(33.8,0,13.6))
	player.position = Vector3(33.8,0,13.6)
	guard.face_yaw(3.0)
	check(await until(func(): return guard.machine.current == GuardStateMachine.CHASE,360),"Escape fixture reaches genuine red pursuit")
	player.position = Vector3(18,0.1,35)
	check(await until(func(): return guard.phase == &"sleeping",3000),"Losing player during chase leads through search and return to chair, not permanent pursuit")
	guard.position = Vector3(25.5,0,10)
	var staff_door := level.get_node("NavigationRegion3D/Doors/Staff")
	await frames(3)
	if staff_door.is_open:
		staff_door.interact(player)
	guard.return_to_seat()
	check(await until(func(): return guard.phase == &"sleeping",1800) and staff_door.is_open,
		"G3 stranded outside opens its staff door and physically returns to chair")
	# Regression: RUN must be audible across this room, not only beside the chair.
	for start in [Vector3(28.5,0,8),Vector3(28.5,0,12),Vector3(28.5,0,16)]:
		await fresh()
		player.position = start
		player.rotation.y = PI if start.z < 10 else 0.0
		player.velocity = Vector3.ZERO
		player.get_node("Noise").set_physics_process(true)
		player.set_physics_process(true)
		await frames(5)
		Input.action_press("sprint")
		Input.action_press("move_forward")
		await frames(40)
		Input.action_release("sprint")
		Input.action_release("move_forward")
		player.set_physics_process(false)
		player.get_node("Noise").set_physics_process(false)
		check(player.get_node("Noise").steps_emitted > 0 and guard.wake_count > 0,
			"Real sprint in west side of staff room wakes G3: " + str(start))
	await fresh()
	await noise(NoiseEvent.Type.RUN,Vector3(25.5,0,12))
	await noise(NoiseEvent.Type.RUN,Vector3(28.5,4.5,12))
	check(guard.phase == &"sleeping" and is_equal_approx(guard.hearing.sensitivity,1.0)
		and is_equal_approx(guard.hearing.wall_factor,0.5),
		"Same-room sprint boost does not leak through corridor walls or upper floor, and restores listener settings")
	for quiet_mode in ["walk","crouch"]:
		await fresh()
		player.position = Vector3(28.5,0,12)
		player.rotation.y = 0.0
		player.get_node("Noise").set_physics_process(true)
		player.set_physics_process(true)
		await frames(5)
		if quiet_mode == "crouch":
			Input.action_press("crouch")
		Input.action_press("move_forward")
		await frames(40)
		Input.action_release("move_forward")
		Input.action_release("crouch")
		player.set_physics_process(false)
		player.get_node("Noise").set_physics_process(false)
		check(player.get_node("Noise").steps_emitted > 0 and guard.wake_count == 0,
			"Actual quiet movement remains safe for sleeping G3: " + quiet_mode)
	# End audio explicitly before freeing an accelerated physics fixture.
	for audio in level.find_children("*","AudioStreamPlayer3D",true,false):
		audio.stop()
		audio.stream = null
	await frames(5)
	paused = false
	current_scene = null
	level.free()
	await frames(3)
	print("Staff room verification: %d checks, %d failures"%[checks,failures])
	quit(0 if failures == 0 else 1)
