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
	var visual := preload("res://maps/isg_museum/scenes/npc/museum_npc_visual.tscn").instantiate()
	add(scene,visual,"Visual")
	visual.position.y = -1
	visual.rotation.y = PI
	var presentation := Node.new()
	presentation.set_script(load("res://maps/isg_museum/scripts/museum_npc_presentation.gd"))
	presentation.set("role","teammate")
	add(scene,presentation,"Presentation")
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
