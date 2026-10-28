extends Control
## North-up map-local X/Z projection, always sampling the live actor transform.
const Data := preload("res://maps/intelligence/resources/layout/minimap_layout.gd")
const DEFAULT_LAYOUT := preload("res://maps/intelligence/resources/k17_minimap_layout.tres")
const Marker := preload("res://maps/intelligence/scripts/minimap_marker.gd")
const ACTION := &"k17_minimap"
var layout: Data = DEFAULT_LAYOUT
var floor_id := 0
var enabled := true
var player: FirstPersonPlayer
var map_root: Node3D
var marker: Control
var marker_local := Vector3.ZERO
var marker_heading := 0.0
var _header: Label
var _footer: Label
var _flow: GameFlow
var _hud: ObjectiveHud
var _stair := false

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	clip_contents=true
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
		var key := InputEventKey.new()
		key.physical_keycode=KEY_M
		InputMap.action_add_event(ACTION,key)
	_header=_label(Vector2(12,7),15,Color("d3e6d9"))
	_footer=_label(Vector2(12,0),12,Color("9bb3a9"))
	marker=Marker.new()
	marker.name="PlayerMarker"
	add_child(marker)
	_hud=get_parent() as ObjectiveHud
	map_root=_hud.get_parent() as Node3D
	player=map_root.get_node_or_null("Player") as FirstPersonPlayer
	_flow=GameFlow.find(self)
	resized.connect(_resize)
	_resize()
	update_marker()

func _process(_delta: float) -> void:
	update_marker()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION) and not event.is_echo() and _can_show():
		enabled=not enabled
		update_marker()
		get_viewport().set_input_as_handled()

func _can_show() -> bool:
	if not is_instance_valid(_flow): _flow=GameFlow.find(self)
	return is_instance_valid(_hud) and _hud.visible and not _hud.is_journal_open() and is_instance_valid(_flow) and _flow.state==GameStateMachine.State.PLAYING and not _flow.is_leaving()

func update_marker() -> void:
	visible=enabled and _can_show()
	if not is_instance_valid(player) and is_instance_valid(map_root):
		player=map_root.get_node_or_null("Player") as FirstPersonPlayer
	if not is_instance_valid(player):
		if marker: marker.hide()
		return
	marker_local=map_root.to_local(player.global_position)
	var next_floor := floor_id
	if marker_local.y< -2.4: next_floor=1
	elif marker_local.y> -1.6: next_floor=0
	if next_floor!=floor_id:
		floor_id=next_floor
		queue_redraw()
	var forward := map_root.global_basis.inverse()*(-player.global_basis.z)
	marker_heading=atan2(forward.x,-forward.z)
	var point := project_local(marker_local)
	var frame := map_rect()
	marker.position=point.clamp(frame.position,frame.end)
	marker.rotation=marker_heading
	marker.show()
	_stair=layout.stairs.any(func(area: Rect2): return area.has_point(Vector2(marker_local.x,marker_local.z)))
	_header.text="K17 / "+("B1" if floor_id==1 else "TRỆT")+"         BẮC ↑"
	_footer.text="Cầu thang TRỆT ↔ B1" if _stair else "▲ Bạn   ·   M: ẩn bản đồ"
	if not layout.bounds_for(floor_id).has_point(Vector2(marker_local.x,marker_local.z)):
		_footer.text="Bạn đang ngoài sơ đồ"

func map_rect() -> Rect2:
	return Rect2(Vector2(10,32),Vector2(maxf(1,size.x-20),maxf(1,size.y-58)))

func project_local(point: Vector3) -> Vector2:
	var bounds := layout.bounds_for(floor_id)
	var frame := map_rect()
	var factor := minf(frame.size.x/bounds.size.x,frame.size.y/bounds.size.y)
	var padding := (frame.size-bounds.size*factor)/2
	return frame.position+padding+(Vector2(point.x,point.z)-bounds.position)*factor

func _resize() -> void:
	if _footer: _footer.position=Vector2(12,size.y-22)
	queue_redraw()

func _draw() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color=Color(.025,.055,.06,.92)
	style.border_color=Color("466459")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	draw_style_box(style,Rect2(Vector2.ZERO,size))
	draw_rect(map_rect(),Color("0b151a"))
	for kind in ["floors","rooms","obstacles","walls"]:
		var colour: Color={"floors":Color("1e3033"),"rooms":Color("2b4240"),"obstacles":Color("4a5e58"),"walls":Color("a5b7a0")}[kind]
		for area: Rect2 in layout.shapes_for(floor_id,kind):
			var top_left := project_local(Vector3(area.position.x,0,area.position.y))
			var bottom_right := project_local(Vector3(area.end.x,0,area.end.y))
			draw_rect(Rect2(top_left,(bottom_right-top_left).max(Vector2.ONE)),colour)
	for area in layout.stairs:
		var top_left := project_local(Vector3(area.position.x,0,area.position.y))
		var bottom_right := project_local(Vector3(area.end.x,0,area.end.y))
		draw_rect(Rect2(top_left,bottom_right-top_left),Color("c4a75d"),false,1)
		for z in range(int(area.position.y)+1,int(area.end.y),2):
			draw_line(project_local(Vector3(area.position.x,0,z)),project_local(Vector3(area.end.x,0,z)),Color("a58d50"),1)

func _label(at: Vector2,font_size: int,colour: Color) -> Label:
	var label := Label.new()
	label.position=at
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",colour)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
