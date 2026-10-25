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
## It draws itself: by default a small box coloured by its value and a label;
## `style` gives a few controls a model of their own (Phase 9 polish, the
## electrical room): "breaker" (a circuit breaker module with a toggle lever
## and an ON / OFF window), "main_breaker" (a wide one, its lever set by its
## puzzle with set_lever()) and "rotary" (a rotary isolator: yellow plate, red
## handle a quarter turn from OFF to ON, a lamp and a name plate); for the
## code locks (polish): "key" (a keypad key marked ▲, its digit shown on the
## keypad's screen at `value_offset`; a button key reads its control_name),
## "wheel" (a combination wheel that rolls one step per use) and "lever" (a
## handle pulled down, springing back); for the pump room (polish): "handwheel"
## (a valve's red handwheel, a quarter turn from SHUT to OPEN, with an indicator
## flag on the bonnet, along the pipe = OPEN, across = SHUT, and a tag showing
## `short_label` and the state; a blocked wheel only jerks) and "starter" (a
## pump starter's green lever, pulled down, springing back unless its puzzle
## holds it down with set_lever()); for the loading dock (polish): "push" (a
## round green push button marked ▲, pressed in and back). The models only change the look: the
## interaction box is always `size`.

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
## "box" (default), "breaker", "main_breaker" or "rotary" (see above).
@export var style := "box"
## Size of a "breaker" / "main_breaker" module (zero: `size`).
@export var model_size := Vector3.ZERO
## "key": where the digit is shown (the keypad's screen), relative to the key.
@export var value_offset := Vector3(0, 0.27, 0.0)

const SNAP_TIME := 0.15
const LEVER_UP := 0.55             # lever angle (radians about x) when ON
const LEVER_DOWN := PI - 0.55      # and when OFF
const HANDLE_OFF := PI / 2.0       # rotary handle: pointing left
const WHEEL_TURN_TIME := 0.3       # handwheel: a quarter turn
const WHEEL_OPEN := PI / 2.0       # handwheel angle (about z) when OPEN; SHUT is 0
const STARTER_DOWN := 1.2          # starter lever angle (about x) when pulled

var index := 0
## Why it can't be used right now ("" = usable).
var blocked_reason := ""

var _material: StandardMaterial3D
var _label: Label3D
## Models with moving parts: the lever / handle pivot, the state window or lamp.
var _pivot: Node3D
var _window: StandardMaterial3D
var _state_text: Label3D
var _tween: Tween
var _lever_on := false
## A lamp colour set by the owner (e.g. blinking while locked); alpha 0: none.
var lamp_override := Color(0, 0, 0, 0)
## "key": the digit on the screen (dark without power).
var _value_text: Label3D
var _value_lit := true
var _cap: Node3D
var _cap_rest := Vector3.ZERO
## "handwheel": the indicator flag and its material.
var _flag: Node3D
var _flag_material: StandardMaterial3D
## "starter": the pull (it springs back at its end unless the lever is held down).
var _pull_tween: Tween


func _ready() -> void:
	super()
	if style != "box":
		_build_model()
		_update_visual(false)
		return
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
	_press()
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


## A "main_breaker"'s lever (its puzzle knows whether the main is engaged).
func set_lever(on: bool, animate := true) -> void:
	_lever_on = on
	_update_visual(animate)


## True when the control shows ON (a value other than OFF / SHUT, or a main breaker's lever up).
func shows_on() -> bool:
	if is_button():
		return _lever_on
	return index > 0 and values[index] != "SHUT" and values[index] != "OFF"


func _update_visual(animate := true) -> void:
	if style != "box":
		_update_model(animate)
		return
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


# --- Styled models (Phase 9 polish) ---------------------------------------------------------

## "key": the digit on the screen lit or dark (no power).
func set_value_lit(lit: bool) -> void:
	if lit == _value_lit:
		return
	_value_lit = lit
	if _value_text:
		_value_text.visible = lit


