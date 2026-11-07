extends SceneTree

## Actual in-engine prototype views, run with a renderer rather than --headless.
func _initialize() -> void:
	_capture.call_deferred()


func save_view(name: String) -> void:
	for tick in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var output := "res://maps/isg_museum/docs/step-08-%s.png" % name
	if root.get_texture().get_image().save_png(output) != OK:
		push_error("Could not save " + output)
		quit(1)
	print("Saved ", output)


func _capture() -> void:
	var level := (load("res://maps/isg_museum/scenes/museum.tscn") as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	for guard in get_nodes_in_group("guards"):
		guard.process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("StealthDirector").set_physics_process(false)
	var player := level.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	player.get_node("Noise").set_physics_process(false)
	for node in get_nodes_in_group("debug_visuals"):
		if node is Node3D:
			node.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for tick in 10:
		await process_frame
	# No simulation is needed for still views; avoid auto-pausing an offscreen window.
	level.get_node("GameFlow").set_process(false)
	level.get_node("GameFlow").set_process_unhandled_input(false)
	if level.get_node("GameFlow").state == GameStateMachine.State.PAUSED:
		level.get_node("GameFlow").resume()
	level.get_node("Interactables/Key").interact(player)
	var painting := level.get_node("Interactables/Painting_T2")
	player.position = Vector3(34.3,4.5,10)
	player.camera.look_at(painting.global_position)
	if not painting.interact(player):
		push_error("Could not pick up T2")
		quit(1)
		return
	player.position = Vector3(32,4.5,16.5)
	player.rotation = Vector3(0,PI,0)
	player.camera.rotation = Vector3.ZERO
	level.get_node("NavigationRegion3D/Doors/GalleryB").interact(player)
	player.camera.look_at(Vector3(32,5.6,24))
	level.get_node("ObjectiveHud").show_message("",Color.WHITE)
	await save_view("t2-carry")
	var depot := level.get_node("Interactables/T2Depot")
	player.position = Vector3(32,4.5,27.5)
	player.rotation = Vector3.ZERO
	player.camera.look_at(depot.global_position + Vector3(0,0.65,0))
	if not depot.interact(player):
		push_error("Could not deliver T2")
		quit(1)
		return
	player.position = Vector3(32,4.5,29)
	player.camera.look_at(depot.global_position + Vector3(0,0.8,0))
	await save_view("t2-delivered")
	current_scene = null
	level.free()
	await process_frame
	quit(0)
