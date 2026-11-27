extends CanvasLayer

## Persistent local control reminder, above sound captions, stamina and stance.
@export_node_path("CharacterBody3D") var player_path := NodePath("../Player")

var _panel: PanelContainer
@onready var _player := get_node_or_null(player_path)


func _ready() -> void:
	layer = 6
	# Keep updating visibility when Escape pauses the rest of the scene.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.name = "CarryStatus"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.offset_left = 20.0
	_panel.offset_top = -306.0
	_panel.offset_right = 440.0
	_panel.offset_bottom = -246.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.78)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.name = "Instructions"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "ĐANG MANG T2 · Di chuyển chậm\nQ: đặt xuống · E: giao tại kho"
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.6))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	_panel.add_child(label)
	_update_visibility()


func _process(_delta: float) -> void:
	_update_visibility()


func _update_visibility() -> void:
	var flow := GameFlow.find(self)
	_panel.visible = is_instance_valid(_player) and _player.has_method("is_carrying") \
		and _player.call("is_carrying") and flow != null \
		and flow.state == GameStateMachine.State.PLAYING and not flow.is_leaving()
