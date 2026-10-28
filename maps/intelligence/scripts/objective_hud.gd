extends ObjectiveHud
const Minimap := preload("res://maps/intelligence/scripts/minimap.gd")
var minimap: Minimap
var _layout_key := ""

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

func _process(delta: float) -> void:
	super(delta)
	_layout_minimap()

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
	# Keep messages clear of both the right map and the left radio captions.
	_message.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_message.position=Vector2(432,view.y-200)
	_message.size=Vector2(maxf(220,minimap.position.x-448),72)

func get_layout_controls() -> Dictionary:
	var controls := super()
	controls["minimap"]=minimap
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
