extends Node3D
## Map-local equipment dressing reads the same state as gameplay.
var _power_label: Label3D
var _power_lamp: StandardMaterial3D
var _last_state := ""

func _ready() -> void:
	_box(Vector3(42.94,2.25,3.2),Vector3(.18,.45,1.25),Color("23332e"))
	_box(Vector3(43,2.44,7.1),Vector3(.05,.05,7.8),Color("151e20"))
	_box(Vector3(43,2.02,11),Vector3(.05,.89,.05),Color("151e20"))
	_power_label=_label("",Vector3(42.83,2.25,3.2),-PI/2)
	var lamp:=_box(Vector3(42.83,1.85,3.2),Vector3(.04,.11,.11),Color("65b889"))
	_power_lamp=lamp.material_override
	_power_lamp.emission_enabled=true
	_box(Vector3(5.35,1.53,-23.52),Vector3(1.05,1.1,.05),Color("172027"))
	_box(Vector3(5.35,.49,-23.55),Vector3(.14,.98,.14),Color("172027"))
	_box(Vector3(5.35,.025,-23.55),Vector3(.5,.05,.34),Color("172027"))
	_label("KIỂM SOÁT KHO / B1",Vector3(5.35,2.04,-23.46),0)
	_box(Vector3(19.80,1.55,3),Vector3(.05,1.1,1.7),Color("293c32"))
	_label("K17 / PHÂN KHU\nCHỈ HUY · HỒ SƠ · KHO B1",Vector3(19.76,1.6,3),-PI/2)

func _process(_delta: float) -> void:
	var power:=PowerNetwork.find(self)
	if power==null: return
	var state: String=("DỰ PHÒNG" if power.get("backup_active") else "NGUỒN CHÍNH")+" / "+("ON" if power.is_powered(&"surveillance") else "OFF")
	if state==_last_state: return
	_last_state=state
	_power_label.text="CAMERA\n"+state
	_power_lamp.albedo_color=Color("e6a551") if power.get("backup_active") else Color("65b889") if power.is_powered(&"surveillance") else Color("343e3a")
	_power_lamp.emission=_power_lamp.albedo_color

func _box(position_: Vector3,size: Vector3,colour: Color) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	node.position=position_
	var box:=BoxMesh.new()
	box.size=size
	node.mesh=box
	var material:=StandardMaterial3D.new()
	material.albedo_color=colour
	material.roughness=.85
	node.material_override=material
	node.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
	add_child(node)
	return node

func _label(text: String,position_: Vector3,angle: float,pixel_size:=.0025) -> Label3D:
	var label:=Label3D.new()
	label.text=text
	label.position=position_
	label.rotation.y=angle
	label.font_size=28
	label.pixel_size=pixel_size
	label.modulate=Color("bacbc0")
	label.outline_size=2
	add_child(label)
	return label
