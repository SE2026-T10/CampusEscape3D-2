extends CanvasLayer

var door: Node3D
var actor: Node3D
var digits := ""
var panel: PanelContainer
var display: Label
var message: Label
var backdrop: ColorRect
var _old_mouse := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 15
	backdrop = ColorRect.new()
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0,0,0,0.65)
	panel = PanelContainer.new()
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12,0.16,0.15)
	style.set_content_margin_all(24)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(380,0)
	column.add_theme_constant_override("separation",12)
	panel.add_child(column)
	var title := Label.new()
	title.text = "KHO PHỤ · KHÓA MÃ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",26)
	column.add_child(title)
	display = Label.new()
	display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	display.add_theme_font_size_override("font_size",36)
	column.add_child(display)
	message = Label.new()
	message.text = "Nhập 4 số · Enter xác nhận"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size",18)
	column.add_child(message)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	column.add_child(grid)
	for caption in ["1","2","3","4","5","6","7","8","9","Xóa","0","Mở"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size = Vector2(120,48)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_button.bind(caption))
		grid.add_child(button)
	var close := Button.new()
	close.text = "Cất bàn phím (E / Esc)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_panel)
	column.add_child(close)
	var hint := Label.new()
	hint.text = "Thế giới vẫn chạy khi nhập mã"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	hide()


func open_for(target: Node3D, by: Node3D) -> void:
	if visible:
		return
	door = target
	actor = by
	var flow := GameFlow.find(self)
	if flow and not flow.state_changed.is_connected(_on_flow_changed):
		flow.state_changed.connect(_on_flow_changed)
	digits = ""
	message.text = "Nhập 4 số · Enter xác nhận"
	_old_mouse = Input.mouse_mode
	actor.set("keypad_active",true)
	actor.velocity.x = 0
	actor.velocity.z = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var reader := get_tree().get_first_node_in_group("staff_reader")
	if reader:
		reader.close_document()
	_update_display()
	show()
	_fit()


func close_panel() -> void:
	if not visible:
		return
	hide()
	if is_instance_valid(actor):
		actor.set("keypad_active",false)
	var flow := GameFlow.find(self)
	if flow and flow.state == GameStateMachine.State.PLAYING and not flow.is_leaving():
		Input.mouse_mode = _old_mouse
	door = null
	actor = null


func _on_flow_changed(_from: int, to: int) -> void:
	if to != GameStateMachine.State.PLAYING:
		close_panel()


func _process(_delta: float) -> void:
	if not visible:
		return
	var flow := GameFlow.find(self)
	if not is_instance_valid(actor) or not is_instance_valid(door) or flow == null \
			or flow.state != GameStateMachine.State.PLAYING or flow.is_leaving() \
			or actor.global_position.distance_to(door.global_position) > 3.0:
		close_panel()
		return
	_fit()


func _fit() -> void:
	panel.size = panel.get_combined_minimum_size()
	panel.position = (get_viewport().get_visible_rect().size-panel.size)/2


func _button(value: String) -> void:
	if not visible:
		return
	if value == "Mở":
		_confirm()
	elif value == "Xóa":
		digits = digits.left(maxi(0,digits.length()-1))
	else:
		if digits.length() < 4:
			digits += value
	_update_display()


func _confirm() -> void:
	if digits.length() != 4:
		message.text = "Cần nhập đủ 4 số"
		return
	var target := door
	var receipt: Dictionary = target.submit_code_request(target.get_instance_id(), target.next_keypad_request_id(), digits, actor)
	if not visible or door != target:
		return
	if receipt.status == &"UNLOCKED":
		close_panel()
		return
	if receipt.status == &"WRONG_CODE":
		message.text = "Cảnh báo! Sai mã ba lần" if receipt.alarm_triggered else "Sai mã · thử lại"
	else:
		message.text = "Chưa thể gửi mã · thử lại"
	digits = ""
	_update_display()


func _update_display() -> void:
	display.text = digits + "_".repeat(4-digits.length())


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("pause"):
		close_panel()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		if event.pressed and not event.echo:
			if event.unicode >= 48 and event.unicode <= 57:
				_button(String.chr(event.unicode))
			elif event.keycode >= KEY_0 and event.keycode <= KEY_9:
				_button(str(event.keycode-KEY_0))
			elif event.keycode >= KEY_KP_0 and event.keycode <= KEY_KP_9:
				_button(str(event.keycode-KEY_KP_0))
			elif event.keycode in [KEY_ENTER,KEY_KP_ENTER]:
				_confirm()
			elif event.keycode in [KEY_BACKSPACE,KEY_DELETE]:
				_button("Xóa")
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
