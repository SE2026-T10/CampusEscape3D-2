class_name SettingsPanel
extends Control

## The settings screen (expansion Phase 7), shared by the main menu and the
## pause menu: HUD scale, master volume, captions, Back. Every change applies
## at once and is saved (GameSettings). Keyboard: Up / Down between rows,
## Left / Right change the focused row, Enter / Space press, Esc or Back closes.

signal closed

var scale_button: OptionButton
var volume_slider: HSlider
var volume_label: Label
var captions_button: CheckButton
var back_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("settings_panels")
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := MenuStyle.centred_panel(self)
	box.add_child(MenuStyle.title("SETTINGS", 40, MenuStyle.ACCENT))
	GameSettings.load_settings()
	box.add_child(_row_label("Interface size"))
	scale_button = OptionButton.new()
	scale_button.custom_minimum_size = Vector2(280, 40)
	scale_button.add_theme_font_size_override("font_size", 20)
	for s in GameSettings.HUD_SCALES:
		scale_button.add_item("%d %%" % int(round(s * 100.0)))
	scale_button.select(GameSettings.HUD_SCALES.find(GameSettings.hud_scale))
	scale_button.item_selected.connect(func(i: int): GameSettings.set_hud_scale(get_tree(), GameSettings.HUD_SCALES[i]))
	box.add_child(scale_button)
	volume_label = _row_label("")
	box.add_child(volume_label)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 5.0
	volume_slider.custom_minimum_size = Vector2(280, 28)
	volume_slider.value = round(GameSettings.master_volume * 100.0)
	volume_slider.value_changed.connect(_on_volume)
	box.add_child(volume_slider)
	captions_button = CheckButton.new()
	captions_button.add_theme_font_size_override("font_size", 20)
	captions_button.button_pressed = GameSettings.captions
	captions_button.toggled.connect(func(on: bool):
		GameSettings.set_captions(get_tree(), on)
		_update_captions_label())
	box.add_child(captions_button)
	back_button = MenuStyle.button("Back")
	back_button.pressed.connect(close)
	box.add_child(back_button)
	_update_volume_label()
	_update_captions_label()
	visible = false


func open() -> void:
	GameSettings.load_settings()
	scale_button.select(GameSettings.HUD_SCALES.find(GameSettings.hud_scale))
	volume_slider.set_value_no_signal(round(GameSettings.master_volume * 100.0))
	captions_button.set_pressed_no_signal(GameSettings.captions)
	_update_volume_label()
	_update_captions_label()
	visible = true
	scale_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_volume(value: float) -> void:
	GameSettings.set_master_volume(get_tree(), value / 100.0)
	_update_volume_label()


func _update_volume_label() -> void:
	volume_label.text = "Master volume: %d %%" % int(volume_slider.value) if volume_slider.value > 0.0 else "Master volume: muted"


## The switch says its state: "Sound captions: On" / "Off".
func _update_captions_label() -> void:
	captions_button.text = "Sound captions: %s" % ("On" if captions_button.button_pressed else "Off")


func _row_label(text: String) -> Label:
	var l := MenuStyle.label(text, 18)
	l.modulate = Color(1, 1, 1, 0.85)
	return l
