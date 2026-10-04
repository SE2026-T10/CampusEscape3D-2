class_name MainMenu
extends Control

## The title screen: Start game / Quit, and the controls. The game's main scene.
## The mouse cursor is visible here; the level captures it when play starts.

const LEVEL_SCENE := "res://scenes/level/library_graybox.tscn"

var start_button: Button
var quit_button: Button
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
	box.add_child(MenuStyle.label("Sneak through the university library, take the access card, and get out unseen.", 18))
	box.add_child(HSeparator.new())
	start_button = MenuStyle.button("Start game")
	start_button.pressed.connect(start_game)
	box.add_child(start_button)
	quit_button = MenuStyle.button("Quit")
	quit_button.pressed.connect(quit)
	box.add_child(quit_button)
	var controls := MenuStyle.label(
		"WASD move  ·  Shift sprint  ·  C / Ctrl crouch  ·  E use  ·  Esc pause\nStay out of the guards' sight. Crouch to stay quiet. Hide in the study carrels.", 15)
	controls.modulate = Color(1, 1, 1, 0.75)
	box.add_child(controls)
	start_button.grab_focus()


## Loads the level. Returns false if it was already requested.
func start_game() -> bool:
	if not scene_requests.is_empty():
		return false
	scene_requests.append(LEVEL_SCENE)
	change_scene.call(LEVEL_SCENE)
	return true


func quit() -> void:
	quit_game.call()
