extends RefCounted
## Functional room dressing, authored with the sector geometry before nav/bake.
## Large furniture has matching solid envelopes. Small surface details do not.
var e

func build(expansion) -> void:
	e=expansion
	_guard_post()
	_command()
	_records()
	_utilities()
	_motor_pool()
	_service()
	_vault()
	_camera_mounts()

func _guard_post() -> void:
	e._select("guard_post")
	_bench(Vector3(-43,0,5),PI/2)
	_chair(Vector3(-36,0,2.6),PI)
	_cabinet(Vector3(-30,0,-3.8),"TỦ TRANG BỊ",0)
	_board(Vector3(-43.78,1.65,.5),PI/2,"LỊCH TRỰC / K17\nCA 01  ·  CA 02  ·  CA 03")
	_box("DutyRegister",Vector3(-36,.835,4.08),Vector3(.65,.025,.4),"paper")
	_chest(Vector3(-30.5,0,11.8),"TIẾP NHẬN / TRANG BỊ")
	_extinguisher(Vector3(-43.65,1.1,11))

func _command() -> void:
	e._select("command")
	# The former inner guard room is now a planning/briefing room. The pass
	# remains only in the west annex, with a clearly different sign there.
	_table(Vector3(-17.2,0,10.5),Vector2(2.8,1.5))
	_box("OperationMap",Vector3(-17.2,.85,10.5),Vector3(2.4,.018,1.12),"paper")
	for x in [-18.2,-17.2,-16.2]:
		_chair(Vector3(x,0,12),0)
		_box("MapRoute",Vector3(x,.866,10.5),Vector3(.05,.005,.8),"red")
	_cabinet(Vector3(-18.6,0,2),"LỆNH / TÁC CHIẾN",0)
	_board(Vector3(-4.235,1.8,2.6),-PI/2,"TÁC CHIẾN\nKHU BẮC · KHU ĐÔNG · TIẾP VẬN")
	# The south command alcove has no through-route; a staffed-looking
	# communications station fits here without narrowing the x=4 doorway.
	_desk(Vector3(9.3,0,1.1),"TIẾP NHẬN ĐIỆN TÍN",PI)
	_chair(Vector3(7,0,1.1),PI/2)
	_board(Vector3(.2,1.65,.235),0,"04 / CHỈ HUY\nĐIỆN TÍN ĐẾN · LỆNH ĐÃ DUYỆT")
	_cabinet(Vector3(-2.4,0,2),"TÀI LIỆU CA TRỰC",0)
	# Additional radio equipment is against the end wall, away from the
	# interactive console and its two approach points.
	_rack(Vector3(10.8,0,12.6),Vector2(1,.65),"VÔ TUYẾN / DỰ PHÒNG",0)
	_box("RadioCoverReturn",Vector3(1.2,.7,13.1),Vector3(.3,1.4,1.2),"olive",true)
	_cable(Vector3(10.9,2.7,13.78),Vector3(10.9,2.7,9.72))
	_cable(Vector3(10.9,2.2,12.6),Vector3(10.9,2.7,12.6))
	for z in [9.72,13.78]: _box("RadioConduitJunction",Vector3(10.9,2.7,z),Vector3(.2,.2,.16),"steel")
	for z in [11.0,13.0]: _cable(Vector3(10.9,2.7,z),Vector3(10.9,3.2,z))
	# Finite dispatch post had only a roof, walls and an empty floor.
	_table(Vector3(-18,0,41.9),Vector2(3.4,1.1))
	_bench(Vector3(-18,0,39.9),0)
	_chest(Vector3(-19.7,0,37.4),"ĐỘI PHẢN ỨNG A")
	_board(Vector3(-18,1.8,42.76),PI,"ĐIỀU ĐỘNG\nKIỂM SOÁT SÂN / KHO B1")

