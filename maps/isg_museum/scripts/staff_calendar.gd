extends "res://maps/isg_museum/scripts/staff_document.gd"

var time_provider := Callable(Time,"get_datetime_dict_from_system")
var calendar_viewport: SubViewport
var face: Control
var current_date: Dictionary = {}
var _refresh_left := 0.0

func _ready() -> void:
	super()
	add_to_group("staff_calendar")
	title = "Lịch treo tường"
	prompt = "Xem lịch tháng"
	$Text.hide()
	$Board.mesh = $Board.mesh.duplicate()
	$Board.mesh.size = Vector3(1.05,1.6,.05)
	$CollisionShape3D.shape = $CollisionShape3D.shape.duplicate()
	$CollisionShape3D.shape.size = Vector3(1.15,1.7,.2)
	calendar_viewport = SubViewport.new()
	calendar_viewport.size = Vector2i(600,850)
	calendar_viewport.disable_3d = true
	add_child(calendar_viewport)
	face = preload("res://maps/isg_museum/scripts/staff_calendar_face.gd").new()
	face.size = Vector2(600,850)
	calendar_viewport.add_child(face)
	var visual := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.04,1.59)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = calendar_viewport.get_texture()
	quad.material = material
	visual.mesh = quad
	visual.position.z = .032
	add_child(visual)
	refresh_clock()

func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0:
		_refresh_left = 1.0
		refresh_clock()

func refresh_clock() -> void:
	var now: Dictionary = time_provider.call()
	if current_date.get("day") == now.day and current_date.get("month") == now.month and current_date.get("year") == now.year:
		return
	current_date = now.duplicate()
	if face:
		face.set_date(current_date)
		calendar_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func get_code() -> String:
	refresh_clock()
	return "%02d%02d"%[current_date.day,current_date.month]

func get_content() -> String:
	refresh_clock()
	return "%02d/%02d/%04d"%[current_date.day,current_date.month,current_date.year]

func _on_interact(_by: Node) -> bool:
	var reader := get_tree().get_first_node_in_group("staff_reader")
	if reader == null:
		return false
	refresh_clock()
	reader.open_calendar(self)
	return true
