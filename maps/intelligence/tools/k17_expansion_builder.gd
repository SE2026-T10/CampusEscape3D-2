extends RefCounted
const L := preload("res://maps/intelligence/resources/layout/k17_layout.gd")
const BASE := "res://maps/intelligence/"
var b
var sectors: Node3D
var sector: Node3D
var materials := {}

func build(builder: SceneTree, region: Node3D) -> void:
	b = builder
	for body in region.get_children():
		if str(body.name).begins_with("Boundary") or str(body.name).begins_with("Fence") or str(body.name).begins_with("NavigationGateCut") or str(body.name).begins_with("SensorPost") or body.name in ["Ground","LatchHousing"]:
			body.free()
	sectors = b._group(region,"Sectors")
	_select("perimeter")
	# Ground plane has actual holes over both descending staircases.
	_box("GroundSouth",Vector3(0,-.2,15.5),Vector3(96,.4,79),"asphalt")
	_box("GroundNorth",Vector3(0,-.2,-43.5),Vector3(96,.4,19),"asphalt")
	for span in [Vector2(-48,2),Vector2(6,28),Vector2(32,48)]:
		_box("GroundStairs",Vector3((span.x+span.y)/2,-.2,-29),Vector3(span.y-span.x,.4,10),"asphalt")
	for x in [-48.0,48.0]: _box("BoundarySide",Vector3(x,2,1),Vector3(.4,4,108),"wall")
	for z in [-53.0,55.0]: _box("BoundaryEnd",Vector3(0,2,z),Vector3(96,4,.4),"wall")
	# Fence openings align exactly with the two physical lockdown gates.
	for span in [Vector2(-48,-38.1),Vector2(-33.9,33.9),Vector2(38.1,48)]:
		var fence := _box("Fence",Vector3((span.x+span.y)/2,1.05,46),Vector3(span.y-span.x,2.1,.35),"steel")
		fence.collision_layer=16
		fence.get_node("Mesh").visible=false
		_fence(span.x,span.y,46)
	for x in [-36.0,36.0]:
		var cut := _box("NavigationGateCut",Vector3(x,1.5,46),Vector3(5,3,1.6),"steel")
		cut.get_node("Mesh").visible=false
		cut.set_meta("bake_cut",true)
		for side in [-2.7,2.7]: _box("GatePier",Vector3(x+side,1.5,46),Vector3(.6,3,.6),"wall")
		_sign("ĐIỂM TẬP KẾT\n"+("PHÍA TÂY" if x<0 else "PHÍA ĐÔNG"),Vector3(x,2.5,53.2),0)
		for side in [-1.7,1.7]:
			_box("Beacon",Vector3(x+side,1,51),Vector3(.15,2,.15),"beacon")
			_light(Vector3(x+side,2.5,51),9,1.8,true)
		_stripe(Vector3(x,.015,51),Vector3(3.8,.02,3.8))
	_box("SpawnCover",Vector3(-32,1.4,50),Vector3(2,2.8,3),"olive")
	_sign("VÀNH ĐAI K17\nSÂN ←   BẢO TRÌ →",Vector3(-30,2.4,48),0)
	for x in [-44.0,-20.0,20.0,44.0]:
		for z in [42.0,20.0,-20.0]:
			_box("FloodlightPole",Vector3(x,3,z),Vector3(.14,6,.14),"steel")
			_model("floodlight",Vector3(x,5.9,z))
			_light(Vector3(x,5.6,z),17,2.2)
	_select("motor_pool")
	_room(Vector3(-36,0,32),Vector2(16,16),[Vector2(-38,-34)],[Vector2(-38,-34)])
	_sign("02 / SÂN TIẾP VẬN\nNHÀ XE · KHO VẬN",Vector3(-36,2.5,40.25),0)
	for p in [Vector3(-41,0,29),Vector3(-30.5,0,35)]: _truck(p)
	for p in [Vector3(-20,.65,30),Vector3(-12,.65,38),Vector3(12,.65,34),Vector3(28,.65,40)]: _crate(p)
	_select("guard_post")
	_room(Vector3(-36,0,3),Vector2(16,22),[Vector2(-38,-34)],[],[Vector2(5,9)])
	_box("PassDesk",Vector3(-36,.4,4),Vector3(2.8,.8,1.2),"steel")
	_model("field_desk",Vector3(-36,.4,4),PI)
	for x in [-41.0,-30.0]:
		_box("Locker",Vector3(x,1.1,-6.5),Vector3(2,2.2,1),"olive")
		_model("locker",Vector3(x,1.1,-6.5),PI)
	_model("command_board",Vector3(-36,1.6,-7.7),PI)
	_sign("03 / PHÒNG TRỰC\nGIẤY THÔNG HÀNH",Vector3(-36,2.6,14.3),0)
	_select("command")
	_box("RadioCheckpointCover",Vector3(0,1.3,11.5),Vector3(3.5,2.6,.5),"olive")
	# Clear wall connection between the west annex and the original core.
	_sign("04 / CHỈ HUY – VÔ TUYẾN\nMÃ KHO Ở BÀN LIÊN LẠC",Vector3(-25,2.4,9),0)
	_room(Vector3(-18,0,39),Vector2(6,8),[],[Vector2(-19.8,-16.2)])
	_sign("ĐỘI PHẢN ỨNG\nCHỐT TIẾP VIỆN A",Vector3(-18,2.7,34.75),PI)
	_select("utilities")
	_room(Vector3(36,0,9),Vector2(16,18),[Vector2(34,38)],[Vector2(34,38)])
	_wall_h(6,28,44,[Vector2(39,43)])
	_wall_h(12,28,44,[Vector2(29,33)])
	for x in [30.0,42.0]:
		_box("Generator",Vector3(x,.8,11),Vector3(2.5,1.6,4),"olive")
		for z in [9.5,10.5,11.5,12.5]: _box("CoolingVent",Vector3(x,1.63,z),Vector3(2.1,.05,.07),"steel",false)
	_box("LatchHousing",L.LATCH,Vector3(.35,.8,1),"olive")
	_box("LatchCover",Vector3(40,1.2,5),Vector3(.4,2.4,3.2),"steel")
	_sign("05 / TRẠM ĐIỆN – XƯỞNG\nCHUẨN BỊ CỬA HẬU →",Vector3(36,2.5,18.3),0)
	_select("records")
	_box("CheckpointCover",Vector3(8,1.25,-18),Vector3(3.7,2.5,.7),"steel")
	_box("CheckpointSide",Vector3(6.1,1.25,-20),Vector3(.5,2.5,4.4),"steel")
	_sign("06 / PHÂN LOẠI HỒ SƠ\nCHECKPOINT TRƯỚC KHO MẬT",Vector3(8,2.25,-18.45),PI)
	_select("secure_vault")
	_wall_v(-4,-34,-24,[])
	_wall_v(12,-34,-24,[])
	_wall_h(-34,-4,12,[])
	_box("SecureBlockRoof",Vector3(4,3.4,-29),Vector3(16.4,.25,10.4),"wall")
	_light(Vector3(4,2.8,-28),14,2)
	_box("VaultFloor",Vector3(0,-4.2,-42),Vector3(20,.4,16),"floor")
	_wall_h(-34,-10,10,[Vector2(2,6)],-4,4)
	_wall_h(-50,-10,10,[],-4,4)
	_wall_v(-10,-50,-34,[],-4,4)
	_wall_v(10,-50,-34,[Vector2(-40,-36)],-4,4)
	# East return corridor and the second independent stairwell.
	_box("ReturnFloor",Vector3(22,-4.2,-38),Vector3(24,.4,8),"floor")
	_wall_h(-42,10,34,[],-4,4)
	_wall_h(-34,10,34,[Vector2(28,32)],-4,4)
	_wall_v(34,-42,-34,[],-4,4)
	_stair(4)
	_stair(30)
	_box("ServiceStairCanopy",Vector3(30,3,-29),Vector3(6,.2,12),"steel")
	for x in [-6.0,-2.0]:
		_box("ArchiveRack",Vector3(x,-2.8,-40),Vector3(1,2.4,7),"steel")
		for z in [-42.0,-39.0]: _model("archive_rack",Vector3(x,-2.8,z),PI/2,Vector3(.55,1,.7))
	_box("FileDesk",Vector3(0,-3.55,-47),Vector3(2.4,.9,1.2),"steel")
	_box("FileSideCover",Vector3(-2.5,-2.75,-46),Vector3(.5,2.5,4),"steel")
	_model("archive_table",Vector3(0,-3.55,-47))
	# A partial divider channels the two sensor strips without blocking retreat.
	_wall_v(1.8,-46,-34,[],-4,3.3)
	_wall_v(6.2,-46,-34,[],-4,3.3)
	for s in L.SENSORS:
		for x in [-1.65,1.65]: _box("SensorPost",s+Vector3(x,0,0),Vector3(.12,2.4,.12),"steel")
	_sign("07 / KHO MẬT B1\nMẬT LỆNH 04 – NIÊM PHONG",Vector3(0,-1.6,-49.7),0)
	for p in [Vector3(0,-1.2,-46),Vector3(4,-1.2,-36),Vector3(22,-1.2,-38)]: _light(p,12,2)
	_sign("B1 / KHO MẬT\nMÃ KHO BẮT BUỘC",Vector3(4,2.6,-23.6),0)
	_sign("LỐI RÚT BẢO TRÌ →",Vector3(8,-1.7,-41),0)
	_select("service_route")
	_wall_v(24,-24,46,[Vector2(18,22)])
	_wall_h(-12,24,48,[Vector2(40,44)])
	_wall_h(24,24,48,[Vector2(24.5,28.5)])
	for z in [-18.0,-2.0,25.0,37.0]:
		_box("ServiceCover",Vector3(24,1.2,z),Vector3(2,2.4,4),"olive")
		_model("supply_crate",Vector3(24,.65,z))
	_sign("08 / HÀNH LANG DỊCH VỤ\nCỬA HẬU ↓",Vector3(30,2.3,-22),0)
	_box("ResponsePost",Vector3(44,1.4,-20),Vector3(3,2.8,3),"wall")
	_sign("CẢNH VỆ HẬU CẦN",Vector3(44,2,-18.4),0)
	# The actor does not need jumps; short markings lead to the east stairs.
	for z in range(-20,44,4): _stripe(Vector3(30,.016,z),Vector3(.15,.02,1.4))

