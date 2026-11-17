class_name PaperNote
extends PanelContainer

## The Expanded Library's mission panel as a note on paper (requested by the owner on
## 2026-11-02): a cream sheet, taped at the top and slightly askew, ruled, with a red
## margin line; the progress ("MISSION 2/8") and the current objective with its hint in
## pen; then one ruled row per objective with a box in the margin: ticked and its text
## crossed out when done, an arrow and bold for the current ones, empty for those still to
## come; the optional ones under "Optional". ObjectiveHud fills it (paper_note); the HUD's
## texts and checklist lines are unchanged. Handwriting: Kalam (SIL OFL 1.1).

const PAPER := Color(0.97, 0.94, 0.84)
const INK := Color(0.1, 0.13, 0.3)
const INK_SOFT := Color(0.32, 0.37, 0.52)
const INK_DONE := Color(0.45, 0.46, 0.5)
const INK_RED := Color(0.74, 0.15, 0.12)
const RULE := Color(0.5, 0.66, 0.86, 0.6)
const TAPE := Color(0.96, 0.9, 0.55, 0.75)
const FONT := preload("res://shared/assets/fonts/kalam/Kalam-Regular.ttf")
const FONT_BOLD := preload("res://shared/assets/fonts/kalam/Kalam-Bold.ttf")
## The box column's width; the red margin line runs just right of it.
const BOX_COLUMN := 24.0

enum Mark { TODO, CURRENT, DONE }

var _header: Label
var _current: Label
var _hint: Label
var _rows: VBoxContainer
var _paper: Control
var _rows_key := ""


func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(2)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 8
	style.shadow_offset = Vector2(3, 5)
	style.content_margin_left = 12
	style.content_margin_right = 16
	style.content_margin_top = 20
	style.content_margin_bottom = 14
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotation_degrees = -1.0
	# Behind the text: the margin line, the rules, the boxes, the tape (drawn, see _draw_paper).
	_paper = Control.new()
	_paper.name = "Paper"
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.draw.connect(_draw_paper)
	add_child(_paper)
	var box := VBoxContainer.new()
	box.name = "Text"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	_header = _label(15, true, INK_RED)
	box.add_child(_indented(_header))
	_current = _label(21, true, INK)
	_current.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_indented(_current))
	_hint = _label(14, false, INK_SOFT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_indented(_hint))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	box.add_child(gap)
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.add_theme_constant_override("separation", 0)
	box.add_child(_rows)
	item_rect_changed.connect(_paper.queue_redraw)


## Shows the progress, the current objective and the rows: [text, Mark, optional].
func show_mission(header: String, title: String, hint: String, rows: Array) -> void:
	_put(_header, header)
	_put(_current, title)
	_put(_hint, hint)
	var key := str(rows)
	if key == _rows_key:
		return
	_rows_key = key
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	var optional_shown := false
	for r in rows:
		if r[2] and not optional_shown:
			optional_shown = true
			var heading := _label(15, true, INK_RED)
			heading.text = "Optional"
			_rows.add_child(_indented(heading, 6.0))
		_rows.add_child(_row(r[0], r[1]))
	_paper.queue_redraw.call_deferred()


## What the note shows, for tests: the header, the objective, the hint, and the rows as
## [text, Mark] in order (the "Optional" heading as ["Optional", -1]).
func get_shown() -> Dictionary:
	var rows := []
	for r in _rows.get_children():
		if r.has_meta("mark"):
			rows.append([(r.get_child(1) as RichTextLabel).get_parsed_text(), int(r.get_meta("mark"))])
		else:
			rows.append([((r as MarginContainer).get_child(0) as Label).text, -1])
	return {"header": _header.text, "title": _current.text, "hint": _hint.text, "rows": rows}


func _row(text: String, mark: Mark) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.set_meta("mark", mark)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(BOX_COLUMN, 23)
	row.add_child(spacer)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("normal_font", FONT)
	label.add_theme_font_override("bold_font", FONT_BOLD)
	label.add_theme_font_size_override("normal_font_size", 16)
	label.add_theme_font_size_override("bold_font_size", 16)
	label.add_theme_constant_override("line_separation", -6)
	var safe := text.replace("[", "[lb]")
	match mark:
		Mark.DONE:
			label.text = "[color=#%s]%s[/color]" % [INK_DONE.to_html(false), safe]
		Mark.CURRENT:
			label.text = "[color=#%s][b]%s[/b][/color]" % [INK.to_html(false), safe]
		_:
			label.text = "[color=#%s]%s[/color]" % [INK_SOFT.to_html(false), safe]
	row.add_child(label)
	return row


