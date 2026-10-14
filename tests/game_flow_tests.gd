extends RefCounted

## Phase 10 game-flow tests. Called from tests/test_scene.gd.
##   - GameStateMachine: states, allowed transitions, no duplicates (unit + random stress)
##   - project setup: main menu is the main scene; Esc / P pause; no old release_mouse action
##   - main menu: Start loads the level once; Quit; cursor visible
##   - in the library: start state, pause / resume (key, focus loss), the pause menu,
##     the whole simulation frozen while paused (guards, navigation, vision,
##     physics, noise clock, timers), caught → respawn, victory, restart, main menu,
##     mouse mode per state, no duplicate transitions
## Scene changes are recorded instead of performed, so the test runner stays loaded.

const LIBRARY_SCENE := "res://scenes/level/library_graybox.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const GUARD_SCENE := "res://scenes/npc/guard.tscn"
const TestUtils := preload("res://tests/test_utils.gd")
const G := GameStateMachine.State

var failures: Array[String] = []
var _host: Node
var _level: Node3D
var _flow: GameFlow
var _menus: GameMenus
var _player: FirstPersonPlayer
var _director: StealthDirector
var _scene_requests: Array[String] = []
var _guard: Guard
var _route: PatrolRoute


func run(host: Node) -> Array[String]:
	_host = host
	_check_state_machine()
	_check_random_requests()
	_check_project_setup()
	await _check_main_menu()
	await _load_level(true)
	await _check_start_state()
	await _check_pause_and_resume()
	await _check_simulation_frozen_while_paused()
	await _check_restart_and_menu_from_pause()
	await _load_level(false)
	await _check_vision_frozen_while_paused()
	await _check_caught_and_respawn()
	await _check_victory()
	_unload()
	await _frames(2)
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[game flow] " + message)


# --- GameStateMachine ----------------------------------------------------------------------

func _check_state_machine() -> void:
	var m := GameStateMachine.new()
	var seen: Array = []
	m.state_changed.connect(func(from, to): seen.append([from, to]))
	_expect(GameStateMachine.State.keys() == ["PLAYING", "CAUGHT", "PAUSED", "WIN"], "Game states should be PLAYING, CAUGHT, PAUSED, WIN.")
	_expect(m.current == G.PLAYING and m.history == [G.PLAYING], "The game should start PLAYING.")
	# Every allowed transition, and nothing else.
	var allowed := {G.PLAYING: [G.CAUGHT, G.PAUSED, G.WIN], G.CAUGHT: [G.PLAYING], G.PAUSED: [G.PLAYING], G.WIN: []}
	for from in allowed:
		for to in [G.PLAYING, G.CAUGHT, G.PAUSED, G.WIN]:
			var probe := GameStateMachine.new()
			probe.current = from
			var expected: bool = to in allowed[from]
			_expect(probe.request(to) == expected, "%s → %s should be %s." % [
				GameStateMachine.name_of(from), GameStateMachine.name_of(to), "allowed" if expected else "refused"])
			_expect(probe.current == (to if expected else from), "A refused request must not change the state.")
	# Duplicates are refused and emit nothing.
	_expect(m.request(G.PAUSED) and not m.request(G.PAUSED), "Pausing twice must be refused the second time.")
	_expect(m.request(G.PLAYING) and not m.request(G.PLAYING), "Resuming twice must be refused the second time.")
	_expect(not m.request(G.PLAYING), "PLAYING → PLAYING is a duplicate.")
	_expect(seen == [[G.PLAYING, G.PAUSED], [G.PAUSED, G.PLAYING]], "Each accepted transition is reported exactly once (got %s)." % [seen])
	_expect(m.rejected_count == 3 and m.history == [G.PLAYING, G.PAUSED, G.PLAYING], "Rejected requests are counted and not recorded.")
	# Caught can't be paused or won; a win is final.
	m.request(G.CAUGHT)
	_expect(not m.request(G.PAUSED) and not m.request(G.WIN) and not m.request(G.CAUGHT), "From CAUGHT only PLAYING (respawn) is allowed.")
	m.request(G.PLAYING)
	m.request(G.WIN)
	for to in [G.PLAYING, G.CAUGHT, G.PAUSED, G.WIN]:
		_expect(not m.request(to), "WIN is final; %s must be refused." % GameStateMachine.name_of(to))


