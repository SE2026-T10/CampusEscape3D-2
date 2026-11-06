extends CanvasLayer

const QUESTIONS := [
	{"question":"Bạn tới tham dự sự kiện nào?", "answers":["Đêm di sản","Triển lãm mùa xuân","Ngày hội thể thao"], "correct":0, "hint":"Kiểm tra áp phích ở sảnh chính."},
	{"question":"Ai là người phụ trách đón khách?", "answers":["Trần Minh","Lê An","Mai Lan"], "correct":1, "hint":"Đọc bảng thông báo bên quầy dịch vụ."},
	{"question":"Bạn được hẹn vào thời gian nào?", "answers":["20:00","22:00","21:30"], "correct":2, "hint":"Xem giấy hẹn đồng đội giao ngoài cổng."},
]
var saved_map := false
var question_index := 0
var wrong_count := 0
var cooldown_left := 0.0
var mode := ""
var actor: Node3D
var source: Node3D
var _old_mouse := Input.MOUSE_MODE_CAPTURED
var backdrop: ColorRect
var panel: PanelContainer
var column: VBoxContainer
var title: Label
var message: Label
var question: Label
var answers: VBoxContainer
var map_canvas: Control
var map_buttons: HBoxContainer
var save_button: Button
var close_button: Button


func _ready() -> void:
	layer = 16
	add_to_group("museum_service_ui")
	backdrop = ColorRect.new()
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0,0,0,0.5)
	panel = PanelContainer.new()
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.92,0.86,0.69)
	style.set_content_margin_all(24)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel",style)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	panel.add_child(column)
	title = _label(26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	message = _label(17)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message)
	question = _label(22)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(question)
	answers = VBoxContainer.new()
	answers.add_theme_constant_override("separation",10)
	column.add_child(answers)
	for i in 3:
		var button := Button.new()
		button.custom_minimum_size.y = 48
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(answer.bind(i))
		answers.add_child(button)
	map_buttons = HBoxContainer.new()
	column.add_child(map_buttons)
	for i in 2:
		var button := Button.new()
		button.text = "Tầng %d"%(i+1)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(show_floor.bind(i))
		map_buttons.add_child(button)
	map_canvas = preload("res://maps/isg_museum/scripts/service_map_canvas.gd").new()
	map_canvas.custom_minimum_size = Vector2(720,410)
	map_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(map_canvas)
	save_button = Button.new()
	save_button.text = "Lưu bản đồ vào sổ (mở lại bằng M)"
	save_button.pressed.connect(save_map)
	column.add_child(save_button)
	close_button = Button.new()
	close_button.text = "Đóng (E / Esc) · Thế giới vẫn hoạt động"
	close_button.pressed.connect(close_panel)
	column.add_child(close_button)
	hide()


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color(0.15,0.18,0.13))
	return label


func _contract() -> Node:
	return get_tree().get_first_node_in_group("museum_contract")


func _open(next_mode: String, target: Node3D, by: Node3D) -> bool:
	var flow := GameFlow.find(self)
	if flow == null or flow.state != GameStateMachine.State.PLAYING or flow.is_leaving():
		return false
	if not visible and by != null and (bool(by.get("modal_active")) or bool(by.get("keypad_active"))):
		return false
	if visible:
		close_panel()
	actor = by
	source = target
	mode = next_mode
	if actor:
		actor.set("modal_active",true)
		actor.velocity.x = 0
		actor.velocity.z = 0
	_old_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not flow.state_changed.is_connected(_on_flow_changed):
		flow.state_changed.connect(_on_flow_changed)
	var reader := get_tree().get_first_node_in_group("staff_reader")
	if reader:
		reader.close_document()
	show()
	return true


func open_quiz(target: Node3D, by: Node3D) -> bool:
	if not _open("quiz",target,by):
		return false
	title.text = "PHÒNG DỊCH VỤ · XÁC NHẬN GIẤY HẸN"
	question_index = 0
	question.show()
	answers.show()
	map_buttons.hide()
	map_canvas.hide()
	save_button.hide()
	message.text = "Trả lời theo áp phích, bảng thông báo và giấy hẹn."
	_refresh_quiz()
	_fit()
	return true


