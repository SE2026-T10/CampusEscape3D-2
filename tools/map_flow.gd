extends SceneTree

## QA run of map selection with real scene changes, repeated (the automated
## tests stub scene changes, because changing scene would end the test runner).
## Starting at the main menu, three times over:
##   Library Tutorial → Esc → Restart → Esc → Main menu →
##   Expanded Library → Esc → Restart → Esc → Main menu
## then Quit. After every scene change it checks:
##   - the right scene is loaded (a new instance; Restart reloads the same map)
##   - the previous scene and its systems are freed (no stale references)
##   - exactly one of each level system (no duplicates), none on the menu
##   - each level's signal connections are made once (counts do not grow)
##   - the game is playing and unpaused in a level, the cursor free on the menu
##   - node and orphan counts on the menu do not grow from cycle to cycle
##   - the mission starts clean on every load: progress made before Restart
##     (first objectives completed, access doors opened) is gone afterwards
##
##   godot --headless --path . --script res://tools/map_flow.gd
##   godot --path . --resolution 1280x720 --script res://tools/map_flow.gd -- --out=docs/expanded/phase2
##
## Prints "MAP FLOW PASSED" or the failed steps, and exits 0 / 1.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const CYCLES := 3
const G := GameStateMachine.State
## Groups of the level-wide systems: exactly one in every level, none on the menu.
const LEVEL_SYSTEMS := ["game_flow", "stealth_director", "noise_system", "audio_director", "player"]
## Mission systems: one in each map.
const MISSION_SYSTEMS := ["objective_manager", "checkpoint_manager"]

var _out := ""
var _failures: Array[String] = []
var _step := 0
var _levels_loaded := 0
var _menu_counts: Array[Dictionary] = []
var _connection_counts := {}   # scene path → connection counts on its first load
var _menu_visits := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = "res://" + a.trim_prefix("--out=")
	if _out != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	change_scene_to_file(MAIN_MENU)
	var scene: Node = await _wait_for_scene(0, false)
	_check(scene is MainMenu, "The game opens at the main menu.")
	_check_menu(scene, 0)
	await _shot("main_menu")
	var tutorial := LevelCatalog.scene_of(LevelCatalog.TUTORIAL)
	var expanded := LevelCatalog.scene_of(LevelCatalog.EXPANDED)
	for cycle in CYCLES:
		for path in [tutorial, expanded]:
			var menu := current_scene as MainMenu
			var button: Button = menu.start_button if path == tutorial else menu.expanded_button
			var title: String = LevelCatalog.get_level(LevelCatalog.id_of_scene(path)).title
			# Select the map.
			var before: WeakRef = weakref(current_scene)
			var before_id := current_scene.get_instance_id()
			button.pressed.emit()
			var level: Node = await _wait_for_scene(before_id, true)
			_check_level(level, path, before, "Cycle %d: %s selected from the menu" % [cycle + 1, title])
			_check(_mission_is_clean(level), "Cycle %d: %s starts with a clean mission." % [cycle + 1, title])
			if cycle == 0:
				await _shot("level_" + String(LevelCatalog.id_of_scene(path)))
			# Make some progress, to check that Restart throws it away.
			var made := _make_progress(level)
			_check(made, "Cycle %d: %s — progress made before restarting." % [cycle + 1, title])
			# Restart it from the pause menu.
			before = weakref(level)
			before_id = level.get_instance_id()
			_press("pause")
			await _wait(0.2)
			_check(GameFlow.find(level).state == G.PAUSED and paused, "Cycle %d: %s — Esc pauses." % [cycle + 1, title])
			(level.get_node("GameMenus") as GameMenus).restart_button.pressed.emit()
			level = await _wait_for_scene(before_id, true)
			_check_level(level, path, before, "Cycle %d: %s restarted (Pause → Restart level)" % [cycle + 1, title])
			_check(_mission_is_clean(level), "Cycle %d: %s restarted with a clean mission (no progress, every access door closed, no checkpoint)." % [cycle + 1, title])
			# Back to the menu.
			before = weakref(level)
			before_id = level.get_instance_id()
			_press("pause")
			await _wait(0.2)
			(level.get_node("GameMenus") as GameMenus).pause_menu_button.pressed.emit()
			var back: Node = await _wait_for_scene(before_id, false)
			await _wait(0.3)
			_check(back is MainMenu and before.get_ref() == null,
				"Cycle %d: %s → Main menu: back at the menu, the level freed." % [cycle + 1, title])
			_check_menu(back, cycle + 1)
	# No growth across cycles on the menu.
	var first: Dictionary = _menu_counts[2]   # back from the first Expanded Library visit
	var last: Dictionary = _menu_counts[_menu_counts.size() - 1]
	_check(last.nodes <= first.nodes and last.orphans <= first.orphans and last.root_children == first.root_children,
		"No leftovers from cycle 1 to cycle %d (menu after the Expanded Library): nodes %d → %d, orphan nodes %d → %d, root children %d → %d." % [
			CYCLES, first.nodes, last.nodes, first.orphans, last.orphans, first.root_children, last.root_children])
	# Quit from the menu (stubbed, so the result can be printed first).
	var menu_end := current_scene as MainMenu
	var quit_called := {"yes": false}
	menu_end.quit_game = func(): quit_called.yes = true
	menu_end.quit_button.pressed.emit()
	_check(quit_called.yes, "Quit quits.")
	if _failures.is_empty():
		print("MAP FLOW PASSED (%d checks, %d levels loaded, %d cycles)" % [_step, _levels_loaded, CYCLES])
	else:
		print("MAP FLOW FAILED: %d of %d checks" % [_failures.size(), _step])
		for f in _failures:
			print("  - " + f)
	# Leave the menu scene and let the audio server release sounds before quitting (as tools/qa_flow.gd does).
	current_scene.queue_free()
	for i in 60:
		OS.delay_msec(5)
		await process_frame
	quit(0 if _failures.is_empty() else 1)


