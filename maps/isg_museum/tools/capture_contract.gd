extends SceneTree
var level: Node3D
func _initialize() -> void:
	run.call_deferred()
func shot(name: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://maps/isg_museum/docs/step-17-%s.png"%name)
	print("Captured ",name)
func run() -> void:
	level = load("res://maps/isg_museum/scenes/museum.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	var flow: GameFlow = level.get_node("GameFlow")
	if flow.state == GameStateMachine.State.PAUSED:
		flow.resume()
	var player = level.get_node("Player")
	player.set_physics_process(false)
	player.get_node("Noise").set_physics_process(false)
	level.get_node("StealthDirector").set_physics_process(false)
	for guard in get_nodes_in_group("guards"):
		guard.process_mode = Node.PROCESS_MODE_DISABLED
	for debug in get_nodes_in_group("debug_visuals"):
		if debug is Node3D:
			debug.hide()
	await process_frame
	player.position = Vector3(16,0,35.3)
	player.camera.look_at(Vector3(14.3,1.4,35.3))
	level.get_node("ContractUI").open_contract(level.get_node("NavigationRegion3D/Teammate"))
	await shot("contract-paper")
	level.get_node("MuseumContract").accept_contract()
	level.get_node("ContractUI").close_sheet()
	var service = level.get_node("NavigationRegion3D/ServiceExpansion")
	var ui = get_first_node_in_group("museum_service_ui")
	player.position = Vector3(31,0,27)
	player.camera.look_at(service.get_node("Receptionist").global_position)
	ui.open_quiz(service.get_node("Receptionist"),player)
	await shot("service-quiz")
	ui.close_panel()
	player.position = Vector3(32,0,25.8)
	player.camera.look_at(service.get_node("WallMap").global_position)
	ui.open_map(service.get_node("WallMap"),player)
	ui.show_floor(1)
	await shot("wall-map")
	ui.close_panel()
	player.position = Vector3(6.2,0,11.5)
	player.camera.look_at(Vector3(4.3,1.7,11.5))
	await shot("sculpture")
	player.position = Vector3(10.5,0,4.5)
	player.camera.look_at(Vector3(10.5,1.35,2.8))
	await shot("history")
	var manager: ObjectiveManager = level.get_node("ObjectiveManager")
	manager.complete(&"take_s1")
	manager.complete(&"take_rope")
	manager.complete(&"take_b2")
	manager.complete(&"escape")
	await shot("result-partial")
	for sound in level.find_children("*","AudioStreamPlayer3D",true,false):
		sound.stop()
		sound.stream = null
	current_scene = null
	level.free()
	await process_frame
	quit()
