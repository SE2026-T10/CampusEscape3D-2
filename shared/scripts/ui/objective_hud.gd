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
##   - Levels whose objectives form a graph (prerequisites, optional ones; the
##     Expanded Library): the header counts mandatory objectives done
##     ("MISSION 3/8"), several may be current ([>]), and discovered optional
##     objectives are listed apart, under OPTIONAL
##   - In levels with an inventory (PlayerInventory enabled): the carried slots
##     (bottom centre, the selected one highlighted), item messages, and the
##     journal (left), opened with J or by reading a document: only clues and
##     documents (expansion Phase 7; the objectives are in the panel)
##   - Expanded Library (expansion Phase 7), a second panel (top left, hidden
##     while the journal is open): WAYS OUT, the
##     escape routes the player knows with the requirements they know, each
##     [x] met / [ ] not yet (the map provider); POWER, the circuits, once the
##     electrical room's switches have been seen; the checkpoint you return to
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
var _hold_bar: ProgressBar
var _prompt_alpha := 0.0
var _header: Label
var _message: Label
var _message_left := 0.0
var _flash := 0.0
var _last_objective := &""
var _slots: Control
var _journal: PanelContainer
## Expansion Phase 7: WAYS OUT / POWER / checkpoint (top left).
var _status_panel: PanelContainer
var _status_text: RichTextLabel
var _journal_text: RichTextLabel
## Document shown first in the journal (the one just read).
var _journal_focus := &""
var _journal_page := 0
## True when the journal was opened by reading a document: J then closes it.
var _journal_from_read := false
## Journal clue paging: the first clue on this page, whether it is a clues-only
## page, the first clue that did not fit (-1: all shown), the view it was laid out for.
var _clue_start := 0
var _clues_only := false
var _clue_next := -1
var _journal_view := Vector2.ZERO
var _prompt_colour := Color(0, 0, 0, 0)

## Space kept free under the journal (captions, stamina, stance), in pixels.
const JOURNAL_BOTTOM_CLEARANCE := 250.0
## Carried slot size, in pixels.
const SLOT_SIZE := Vector2(184, 44)
## Scene-local wording; other maps keep the default controls hint.
@export var inventory_hint_format := "1–3 select  ·  F use / throw  ·  J journal (%d)"


func _ready() -> void:
	layer = 6
	_build_panel()
	_build_prompt()

	_message = _make_label(26, HORIZONTAL_ALIGNMENT_CENTER)
	_message.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_message.position = Vector2(-450, -200)
	_message.size = Vector2(900, 40)
	add_child(_message)

	_build_slots()
	_build_status_panel()
	_build_journal()
	_connect_signals.call_deferred()


func _connect_signals() -> void:
	var inventory := get_inventory()
	if inventory:
		inventory.notice.connect(func(text: String, good: bool): show_message(text, COLOUR_GOOD if good else COLOUR_WARNING))
		inventory.document_opened.connect(open_journal)
	var objectives := ObjectiveManager.find(self)
	if objectives:
		objectives.objective_completed.connect(_on_objective_completed)
		objectives.objective_discovered.connect(func(id: StringName):
			show_message("New optional objective: %s" % objectives.get_title(id), COLOUR_GOOD))
	var checkpoints := CheckpointManager.find(self)
	if checkpoints:
		checkpoints.checkpoint_activated.connect(func(cp: Checkpoint): show_message("Checkpoint reached: %s" % cp.checkpoint_name, COLOUR_GOOD))
	# The security alarm says why it sounds (cameras); a puzzle's own message follows it.
	var alarm := get_tree().get_first_node_in_group("security_alarm")
	if alarm:
		alarm.alarm_raised.connect(func(_at: Vector3, reason: String): show_message("ALARM: %s" % reason, COLOUR_WARNING))
	# Puzzles explain every attempt (Expanded Library).
	for node in get_tree().get_nodes_in_group("puzzles"):
		node.feedback.connect(func(text: String, good: bool): show_message(text, COLOUR_GOOD if good else COLOUR_WARNING))
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
	var inventory := get_inventory()
	_slots.visible = inventory != null and not finished
	if _slots.visible:
		_slots.queue_redraw()
	if _journal.visible and (inventory == null or finished):
		_journal.visible = false
	if _journal.visible and get_viewport().get_visible_rect().size != _journal_view:
		_show_journal_page()   # the interface size changed: re-page


