extends RefCounted
const C := preload("res://maps/intelligence/resources/layout/k17_projection.gd")
var e

func build(expansion) -> void:
	e=expansion
	e._box("VaultFloor",Vector3(-9,-4.2,-43.4),Vector3(38,.4,18.8),"floor")
	e._wall_h(-34,-28,10,[Vector2(2,6)],-4,3.6)
	e._wall_h(-52.8,-28,10,[],-4,3.6)
	e._wall_v(-28,-52.8,-34,[],-4,3.6)
	e._wall_v(10,-52.8,-34,[Vector2(-36.8,-34.2)],-4,3.6)
	e._wall_h(C.HALL_TOP,-28,10,[Vector2(-10.1,-7.3),Vector2(-1.1,1.7),Vector2(2.2,5.8)],-4,3.6)
	for x in [-17.2,-7,2,6.2]: e._wall_v(x,-52.8,C.HALL_TOP,[],-4,3.6)
	e._wall_h(C.HALL_BOTTOM,-28,1.8,[Vector2(-15.5,-12.5),Vector2(-11.4,-9),Vector2(-4.2,-1.8)],-4,3.6)
	# The return baffle is inside the room, never across the cart lane.
	e._wall_v(-22,C.HALL_BOTTOM,-39,[],-4,3.6)
	e._wall_v(-12.5,C.HALL_BOTTOM,-39,[],-4,3.6)
	e._wall_h(-39,-28,1.8,[Vector2(-11.4,-9),Vector2(-4.2,-1.8)],-4,3.6)
	e._wall_v(-17,-44.5,-42.7,[],-4,3.6)
	for x in [-11.4,-9,-4.2,-1.8]: e._wall_v(x,C.HALL_BOTTOM,-39,[],-4,3.6)
	for x in [-10.2,-3]: _window(x)
	# Both stairs and the patrol aisle meet upstream of S1.
	e._wall_v(1.8,C.HALL_BOTTOM,-34,[Vector2(-36.8,-34.2)],-4,3.6)
	e._wall_v(6.2,C.HALL_TOP,-34,[Vector2(-36.8,-34.2)],-4,3.6)
	e._box("HallServiceSoffit",Vector3(-11,-1.0,-47),Vector3(33.65,1,2.6),"wall")
	for x in [-24,-19,-14,-9,-4,1]:
		e._box("HallCeilingFixture",Vector3(x,-1.56,-47),Vector3(.5,.12,.5),"lamp",false)
		e._light(Vector3(x,-1.8,-47),7,1.1)
	for z in [-48.31,-45.69]: e._box("CartGuide",Vector3(-10.5,-3.97,z),Vector3(32,.06,.06),"steel",false)
	for x in [-25,-18,-6,0]:
		e._box("B1ArchiveRack",Vector3(x,-2.9,-34.8),Vector3(2.6,2.2,.8),"steel")
		for y in [-3.6,-3,-2.4,-1.8]:
			e._box("ArchiveShelf",Vector3(x,y,-34.8),Vector3(2.75,.06,.9),"olive",false)
			for dx in [-.8,0,.8]: e._box("ArchiveBox",Vector3(x+dx,y+.17,-34.8),Vector3(.6,.28,.58),"paper",false)
	e._box("FileDesk",Vector3(-19,-3.55,-41.2),Vector3(2.4,.9,1.2),"steel").get_node("Mesh").visible=false
	e._model("archive_table",Vector3(-19,-3.55,-41.2))
	for p in [Vector3(-26,-2.9,-42),Vector3(-7,-2.9,-42)]: e._box("ArchiveServiceCabinet",p,Vector3(1.1,2.2,1.2),"olive")
	e._box("PostDesk",C.TERMINAL-Vector3(0,.3,0),Vector3(1.3,.7,.8),"steel")
	e._box("PostMonitor",C.TERMINAL+Vector3(0,.3,0),Vector3(.65,.45,.18),"beacon",false)
	for p in [Vector3(3,-.52,-50.6),Vector3(-4,-.52,-50.7),Vector3(-13,-.52,-50.7),Vector3(-19,-.52,-41),Vector3(-3,-.52,-36),Vector3(-10,-.52,-36),Vector3(4,-.52,-40)]:
		e._box("B1CeilingFixture",p,Vector3(1.25,.12,.26),"lamp",false)
		e._box("B1FixtureAnchor",p+Vector3(0,.09,0),Vector3(.2,.06,.2),"steel",false)
		e._light(p+Vector3(0,-.15,0),8,1.4)
	e._sign("MẬT LỆNH 04 / NIÊM PHONG\nLẤY HỒ SƠ → RÚT NGƯỢC ĐƯỜNG VÀO",Vector3(-21.76,-1.8,-41.5),PI/2)
	e._sign("B1 / CAMERA NGUỒN NỘI BỘ\nE CHIẾM KÊNH · V XEM · R YÊU CẦU GIẢ",Vector3(4,-1.65,-52.57),0)
	for i in 2:
		e._sign("HỐC %d / CHE CẢ NGƯỜI VÀ XE\nCHỈ RẼ KHI CHỐT ĐANG NHÌN MÁY"%(i+1),Vector3(C.BAYS[i].x,-2.0,-52.57),0)
		e._stripe(C.BAYS[i]+Vector3(.4,.015,0),Vector3(2.5,.02,2.6))
	e._stripe(C.DOCK+Vector3(.5,.015,0),Vector3(1.4,.02,2.2))
	e._sign("ĐẨY QUA CỬA RỒI DỪNG\nKHI RÚT: RA CỬA, QUAY VỀ PHÍA SẢNH",Vector3(-20,-2.0,-45.76),PI)
	e._sign("SẢNH / CẢ HAI LỐI ĐỀU QUA S1 → S2",Vector3(8,-1.8,-34.23),PI)

func _window(x: float) -> void:
	var body: StaticBody3D=e._box("SideObservationGlass",Vector3(x,-2.7,C.HALL_BOTTOM),Vector3(2.4,1.6,.12),"steel")
	body.collision_layer=16
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color(.35,.58,.62,.14)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness=.15
	body.get_node("Mesh").material_override=material
	body.get_node("Mesh").gi_mode=GeometryInstance3D.GI_MODE_DISABLED
	e._box("ObservationSill",Vector3(x,-3.75,C.HALL_BOTTOM),Vector3(2.4,.5,.35),"wall")
	e._box("ObservationHead",Vector3(x,-1.15,C.HALL_BOTTOM),Vector3(2.4,1.5,.35),"wall")
	for side in [-1.2,1.2]: e._box("ObservationFrame",Vector3(x+side,-2.7,C.HALL_BOTTOM),Vector3(.07,1.7,.22),"steel",false)
	for y in [-3.5,-1.9]: e._box("ObservationFrame",Vector3(x,y,C.HALL_BOTTOM),Vector3(2.47,.07,.22),"steel",false)
