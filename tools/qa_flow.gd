extends SceneTree

## QA run of the real game flow with real scene changes (the automated tests
## stub scene changes, because changing scene would end the test runner):
##   main menu → Start → level → Esc (pause) → Resume → Esc → Restart (level
##   reloads) → caught → respawn → Esc → Main menu → Start → finish the level →
##   win screen → Play again (level reloads) → Esc → Main menu → Quit
## Every step is checked; a screenshot is saved for each when there is a display.
##
##   godot --path . --resolution 1280x720 --script res://tools/qa_flow.gd -- --out=docs/qa/flow
##   godot --headless --path . --script res://tools/qa_flow.gd
##
## Prints "QA FLOW PASSED" or the failed steps, and exits 0 / 1.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const G := GameStateMachine.State

var _out := ""
var _failures: Array[String] = []
var _step := 0
var _levels_seen: Array[int] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = "res://" + a.trim_prefix("--out=")
	if _out != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))

	change_scene_to_file(MAIN_MENU)
	await _wait(0.5)
	var menu := current_scene as MainMenu
	_check(menu != null and menu.start_button.has_focus(), "The main menu opens with Start focused.")
	await _shot("main_menu")

	# Start.
	menu.start_button.pressed.emit()
	var level := await _wait_for_level()
	_check(level != null and _flow().state == G.PLAYING and not paused, "Start loads the level, playing and unpaused.")
	await _wait(1.0)
	await _shot("playing")

	# Pause with Esc, resume with the button.
	_press("pause")
	await _wait(0.3)
	_check(_flow().state == G.PAUSED and paused and _menus().pause_panel.visible, "Esc pauses and shows the pause menu.")
	await _shot("paused")
	_menus().resume_button.pressed.emit()
	await _wait(0.3)
	_check(_flow().state == G.PLAYING and not paused and not _menus().pause_panel.visible, "Resume continues the game.")

	# Pause → Restart: a fresh copy of the level.
	var first_id := current_scene.get_instance_id()
	_press("pause")
	await _wait(0.3)
	_menus().restart_button.pressed.emit()
	level = await _wait_for_level(first_id)
	_check(level != null and level.get_instance_id() != first_id and _flow().state == G.PLAYING and not paused,
		"Restart reloads the level and plays (unpaused).")
	_check(ObjectiveManager.find(level).current() == ObjectiveManager.ENTER_LIBRARY, "After a restart the objectives start over.")

	# Caught → respawn.
	await _get_caught(level)
	await _wait(0.1)  # the HUD updates on its next frame
	_check(_flow().state == G.CAUGHT and (level.get_node("StealthHud") as StealthHud)._caught.visible, "Being caught shows the caught screen.")
	await _wait(0.8)
	await _shot("caught")
	var director := StealthDirector.find(level)
	for i in 400:
		if director.status != StealthDirector.Status.CAUGHT:
			break
		await physics_frame
	await _wait(0.3)
	_check(_flow().state == G.PLAYING and director.catches == 1, "After the caught screen, play resumes from the respawn point.")

	# Pause → Main menu → Start again.
	_press("pause")
	await _wait(0.3)
	_menus().pause_menu_button.pressed.emit()
	await _wait(0.6)
	menu = current_scene as MainMenu
	_check(menu != null and not paused, "Main menu from the pause menu returns to the title screen, unpaused.")
	menu.start_button.pressed.emit()
	level = await _wait_for_level()
	_check(level != null and _flow().state == G.PLAYING, "Start works again after returning to the menu.")

	# Finish the level: complete the earlier objectives, then really use the exit door.
	var objectives := ObjectiveManager.find(level)
	for id in [ObjectiveManager.ENTER_LIBRARY, ObjectiveManager.REACH_RESTRICTED, ObjectiveManager.TAKE_CARD]:
		objectives.complete(id)
	var player := level.get_node("Player") as FirstPersonPlayer
	var door := level.get_node("Gameplay/ExitDoor") as Node3D
	player.global_position = Vector3(26.4, 0.05, -23)
	_face(player, door.global_position)
	await _wait(0.5)
	_press("interact")
	await _wait(1.0)
	_check(_flow().state == G.WIN and _menus().win_panel.visible and _menus().play_again_button.has_focus(),
		"Using the unlocked door wins: the win screen shows with Play again focused.")
	await _shot("win")
	_press("pause")
	await _wait(0.2)
	_check(_flow().state == G.WIN, "Esc on the win screen doesn't pause.")

	# Play again → fresh level.
	var won_id := current_scene.get_instance_id()
	_menus().play_again_button.pressed.emit()
	level = await _wait_for_level(won_id)
	_check(level != null and _flow().state == G.PLAYING and ObjectiveManager.find(level).current() == ObjectiveManager.ENTER_LIBRARY,
		"Play again starts a fresh level.")

	# Back to the menu and quit.
	_press("pause")
	await _wait(0.3)
	_menus().pause_menu_button.pressed.emit()
	await _wait(0.6)
	menu = current_scene as MainMenu
	_check(menu != null, "Back at the main menu.")
	var quit_called := {"yes": false}
	menu.quit_game = func(): quit_called.yes = true
	menu.quit_button.pressed.emit()
	_check(quit_called.yes, "Quit quits.")

	if _failures.is_empty():
		print("QA FLOW PASSED (%d checks, %d levels loaded)" % [_step, _levels_seen.size()])
	else:
		for f in _failures:
			printerr("QA FLOW FAIL: ", f)
	# Leave the menu scene and let the audio server release sounds before quitting.
	current_scene.queue_free()
	for i in 60:
		OS.delay_msec(5)
		await process_frame
	quit(0 if _failures.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	_step += 1
	print("  [%s] %d. %s" % ["ok" if ok else "FAIL", _step, what])
	if not ok:
		_failures.append(what)


func _flow() -> GameFlow:
	return GameFlow.find(current_scene) if current_scene else null


func _menus() -> GameMenus:
	return current_scene.get_node("GameMenus") as GameMenus


func _wait_for_level(previous_id := 0) -> Node:
	for i in 600:
		await process_frame
		var scene := current_scene
		if scene and scene.get_instance_id() != previous_id and scene.has_node("GameFlow"):
			# Wait for navigation and the guards to start.
			for k in 60:
				await physics_frame
			_levels_seen.append(scene.get_instance_id())
			return scene
	return null


func _get_caught(level: Node) -> void:
	var guard := level.get_node("Guards/GuardMain") as Guard
	var player := level.get_node("Player") as FirstPersonPlayer
	var director := StealthDirector.find(level)
	for i in 1500:
		if director.status == StealthDirector.Status.CAUGHT:
			return
		if guard.machine.current != GuardStateMachine.CHASE:
			player.global_position = guard.global_position - guard.global_basis.z * 5.0
			player.velocity = Vector3.ZERO
		_face(player, guard.global_position + Vector3(0, 1.4, 0))
		await physics_frame


func _face(player: FirstPersonPlayer, target: Vector3) -> void:
	var flat := target - player.global_position
	player.rotation.y = atan2(-flat.x, -flat.z)
	var eye := player.camera.global_position
	player.head.rotation.x = atan2(target.y - eye.y, Vector2(target.x - eye.x, target.z - eye.z).length())


func _press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	root.push_input(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	root.push_input(up)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _shot(name: String) -> void:
	if _out == "" or DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(_out.path_join(name + ".png")))
