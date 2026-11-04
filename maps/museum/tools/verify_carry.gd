extends SceneTree

## Integration checks for the museum's large T2 transport prototype.
## godot --headless --fixed-fps 60 --path . --script res://maps/museum/tools/verify_carry.gd
const SCENE := "res://maps/museum/scenes/museum.tscn"
const WALL := 0
const CARRIED := 1
const DROPPED := 2
const DELIVERED := 3
var level: Node3D
var player
var painting
var depot
var objectives: ObjectiveManager
var checks := 0
var failures := 0


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
	for tick in count:
		await physics_frame


func isolate() -> void:
	for actor: Guard in get_nodes_in_group("guards"):
		actor.set_physics_process(false)
		actor.agent.avoidance_enabled = false
		actor.velocity = Vector3.ZERO
		actor.vision.set_physics_process(false)
		actor.vision.reset()
		actor.hearing.set_physics_process(false)
		actor.get_node("Presentation").process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("Player").set_physics_process(false)
	level.get_node("Player/Noise").set_physics_process(false)
	level.get_node("StealthDirector").set_physics_process(false)


func bind_level() -> void:
	player = level.get_node("Player")
	painting = level.get_node("Interactables/Painting_T2")
	depot = level.get_node("Interactables/T2Depot")
	objectives = level.get_node("ObjectiveManager")