func _records() -> void:
	e._select("records")
	# Storage stays along the west/north walls. Patrols at x=-15/-1 and
	# the right-hand corridor/checkpoint keep their existing clear space.
	for z in [-22.0,-12.0,-3.0]:
		_rack(Vector3(-18.8,0,z),Vector2(.8,2.4),"LƯU TRỮ / "+str(int(-z)),PI/2)
	_table(Vector3(-8,0,-22.3),Vector2(3.2,1.2))
	for x in [-8.8,-8,-7.2]: _files(Vector3(x,.85,-22.3))
	_cabinet(Vector3(17.8,0,-19.5),"HỒ SƠ NIÊM PHONG",0)
	_rack(Vector3(17.8,0,-12),Vector2(2.8,.7),"PHÂN LOẠI / CHỜ CHUYỂN",0)
	_board(Vector3(-11.75,1.8,-13),PI/2,"06 / PHÂN LOẠI\nĐĂNG KÝ · ĐỐI CHIẾU · LƯU KHO")
	_board(Vector3(11.765,2.05,-8.25),-PI/2,"KHU MẬT B1 ↑\nCHỈ NGƯỜI CÓ GIẤY THÔNG HÀNH")
	for z in [-10.0,-20.0]:
		_box("SortingFixture",Vector3(16,3.14,z),Vector3(1.6,.08,.22),"lamp")
		e._light(Vector3(16,2.85,z),8,.9)

func _utilities() -> void:
	e._select("utilities")
	# Three existing compartments now read as switchgear, generator hall
	# and a workshop. Keep the alternating doors and the latch reachable.
	_rack(Vector3(30,0,2.3),Vector2(1.1,.85),"TỦ PHÂN PHỐI / 01",0)
	_rack(Vector3(32,0,2.3),Vector2(1.1,.85),"TỦ PHÂN PHỐI / 02",0)
	_board(Vector3(30.5,1.8,.235),0,"SƠ ĐỒ NGUỒN\nNGUỒN CHÍNH → CAMERA\nDỰ PHÒNG → TỰ KHỞI ĐỘNG")
	for x in [30.0,42.0]:
		for z in [9.2,10.1,11,11.9,12.8]:
			_box("GeneratorRib",Vector3(x,1.1,z),Vector3(2.55,.08,.1),"steel")
		_box("GeneratorBase",Vector3(x,.12,11),Vector3(2.75,.24,4.25),"steel")
		_box("GeneratorPanel",Vector3(x,1.1,8.96),Vector3(1.5,.65,.03),"sign")
		_box("GeneratorGauge",Vector3(x,1.15,8.93),Vector3(.36,.22,.02),"paper")
		_box("GeneratorStatus",Vector3(x+.55,1.15,8.92),Vector3(.1,.12,.02),"beacon")
		_cable(Vector3(x,1.6,11),Vector3(x,2.65,11))
		_cable(Vector3(x,2.65,11),Vector3(x,2.65,6.2))
		_box("GeneratorConduitJunction",Vector3(x,2.65,6.21),Vector3(.2,.25,.14),"steel")
		for z in [8.0,11.0]: _cable(Vector3(x,2.65,z),Vector3(x,3.275,z))
	for z in [1.25,3.25,5.25]:
		_box("PanelCabinetSeam",Vector3(42.942,1.25,z),Vector3(.012,2.25,.025),"steel")
	_box("GeneratorFixture",Vector3(36,3.14,9),Vector3(1.8,.08,.25),"lamp")
	e._light(Vector3(36,2.85,9),8,1.2)
	_table(Vector3(41.5,0,16.7),Vector2(3.8,1))
	for x in [40.4,41.2,42]: _box("WorkshopTool",Vector3(x,.85,16.7),Vector3(.12,.055,.4),"steel")
	_board(Vector3(41.5,1.65,17.77),PI,"XƯỞNG BẢO TRÌ\nDỤNG CỤ · PHỤ TÙNG · KIỂM TRA MÁY")
	_chest(Vector3(29.5,0,15.6),"PHỤ TÙNG DỰ PHÒNG")
	_extinguisher(Vector3(43.7,1.1,13.4))
	_box("InsulatedSpares",Vector3(40.8,.7,5.85),Vector3(1.5,1.4,.6),"olive",true)
	# A lamp is tied to the actual workshop ceiling fixture, not a floating
	# point light. Existing generator room was almost black from this side.
	_box("WorkshopFixture",Vector3(41,3.15,15.8),Vector3(1.8,.09,.25),"lamp")
	e._light(Vector3(41,2.85,15.8),8,.9)

