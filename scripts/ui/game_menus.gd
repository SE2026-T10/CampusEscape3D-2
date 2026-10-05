class_name GameMenus
extends CanvasLayer

## The in-level menus, shown according to GameFlow's state:
##   - PAUSED: "PAUSED" with Resume / Restart level / Main menu, and the controls
##   - WIN: "ESCAPED" with the time and catches, Play again / Main menu
## Runs while the tree is paused (PROCESS_MODE_ALWAYS). Keyboard works too:
## the first button has focus, and Enter or Space presses it.
## Panels fade in; the win title pops in. Buttons click and tick on hover
## (MenuStyle); pause, resume and victory sounds come from AudioDirector.

var pause_panel: Control
var win_panel: Control
var resume_button: Button
var restart_button: Button
var pause_menu_button: Button
var play_again_button: Button
var win_menu_button: Button

## The win screen's "ESCAPED" title (it pops in when the screen opens).
var win_title: Label

var _pause_time: Label
var _win_stats: Label
var _win_objectives: Label


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
	# The title sits in a plain Control, not directly in the VBoxContainer:
	# containers reset their children's scale, which would cancel the pop.
	win_title = MenuStyle.title("ESCAPED", 56, Color(0.5, 1.0, 0.6))
	var title_holder := Control.new()
	win_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_holder.add_child(win_title)
	win_box.add_child(title_holder)
	# The holder takes the title's size (known once the theme applies, in the tree).
	var fit := func(): title_holder.custom_minimum_size = win_title.get_combined_minimum_size()
	win_title.minimum_size_changed.connect(fit)
	fit.call()
	win_box.add_child(MenuStyle.label("You got out of the library with the access card.", 18))
	_win_stats = MenuStyle.label("", 22)
	win_box.add_child(_win_stats)
	_win_objectives = MenuStyle.label("", 16)
	_win_objectives.add_theme_color_override("font_color", Color(0.7, 0.9, 0.75))
	win_box.add_child(_win_objectives)
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
			_fade_in(pause_panel, 0.15)
	if win_panel.visible:
		_win_stats.text = get_win_text()
		_win_objectives.text = get_objectives_text()
		if not was_won:
			play_again_button.grab_focus()
			_fade_in(win_panel, 0.6)
			_pop_title()


## Scales the win title from 140% to 100% around its centre. Waits one frame
## first, so the panel that just appeared has been laid out and the title's
## size (and so its centre) is the real one.
func _pop_title() -> void:
	win_title.scale = Vector2.ONE * 1.4
	await get_tree().process_frame
	win_title.pivot_offset = win_title.size / 2.0
	create_tween().tween_property(win_title, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## "Objectives 5/5 complete" for the win screen.
func get_objectives_text() -> String:
	var objectives := ObjectiveManager.find(self)
	if objectives == null:
		return ""
	var done := 0
	for id in objectives.get_ids():
		if objectives.get_state(id) == ObjectiveManager.State.COMPLETED:
			done += 1
	return "Objectives %d/%d complete" % [done, objectives.get_ids().size()]


func get_win_text() -> String:
	var flow := _flow()
	var director := StealthDirector.find(self)
	var catches := director.catches if director else 0
	return "Time %s  ·  caught %d time%s" % [format_time(flow.play_time if flow else 0.0), catches, "" if catches == 1 else "s"]


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]


func _fade_in(panel: Control, seconds: float) -> void:
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, seconds)


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
