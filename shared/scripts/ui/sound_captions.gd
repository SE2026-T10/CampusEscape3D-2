class_name SoundCaptions
extends Control

## Captions for important sounds (expansion Phase 7, accessibility), built by
## StealthHud on both maps; shown only while GameSettings.captions is on.
## Bottom left, above the stamina bar, newest last, up to MAX_LINES, each for LINE_TIME seconds, e.g.
##   ← Footsteps (close)      → ALARM ringing      ↓ Glass smashes
## The arrow is the direction of the sound from where the player faces (ahead
## ↑, behind ↓, left ←, right →); "above" / "below" mark another floor.
## Sources (they only report; nothing here changes gameplay):
##   - NoiseSystem: every noise with a caption, and every alarm, the player could
##     hear (within the noise's radius, or 1.5× it for alarms);
##   - AudioDirector: the stealth stingers (a guard notices you, investigates,
##     gives chase, loses you);
##   - GuardPresentation: footsteps and radio of guards within earshot;
##   - PlayerStamina: running out of breath.
## The same cue (key) is merged instead of repeated within MERGE_TIME.

const MAX_LINES := 4
const LINE_TIME := 3.5
const MERGE_TIME := 2.5
const FONT_SIZE := 17

var lines: Array[Dictionary] = []   # {key, text, at, time_left, count}
## Every caption shown (text without arrow), for tests.
var history: Array[String] = []

var _labels: Array[Label] = []
var _box: VBoxContainer


## Reports a sound. `at`: where it is (Vector3.INF: no direction, e.g. your own
## breath); `audible`: the farthest distance (metres) it is captioned at.
static func cue(node: Node, key: String, text: String, at := Vector3.INF, audible := INF) -> void:
	if node == null or not node.is_inside_tree():
		return
	var captions := node.get_tree().get_first_node_in_group("sound_captions") as SoundCaptions
	if captions:
		captions.add(key, text, at, audible)


func _ready() -> void:
	add_to_group("sound_captions")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Bottom left, above the stamina bar and stance line, clear of the slots and
	# both panels at every interface size (anchors and offsets set directly:
	# this runs inside the tree).
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 0.0
	anchor_bottom = 1.0
	offset_left = 20.0
	offset_top = -238.0
	offset_right = 420.0
	offset_bottom = -98.0
	_box = VBoxContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.alignment = BoxContainer.ALIGNMENT_END
	_box.add_theme_constant_override("separation", 4)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	for i in MAX_LINES:
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.62)
		style.set_corner_radius_all(4)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		panel.add_theme_stylebox_override("panel", style)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(label)
		panel.visible = false
		_box.add_child(panel)
		_labels.append(label)
	_connect.call_deferred()


func _connect() -> void:
	var noise := NoiseSystem.find(self)
	if noise and not noise.noise_emitted.is_connected(_on_noise):
		noise.noise_emitted.connect(_on_noise)
	var player := get_tree().get_first_node_in_group("player")
	var stamina := player.get_node_or_null("Stamina") as PlayerStamina if player else null
	if stamina and not stamina.exhausted.is_connected(_on_exhausted):
		stamina.exhausted.connect(_on_exhausted)


func add(key: String, text: String, at := Vector3.INF, audible := INF) -> void:
	if not GameSettings.captions:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if at != Vector3.INF and player and player.global_position.distance_to(at) > audible:
		return
	for line in lines:
		if line.key == key:
			line.text = text
			line.at = at
			line.time_left = LINE_TIME
			line.count += 1
			_refresh()
			return
	lines.append({"key": key, "text": text, "at": at, "time_left": LINE_TIME, "count": 1, "age": 0.0})
	history.append(text)
	while lines.size() > MAX_LINES:
		lines.pop_front()
	_refresh()


## The captions as shown, with their direction arrows.
func get_shown_texts() -> Array[String]:
	var out: Array[String] = []
	for line in lines:
		out.append(_line_text(line))
	return out


func _process(delta: float) -> void:
	visible = GameSettings.captions
	if lines.is_empty():
		return
	for line in lines:
		line.time_left -= delta
		line.age += delta
	lines = lines.filter(func(l): return l.time_left > 0.0)
	_refresh()


func _refresh() -> void:
	for i in MAX_LINES:
		var panel := _labels[i].get_parent() as Control
		var j := i - (MAX_LINES - lines.size())
		if j < 0:
			panel.visible = false
			continue
		var line: Dictionary = lines[j]
		panel.visible = true
		_labels[i].text = _line_text(line)
		panel.modulate.a = clampf(line.time_left, 0.0, 1.0)


func _line_text(line: Dictionary) -> String:
	return (direction_of(line.at) + " " if line.at != Vector3.INF else "") + line.text


## An arrow for where `at` is from the player's view, with "above" / "below" for another floor.
func direction_of(at: Vector3) -> String:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return ""
	var local := player.global_transform.affine_inverse() * at
	var arrow := "↑"
	var angle := rad_to_deg(atan2(local.x, -local.z))
	if absf(angle) > 135.0:
		arrow = "↓"
	elif angle > 45.0:
		arrow = "→"
	elif angle < -45.0:
		arrow = "←"
	var dy := at.y - player.global_position.y
	if dy > 2.5:
		arrow += " above"
	elif dy < -2.5:
		arrow += " below"
	return arrow


func _on_noise(event: NoiseEvent) -> void:
	var text := event.caption
	var reach := event.radius
	if text == "" and event.source_group == "alarm":
		text = "ALARM ringing"
	if event.source_group == "alarm":
		reach = event.radius * 1.5
	if text == "":
		return
	add("noise:%s" % text, text, event.position, reach)


func _on_exhausted() -> void:
	add("breath", "You're out of breath")
