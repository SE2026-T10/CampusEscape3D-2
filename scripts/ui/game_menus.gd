class_name GameMenus
extends CanvasLayer

## The in-level menus, shown according to GameFlow's state:
##   - PAUSED: "PAUSED" with Resume / Restart level / Main menu, and the controls
##   - WIN: "ESCAPED" with the time and catches, Play again / Main menu
## Runs while the tree is paused (PROCESS_MODE_ALWAYS). Keyboard works too:
## the first button has focus, and Enter or Space presses it.

var pause_panel: Control
var win_panel: Control
var resume_button: Button
var restart_button: Button
var pause_menu_button: Button
var play_again_button: Button
var win_menu_button: Button

var _pause_time: Label
var _win_stats: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel = _overlay(Color(0, 0, 0, 0.55))
	var box := MenuStyle.centred_panel(pause_panel)
	box.add_child(MenuStyle.title("PAUSED"))
	_pause_time = MenuStyle.label("", 16)
	box.add_child(_pause_time)
	resume_button = _add_button(box, "Resume", func(): _flow().resume())
	restart_button = _add_button(box, "Restart level", func(): _flow().restart())
	pause_menu_button = _add_button(box, "Main menu", func(): _flow().go_to_main_menu())
	var controls := MenuStyle.label("WASD move · Shift sprint · C/Ctrl crouch · E use · Esc resume", 14)
	controls.modulate = Color(1, 1, 1, 0.7)
	box.add_child(controls)

	win_panel = _overlay(Color(0.02, 0.16, 0.09, 0.82))
	var win_box := MenuStyle.centred_panel(win_panel)
	win_box.add_child(MenuStyle.title("ESCAPED", 56, Color(0.5, 1.0, 0.6)))
	win_box.add_child(MenuStyle.label("You got out of the library with the access card.", 18))
	_win_stats = MenuStyle.label("", 22)
	win_box.add_child(_win_stats)
	play_again_button = _add_button(win_box, "Play again", func(): _flow().restart())
	win_menu_button = _add_button(win_box, "Main menu", func(): _flow().go_to_main_menu())
	_connect_flow.call_deferred()


func _connect_flow() -> void:
	var flow := _flow()
	if flow:
		flow.state_changed.connect(func(_from, _to): refresh())
	refresh()


## Shows the panel for the current game state and focuses its first button.
func refresh() -> void:
	var flow := _flow()
	var game_state := flow.state if flow else GameStateMachine.State.PLAYING
	var was_paused := pause_panel.visible
	var was_won := win_panel.visible
	pause_panel.visible = game_state == GameStateMachine.State.PAUSED
	win_panel.visible = game_state == GameStateMachine.State.WIN
	if pause_panel.visible:
		_pause_time.text = "Time played %s" % format_time(flow.play_time)
		if not was_paused:
			resume_button.grab_focus()
	if win_panel.visible:
		_win_stats.text = get_win_text()
		if not was_won:
			play_again_button.grab_focus()


func get_win_text() -> String:
	var flow := _flow()
	var director := StealthDirector.find(self)
	var catches := director.catches if director else 0
	return "Time %s  ·  caught %d time%s" % [format_time(flow.play_time if flow else 0.0), catches, "" if catches == 1 else "s"]


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]


func _flow() -> GameFlow:
	return GameFlow.find(self)


func _overlay(colour: Color) -> Control:
	var rect := ColorRect.new()
	rect.color = colour
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.visible = false
	add_child(rect)
	return rect


func _add_button(box: VBoxContainer, text: String, action: Callable) -> Button:
	var b := MenuStyle.button(text)
	b.pressed.connect(action)
	box.add_child(b)
	return b
