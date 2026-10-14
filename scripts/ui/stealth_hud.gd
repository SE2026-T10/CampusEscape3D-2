class_name StealthHud
extends CanvasLayer

## Player-facing stealth HUD (not a debug tool; present in release builds).
##   - Banner (top centre): CHASED / BEING SEEN / A guard is investigating / HIDDEN
##   - Indicators around the crosshair: one per guard that is noticing you,
##     pointing toward that guard, filling with its detection meter, coloured
##     white → yellow "?" (suspicious / investigating) → red "!" (alerted / chasing)
##   - Stance and noise (bottom left): e.g. "CROUCHED · noise: QUIET"
##   - Detection meter (under the banner): the most aware guard's meter, with
##     marks where guards become suspicious (30) and alerted (100); it fades out
##     when no guard is noticing you
##   - Caught overlay, naming the checkpoint the player goes back to, with a
##     red vignette and a bar counting down to the respawn
## All information comes from the guards' own perception and the StealthDirector.

const COLOUR_NOTICE := Color(1, 1, 1)
const COLOUR_SUSPICIOUS := Color(1.0, 0.82, 0.2)
const COLOUR_ALERT := Color(1.0, 0.25, 0.2)
const COLOUR_HIDDEN := Color(0.45, 0.7, 1.0)
const BANNERS := {
	StealthDirector.Status.NONE: ["", Color.WHITE],
	StealthDirector.Status.HIDDEN: ["HIDDEN", COLOUR_HIDDEN],
	StealthDirector.Status.INVESTIGATING: ["A guard is investigating", COLOUR_SUSPICIOUS],
	StealthDirector.Status.SPOTTED: ["YOU ARE BEING SEEN", Color(1.0, 0.55, 0.15)],
	StealthDirector.Status.CHASE: ["CHASED — break line of sight!", COLOUR_ALERT],
	StealthDirector.Status.CAUGHT: ["", COLOUR_ALERT],
	StealthDirector.Status.ESCAPED: ["", Color.WHITE],
}
## Distance of the indicators from the screen centre, in pixels.
const RING_RADIUS := 90.0
## Detection meter size, in pixels.
const METER_SIZE := Vector2(260, 10)

var _banner: Label
var _stance: Label
var _caught: ColorRect
var _caught_label: Label
var _indicators: Control
var _meter: Control
var _meter_alpha := 0.0
var _caught_bar: ProgressBar
var _caught_time := 0.0


func _ready() -> void:
	layer = 5
	_indicators = Control.new()
	_indicators.set_anchors_preset(Control.PRESET_FULL_RECT)
	_indicators.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicators.draw.connect(_draw_indicators)
	add_child(_indicators)

	_banner = _make_label(30, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-400, 24)
	_banner.size = Vector2(800, 44)
	add_child(_banner)

	_meter = Control.new()
	_meter.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_meter.position = Vector2(-METER_SIZE.x / 2.0, 76)
	_meter.size = Vector2(METER_SIZE.x, 30)
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.draw.connect(_draw_meter)
	add_child(_meter)

	_stance = _make_label(18, HORIZONTAL_ALIGNMENT_LEFT)
	_stance.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_stance.position = Vector2(20, -44)
	_stance.size = Vector2(500, 30)
	add_child(_stance)

	_caught = ColorRect.new()
	_caught.color = Color(0.35, 0.0, 0.0, 0.6)
	_caught.set_anchors_preset(Control.PRESET_FULL_RECT)
	_caught.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caught.visible = false
	_caught.color = Color(0.25, 0.0, 0.0, 0.35)
	var vignette := TextureRect.new()
	vignette.texture = _vignette_texture()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caught.add_child(vignette)
	_caught_label = _make_label(44, HORIZONTAL_ALIGNMENT_CENTER)
	_caught_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_caught_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caught.add_child(_caught_label)
	_caught_bar = ProgressBar.new()
	_caught_bar.show_percentage = false
	_caught_bar.set_anchors_preset(Control.PRESET_CENTER)
	_caught_bar.position = Vector2(-150, 80)
	_caught_bar.size = Vector2(300, 8)
	_caught_bar.max_value = 1.0
	_caught_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caught_bar.add_theme_stylebox_override("background", _flat(Color(0, 0, 0, 0.5)))
	_caught_bar.add_theme_stylebox_override("fill", _flat(Color(1.0, 0.35, 0.3)))
	_caught.add_child(_caught_bar)
	add_child(_caught)