func _draw_paper() -> void:
	var w := _paper.size.x
	var h := _paper.size.y
	var top := -20.0   # the sheet's top edge (the content margin above)
	# Tape across the top edge.
	_paper.draw_set_transform(Vector2(w * 0.5, top), deg_to_rad(2.5))
	_paper.draw_rect(Rect2(-48, -11, 96, 22), TAPE)
	_paper.draw_set_transform(Vector2.ZERO)
	# The red margin line, top to bottom of the sheet.
	var mx := BOX_COLUMN + 2.0
	_paper.draw_line(Vector2(mx, top), Vector2(mx, h + 14.0), Color(INK_RED, 0.55), 1.5)
	# A rule under the hint, and one under each row; the boxes and marks in the margin.
	var text := get_node("Text") as Control
	var hint_bottom: float = _hint.get_parent().position.y + _hint.get_parent().size.y + 3.0
	_paper.draw_line(Vector2(-12, hint_bottom), Vector2(w + 16, hint_bottom), RULE, 1.2)
	for row in _rows.get_children():
		var r := row as Control
		var y0 := text.position.y - _paper.position.y + _rows.position.y + r.position.y
		var y1 := y0 + r.size.y
		_paper.draw_line(Vector2(-12, y1), Vector2(w + 16, y1), RULE, 1.0)
		if not r.has_meta("mark"):
			continue
		var c := Vector2(BOX_COLUMN * 0.5 - 2.0, y0 + 12.0)
		if int(r.get_meta("mark")) == Mark.DONE:
			_cross_out(r.get_child(1) as RichTextLabel, r.position.x + r.get_child(1).position.x, y0)
		match int(r.get_meta("mark")):
			Mark.CURRENT:
				_paper.draw_line(c + Vector2(-7, 0), c + Vector2(6, 0), INK_RED, 2.2)
				_paper.draw_line(c + Vector2(1, -5), c + Vector2(7, 0), INK_RED, 2.2)
				_paper.draw_line(c + Vector2(1, 5), c + Vector2(7, 0), INK_RED, 2.2)
			_:
				_box(c, int(r.get_meta("mark")) == Mark.DONE)


## A pen stroke through a done objective's text, line by line (slightly rising, as by hand).
func _cross_out(label: RichTextLabel, x0: float, y0: float) -> void:
	var lines := maxi(label.get_line_count(), 1)
	var full := label.get_content_width()
	var line_h := label.get_content_height() / float(lines)
	for i in lines:
		var width: float = full if i < lines - 1 else _last_line_width(label, full, lines)
		var y := y0 + line_h * (i + 0.55)
		_paper.draw_line(Vector2(x0 - 3.0, y + 1.2), Vector2(x0 + width + 3.0, y - 1.2), Color(INK, 0.85), 2.0)


## The width of a label's last line (its text measured after the earlier lines' words).
func _last_line_width(label: RichTextLabel, full: float, lines: int) -> float:
	if lines == 1:
		return full
	var font := label.get_theme_font("normal_font")
	var size := label.get_theme_font_size("normal_font_size")
	var words := label.get_parsed_text().split(" ")
	var line := ""
	var last := ""
	for w in words:
		var trial: String = (line + " " + String(w)).strip_edges()
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > label.size.x and line != "":
			line = w
		else:
			line = trial
		last = line
	return minf(font.get_string_size(last, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, full)


## A hand-drawn box (slightly uneven), ticked when done.
func _box(c: Vector2, ticked: bool) -> void:
	var s := 6.5
	var pts := PackedVector2Array([c + Vector2(-s, -s + 0.6), c + Vector2(s - 0.4, -s), c + Vector2(s, s - 0.3), c + Vector2(-s + 0.5, s), c + Vector2(-s, -s + 0.6)])
	_paper.draw_polyline(pts, INK_SOFT, 1.4)
	if ticked:
		_paper.draw_polyline(PackedVector2Array([c + Vector2(-4, -0.5), c + Vector2(-0.5, 4), c + Vector2(8, -9)]), INK, 2.4)


func _label(size: int, bold: bool, colour: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT_BOLD if bold else FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_constant_override("line_spacing", -5)
	return label


## The label right of the margin line (the header, the objective, the hint).
func _indented(control: Control, top := 0.0) -> MarginContainer:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", int(BOX_COLUMN + 8.0))
	m.add_theme_constant_override("margin_top", int(top))
	m.add_child(control)
	return m


static func _put(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text
