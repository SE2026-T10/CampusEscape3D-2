class_name ObjectiveHud
extends CanvasLayer

## Player-facing objective UI (a production HUD, not a debug tool):
##   - Panel (top right): the current objective and its hint, then a checklist
##     of every objective: [x] done, [>] current, [ ] still locked
##   - Interaction prompt under the crosshair, e.g. "[E] Take the access card",
##     drawn as a key cap and the action; it fades in and out
##   - Short messages: objective done, checkpoint reached, exit locked
##   - The panel header counts progress ("OBJECTIVE 2/5") and the panel flashes
##     when a new objective starts
## The end-of-level screen and restarting belong to GameMenus / GameFlow.
## Everything shown comes from ObjectiveManager, CheckpointManager, the exit
## door and the player's PlayerInteractor.

const COLOUR_DONE := Color(0.45, 0.85, 0.55)
const COLOUR_CURRENT := Color(1, 1, 1)
const COLOUR_LOCKED := Color(0.6, 0.62, 0.66)
const COLOUR_WARNING := Color(1.0, 0.45, 0.35)
const COLOUR_GOOD := Color(0.45, 0.95, 0.6)
## Seconds a message stays on screen (it fades during the last second).
const MESSAGE_TIME := 3.5

var _panel: PanelContainer
var _current: Label
var _hint: Label
var _list: RichTextLabel
var _prompt: Label
var _prompt_box: PanelContainer
var _prompt_key: Label
var _prompt_alpha := 0.0
var _header: Label
var _message: Label
var _message_left := 0.0
var _flash := 0.0
var _last_objective := &""


func _ready() -> void:
	layer = 6
	_build_panel()
	_build_prompt()

	_message = _make_label(26, HORIZONTAL_ALIGNMENT_CENTER)
	_message.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_message.position = Vector2(-450, -200)
	_message.size = Vector2(900, 40)
	add_child(_message)

	_connect_signals.call_deferred()


func _connect_signals() -> void:
	var objectives := ObjectiveManager.find(self)
	if objectives:
		objectives.objective_completed.connect(_on_objective_completed)
	var checkpoints := CheckpointManager.find(self)
	if checkpoints:
		checkpoints.checkpoint_activated.connect(func(cp: Checkpoint): show_message("Checkpoint reached: %s" % cp.checkpoint_name, COLOUR_GOOD))
	# Doors that refuse the player (the exit, and any access door) explain why.
	for node in get_tree().get_nodes_in_group("interactables"):
		if node.has_signal("rejected"):
			node.rejected.connect(func(reason: String): show_message(reason, COLOUR_WARNING))
		if node.has_signal("opened"):
			node.opened.connect(func(): show_message("%s opened" % node.get("door_name"), COLOUR_GOOD))


func _process(delta: float) -> void:
	var objectives := ObjectiveManager.find(self)
	var finished := objectives != null and objectives.is_finished()
	_update_panel(objectives)
	_update_prompt(delta)
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		_panel.self_modulate = Color.WHITE.lerp(Color(1.6, 1.4, 0.8), _flash / 0.8)
	if _message_left > 0.0:
		_message_left -= delta
		_message.modulate.a = clampf(_message_left, 0.0, 1.0)
		if _message_left <= 0.0:
			_message.text = ""
	_panel.visible = not finished
	_prompt_box.visible = not finished
	_message.visible = not finished


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


## Splits a prompt into its key and action: "[E] Escape" → ["E", "Escape"].
static func split_prompt(text: String) -> PackedStringArray:
	if text.begins_with("[") and text.find("] ") > 1:
		var end := text.find("] ")
		return PackedStringArray([text.substr(1, end - 1), text.substr(end + 2)])
	return PackedStringArray(["", text])


## "OBJECTIVE 2/5": the current objective's number out of all of them.
func get_header_text() -> String:
	var objectives := ObjectiveManager.find(self)
	if objectives == null or objectives.get_ids().is_empty():
		return "OBJECTIVE"
	var ids := objectives.get_ids()
	var index := ids.find(objectives.current())
	return "OBJECTIVE %d/%d" % [(index + 1) if index >= 0 else ids.size(), ids.size()]


func get_message_text() -> String:
	return _message.text


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
	if id != _last_objective:
		if _last_objective != &"":
			_flash = 0.8
		_last_objective = id
	_header.text = get_header_text()
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
	_header = _make_label(14, HORIZONTAL_ALIGNMENT_LEFT)
	_header.text = "OBJECTIVE"
	_header.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	box.add_child(_header)
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


func _update_prompt(delta: float) -> void:
	var text := get_prompt_text()
	if text != "":
		var parts := split_prompt(text)
		_prompt_key.text = parts[0]
		_prompt_key.get_parent().visible = parts[0] != ""
		_prompt.text = parts[1]
		_prompt.add_theme_color_override("font_color", COLOUR_WARNING if text.contains("locked") or text.contains("not yet") else Color.WHITE)
	_prompt_alpha = move_toward(_prompt_alpha, 1.0 if text != "" else 0.0, delta * 8.0)
	_prompt_box.modulate.a = _prompt_alpha


func _build_prompt() -> void:
	# A centred row under the crosshair: [ E ] Take the access card
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_CENTER)
	centre.position = Vector2(-300, 34)
	centre.size = Vector2(600, 40)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_prompt_box = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.6)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_prompt_box.add_theme_stylebox_override("panel", style)
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_box.modulate.a = 0.0
	centre.add_child(_prompt_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_prompt_box.add_child(row)
	var cap := PanelContainer.new()
	var cap_style := StyleBoxFlat.new()
	cap_style.bg_color = Color(0.92, 0.92, 0.88)
	cap_style.border_color = Color(0.55, 0.55, 0.5)
	cap_style.border_width_bottom = 3
	cap_style.set_corner_radius_all(4)
	cap_style.content_margin_left = 8
	cap_style.content_margin_right = 8
	cap.add_theme_stylebox_override("panel", cap_style)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cap)
	_prompt_key = Label.new()
	_prompt_key.add_theme_font_size_override("font_size", 18)
	_prompt_key.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
	_prompt_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(_prompt_key)
	_prompt = _make_label(20, HORIZONTAL_ALIGNMENT_LEFT)
	row.add_child(_prompt)


func _make_label(font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
