extends RefCounted

## Map selection tests (Expanded Library Phase 2). Called from tests/test_scene.gd.
##
##   A. The catalog: both maps, unique ids, scenes that load, the tutorial first.
##   B. The main menu: one button per map in catalog order, Library Tutorial
##      focused, Up/Down reach every button, each button requests its own scene
##      once, start_game() still means the tutorial, Quit still quits.
##   C. Each map, loaded twice: exactly one of each level system, Restart
##      requests the same map, Main menu requests the menu, each signal
##      connection made once, and everything freed when the map is left.
## Scene changes are stubbed here (a real change would end the test runner);
## tools/map_flow.gd repeats the transitions with real scene changes.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const TestUtils := preload("res://tests/test_utils.gd")
const LEVEL_SYSTEMS := ["game_flow", "stealth_director", "noise_system", "audio_director", "player"]
const MISSION_SYSTEMS := ["objective_manager", "checkpoint_manager"]
## A point on each map's navmesh, to wait for navigation (the spawn).
const NAV_PROBE := {
	&"library_tutorial": Vector3(0, 0, 18),
	&"expanded_library": Vector3(0, 0.05, 32),
}

var failures: Array[String] = []
var _host: Node


func run(host: Node) -> Array[String]:
	_host = host
	_check_catalog()
	await _check_menu()
	for level in LevelCatalog.LEVELS:
		var first := await _check_level(level)
		var second := await _check_level(level)
		_expect(first == second, "%s: the second load made different connections %s than the first %s (repeated connections?)." % [
			level.title, second, first])
		print("  [maps] %s: one of each system, Restart → %s, Main menu → menu, connections %s, all freed on leaving (loaded twice)" % [
			level.title, String(level.scene).get_file(), first])
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[maps] " + message)


# --- A. Catalog --------------------------------------------------------------------------------

func _check_catalog() -> void:
	var ids := LevelCatalog.ids()
	_expect(ids.size() >= 2 and ids.has(LevelCatalog.TUTORIAL) and ids.has(LevelCatalog.EXPANDED), "The catalog must offer both maps.")
	_expect(ids[0] == LevelCatalog.TUTORIAL, "The Library Tutorial must stay the first (default) map.")
	var unique := {}
	for level in LevelCatalog.LEVELS:
		unique[level.id] = true
		_expect(level.title != "" and level.description != "", "Map %s needs a title and a description." % level.id)
		_expect(load(level.scene) is PackedScene, "Map %s: its scene %s must load." % [level.id, level.scene])
		_expect(LevelCatalog.id_of_scene(level.scene) == level.id, "Map %s: id_of_scene must find it again." % level.id)
	_expect(unique.size() == LevelCatalog.LEVELS.size(), "Map ids must be unique.")
	_expect(LevelCatalog.scene_of(LevelCatalog.TUTORIAL) == MainMenu.LEVEL_SCENE, "The tutorial entry must be the scene the menu always started.")
	_expect(LevelCatalog.scene_of(&"no_such_map") == "", "An unknown map has no scene.")
	print("  [maps] catalog: %s, tutorial first" % [ids])


# --- B. Main menu ------------------------------------------------------------------------------

func _check_menu() -> void:
	for level in LevelCatalog.LEVELS:
		var menu := await _open_menu()
		var requests: Array = menu.get_meta("requests")
		_expect(menu.level_buttons.size() == LevelCatalog.LEVELS.size(), "The menu needs one button per map.")
		_expect(menu.start_button == menu.level_buttons[LevelCatalog.TUTORIAL] and menu.start_button.text == "Library Tutorial",
			"start_button must be the Library Tutorial button.")
		_expect(menu.expanded_button == menu.level_buttons[LevelCatalog.EXPANDED] and menu.expanded_button.text == "Expanded Library",
			"expanded_button must be the Expanded Library button.")
		_expect(menu.start_button.has_focus(), "The Library Tutorial button should have keyboard focus.")
		# Keyboard: Down walks tutorial → expanded → Quit, Up walks back.
		var down := menu.start_button.find_valid_focus_neighbor(SIDE_BOTTOM)
		_expect(down == menu.expanded_button and menu.expanded_button.find_valid_focus_neighbor(SIDE_BOTTOM) == menu.quit_button
			and menu.quit_button.find_valid_focus_neighbor(SIDE_TOP) == menu.expanded_button,
			"Up/Down must move between the map buttons and Quit.")
		var button: Button = menu.level_buttons[level.id]
		button.pressed.emit()
		button.pressed.emit()
		menu.start_button.pressed.emit()
		_expect(requests == [level.scene], "%s should request %s once, even with more presses (got %s)." % [level.title, level.scene, requests])
		_expect(not _host.get_tree().paused, "The menu must not leave the game paused.")
		await _close(menu)
	# The old entry point still starts the tutorial, unknown maps are refused, Quit still quits.
	var menu := await _open_menu()
	var requests: Array = menu.get_meta("requests")
	_expect(not menu.start_level(&"no_such_map") and requests.is_empty(), "An unknown map must not load anything.")
	_expect(menu.start_game() and requests == [MainMenu.LEVEL_SCENE], "start_game() must still start the tutorial.")
	menu.quit_button.pressed.emit()
	_expect(menu.get_meta("quits")[0] == 1, "Quit should quit the game.")
	await _close(menu)
	print("  [maps] menu: %d map buttons in catalog order, Library Tutorial focused, Up/Down reach every button, each button loads its map once, Quit quits" % LevelCatalog.LEVELS.size())


