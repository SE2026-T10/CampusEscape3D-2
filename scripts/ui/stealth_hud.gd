class_name StealthHud
extends CanvasLayer

## Player-facing stealth HUD (not a debug tool; present in release builds).
##   - Banner (top centre): CHASED / BEING SEEN / A guard is investigating / HIDDEN
##   - Indicators around the crosshair: one per guard that is noticing you,
##     pointing toward that guard, filling with its detection meter, coloured
##     white → yellow "?" (suspicious / investigating) → red "!" (alerted / chasing)
##   - Stance and noise (bottom left): e.g. "CROUCHED · noise: QUIET"
##   - Caught overlay
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
}
## Distance of the indicators from the screen centre, in pixels.
const RING_RADIUS := 90.0

var _banner: Label
var _stance: Label
var _caught: ColorRect
var _indicators: Control


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
	var caught_label := _make_label(44, HORIZONTAL_ALIGNMENT_CENTER)
	caught_label.text = "CAUGHT\nBack to the entrance…"
	caught_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	caught_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caught.add_child(caught_label)
	add_child(_caught)


func _process(_delta: float) -> void:
	var director := StealthDirector.find(self)
	var status: StealthDirector.Status = director.status if director else StealthDirector.Status.NONE
	var banner: Array = BANNERS[status]
	_banner.text = banner[0]
	_banner.add_theme_color_override("font_color", banner[1])
	_caught.visible = status == StealthDirector.Status.CAUGHT
	_stance.text = get_stance_text()
	_indicators.queue_redraw()


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


func _make_label(font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