func _motor_pool() -> void:
	e._select("motor_pool")
	_table(Vector3(-42.6,0,25),Vector2(1.1,1.5))
	_board(Vector3(-43.78,1.9,25),PI/2,"BẢO DƯỠNG XE\nNHIÊN LIỆU · LỐP · ĐIỆN")
	for x in [-42.8,-42.4]: _box("RepairTools",Vector3(x,.87,25),Vector3(.08,.08,.6),"steel")
	for z in [25.5,39.0]:
		_box("ParkingStripe",Vector3(-36,.026,z),Vector3(14,.012,.09),"stripe")
	_chest(Vector3(-30,0,25.5),"PHỤ TÙNG XE")

func _service() -> void:
	e._select("service_route")
	# Low peripheral stores and pipework give the outdoor channel a
	# maintenance/loading purpose while the running line remains open.
	_chest(Vector3(46.6,0,-3),"KHO VẬT TƯ / 08")
	_chest(Vector3(46.6,0,18),"VẬN CHUYỂN / K17")
	for z in [30.0,33.0]: _chest(Vector3(46.5,0,z),"HÀNG CHỜ XUẤT")
	for y in [.7,1.0]: _cable(Vector3(24.22,y,26),Vector3(24.22,y,42))
	for z in [26.0,42.0]: _box("ServiceConduitJunction",Vector3(24.22,.85,z),Vector3(.16,.5,.25),"steel")
	for z in [30.0,34.0,38.0]: _box("ServiceConduitClamp",Vector3(24.2,.85,z),Vector3(.1,.48,.08),"steel")
	_board(Vector3(24.23,1.85,40.5),PI/2,"08 / TIẾP VẬN\nCỬA HẬU → ĐÈN TẬP KẾT")
	_board(Vector3(24.23,1.85,-18),PI/2,"HÀNH LANG KỸ THUẬT\nB1 ↓  ·  TRẠM ĐIỆN →")
	# Service post gets equipment on its outside face, not an empty room.
	_box("ResponseCabinet",Vector3(45.9,1,-20),Vector3(.7,2,1.5),"olive",true)
	_board(Vector3(46.3,1.9,-20),PI/2,"CHỐT HẬU CẦN\nTHÔNG TIN / ĐIỀU ĐỘNG")
	_box("ServiceCargoStack",Vector3(27.3,.7,37),Vector3(1.5,1.4,3),"olive",true)
	_box("ServiceCargoReturn",Vector3(25.8,.7,35.5),Vector3(2.2,1.4,.8),"olive",true)
	for z in [36.0,37.0,38.0]: _box("CargoBand",Vector3(27.3,1.41,z),Vector3(1.55,.035,.08),"steel")

func _vault() -> void:
	e._select("secure_vault")
	# V6 archive furniture is authored with the new projection geometry.
	_board(Vector3(9.76,-2.15,-44.2),-PI/2,"B1 / KHO NIÊM PHONG\nLỐI BẢO TRÌ MỞ SAU HỒ SƠ")
	_cable(Vector3(10.12,-1.15,-41.78),Vector3(33.85,-1.15,-41.78))
	for x in [12.0,22.0,33.0]: _box("ReturnConduitJunction",Vector3(x,-1.15,-41.78),Vector3(.2,.25,.12),"steel")
	for x in [14.0,18.0,26.0,30.0]: _box("ReturnConduitClamp",Vector3(x,-1.15,-41.8),Vector3(.08,.12,.1),"steel")
	for x in [14.0,22.0,29.0]:
		_cable(Vector3(x,-1.15,-41.78),Vector3(x,-.5,-41.78))
		_cable(Vector3(x,-.5,-41.78),Vector3(x,-.5,-38))
		_box("ReturnFixture",Vector3(x,-.45,-38),Vector3(1.4,.08,.2),"lamp")
		_box("ReturnFixtureAnchor",Vector3(x,-.405,-38),Vector3(.3,.02,.25),"steel")
	_board(Vector3(20,-2.1,-41.76),0,"TUYẾN BẢO TRÌ →\nCẦU THANG PHÍA ĐÔNG")

