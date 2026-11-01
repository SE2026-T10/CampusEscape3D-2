extends ObjectiveHud
const Minimap := preload("res://maps/intelligence/scripts/minimap.gd")
var minimap: Minimap
var _layout_key := ""
var _projection_status: Label

func _ready() -> void:
	super()
	minimap=Minimap.new()
	minimap.name="Minimap"
	minimap.size=Vector2(224,244)
	add_child(minimap)
	_message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_font_size_override("font_size",22)
	_message.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	_layout_minimap()
	_projection_status=Label.new()
	_projection_status.name="ProjectionStatus"
	_projection_status.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_projection_status.size=Vector2(224,64)
	_projection_status.add_theme_font_size_override("font_size",14)
	_projection_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_projection_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_projection_status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_projection_status)

func _process(delta: float) -> void:
	super(delta)
	_update_projection_status()
	_layout_minimap()

func _update_projection_status() -> void:
	var rig := get_tree().get_first_node_in_group("k17_projection_rigs") as K17ProjectionRig
	var player := get_tree().get_first_node_in_group("player") as FirstPersonPlayer
	var flow := GameFlow.find(self)
	var objectives := ObjectiveManager.find(self)
	_projection_status.visible=rig!=null and player!=null and flow!=null and objectives!=null and objectives.is_completed(K17MissionController.VAULT) and flow.state==GameStateMachine.State.PLAYING and not _journal.visible and player.global_position.distance_to(rig.global_position)<6.0
	if not _projection_status.visible: return
	var mission := MapHudProvider.find_for(self) as K17MissionController
	if mission and (mission.has_file or mission.finale_pending):
		_projection_status.visible=false
		return
	_projection_status.text=rig.status_text()
	_projection_status.modulate=Color("72c5ac") if rig.calibration_valid(rig.observer_eye()) and not rig.near_calibration_limit() else Color("e6c487")

func open_journal(focus: StringName) -> void:
	var rig := get_tree().get_first_node_in_group("k17_projection_rigs")
	if rig: rig.release_grip()
	super(focus)

func _layout_minimap() -> void:
	var view := get_viewport().get_visible_rect().size
	var panel := _panel.get_global_rect()
	var slots := _slots.get_global_rect()
	var projection_shown := is_instance_valid(_projection_status) and _projection_status.visible
	var key := str([view,panel,slots,projection_shown])
	if key==_layout_key: return
	_layout_key=key
	var top := panel.end.y+12
	var bottom := minf(view.y-112,slots.position.y-14)
	minimap.position=Vector2(view.x-244,top)
	minimap.size=Vector2(224,minf(244,maxf(130,bottom-top-(72 if projection_shown else 0))))
	if projection_shown:
		_projection_status.position=minimap.position+Vector2(0,minimap.size.y+8)
	# Keep messages clear of both the right map and the left radio captions.
	_message.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_message.position=Vector2(432,view.y-200)
	var message_width := maxf(100,minimap.position.x-448)
	_message.size=Vector2(message_width,72)
	_message.add_theme_font_size_override("font_size",14 if message_width<240 else 22)

func get_layout_controls() -> Dictionary:
	var controls := super()
	controls["minimap"]=minimap
	controls["projection_status"]=_projection_status
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