func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action("journal") and event.is_action_pressed("journal") and get_inventory() != null:
		if not _journal.visible:
			open_journal(&"")
		else:
			next_journal_page()
		get_viewport().set_input_as_handled()


## J while the journal is open: the clues that did not fit, then the next
## document, then close.
func next_journal_page() -> void:
	if _clue_next >= 0:
		_clue_start = _clue_next
		_clues_only = true
		_show_journal_page()
	elif not _journal_from_read and _journal_page < get_journal_documents().size() - 1:
		_journal_page += 1
		_clue_start = 0
		_clues_only = false
		_show_journal_page()
	else:
		close_journal()


func _set_text(control: Control, text: String) -> void:
	if control.get("text") != text:
		control.set("text", text)


## The player's inventory if this level uses one, else null.
func get_inventory() -> PlayerInventory:
	var player := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	var inventory := player.get_node_or_null("Inventory") as PlayerInventory if player else null
	return inventory if inventory and inventory.enabled else null


## Text per carried slot, e.g. ["1 Tool kit", "2 —", "3 —"].
func get_slot_texts() -> Array[String]:
	var texts: Array[String] = []
	var inventory := get_inventory()
	if inventory == null:
		return texts
	for i in inventory.slot_count:
		var id := inventory.get_item(i)
		texts.append("%d %s" % [i + 1, ItemCatalog.item_name(id) if id != &"" else "—"])
	return texts


func is_journal_open() -> bool:
	return _journal.visible


## Opens the journal. It shows every clue found and one document in full
## (expansion Phase 7: the objectives are in the panel, not here):
## `focus` (the one just read), else the newest. J shows the next document,
## and closes the journal after the last one.
func open_journal(focus: StringName) -> void:
	var inventory := get_inventory()
	if inventory == null:
		return
	_journal_from_read = focus != &""
	if focus != &"":
		_journal_focus = focus
	_journal_page = 0
	_clue_start = 0
	_clues_only = false
	_show_journal_page()
	_journal.visible = true


## The documents in journal page order: the focused one, then newest first.
func get_journal_documents() -> Array:
	var inventory := get_inventory()
	if inventory == null:
		return []
	var docs := inventory.documents.filter(func(d): return d.get("kind", "document") == "document")
	docs.reverse()  # newest first
	for i in docs.size():
		if docs[i].id == _journal_focus:
			docs.push_front(docs.pop_at(i))
			break
	return docs


## The journal's text as shown (for tests and the screenshot tool).
func get_journal_text() -> String:
	return _journal_text.text if _journal.visible else ""


func _show_journal_page() -> void:
	var inventory := get_inventory()
	var docs := get_journal_documents()
	var clues := inventory.documents.filter(func(d): return d.get("kind", "document") == "clue")
	clues.reverse()  # newest first
	_fit_journal()
	var max_height := _journal_max_height()
	# Expansion Phase 7: the document first, then as many clues (newest first)
	# as fit above the captions and stamina; the rest are on the next J page.
	# A clue page shows at least one clue; a document page may show none.
	var least := 1 if _clues_only else 0
	var shown := clues.size() - _clue_start
	while true:
		_journal_text.text = _journal_page_text(docs, clues, shown)
		if shown <= least or _journal_text.get_content_height() <= max_height:
			break
		shown -= 1
	_clue_next = _clue_start + shown if _clue_start + shown < clues.size() else -1
	_journal_text.text = _journal_page_text(docs, clues, shown)
	_fit_journal()


