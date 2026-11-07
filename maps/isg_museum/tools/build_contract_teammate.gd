extends SceneTree
var scene := Area3D.new()
func add(parent: Node,node: Node,node_name: String) -> void:
	node.name = node_name
	parent.add_child(node)
	node.owner = scene
func cube(node_name: String,at: Vector3,size: Vector3,colour: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mesh.material = mat
	node.mesh = mesh
	add(scene,node,node_name)
	node.position = at
func _initialize() -> void:
	scene.name = "Teammate"
	scene.position = Vector3(20.5,1,31.5)
	scene.rotation.y = -0.45
	scene.set_script(load("res://maps/isg_museum/scripts/contract_teammate.gd"))
	scene.set("prompt","Nói chuyện với N0 · nhận hợp đồng")
	var shape := CollisionShape3D.new()
	var form := BoxShape3D.new()
	form.size = Vector3(0.8,1.9,0.8)
	shape.shape = form
	add(scene,shape,"Interaction")
	cube("Body",Vector3(0,.08,0),Vector3(.55,.65,.35),Color(.14,.42,.47))
	cube("Head",Vector3(0,.68,0),Vector3(.32,.36,.3),Color(.73,.55,.37))
	for x in [-.065,.065]:
		cube("Eye%d"%scene.get_child_count(),Vector3(x,.71,.16),Vector3(.035,.04,.02),Color(.07,.1,.12))
	for x in [-.17,.17]:
		cube("Leg%d"%scene.get_child_count(),Vector3(x,-.58,0),Vector3(.22,.7,.26),Color(.12,.17,.22))
	for x in [-.38,.38]:
		cube("Arm%d"%scene.get_child_count(),Vector3(x,-.03,0),Vector3(.18,.62,.24),Color(.14,.42,.47))
	var label := Label3D.new()
	label.text = "N0 · ĐỒNG ĐỘI\nE: NHẬN HỢP ĐỒNG"
	label.pixel_size = .002
	label.font_size = 44
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add(scene,label,"Label")
	label.position.y = 1.12
	var packed := PackedScene.new()
	packed.pack(scene)
	var error := ResourceSaver.save(packed,"res://maps/isg_museum/scenes/contract_teammate.tscn")
	scene.free()
	quit(0 if error == OK else 1)