func save_sectors() -> bool:
	for child in sectors.get_children():
		var packed := PackedScene.new()
		_set_owner(child,child)
		var path:=BASE+"scenes/sectors/"+str(child.name)+".tscn"
		if packed.pack(child)!=OK or ResourceSaver.save(packed,path)!=OK:
			push_error("K17 sector save failed: "+str(child.name))
			return false
		child.free()
		var instance: Node3D=(ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate()
		b._add(sectors,instance)
	return true

func _select(title: String) -> void:
	sector=b._group(sectors,title)

func _set_owner(node: Node,owner_node: Node) -> void:
	for child in node.get_children():
		child.owner=owner_node
		if child.scene_file_path=="": _set_owner(child,owner_node)

func _box(title: String,pos: Vector3,size: Vector3,material: String,collision:=true) -> Node3D:
	var body: Node3D
	if collision: body=b._box(sector,title,pos,size,Color.WHITE)
	else:
		body=b._group(sector,title)
		body.position=pos
		b._paint(body,"Mesh",Vector3.ZERO,size,Color.WHITE)
	body.set_meta("expansion",true)
	var mesh:=body.get_node("Mesh") as MeshInstance3D
	(mesh.mesh as BoxMesh).add_uv2=true
	mesh.material_override=_material(material)
	mesh.gi_mode=GeometryInstance3D.GI_MODE_STATIC
	if title=="Wall":
		for item in [["PaintBand",.7,.85,"olive"],["Skirting",.12,.24,"steel"]]:
			var trim:=MeshInstance3D.new()
			trim.name=item[0]
			trim.position.y=-size.y/2+float(item[1])
			var trim_mesh:=BoxMesh.new()
			trim_mesh.size=Vector3(size.x+.012,float(item[2]),size.z+.012)
			trim_mesh.add_uv2=true
			trim.mesh=trim_mesh
			trim.material_override=_material(item[3])
			trim.gi_mode=GeometryInstance3D.GI_MODE_STATIC
			b._add(body,trim)
	return body

func _material(id: String) -> StandardMaterial3D:
	if materials.has(id): return materials[id]
	var m:=StandardMaterial3D.new()
	m.roughness=.85
	var source={"wall":"concrete_wall_001","floor":"concrete_floor_02","asphalt":"asphalt_02"}.get(id,"")
	if source!="":
		m.albedo_texture=load(BASE+"assets/textures/"+source+"/Diffuse.jpg")
		m.uv1_triplanar=true
		m.uv1_scale=Vector3.ONE*.4
	else: m.albedo_color={"olive":Color("434c32"),"steel":Color("273236"),"beacon":Color("5bbdae"),"stripe":Color("c2a44f"),"sign":Color("141d23")}.get(id,Color("b9c2be"))
	if id=="beacon":
		m.emission_enabled=true
		m.emission=m.albedo_color
	materials[id]=m
	return m

func _room(center: Vector3,size: Vector2,front: Array,back: Array,east: Array=[]) -> void:
	_wall_h(center.z+size.y/2,center.x-size.x/2,center.x+size.x/2,front)
	_wall_h(center.z-size.y/2,center.x-size.x/2,center.x+size.x/2,back)
	_wall_v(center.x-size.x/2,center.z-size.y/2,center.z+size.y/2,[])
	_wall_v(center.x+size.x/2,center.z-size.y/2,center.z+size.y/2,east)
	_box("Roof",center+Vector3(0,3.4,0),Vector3(size.x+.4,.25,size.y+.4),"wall")
	_box("FloorFinish",center+Vector3(0,.008,0),Vector3(size.x,.016,size.y),"floor",false)
	for z in [center.z-size.y*.25,center.z+size.y*.25]:
		_box("CeilingFixture",Vector3(center.x,3.12,z),Vector3(2,.08,.25),"beacon",false)
		_light(Vector3(center.x,2.8,z),15,2)

func _wall_h(z: float,low: float,high: float,gaps: Array,y:=0.0,height:=3.2) -> void:
	var start:=low
	for i in gaps.size()+1:
		var end: float=gaps[i].x if i<gaps.size() else high
		if end>start: _box("Wall",Vector3((start+end)/2,y+height/2,z),Vector3(end-start,height,.35),"wall")
		start=gaps[i].y if i<gaps.size() else high

func _wall_v(x: float,low: float,high: float,gaps: Array,y:=0.0,height:=3.2) -> void:
	var start:=low
	for i in gaps.size()+1:
		var end: float=gaps[i].x if i<gaps.size() else high
		if end>start: _box("Wall",Vector3(x,y+height/2,(start+end)/2),Vector3(.35,height,end-start),"wall")
		start=gaps[i].y if i<gaps.size() else high

func _stair(x: float) -> void:
	var body:=StaticBody3D.new()
	body.name="StairRamp"
	body.set_meta("expansion",true)
	b._add(sector,body)
	var points:=PackedVector3Array()
	for dx in [-2.0,2.0]:
		for z in [-34.0,-24.0]:
			points.append(Vector3(x+dx,-4.25,z))
			points.append(Vector3(x+dx,(-4.0 if z==-34 else 0.0),z))
	var shape:=ConvexPolygonShape3D.new()
	shape.points=points
	var collision:=CollisionShape3D.new()
	collision.name="RampShape"
	collision.shape=shape
	b._add(body,collision)
	for i in 20:
		_box("StairTread",Vector3(x,-3.9+i*.2,-33.75+i*.5),Vector3(3.96,.2,.5),"floor",false)
	for side in [-2.1,2.1]:
		# Solid side walls stop falls into the excavated stairwell.
		_box("StairSide",Vector3(x+side,-.8,-29),Vector3(.2,6.4,10.3),"wall")
	_light(Vector3(x,2.5,-26),13,2)

func _model(id: String,pos: Vector3,angle:=0.0,scale:=Vector3.ONE) -> void:
	var model: Node3D=(load(BASE+"assets/models/"+id+".glb") as PackedScene).instantiate()
	model.position=pos
	model.rotation.y=angle
	model.scale=scale
	b._add(sector,model)
	for mesh in model.find_children("*","GeometryInstance3D",true,false): mesh.gi_mode=GeometryInstance3D.GI_MODE_STATIC

func _crate(pos: Vector3) -> void:
	_box("SupplyCover",pos,Vector3(2.8,1.3,1.5),"olive")
	_model("supply_crate",pos)

func _truck(p: Vector3) -> void:
	var collision_body:=_box("MilitaryTruck",p+Vector3(0,1.4,.1),Vector3(3.4,2.8,7),"olive")
	collision_body.get_node("Mesh").visible=false
	_box("Chassis",p+Vector3(0,.85,0),Vector3(2.7,.35,6.6),"steel",false)
	_box("CargoCanvas",p+Vector3(0,1.9,-1.2),Vector3(2.7,1.8,3.6),"olive",false)
	_box("TruckCab",p+Vector3(0,1.8,1.5),Vector3(2.6,1.8,1.6),"olive",false)
	_box("Hood",p+Vector3(0,1.2,2.8),Vector3(2.7,.8,1.3),"olive",false)
	_box("Windshield",p+Vector3(0,2.15,2.32),Vector3(2.3,.7,.025),"sign",false)
	_box("WindowDivider",p+Vector3(0,2.15,2.34),Vector3(.07,.8,.025),"olive",false)
	_box("Bumper",p+Vector3(0,.65,3.55),Vector3(3,.25,.3),"steel",false)
	for x in [-1.47,1.47]:
		_box("SideWindow",p+Vector3(signf(x)*1.32,2.15,1.5),Vector3(.02,.7,1.15),"sign",false)
		for z in [-1.95,1.95]:
			var wheel:=MeshInstance3D.new()
			wheel.position=p+Vector3(x,.65,z)
			wheel.rotation.z=PI/2
			var cylinder:=CylinderMesh.new()
			cylinder.top_radius=.65
			cylinder.bottom_radius=.65
			cylinder.height=.42
			cylinder.radial_segments=20
			cylinder.add_uv2=true
			wheel.mesh=cylinder
			wheel.material_override=_material("sign")
			wheel.gi_mode=GeometryInstance3D.GI_MODE_STATIC
			b._add(sector,wheel)
	for x in [-1.0,1.0]:
		_box("Headlamp",p+Vector3(x,1.15,3.47),Vector3(.38,.25,.02),"beacon",false)
	for z in [-2.6,-1.6,-.6,.4]: _box("CanvasRib",p+Vector3(0,2.82,z),Vector3(2.82,.08,.12),"steel",false)

func _fence(left: float,right: float,z: float) -> void:
	var count:=ceili((right-left)/1.9)
	var step: float=(right-left)/count
	for i in count: _model("fence_panel",Vector3(left+(i+.5)*step,0,z),0,Vector3(step/1.914,.91,1))

func _sign(text: String,pos: Vector3,angle: float) -> void:
	var mount:=Node3D.new()
	mount.position=pos
	mount.rotation.y=angle
	b._add(sector,mount)
	var plate:=MeshInstance3D.new()
	var plate_mesh:=BoxMesh.new()
	plate_mesh.size=Vector3(3.6,.52,.045)
	plate_mesh.add_uv2=true
	plate.mesh=plate_mesh
	plate.material_override=_material("sign")
	plate.gi_mode=GeometryInstance3D.GI_MODE_STATIC
	b._add(mount,plate)
	var label:=Label3D.new()
	label.text=text
	label.position.z=.029
	label.font_size=40
	label.pixel_size=.0028
	label.double_sided=false
	label.outline_size=2
	b._add(mount,label)

func _stripe(pos: Vector3,size: Vector3) -> void:
	_box("RouteMark",pos,size,"stripe",false)

func _light(pos: Vector3,distance: float,energy: float,beacon:=false) -> void:
	var light:=OmniLight3D.new()
	light.position=pos
	light.light_energy=energy
	light.omni_range=distance
	light.light_color=Color("98d7b8") if beacon else Color("bccac0")
	light.light_bake_mode=Light3D.BAKE_STATIC
	b._add(sector,light)
