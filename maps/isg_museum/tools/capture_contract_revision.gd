extends "res://maps/isg_museum/tools/capture_contract.gd"

func shot(name: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://maps/isg_museum/docs/step-18-%s.png"%name)
	print("Captured ",name)

func run() -> void:
	level = load("res://maps/isg_museum/scenes/museum.tscn").instantiate()
	level.get_node("MuseumContract").contract_index_override = 3 if "--contract-04" in OS.get_cmdline_user_args() else 0
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
	var teammate := level.get_node("NavigationRegion3D/Teammate")
	player.position = Vector3(18,0,35)
	player.camera.look_at(Vector3(19.5,1.6,30))
	await shot("entrance-n0")
	player.position = Vector3(20.5,0,33)
	player.camera.look_at(teammate.global_position)
	level.get_node("ContractUI").open_contract(teammate)
	await shot("contract-04" if "--contract-04" in OS.get_cmdline_user_args() else "contract-01")
	if "--contract-04" in OS.get_cmdline_user_args():
		current_scene = null
		level.free()
		await process_frame
		quit()
		return
	level.get_node("MuseumContract").accept_contract()
	level.get_node("ContractUI").close_sheet()
	var service := level.get_node("NavigationRegion3D/ServiceExpansion")
	player.position = Vector3(30,0,26.35)
	player.camera.look_at(service.get_node("ReceptionNotice").global_position)
	await shot("desk-nameplate")
	player.position = Vector3(31.1,0,27)
	player.camera.look_at(service.get_node("Receptionist").global_position)
	var ui := service.get_node("ServiceUi")
	ui.open_quiz(service.get_node("Receptionist"),player)
	await shot("service-quiz")
	for i in 3:
		ui.answer(ui.questions[i].correct)
	await shot("ticket")
	for sound in level.find_children("*","AudioStreamPlayer3D",true,false):
		sound.stop()
		sound.stream = null
	current_scene = null
	level.free()
	await process_frame
	quit()