## A key goes in and back, a lever goes down and back (a used control, even a blocked one);
## a blocked handwheel only jerks (it is seized).
func _press() -> void:
	if not is_inside_tree():
		return
	if style == "handwheel":
		if blocked_reason != "" and _pivot:
			if _tween:
				_tween.kill()
			var rest := _pivot.rotation.z
			_tween = create_tween()
			_tween.tween_property(_pivot, "rotation:z", rest + 0.08, 0.05)
			_tween.tween_property(_pivot, "rotation:z", rest - 0.05, 0.07)
			_tween.tween_property(_pivot, "rotation:z", rest, 0.06)
		return
	if _cap == null:
		return
	if style == "starter":
		if _pull_tween:
			_pull_tween.kill()
		_pull_tween = create_tween()
		_pull_tween.tween_property(_cap, "rotation:x", STARTER_DOWN, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_pull_tween.tween_interval(0.25)
		_pull_tween.tween_callback(_spring_back)
		return
	var t := create_tween()
	if style == "lever":
		t.tween_property(_cap, "rotation:x", -1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.12)
		t.tween_property(_cap, "rotation:x", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	else:
		t.tween_property(_cap, "position", _cap_rest - Vector3(0, 0, 0.007), 0.06)
		t.tween_property(_cap, "position", _cap_rest, 0.08)


## "starter": back up after a pull, unless the puzzle holds it down (the pump runs).
func _spring_back() -> void:
	if _lever_on or _cap == null:
		return
	_pull_tween = create_tween()
	_pull_tween.tween_property(_cap, "rotation:x", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _build_model() -> void:
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	match style:
		"key":
			var cap_size := Vector3(minf(size.x * 0.9, 0.5), minf(size.y * 0.75, 0.09), 0.025)
			var colour := Color(0.18, 0.62, 0.3) if is_button() else Color(0.78, 0.8, 0.82)
			_cap = _box(model, "Cap", cap_size, Vector3(0, 0, 0.016), colour)   # in front of the keypad's housing
			_cap_rest = _cap.position
			var mark := Label3D.new()
			mark.name = "Mark"
			mark.text = control_name if is_button() else "▲"
			mark.font_size = 24 if is_button() else 30
			mark.pixel_size = 0.0018
			mark.outline_size = 0
			mark.modulate = Color(0.95, 0.98, 0.95) if is_button() else Color(0.12, 0.13, 0.15)
			mark.position = Vector3(0, 0, cap_size.z / 2.0 + 0.001)
			_cap.add_child(mark)
			if not is_button():
				_value_text = Label3D.new()
				_value_text.name = "Digit"
				_value_text.font_size = 56
				_value_text.pixel_size = 0.0016
				_value_text.outline_size = 0
				_value_text.modulate = Color(0.35, 1.0, 0.5)
				_value_text.position = value_offset
				model.add_child(_value_text)
		"wheel":
			# A drum turning about local X; its number shows in the frame's window.
			_cap = Node3D.new()
			_cap.name = "Drum"
			model.add_child(_cap)
			var drum := MeshInstance3D.new()
			drum.name = "Mesh"
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.04
			cyl.bottom_radius = 0.04
			cyl.height = size.x * 0.9
			cyl.radial_segments = 10
			drum.mesh = cyl
			drum.rotation = Vector3(0, 0, PI / 2.0)
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.2, 0.21, 0.23)
			m.roughness = 0.5
			drum.material_override = m
			_cap.add_child(drum)
			for k in 10:   # ribs, so the roll is visible
				var rib := _box(_cap, "Rib%d" % k, Vector3(size.x * 0.92, 0.006, 0.012), Vector3.ZERO, Color(0.45, 0.46, 0.48))
				var a := TAU * k / 10.0
				rib.position = Vector3(0, 0.04 * sin(a), 0.04 * cos(a))
				rib.rotation = Vector3(-a, 0, 0)
			_value_text = Label3D.new()
			_value_text.name = "Digit"
			_value_text.font_size = 40
			_value_text.pixel_size = 0.0016
			_value_text.outline_size = 4
			_value_text.outline_modulate = Color(0.1, 0.1, 0.1)
			_value_text.modulate = Color(0.97, 0.97, 0.95)
			_value_text.position = Vector3(0, 0, 0.043)
			model.add_child(_value_text)
		"lever":
			_box(model, "Mount", Vector3(0.06, 0.06, 0.03), Vector3(0, 0.02, -size.z / 2.0 + 0.015), Color(0.3, 0.31, 0.33))
			_cap = Node3D.new()
			_cap.name = "Lever"
			_cap.position = Vector3(0, 0.02, -size.z / 2.0 + 0.035)
			model.add_child(_cap)
			_box(_cap, "Arm", Vector3(0.025, 0.025, 0.05), Vector3(0, 0, 0.02), Color(0.3, 0.31, 0.33))
			_box(_cap, "Grip", Vector3(minf(size.x, 0.2), 0.03, 0.03), Vector3(0, 0, 0.045), Color(0.12, 0.12, 0.13))
		"handwheel":
			_build_handwheel(model)
		"push":
			_cap = Node3D.new()
			_cap.name = "Cap"
			_cap.position = Vector3(0, 0, size.z / 2.0 + 0.012)
			_cap_rest = _cap.position
			model.add_child(_cap)
			_cylinder(_cap, "Button", 0.034, 0.026, Vector3.ZERO, Vector3(PI / 2.0, 0, 0), Color(0.12, 0.62, 0.28))
			_cylinder(model, "Collar", 0.044, 0.012, Vector3(0, 0, size.z / 2.0 + 0.002), Vector3(PI / 2.0, 0, 0), Color(0.15, 0.15, 0.16))
			var arrow := Label3D.new()
			arrow.name = "Mark"
			arrow.text = "▲"
			arrow.font_size = 28
			arrow.pixel_size = 0.0016
			arrow.outline_size = 0
			arrow.modulate = Color(0.95, 0.98, 0.95)
			arrow.position = Vector3(0, 0, 0.0135)
			_cap.add_child(arrow)
		"starter":
			_box(model, "Slot", Vector3(0.07, 0.3, 0.01), Vector3(0, 0.0, -size.z / 2.0 + 0.005), Color(0.1, 0.1, 0.11))
			_cap = Node3D.new()
			_cap.name = "Lever"
			_cap.position = Vector3(0, -0.11, -size.z / 2.0 + 0.03)
			model.add_child(_cap)
			_box(_cap, "Boss", Vector3(0.06, 0.05, 0.04), Vector3.ZERO, Color(0.25, 0.26, 0.28))
			_box(_cap, "Arm", Vector3(0.024, 0.2, 0.024), Vector3(0, 0.11, 0.0), Color(0.62, 0.64, 0.66))
			_box(_cap, "Grip", Vector3(0.1, 0.045, 0.045), Vector3(0, 0.22, 0.0), Color(0.12, 0.6, 0.25))
		"breaker", "main_breaker":
			var m := model_size if model_size != Vector3.ZERO else size
			_box(model, "Module", m, Vector3.ZERO, Color(0.92, 0.92, 0.9))
			_box(model, "Face", Vector3(m.x * 0.8, m.y * 0.55, 0.006), Vector3(0, m.y * 0.12, m.z / 2.0), Color(0.82, 0.82, 0.8))
			_pivot = Node3D.new()
			_pivot.name = "Lever"
			_pivot.position = Vector3(0, m.y * 0.12, m.z / 2.0)
			model.add_child(_pivot)
			var lever_w := 0.02 if style == "breaker" else m.x * 0.45
			_box(_pivot, "Handle", Vector3(lever_w, 0.05, 0.022), Vector3(0, 0.025, 0.0), Color(0.08, 0.08, 0.09))
			var win := _box(model, "Window", Vector3(minf(m.x * 0.5, 0.06), 0.018, 0.006), Vector3(0, -m.y * 0.2, m.z / 2.0 + 0.001), Color.WHITE)
			_window = win.material_override
			_window.emission_enabled = true
			_state_text = Label3D.new()
			_state_text.name = "State"
			_state_text.font_size = 14
			_state_text.pixel_size = 0.0022
			_state_text.outline_size = 0
			_state_text.modulate = Color(0.1, 0.1, 0.1)
			_state_text.position = Vector3(0, -m.y * 0.36, m.z / 2.0 + 0.004)
			model.add_child(_state_text)
		"rotary":
			_box(model, "Plate", Vector3(0.2, 0.2, 0.02), Vector3(0, 0, -size.z / 2.0 + 0.01), Color(0.95, 0.75, 0.1))
			_box(model, "Hub", Vector3(0.05, 0.05, 0.03), Vector3(0, 0, -size.z / 2.0 + 0.035), Color(0.75, 0.1, 0.08))
			_pivot = Node3D.new()
			_pivot.name = "Handle"
			_pivot.position = Vector3(0, 0, -size.z / 2.0 + 0.045)
			model.add_child(_pivot)
			_box(_pivot, "Bar", Vector3(0.032, 0.1, 0.03), Vector3(0, 0.05, 0), Color(0.75, 0.1, 0.08))
			var face_z := -size.z / 2.0 + 0.022
			_mark(model, "OFF", Vector3(-0.07, -0.045, face_z))
			_mark(model, "ON", Vector3(0.05, 0.078, face_z))
			# The name plate above, the lamp below.
			_box(model, "NamePlate", Vector3(0.24, 0.045, 0.012), Vector3(0, 0.135, -size.z / 2.0 + 0.006), Color(0.16, 0.17, 0.19))
			var name_text := Label3D.new()
			name_text.name = "Name"
			name_text.text = control_name
			name_text.font_size = 16
			name_text.pixel_size = 0.0025
			name_text.outline_size = 0
			name_text.modulate = Color(0.95, 0.95, 0.92)
			name_text.position = Vector3(0, 0.135, -size.z / 2.0 + 0.014)
			model.add_child(name_text)
			var lamp_mesh := MeshInstance3D.new()
			lamp_mesh.name = "Lamp"
			var lens := CylinderMesh.new()
			lens.top_radius = 0.02
			lens.bottom_radius = 0.022
			lens.height = 0.02
			lens.radial_segments = 12
			lamp_mesh.mesh = lens
			lamp_mesh.rotation = Vector3(PI / 2.0, 0, 0)
			lamp_mesh.position = Vector3(0, -0.135, -size.z / 2.0 + 0.01)
			_window = StandardMaterial3D.new()
			_window.emission_enabled = true
			lamp_mesh.material_override = _window
			model.add_child(lamp_mesh)
	var shape := CollisionShape3D.new()
	var area := BoxShape3D.new()
	area.size = size + Vector3(0.06, 0.06, 0.1)
	shape.shape = area
	add_child(shape)


## "handwheel" (local +z toward the player, the pipe behind): bonnet, red wheel with three
## spokes (turning about z), the indicator flag above and the tag below.
func _build_handwheel(model: Node3D) -> void:
	var grey := Color(0.3, 0.31, 0.33)
	var red := Color(0.68, 0.08, 0.06)
	_cylinder(model, "Bonnet", 0.032, 0.09, Vector3(0, 0, -0.05), Vector3(PI / 2.0, 0, 0), grey)
	_pivot = Node3D.new()
	_pivot.name = "Wheel"
	_pivot.position = Vector3(0, 0, 0.005)
	model.add_child(_pivot)
	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.112
	torus.outer_radius = 0.14
	torus.rings = 24
	torus.ring_segments = 8
	rim.mesh = torus
	rim.rotation = Vector3(PI / 2.0, 0, 0)
	rim.material_override = _material_of(red, 0.45)
	_pivot.add_child(rim)
	for k in 3:
		var spoke := _box(_pivot, "Spoke%d" % k, Vector3(0.235, 0.018, 0.014), Vector3.ZERO, red)
		spoke.rotation = Vector3(0, 0, PI * k / 3.0)
	_cylinder(_pivot, "Hub", 0.03, 0.035, Vector3.ZERO, Vector3(PI / 2.0, 0, 0), Color(0.5, 0.06, 0.05))
	# The indicator: a flag on a post above the bonnet.
	_box(model, "FlagPost", Vector3(0.014, 0.06, 0.014), Vector3(0, 0.16, -0.075), grey)
	_flag = Node3D.new()
	_flag.name = "Flag"
	_flag.position = Vector3(0, 0.195, -0.075)
	model.add_child(_flag)
	var flag_mesh := _box(_flag, "Plate", Vector3(0.13, 0.026, 0.01), Vector3.ZERO, Color.WHITE)
	_flag_material = flag_mesh.material_override
	# The tag below: the valve's short name and its state.
	_box(model, "Tag", Vector3(0.12, 0.075, 0.006), Vector3(0, -0.215, -0.09), Color(0.85, 0.72, 0.3))
	var name_text := Label3D.new()
	name_text.name = "Name"
	name_text.text = short_label if short_label != "" else control_name
	name_text.font_size = 22
	name_text.pixel_size = 0.0018
	name_text.outline_size = 0
	name_text.modulate = Color(0.08, 0.08, 0.08)
	name_text.position = Vector3(0, -0.198, -0.086)
	model.add_child(name_text)
	_state_text = Label3D.new()
	_state_text.name = "State"
	_state_text.font_size = 16
	_state_text.pixel_size = 0.0018
	_state_text.outline_size = 0
	_state_text.modulate = Color(0.08, 0.08, 0.08)
	_state_text.position = Vector3(0, -0.233, -0.086)
	model.add_child(_state_text)


func _cylinder(parent: Node3D, node_name: String, radius: float, height: float, at: Vector3, rot: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 12
	cyl.rings = 1
	mesh.mesh = cyl
	mesh.material_override = _material_of(colour, 0.6)
	mesh.position = at
	mesh.rotation = rot
	parent.add_child(mesh)
	return mesh


func _material_of(colour: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	return material


func _box(parent: Node3D, node_name: String, box_size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = box_size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.6
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh


func _mark(parent: Node3D, text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.name = text
	label.text = text
	label.font_size = 14
	label.pixel_size = 0.0022
	label.outline_size = 0
	label.modulate = Color(0.1, 0.1, 0.1)
	label.position = at
	parent.add_child(label)


func _update_model(animate: bool) -> void:
	if style in ["key", "wheel", "lever", "push"]:
		_update_code_model(animate)
		return
	if style == "handwheel":
		_update_handwheel(animate)
		return
	if style == "starter":
		# Held down while its puzzle says so; a pull in progress springs back by itself.
		if _cap and not (_pull_tween and _pull_tween.is_running()):
			_cap.rotation.x = STARTER_DOWN if _lever_on else 0.0
		return
	if _pivot == null:
		return
	var on := shows_on()
	var angle := 0.0
	var axis := "rotation:x"
	if style == "rotary":
		axis = "rotation:z"
		angle = 0.0 if on else HANDLE_OFF
	else:
		angle = LEVER_UP if on else LEVER_DOWN
	if _tween:
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.tween_property(_pivot, axis, angle, SNAP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif style == "rotary":
		_pivot.rotation.z = angle
	else:
		_pivot.rotation.x = angle
	_set_lamp()
	if _state_text:
		_state_text.text = "ON" if on else "OFF"


## The window (breakers) or lamp (rotary): green ON, red OFF, or the owner's override.
func _set_lamp() -> void:
	if _window == null:
		return
	var colour := Color(0.2, 0.85, 0.35) if shows_on() else Color(0.85, 0.15, 0.1)
	if lamp_override.a > 0.0:
		colour = Color(lamp_override, 1.0)
	_window.albedo_color = colour
	_window.emission = colour
	_window.emission_energy_multiplier = 0.6 if style == "rotary" else 0.35


func _update_handwheel(animate: bool) -> void:
	if _pivot == null:
		return
	var open := shows_on()
	var angle := WHEEL_OPEN if open else 0.0
	if _tween:
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.tween_property(_pivot, "rotation:z", angle, WHEEL_TURN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		_tween.parallel().tween_property(_flag, "rotation:z", 0.0 if open else PI / 2.0, WHEEL_TURN_TIME)
	else:
		_pivot.rotation.z = angle
		_flag.rotation.z = 0.0 if open else PI / 2.0
	var colour := Color(0.2, 0.7, 0.3) if open else Color(0.8, 0.15, 0.1)
	_flag_material.albedo_color = colour
	_state_text.text = values[index] if not is_button() else ""


func _update_code_model(animate: bool) -> void:
	if _value_text and not is_button():
		_value_text.text = values[index]
	if style != "wheel" or _cap == null:
		return
	# The drum rolls one step (36°) per value.
	var angle := -TAU * index / maxf(values.size(), 1.0)
	if _tween:
		_tween.kill()
	if animate and is_inside_tree():
		var from := _cap.rotation.x
		while angle > from + 0.01:
			angle -= TAU   # always roll forward
		_tween = create_tween()
		_tween.tween_property(_cap, "rotation:x", angle, SNAP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_cap.rotation.x = angle

