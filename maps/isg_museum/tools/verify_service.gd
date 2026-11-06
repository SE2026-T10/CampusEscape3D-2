extends SceneTree

class TestContract extends Node:
	var has_ticket := false
	var ticket_scanned := false
	func grant_ticket(): has_ticket = true
	func scan_ticket():
		if not has_ticket: return false
		ticket_scanned = true
		return true

var level: Node3D
var checks := 0
var failures := 0

func _initialize():
	run.call_deferred()

func check(value: bool,caption: String):
	checks += 1
	if value: print("PASS: ",caption)
	else:
		failures += 1
		push_error(caption)

func frames(count: int):
	for i in count: await physics_frame

func press_e():
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := InputEventAction.new()
	release.action = &"interact"
	Input.parse_input_event(release)
	await frames(4)

func walk_to(player: Node3D,target: Vector3) -> bool:
	player.set_physics_process(true)
	for tick in 360:
		var direction := target-player.global_position
		direction.y = 0
		if direction.length() < .14:
			Input.action_release("move_forward")
			await frames(10)
			player.set_physics_process(false)
			return absf(player.position.y-target.y) < .15
		player.rotation.y = atan2(-direction.x,-direction.z)
		Input.action_press("move_forward")
		await physics_frame
	Input.action_release("move_forward")
	player.set_physics_process(false)
	return false

