extends RefCounted
const C := preload("res://maps/intelligence/resources/layout/k17_projection.gd")
var e

func build(expansion) -> void:
	e=expansion
	e._box("VaultFloor",Vector3(-4.5,-4.2,-43.4),Vector3(29,.4,18.8),"floor")
	e._wall_h(-34,-19,10,[Vector2(2,6)],-4,3.6)
	e._wall_h(-52.8,-19,10,[],-4,3.6)
	e._wall_v(-19,-52.8,-34,[],-4,3.6)
	e._wall_v(10,-52.8,-34,[Vector2(-40,-36)],-4,3.6)
	# A real L-shaped pocket: enter on its east side, then park west behind
	# the solid return. The side patrol cannot see either the rig or its user.
	e._wall_h(-48.7,-19,10,[Vector2(-7.8,-5.2),Vector2(-.8,1.8),Vector2(2.2,5.8)],-4,3.6)
	for x in [-11.5,-4.8,2.0,6.2]: e._wall_v(x,-52.8,-48.7,[],-4,3.6)
	e._wall_h(-45.3,-19,1.8,[Vector2(-10.9,-8.5),Vector2(-6.5,-3.5)],-4,3.6)
	# The file room has a recessed entry and a separate, FILE-gated exit.
	e._wall_v(-15.5,-45.3,-39,[],-4,3.6)
	e._wall_v(-8,-45.3,-39,[],-4,3.6)
	e._wall_v(-12.1,-46.4,-43.7,[],-4,3.6)
	e._wall_h(-39,-19,1.8,[Vector2(-14,-10),Vector2(-9.8,-8.5),Vector2(-6.5,-3.5)],-4,3.6)
	# Observe extraction before breaking the seal. Glass blocks movement and
	# navigation, but both the player and guards can legitimately see through.
	e._box("ObservationSillWall",Vector3(-9.15,-3.45,-39),Vector3(1.3,1.1,.35),"wall")
	e._box("ObservationHeadWall",Vector3(-9.15,-1.125,-39),Vector3(1.3,1.45,.35),"wall")
	var glass_body: StaticBody3D=e._box("ObservationGlass",Vector3(-9.15,-2.375,-39),Vector3(1.3,1.05,.12),"steel")
	glass_body.collision_layer=16
	var glass := StandardMaterial3D.new()
	glass.albedo_color=Color(.35,.58,.62,.12)
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	glass.roughness=.12
	glass_body.get_node("Mesh").material_override=glass
	glass_body.get_node("Mesh").gi_mode=GeometryInstance3D.GI_MODE_DISABLED
	for x in [-9.8,-8.5]: e._box("ObservationFrame",Vector3(x,-2.375,-39),Vector3(.07,1.17,.22),"steel",false)
	for y in [-2.9,-1.85]: e._box("ObservationFrame",Vector3(-9.15,y,-39),Vector3(1.37,.07,.22),"steel",false)
	var dressing := preload("res://maps/intelligence/tools/k17_room_dressing.gd").new()
	dressing.e=e
	dressing._board(Vector3(-9.15,-1.45,-39.23),PI,"QUAN SÁT\nLỐI RÚT",1.2)
	e._wall_v(-6.5,-45.3,-39,[],-4,3.6)
	e._wall_v(-3.5,-45.3,-39,[],-4,3.6)
	# The original sensor lane is retained. Its west escape door opens only
	# after the document, so the service stairs cannot bypass the signature.
	e._wall_v(1.8,-45.3,-34,[Vector2(-38.5,-34.5)],-4,3.6)
	e._wall_v(6.2,-48.7,-34,[Vector2(-40,-36)],-4,3.6)
	for s in preload("res://maps/intelligence/resources/layout/k17_layout.gd").SENSORS:
		for x in [-1.65,1.65]: e._box("SensorPost",s+Vector3(x,0,0),Vector3(.12,2.4,.12),"steel")
	# Raised room lights and cable tray all attach to the actual slab at -.4.
	for p in [Vector3(3,-.52,-50.5),Vector3(-3,-.52,-50.7),Vector3(-10,-.52,-50.7),Vector3(-13,-.52,-41),Vector3(-5,-.52,-36),Vector3(-16,-.52,-36),Vector3(4,-.52,-38),Vector3(4,-.52,-44)]:
		e._box("B1CeilingFixture",p,Vector3(1.25,.12,.26),"lamp",false)
		e._box("B1FixtureAnchor",p+Vector3(0,.09,0),Vector3(.2,.06,.2),"steel",false)
		e._light(p+Vector3(0,-.15,0),8,1.4)
	for x in [-16,-10,-4,2]:
		e._box("HallFixture",Vector3(x,-.52,-47),Vector3(.55,.12,.55),"lamp",false)
		e._box("HallFixtureAnchor",Vector3(x,-.43,-47),Vector3(.2,.06,.2),"steel",false)
		e._light(Vector3(x,-.8,-47),8,1.0)
		e._box("HallTrayHanger",Vector3(x,-.75,-48.38),Vector3(.05,.7,.05),"steel",false)
	e._box("HallCableTray",Vector3(-5.5,-1.08,-48.38),Vector3(26,.1,.22),"steel",false)
	for z in [-47.7,-46.3]: e._stripe(Vector3(-5.8,-3.985,z),Vector3(22,.02,.055))
	# Furnish the accessible north return lane and the archive, keeping the
	# cart corridor and all bay parking envelopes clear.
	for x in [-17,-10,-1]:
		e._box("B1ArchiveRack",Vector3(x,-2.9,-34.8),Vector3(2.6,2.2,.8),"steel")
		for y in [-3.6,-3,-2.4,-1.8]:
			e._box("ArchiveShelf",Vector3(x,y,-34.8),Vector3(2.75,.06,.9),"olive",false)
			for dx in [-.8,0,.8]: e._box("SealedArchiveBox",Vector3(x+dx,y+.17,-34.8),Vector3(.6,.28,.58),"paper",false)
	e._box("FileDesk",Vector3(-13,-3.55,-41.2),Vector3(2.4,.9,1.2),"steel").get_node("Mesh").visible=false
	e._model("archive_table",Vector3(-13,-3.55,-41.2))
	e._box("FileTerminal",Vector3(-14.4,-2.9,-40),Vector3(.8,1.4,.6),"olive")
	e._box("TerminalDisplay",Vector3(-14.4,-2.7,-40.31),Vector3(.6,.4,.018),"beacon",false)
	e._sign("MẬT LỆNH 04\nTHÁO NIÊM PHONG = 120 GIÂY",Vector3(-15.265,-1.6,-41.7),PI/2)
	e._sign("MÀN CHIẾU / HIỆU CHỈNH 01\nE DỰNG · E NẮM · WASD ĐẨY",Vector3(4,-1.65,-52.57),0)
	e._sign("HỐC 01 / ĐỖ SAU VÁCH\nCHE CẢ NGƯỜI VÀ KHUNG MÀN",Vector3(-2.8,-1.9,-52.57),0)
	e._sign("HỐC 02 / ĐỖ SAU VÁCH\nCHỜ TUẦN TRA ĐI QUA",Vector3(-9.8,-1.9,-52.57),0)
	e._sign("B1 / CHỐT NỘI BỘ\nKHU VỰC KIỂM SOÁT TẦM NHÌN",Vector3(-18.77,-1.65,-47),PI/2)
	e._sign("LỐI RÚT SAU NIÊM PHONG →\nCẦU THANG CHÍNH / BẢO TRÌ",Vector3(-1,-1.7,-34.23),PI)
	for bay in C.BAYS:
		e._stripe(bay+Vector3(.45,.015,0),Vector3(2.6,.02,2.5))
		e._box("BayWallServiceCabinet",Vector3(bay.x-.5,-2.85,-52.35),Vector3(1.1,2.3,.5),"olive")
	e._box("PrepWallCabinet",Vector3(5.65,-2.85,-51.8),Vector3(.7,2.3,1),"olive")