## One journal page: header, the current document (unless a clue page), and
## `shown` clues from _clue_start.
func _journal_page_text(docs: Array, clues: Array, shown: int) -> String:
	var rest := clues.size() - _clue_start - shown
	var more := "J: close"
	if rest > 0:
		more = "J: more clues"
	elif _journal_page < docs.size() - 1 and not _journal_from_read:
		more = "J: next document (%d/%d)" % [_journal_page + 2, docs.size()]
	var text := "[b]JOURNAL[/b]  [color=#9aa3ad]%s[/color]\n" % more
	if not _clues_only:
		text += "\n[color=#ffd36b]DOCUMENTS (%d)[/color]\n" % docs.size()
		if docs.is_empty():
			text += "[color=#9aa3ad]None yet. Read notes and notices to collect them here.[/color]\n"
		else:
			var d: Dictionary = docs[clampi(_journal_page, 0, docs.size() - 1)]
			text += "[b]%s[/b]\n%s\n" % [d.title, d.text]
	if not clues.is_empty() and (shown > 0 or _clues_only):
		text += "\n[color=#ffd36b]CLUES (%d)%s[/color]\n" % [clues.size(), ", continued" if _clue_start > 0 else ""]
		for i in shown:
			var c: Dictionary = clues[_clue_start + i]
			text += "· %s: %s\n" % [c.title, c.text]
	if rest > 0:
		text += "[color=#9aa3ad]… %d more clue%s: press J[/color]\n" % [rest, "" if rest == 1 else "s"]
	return text.strip_edges()


## Expansion Phase 7: the journal keeps clear of the objective panel (right) and
## the captions, stamina and stance (bottom left) at every interface size: it
## widens into the free space (up to 600 px); clues that do not fit go on the
## next page, and only a single over-long entry is cut at the bottom.
func _fit_journal() -> void:
	var view := _journal_view_size()
	_journal_view = view
	var width := clampf(view.x - 364.0 - 20.0 - 20.0 - 20.0, 420.0, 600.0)
	var max_height := _journal_max_height()
	_journal.custom_minimum_size = Vector2(width, 0)
	_journal_text.custom_minimum_size = Vector2(width - 32.0, 0)
	_journal_text.fit_content = true
	_journal.size = Vector2(width, 0)
	var height := _journal_text.get_content_height()
	if height > max_height:
		_journal_text.fit_content = false
		_journal_text.custom_minimum_size = Vector2(width - 32.0, max_height)
		_journal_text.size = _journal_text.custom_minimum_size
	_journal.size = Vector2(width, 0)


func _journal_view_size() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)


func _journal_max_height() -> float:
	return maxf(_journal_view_size().y - 20.0 - JOURNAL_BOTTOM_CLEARANCE - 32.0, 120.0)


func close_journal() -> void:
	_journal.visible = false


func _build_slots() -> void:
	_slots = Control.new()
	_slots.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_slots.position = Vector2(-(SLOT_SIZE.x * 3 + 16) / 2.0, -96)
	_slots.size = Vector2(SLOT_SIZE.x * 3 + 16, SLOT_SIZE.y + 26)
	_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slots.visible = false
	_slots.draw.connect(_draw_slots)
	add_child(_slots)


