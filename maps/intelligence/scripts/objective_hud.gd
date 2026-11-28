extends ObjectiveHud
const Minimap := preload("res://maps/intelligence/scripts/minimap.gd")
const Surveillance := preload("res://maps/intelligence/scripts/projection_surveillance.gd")
const B1 := preload("res://maps/intelligence/resources/layout/k17_projection.gd")
var minimap: Minimap
var _layout_key := ""
var _projection_panel: PanelContainer
var _projection_status: Label
var _camera_status: Label
var _call_status: Label
var _b1_hint: Label
var _b1_radio: Label

func _ready() -> void:
	super()
	minimap=Minimap.new()
	minimap.name="Minimap"
	minimap.size=Vector2(224,244)
	add_child(minimap)
	_message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_font_size_override("font_size",22)
	_message.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	_list.hide()
	for child in _list.get_parent().get_children():
		if child is HSeparator: child.hide()
	_current.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_build_projection_panel()
	_layout_minimap()

func _process(delta: float) -> void:
	if not visible: return
	super(delta)
	_update_projection_panel()
	_layout_minimap()

func _build_projection_panel() -> void:
	_projection_panel=PanelContainer.new()
	_projection_panel.name="B1Status"
	_projection_panel.position=Vector2(20,20)
	_projection_panel.custom_minimum_size=Vector2(304,0)
	_projection_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_projection_panel.add_theme_stylebox_override("panel",_panel.get_theme_stylebox("panel"))
	add_child(_projection_panel)
	var column:=VBoxContainer.new()
	column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_projection_panel.add_child(column)
	for id in ["Alignment","Camera","Request","Hint","Radio"]:
		var line:=_make_label(14,HORIZONTAL_ALIGNMENT_LEFT)
		line.name=id
		line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		column.add_child(line)
	_projection_status=column.get_node("Alignment")
	_camera_status=column.get_node("Camera")
	_call_status=column.get_node("Request")
	_b1_hint=column.get_node("Hint")
	_b1_radio=column.get_node("Radio")
	_projection_panel.hide()

func _update_projection_panel() -> void:
	var rig := get_tree().get_first_node_in_group("k17_projection_rigs") as K17ProjectionRig
	var camera := get_tree().get_first_node_in_group("k17_b1_surveillance") as Surveillance
	var player := get_tree().get_first_node_in_group("player") as FirstPersonPlayer
	var flow := GameFlow.find(self)
	var mission := MapHudProvider.find_for(self) as K17MissionController
	var playing := flow!=null and flow.state==GameStateMachine.State.PLAYING and not flow.is_leaving()
	var active := playing and mission!=null and not mission.has_file and camera!=null and rig!=null and player!=null and player.global_position.y< -2.0 and not _journal.visible
	var near_rig := active and player.global_position.distance_to(rig.global_position)<6.0
	_projection_panel.visible=active and (near_rig or camera.hacked)
	var show_objective_hint := not (active and rig.holder==player)
	if _hint.visible!=show_objective_hint:
		_hint.visible=show_objective_hint
		_panel.reset_size()
	if not _projection_panel.visible: return
	_status_panel.hide()
	_projection_status.visible=near_rig
	if near_rig:
		_set_text(_projection_status,rig.status_text())
		_projection_status.modulate=Color("a9e5cf") if rig.powered and rig.calibration_valid(rig.observer_eye()) and not rig.near_calibration_limit() else Color("ffcb81")
	_set_text(_camera_status,camera.feed_status())
	var feet := player.global_position
	var in_bay := feet.distance_squared_to(B1.PREP)<4.0 or feet.distance_squared_to(B1.BAYS[0])<1.44 or feet.distance_squared_to(B1.BAYS[1])<1.44
	var call := camera.call_status(in_bay and (near_rig or not rig.deployed))
	_set_text(_call_status,call)
	_call_status.visible=not call.is_empty()
	var hint := mission.nearby_sensor_status(player)
	if hint.is_empty() and near_rig and camera.hacked and rig.deployed:
		if feet.distance_squared_to(B1.PREP)<4.0 and rig.holder!=player:
			hint = "E nắm tay đẩy. Theo camera trước."
		elif not mission.is_test_mode():
			hint = "W1/W2 · Kiểm tra tuần tra trước khi rẽ."
	_set_text(_b1_hint,hint)
	_b1_hint.visible=not hint.is_empty()
	var radio := mission.get_active_radio_message()
	_set_text(_b1_radio, radio)
	_b1_radio.visible = not radio.is_empty()
	var panel_size := _projection_panel.get_combined_minimum_size()
	if _projection_panel.size!=panel_size: _projection_panel.size=panel_size
	var feed_top := _projection_panel.get_global_rect().end.y + 8.0
	var feed_bottom := get_viewport().get_visible_rect().end.y
	var captions := get_tree().get_first_node_in_group("sound_captions") as SoundCaptions
	if captions and captions.visible:
		feed_bottom = captions.get_global_rect().position.y - 8.0
	camera.place_feed(Vector2(20,feed_top),_projection_panel.size.x,feed_bottom-feed_top)

