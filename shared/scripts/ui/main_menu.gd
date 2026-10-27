class_name MainMenu
extends Control

## The title screen: choose a map (LevelCatalog), Quit, and the controls. The
## game's main scene. The mouse cursor is visible here; the level captures it
## when play starts.
##
## One button per map, in catalog order. The first (the Library Tutorial) has
## keyboard focus, so Enter starts the tutorial exactly as the old single
## "Start game" button did; Up / Down move between the buttons.

## The tutorial: what start_game() loads (kept for existing callers and tests).
const LEVEL_SCENE := "res://maps/tutorial/scenes/library_graybox.tscn"

## The tutorial's button (the first map). Kept under its old name.
var start_button: Button
## The Expanded Library's button.
var expanded_button: Button
var quit_button: Button
## Expansion Phase 7: the settings screen (SettingsPanel) and its button.
var settings_button: Button
var settings_panel: SettingsPanel
## Map id → its button, for every map in the catalog.
var level_buttons := {}
## Optional map test variants, kept next to their normal map buttons.
var test_buttons := {}
## How the level is loaded and how the game quits. Tests replace these.
var change_scene: Callable
var quit_game: Callable
## Scene changes requested so far (at most one).
var scene_requests: Array[String] = []


func _init() -> void:
	change_scene = func(path: String): get_tree().change_scene_to_file.call_deferred(path)
	quit_game = func(): get_tree().quit()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameSettings.apply(get_tree())
	var background := ColorRect.new()
	background.color = Color(0.05, 0.07, 0.1)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	# More maps and larger interface settings must not hide the last buttons.
	var scroll := ScrollContainer.new()
	scroll.name = "MapScroll"
	scroll.follow_focus = true
	scroll.resized.connect(_reveal_focused_button.call_deferred)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := MenuStyle.centred_panel(scroll)
	var centre := box.get_parent().get_parent() as CenterContainer
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(MenuStyle.title("CAMPUS ESCAPE 3D", 54, MenuStyle.ACCENT))
	box.add_child(MenuStyle.label("Choose an independent mission. Stay unseen, finish your objective, and escape.", 18))
	box.add_child(HSeparator.new())
	box.add_child(MenuStyle.title("CHOOSE A MAP", 16, MenuStyle.ACCENT))
	for level in LevelCatalog.LEVELS:
		var button := MenuStyle.button(level.title)
		var id: StringName = level.id
		button.pressed.connect(func(): start_level(id))
		box.add_child(button)
		var description := MenuStyle.label(level.description, 14)
		description.modulate = Color(1, 1, 1, 0.7)
		box.add_child(description)
		level_buttons[id] = button
		if level.get("test_scene", "") != "":
			var test_button := MenuStyle.button(level.test_title)
			test_button.pressed.connect(func(): start_test_level(id))
			box.add_child(test_button)
			var test_description := MenuStyle.label(level.test_description, 14)
			test_description.modulate = Color(1, 1, 1, 0.7)
			box.add_child(test_description)
			test_buttons[id] = test_button
	start_button = level_buttons[LevelCatalog.TUTORIAL]
	expanded_button = level_buttons[LevelCatalog.EXPANDED]
	box.add_child(HSeparator.new())
	settings_button = MenuStyle.button("Settings")
	settings_button.pressed.connect(open_settings)
	box.add_child(settings_button)
	quit_button = MenuStyle.button("Quit")
	quit_button.pressed.connect(quit)
	box.add_child(quit_button)
	var controls := MenuStyle.label(
		"WASD move  ·  Shift sprint  ·  C / Ctrl crouch  ·  E use  ·  Esc pause\nStay out of the guards' sight. Crouch to stay quiet. Use cover.", 15)
	controls.modulate = Color(1, 1, 1, 0.75)
	box.add_child(controls)
	settings_panel = SettingsPanel.new()
	add_child(settings_panel)
	settings_panel.closed.connect(func(): settings_button.grab_focus())
	start_button.grab_focus()


func _reveal_focused_button() -> void:
	# Container minimum sizes settle after the viewport scale changes.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var focus := get_viewport().gui_get_focus_owner()
	var scroll := get_node_or_null("MapScroll") as ScrollContainer
	if focus and scroll and scroll.is_ancestor_of(focus):
		scroll.ensure_control_visible(focus)


func open_settings() -> void:
	settings_panel.open()


## Loads the tutorial. Returns false if a map was already requested.
func start_game() -> bool:
	return start_level(LevelCatalog.TUTORIAL)


## Loads the map `id` from the catalog. Returns false if it is unknown or a map
## was already requested (a second press while the scene changes is ignored).
func start_level(id: StringName) -> bool:
	return _start_scene(LevelCatalog.scene_of(id))


## Test mode is encoded by its scene, so Restart never loses the selection.
func start_test_level(id: StringName) -> bool:
	return _start_scene(LevelCatalog.test_scene_of(id))


func _start_scene(path: String) -> bool:
	if path == "" or not scene_requests.is_empty():
		return false
	scene_requests.append(path)
	change_scene.call(path)
	return true


func quit() -> void:
	quit_game.call()
