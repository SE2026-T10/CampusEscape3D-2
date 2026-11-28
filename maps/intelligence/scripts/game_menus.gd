extends GameMenus
## Preserve the shared menus; show the gameplay snapshot instead of cinematic time.
const WORKSHOP_RESULT_HEIGHT := 900.0

var _result_view: SubViewport
var _result_ui: CanvasLayer
var _result_background: TextureRect
var _result_image: TextureRect

func _ready() -> void:
	super()
	win_title.text = "HOÀN THÀNH NHIỆM VỤ"
	win_title.add_theme_font_size_override("font_size", 40)
	_win_stats.add_theme_font_size_override("font_size", 18)
	_win_objectives.add_theme_font_size_override("font_size", 14)
	# The results card already has a dark backing; its labels need only the fill glyphs.
	for label in win_panel.find_children("*", "Label", true, false):
		label.add_theme_constant_override("outline_size", 0)
	(play_again_button.get_parent() as VBoxContainer).add_theme_constant_override("separation", 7)
	play_again_button.text = "Chơi lại"
	win_menu_button.text = "Về menu"
	resume_button.text = "Tiếp tục"
	restart_button.text = "Chơi lại từ đầu"
	pause_menu_button.text = "Về menu"
	settings_button.text = "Cài đặt"
	for label in pause_panel.find_children("*", "Label", true, false):
		if label.text == "PAUSED": label.text = "TẠM DỪNG"
	if DisplayServer.get_name() != "headless":
		_setup_result_view()
		_warm_result_text.call_deferred()

func _setup_result_view() -> void:
	_result_view = SubViewport.new()
	_result_view.disable_3d = true
	_result_view.gui_disable_input = true
	_result_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_result_view.size_2d_override_stretch = true
	add_child(_result_view)
	_result_background = _result_texture(_result_view)
	_result_image = _result_texture(self)
	_result_image.texture = _result_view.get_texture()
	_result_image.hide()
	_result_ui = CanvasLayer.new()
	_result_ui.layer = layer
	_result_ui.custom_viewport = _result_view
	add_child(_result_ui)
	for button in [play_again_button, win_menu_button]:
		button.draw.connect(_redraw_result)
	get_viewport().size_changed.connect(_resize_result_view)
	_resize_result_view()
	_result_view.render_target_update_mode = SubViewport.UPDATE_ONCE

func _result_texture(parent: Node) -> TextureRect:
	var image := TextureRect.new()
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	parent.add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return image

func _resize_result_view() -> void:
	var viewport := get_viewport()
	var pixels := viewport.get_texture().get_size().max(Vector2(2, 2))
	_result_view.size = Vector2i((pixels * minf(1.0, WORKSHOP_RESULT_HEIGHT / pixels.y)).round())
	_result_view.size_2d_override = Vector2i(viewport.get_visible_rect().size)
	_redraw_result()

func _redraw_result() -> void:
	if _result_image.visible:
		_result_view.render_target_update_mode = SubViewport.UPDATE_ONCE

func _cache_workshop_result(backdrop: TextureRect) -> void:
	# The controls remain in the window for native input and keyboard focus.
	prepare_workshop_result()
	_set_result_backdrop(backdrop)
	_result_background.self_modulate = backdrop.self_modulate
	_result_image.show()
	backdrop.hide()
	_redraw_result()
	if not play_again_button.has_focus():
		play_again_button.grab_focus()

func prepare_workshop_result() -> void:
	if _result_ui and win_panel.get_parent() != _result_ui:
		win_panel.reparent(_result_ui, false)

func _set_result_backdrop(backdrop: TextureRect) -> void:
	_result_background.texture = backdrop.texture
	_result_background.stretch_mode = backdrop.stretch_mode

func warm_workshop_result(backdrop: TextureRect) -> void:
	if not _result_view: return
	_set_result_backdrop(backdrop)
	_result_view.render_target_update_mode = SubViewport.UPDATE_ONCE

func cancel_workshop_result() -> void:
	if not _result_ui or win_panel.get_parent() != _result_ui: return
	_result_image.hide()
	_result_background.texture = null
	_result_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	win_panel.reparent(self, false)

func _warm_result_text() -> void:
	# Use the real fonts and viewport scale without making the panel visible or focusable.
	var canvas := RenderingServer.canvas_item_create()
	for control in win_panel.find_children("*", "Control", true, false):
		if not (control is Label or control is Button): continue
		var sample := str(control.text)
		if control == _win_stats: sample = get_win_text() + " 0123456789"
		if control == _win_objectives: sample = get_objectives_text()
		var line := TextLine.new()
		line.add_string(sample.replace("\n", " "), control.get_theme_font("font"), control.get_theme_font_size("font_size"))
		line.draw(canvas, Vector2.ZERO, Color.WHITE, get_viewport().get_oversampling())
	RenderingServer.free_rid(canvas)

func _pop_title() -> void:
	# Keep the heading at its warmed, native font scale.
	win_title.scale = Vector2.ONE

func _fade_in(panel: Control, seconds: float) -> void:
	if panel == win_panel:
		panel.self_modulate.a = 1.0
		var objectives := ObjectiveManager.find(self)
		if objectives and objectives.escape_route == &"maintenance" \
				and objectives.is_completed(K17MissionController.SABOTAGE):
			var finale := get_parent().get_node_or_null("Gameplay/ExtractionFinale")
			if finale and finale.tint_workshop_result():
				panel.self_modulate.a = 0.0
				if _result_view:
					_cache_workshop_result(finale._workshop_backdrop)
			panel.modulate.a = 1.0
			return
	super(panel, seconds)

func prepare_workshop_summary() -> void:
	_win_stats.text = get_win_text()
	_win_stats.get_combined_minimum_size()

func get_controls_text() -> String:
	return "WASD di chuyển · Shift chạy · C/Ctrl cúi · E/giữ E tương tác\nV camera B1 · R gọi chốt · M bản đồ · J nhật ký\n1–3 chọn đồ · F ném chai · Esc/P tạm dừng"

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