func _camera_mounts() -> void:
	# These coordinates join the common camera's rear bracket at local
	# (0,0,.5), without moving its lens, sweep or gameplay cone.
	var config:=preload("res://maps/intelligence/resources/layout/k17_v4.gd")
	for entry in config.CAMERAS:
		var outdoor: bool=entry[0]=="Service"
		e._select("service_route" if outdoor else "command" if entry[0]=="Command" else "records")
		var direction: Vector3=entry[2]-entry[1]
		direction.y=0
		var rear: Vector3=entry[1]-direction.normalized()*.5
		if outdoor:
			_box("CameraMastBase",Vector3(rear.x,.08,rear.z),Vector3(.48,.16,.48),"steel")
			_box("CameraMast",Vector3(rear.x,1.55,rear.z),Vector3(.12,3.1,.12),"steel")
			_box("CameraJunction",rear+Vector3(0,-.35,0),Vector3(.26,.25,.14),"olive")
			_box("CameraSignRail",Vector3(rear.x,rear.y-.8,rear.z+.02),Vector3(1.45,.08,.08),"steel")
			_board(Vector3(rear.x,rear.y-.8,rear.z+.08),0,"GIÁM SÁT\nCHỐT ĐÔNG")
		else:
			_box("CameraCeilingPlate",Vector3(rear.x,3.19,rear.z),Vector3(.3,.08,.3),"steel")
			_cable(Vector3(rear.x,3.19,rear.z),rear)
		_box("CameraBracketJoint",rear,Vector3(.16,.16,.16),"steel")

func _box(title: String,p: Vector3,size: Vector3,material: String,solid:=false) -> Node3D:
	return e._box(title,p,size,material,solid)

func _cable(a: Vector3,b: Vector3) -> void:
	var conduit:=_box("Conduit",(a+b)*.5,Vector3(maxf(absf(a.x-b.x),.055),maxf(absf(a.y-b.y),.055),maxf(absf(a.z-b.z),.055)),"steel")
	conduit.set_meta("conduit_endpoints",PackedVector3Array([a,b]))

func _table(p: Vector3,size: Vector2) -> void:
	var body:=_box("WorkTable",p+Vector3(0,.4,0),Vector3(size.x,.8,size.y),"steel",true)
	body.get_node("Mesh").visible=false
	_box("TableTop",p+Vector3(0,.8,0),Vector3(size.x,.09,size.y),"olive")
	for x in [-size.x*.42,size.x*.42]:
		for z in [-size.y*.38,size.y*.38]: _box("TableLeg",p+Vector3(x,.4,z),Vector3(.09,.8,.09),"steel")

func _chair(p: Vector3,angle: float) -> void:
	_box("ChairSeat",p+Vector3(0,.47,0),Vector3(.55,.09,.55),"olive",true)
	var back:=Vector3(sin(angle)*.24,.8,cos(angle)*.24)
	_box("ChairBack",p+back,Vector3(.55,.55,.08) if absf(sin(angle))<.5 else Vector3(.08,.55,.55),"olive",true)
	for x in [-.22,.22]:
		for z in [-.22,.22]: _box("ChairLeg",p+Vector3(x,.23,z),Vector3(.045,.46,.045),"steel")

func _bench(p: Vector3,angle: float) -> void:
	var across:=absf(sin(angle))>.5
	var size:=Vector3(.65,.12,2.6) if across else Vector3(2.6,.12,.65)
	_box("BenchSeat",p+Vector3(0,.48,0),size,"olive",true)
	for offset in [-1.0,1.0]: _box("BenchFoot",p+(Vector3(0,.24,offset) if across else Vector3(offset,.24,0)),Vector3(.45,.48,.45),"steel",true)

func _desk(p: Vector3,title: String,angle: float) -> void:
	var body:=_box("CommsDesk",p+Vector3(0,.55,0),Vector3(3,1.1,1.2),"olive",true)
	body.get_node("Mesh").visible=false
	e._model("comms_console",p+Vector3(0,.55,0),angle)
	_board(p+Vector3(0,2.0,-.865),0,title)

