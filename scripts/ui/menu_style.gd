class_name MenuStyle
extends RefCounted

## Shared look for the menus (main menu, pause menu, win screen).

const ACCENT := Color(1.0, 0.82, 0.3)
const PANEL := Color(0.04, 0.05, 0.08, 0.92)


static func title(text: String, size := 48, colour := Color.WHITE) -> Label:
	var label := label(text, size)
	label.add_theme_color_override("font_color", colour)
	return label


static func label(text: String, size := 18) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	return l


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 46)
	b.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(6)
		box.set_content_margin_all(8)
		match state:
			"normal":
				box.bg_color = Color(0.14, 0.16, 0.2)
			"hover":
				box.bg_color = Color(0.22, 0.25, 0.31)
			"pressed":
				box.bg_color = Color(0.3, 0.26, 0.12)
			"focus":
				box.bg_color = Color(0, 0, 0, 0)
				box.border_color = ACCENT
				box.set_border_width_all(2)
		b.add_theme_stylebox_override(state, box)
	b.mouse_entered.connect(func(): play_ui_sound(b, "ui_hover", -8.0))
	b.pressed.connect(func(): play_ui_sound(b, "ui_click"))
	return b


## Plays a UI sound for `node`: through the level's AudioDirector when there is
## one, otherwise (main menu) on a short-lived player that works while paused.
static func play_ui_sound(node: Node, sound: String, volume_db := 0.0) -> void:
	if not node.is_inside_tree():
		return
	var audio := AudioDirector.find(node)
	if audio:
		audio.play_ui(sound, volume_db)
		return
	var stream := SoundBank.pick(sound)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"UI"
	player.volume_db = volume_db - 4.0
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.finished.connect(player.queue_free)
	node.get_tree().root.add_child(player)
	player.play()


## A centred panel with a vertical list, filling `parent`. Returns the list.
static func centred_panel(parent: Control) -> VBoxContainer:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(centre)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.set_corner_radius_all(10)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	centre.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	return box