func open_journal(focus: StringName) -> void:
	var rig := get_tree().get_first_node_in_group("k17_projection_rigs")
	if rig: rig.release_grip()
	super(focus)

func _layout_minimap() -> void:
	var view := get_viewport().get_visible_rect().size
	var panel := _panel.get_global_rect()
	var slots := _slots.get_global_rect()
	var key := str([view,panel,slots])
	if key==_layout_key: return
	_layout_key=key
	var top := panel.end.y+12
	var bottom := minf(view.y-112,slots.position.y-14)
	minimap.position=Vector2(view.x-244,top)
	minimap.size=Vector2(224,minf(244,maxf(130,bottom-top)))
	# The prompt stays near the crosshair. Notices use the space above the slots.
	_message.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var message_width := minf(560,view.x*.48)
	_message.position=Vector2((view.x-message_width)/2,view.y-172)
	_message.size=Vector2(message_width,72)
	_message.add_theme_font_size_override("font_size",18)

func get_layout_controls() -> Dictionary:
	var controls := super()
	controls["minimap"]=minimap
	controls["projection_status"]=_projection_panel
	return controls

func get_header_text() -> String:
	return super().replace("MISSION","NHIỆM VỤ").replace("OBJECTIVE","MỤC TIÊU")

func get_slot_texts() -> Array[String]:
	var texts := super()
	for i in texts.size(): texts[i]=texts[i].replace("Staff access card","Giấy thông hành").replace("Glass bottle","Chai rỗng")
	return texts

func _journal_page_text(docs: Array,clues: Array,shown: int) -> String:
	var text := super(docs,clues,shown)
	for pair in [["JOURNAL","NHẬT KÝ"],["DOCUMENTS","TÀI LIỆU"],["CLUES","MANH MỐI"],["J: close","J: đóng"],["J: next document","J: tài liệu tiếp"],["J: more clues","J: manh mối tiếp"],["None yet. Read notes and notices to collect them here.","Chưa có. Đọc tài liệu trong cơ sở để lưu lại."]]: text=text.replace(pair[0],pair[1])
	return text

func show_message(text: String,colour := COLOUR_GOOD) -> void:
	for pair in [["New optional objective:","Mục tiêu tùy chọn:"],["Checkpoint reached:","Đã lưu checkpoint:"],["ALARM:","BÁO ĐỘNG:"],["code accepted.","mã hợp lệ."],["code rejected.","mã sai."],["The alarm is sounding!","Đã kích hoạt báo động!"],["Locked out for","Khóa tạm trong"],["Try again in","Thử lại sau"],["tries left.","lần thử còn lại."],["try left.","lần thử còn lại."],["spotted you","đã phát hiện bạn"],[" opened"," đã mở"]]: text=text.replace(pair[0],pair[1])
	super(text,colour)
