extends "res://tools/map_flow.gd"

## Native-renderer QA, starting from the same project entry scene as F5.
## Uses GUI mouse/keyboard events and actual scene changes; no product saves.
const REPORT := "res://maps/isg_museum/docs/reports/menu-integration-v1/"
const ReportPaths := preload("res://maps/isg_museum/tools/report_paths.gd")
var _evidence := []

func _run() -> void:
	root.size = Vector2i(1280,720)
	_out = REPORT+"images/"
	DirAccess.make_dir_recursive_absolute(_out)
	_check(ProjectSettings.get_setting("application/run/main_scene")==MAIN_MENU,"F5 still opens the shared main menu.")
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	var menu := await _wait_for_scene(0,false) as MainMenu
	await _shot("01-menu-top")
	menu.quit_button.grab_focus()
	for i in 6: await process_frame
	await _shot("02-menu-museum")
	for editing in [false,true]:
		menu = current_scene as MainMenu
		var button: Button = menu.test_buttons[LevelCatalog.MUSEUM] if editing else menu.level_buttons[LevelCatalog.MUSEUM]
		if editing:
			var ordered: Array[Button] = []
			for entry in LevelCatalog.LEVELS:
				ordered.append(menu.level_buttons[entry.id])
				if menu.test_buttons.has(entry.id): ordered.append(menu.test_buttons[entry.id])
			for next in ordered.slice(1):
				_press("ui_down")
				for i in 4: await process_frame
				_check(root.gui_get_focus_owner()==next,"Down reaches "+next.text)
				if next==button: break
		else:
			button.grab_focus()
		for i in 6: await process_frame
		var before: WeakRef = weakref(menu)
		var previous_id := menu.get_instance_id()
		if editing:
			_press("ui_accept")
		else:
			var at := button.get_global_rect().get_center()
			var motion := InputEventMouseMotion.new()
			motion.position = at
			motion.global_position = at
			root.push_input(motion)
			for down in [true,false]:
				var click := InputEventMouseButton.new()
				click.position = at
				click.global_position = at
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = down
				root.push_input(click)
				await process_frame
		var level := await _wait_for_scene(previous_id,true)
		if level==null:
			push_error("GUI selection did not load a level")
			quit(1)
			return
		var path := LevelCatalog.test_scene_of(LevelCatalog.MUSEUM) if editing else LevelCatalog.scene_of(LevelCatalog.MUSEUM)
		var mode := "editing" if editing else "normal"
		# A capture window can lose OS focus; resume that QA instance before checks.
		if GameFlow.find(level).state==G.PAUSED: GameFlow.find(level).resume()
		_check_level(level,path,before,"GUI selected museum "+mode)
		await _shot("03-museum-"+mode+"-from-menu")
		await _interact_with_npcs(level,mode)
		var contract := SceneChecks.owned_system(level,&"museum_contract")
		var old_contract_number: int = contract.contract_info.number
		_press("pause")
		await _wait(.15)
		_check(paused and GameFlow.find(level).state==G.PAUSED,"GUI Esc pauses "+mode)
		await _shot("06-pause-"+mode)
		(level.get_node("GameMenus") as GameMenus).resume_button.pressed.emit()
		await _wait(.1)
		_check(not paused and GameFlow.find(level).state==G.PLAYING,"GUI Resume works "+mode)
		_press("pause")
		await _wait(.1)
		previous_id = level.get_instance_id()
		before = weakref(level)
		(level.get_node("GameMenus") as GameMenus).restart_button.pressed.emit()
		level = await _wait_for_scene(previous_id,true)
		if GameFlow.find(level).state==G.PAUSED: GameFlow.find(level).resume()
		_check_level(level,path,before,"GUI Restart preserves museum "+mode)
		_check(_mission_is_clean(level),"GUI Restart resets contract/ticket/progress "+mode)
		_evidence.append({"mode":mode,"guards":get_nodes_in_group("guards").size(),"scene":level.scene_file_path,
			"contract_before":old_contract_number,"contract_after":SceneChecks.owned_system(level,&"museum_contract").contract_info.number})
		previous_id = level.get_instance_id()
		before = weakref(level)
		_press("pause")
		await _wait(.1)
		(level.get_node("GameMenus") as GameMenus).pause_menu_button.pressed.emit()
		menu = await _wait_for_scene(previous_id,false) as MainMenu
		_check(menu!=null and before.get_ref()==null and not paused,"GUI Main menu frees museum "+mode)
	var file := FileAccess.open(ReportPaths.artifact(REPORT,"capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"results":_evidence,"failures":_failures,"checks":_step,"resolution":[root.size.x,root.size.y],
		"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),
		"fixture":"Project F5 entry scene; normal mode selected by GUI mouse, editing mode by Down navigation then Enter. QA anchor moves to N0/receptionist use real interaction/quiz APIs; no guard freezing or saved changes. Resume OS-focus pauses only before scene checks."},"\t")+"\n")
	file.close()
	current_scene.queue_free()
	await preload("res://tests/test_utils.gd").settle_async_audio(self)
	print("MENU CAPTURE: ",_step," checks, ",_failures.size()," failures")
	quit(0 if _failures.is_empty() else 1)

func _interact_with_npcs(level: Node, mode: String) -> void:
	var player := SceneChecks.owned_system(level,&"player") as FirstPersonPlayer
	var n0 := level.get_node("NavigationRegion3D/Teammate") as Node3D
	player.position = Vector3(20.5,.05,33)
	player.velocity = Vector3.ZERO
	player.camera.look_at(n0.global_position)
	for i in 3: await physics_frame
	_check(n0.interact(player),"N0 opens a direct contract conversation "+mode)
	var contract_ui := get_first_node_in_group("museum_contract_ui")
	_check(contract_ui.visible,"Contract UI is visible "+mode)
	await _shot("04-n0-contract-"+mode)
	contract_ui.accept_button.pressed.emit()
	for i in 3: await physics_frame
	var npc := level.get_node("NavigationRegion3D/ServiceExpansion/Receptionist") as Node3D
	player.position = Vector3(30.9,.05,27.5)
	player.velocity = Vector3.ZERO
	player.camera.look_at(npc.global_position)
	for i in 3: await physics_frame
	_check(npc.interact(player),"Receptionist opens the quiz "+mode)
	var service_ui := get_first_node_in_group("museum_service_ui")
	_check(service_ui.visible and service_ui.mode=="quiz","Service quiz is visible "+mode)
	await _shot("05-receptionist-quiz-"+mode)
	for i in 3:
		service_ui.answer(int(service_ui.questions[service_ui.question_index].correct))
		await process_frame
	_check(SceneChecks.owned_system(level,&"museum_contract").has_ticket,"Three correct answers grant the museum ticket "+mode)
	service_ui.close_panel()