func _draw_slots() -> void:
	var inventory := get_inventory()
	if inventory == null:
		return
	var font := ThemeDB.fallback_font
	var texts := get_slot_texts()
	for i in texts.size():
		var rect := Rect2(Vector2(i * (SLOT_SIZE.x + 8), 0), SLOT_SIZE)
		var chosen := i == inventory.selected
		_slots.draw_rect(rect, Color(0.03, 0.04, 0.06, 0.72 if chosen else 0.55))
		_slots.draw_rect(rect, Color(1.0, 0.82, 0.3) if chosen else Color(1, 1, 1, 0.25), false, 2.0 if chosen else 1.0)
		var id := inventory.get_item(i)
		if id != &"":
			var info: Dictionary = ItemCatalog.ITEMS[id]
			_slots.draw_rect(Rect2(rect.position + Vector2(8, 14), Vector2(14, 14)), info.colour)
		# Expansion Phase 7: a long name gets a smaller font instead of being cut.
		var label := texts[i].substr(2)
		var font_size := 15
		while font_size > 11 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > SLOT_SIZE.x - 36:
			font_size -= 1
		_slots.draw_string(font, rect.position + Vector2(30, 27), label, HORIZONTAL_ALIGNMENT_LEFT, SLOT_SIZE.x - 36, font_size,
			Color.WHITE if id != &"" else Color(1, 1, 1, 0.4))
		_slots.draw_string(font, rect.position + Vector2(4, 12), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
	var hint := inventory_hint_format % inventory.documents.size()
	_slots.draw_string_outline(font, Vector2(0, SLOT_SIZE.y + 20), hint, HORIZONTAL_ALIGNMENT_CENTER, _slots.size.x, 13, 4, Color.BLACK)
	_slots.draw_string(font, Vector2(0, SLOT_SIZE.y + 20), hint, HORIZONTAL_ALIGNMENT_CENTER, _slots.size.x, 13, Color(1, 1, 1, 0.75))


func _build_status_panel() -> void:
	_status_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.62)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	_status_panel.add_theme_stylebox_override("panel", style)
	_status_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_status_panel.position = Vector2(20, 20)
	_status_panel.custom_minimum_size = Vector2(330, 0)
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_panel.visible = false
	add_child(_status_panel)
	_status_text = RichTextLabel.new()
	_status_text.bbcode_enabled = true
	_status_text.fit_content = true
	_status_text.scroll_active = false
	_status_text.custom_minimum_size = Vector2(306, 0)
	_status_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_text.add_theme_font_size_override("normal_font_size", 14)
	_status_text.add_theme_constant_override("outline_size", 5)
	_status_text.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_panel.add_child(_status_text)


## The status panel (WAYS OUT, POWER, checkpoint) and the objective panel, for layout tests.
func get_layout_controls() -> Dictionary:
	return {"objectives": _panel, "status": _status_panel, "journal": _journal, "slots": _slots, "prompt": _prompt_box, "message": _message}


