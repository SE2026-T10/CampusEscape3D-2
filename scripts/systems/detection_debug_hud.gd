extends CanvasLayer

## Development tool: a small on-screen panel listing every guard's AI state,
## awareness, detection meter and last known player position. Shown with the other
## debug visuals (F3). Removed from release builds.

var _label: Label


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	add_to_group("debug_visuals")
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.modulate = Color(1, 1, 1, 0.9)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 15)
	panel.add_child(_label)
	add_child(panel)


func _process(_delta: float) -> void:
	if visible:
		_label.text = get_text()


## The panel text (also used by tests).
func get_text() -> String:
	var lines := PackedStringArray(["GUARDS (F3 to hide)"])
	for guard in get_tree().get_nodes_in_group("guards"):
		var vision: GuardVision = guard.get_node_or_null("Vision")
		if vision == null:
			continue
		var lkp := "-"
		if vision.has_last_known_position:
			lkp = "(%.1f, %.1f)" % [vision.last_known_position.x, vision.last_known_position.z]
		var ai: String = guard.machine.get_debug_text() if guard.machine else "-"
		lines.append("%-16s %-34s %s  last seen at %s" % [guard.name, ai, vision.get_debug_text(), lkp])
	return "\n".join(lines)