func _open_menu() -> MainMenu:
	var menu: MainMenu = (load(MAIN_MENU) as PackedScene).instantiate()
	var requests: Array[String] = []
	var quits := [0]
	menu.change_scene = func(path: String): requests.append(path)
	menu.quit_game = func(): quits[0] += 1
	menu.set_meta("requests", requests)
	menu.set_meta("quits", quits)
	_host.add_child(menu)
	await _frames(2)
	return menu


func _close(node: Node) -> void:
	node.queue_free()
	await _frames(2)


# --- C. Each map -------------------------------------------------------------------------------

## Loads the map, checks it, leaves it. Returns its signal connection counts.
func _check_level(level: Dictionary) -> Dictionary:
	var scene: Node3D = (load(level.scene) as PackedScene).instantiate()
	var ready: bool = await TestUtils.add_level_and_wait_for_navigation(_host, scene, NAV_PROBE[level.id])
	_expect(ready, "%s: navigation never became ready." % level.title)
	await _frames(3)
	# Exactly one of each level system, and none left over from earlier loads.
	var has_mission := scene.has_node("Gameplay/ObjectiveManager")
	for g in LEVEL_SYSTEMS + MISSION_SYSTEMS:
		var expected := 1 if g in LEVEL_SYSTEMS or has_mission else 0
		var all := _host.get_tree().get_nodes_in_group(g)
		var mine := all.filter(func(n): return scene.is_ancestor_of(n))
		_expect(mine.size() == expected and all.size() == expected, "%s: expected %d node(s) in group '%s', found %d (%d in the whole tree)." % [
			level.title, expected, g, mine.size(), all.size()])
	var flow := GameFlow.find(scene)
	var director := StealthDirector.find(scene)
	var connections := {}
	if flow and director:
		connections = {"player_caught": director.player_caught.get_connections().size(),
			"level_reset": director.level_reset.get_connections().size(),
			"state_changed": flow.state_changed.get_connections().size()}
		_expect(connections.player_caught == 1, "%s: GameFlow must listen to player_caught exactly once." % level.title)
		_expect(connections.level_reset == (2 if has_mission else 1), "%s: level_reset should reach GameFlow%s once each." % [
			level.title, " and CheckpointManager" if has_mission else ""])
		# Restart reloads this map; Main menu goes to the menu (scene changes recorded, not made).
		var requests: Array[String] = []
		flow.change_scene = func(path: String): requests.append(path)
		_expect(flow.restart() and requests == [level.scene], "%s: Restart should reload %s (got %s)." % [level.title, level.scene, requests])
		flow.scene_requests.clear()
		requests.clear()
		_expect(flow.go_to_main_menu() and requests == [MAIN_MENU], "%s: Main menu should load the menu (got %s)." % [level.title, requests])
		_expect(not _host.get_tree().paused, "%s: leaving must unpause the game." % level.title)
	else:
		_expect(false, "%s: GameFlow and StealthDirector must exist." % level.title)
	# Leave: the level and its systems are freed, no group keeps a reference.
	var refs: Array[WeakRef] = [weakref(scene), weakref(flow), weakref(director)]
	scene.queue_free()
	await _frames(3)
	for r in refs:
		_expect(r.get_ref() == null, "%s: %s was not freed when the map was left." % [level.title, r])
	for g in LEVEL_SYSTEMS + MISSION_SYSTEMS:
		_expect(_host.get_tree().get_nodes_in_group(g).is_empty(), "%s: group '%s' still has nodes after leaving." % [level.title, g])
	return connections


func _frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
