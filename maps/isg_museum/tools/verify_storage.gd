extends "res://maps/isg_museum/tools/verify_blockout.gd"

## Real camera input, keypad, physical traversal, hearing, sight and reset.
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
	await frames(4)


func type_code(value: String) -> void:
	for character in value:
		var event := InputEventKey.new()
		event.keycode = character.unicode_at(0)
		event.unicode = character.unicode_at(0)
		event.pressed = true
		Input.parse_input_event(event)
		await frames(2)
		var release := InputEventKey.new()
		release.keycode = character.unicode_at(0)
		Input.parse_input_event(release)
		await frames(2)
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await frames(2)
	var release_enter := InputEventKey.new()
	release_enter.keycode = KEY_ENTER
	Input.parse_input_event(release_enter)
	await frames(5)


func _run() -> void:
	level = load(SCENE).instantiate()
	root.add_child(level)
	current_scene = level
	var player = level.get_node("Player")
	for guard: Guard in get_nodes_in_group("guards"):
		guard.set_physics_process(false)
		guard.agent.avoidance_enabled = false
		guard.vision.set_physics_process(false)
		guard.vision.reset()
		guard.hearing.set_physics_process(false)
		guard.get_node("Presentation").process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("StealthDirector").set_physics_process(false)
	player.set_physics_process(false)
	player.get_node("Noise").set_physics_process(false)
	await frames(20)
	var door = level.get_node("NavigationRegion3D/Doors/Storage")
	var ui = door.keypad
	var rope = level.get_node("Interactables/Rope")
	var manager: ObjectiveManager = level.get_node("ObjectiveManager")
	var flow: GameFlow = level.get_node("GameFlow")
	check(not door.unlocked and not door.is_open and not ui.visible,"Storage starts locked with keypad hidden")
	check(rope.position.y < 2 and rope.position.x > 35,"Only rope pickup has moved to ground-floor east rack")
	check(not rope.interact(player) and not manager.is_completed(&"take_rope"),"Locked storage does not allow collecting rope")
	check(not connected(Vector3(25.5,.1,21),Vector3(33.9,.1,20.6)),"Closed storage has no traversable nav connection")
	await push_against_door(player,Vector3(25.5,0,21),-PI/2)
	check(player.position.x < 26.7,"Locked panel physically blocks player")
	player.position = Vector3(25.4,0,19.9)
	player.camera.look_at(Vector3(26.72,1.45,19.9))
	await frames(5)
	check(player.get_node("Interactor").find_target() == door,"Physical wall keypad is selectable before the wall collider")
	await press_e()
	check(ui.visible and not door.unlocked,"E on wall keypad opens the same code interface")
	await press_e()
	await use_door(door,Vector3(25.5,0,21))
	check(ui.visible and player.keypad_active and not paused and not door.unlocked,"Camera E opens keypad without unlocking or pausing")
	await frames(5)
	check(ui.panel.get_global_rect().get_center().distance_to(root.get_visible_rect().get_center()) < 2
		and root.get_visible_rect().encloses(ui.panel.get_global_rect()),"Keypad fits centred in viewport")
	var at: Vector3 = player.position
	var time_before: float = level.get_node("NoiseSystem").now
	player.set_physics_process(true)
	Input.action_press("move_forward")
	await frames(60)
	Input.action_release("move_forward")
	player.set_physics_process(false)
	check(Vector2(player.position.x-at.x,player.position.z-at.z).length() < .02,"Movement input does not walk player away while entering code")
	check(level.get_node("NoiseSystem").now > time_before+.5,"World simulation continues during keypad use")
	ui._button("1")
	ui._button("Mở")
	check(not door.unlocked and door.wrong_attempts == 0,"Incomplete code cannot unlock or consume a failed attempt")
	ui._button("Xóa")
	var watcher: Guard = level.get_node("Guard_G4")
	watcher.position = Vector3(25.5,0,22.5)
	watcher.hearing.set_physics_process(true)
	var before_reports := watcher.hearing.reported_count
	await type_code("0000")
	check(not door.unlocked and door.wrong_attempts == 1 and ui.digits.is_empty(),"Wrong typed code leaves collision locked and clears entry")
	await frames(70)
	await type_code("9999")
	await frames(70)
	check(door.alarm_count == 0,"Two wrong codes do not trigger the loud alarm")
	await type_code("2222")
	await frames(8)
	check(door.alarm_count == 1 and not door.is_open,"Third wrong code emits alarm without opening door")
	check(watcher.hearing.reported_count > before_reports and watcher.hearing.has_report,
		"Nearby guard receives real keypad noise through NoiseSystem and hearing")
	check(ui.visible and ui.message.text.contains("Cảnh báo"),"Alarm leaves keypad available for retry")
	await press_e()
	check(not ui.visible and not player.keypad_active and not door.unlocked,"E cancels code entry without opening door")
	await use_door(door,Vector3(25.5,0,21))
	flow.pause()
	check(not ui.visible and not player.keypad_active,"Pause closes keypad and releases player control lock")
	flow.resume()
	await use_door(door,Vector3(25.5,0,21))
	await type_code(door.current_code())
	check(door.unlocked and door.is_open and not ui.visible and not player.keypad_active,"Correct keyboard code unlocks, opens and returns to play")
	check(door.get_node("Panel").collision_layer == 0 and door.get_node("Passage").enabled,"Unlock removes physical panel and enables nav link")
	await frames(6)
	check(connected(Vector3(25.5,.1,21),Vector3(33.9,.1,20.6)),"Open storage connects corridor navigation to rope")
	check(await walk(player,[Vector3(28.5,0,21),Vector3(33.9,0,20.6)]),"Actual player walks through door and around furniture to rope")
	player.camera.look_at(rope.global_position)
	await frames(5)
	check(player.get_node("Interactor").find_target() == rope,"Camera ray can select coiled rope on rack")
	await press_e()
	check(manager.is_completed(&"take_rope") and not rope.visible and rope.collision_layer == 0,"E collects rope and completes mission")
	check(level.get_node("NavigationRegion3D/Geometry/StorageInterior/RopeRack").visible,"Empty rope rack remains after collection")
	check(not rope.interact(player),"Rope cannot be collected twice")
	check(await walk(player,[Vector3(34.4,0,21),Vector3(34.4,0,22.4),Vector3(32,0,22.4)]),"Player can walk in front of cabinet placed against south wall")
	watcher.hearing.set_physics_process(false)
	watcher.position = Vector3(25.5,0,21)
	watcher.rotation.y = atan2(-(player.position.x-watcher.position.x),-(player.position.z-watcher.position.z))
	watcher.vision.set_physics_process(true)
	watcher.vision.reset()
	await frames(8)
	check(level.get_node("NavigationRegion3D/Geometry/StorageInterior/SteelCabinet").position.z > 23.5,"Cabinet sits flush against south wall")
	player.position = Vector3(29,0,21)
	watcher.rotation.y = -PI/2
	await frames(8)
	check(watcher.vision.can_see_target,"Open doorway exposes player in central aisle")
	watcher.vision.set_physics_process(false)
	watcher.vision.reset()
	await use_door(door,Vector3(28.5,0,21))
	check(not door.is_open and door.unlocked and door.get_node("Panel").collision_layer == 1,"E closes storage from inside while retaining solved code")
	await use_door(door,Vector3(28.5,0,21))
	check(door.is_open and not ui.visible,"Solved door reopens without requiring code again")
	player.position = Vector3(27,0,21)
	await frames(4)
	check(not door.interact(player) and door.is_open,"Storage cannot close through player in doorway")
	flow.pause()
	level.get_node("GameMenus").restart_button.pressed.emit()
	for i in 40:
		await process_frame
		if current_scene != null and current_scene != level:
			level = current_scene
			break
	door = level.get_node("NavigationRegion3D/Doors/Storage")
	rope = level.get_node("Interactables/Rope")
	await frames(20)
	check(not door.unlocked and not door.is_open and rope.visible and rope.enabled
		and not level.get_node("ObjectiveManager").is_completed(&"take_rope"),"Restart resets code lock and restores rope and objective together")
	print("Storage verification: %d checks, %d failures"%[checks,failures])
	for sound in level.find_children("*","AudioStreamPlayer3D",true,false):
		sound.stop()
		sound.stream = null
	current_scene = null
	level.free()
	await process_frame
	quit(0 if failures == 0 else 1)
