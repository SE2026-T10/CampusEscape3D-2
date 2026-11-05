class_name FoldedNote
extends Control

## The mission note folded away (K, requested by the owner on 2026-11-02): a small folded
## sheet in the top-right corner, taped, a crease across it and a dog-eared corner, with
## "Mission" and the progress in handwriting and a K key cap; it hops when the progress
## changes. ObjectiveHud shows it while the PaperNote is folded.

const SIZE := Vector2(84, 96)

var progress := ""
var _bounce := 0.0


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = SIZE * 0.5


## Shows the progress ("2/8"); a change makes it hop.
func set_progress(text: String) -> void:
	if text == progress:
		return
	if progress != "":
		_bounce = 0.6
	progress = text
	queue_redraw()


func _process(delta: float) -> void:
	if _bounce > 0.0:
		_bounce = maxf(_bounce - delta, 0.0)
		var k := sin((0.6 - _bounce) / 0.6 * PI)
		scale = Vector2.ONE * (1.0 + 0.18 * k)
		rotation = deg_to_rad(-6.0 * k)
	elif scale != Vector2.ONE:
		scale = Vector2.ONE
		rotation = 0.0


func _draw() -> void:
	var paper := Rect2(12, 10, 64, 78)
	draw_set_transform(paper.get_center(), deg_to_rad(-4.0))
	var r := Rect2(-paper.size / 2.0, paper.size)
	# Shadow, the sheet, the lower half a shade darker (folded over), the crease.
	draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.4))
	var ear := 14.0
	var outline := PackedVector2Array([r.position, r.position + Vector2(r.size.x - ear, 0), r.position + Vector2(r.size.x, ear), r.end, r.position + Vector2(0, r.size.y)])
	draw_colored_polygon(outline, PaperNote.PAPER)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.5), Vector2(r.size.x, r.size.y * 0.5)), Color(0.86, 0.82, 0.7, 0.55))
	draw_line(r.position + Vector2(0, r.size.y * 0.5), r.position + Vector2(r.size.x, r.size.y * 0.5), Color(0.55, 0.5, 0.4, 0.8), 1.5)
	# The dog-ear: the corner folded down.
	draw_colored_polygon(PackedVector2Array([r.position + Vector2(r.size.x - ear, 0), r.position + Vector2(r.size.x - ear, ear), r.position + Vector2(r.size.x, ear)]), Color(0.84, 0.79, 0.64))
	# Tape, and the writing.
	draw_set_transform(paper.get_center() + Vector2(-4, -r.size.y * 0.5), deg_to_rad(4.0))
	draw_rect(Rect2(-17, -7, 34, 13), PaperNote.TAPE)
	draw_set_transform(paper.get_center(), deg_to_rad(-4.0))
	draw_string(PaperNote.FONT_BOLD, r.position + Vector2(6, 24), "Mission", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 13, PaperNote.INK_RED)
	draw_string(PaperNote.FONT_BOLD, r.position + Vector2(0, 58), progress, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, PaperNote.INK)
	draw_set_transform(Vector2.ZERO)
	# The key cap.
	var cap := Rect2(2, SIZE.y - 26, 24, 24)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.92)
	style.border_color = Color(1, 1, 1, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	draw_style_box(style, cap)
	draw_string(get_theme_default_font(), cap.position + Vector2(0, 18), "K", HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, 16, Color.WHITE)
