extends RefCounted
## Generates the editable gameplay overlay, leaving the baked environment untouched.
const BASE := "res://maps/intelligence/"
const L := preload("res://maps/intelligence/resources/layout/k17_layout.gd")
var scene: Node3D

func build() -> Node3D:
	scene = Node3D.new()
	scene.name = "Security"
	scene.set_script(load(BASE+"scripts/security_presentation.gd"))
	var alarm := preload("res://maps/intelligence/scripts/security_alarm.gd").new()
	alarm.name = "Alarm"
	_add(scene,alarm)
	var cover := (load(BASE+"assets/models/archive_rack.glb") as PackedScene).instantiate() as Node3D
	cover.name = "CheckpointSideCover"
	cover.position = Vector3(6.4,1.2,-5.5)
	cover.rotation.y = PI/2
	cover.scale = Vector3(4.0/5.5,1,.5)
	_add(scene,cover)
	for mesh in cover.find_children("*","GeometryInstance3D",true,false): mesh.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	for i in 2: _sensor(i,L.SENSORS[i])
	_gate("CourtyardGate",L.GATES[0],0)
	_gate("MaintenanceGate",L.GATES[1],1)
	var radio := _script("Radio",Area3D.new(),"radio_distraction.gd") as Interactable
	radio.position = Vector3(3.6,1.15,11.5)
	_shape(radio,Vector3(.6,.8,1.0))
	_box(radio,"Timer",Vector3.ZERO,Vector3(.16,.25,.45),Color("26382f"))
	_label(radio,"Plate","RADIO / HẸN 4 GIÂY\n[E] GÂY NHIỄU QUA LOA",Vector3(-.09,.28,0),Vector3(0,-90,0),.003)
	_audio(radio,"Static","radio",36)
	# The console drives a visible PA speaker on the yard facade.
	radio.get_node("Static").position = Vector3(18.4,2.05,4.5)
	_box(radio,"YardSpeaker",Vector3(18.4,2.05,4.5),Vector3(.7,.35,.3),Color("222d28"))
	_audio(radio,"IndoorStatic","radio",24)
	# Radio positions are relative to the console: the indoor speaker draws
	# attention into the communications bay, away from the archive threshold.
	radio.get_node("IndoorStatic").position = Vector3(6.4,.45,1)
	_box(radio,"IndoorSpeaker",Vector3(6.4,.45,1),Vector3(.7,.35,.3),Color("222d28"))
	_box(radio,"SpeakerBracket",Vector3(6.4,.71,1),Vector3(.08,.3,.08),Color("222d28"))
	var latch := _script("PreparedLatch",Area3D.new(),"prepared_latch.gd") as Interactable
	latch.position = L.LATCH
	_shape(latch,Vector3(.5,1,1.1))
	_box(latch,"Housing",Vector3.ZERO,Vector3(.35,.8,1),Color("414c36"))
	_box(latch,"Switch",Vector3(-.22,0,0),Vector3(.15,.3,.16),Color("c5a651"))
	_label(latch,"Plate","CHỐT CỬA HẬU\nCHUẨN BỊ TRƯỚC BÁO ĐỘNG",Vector3(-.2,.65,0),Vector3(0,-90,0),.003)
	_audio(latch,"Latch","relay",10)
	return scene

func _sensor(index: int, position: Vector3) -> void:
	var sensor := _script("Sensor%d"%index,Node3D.new(),"sensor_lane.gd") as Node3D
	sensor.position = position
	sensor.set("phase_offset",index*4.0)
	var area := Area3D.new()
	area.name = "Detection"
	area.collision_layer = 0
	area.collision_mask = 0
	area.monitoring = false
	_add(sensor,area)
	_shape(area,Vector3(3.6,2.4,.4))
	var beams := Node3D.new()
	beams.name = "Beams"
	_add(sensor,beams)
	for y in [-.92,-.3,.4,1.0]:
		_box(beams,"Beam",Vector3(0,y,0),Vector3(3.35,.018,.025),Color("ec5746"),true)
	for x in [-1.65,1.65]:
		_box(sensor,"EmitterPost",Vector3(x,0,0),Vector3(.12,2.4,.12),Color("303c35"))
	_box(sensor,"Indicator",Vector3(1.62,1.0,.12),Vector3(.16,.18,.16),Color("55d497"),true)
	_box(sensor,"Header",Vector3(0,1.25,0),Vector3(3.5,.32,.12),Color("27352c"))
	_label(sensor,"Status","CẢM BIẾN",Vector3(0,1.25,.12),Vector3.ZERO,.004)
	_label(sensor,"StatusBack","CẢM BIẾN",Vector3(0,1.25,-.12),Vector3(0,180,0),.004)
	_audio(sensor,"Relay","relay",8)