func _check_random_requests() -> void:
	# Random requests; after a WIN (final) a new game starts with a new machine.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var machines: Array[GameStateMachine] = [GameStateMachine.new()]
	var emitted := {"count": 0}
	machines[0].state_changed.connect(func(_a, _b): emitted.count += 1)
	for i in 3000:
		if machines[-1].current == G.WIN:
			machines.append(GameStateMachine.new())
			machines[-1].state_changed.connect(func(_a, _b): emitted.count += 1)
		machines[-1].request(rng.randi_range(0, 3))
	var transitions := 0
	var refused := 0
	var bad := 0
	for m in machines:
		refused += m.rejected_count
		for k in range(1, m.history.size()):
			transitions += 1
			if m.history[k] == m.history[k - 1] or not (m.history[k] in GameStateMachine.ALLOWED[m.history[k - 1]]):
				bad += 1
	_expect(bad == 0, "Random requests produced %d duplicate or illegal transitions." % bad)
	_expect(emitted.count == transitions and transitions + refused == 3000, "Every request is either one reported transition or refused.")
	print("  [game flow] 3000 random requests over %d games: %d transitions, %d refused, 0 duplicate or illegal" % [machines.size(), transitions, refused])


func _check_project_setup() -> void:
	_expect(ProjectSettings.get_setting("application/run/main_scene") == MAIN_MENU_SCENE, "The game should start at the main menu.")
	var keys: Array = []
	if InputMap.has_action("pause"):
		for event in InputMap.action_get_events("pause"):
			if event is InputEventKey:
				keys.append(event.physical_keycode)
	_expect(KEY_ESCAPE in keys and KEY_P in keys, "'pause' should be bound to Escape and P (got %s)." % [keys])
	_expect(not InputMap.has_action("release_mouse"), "The old 'release_mouse' action should be gone (Escape pauses now).")


# --- Main menu -------------------------------------------------------------------------------

func _check_main_menu() -> void:
	var menu: MainMenu = (load(MAIN_MENU_SCENE) as PackedScene).instantiate()
	var requests: Array[String] = []
	var quits := {"count": 0}
	menu.change_scene = func(path: String): requests.append(path)
	menu.quit_game = func(): quits.count += 1
	_host.add_child(menu)
	await _frames(2)
	_expect(menu.start_button != null and menu.quit_button != null, "The main menu needs Start and Quit buttons.")
	_expect(menu.start_button.has_focus(), "Start should have keyboard focus.")
	_expect(not _host.get_tree().paused, "The main menu must not leave the game paused.")
	menu.start_button.pressed.emit()
	menu.start_button.pressed.emit()
	_expect(requests == [LIBRARY_SCENE], "Start should load the library once, even if pressed twice (got %s)." % [requests])
	menu.quit_button.pressed.emit()
	_expect(quits.count == 1, "Quit should quit the game.")
	menu.queue_free()
	await _frames(2)


# --- In the library ------------------------------------------------------------------------

func _check_start_state() -> void:
	_expect(_flow != null and _menus != null, "The library needs GameFlow and GameMenus.")
	_expect(_flow.state == G.PLAYING and not _host.get_tree().paused, "The level should start PLAYING, unpaused.")
	_expect(_flow.applied_mouse_mode == Input.MOUSE_MODE_CAPTURED, "The mouse should be captured while playing.")
	_expect(not _menus.pause_panel.visible and not _menus.win_panel.visible, "No menu should show while playing.")
	_expect(_flow.process_mode == Node.PROCESS_MODE_ALWAYS and _menus.process_mode == Node.PROCESS_MODE_ALWAYS,
		"GameFlow and the menus must keep running while paused.")


