extends CanvasLayer

class ArtifactIcon extends Control:
	var kind := "painting"
	func _draw() -> void:
		draw_style_box(_paper(),Rect2(Vector2.ZERO,size))
		var ink := Color(.38,.24,.12)
		var silver := Color(.62,.7,.76)
		match kind:
			"bust":
				draw_circle(Vector2(45,27),16,Color(.78,.78,.7))
				draw_rect(Rect2(34,40,22,16),Color(.7,.7,.63))
				draw_colored_polygon(PackedVector2Array([Vector2(35,48),Vector2(55,48),Vector2(70,68),Vector2(20,68)]),Color(.78,.78,.7))
				draw_rect(Rect2(18,68,54,7),ink)
			"watch":
				draw_arc(Vector2(45,15),7,0,TAU,20,ink,3)
				draw_circle(Vector2(45,47),26,Color(.75,.56,.2))
				draw_circle(Vector2(45,47),21,Color(.95,.91,.75))
				draw_line(Vector2(45,47),Vector2(45,31),ink,3)
				draw_line(Vector2(45,47),Vector2(57,54),ink,3)
			"scroll":
				draw_rect(Rect2(22,20,46,48),Color(.94,.88,.7))
				draw_arc(Vector2(24,44),23,PI/2,PI*1.5,20,ink,4)
				draw_line(Vector2(31,34),Vector2(60,34),ink,2)
				draw_line(Vector2(31,45),Vector2(60,45),ink,2)
			"bird":
				_draw_oval(Vector2(44,48),Vector2(18,12),Color(.6,.4,.15))
				draw_colored_polygon(PackedVector2Array([Vector2(43,45),Vector2(15,17),Vector2(30,52)]),ink)
				draw_colored_polygon(PackedVector2Array([Vector2(45,44),Vector2(70,15),Vector2(61,53)]),ink)
				draw_circle(Vector2(58,34),8,Color(.6,.4,.15))
				draw_line(Vector2(40,58),Vector2(36,71),ink,3)
				draw_line(Vector2(49,58),Vector2(53,71),ink,3)
			"medal":
				draw_colored_polygon(PackedVector2Array([Vector2(28,9),Vector2(39,9),Vector2(52,42),Vector2(41,42)]),Color(.15,.3,.65))
				draw_colored_polygon(PackedVector2Array([Vector2(51,9),Vector2(62,9),Vector2(48,42),Vector2(38,42)]),Color(.1,.25,.5))
				draw_circle(Vector2(45,54),22,silver)
				draw_arc(Vector2(45,54),17,0,TAU,32,ink,2)
				draw_string(ThemeDB.fallback_font,Vector2(38,61),"★",HORIZONTAL_ALIGNMENT_LEFT,-1,20,ink)
			_:
				draw_rect(Rect2(12,17,66,52),ink)
				draw_rect(Rect2(17,22,56,42),Color(.43,.62,.72))
				draw_circle(Vector2(59,33),7,Color(.95,.78,.3))
				draw_colored_polygon(PackedVector2Array([Vector2(17,62),Vector2(34,36),Vector2(49,56),Vector2(61,42),Vector2(73,62)]),Color(.24,.4,.23))
	func _draw_oval(at: Vector2,radius: Vector2,colour: Color) -> void:
		var points := PackedVector2Array()
		for i in 32:
			points.append(at+Vector2(cos(i*TAU/32),sin(i*TAU/32))*radius)
		draw_colored_polygon(points,colour)
	func _paper() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(.9,.85,.73)
		style.set_corner_radius_all(5)
		return style

var panel: PanelContainer
var result_panel: PanelContainer
var content: VBoxContainer
var _buttons: HBoxContainer
var accept_button: Button
var restart_button: Button
var _backdrop: ColorRect
var _summary_text: RichTextLabel
var _source: Node3D
var _old_mouse := Input.MOUSE_MODE_CAPTURED
var _is_result := false


func _ready() -> void:
	add_to_group("museum_contract_ui")
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_backdrop = ColorRect.new()
	add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(.025,.03,.04,.7)
	panel = PanelContainer.new()
	add_child(panel)
	result_panel = panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.95,.9,.77)
	style.set_content_margin_all(26)
	style.shadow_size = 15
	style.shadow_color = Color(0,0,0,.6)
	panel.add_theme_stylebox_override("panel",style)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation",12)
	panel.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",10)
	scroll.add_child(content)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation",12)
	outer.add_child(_buttons)
	hide()
	_connect.call_deferred()


func _connect() -> void:
	_contract().ended.connect(show_result)
	GameFlow.find(self).state_changed.connect(func(_from: int,to: int):
		if to != GameStateMachine.State.PLAYING and not _is_result:
			close_sheet())


func _contract():
	return get_tree().get_first_node_in_group("museum_contract")


func _clear() -> void:
	for child in content.get_children():
		child.free()
	for child in _buttons.get_children():
		child.free()


func _label(text: String, font_size := 20) -> Label:
	var item := Label.new()
	item.text = text
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",Color(.2,.15,.1))
	content.add_child(item)
	return item


