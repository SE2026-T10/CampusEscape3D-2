class_name PuzzleControl
extends Interactable

## One control of a puzzle (Expanded Library, expansion Phase 4): a dial, a
## breaker, a valve or a push button, used with E like any Interactable.
##   - With `values` (e.g. OFF / ON, 0–9), each use moves to the next value
##     and emits `changed`.
##   - Without values it is a button: each use emits `pressed`.
##   - The puzzle that owns it sets `blocked_reason` while it can't be used
##     (e.g. "behind the panel cover", "no power"): it is still focused, its
##     prompt says why, and using it does nothing.
## It draws itself: a small box coloured by its value and a label.

signal changed(index: int)
signal pressed

@export var control_name := "Switch"
## Values cycled through; empty for a push button.
@export var values: PackedStringArray = PackedStringArray(["OFF", "ON"])
## Prompt verb for a button.
@export var action_text := "Press"
## Short text on its label (empty: control_name), e.g. "A1" for "A1 ARCHIVE LIGHTS".
@export var short_label := ""
## Size of the drawn box (metres).
@export var size := Vector3(0.12, 0.2, 0.08)

var index := 0
## Why it can't be used right now ("" = usable).
var blocked_reason := ""

var _material: StandardMaterial3D
var _label: Label3D


func _ready() -> void:
	super()
	var mesh := MeshInstance3D.new()
	mesh.name = "Model"
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	_material = StandardMaterial3D.new()
	mesh.material_override = _material
	add_child(mesh)
	_label = Label3D.new()
	_label.font_size = 22
	_label.pixel_size = 0.0028
	_label.outline_size = 6
	_label.position = Vector3(0, size.y / 2.0 + 0.07, size.z / 2.0 + 0.01)
	add_child(_label)
	var shape := CollisionShape3D.new()
	var area := BoxShape3D.new()
	area.size = size + Vector3(0.06, 0.06, 0.1)
	shape.shape = area
	add_child(shape)
	_update_visual()


func is_button() -> bool:
	return values.is_empty()


func get_value() -> String:
	return "" if is_button() else values[index]


func get_prompt(_by: Node) -> String:
	if blocked_reason != "":
		return "%s · %s" % [control_name, blocked_reason]
	if is_button():
		return "%s: %s" % [control_name, action_text.to_lower()]
	return "%s: %s → %s" % [control_name, values[index], values[(index + 1) % values.size()]]


func _on_interact(_by: Node) -> bool:
	if blocked_reason != "":
		return false
	if is_button():
		pressed.emit()
		return true
	index = (index + 1) % values.size()
	_update_visual()
	changed.emit(index)
	return true


## Sets the value without emitting (resets and checkpoint restores).
func set_index(value: int) -> void:
	index = clampi(value, 0, maxi(values.size() - 1, 0))
	_update_visual()


func _update_visual() -> void:
	if _material == null:
		return
	if is_button():
		_material.albedo_color = Color(0.85, 0.65, 0.15)
		_label.text = short_label if short_label != "" else control_name
	else:
		var on := index > 0 and values[index] != "SHUT" and values[index] != "OFF"
		_material.albedo_color = Color(0.25, 0.75, 0.35) if on else Color(0.55, 0.2, 0.18)
		if values.size() > 2:
			_material.albedo_color = Color(0.25, 0.27, 0.3)
		_label.text = "%s\n%s" % [short_label if short_label != "" else control_name, values[index]] if values.size() <= 2 else values[index]
		_label.font_size = 22 if values.size() <= 2 else 48