func _check_pause_and_resume() -> void:
	_press_pause()
	await _frames(2)
	_expect(_flow.state == G.PAUSED and _host.get_tree().paused, "Escape should pause the game and the scene tree.")
	_expect(_flow.applied_mouse_mode == Input.MOUSE_MODE_VISIBLE, "The cursor should be visible while paused.")
	_expect(_menus.pause_panel.visible and _menus.resume_button.has_focus(), "The pause menu should show, with Resume focused.")
	_expect(not _flow.pause(), "Pausing again while paused must be refused.")
	_press_pause()
	await _frames(2)
	_expect(_flow.state == G.PLAYING and not _host.get_tree().paused, "Escape again should resume.")
	_expect(_flow.applied_mouse_mode == Input.MOUSE_MODE_CAPTURED, "Resuming should capture the mouse again.")
	_expect(not _menus.pause_panel.visible, "The pause menu should hide on resume.")
	_expect(not _flow.resume(), "Resuming while playing must be refused.")
	# The Resume button.
	_flow.pause()
	await _frames(1)
	_menus.resume_button.pressed.emit()
	await _frames(1)
	_expect(_flow.state == G.PLAYING, "The Resume button should resume.")
	# Losing window focus pauses.
	_flow.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(1)
	_expect(_flow.state == G.PAUSED, "Losing window focus while playing should pause.")
	_flow.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(_flow.machine.history.count(G.PAUSED) == 3, "A second focus loss must not pause again.")
	_flow.resume()
	await _frames(1)
	var history := _flow.machine.history.map(func(s): return GameStateMachine.name_of(s))
	_expect(history == ["PLAYING", "PAUSED", "PLAYING", "PAUSED", "PLAYING", "PAUSED", "PLAYING"],
		"Unexpected transition history %s." % [history])
	print("  [game flow] pause/resume by key, button and focus loss: %s" % " → ".join(history))


func _check_simulation_frozen_while_paused() -> void:
	var guards: Array[Guard] = []
	for node in _level.find_children("*", "Guard", true, false):
		guards.append(node)
	# Wait until at least one guard is walking.
	var moving := false
	for attempt in 20:
		var before := _positions(guards)
		await _frames(20)
		if _max_moved(before, _positions(guards)) > 0.2:
			moving = true
			break
	_expect(moving, "A guard should be walking before the pause test.")
	var noise := NoiseSystem.find(_level)
	var objectives_hud: ObjectiveHud = _level.get_node("ObjectiveHud")
	objectives_hud.show_message("test message")
	_flow.pause()
	await _frames(1)
	var positions := _positions(guards)
	var velocities := guards.map(func(g): return g.velocity)
	var states := guards.map(func(g): return g.machine.current)
	var targets := guards.map(func(g): return g.get_node("NavigationAgent3D").target_position)
	var clock := noise.now
	var play_time := _flow.play_time
	var player_at := _player.global_position
	var message_left := objectives_hud._message_left
	Input.action_press("move_forward")  # held during the pause: must not move the player
	await _frames(120)
	Input.action_release("move_forward")
	_expect(_max_moved(positions, _positions(guards)) == 0.0, "Guards must not move while paused.")
	_expect(guards.map(func(g): return g.velocity) == velocities and guards.map(func(g): return g.machine.current) == states,
		"Guard velocities and AI states must not change while paused.")
	_expect(guards.map(func(g): return g.get_node("NavigationAgent3D").target_position) == targets, "Navigation targets must not change while paused.")
	_expect(noise.now == clock, "The noise clock must stop while paused.")
	_expect(_flow.play_time == play_time, "Play time must stop while paused.")
	_expect(_player.global_position == player_at, "The player must not move while paused, even holding a movement key.")
	_expect(objectives_hud._message_left == message_left, "HUD message timers must stop while paused.")
	_flow.resume()
	var resumed := _positions(guards)
	await _frames(90)
	_expect(_max_moved(resumed, _positions(guards)) > 0.2, "Guards should carry on after resuming.")
	_expect(_flow.play_time > play_time, "Play time should count again after resuming.")
	print("  [game flow] paused 120 frames: guards, navigation, noise clock, player and timers frozen; guards moved again after resume")


