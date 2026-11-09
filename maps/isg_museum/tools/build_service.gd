extends SceneTree

const OUTPUT := "res://maps/isg_museum/scenes/service_expansion.tscn"
const Palette := preload("res://maps/isg_museum/tools/material_palette.gd")
var scene := Node3D.new()
var metal := material(Color(0.24,0.31,0.29))
var wood := material(Color(0.34,0.21,0.12))
var paper := material(Color(0.9,0.84,0.66))
var blue := material(Color(0.2,0.42,0.58))


func _initialize() -> void:
	_build.call_deferred()


func material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = .8
	return mat


func attach(parent: Node,node: Node,node_name: String) -> void:
	node.name = node_name
	parent.add_child(node)
	node.owner = scene


func visual(parent: Node,node_name: String,size: Vector3,at: Vector3,mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	cube.material = mat
	mesh.mesh = cube
	mesh.position = at
	attach(parent,mesh,node_name)


func solid(parent: Node,node_name: String,size: Vector3,at: Vector3,mat: Material) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	attach(parent,body,node_name)
	visual(body,"Visual",size,Vector3.ZERO,mat)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	attach(body,collision,"CollisionShape3D")


func sign_label(parent: Node,node_name: String,text: String,at: Vector3,yaw := 0.0,pixel := .0022) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.rotation.y = yaw
	label.pixel_size = pixel
	label.font_size = 44
	label.outline_size = 3
	attach(parent,label,node_name)


func interactive(parent: Node,node_name: String,at: Vector3,size: Vector3,script_path: String) -> Area3D:
	var area := Area3D.new()
	area.set_script(load(script_path))
	area.position = at
	attach(parent,area,node_name)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	attach(area,collision,"CollisionShape3D")
	return area


func document(node_name: String,at: Vector3,yaw: float,title: String,text: String,caption: String) -> void:
	var board := interactive(scene,node_name,at,Vector3(1.8,1.2,.18),"res://maps/isg_museum/scripts/service_document.gd")
	board.rotation.y = yaw
	board.set("title",title)
	board.set("content",text)
	board.set("prompt","Đọc "+title.to_lower())
	visual(board,"Paper",Vector3(1.7,1.1,.04),Vector3.ZERO,paper)
	sign_label(board,"Caption",caption,Vector3(0,0,.035),0,.0018)


func ticket_door(node_name: String,at: Vector3,width: float) -> void:
	var door := interactive(scene,node_name,at,Vector3(width,2.8,.5),"res://maps/isg_museum/scripts/service_ticket_door.gd")
	door.rotation.y = PI/2
	door.set("door_name","Cửa vé tầng 2 · "+node_name)
	door.get_node("CollisionShape3D").position.y = 1.4
	var panel := StaticBody3D.new()
	panel.position.y = 1.4
	panel.collision_layer = 1
	panel.collision_mask = 0
	attach(door,panel,"Panel")
	visual(panel,"MeshInstance3D",Vector3(width,2.8,.26),Vector3.ZERO,metal)
	var collision := CollisionShape3D.new()
	var form := BoxShape3D.new()
	form.size = Vector3(width,2.8,.26)
	collision.shape = form
	attach(panel,collision,"CollisionShape3D")
	var passage := NavigationLink3D.new()
	passage.start_position = Vector3(0,.45,-1.1)
	passage.end_position = Vector3(0,.45,1.1)
	passage.enabled = false
	attach(door,passage,"Passage")
	sign_label(door,"Label","V · CẦN VÉ TẦNG 2",Vector3(0,3.05,0),-PI/2,.0021)
	visual(door,"Reader",Vector3(.25,.45,.12),Vector3(width/2-.18,1.4,-.24),blue)


func _build() -> void:
	scene.name = "ServiceExpansion"
	scene.set_script(load("res://maps/isg_museum/scripts/service_expansion.gd"))
	solid(scene,"ReceptionCounter",Vector3(.8,1.0,2.6),Vector3(31.8,.5,27),wood)
	visual(scene,"CounterTop",Vector3(.95,.1,2.7),Vector3(31.8,1.04,27),paper)
	solid(scene,"ReceptionChair",Vector3(.6,.5,.6),Vector3(33.05,.25,27),metal)
	visual(scene,"ChairBack",Vector3(.12,.85,.65),Vector3(33.35,.7,27),wood)
	var npc := interactive(scene,"Receptionist",Vector3(32.7,1.15,27),Vector3(.9,1.5,.9),"res://maps/isg_museum/scripts/service_npc.gd")
	npc.set("prompt","Nói chuyện với nhân viên tiếp đón")
	visual(npc,"Torso",Vector3(.42,.55,.5),Vector3(0,-.2,0),blue)
	visual(npc,"Head",Vector3(.3,.33,.3),Vector3(0,.24,0),material(Color(.7,.5,.34)))
	for z in [-.08,.08]:
		visual(npc.get_node("Head"),"Eye%d"%npc.get_node("Head").get_child_count(),Vector3(.02,.035,.035),Vector3(-.155,.025,z),metal)
	sign_label(npc,"WatchNotice","Đang kiểm tra giấy hẹn...",Vector3(0,.85,0),-PI/2,.0015)
	npc.get_node("WatchNotice").visible = false
	for z in [-.18,.18]:
		visual(npc,"Thigh%d"%npc.get_child_count(),Vector3(.4,.18,.17),Vector3(-.14,-.57,z),metal)
		visual(npc,"Shin%d"%npc.get_child_count(),Vector3(.15,.43,.17),Vector3(-.3,-.8,z),metal)
	sign_label(npc,"Name","N1 · TIẾP ĐÓN",Vector3(0,.65,0),-PI/2,.0018)
	document("EventPoster",Vector3(22,1.7,29.72),PI,"Áp phích sự kiện",
		"BẢO TÀNG · ĐÊM DI SẢN\n\nKhách có giấy hẹn vui lòng tới phòng dịch vụ để nhận vé tham quan tầng 2.\n\nMang theo thông tin người phụ trách và giờ hẹn.","ĐÊM DI SẢN\nNhận vé tại phòng dịch vụ")
	var plate := interactive(scene,"ReceptionNotice",Vector3(31.48,1.23,26.35),Vector3(.65,.3,.2),"res://maps/isg_museum/scripts/service_document.gd")
	plate.rotation.y = -PI/2
	plate.set("document_kind","host")
	visual(plate,"Base",Vector3(.6,.04,.18),Vector3(0,-.12,0),wood)
	visual(plate,"Plate",Vector3(.58,.2,.04),Vector3.ZERO,paper)
	sign_label(plate,"Caption","NHÂN VIÊN\nTiếp đón",Vector3(0,0,.03),0,.0011)
	var map := interactive(scene,"WallMap",Vector3(32,1.65,24.3),Vector3(2.2,1.4,.22),"res://maps/isg_museum/scripts/service_map.gd")
	map.set("prompt","Xem bản đồ hai tầng")
	visual(map,"Frame",Vector3(2.3,1.5,.12),Vector3.ZERO,wood)
	visual(map,"Paper",Vector3(2.15,1.35,.04),Vector3(0,0,.09),paper)
	for x in [-.52,.52]:
		visual(map,"Floor%d"%map.get_child_count(),Vector3(.8,.85,.02),Vector3(x,0,.12),metal)
		visual(map,"Courtyard%d"%map.get_child_count(),Vector3(.3,.35,.02),Vector3(x,0,.14),blue)
	sign_label(map,"Caption","M · BẢN ĐỒ HAI TẦNG\nE: XEM / LƯU",Vector3(0,.5,.16),0,.0016)
	ticket_door("TicketGate_A",Vector3(9,4.5,27),1.6)
	ticket_door("TicketGate_B",Vector3(27,4.5,3),2.0)
	Palette.apply_service(scene)
	var packed := PackedScene.new()
	var error := packed.pack(scene)
	if error == OK:
		error = ResourceSaver.save(packed,OUTPUT)
	scene.free()
	if error != OK:
		push_error("Could not save service scene: %d"%error)
	quit(0 if error == OK else 1)