func _process(delta: float) -> void:
	var director := StealthDirector.find(self)
	var status: StealthDirector.Status = director.status if director else StealthDirector.Status.NONE
	var banner: Array = BANNERS[status]
	_banner.text = banner[0]
	_banner.add_theme_color_override("font_color", banner[1])
	# The chase banner pulses.
	_banner.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 110.0) if status == StealthDirector.Status.CHASE else 1.0
	var was_caught := _caught.visible
	_caught.visible = status == StealthDirector.Status.CAUGHT
	if _caught.visible:
		if not was_caught:
			_caught_time = 0.0
			_caught.modulate.a = 0.0
		_caught_time += delta
		_caught.modulate.a = minf(_caught.modulate.a + delta * 4.0, 1.0)
		_caught_label.text = get_caught_text()
		_caught_bar.value = 1.0 - clampf(_caught_time / director.reset_delay, 0.0, 1.0)
	_stance.text = get_stance_text()
	var level := get_detection_level()
	_meter_alpha = move_toward(_meter_alpha, 1.0 if level > 0.0 and status < StealthDirector.Status.CAUGHT else 0.0, delta * 3.0)
	_meter.modulate.a = _meter_alpha
	_meter.queue_redraw()
	_indicators.queue_redraw()


## How close the most aware guard is to catching on (0–1): its detection meter
## divided by 100, or 1 while any guard is chasing. 0 when no guard notices you.
func get_detection_level() -> float:
	var level := 0.0
	for guard in get_tree().get_nodes_in_group("guards"):
		if guard.machine == null or guard.vision == null:
			continue
		if guard.machine.current == GuardStateMachine.CHASE:
			return 1.0
		level = maxf(level, clampf(guard.vision.detection / GuardVision.DETECTION_MAX, 0.0, 1.0))
	return level


## Caught overlay text, naming where the player will respawn.
func get_caught_text() -> String:
	var checkpoints := CheckpointManager.find(self)
	var where := checkpoints.get_respawn_name() if checkpoints else "the entrance"
	return "CAUGHT\nBack to %s…" % where


## Bottom-left text, e.g. "CROUCHED · noise: QUIET".
func get_stance_text() -> String:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("get_noise_level"):
		return ""
	var stance := "CROUCHED" if player.is_crouching else "STANDING"
	return "%s · noise: %s" % [stance, player.get_noise_level()]


## One entry per guard that is noticing the player: where it is relative to
## the camera (degrees, 0 = straight ahead, positive = to the right), how full
## its meter is (0–1), its colour and its icon ("", "?" or "!").
func get_indicators() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return result
	for guard in get_tree().get_nodes_in_group("guards"):
		if guard.machine == null or guard.vision == null:
			continue
		var state: int = guard.machine.current
		var detection: float = guard.vision.detection
		if state == GuardStateMachine.PATROL and detection < 1.0:
			continue
		var local: Vector3 = camera.global_basis.inverse() * (guard.global_position - camera.global_position)
		var angle := rad_to_deg(atan2(local.x, -local.z))
		var colour := COLOUR_NOTICE
		var icon := ""
		if state == GuardStateMachine.CHASE or guard.vision.awareness == GuardVision.Awareness.ALERTED:
			colour = COLOUR_ALERT
			icon = "!"
		elif state == GuardStateMachine.INVESTIGATE or guard.vision.awareness == GuardVision.Awareness.SUSPICIOUS:
			colour = COLOUR_SUSPICIOUS
			icon = "?"
		var fill := 1.0 if state == GuardStateMachine.CHASE else clampf(detection / 100.0, 0.0, 1.0)
		result.append({"guard": guard, "angle": angle, "fill": fill, "colour": colour, "icon": icon})
	return result


