extends ObjectiveHud

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
