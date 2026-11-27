class_name JournalClipboard
extends PanelContainer

## The Expanded Library's journal as a sheet on a clipboard (requested by the owner on
## 2026-11-02): a brown hardboard with rounded corners, a cream sheet held at the top by a
## metal clip; the journal's text on the sheet (headings and clues in handwriting, documents
## typed: ObjectiveHud writes it). Only the look: the text, its paging and its fitting are
## ObjectiveHud's, as before.

const BOARD := Color(0.56, 0.37, 0.2)
const BOARD_EDGE := Color(0.38, 0.24, 0.12)
const METAL := Color(0.74, 0.76, 0.79)
const METAL_DARK := Color(0.45, 0.47, 0.5)
const METAL_LIGHT := Color(0.93, 0.94, 0.96)
## The board shown round the sheet (more at the top, under the clip), and the sheet's margins.
const EDGE := 12.0
const TOP := 34.0
const SHEET_MARGIN := Vector2(14, 14)
## The sheet's top margin, below the clip's jaw.
const SHEET_TOP := 26.0
const CLIP_SIZE := Vector2(116, 38)
## The clipboard's width, and its height at most this many times its width (a page, portrait).
const WIDTH := 340.0
const PAGE_RATIO := 1.45
## Width and height the clipboard and the sheet add round the text.
const CHROME := Vector2(2.0 * (EDGE + SHEET_MARGIN.x), TOP + EDGE + SHEET_TOP + SHEET_MARGIN.y)

var sheet: PanelContainer


func _init() -> void:
	var board := StyleBoxFlat.new()
	board.bg_color = BOARD
	board.border_color = BOARD_EDGE
	board.set_border_width_all(3)
	board.set_corner_radius_all(12)
	board.shadow_color = Color(0, 0, 0, 0.5)
	board.shadow_size = 10
	board.shadow_offset = Vector2(4, 6)
	board.set_content_margin_all(EDGE)
	board.content_margin_top = TOP
	add_theme_stylebox_override("panel", board)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet = PanelContainer.new()
	sheet.name = "Sheet"
	var paper := StyleBoxFlat.new()
	paper.bg_color = PaperNote.PAPER
	paper.shadow_color = Color(0, 0, 0, 0.3)
	paper.shadow_size = 3
	paper.shadow_offset = Vector2(1, 2)
	paper.content_margin_left = SHEET_MARGIN.x
	paper.content_margin_right = SHEET_MARGIN.x
	paper.content_margin_top = SHEET_TOP
	paper.content_margin_bottom = SHEET_MARGIN.y
	sheet.add_theme_stylebox_override("panel", paper)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheet)
	# The clip, over the board's top and the sheet's top edge.
	var clip := Control.new()
	clip.name = "Clip"
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.draw.connect(_draw_clip.bind(clip))
	add_child(clip)
	item_rect_changed.connect(clip.queue_redraw)


func _draw_clip(c: Control) -> void:
	# The Clip control fills the content area (the sheet's rect); the clip sits on its top
	# edge, centred, reaching up onto the board.
	var w := CLIP_SIZE.x
	var x := (c.size.x - w) * 0.5
	var top := -TOP + 12.0
	# Shadow, then the plate holding the sheet, then the lever's hinge and its ring.
	c.draw_rect(Rect2(x + 3, top + 4, w, CLIP_SIZE.y), Color(0, 0, 0, 0.3))
	var plate := PackedVector2Array([Vector2(x + 14, top), Vector2(x + w - 14, top), Vector2(x + w, top + CLIP_SIZE.y), Vector2(x, top + CLIP_SIZE.y)])
	c.draw_colored_polygon(plate, METAL)
	c.draw_polyline(PackedVector2Array([plate[0], plate[1], plate[2], plate[3], plate[0]]), METAL_DARK, 1.5, true)
	c.draw_line(Vector2(x + 16, top + 3), Vector2(x + w - 16, top + 3), METAL_LIGHT, 2.0)
	c.draw_rect(Rect2(x + 10, top + CLIP_SIZE.y - 9, w - 20, 5), METAL_DARK)
	var ring := Rect2(x + w * 0.5 - 26, top - 12, 52, 22)
	c.draw_arc(ring.get_center(), 18.0, PI, TAU, 24, METAL_DARK, 5.0, true)
	c.draw_arc(ring.get_center(), 18.0, PI, TAU, 24, METAL, 3.0, true)
	for dx in [-w * 0.32, w * 0.32]:
		c.draw_circle(Vector2(x + w * 0.5 + dx, top + 14), 3.0, METAL_DARK)
