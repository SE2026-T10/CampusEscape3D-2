extends Node3D

## Stage A controls live only on this preview wrapper, never museum.tscn.
const Palette := preload("res://maps/isg_museum/tools/courtyard_palette.gd")
var palette: RefCounted
var map: Node3D
var hint: Label
var anchor_index := 0

func _ready() -> void:
	map = $Map
	var world := map.get_node("WorldEnvironment") as WorldEnvironment
	world.environment = world.environment.duplicate(true)
	palette = Palette.new()
	palette.prepare(map)
	palette.set_proposed(true)
	for child in map.get_children():
		if child is CanvasLayer: child.hide()
	for node in get_tree().get_nodes_in_group("debug_visuals"):
		if node is Node3D: node.hide()
	var canvas := CanvasLayer.new()
	canvas.layer = 60
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(16,12)
	hint.add_theme_font_size_override("font_size",17)
	hint.add_theme_color_override("font_shadow_color",Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x",1)
	hint.add_theme_constant_override("shadow_offset_y",1)
	canvas.add_child(hint)
	go_to_anchor(0)
	update_hint()

func set_proposed(enabled: bool) -> void:
	palette.set_proposed(enabled)
	update_hint()

func update_hint() -> void:
	if palette.config.stage=="B_production":
		hint.text = "GARDNER B — VẬT LIỆU ĐÃ LƯU TRONG MAP\nF8: đổi tầng/điểm đứng · WASD, chuột: đi/xem · F7: không dùng (baseline hiện tại là B)"
		return
	if hint:
		hint.text = "THỬ VẬT LIỆU — %s\nF7: trước/sau · F8: đổi tầng/điểm đứng · WASD, chuột: đi/xem · Esc: pause"%["VENICE ẤM" if palette.proposed else "BẢN HIỆN TẠI"]

func go_to_anchor(index: int) -> void:
	anchor_index = index%palette.config.preview.anchors.size()
	var a: Array = palette.config.preview.anchors[anchor_index]
	var player := map.get_node("Player") as FirstPersonPlayer
	player.position = Vector3(a[0],a[1],a[2])
	player.velocity = Vector3.ZERO
	var target := Vector3(18,2 if anchor_index<2 else 4.8,13)
	var offset := target-player.global_position
	player.rotation.y = atan2(-offset.x,-offset.z)
	player.head.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.camera.look_at(target)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode==KEY_F7:
		if palette.config.stage!="B_production": set_proposed(not palette.proposed)
		get_viewport().set_input_as_handled()
	elif event.keycode==KEY_F8:
		go_to_anchor(anchor_index+1)
		get_viewport().set_input_as_handled()
