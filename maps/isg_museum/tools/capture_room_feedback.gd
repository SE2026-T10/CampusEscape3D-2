extends "res://maps/isg_museum/tools/capture_contract.gd"

func shot(name: String) -> void:
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://maps/isg_museum/docs/step-19-%s.png"%name)
	print("Captured ",name)

func run() -> void:
	level = load("res://maps/isg_museum/scenes/museum.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	var flow: GameFlow = level.get_node("GameFlow")
	if flow.state == GameStateMachine.State.PAUSED:
		flow.resume()
	var player := level.get_node("Player")
	player.set_physics_process(false)
	player.get_node("Noise").set_physics_process(false)
	level.get_node("StealthDirector").set_physics_process(false)
	for guard in get_nodes_in_group("guards"):
		guard.set_physics_process(false)
		guard.vision.set_physics_process(false)
		guard.hearing.set_physics_process(false)
		guard.get_node("Presentation").process_mode = Node.PROCESS_MODE_DISABLED
		guard.get_node("DebugLabel").hide()
	for child in level.get_children():
		if child is CanvasLayer:
			child.hide()
	for debug in get_nodes_in_group("debug_visuals"):
		if debug is Node3D:
			debug.hide()
	var calendar := get_first_node_in_group("staff_calendar")
	player.position = Vector3(28.7,0,16)
	player.camera.look_at(calendar.global_position)
	await shot("calendar-wall")
	level.get_node("StaffReader").show()
	calendar.interact(player)
	await shot("calendar-read")
	level.get_node("StaffReader").close_document()
	var seated := level.get_node("Guard_G3")
	seated.position.y = 0
	seated.go_to_sleep()
	seated.get_node("Presentation")._process(0)
	player.position = Vector3(34.1,0,14.4)
	player.camera.look_at(Vector3(33.9,.8,12))
	await shot("g3-seated")
	player.position = Vector3(33.5,0,10.2)
	player.camera.look_at(Vector3(35.012,1.6,10.2))
	await shot("key-label")
	player.position = Vector3(28.4,0,20.5)
	player.camera.look_at(Vector3(33.3,1.1,22.4))
	await shot("storage")
	player.position = Vector3(32,4.5,16.5)
	player.camera.look_at(Vector3(32,6,18))
	await shot("closed-shortcut")
	for sound in level.find_children("*","AudioStreamPlayer3D",true,false):
		sound.stop()
		sound.stream = null
	current_scene = null
	level.free()
	await process_frame
	quit()