func run():
	level = load("res://maps/isg_museum/scenes/museum.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(8)
	var expansion := level.get_node_or_null("NavigationRegion3D/ServiceExpansion")
	if expansion == null:
		expansion = load("res://maps/isg_museum/scenes/service_expansion.tscn").instantiate()
		level.get_node("NavigationRegion3D").add_child(expansion)
	var contract := get_first_node_in_group("museum_contract")
	if contract == null:
		contract = TestContract.new()
		level.add_child(contract)
		contract.add_to_group("museum_contract")
	for guard: Guard in get_nodes_in_group("guards"):
		guard.set_physics_process(false)
		guard.agent.avoidance_enabled = false
		guard.vision.set_physics_process(false)
		guard.vision.reset()
		guard.hearing.set_physics_process(false)
		guard.get_node("Presentation").process_mode = Node.PROCESS_MODE_DISABLED
	var player := level.get_node("Player")
	player.set_physics_process(false)
	player.get_node("Noise").set_physics_process(false)
	level.get_node("StealthDirector").set_physics_process(false)
	await frames(15)
	var npc := expansion.get_node("Receptionist")
	var ui := expansion.get_node("ServiceUi")
	player.position = Vector3(31.1,0,27)
	player.camera.look_at(npc.global_position)
	await frames(5)
	check(player.get_node("Interactor").find_target() == npc,"Receptionist reachable by actual camera ray above counter")
	await press_e()
	check(ui.visible and ui.mode == "quiz" and player.modal_active and not paused,"E opens service quiz without pausing world")
	await frames(4)
	check(root.get_visible_rect().encloses(ui.panel.get_global_rect()),"Service quiz fits in viewport")
	ui.answers.get_child(1).pressed.emit()
	check(not contract.has_ticket and ui.message.text.contains("áp phích"),"Incorrect answer offers clue and gives no ticket")
	ui.answers.get_child(1).pressed.emit()
	ui.answers.get_child(1).pressed.emit()
	check(ui.cooldown_left > 9 and not contract.has_ticket,"Three wrong answers start temporary cooldown")
	ui.answer(0)
	check(ui.question_index == 0 and not contract.has_ticket,"Cooldown prevents rapid retry")
	await frames(620)
	check(ui.cooldown_left <= 0 and not ui.answers.get_child(0).disabled,"Cooldown expires with no permanent lock")
	ui.answers.get_child(0).pressed.emit()
	ui.answers.get_child(1).pressed.emit()
	check(not contract.has_ticket and ui.question_index == 2,"First two correct answers do not grant ticket early")
	ui.answers.get_child(2).pressed.emit()
	check(contract.has_ticket and not ui.answers.visible,"All three evidence answers grant ticket")
	await press_e()
	check(not ui.visible and not player.modal_active,"E closes quiz and restores player control")
	player.modal_active = true
	check(not ui.open_map(expansion.get_node("WallMap"),player),"Map cannot overlap another modal dialogue")
	player.modal_active = false
	player.keypad_active = true
	check(not ui.open_quiz(npc,player),"Quiz cannot overlap storage keypad")
	player.keypad_active = false
	var door_a := expansion.get_node("TicketGate_A")
	var door_b := expansion.get_node("TicketGate_B")
	contract.has_ticket = false
	player.position = Vector3(10.5,4.5,27)
	check(not door_a.interact(player) and not door_a.is_open,"Ticket gate refuses entry without ticket")
	contract.has_ticket = true
	check(door_a.interact(player) and door_a.is_open and contract.ticket_scanned,"First ticket interaction scans and opens gate A")
	check(door_b.unlocked and door_b.interact(player) and door_b.is_open,"One scan grants rights at both upper landing gates")
	check(door_b.get_node("Panel/CollisionShape3D").shape.size.x == 2.0,"Gate B covers full two-metre opening")
	check(door_a.get_node("Panel").collision_layer == 0 and door_a.get_node("Passage").enabled,"Opening ticket gate clears collision and enables nav link")
	check(door_a.interact(player) and not door_a.is_open and door_a.get_node("Panel").collision_layer == 1,"Solved ticket door still closes physically")
	check(door_a.interact(player) and door_a.is_open,"Solved ticket door can reopen")
	player.position = Vector3(10.5,4.5,27)
	check(await walk_to(player,Vector3(7.9,4.5,27)),"Real player crosses upper gate A on flat landing without falling")
	check(await walk_to(player,Vector3(10.5,4.5,27)),"Real player returns through upper gate A")
	player.position = Vector3(25.5,4.5,3)
	check(await walk_to(player,Vector3(28.1,4.5,3)),"Real player crosses upper gate B on flat landing without falling")
	check(await walk_to(player,Vector3(25.5,4.5,3)),"Real player returns through upper gate B")
	var nav_path := NavigationServer3D.map_get_path(level.get_world_3d().navigation_map,Vector3(25.5,4.95,3),Vector3(28.1,4.95,3),true)
	check(not nav_path.is_empty() and nav_path[-1].distance_to(Vector3(28.1,4.95,3)) < .8,"Open gate B has a connected baked navigation path")
	var map := expansion.get_node("WallMap")
	player.position = Vector3(32,0,25.7)
	player.camera.look_at(map.global_position)
	await frames(5)
	check(player.get_node("Interactor").find_target() == map,"Wall map reachable by actual camera ray")
	await press_e()
	check(ui.visible and ui.mode == "map" and ui.map_canvas.floor_index == 0,"E opens centred map on floor one")
	await frames(5)
	check(root.get_visible_rect().encloses(ui.panel.get_global_rect()),"Two-floor map UI fits in viewport")
	ui.map_buttons.get_child(1).pressed.emit()
	check(ui.map_canvas.floor_index == 1,"Map tab switches to upper floor")
	ui.save_button.pressed.emit()
	check(ui.saved_map,"Save stores map access for this attempt")
	await press_e()
	player.position = Vector3(18,0,35)
	var m := InputEventKey.new()
	m.physical_keycode = KEY_M
	m.keycode = KEY_M
	m.pressed = true
	Input.parse_input_event(m)
	await frames(5)
	check(ui.visible and ui.mode == "map" and ui.source == null,"M reopens saved map away from wall")
	var flow := GameFlow.find(level)
	flow.pause()
	check(not ui.visible and not player.modal_active,"Pause closes map and releases modal lock")
	flow.resume()
	print("Service verification: %d checks, %d failures"%[checks,failures])
	for sound in level.find_children("*","AudioStreamPlayer3D",true,false):
		sound.stop()
		sound.stream = null
	current_scene = null
	level.free()
	await process_frame
	quit(0 if failures == 0 else 1)