func _check_level(level: Node, path: String, previous: WeakRef, what: String) -> void:
	_levels_loaded += 1
	var ok := level != null and level.scene_file_path == path and previous.get_ref() == null
	var flow := GameFlow.find(level) if level else null
	ok = ok and flow != null and flow.state == G.PLAYING and not paused
	var counts := _group_counts()
	for g in LEVEL_SYSTEMS:
		ok = ok and counts[g] == 1
	var has_mission := level != null and level.has_node("Gameplay/ObjectiveManager")
	for g in MISSION_SYSTEMS:
		ok = ok and counts[g] == (1 if has_mission else 0)
	ok = ok and _count_nodes(root, func(n): return n is MainMenu) == 0
	# Each connection made once: the same counts every time this map loads.
	var connections := _connections(level) if level else {}
	if not _connection_counts.has(path):
		_connection_counts[path] = connections
	var same: bool = connections == _connection_counts[path]
	ok = ok and same and connections.get("player_caught", 0) == 1
	_check(ok, "%s: loads %s, previous scene freed, playing and unpaused, one of each system %s, connections %s%s." % [
		what, path.get_file(), counts, connections, "" if same else " (first load: %s)" % [_connection_counts[path]]])


## Completes the first two objectives and opens every access door. True if anything changed.
func _make_progress(level: Node) -> bool:
	var objectives := level.get_node_or_null("Gameplay/ObjectiveManager") as ObjectiveManager
	if objectives == null:
		return false
	var ids := objectives.get_ids()
	objectives.complete(ids[0])
	objectives.complete(ids[1])
	for door in get_nodes_in_group("access_doors"):
		door.open()
	return objectives.completed_count() == 2


func _mission_is_clean(level: Node) -> bool:
	var objectives := level.get_node_or_null("Gameplay/ObjectiveManager") as ObjectiveManager
	var checkpoints := level.get_node_or_null("Gameplay/CheckpointManager") as CheckpointManager
	if objectives == null or checkpoints == null:
		return false
	var doors_closed := get_nodes_in_group("access_doors").all(func(d): return not d.is_open)
	return objectives.completed_count() == 0 and objectives.current() == objectives.get_ids()[0] \
		and doors_closed and checkpoints.active == null


func _check_menu(menu: Node, _index: int) -> void:
	_menu_visits += 1
	var counts := _group_counts()
	var none := true
	for g in LEVEL_SYSTEMS + MISSION_SYSTEMS:
		none = none and counts[g] == 0
	var menus := _count_nodes(root, func(n): return n is MainMenu)
	var entry := {"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), "root_children": root.get_child_count()}
	_menu_counts.append(entry)
	var m := menu as MainMenu
	_check(m != null and menus == 1 and none and not paused and m.start_button.has_focus()
			and m.level_buttons.size() == LevelCatalog.LEVELS.size(),
		"Menu (visit %d): one menu, no level systems left, unpaused, Library Tutorial focused, %d maps offered; nodes %d, orphans %d." % [
			_menu_visits, LevelCatalog.LEVELS.size(), entry.nodes, entry.orphans])


func _connections(level: Node) -> Dictionary:
	var director := StealthDirector.find(level)
	var flow := GameFlow.find(level)
	var result := {}
	if director:
		result.player_caught = director.player_caught.get_connections().size()
		result.level_reset = director.level_reset.get_connections().size()
		result.status_changed = director.status_changed.get_connections().size()
	if flow:
		result.state_changed = flow.state_changed.get_connections().size()
	return result


func _group_counts() -> Dictionary:
	var counts := {}
	for g in LEVEL_SYSTEMS + MISSION_SYSTEMS:
		counts[g] = get_nodes_in_group(g).size()
	return counts


func _count_nodes(node: Node, keep: Callable) -> int:
	var n := 1 if keep.call(node) else 0
	for child in node.get_children():
		n += _count_nodes(child, keep)
	return n


func _check(ok: bool, what: String) -> void:
	_step += 1
	print("  [%s] %d. %s" % ["ok" if ok else "FAIL", _step, what])
	if not ok:
		_failures.append(what)


## Waits for the current scene to become a new instance (a level with GameFlow,
## or the menu), then lets it settle.
func _wait_for_scene(previous_id: int, level: bool) -> Node:
	for i in 600:
		await process_frame
		var scene := current_scene
		if scene and scene.get_instance_id() != previous_id and (scene.has_node("GameFlow") if level else scene is MainMenu):
			for k in 30:
				await physics_frame
			return scene
	return null


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
	await _wait(0.5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(_out.path_join(name + ".png")))
