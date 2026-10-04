class_name ObjectiveHud
extends CanvasLayer

## Player-facing objective UI (a production HUD, not a debug tool):
##   - Panel (top right): the current objective and its hint, then a checklist
##     of every objective: [x] done, [>] current, [ ] still locked
##   - Interaction prompt under the crosshair, e.g. "[E] Take the access card"
##   - Short messages: objective done, checkpoint reached, exit locked
##   - "Escaped" screen with the time and the number of times caught;
##     the interact key starts the level again
## Everything shown comes from ObjectiveManager, CheckpointManager, the exit
## door and the player's PlayerInteractor.

const COLOUR_DONE := Color(0.45, 0.85, 0.55)
const COLOUR_CURRENT := Color(1, 1, 1)
const COLOUR_LOCKED := Color(0.6, 0.62, 0.66)
const COLOUR_WARNING := Color(1.0, 0.45, 0.35)
const COLOUR_GOOD := Color(0.45, 0.95, 0.6)
## Seconds a message stays on screen (it fades during the last second).
const MESSAGE_TIME := 3.5

## Seconds played since the level started (stops when the player escapes).
var elapsed := 0.0

var _panel: PanelContainer
var _current: Label
var _hint: Label
var _list: RichTextLabel
var _prompt: Label
var _message: Label
var _message_left := 0.0
var _escaped: ColorRect
var _escaped_label: Label


func _ready() -> void:
	layer = 6
	_build_panel()
	_prompt = _make_label(20, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.position = Vector2(-300, 34)
	_prompt.size = Vector2(600, 30)
	add_child(_prompt)

	_message = _make_label(26, HORIZONTAL_ALIGNMENT_CENTER)
	_message.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_message.position = Vector2(-450, -200)
	_message.size = Vector2(900, 40)
	add_child(_message)

	_escaped = ColorRect.new()
	_escaped.color = Color(0.02, 0.18, 0.1, 0.8)
	_escaped.set_anchors_preset(Control.PRESET_FULL_RECT)
	_escaped.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_escaped.visible = false
	_escaped_label = _make_label(40, HORIZONTAL_ALIGNMENT_CENTER)
	_escaped_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_escaped_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_escaped.add_child(_escaped_label)
	add_child(_escaped)
	_connect_signals.call_deferred()


func _connect_signals() -> void:
	var objectives := ObjectiveManager.find(self)
	if objectives:
		objectives.objective_completed.connect(_on_objective_completed)
	var checkpoints := CheckpointManager.find(self)
	if checkpoints:
		checkpoints.checkpoint_activated.connect(func(cp: Checkpoint): show_message("Checkpoint reached: %s" % cp.checkpoint_name, COLOUR_GOOD))
	for node in get_tree().get_nodes_in_group("interactables"):
		if node is ExitDoor:
			node.rejected.connect(func(reason: String): show_message(reason, COLOUR_WARNING))


func _process(delta: float) -> void:
	var objectives := ObjectiveManager.find(self)
	var finished := objectives != null and objectives.is_finished()
	if not finished:
		elapsed += delta
	_update_panel(objectives)
	_prompt.text = get_prompt_text()
	_prompt.add_theme_color_override("font_color", COLOUR_WARNING if _prompt.text.contains("locked") else Color.WHITE)
	if _message_left > 0.0:
		_message_left -= delta
		_message.modulate.a = clampf(_message_left, 0.0, 1.0)
		if _message_left <= 0.0:
			_message.text = ""
	_escaped.visible = finished
	_panel.visible = not finished
	_prompt.visible = not finished
	_message.visible = not finished
	if finished:
		_escaped_label.text = get_escape_text()


func _unhandled_input(event: InputEvent) -> void:
	if _escaped.visible and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()


## Current objective title, or "" when finished.
func get_current_text() -> String:
	var objectives := ObjectiveManager.find(self)
	if objectives == null or objectives.current() == &"":
		return ""
	return objectives.get_title(objectives.current())


## The checklist, one line per objective: "[x] …" done, "[>] …" current, "[ ] …" locked.
func get_lines() -> Array[String]:
	var lines: Array[String] = []
	var objectives := ObjectiveManager.find(self)
	if objectives == null:
		return lines
	for id in objectives.get_ids():
		var mark := "[ ]"
		match objectives.get_state(id):
			ObjectiveManager.State.COMPLETED:
				mark = "[x]"
			ObjectiveManager.State.ACTIVE:
				mark = "[>]"
		lines.append("%s %s" % [mark, objectives.get_title(id)])
	return lines


## "[E] …" for whatever the player is looking at, or "".
func get_prompt_text() -> String:
	var player := get_tree().get_first_node_in_group("player")
	var interactor := player.get_node_or_null("Interactor") as PlayerInteractor if player else null
	return interactor.get_prompt_text() if interactor else ""


func get_message_text() -> String:
	return _message.text


func get_escape_text() -> String:
	var director := StealthDirector.find(self)
	var catches := director.catches if director else 0
	var seconds := int(elapsed)
	return "ESCAPED\nTime %d:%02d  ·  caught %d time%s\n\nPress E to play again" % [
		seconds / 60, seconds % 60, catches, "" if catches == 1 else "s"]


func show_message(text: String, colour := Color.WHITE) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", colour)
	_message.modulate.a = 1.0
	_message_left = MESSAGE_TIME


func _on_objective_completed(id: StringName) -> void:
	var objectives := ObjectiveManager.find(self)
	if objectives and not objectives.is_finished():
		show_message(objectives.get_done_message(id), COLOUR_GOOD)


func _update_panel(objectives: ObjectiveManager) -> void:
	if objectives == null:
		_panel.visible = false
		return
	var id := objectives.current()
	_current.text = objectives.get_title(id)
	_hint.text = objectives.get_hint(id)
	var colours := {ObjectiveManager.State.COMPLETED: COLOUR_DONE, ObjectiveManager.State.ACTIVE: COLOUR_CURRENT,
		ObjectiveManager.State.LOCKED: COLOUR_LOCKED}
	var lines := get_lines()
	var ids := objectives.get_ids()
	var text := ""
	for i in ids.size():
		text += "[color=#%s]%s[/color]\n" % [colours[objectives.get_state(ids[i])].to_html(false), lines[i]]
	_list.text = text.strip_edges()


func _build_panel() -> void:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.62)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.position = Vector2(-384, 20)
	_panel.custom_minimum_size = Vector2(364, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)
	var header := _make_label(14, HORIZONTAL_ALIGNMENT_LEFT)
	header.text = "OBJECTIVE"
	header.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	box.add_child(header)
	_current = _make_label(23, HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(_current)
	_hint = _make_label(15, HORIZONTAL_ALIGNMENT_LEFT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", Color(0.82, 0.85, 0.9))
	box.add_child(_hint)
	box.add_child(HSeparator.new())
	_list = RichTextLabel.new()
	_list.bbcode_enabled = true
	_list.fit_content = true
	_list.scroll_active = false
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_theme_font_size_override("normal_font_size", 15)
	_list.add_theme_constant_override("outline_size", 5)
	_list.add_theme_color_override("font_outline_color", Color.BLACK)
	box.add_child(_list)


func _make_label(font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