func _gate(title: String,position: Vector3,route: int) -> void:
	var gate := _script(title,Area3D.new(),"lockdown_gate.gd") as Node3D
	gate.position = position
	gate.set("route",route)
	_shape(gate,Vector3(4.2,2.4,1.0))
	var panel := StaticBody3D.new()
	panel.name = "Panel"
	panel.collision_layer = 0
	panel.collision_mask = 0
	_add(gate,panel)
	_shape(panel,Vector3(4.1,2.2,.28))
	var safety := Area3D.new()
	safety.name = "Safety"
	safety.collision_layer = 0
	safety.collision_mask = 0
	safety.monitoring = false
	_add(gate,safety)
	_shape(safety,Vector3(4.3,2.8,1.3))
	var leaf := Node3D.new()
	leaf.name = "Leaf"
	leaf.set_script(load(BASE+"scripts/dynamic_geometry.gd"))
	_add(gate,leaf)
	var model := (load(BASE+"assets/models/blast_door.glb") as PackedScene).instantiate() as Node3D
	model.scale = Vector3(1.16,.91,1)
	_add(leaf,model)
	for mesh in model.find_children("*","GeometryInstance3D",true,false): mesh.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	_box(gate,"Indicator",Vector3(2.7,1.3,.35),Vector3(.22,.2,.16),Color("62b998"),true)
	var text := "CỔNG SÂN / PHONG TỎA" if route == 0 else "CỬA HẬU / KHÓA CƠ"
	_label(gate,"Plate",text,Vector3(0,1.27,.18),Vector3.ZERO,.0035)
	_label(gate,"PlateBack",text,Vector3(0,1.27,-.18),Vector3(0,180,0),.0035)
	var link := NavigationLink3D.new()
	link.name = "WalkingLink"
	link.start_position = Vector3(0,-1,-2)
	link.end_position = Vector3(0,-1,2)
	link.bidirectional = true
	_add(gate,link)
	_audio(gate,"Motor","gate_motor",18)

func _script(title: String,node: Node,script: String) -> Node:
	node.name = title
	node.set_script(load(BASE+"scripts/"+script))
	_add(scene,node)
	return node

func _add(parent: Node,node: Node) -> void:
	parent.add_child(node,true)
	node.owner = scene

func _shape(parent: Node,size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.name = "Shape"
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	_add(parent,collision)

func _box(parent: Node,title: String,position: Vector3,size: Vector3,colour: Color,lit := false) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	mesh.position = position
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = .65
	material.resource_local_to_scene = true
	material.emission_enabled = lit
	material.emission = colour
	material.emission_energy_multiplier = 1.6 if lit else 0.0
	mesh.material_override = material
	mesh.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	_add(parent,mesh)

func _label(parent: Node,title: String,text: String,position: Vector3,rotation: Vector3,pixel: float) -> void:
	var label := Label3D.new()
	label.name = title
	label.text = text
	label.position = position
	label.rotation_degrees = rotation
	label.pixel_size = pixel
	label.font_size = 28
	label.outline_size = 2
	label.double_sided = false
	label.modulate = Color("dfdfbb")
	_add(parent,label)

func _audio(parent: Node,title: String,cue: String,distance: float) -> void:
	var player := AudioStreamPlayer3D.new()
	player.name = title
	player.stream = load(BASE+"assets/audio/"+cue+".wav")
	player.bus = "SFX"
	player.volume_db = -12
	player.max_distance = distance
	_add(parent,player)