func _draw_indicators() -> void:
	var centre := _indicators.size / 2.0
	_indicators.draw_circle(centre, 2.5, Color(1, 1, 1, 0.8))  # crosshair dot
	var font := ThemeDB.fallback_font
	for entry in get_indicators():
		var direction := Vector2.from_angle(deg_to_rad(entry.angle) - PI / 2.0)
		var side := direction.orthogonal()
		var base := centre + direction * RING_RADIUS
		var tip := base + direction * 26.0
		var outline := PackedVector2Array([base - side * 13.0, tip, base + side * 13.0])
		_indicators.draw_colored_polygon(outline, Color(0, 0, 0, 0.45))
		# Fill from the base toward the tip as the meter rises.
		var f: float = maxf(entry.fill, 0.08)
		var fill_tip := base + direction * 26.0 * f
		var w := 13.0 * (1.0 - f) + 0.0001
		var filled := PackedVector2Array([base - side * 13.0, base - side * w + direction * 26.0 * f, fill_tip, base + side * w + direction * 26.0 * f, base + side * 13.0]) \
			if f < 1.0 else outline
		_indicators.draw_colored_polygon(filled, entry.colour)
		_indicators.draw_polyline(outline + PackedVector2Array([outline[0]]), Color(entry.colour, 0.9), 1.5)
		if entry.icon != "":
			var at := tip + direction * 14.0 - Vector2(7, -9)
			_indicators.draw_string_outline(font, at, entry.icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color.BLACK)
			_indicators.draw_string(font, at, entry.icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, entry.colour)


func _draw_meter() -> void:
	var level := get_detection_level()
	var bar := Rect2(Vector2(0, 16), METER_SIZE)
	var colour := COLOUR_NOTICE.lerp(COLOUR_SUSPICIOUS, clampf(level / 0.3, 0.0, 1.0))
	if level >= 0.3:
		colour = COLOUR_SUSPICIOUS.lerp(COLOUR_ALERT, clampf((level - 0.3) / 0.7, 0.0, 1.0))
	_meter.draw_rect(bar.grow(2.0), Color(0, 0, 0, 0.55))
	_meter.draw_rect(Rect2(bar.position, Vector2(bar.size.x * level, bar.size.y)), colour)
	# Marks: suspicious (30) and alerted (100).
	var mark := bar.position.x + bar.size.x * 0.3
	_meter.draw_line(Vector2(mark, bar.position.y - 3), Vector2(mark, bar.end.y + 3), Color(1, 1, 1, 0.8), 2.0)
	var font := ThemeDB.fallback_font
	_meter.draw_string_outline(font, Vector2(0, 12), "DETECTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color.BLACK)
	_meter.draw_string(font, Vector2(0, 12), "DETECTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.85))
	_meter.draw_string_outline(font, Vector2(mark - 4, 12), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color.BLACK)
	_meter.draw_string(font, Vector2(mark - 4, 12), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOUR_SUSPICIOUS)
	_meter.draw_string_outline(font, Vector2(bar.end.x - 4, 12), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color.BLACK)
	_meter.draw_string(font, Vector2(bar.end.x - 4, 12), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOUR_ALERT)


static func _vignette_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.3, 0, 0, 0.0))
	gradient.set_color(1, Color(0.3, 0, 0, 0.85))
	gradient.add_point(0.55, Color(0.3, 0, 0, 0.1))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 1.0)
	texture.width = 256
	texture.height = 256
	return texture


static func _flat(colour: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(3)
	return box


func _make_label(font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