func _check_restart_and_menu_from_pause() -> void:
	_flow.pause()
	await _frames(1)
	_menus.restart_button.pressed.emit()
	_expect(_scene_requests == [LIBRARY_SCENE], "Restart should reload the library (got %s)." % [_scene_requests])
	_expect(not _host.get_tree().paused, "Leaving the level must unpause the tree.")
	_expect(_flow.applied_mouse_mode == Input.MOUSE_MODE_VISIBLE, "Leaving the level frees the mouse.")
	_menus.pause_menu_button.pressed.emit()
	_expect(not _flow.restart() and _scene_requests.size() == 1, "Only one scene change may be requested.")
	# Main menu from a fresh pause.
	await _load_level(true)
	_flow.pause()
	await _frames(1)
	_menus.pause_menu_button.pressed.emit()
	_expect(_scene_requests == [MAIN_MENU_SCENE] and not _host.get_tree().paused, "Main menu from the pause menu should go to the main menu, unpaused.")


func _check_vision_frozen_while_paused() -> void:
	await _spawn_guard(Vector3(2, 0, -6), PI)  # facing south
	_player.global_position = Vector3(2, 0.05, 5)  # 11 m away: the meter fills slowly
	await _until(func(): return _guard.vision.detection > 5.0, 240)
	_flow.pause()
	await _frames(1)
	var detection := _guard.vision.detection
	await _frames(60)
	_expect(_guard.vision.detection == detection, "A guard's detection meter must not change while paused (%.2f → %.2f)." % [detection, _guard.vision.detection])
	_flow.resume()
	await _frames(20)
	_expect(_guard.vision.detection > detection, "The meter should keep filling after resuming.")
	_player.global_position = Vector3(0, 0.05, 21)
	await _frames(5)


func _check_caught_and_respawn() -> void:
	var transitions: Array = []
	_flow.state_changed.connect(func(from, to): transitions.append([from, to]))
	await _spawn_guard(Vector3(2, 0, -3), PI)
	_player.global_position = Vector3(2, 0.05, 2)
	await _until(func(): return _director.status == StealthDirector.Status.CAUGHT, 600)
	await _frames(1)
	_expect(_flow.state == G.CAUGHT, "Being caught should switch the game to CAUGHT.")
	_expect(_flow.applied_mouse_mode == Input.MOUSE_MODE_CAPTURED and not _host.get_tree().paused, "The caught screen keeps the mouse captured and the tree running.")
	_press_pause()
	await _frames(1)
	_expect(_flow.state == G.CAUGHT and not _menus.pause_panel.visible, "Pausing during the caught screen must be refused.")
	await _until(func(): return _flow.state != G.CAUGHT, int(_director.reset_delay * Engine.physics_ticks_per_second) + 30)
	_expect(_flow.state == G.PLAYING, "Respawning should switch the game back to PLAYING.")
	_expect(transitions == [[G.PLAYING, G.CAUGHT], [G.CAUGHT, G.PLAYING]], "Caught and respawn should be exactly two transitions (got %s)." % [transitions])
	# Move the test guard far away so it can't catch again.
	_guard.queue_free()
	_route.queue_free()
	_guard = null
	_route = null
	await _frames(2)
	print("  [game flow] caught → respawn: PLAYING → CAUGHT → PLAYING, pause refused on the caught screen")


