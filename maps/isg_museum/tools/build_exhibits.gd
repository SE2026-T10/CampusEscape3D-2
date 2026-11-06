extends SceneTree

## Offline authoring: preserves the existing museum geometry and guard routes.
const OUTPUT := "res://maps/isg_museum/scenes/exhibits_expansion.tscn"
var expansion := Node3D.new()
var bronze := material(Color(0.59,0.38,0.14),0.55)
var silver := material(Color(0.67,0.73,0.78),0.8)
var marble := material(Color(0.86,0.83,0.73))
var wood := material(Color(0.28,0.15,0.075))
var gold := material(Color(0.7,0.5,0.19),0.55)


func _initialize() -> void:
	build.call_deferred()


func material(colour: Color, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.72 if metallic == 0 else 0.35
	mat.metallic = metallic
	return mat


func attach(parent: Node, node: Node, node_name: String) -> void:
	node.name = node_name
	parent.add_child(node)
	node.owner = expansion


func mesh(parent: Node,node_name: String,resource: Mesh,at: Vector3,mat: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = resource
	item.material_override = mat
	attach(parent,item,node_name)
	item.position = at
	return item


func cube(parent: Node,node_name: String,size: Vector3,at: Vector3,mat: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent,node_name,shape,at,mat)


func sphere(parent: Node,node_name: String,radius: float,height: float,at: Vector3,mat: Material) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = height
	return mesh(parent,node_name,shape,at,mat)


func cylinder(parent: Node,node_name: String,radius: float,height: float,at: Vector3,mat: Material) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	return mesh(parent,node_name,shape,at,mat)


func trigger(parent: Area3D,size: Vector3) -> void:
	var form := BoxShape3D.new()
	form.size = size
	var shape := CollisionShape3D.new()
	shape.shape = form
	attach(parent,shape,"CollisionShape3D")


func label(parent: Node,caption: String,at: Vector3,billboard := true) -> void:
	var sign := Label3D.new()
	sign.text = caption
	sign.position = at
	sign.font_size = 36
	sign.pixel_size = 0.0018
	sign.outline_size = 5
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	attach(parent,sign,"Label3D")


func item(parent: Node,node_name: String,script_path: String,objective: StringName,title: String,at: Vector3) -> Area3D:
	var root := Area3D.new()
	attach(parent,root,node_name)
	root.position = at
	root.set_script(load(script_path))
	root.set("objective_id",objective)
	root.set("exhibit_name",title)
	return root


func sculpture(node_name: String,objective: StringName,title: String,at: Vector3,bird: bool) -> void:
	var root := item(expansion,node_name,"res://maps/isg_museum/scripts/exhibit_glass_case.gd",objective,title,at)
	trigger(root,Vector3(1.9,1.2,2.7))
	cube(root,"BasePlate",Vector3(1.85,0.07,2.6),Vector3(0,-0.45,0),wood)
	var glass := Node3D.new()
	attach(root,glass,"Glass")
	var translucent := material(Color(0.65,0.88,0.9,0.2))
	translucent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	translucent.cull_mode = BaseMaterial3D.CULL_DISABLED
	translucent.roughness = 0.12
	for x in [-0.88,0.88]:
		cube(glass,"Side%d"%glass.get_child_count(),Vector3(0.025,1,2.5),Vector3(x,0.08,0),translucent)
	for z in [-1.25,1.25]:
		cube(glass,"Front%d"%glass.get_child_count(),Vector3(1.8,1,0.025),Vector3(0,0.08,z),translucent)
	cube(glass,"Top",Vector3(1.8,0.025,2.5),Vector3(0,0.58,0),translucent)
	var shards := Node3D.new()
	attach(root,shards,"Shards")
	shards.visible = false
	for i in 9:
		var bit := cube(shards,"Shard%d"%i,Vector3(0.12+i%3*0.035,0.018,0.09),Vector3(-0.74+(i%4)*0.46,-0.39,-0.85+(i/4)*0.7),translucent)
		bit.rotation.y = i*0.73
	var artifact := Node3D.new()
	attach(root,artifact,"Artifact")
	cylinder(artifact,"Stand",0.3,0.08,Vector3(0,-0.36,0),wood)
	if bird:
		sphere(artifact,"Body",0.22,0.34,Vector3(0,-0.04,0),bronze)
		for x in [-0.24,0.24]:
			var wing := cube(artifact,"Wing%d"%artifact.get_child_count(),Vector3(0.32,0.05,0.3),Vector3(x,0.03,0.04),bronze)
			wing.rotation.z = signf(x)*0.2
		sphere(artifact,"Head",0.13,0.24,Vector3(0,0.19,-0.15),bronze)
		var beak := CylinderMesh.new()
		beak.top_radius = 0
		beak.bottom_radius = 0.07
		beak.height = 0.2
		var nose := mesh(artifact,"Beak",beak,Vector3(0,0.18,-0.34),gold)
		nose.rotation.x = -PI/2
		for x in [-0.12,0.12]:
			cylinder(artifact,"Leg%d"%artifact.get_child_count(),0.025,0.21,Vector3(x,-0.24,0),bronze)
	else:
		cube(artifact,"BustBase",Vector3(0.5,0.12,0.35),Vector3(0,-0.27,0),marble)
		sphere(artifact,"Shoulders",0.29,0.25,Vector3(0,-0.12,0),marble)
		cylinder(artifact,"Neck",0.09,0.18,Vector3(0,0.05,0),marble)
		sphere(artifact,"Head",0.16,0.4,Vector3(0,0.27,0),marble)
	label(root,title+"\nE: đập kính → lấy",Vector3(0,0.83,0))


func drawer(node_name: String,objective: StringName,title: String,at: Vector3,medal: bool) -> void:
	var root := item(expansion,node_name,"res://maps/isg_museum/scripts/exhibit_drawer.gd",objective,title,at)
	trigger(root,Vector3(1.5,0.55,0.95))
	cube(root,"Tray",Vector3(1.4,0.12,0.88),Vector3(0,-0.1,0),wood)
	cube(root,"Lid",Vector3(1.45,0.1,0.92),Vector3(0,0.12,0),wood)
	cube(root,"Latch",Vector3(0.13,0.13,0.08),Vector3(0,0.08,0.48),gold)
	var artifact := Node3D.new()
	attach(root,artifact,"Artifact")
	artifact.visible = false
	if medal:
		cylinder(artifact,"Medal",0.19,0.055,Vector3(0,0.015,0),silver)
		cube(artifact,"Ribbon",Vector3(0.23,0.025,0.22),Vector3(0,0.02,-0.21),material(Color(0.12,0.3,0.6)))
		cylinder(artifact,"Mark",0.06,0.065,Vector3(0,0.015,0),gold)
	else:
		cylinder(artifact,"Watch",0.18,0.08,Vector3(0,0.025,0),gold)
		cylinder(artifact,"Face",0.15,0.085,Vector3(0,0.025,0),marble)
		cube(artifact,"HourHand",Vector3(0.018,0.01,0.1),Vector3(0,0.075,-0.04),wood)
		cube(artifact,"MinuteHand",Vector3(0.11,0.01,0.018),Vector3(0.05,0.075,0),wood)
	label(root,title+"\nGiữ E mở ngăn",Vector3(0,0.54,0))


func painting(node_name: String,objective: StringName,title: String,at: Vector3,yaw: float,colour: Color) -> void:
	var root := item(expansion,node_name,"res://maps/isg_museum/scripts/exhibit_painting.gd",objective,title,at)
	root.rotation.y = yaw
	root.set("prompt","Lấy " + title)
	trigger(root,Vector3(1.15,0.95,0.25))
	var canvas := Node3D.new()
	attach(root,canvas,"Canvas")
	cube(canvas,"Painting",Vector3(0.98,0.76,0.045),Vector3(0,0,0.035),material(colour))
	cube(canvas,"Landscape",Vector3(0.7,0.2,0.02),Vector3(0,-0.16,0.07),material(colour.lightened(0.25)))
	sphere(canvas,"Sun",0.1,0.2,Vector3(0.25,0.15,0.08),gold).scale.z = 0.15
	var frame := Node3D.new()
	attach(root,frame,"Frame")
	for x in [-0.55,0.55]:
		cube(frame,"Side%d"%frame.get_child_count(),Vector3(0.08,0.92,0.1),Vector3(x,0,0.02),gold)
	for y in [-0.44,0.44]:
		cube(frame,"Edge%d"%frame.get_child_count(),Vector3(1.18,0.08,0.1),Vector3(0,y,0.02),gold)
	label(root,title,Vector3(0,0.7,0.09),false)


func scroll() -> void:
	var root := item(expansion,"B2","res://maps/isg_museum/scripts/exhibit_scroll.gd",&"take_b2","B2 · Tranh cuộn phác thảo",Vector3(35.7,6,15))
	root.rotation.y = -PI/2
	root.set("prompt","Lấy B2 · Tranh cuộn phác thảo")
	trigger(root,Vector3(1.15,0.8,0.3))
	var paper := material(Color(0.83,0.76,0.58))
	cube(root,"Sheet",Vector3(0.85,0.5,0.04),Vector3(0,0,0.045),paper)
	cube(root,"Sketch",Vector3(0.42,0.025,0.012),Vector3(0,-0.08,0.075),wood)
	for y in [-0.27,0.27]:
		var roll := cylinder(root,"Roll%d"%root.get_child_count(),0.08,1.0,Vector3(0,y,0.1),paper)
		roll.rotation.z = PI/2
	label(root,"B2 · TRANH CUỘN",Vector3(0,0.6,0.09),false)


func gallery_alarm() -> void:
	var root := Area3D.new()
	attach(expansion,root,"GalleryAlarmSwitch")
	root.position = Vector3(25.7,5.95,5.7)
	root.rotation.y = PI
	root.set_script(load("res://maps/isg_museum/scripts/exhibit_gallery_alarm.gd"))
	trigger(root,Vector3(0.7,0.65,0.28))
	cube(root,"Panel",Vector3(0.6,0.55,0.12),Vector3.ZERO,material(Color(0.2,0.24,0.23)))
	cube(root,"Indicator",Vector3(0.17,0.1,0.05),Vector3(0,0.14,0.09),gold)
	cube(root,"Switch",Vector3(0.09,0.22,0.09),Vector3(0,-0.08,0.1),marble)
	label(root,"PHÒNG C\nTắt báo động trước khi lấy tranh",Vector3(0,0.56,0.08),false)


func build() -> void:
	expansion.name = "ExhibitsExpansion"
	sculpture("S1",&"take_s1","S1 · Tượng chim đồng",Vector3(4.3,1.7,11.5),true)
	sculpture("S2",&"take_s2","S2 · Tượng bán thân đá",Vector3(4.3,1.7,18),false)
	drawer("H1",&"take_h1","H1 · Huy chương bạc",Vector3(10.5,1.35,2.8),true)
	drawer("H2",&"take_h2","H2 · Đồng hồ bỏ túi",Vector3(22,1.35,2.8),false)
	painting("A2",&"take_a2","A2 · Phong cảnh nhỏ",Vector3(0.24,6,18),PI/2,Color(0.16,0.35,0.25))
	scroll()
	painting("C2",&"take_c2","C2 · Tĩnh vật hoa",Vector3(10,6,0.24),0,Color(0.43,0.2,0.3))
	gallery_alarm()
	var packed := PackedScene.new()
	var result := packed.pack(expansion)
	if result == OK:
		result = ResourceSaver.save(packed,OUTPUT)
	expansion.free()
	print("Exhibit expansion saved: ",OUTPUT," result=",result)
	quit(0 if result == OK else 1)
