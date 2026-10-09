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
const LEVEL_SCENE := "res://scenes/level/library_graybox.tscn"

## The tutorial's button (the first map). Kept under its old name.
var start_button: Button
## The Expanded Library's button.
var expanded_button: Button
var quit_button: Button
## Map id → its button, for every map in the catalog.
var level_buttons := {}
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
	var background := ColorRect.new()
	background.color = Color(0.05, 0.07, 0.1)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var box := MenuStyle.centred_panel(self)
	box.add_child(MenuStyle.title("CAMPUS ESCAPE 3D", 54, MenuStyle.ACCENT))
	box.add_child(MenuStyle.label("Sneak through the university library, take what you came for, and get out unseen.", 18))
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
	start_button = level_buttons[LevelCatalog.TUTORIAL]
	expanded_button = level_buttons[LevelCatalog.EXPANDED]
	box.add_child(HSeparator.new())
	quit_button = MenuStyle.button("Quit")
	quit_button.pressed.connect(quit)
	box.add_child(quit_button)
	var controls := MenuStyle.label(
		"WASD move  ·  Shift sprint  ·  C / Ctrl crouch  ·  E use  ·  Esc pause\nStay out of the guards' sight. Crouch to stay quiet. Hide in the study carrels.", 15)
	controls.modulate = Color(1, 1, 1, 0.75)
	box.add_child(controls)
	start_button.grab_focus()


## Loads the tutorial. Returns false if a map was already requested.
func start_game() -> bool:
	return start_level(LevelCatalog.TUTORIAL)


## Loads the map `id` from the catalog. Returns false if it is unknown or a map
## was already requested (a second press while the scene changes is ignored).
func start_level(id: StringName) -> bool:
	var path := LevelCatalog.scene_of(id)
	if path == "" or not scene_requests.is_empty():
		return false
	scene_requests.append(path)
	change_scene.call(path)
	return true


func quit() -> void:
	quit_game.call()
