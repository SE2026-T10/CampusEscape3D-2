extends GameMenus
## Preserve the shared menus; show the gameplay snapshot instead of cinematic time.
func _ready() -> void:
	super()
	win_title.text = "HOÀN THÀNH NHIỆM VỤ"
	win_title.add_theme_font_size_override("font_size", 40)
	_win_stats.add_theme_font_size_override("font_size", 18)
	_win_objectives.add_theme_font_size_override("font_size", 14)
	(play_again_button.get_parent() as VBoxContainer).add_theme_constant_override("separation", 7)
	play_again_button.text = "Chơi lại"
	win_menu_button.text = "Về menu"
	resume_button.text = "Tiếp tục"
	restart_button.text = "Chơi lại từ đầu"
	pause_menu_button.text = "Về menu"
	settings_button.text = "Cài đặt"
	for label in pause_panel.find_children("*", "Label", true, false):
		if label.text == "PAUSED": label.text = "TẠM DỪNG"

func get_controls_text() -> String:
	return "WASD di chuyển · Shift chạy · C/Ctrl cúi · E/giữ E tương tác\n1–3 chọn đồ · F ném chai · J nhật ký · Esc/P tạm dừng"

func get_win_text() -> String:
	var m := MapHudProvider.find_for(self) as K17MissionController
	if m == null: return super()
	var director := StealthDirector.find(self)
	var catches := director.catches if director else 0
	var text := "Thời gian %s · Bị bắt %d lần" % [format_time(m.extraction_play_time), catches]
	for line in m.get_result_lines(): text += "\n" + line
	return text

func get_objectives_text() -> String:
	return super().replace("Mission objectives", "Mục tiêu chính").replace("complete · optional", "hoàn tất · tùy chọn").replace("Optional:", "Đã làm thêm:").replace("Escape route:", "Đường rút:")