func _cabinet(p: Vector3,title: String,angle: float) -> void:
	var sideways:=absf(sin(angle))>.5
	var body:=_box("FileCabinet",p+Vector3(0,1.05,0),Vector3(1.1,2.1,2) if sideways else Vector3(2,2.1,1.1),"olive",true)
	body.get_node("Mesh").visible=false
	e._model("locker",p+Vector3(0,1.1,0),angle+PI)
	_board(p+Vector3(0,1.8,0)+Basis(Vector3.UP,angle)*Vector3(0,0,.57),angle,title)

func _rack(p: Vector3,size: Vector2,title: String,angle: float) -> void:
	# Local coordinates keep the shelf front, notices and wall-facing back
	# consistent when a long rack is rotated against a side wall.
	var previous: Node3D=e.sector
	var rack:=Node3D.new()
	rack.name="DressedRack"
	rack.position=p
	rack.rotation.y=angle
	e.b._add(previous,rack)
	e.sector=rack
	if absf(sin(angle))>.5: size=Vector2(size.y,size.x)
	p=Vector3.ZERO
	var body:=_box("StorageRack",p+Vector3(0,1.1,0),Vector3(size.x,2.2,size.y),"olive",true)
	body.get_node("Mesh").visible=false
	for x in [-size.x*.46,size.x*.46]:
		for z in [-size.y*.45,size.y*.45]: _box("RackUpright",p+Vector3(x,1.1,z),Vector3(.06,2.2,.06),"steel")
	_box("RackBack",p+Vector3(0,1.1,-size.y*.48),Vector3(size.x,2.2,.035),"olive")
	var face: float=size.y*.5+.016
	_box("RackNoticeRail",p+Vector3(0,1.92,size.y*.5-.02),Vector3(size.x,.12,.08),"steel")
	for y in [.45,1.0,1.55,2.08]:
		_box("RackShelf",p+Vector3(0,y,0),Vector3(size.x,.06,size.y),"steel")
		for i in 4:
			var box_p:=p+Vector3((i-1.5)*size.x*.21,y+.2,0)
			_box("RecordBox",box_p,Vector3(size.x*.17,.32,size.y*.8),"paper" if i%2 else "olive")
			_box("RecordTag",box_p+Vector3(0,0,size.y*.405),Vector3(size.x*.1,.065,.008),"sign")
	_board(p+Vector3(0,1.92,face+.05),0,title,minf(1.65,size.x*.9))
	e.sector=previous

func _files(p: Vector3) -> void:
	for i in 3: _box("FileStack",p+Vector3(0,i*.045,0),Vector3(.5,.035,.38),"paper" if i%2 else "olive")

func _chest(p: Vector3,title: String) -> void:
	_box("EquipmentChest",p+Vector3(0,.5,0),Vector3(1.6,1,1),"olive",true)
	_box("ChestLid",p+Vector3(0,1.02,0),Vector3(1.65,.07,1.05),"steel")
	for x in [-.5,.5]: _box("ChestLatch",p+Vector3(x,.65,.52),Vector3(.12,.2,.04),"steel")
	_board(p+Vector3(0,.4,.53),0,title)

func _board(p: Vector3,angle: float,text: String,width:=1.65) -> void:
	var n:=Node3D.new()
	n.name="EquipmentNotice"
	n.position=p
	n.rotation.y=angle
	e.b._add(e.sector,n)
	var plate:=MeshInstance3D.new()
	var box:=BoxMesh.new()
	box.size=Vector3(width,.52,.035)
	box.add_uv2=true
	plate.mesh=box
	plate.material_override=e._material("sign")
	plate.gi_mode=GeometryInstance3D.GI_MODE_STATIC
	e.b._add(n,plate)
	var label:=Label3D.new()
	label.text=text
	label.font_size=30
	var longest:=1
	for line in text.split("\n"): longest=maxi(longest,line.length())
	label.pixel_size=minf(.0032,(width-.15)/(longest*18.0))
	label.position.z=.025
	label.outline_size=0
	label.modulate=Color("d2ccb2")
	e.b._add(n,label)
	preload("res://maps/intelligence/tools/k17_attachment_builder.gd").mount(n,Vector2(width,.52),"wall",.08)

func _extinguisher(p: Vector3) -> void:
	_box("Extinguisher",p,Vector3(.2,.55,.2),"red")
	_box("ExtinguisherBracket",p+Vector3(-.08,0,0),Vector3(.06,.4,.3),"steel")