func _build_journal() -> void:
	_journal = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.04, 0.86)
	style.border_color = Color(0.6, 0.5, 0.3, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	_journal.add_theme_stylebox_override("panel", style)
	_journal.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_journal.position = Vector2(20, 20)
	_journal.custom_minimum_size = Vector2(420, 0)
	_journal.size = Vector2(420, 0)
	_journal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_journal.visible = false
	add_child(_journal)
	_journal_text = RichTextLabel.new()
	_journal_text.bbcode_enabled = true
	_journal_text.fit_content = true
	_journal_text.scroll_active = false
	_journal_text.custom_minimum_size = Vector2(388, 0)
	_journal_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_journal_text.add_theme_font_size_override("normal_font_size", 13)
	_journal_text.add_theme_font_size_override("bold_font_size", 18)
	_journal.add_child(_journal_text)


## Current objective title, or "" when finished.
func get_current_text() -> String:
	var objectives := ObjectiveManager.find(self)
	if objectives == null or objectives.current() == &"":
		return ""
	return objectives.get_title(objectives.current())


## The checklist, one line per objective: "[x] …" done, "[>] …" current, "[ ] …" locked.
## Graph mode: the mandatory objectives in order, then the visible optional
## ones as "[x] (optional) …" (hidden ones stay out until discovered).
func get_lines() -> Array[String]:
	var lines: Array[String] = []
	var objectives := ObjectiveManager.find(self)
	if objectives == null:
		return lines
	for id in get_listed_ids():
		lines.append("%s %s%s" % [_mark(objectives, id), "(optional) " if objectives.is_optional(id) else "", objectives.get_title(id)])
	return lines


## The objectives the checklist shows, in its order (see get_lines()).
func get_listed_ids() -> Array[StringName]:
	var objectives := ObjectiveManager.find(self)
	var ids: Array[StringName] = []
	if objectives == null:
		return ids
	if not objectives.is_graph():
		return objectives.get_ids()
	ids.append_array(objectives.get_mandatory_ids())
	for id in objectives.get_optional_ids():
		if objectives.is_visible(id):
			ids.append(id)
	return ids


static func _mark(objectives: ObjectiveManager, id: StringName) -> String:
	match objectives.get_state(id):
		ObjectiveManager.State.COMPLETED:
			return "[x]"
		ObjectiveManager.State.ACTIVE:
			return "[>]"
	return "[ ]"


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
	if objectives.is_graph():
		var mandatory := objectives.get_mandatory_ids()
		var done := mandatory.filter(func(id): return objectives.is_completed(id)).size()
		return "MISSION %d/%d" % [done, mandatory.size()]
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
	# Expansion Phase 9: labels are only reassigned when their text changes (a
	# RichTextLabel re-parses and re-lays out its BBCode on every assignment).
	_set_text(_header, get_header_text())
	_set_text(_current, objectives.get_title(id))
	_set_text(_hint, objectives.get_hint(id))
	var colours := {ObjectiveManager.State.COMPLETED: COLOUR_DONE, ObjectiveManager.State.ACTIVE: COLOUR_CURRENT,
		ObjectiveManager.State.LOCKED: COLOUR_LOCKED}
	var lines := get_lines()
	var ids := get_listed_ids()
	var text := ""
	var optional_header := false
	for i in ids.size():
		if objectives.is_optional(ids[i]) and not optional_header:
			optional_header = true
			text += "[color=#%s]OPTIONAL[/color]\n" % Color(1.0, 0.82, 0.3).to_html(false)
		text += "[color=#%s]%s[/color]\n" % [colours[objectives.get_state(ids[i])].to_html(false), lines[i]]
	_set_text(_list, text.strip_edges())
	var hud_provider := MapHudProvider.find_for(self)
	_list.visible = hud_provider == null or hud_provider.show_objective_checklist()
	var status := _status_bbcode() if objectives.is_graph() or MapHudProvider.find_for(self) != null else ""
	_set_text(_status_text, status.strip_edges())
	_status_panel.visible = status != "" and not _journal.visible and not objectives.is_finished()


## Map-specific status comes from the map's provider; checkpoint text stays shared.
func get_status_lines() -> Array[String]:
	var out: Array[String] = []
	var provider := MapHudProvider.find_for(self)
	if provider:
		out.append_array(provider.get_status_lines())
	var objectives := ObjectiveManager.find(self)
	var checkpoints := CheckpointManager.find(self)
	if checkpoints and objectives and objectives.is_graph():
		out.append("Checkpoint: %s" % checkpoints.get_respawn_name())
	return out


func _status_bbcode() -> String:
	var accent := Color(1.0, 0.82, 0.3)
	var text := ""
	var provider := MapHudProvider.find_for(self)
	if provider:
		text = provider.get_status_bbcode(accent, COLOUR_DONE, COLOUR_LOCKED)
		if text != "" and not text.ends_with("\n"):
			text += "\n"
	var checkpoints := CheckpointManager.find(self)
	if checkpoints:
		text += "[color=#%s]Checkpoint:[/color] %s\n" % [accent.to_html(false), checkpoints.get_respawn_name()]
	return text


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
	var player := get_tree().get_first_node_in_group("player")
	var interactor := player.get_node_or_null("Interactor") as PlayerInteractor if player else null
	_hold_bar.visible = interactor != null and interactor.hold_target != null
	if _hold_bar.visible:
		_hold_bar.value = interactor.get_hold_progress() * 100.0
	if text != "":
		var parts := split_prompt(text)
		_set_text(_prompt_key, parts[0])
		_prompt_key.get_parent().visible = parts[0] != ""
		_set_text(_prompt, parts[1])
		var colour := COLOUR_WARNING if text.contains("locked") or text.contains("not yet") or text.contains("hands full") else Color.WHITE
		if colour != _prompt_colour:
			# Every override call sends a theme change through the control: only on change.
			_prompt_colour = colour
			_prompt.add_theme_color_override("font_color", colour)
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
	var prompt_column := VBoxContainer.new()
	_prompt_box.add_child(prompt_column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	prompt_column.add_child(row)
	_hold_bar = ProgressBar.new()
	_hold_bar.custom_minimum_size = Vector2(220, 7)
	_hold_bar.show_percentage = false
	_hold_bar.visible = false
	_hold_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_column.add_child(_hold_bar)
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
