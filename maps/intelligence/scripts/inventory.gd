extends PlayerInventory
## Content translation is local; the common item catalog stays compatible.
func use_selected() -> bool:
	if is_instance_valid(get_parent().get("projection_rig")):
		notify("Thả tay đẩy bằng E trước khi dùng vật phẩm.")
		return false
	return super()

func notify(text: String,good := false) -> void:
	for pair in [["Glass bottle","Chai rỗng"],["Staff access card","Giấy thông hành"],[" taken"," — đã lấy"],["Added to your journal:","Đã lưu nhật ký:"],["Nothing in slot","Ô đồ trống:"],["Nowhere to throw it there. Aim at the floor further away.","Không có chỗ ném. Hướng vào nền phía xa."],["Throw the","Ném"]]:
		text=text.replace(pair[0],pair[1])
	super(text,good)