func fresh() -> void:
	paused = false
	for action in [&"move_forward", &"move_backward", &"move_left", &"move_right", &"sprint", &"crouch"]:
		Input.action_release(action)
	if is_instance_valid(level):
		current_scene = null
		level.free()
		await frames(3)
	level = (load(SCENE) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	isolate()
	bind_level()
	await frames(12)


func pose(feet: Vector3, yaw := 0.0) -> void:
	player.position = feet
	player.rotation = Vector3(0, yaw, 0)
	player.head.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await frames(3)


func aim_at(target: Node3D, feet: Vector3) -> void:
	await pose(feet)
	player.camera.look_at(target.global_position)
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
	await frames(2)


func press_q(echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Q
	event.keycode = KEY_Q
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = KEY_Q
	event.keycode = KEY_Q
	Input.parse_input_event(event)
	await process_frame
	await frames(2)


func take_key() -> void:
	await aim_at(level.get_node("Interactables/Key"), Vector3(34,0,10.2))
	await press_e()
	check(objectives.is_completed(&"take_key"), "Camera E collects staff-room key before T2 transport")


func take_t2() -> void:
	await aim_at(painting, Vector3(33.5,4.5,10))
	check(player.get_node("Interactor").find_target() == painting, "Camera ray selects the large T2 on its wall")
	await press_e()
	check(painting.state == CARRIED and player.carried_painting == painting, "E takes T2 into the player's hands")


func clean_start() -> bool:
	return painting.state == WALL and not player.is_carrying() \
		and painting.visible and painting.enabled and painting.collision_layer == Interactable.LAYER \
		and painting.visual.get_parent() == painting \
		and objectives.completed_count() == 0 \
		and objectives.get_state(&"take_t2") == ObjectiveManager.State.LOCKED \
		and objectives.get_state(&"escape") == ObjectiveManager.State.LOCKED \
		and player.get_target_velocity(Vector2(0,-1),true).length() > 5.0 \
		and player.position.distance_to(Vector3(18,0.1,35)) < 0.12 \
		and not level.get_node("NavigationRegion3D/Doors/Entrance").is_open \
		and not level.get_node("NavigationRegion3D/Doors/RestorationShortcut").is_open


func restart_real_scene() -> void:
	var old_id := level.get_instance_id()
	level.get_node("GameFlow").pause()
	level.get_node("GameMenus").restart_button.pressed.emit()
	var reloaded := false
	for tick in 90:
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != old_id:
			level = current_scene as Node3D
			isolate()
			bind_level()
			await frames(12)
			reloaded = true
			break
	check(reloaded and clean_start(), "Restart restores T2 wall, movement, objectives, exterior spawn and doors")


func move_for_half_second(sprint: bool) -> float:
	await pose(Vector3(32,4.5,17))
	player.set_physics_process(true)
	await frames(3)
	var start: Vector3 = player.position
	Input.action_press(&"move_forward")
	if sprint:
		Input.action_press(&"sprint")
	await frames(30)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	return Vector2(player.position.x-start.x,player.position.z-start.z).length()


func walk_to(destination: Vector3, max_frames := 1600) -> bool:
	# Real controller input and world collision; no teleport through doors or turns.
	player.set_physics_process(true)
	player.head.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	var reached := false
	for tick in max_frames:
		var offset: Vector3 = destination-player.global_position
		offset.y = 0.0
		if offset.length() < 0.14:
			reached = true
			break
		player.rotation.y = atan2(-offset.x,-offset.z)
		Input.action_press(&"move_forward")
		await physics_frame
	Input.action_release(&"move_forward")
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	await frames(3)
	return reached and absf(player.position.y-destination.y) < 0.15


func _run() -> void:
	await fresh()
	check(clean_start(), "T2 begins on the wall with ordinary sprint available and transport locked by K")
	await aim_at(painting, Vector3(33.5,4.5,10))
	await press_e()
	check(painting.state == WALL and not player.is_carrying() and not objectives.is_completed(&"take_t2"),
		"Without K, E cannot take or complete transport of T2")
	await aim_at(depot, Vector3(32,4.5,27.5))
	await press_e()
	check(not objectives.is_completed(&"take_t2") and painting.state == WALL, "Empty-handed depot interaction cannot fabricate a delivery")
	await take_key()
	player.velocity = Vector3(5.5,0,0)
	# Set up a real interaction; preserve a sprint velocity until the E press.
	await aim_at(painting, Vector3(33.5,4.5,10))
	player.velocity = Vector3(5.5,0,0)
	await press_e()
	check(painting.state == CARRIED and player.is_carrying(), "T2 becomes a carried world item after K")
	check(not objectives.is_completed(&"take_t2") and objectives.get_state(&"escape") == ObjectiveManager.State.LOCKED,
		"Initial T2 pickup does not complete transport or unlock escape")
	check(Vector2(player.velocity.x,player.velocity.z).length() <= player.carry_walk_speed+0.01,
		"Taking T2 immediately removes residual sprint momentum")
	check(painting.visual.get_parent() == player.camera \
		and painting.visual.is_visible_in_tree() and painting.collision_layer == 0 and not painting.enabled,
		"Held T2 is visible under the camera and cannot intercept further E rays")
	check(level.get_node("CarryHud/CarryStatus").visible \
		and level.get_node("CarryHud/CarryStatus/Instructions").text.contains("Q:"),
		"Persistent carry HUD explains the drop control while T2 is held")
	check(not painting.interact(player), "Repeated E cannot create a second held T2")
	var slow: Vector3 = player.get_target_velocity(Vector2(0,-1),false)
	var shift: Vector3 = player.get_target_velocity(Vector2(0,-1),true)
	check(is_equal_approx(slow.length(),player.carry_walk_speed) and slow.is_equal_approx(shift) and slow.length() < player.walk_speed,
		"Carrying slows walking and Shift does not increase target speed")
	check(player.get_target_velocity(Vector2(1,-1),true).length() <= player.carry_walk_speed+0.001 \
		and is_equal_approx(player.get_target_velocity(Vector2(0,1),true).length(),player.carry_walk_speed),
		"Carry speed cap also applies to diagonals and walking backward")
	player.set_crouching(true)
	check(is_equal_approx(player.get_target_velocity(Vector2(0,-1),true).length(),player.carry_crouch_speed),
		"Crouching remains available at a lower carry speed")
	player.set_crouching(false)
	var walked := await move_for_half_second(false)
	var sprinted := await move_for_half_second(true)
	check(walked > 0.7 and walked < 1.1 and absf(walked-sprinted) < 0.04,
		"Actual W/Shift movement covers the same short distance while carrying")
	check(not player.stamina.is_sprinting, "Carrying never reports sprinting in the stamina state")
	player.stamina.enabled = true
	player.stamina.stamina = 55.0
	var sprint_time: float = player.stamina.sprint_time
	await move_for_half_second(true)
	check(player.stamina.stamina >= 55.0 and is_equal_approx(player.stamina.sprint_time,sprint_time) \
		and not player.stamina.is_sprinting, "Holding Shift with enabled stamina cannot consume sprint energy while carrying")
	player.stamina.enabled = false
	await pose(Vector3(32,4.5,16))
	await press_q(true)
	check(painting.state == CARRIED, "Repeated keyboard Q events cannot accidentally drop the painting")
	await press_q()
	check(painting.state == DROPPED and not player.is_carrying() \
		and painting.visible and painting.enabled and painting.collision_layer == Interactable.LAYER,
		"Q places T2 safely on clear floor and makes it available to pick up again")
	check(painting.visual.get_parent() == painting and not objectives.is_completed(&"take_t2"),
		"Dropped T2 remains one visible world object and transport stays unfinished")
	check(player.get_target_velocity(Vector2(0,-1),true).length() > 5.0, "Putting T2 down restores ordinary sprint speed")
	check(not level.get_node("CarryHud/CarryStatus").visible, "Putting T2 down clears the persistent carry HUD")
	var dropped_at: Vector3 = painting.global_position
	await aim_at(painting, Vector3(32,4.5,16))
	check(player.get_node("Interactor").find_target() == painting, "Camera ray can reacquire the dropped painting")
	await press_e()
	check(painting.state == CARRIED and player.is_carrying() and not painting.global_position.is_equal_approx(Vector3.ZERO),
		"E picks up the same dropped T2 for another transport attempt")
	check(not objectives.is_completed(&"take_t2") and dropped_at.y > 4.5, "Regrabbing T2 does not complete its delivery")
	# Safeguards must preserve the held object on failure rather than lose it.
	var unsafe_positions := [
		[Vector3(35.4,4.5,13),-PI/2.0,"outer wall"],
		[Vector3(32,4.5,17.4),PI,"closed shortcut"],
		[Vector3(18,4.5,8),PI,"courtyard railing and opening"],
		[Vector3(5,0.9,28.25),PI/2.0,"sloping stair flight"],
		[Vector3(32,4.5,14.5),0.0,"gallery plinth"],
	]
	for sample in unsafe_positions:
		await pose(sample[0],sample[1])
		check(not painting.try_drop() and painting.state == CARRIED and player.is_carrying(),
			"Unsafe drop at " + sample[2] + " is refused while T2 remains in hand")
	await pose(Vector3(32,4.5,16))
	player.set_crouching(true)
	player.head.position.y = player.crouch_eye_height
	check(painting.try_drop() and painting.state == DROPPED, "Crouched player can put T2 on flat floor")
	player.set_crouching(false)
	player.head.position.y = player.stand_eye_height
	await aim_at(painting,Vector3(32,4.5,16))
	await press_e()
	check(painting.state == CARRIED, "A painting dropped while crouched is reachable again while standing")
	var shortcut = level.get_node("NavigationRegion3D/Doors/RestorationShortcut")
	await aim_at(shortcut,Vector3(32,4.5,16.5))
	player.camera.look_at(shortcut.global_position+Vector3(0,1.4,0))
	await frames(3)
	check(player.get_node("Interactor").find_target() == shortcut, "Held T2 leaves the shortcut latch reachable by the camera E ray")
	await press_e()
	check(shortcut.is_open and shortcut.get_node("Panel").collision_layer == 0 \
		and shortcut.get_node("Passage").enabled and player.is_carrying(),
		"Player can open the B-to-store shortcut while carrying T2")
	await pose(Vector3(32,4.5,16.5),PI)
	player.set_physics_process(true)
	Input.action_press(&"move_forward")
	await frames(120)
	Input.action_release(&"move_forward")
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	check(player.position.z > 19.5 and absf(player.position.y-4.5) < 0.15 and player.is_carrying(),
		"Carrying player physically walks through the opened shortcut into restoration room")
	check(not depot.interact(player) and not objectives.is_completed(&"take_t2"), "Depot cannot accept T2 remotely from another room")
	await aim_at(depot,Vector3(32,4.5,27.5))
	check(player.get_node("Interactor").find_target() == depot, "Depot remains selectable with T2 visible in front of the camera")
	await frames(12)
	check(painting.state == CARRIED and not objectives.is_completed(&"take_t2"), "Standing at depot still requires an explicit E delivery")
	await press_e()
	check(painting.state == DELIVERED and objectives.is_completed(&"take_t2") and not player.is_carrying(),
		"Depot E completes transport exactly when T2 is delivered")
	check(painting.visual.get_parent() == painting and painting.is_visible_in_tree() \
		and painting.global_position.distance_to(depot.global_position) < 2.0 and not painting.enabled and painting.collision_layer == 0,
		"Delivered T2 remains visibly staged at the depot and cannot be removed")
	check(not painting.interact(player) and not depot.interact(player), "Delivered T2 cannot be taken or credited twice")
	check(player.get_target_velocity(Vector2(0,-1),true).length() > 5.0, "Delivery restores normal sprinting immediately")
	check(not objectives.is_finished() and objectives.get_state(&"escape") == ObjectiveManager.State.LOCKED,
		"Delivering T2 alone does not end the level or bypass the other artworks and rope")
	await restart_real_scene()
	# Carrying must not bypass escape when every other required item was collected.
	await take_key()
	await take_t2()
	var carry_pose: Vector3 = player.position
	player.position = Vector3(25.5,0,21)
	level.get_node("NavigationRegion3D/Doors/Storage").submit_code("1403",player)
	player.position = carry_pose
	for name in ["Painting_T1","Painting_T3","Rope"]:
		level.get_node("Interactables/"+name).interact(player)
	var exit = level.get_node("Interactables/EscapeWindow")
	check(not exit.interact(player) and not objectives.is_finished() and not objectives.is_completed(&"take_t2"),
		"All other items plus T2 in hand still cannot escape before depot delivery")
	check(level.get_node("Interactables/Painting_T1").is_artwork_missing() \
		and not level.get_node("Interactables/Painting_T3").visible,
		"T1 retains its empty frame and T3 remains an ordinary immediate pickup")
	await restart_real_scene()
	# Verify full scene restoration from both transient transport states.
	await take_key()
	await take_t2()
	await restart_real_scene()
	await take_key()
	await take_t2()
	await pose(Vector3(32,4.5,16))
	check(painting.try_drop(), "Restart fixture leaves T2 on a valid floor position")
	await restart_real_scene()
	# Keep the latch closed and transport through the longer ring-hall route.
	await take_key()
	await take_t2()
	var gallery_door = level.get_node("NavigationRegion3D/Doors/GalleryB")
	check(await walk_to(Vector3(28.5,4.5,10)), "Carrying player walks across B to the gallery door")
	player.camera.look_at(gallery_door.global_position+Vector3(0,1.4,0))
	await frames(3)
	await press_e()
	check(gallery_door.is_open and not level.get_node("NavigationRegion3D/Doors/RestorationShortcut").is_open \
		and player.is_carrying(), "Gallery door can open with K while carrying, leaving the shortcut latched")
	var long_route := [Vector3(25.5,4.5,10),Vector3(25.5,4.5,22.5),Vector3(18,4.5,22.5),
		Vector3(18,4.5,27),Vector3(25.5,4.5,27),Vector3(28,4.5,27),Vector3(32,4.5,27.5)]
	var followed_route := true
	for destination in long_route:
		if destination.is_equal_approx(Vector3(28,4.5,27)):
			var south_entry = level.get_node("NavigationRegion3D/Doors/RestorationEntrance")
			player.camera.look_at(south_entry.global_position+Vector3(0,1.4,0))
			await frames(3)
			await press_e()
			check(south_entry.is_open and player.is_carrying(),"Carrying player opens new south restoration door with E")
		var reached: bool = await walk_to(destination)
		followed_route = reached and followed_route
	check(followed_route and player.is_carrying() \
		and not level.get_node("NavigationRegion3D/Doors/RestorationShortcut").is_open,
		"Real carry movement follows the longer ring hall and free southern store entrance without opening the shortcut")
	player.camera.look_at(depot.global_position+Vector3(0,0.65,0))
	await frames(3)
	await press_e()
	check(painting.state == DELIVERED and objectives.is_completed(&"take_t2"),
		"Long-route T2 delivery succeeds with the B-to-store latch still closed")
	# Direct calls and input must both obey gameplay state, even without processing.
	for blocked_state in [GameStateMachine.State.PAUSED,GameStateMachine.State.CAUGHT,GameStateMachine.State.WIN]:
		await fresh()
		await take_key()
		await take_t2()
		await aim_at(depot,Vector3(32,4.5,27.5))
		level.get_node("GameFlow").machine.request(blocked_state)
		await press_q()
		await press_e()
		check(painting.state == CARRIED and not painting.try_drop() and not depot.interact(player) \
			and not objectives.is_completed(&"take_t2") and not level.get_node("CarryHud/CarryStatus").visible,
			"Transport and delivery are blocked and carry HUD hides in gameplay state " + str(blocked_state))
		paused = false
	# A natural guard catch while holding T2 must reload all world and carry state.
	await fresh()
	await take_key()
	await take_t2()
	await pose(Vector3(7,0,13))
	var guard := level.get_node("Guard_G1") as Guard
	guard.position = Vector3(7,0,10.5)
	guard.rotation.y = PI
	guard.vision.reset()
	guard.stop_moving()
	guard.face_yaw(PI)
	var patrol := guard.machine.get_state(GuardStateMachine.PATROL) as PatrolState
	patrol.waiting = true
	patrol.wait_left = 5.0
	guard.set_physics_process(true)
	guard.vision.set_physics_process(true)
	var director := level.get_node("StealthDirector") as StealthDirector
	director.set_physics_process(true)
	var old_id := level.get_instance_id()
	var caught := false
	var reloaded := false
	for tick in 700:
		await physics_frame
		if current_scene != null and current_scene.get_instance_id() != old_id:
			level = current_scene as Node3D
			isolate()
			bind_level()
			await frames(12)
			reloaded = true
			break
		if is_instance_valid(director) and director.status == StealthDirector.Status.CAUGHT:
			caught = level.get_node("GameFlow").state == GameStateMachine.State.CAUGHT
	check(caught, "Real guard sight, chase and capture still catch a player carrying T2")
	check(reloaded and clean_start(), "Caught delay fully restores T2, movement, objectives and exterior starting state")
	paused = false
	current_scene = null
	level.free()
	await frames(3)
	print("Museum carry verification: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