func open_map(target: Node3D, by: Node3D) -> bool:
	if not _open("map",target,by):
		return false
	title.text = "BẢN ĐỒ BẢO TÀNG"
	message.text = "Tên phòng và lối đi · V: cửa vé · E: cửa sổ thoát · Không theo dõi bảo vệ"
	question.hide()
	answers.hide()
	map_buttons.show()
	map_canvas.show()
	save_button.show()
	show_floor(0)
	_fit()
	return true


func answer(index: int) -> void:
	var contract := _contract()
	if not visible or mode != "quiz" or cooldown_left > 0 or contract == null or contract.has_ticket:
		return
	var info: Dictionary = QUESTIONS[question_index]
	if index != info.correct:
		wrong_count += 1
		if wrong_count >= 3:
			wrong_count = 0
			question_index = 0
			cooldown_left = 10.0
			message.text = "Nhân viên cần kiểm tra lại. Vui lòng chờ một lát rồi thử lại."
		else:
			message.text = "Thông tin chưa khớp. " + info.hint
		_refresh_quiz()
		return
	question_index += 1
	if question_index >= QUESTIONS.size():
		contract.grant_ticket()
		message.text = "Thông tin khớp. Đây là vé V lên tầng 2. Quét tại cửa thang A hoặc B."
		question_index = 0
	else:
		message.text = "Đã xác nhận. Xin kiểm tra thông tin tiếp theo."
	_refresh_quiz()


func _refresh_quiz() -> void:
	if mode != "quiz":
		return
	var contract := _contract()
	if contract != null and contract.has_ticket:
		question.text = "Bạn đã có vé V. Cả hai cửa tầng 2 đều chấp nhận vé này."
		answers.hide()
		return
	answers.show()
	question.text = "Câu %d/3 · %s"%[question_index+1,QUESTIONS[question_index].question]
	for i in 3:
		var button := answers.get_child(i) as Button
		button.text = QUESTIONS[question_index].answers[i]
		button.disabled = cooldown_left > 0
	if cooldown_left > 0:
		message.text = "Tạm kiểm tra giấy tờ · thử lại sau %d giây. Không mất vé vĩnh viễn."%ceili(cooldown_left)


func show_floor(index: int) -> void:
	map_canvas.floor_index = index
	for i in 2:
		(map_buttons.get_child(i) as Button).disabled = i == index


func save_map() -> void:
	saved_map = true
	save_button.text = "Đã lưu · Nhấn M khi chơi để mở lại"


func close_panel() -> void:
	if not visible:
		return
	hide()
	if is_instance_valid(actor):
		actor.set("modal_active",false)
	var flow := GameFlow.find(self)
	if flow and flow.state == GameStateMachine.State.PLAYING and not flow.is_leaving():
		Input.mouse_mode = _old_mouse
	actor = null
	source = null
	mode = ""


func _on_flow_changed(_from: int,to: int) -> void:
	if to != GameStateMachine.State.PLAYING:
		close_panel()


func _process(delta: float) -> void:
	if cooldown_left > 0:
		cooldown_left = maxf(0,cooldown_left-delta)
		if visible and mode == "quiz":
			_refresh_quiz()
	if not visible:
		return
	var flow := GameFlow.find(self)
	if flow == null or flow.state != GameStateMachine.State.PLAYING or flow.is_leaving() \
			or not is_instance_valid(actor) or (is_instance_valid(source) and actor.global_position.distance_to(source.global_position) > 3.2):
		close_panel()
		return
	_fit()


func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	column.custom_minimum_size.x = minf(720 if mode == "map" else 650,view.x-72)
	map_canvas.custom_minimum_size.x = column.custom_minimum_size.x
	map_canvas.custom_minimum_size.y = minf(410,view.y-250)
	panel.size = panel.get_combined_minimum_size()
	panel.position = (view-panel.size)/2


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		var flow := GameFlow.find(self)
		if saved_map and flow and flow.state == GameStateMachine.State.PLAYING and not flow.is_leaving():
			var player := get_tree().get_first_node_in_group("player")
			if not visible and player != null and (bool(player.get("modal_active")) or bool(player.get("keypad_active"))):
				return
			if visible:
				close_panel()
			else:
				open_map(null,get_tree().get_first_node_in_group("player"))
			get_viewport().set_input_as_handled()
			return
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("pause"):
		close_panel()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