func _check_victory() -> void:
	var objectives := ObjectiveManager.find(_level)
	for id in [ObjectiveManager.ENTER_LIBRARY, ObjectiveManager.REACH_RESTRICTED, ObjectiveManager.TAKE_CARD, ObjectiveManager.REACH_EXIT]:
		objectives.complete(id)
	var door: ExitDoor = _level.get_node("Gameplay/ExitDoor")
	var won := {"count": 0}
	_flow.state_changed.connect(func(_from, to): if to == G.WIN: won.count += 1)
	_expect(door.interact(_player), "With every objective done, the exit should open.")
	await _frames(2)
	_expect(_flow.state == G.WIN, "Escaping should switch the game to WIN.")
	_expect(_flow.applied_mouse_mode == Input.MOUSE_MODE_VISIBLE, "The cursor should be visible on the win screen.")
	_expect(_menus.win_panel.visible and _menus.play_again_button.has_focus(), "The win screen should show with Play again focused.")
	_expect(_menus.get_win_text().contains("caught 1 time"), "The win screen should count the earlier catch, got '%s'." % _menus.get_win_text())
	_press_pause()
	await _frames(1)
	_expect(_flow.state == G.WIN and not _menus.pause_panel.visible and not _host.get_tree().paused, "Escape on the win screen must not pause.")
	_expect(not door.interact(_player), "The exit can't be used again after winning.")
	_expect(_flow.machine.history.count(G.WIN) == 1 and won.count == 1, "WIN must be entered once.")
	var play_time := _flow.play_time
	await _frames(30)
	_expect(_flow.play_time == play_time, "The clock stops on the win screen.")
	_menus.play_again_button.pressed.emit()
	_menus.win_menu_button.pressed.emit()
	_expect(_scene_requests == [LIBRARY_SCENE], "Play again should reload the level once (got %s)." % [_scene_requests])
	print("  [game flow] victory: WIN once, cursor visible, play again requested %s" % [_scene_requests])


# --- Helpers ---------------------------------------------------------------------------------

func _load_level(keep_guards: bool) -> void:
	_unload()
	await _frames(2)
	_level = (load(LIBRARY_SCENE) as PackedScene).instantiate()
	if not keep_guards:
		var guards := _level.get_node("Guards")
		_level.remove_child(guards)
		guards.free()
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, _level, Vector3(0, 0, 18)), "Library navigation never became ready.")
	await _frames(2)
	_flow = _level.get_node("GameFlow")
	_menus = _level.get_node("GameMenus")
	_player = _level.get_node("Player")
	_director = _level.get_node("StealthDirector")
	_scene_requests = []
	_flow.change_scene = func(path: String): _scene_requests.append(path)
	_guard = null
	_route = null


func _unload() -> void:
	Input.action_release("move_forward")
	if _level and is_instance_valid(_level):
		_level.queue_free()
	_level = null
	_host.get_tree().paused = false


func _press_pause() -> void:
	var event := InputEventAction.new()
	event.action = "pause"
	event.pressed = true
	_host.get_viewport().push_input(event)


func _positions(guards: Array[Guard]) -> Array:
	return guards.map(func(g): return g.global_position)


func _max_moved(a: Array, b: Array) -> float:
	var most := 0.0
	for i in a.size():
		most = maxf(most, (a[i] as Vector3).distance_to(b[i]))
	return most


func _spawn_guard(at: Vector3, yaw: float) -> void:
	if _guard and is_instance_valid(_guard):
		_guard.free()
	if _route and is_instance_valid(_route):
		_route.free()
	_route = PatrolRoute.new()
	var post := PatrolPoint.new()
	post.position = at
	post.wait_time = 300.0
	_route.add_child(post)
	_level.add_child(_route)
	_guard = (load(GUARD_SCENE) as PackedScene).instantiate()
	_guard.name = "GameFlowTestGuard"
	_guard.patrol_route = _route
	_guard.position = at + Vector3(0, 0.05, 0)
	_guard.rotation.y = yaw
	_level.add_child(_guard)
	await _frames(3)


func _until(done: Callable, max_frames: int) -> void:
	for i in max_frames:
		if done.call():
			return
		await _host.get_tree().physics_frame


func _frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