func _button(text: String,action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	_buttons.add_child(button)
	return button


func open_contract(source: Node3D = null) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var flow := GameFlow.find(self)
	if flow.state != GameStateMachine.State.PLAYING or flow.is_leaving() or player.keypad_active or player.modal_active:
		return
	var reader := get_tree().get_first_node_in_group("staff_reader")
	if reader:
		reader.close_document()
	_source = source
	_is_result = false
	_clear()
	var contract = _contract()
	_label("HỢP ĐỒNG %02d • %s"%[contract.contract_info.number,contract.contract_info.event.to_upper()],26)
	var found: Array = contract.collected_ids()
	for id in contract.selected_ids:
		var info: Dictionary = contract.catalog[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",14)
		content.add_child(row)
		var icon := ArtifactIcon.new()
		icon.kind = info.icon
		icon.custom_minimum_size = Vector2(90,76)
		row.add_child(icon)
		var text := Label.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.text = "%s • %d điểm%s\n%s\n%s"%[info.name,info.points," • ĐÃ LẤY" if id in found else "",info.room,info.detail]
		text.add_theme_color_override("font_color",Color(.2,.15,.1))
		text.add_theme_font_size_override("font_size",18)
		row.add_child(text)
	_label("Yêu cầu phụ: không bị truy đuổi (+200 điểm).\nĐồ ngoài hợp đồng: +50 điểm/món.",18)
	_label("GIẤY HẸN • %s • Giờ hẹn: %s"%[contract.contract_info.event,contract.contract_info.appointment],18)
	_label("Dây: kho phụ tầng 1 • J: giấy hẹn • M: bản đồ đã lưu • V: vé đã nhận\nĐồ ngoài hợp đồng không thay thế mục tiêu. T2 chỉ tính sau khi giao.",14)
	if not contract.accepted:
		accept_button = _button("Nhận hợp đồng và giấy hẹn",func():
			contract.accept_contract()
			close_sheet())
	_button("Cất giấy (E / Esc / J)",close_sheet)
	_open()


func show_result(summary: Dictionary) -> void:
	close_sheet()
	_is_result = true
	_clear()
	_label("KẾT QUẢ · "+summary.rating_text.to_upper(),28)
	_label("Điểm: %d · Thời gian: %02d:%02d\nBáo động: %d · Lần truy đuổi: %d"%[summary.score,int(summary.time)/60,int(summary.time)%60,summary.alarms,summary.detections],22)
	_summary_text = RichTextLabel.new()
	_summary_text.fit_content = true
	_summary_text.scroll_active = false
	_summary_text.add_theme_color_override("default_color",Color(.2,.15,.1))
	_summary_text.add_theme_font_size_override("normal_font_size",20)
	_summary_text.text = summary_text(summary)
	content.add_child(_summary_text)
	restart_button = _button("Chơi lại từ đầu",func(): GameFlow.find(self).restart())
	_button("Về menu chính",func(): GameFlow.find(self).go_to_main_menu())
	_open()


func summary_text(summary: Dictionary) -> String:
	var contract = _contract()
	var text := "HIỆN VẬT ĐƯỢC YÊU CẦU\n"
	for id in summary.required:
		text += ("[Đã lấy] " if id in summary.collected else "[Còn thiếu] ")+contract.catalog[id].name+"\n"
	if summary.required.is_empty():
		text += "Chưa nhận hợp đồng từ N0.\n"
	text += "\nTẤT CẢ ĐÃ THU THẬP\n"
	for id in summary.collected:
		text += contract.catalog[id].name+"\n"
	if summary.collected.is_empty():
		text += "Chưa có hiện vật.\n"
	text += "\nNGOÀI HỢP ĐỒNG\n"
	for id in summary.extras:
		text += contract.catalog[id].name+" (+50)\n"
	if summary.extras.is_empty():
		text += "Không có.\n"
	text += "\nThưởng không bị truy đuổi: "+("+200" if summary.bonus else "không đạt")
	text += "\nT2 chỉ được tính khi đã giao tới thảm tập kết."
	return text


func _open() -> void:
	_old_mouse = Input.mouse_mode
	get_tree().get_first_node_in_group("player").modal_active = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	_fit()


func close_sheet() -> void:
	if not visible:
		return
	hide()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.modal_active = false
	var flow := GameFlow.find(self)
	if flow and flow.state == GameStateMachine.State.PLAYING and not flow.is_leaving():
		Input.mouse_mode = _old_mouse
	_source = null


func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	content.custom_minimum_size.x = minf(720,view.x-100)-52
	panel.size = Vector2(minf(760,view.x-80),minf(650 if _is_result else 610,view.y-60))
	panel.position = (view-panel.size)/2


func _process(_delta: float) -> void:
	if not visible:
		return
	_fit()
	if _is_result:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif is_instance_valid(_source) and _source.global_position.distance_to(get_tree().get_first_node_in_group("player").global_position) > 3.5:
		close_sheet()


func _input(event: InputEvent) -> void:
	var is_j: bool = event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_J or event.keycode == KEY_J)
	if not visible:
		if is_j and _contract().accepted:
			open_contract()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
	elif event is InputEventKey or event is InputEventAction:
		if not _is_result and (is_j or event.is_action_pressed("interact") or event.is_action_pressed("pause")):
			close_sheet()
		get_viewport().set_input_as_handled()
