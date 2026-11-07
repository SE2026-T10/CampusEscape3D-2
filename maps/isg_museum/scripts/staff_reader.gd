extends CanvasLayer

class PaperGrain extends Control:
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1403
		for i in 350:
			var at := Vector2(rng.randf_range(0,size.x),rng.randf_range(0,size.y))
			draw_line(at,at+Vector2(rng.randf_range(1,5),0),Color(0.4,0.29,0.13,0.045))
		for y in range(74,int(size.y)-25,30):
			draw_line(Vector2(0,y),Vector2(size.x,y),Color(0.4,0.29,0.13,0.06))
		draw_colored_polygon(PackedVector2Array([Vector2(size.x-24,0),Vector2(size.x,24),Vector2(size.x-24,24)]),Color(0.8,0.72,0.53,0.6))

var panel: PanelContainer
var heading: Label
var body: Label
var backdrop: ColorRect
var column: VBoxContainer
var _document: WeakRef
var _clock_left := 0.0
var _view_size := Vector2.ZERO
var _calendar_column: VBoxContainer
var _calendar_image: TextureRect
var _calendar_mode := false


func _ready() -> void:
	add_to_group("staff_reader")
	layer = 7
	backdrop = ColorRect.new()
	add_child(backdrop)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02,0.025,0.03,0.42)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.hide()
	panel = PanelContainer.new()
	add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.94,0.88,0.71)
	style.border_color = Color(0.59,0.46,0.27)
	style.set_border_width_all(1)
	style.set_content_margin_all(32)
	style.shadow_color = Color(0,0,0,0.5)
	style.shadow_size = 16
	style.shadow_offset = Vector2(4,7)
	panel.add_theme_stylebox_override("panel",style)
	var grain := PaperGrain.new()
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grain.resized.connect(grain.queue_redraw)
	panel.add_child(grain)
	column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation",18)
	panel.add_child(column)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size",27)
	heading.add_theme_color_override("font_color",Color(0.23,0.14,0.065))
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	var separator := HSeparator.new()
	column.add_child(separator)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 80
	column.add_child(scroll)
	body = Label.new()
	body.add_theme_font_size_override("font_size",22)
	body.add_theme_color_override("font_color",Color(0.2,0.16,0.11))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var hint := Label.new()
	hint.text = "E / Esc: cất giấy · Thế giới vẫn đang chạy"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size",16)
	hint.add_theme_color_override("font_color",Color(0.39,0.3,0.2))
	column.add_child(hint)
	_calendar_column = VBoxContainer.new()
	panel.add_child(_calendar_column)
	_calendar_image = TextureRect.new()
	_calendar_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_calendar_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_calendar_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_calendar_column.add_child(_calendar_image)
	var calendar_hint := Label.new()
	calendar_hint.text = "E / Esc: cất lịch"
	calendar_hint.add_theme_color_override("font_color",Color(.25,.2,.12))
	_calendar_column.add_child(calendar_hint)
	_calendar_column.hide()
	panel.hide()
	_fit_sheet()
	var flow := GameFlow.find(self)
	if flow:
		flow.state_changed.connect(func(_from: int,to: int):
			if to != GameStateMachine.State.PLAYING:
				close_document())


func open_document(title: String, text: String, source: Node = null) -> void:
	_calendar_mode = false
	_calendar_column.hide()
	column.show()
	heading.text = title
	body.text = text
	_document = weakref(source) if source != null else null
	_clock_left = 0.0
	panel.show()
	backdrop.show()
	_fit_sheet()
	_settle_sheet()


func open_calendar(source: Node) -> void:
	open_document("Lịch tháng",source.get_content(),source)
	_calendar_mode = true
	column.hide()
	_calendar_column.show()
	_calendar_image.texture = source.calendar_viewport.get_texture()
	_fit_sheet()


func _settle_sheet() -> void:
	# Autowrapped labels need the container width before reporting their height.
	for frame in 2:
		await get_tree().process_frame
	_fit_sheet()


func close_document() -> void:
	panel.hide()
	backdrop.hide()
	_document = null


func _process(delta: float) -> void:
	if panel.visible or get_viewport().get_visible_rect().size != _view_size:
		_fit_sheet()
	if not panel.visible:
		return
	_clock_left -= delta
	if _clock_left <= 0.0 and _document != null:
		_clock_left = 1.0
		var source = _document.get_ref()
		if is_instance_valid(source):
			body.text = source.get_content()


func _fit_sheet() -> void:
	_view_size = get_viewport().get_visible_rect().size
	column.custom_minimum_size.x = maxf(1,minf(620,_view_size.x-48)-64)
	panel.size = Vector2(minf(620,_view_size.x-48),minf(560,_view_size.y-48))
	if _calendar_mode:
		panel.size = Vector2(minf(510,_view_size.x-48),minf(690,_view_size.y-32))
	panel.position = (_view_size-panel.size)/2


func _input(event: InputEvent) -> void:
	if panel.visible and (event.is_action_pressed("interact") or event.is_action_pressed("pause")):
		close_document()
		get_viewport().set_input_as_handled()
