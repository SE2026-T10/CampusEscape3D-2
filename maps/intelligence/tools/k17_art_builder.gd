extends RefCounted
## Authoring helper. Ships a separate, editable environment scene, never runs in game.
const BASE := "res://maps/intelligence/"
const L := preload("res://maps/intelligence/resources/layout/k17_layout.gd")
const MODEL := BASE + "assets/models/"
var scene: Node3D
var concrete: StandardMaterial3D
var floor_mat: StandardMaterial3D
var asphalt: StandardMaterial3D
var olive: StandardMaterial3D
var steel: StandardMaterial3D
var yellow: StandardMaterial3D
var black: StandardMaterial3D
var lit: StandardMaterial3D
var roof_mat: StandardMaterial3D
var drain_mat: StandardMaterial3D
var models := {}


func build(collision_root: Node3D) -> Node3D:
	scene = Node3D.new()
	scene.name = "K17Environment"
	scene.set_meta("art_version", "v4-room-dressing")
	concrete = _pbr("concrete_wall_001", 0.42)
	floor_mat = _pbr("concrete_floor_02", 0.45)
	floor_mat.roughness_texture = null
	floor_mat.roughness = .92
	floor_mat.normal_scale = .25
	asphalt = _pbr("asphalt_02", 0.35)
	roof_mat = _pbr("corrugated_iron",.7)
	roof_mat.metallic = 1
	roof_mat.metallic_texture = load(BASE+"assets/textures/corrugated_iron/Metal.jpg")
	drain_mat = _pbr("rusty_metal_04",.7)
	drain_mat.metallic = .7
	olive = _solid(Color("434c32"), 0.25, 0.55)
	steel = _solid(Color("273236"), 0.7, 0.4)
	yellow = _solid(Color("c2a44f"), 0.2, 0.65)
	black = _solid(Color("171e22"), 0.1, 0.8)
	lit = _solid(Color("b9d8cc"), 0.1, 0.4)
	lit.emission_enabled = true
	lit.emission = Color("9ebfae")
	lit.emission_energy_multiplier = 1.5
	for body in collision_root.get_children():
		if body is not StaticBody3D:
			continue
		var shape := body.get_node("Shape").shape as BoxShape3D
		var pos: Vector3 = body.position
		var size: Vector3 = shape.size
		var title := str(body.name)
		if title.begins_with("NavigationGateCut") or title.begins_with("SensorPost") or title in ["LatchHousing","CheckpointSideCover"]:
			continue # The security overlay supplies these visuals; cuts are bake-only.
		if title == "Ground":
			_box("YardFoundation", pos, size, asphalt)
		elif title.begins_with("Fence"):
			_fence(pos, size)
		elif title.begins_with("Boundary"):
			_box(title, pos, size, concrete)
			_box(title + "Coping", pos + Vector3(0, 1.64, 0), Vector3(size.x + 0.1, 0.15, size.z + 0.1), steel)
		elif title == "PassDesk":
			_model("field_desk", pos, PI)
		elif title == "ArchiveDesk":
			_model("archive_table", pos)
		elif title.begins_with("GuardRoomLocker"):
			_model("locker", pos, PI)
		elif title.begins_with("ArchiveRack"):
			_model("archive_rack", pos, PI)
		elif title == "CheckpointCover":
			var rack := _model("archive_rack", pos)
			rack.scale = Vector3(0.69, 1, 0.82)
		elif title == "Terminal":
			_model("comms_console", pos, PI)
		elif title.begins_with("SupplyCrate"):
			_model("supply_crate", pos)
		elif title == "EntryCover":
			var cover := _model("supply_crate",pos)
			cover.scale = Vector3(.55,1.70,1.30)
		elif title == "VehicleBarrier":
			_box("BarrierPedestal",pos+Vector3(-3,0,0),Vector3(.5,1.2,.5),yellow)
			var boom := _cylinder("BarrierBoom",pos+Vector3(0,.45,0),.065,6.0,lit)
			boom.rotation.z = PI/2
			for x in [-2.6,-1.8,-1.0,-.2,.6,1.4,2.2]:
				var band := _cylinder("BarrierWarning",pos+Vector3(x,.45,0),.068,.3,yellow)
				band.rotation.z = PI/2
			_box("BarrierRest",pos+Vector3(3,0,0),Vector3(.08,1.2,.08),steel)
		elif title.begins_with("FuelDrum"):
			_model("fuel_drum",pos-Vector3(0,.11,0))
		elif title.begins_with("ServiceCover"):
			var crate := _model("supply_crate", pos)
			crate.scale = Vector3(0.48, 1, 1.17)
		else:
			_wall(title, pos, size)
	_interior()
	_yard()
	_lighting()
	return scene


func _wall(title: String, pos: Vector3, size: Vector3) -> void:
	_box(title, pos, size, concrete)
	# The painted lower band and base trim lie on the physical wall surface.
	var band_size := Vector3(size.x + 0.006, 0.85, size.z + 0.006)
	_box(title + "PaintBand", Vector3(pos.x, 0.70, pos.z), band_size, olive)
	_box(title + "Skirting", Vector3(pos.x, 0.12, pos.z), Vector3(size.x + .025, .24, size.z + .025), black)
	_box(title + "TopBeam", Vector3(pos.x, 3.08, pos.z), Vector3(size.x + .04, .22, size.z + .04), concrete)
	var horizontal := size.x > size.z
	var span: float = size.x if horizontal else size.z
	for i in range(1, int(span / 4.0) + 1):
		var offset := -span / 2 + i * 4.0
		var p := pos + (Vector3(offset, 0, 0) if horizontal else Vector3(0, 0, offset))
		var s := Vector3(.18, 3.2, size.z + .05) if horizontal else Vector3(size.x + .05, 3.2, .18)
		_box(title + "Joint", p, s, concrete)


func _fence(pos: Vector3, size: Vector3) -> void:
	var left := pos.x - size.x / 2
	var count := maxi(1, ceili(size.x / 1.90))
	var step := size.x / count
	for i in count:
		var panel := _model("fence_panel", Vector3(left + (i + .5) * step, 0, pos.z))
		panel.scale.x = step / 1.914
		panel.scale.y = .91
		_cylinder("FencePost", Vector3(left + i * step, 1.19, pos.z), .04, 2.38, steel)
	_cylinder("FencePost", Vector3(left + size.x, 1.19, pos.z), .04, 2.38, steel)
	# The original movement blocker is layer 5: physical, but transparent to sight rays.
	for offset in [.0, .12]:
		var wire := _cylinder("TopWire", Vector3(pos.x, 2.3 + offset, pos.z), .008, size.x, steel)
		wire.rotation.z = PI/2


func _interior() -> void:
	_box("InteriorSlab", Vector3(0,.012,-5), Vector3(39.5,.024,37.5), floor_mat)
	_box("Roof", Vector3(0,3.32,-5), Vector3(40.5,.24,38.5), concrete)
	for z in [-22.0, -18.0, -14.0, -10.0, -6.0, -2.0, 2.0, 6.0, 10.0, 13.5]:
		_box("CeilingBeam", Vector3(0,3.14,z), Vector3(40,.16,.16), olive)
	for x in [-19.75,19.75]:
		_box("CeilingCableTray", Vector3(x,2.86,-5), Vector3(.25,.1,37), steel)
		for j in 9:
			var pipe := _model("pipe_straight", Vector3(x,2.70,11 - j*4.0))
			pipe.rotation.x = PI/2
			pipe.scale.y = 4.0/.859
	# Full framed openings, with a lintel above the player's and guards' headroom.
	for x in [-12.0, 16.0]:
		_frame(Vector3(x,0,14), 3.6)
	_frame(Vector3(4,0,0), 3.6)
	var records_frame:=_group("RecordsSortingFrame")
	records_frame.position=Vector3(12,0,-5)
	records_frame.rotation.y=PI/2
	_frame(Vector3.ZERO,4,records_frame)
	for x in [-4.0,12.0]:
		var f := _group("CrossCorridorFrame")
		f.position = Vector3(x,0,7)
		f.rotation.y = PI/2
		_frame(Vector3.ZERO,3.6,f)
	_sign("K17 / CƠ SỞ TÌNH BÁO\nKHU VỰC KIỂM SOÁT  ·  CẤM PHẬN SỰ", Vector3(-12,2.85,14.27), 5.5, .48)
	_sign("04 / PHÒNG TÁC CHIẾN\nPHÂN TÍCH / ĐIỀU PHỐI", Vector3(-12,2.35,.29), 2.5,.54)
	_model("command_board",Vector3(-12,1.45,.32),PI)
	_frame(Vector3(4,0,4.7),3.6)
	_frame(Vector3(0,0,9.5),3.6)
	_sign("04 / THÔNG TIN LIÊN LẠC\nKÊNH LIÊN LẠC MÃ HÓA", Vector3(5,2.35,13.7), 3.4,.55,PI)
	_sign("06 / KHU HỒ SƠ MẬT\nCHỈ DÀNH CHO NGƯỜI CÓ PHẬN SỰ", Vector3(4,2.85,4.96), 4,.44)
	_sign("BẢO TRÌ / LỐI RA PHÍA ĐÔNG", Vector3(16,2.75,13.7), 3.2,.35)
	_sign("KHO MẬT B1 ↓\nMÃ KHO BẮT BUỘC", Vector3(8,2.3,-23.65), 2.1,.5)
	# Small details stay against existing solids, clear of all tested routes.
	for x in [-16.0,-8.0,0.0,8.0,16.0]:
		_model("caged_lamp",Vector3(x,2.35,-23.65))
	for x in [-17.0,-9.0,-1.0,7.0,17.0]:
		_fixture(Vector3(x,2.98,7))
	_fixture(Vector3(5,2.98,11.5))
	for x in [-14.0,0.0,14.0]:
		for z in [-7.0,-19.0]:
			_fixture(Vector3(x,2.98,z))
	for x in [-8.0,3.0]:
		_fixture(Vector3(x,2.98,-14))
	_fixture(Vector3(-12,2.98,2.8))
	# Maintenance floor stripe and physical direction marks.
	for z in range(1,14,2):
		_box("MaintenanceStripe", Vector3(16,.031,z),Vector3(.12,.006,1.2),yellow)
	for x in [-18.5,18.5]:
		for z in [2.0,10.0]:
			var valve := _model("pipe_valve",Vector3(x,1.7,z))
			valve.rotation.y = PI/2
	# Extraction signals and checkpoint become physical set dressing, not floating text.
	for x in [-36.0,36.0]:
		for side in [-1.0,1.0]:
			_box("ExtractionMark",Vector3(x+side*1.65,.018,51),Vector3(.10,.012,3.5),yellow)
			_cylinder("BeaconPost",Vector3(x+side*1.75,.55,51),.055,1.1,steel)
			_box("Beacon",Vector3(x+side*1.75,1.12,51),Vector3(.13,.16,.13),lit)
		_sign("ĐIỂM TẬP KẾT\n" + ("PHÍA TÂY" if x<0 else "PHÍA ĐÔNG"),Vector3(x,1.3,53.8),1.2,.48)
	for x in [6.95,9.05]:
		_box("CheckpointFloorMark",Vector3(x,.024,-6),Vector3(.08,.008,2.4),yellow)
	_sign("ĐIỂM CHUẨN BỊ\nCHECKPOINT / K17",Vector3(8,1.9,-3.26),1.7,.48,PI)


func _yard() -> void:
	# Parapet, loading awnings and fixed beams give the facade depth and scale.
	_box("FacadeCornice",Vector3(0,3.48,14.14),Vector3(41,.32,.68),concrete)
	for x in [-12.0,16.0]:
		_box("EntranceCanopy",Vector3(x,3.04,15),Vector3(5,.16,2),roof_mat)
		for side in [-2.25,2.25]:
			_box("CanopyBracket",Vector3(x+side,2.83,14.38),Vector3(.12,.4,.75),olive)
		_model("caged_lamp",Vector3(x-2,2.15,14.3))
	# Perimeter gate piers flank the two passable entrances; no new route obstacles.
	for x in [-18.7,-13.3,13.3,18.7]:
		_box("GatePier",Vector3(x,1.4,22),Vector3(.55,2.8,.55),concrete)
		_box("GatePierCap",Vector3(x,2.85,22),Vector3(.7,.12,.7),steel)
		_box("GateLamp",Vector3(x,2.94,22),Vector3(.26,.12,.26),lit)
	_sign("K17\nKHU VỰC QUÂN SỰ",Vector3(0,1.6,22.12),3,.85)
	for x in [-16.0,16.0]:
		_sign("CỔNG KIỂM SOÁT\nXUẤT TRÌNH GIẤY THÔNG HÀNH",Vector3(x,2.8,22),3.6,.50)
	# Bollards and supply details are placed inside the existing cover footprints.
	for p in [Vector3(-8,.75,17),Vector3(2,.75,19),Vector3(11,.75,16.5)]:
		_box("CrateStencil",p+Vector3(0,.1,.77),Vector3(.75,.24,.008),black)
	for x in [-16.0,16.0]:
		for z in [23.0,24.2]:
			_box("ThresholdStripe",Vector3(x,.012,z),Vector3(3.5,.008,.12),yellow)
	for x in [-22.0,22.0]:
		for z in [16.0,25.0]:
			_cylinder("FloodlightPole",Vector3(x,2.8,z),.07,5.6,steel)
			_model("floodlight",Vector3(x,5.55,z),0 if x<0 else PI)
			_spot("YardFlood",Vector3(x,5.48,z),Vector3(0,.1,z-4),Color("e4d3ad"),1.7,28, true)
	# A background antenna silhouette, outside playable interior routes.
	for y in [3.5,5.5,7.5]:
		_box("RadioAntenna",Vector3(-18,y,-22),Vector3(2.8,.05,.05),steel)
	_cylinder("AntennaMast",Vector3(-18,5,-22),.045,5.5,steel)
	for x in [-18.0,18.0]:
		for z in [16.0,20.0]:
			_box("DrainGrating",Vector3(x,.017,z),Vector3(1.2,.01,.34),drain_mat)
			for i in 9:
				_box("GratingSlot",Vector3(x-.5+i*.12,.024,z),Vector3(.045,.005,.27),black)


func _lighting() -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("07101c")
	sky_mat.sky_horizon_color = Color("263946")
	sky_mat.ground_bottom_color = Color("080e13")
	sky_mat.ground_horizon_color = Color("263946")
	sky_mat.sky_energy_multiplier = .45
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("92a9b7")
	env.ambient_light_energy = .22
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("283c4b")
	env.fog_density = .0025
	world.environment = env
	_add(scene,world)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation_degrees = Vector3(-45,-30,0)
	moon.light_color = Color("9fb4c4")
	moon.light_energy = .55
	moon.shadow_enabled = true
	moon.shadow_normal_bias = 2.0
	moon.directional_shadow_max_distance = 65
	_add(scene,moon)
	for p in [Vector3(-12,2.85,7),Vector3(-12,2.85,2.8),Vector3(4,2.85,7),Vector3(5,2.85,11.5),Vector3(4,2.85,2),Vector3(16,2.85,7),Vector3(-16,2.85,-10),Vector3(-4,2.85,-10),Vector3(10,2.85,-10),Vector3(4,2.85,-21),Vector3(-8,2.85,-14),Vector3(3,2.85,-14)]:
		_spot("InteriorLight",p,p-Vector3(0,3,.01),Color("c6d4c6"),2.5,17,false)
		var fill := OmniLight3D.new()
		fill.name = "InteriorBounceFill"
		fill.position = p-Vector3(0,.45,0)
		fill.light_color = Color("bccac0")
		fill.light_energy = .8
		fill.omni_range = 9
		fill.light_bake_mode = Light3D.BAKE_STATIC
		_add(scene,fill)
	for p in [Vector3(4,2.6,-1),Vector3(4,2.6,-20),Vector3(16,2.6,7)]:
		var alarm := OmniLight3D.new()
		alarm.name = "AlarmLight"
		alarm.position = p
		alarm.light_color = Color(1,.1,.035)
		alarm.light_energy = 2.0
		alarm.omni_range = 8.0
		alarm.visible = false
		alarm.set_meta("alarm_only",true)
		alarm.add_to_group("k17_alarm_lights",true)
		_add(scene,alarm)
		_box("AlarmHousing",p,Vector3(.2,.12,.2),steel)
	var probe := ReflectionProbe.new()
	probe.name = "InteriorReflection"
	probe.position = Vector3(0,1.6,-5)
	probe.size = Vector3(40,3.2,38)
	probe.interior = true
	probe.box_projection = true
	probe.intensity = .55
	_add(scene,probe)
	var lightmap := LightmapGI.new()
	lightmap.name = "LightmapGI"
	lightmap.quality = LightmapGI.BAKE_QUALITY_MEDIUM
	lightmap.bounces = 2
	lightmap.use_texture_for_bounces = true
	_add(scene,lightmap)


func _spot(title: String, pos: Vector3, target: Vector3, color: Color, energy: float, distance: float, shadow: bool) -> void:
	var light := SpotLight3D.new()
	light.name = title
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.spot_range = distance
	light.spot_angle = 65
	light.spot_attenuation = .4
	light.shadow_enabled = shadow
	light.shadow_normal_bias = 2.0
	light.light_bake_mode = Light3D.BAKE_STATIC
	_add(scene,light)
	light.quaternion = Quaternion(Vector3.FORWARD,(target-pos).normalized())


func _fixture(pos: Vector3) -> void:
	_box("FluorescentHousing",pos,Vector3(1.5,.08,.22),steel)
	_box("FluorescentDiffuser",pos-Vector3(0,.05,0),Vector3(1.35,.03,.14),lit)


func _frame(pos: Vector3,width: float,parent: Node3D = null) -> void:
	if parent == null:
		parent = scene
	for side in [-1.0,1.0]:
		_box("SteelDoorJamb",pos+Vector3(side*(width/2-.06),1.35,0),Vector3(.12,2.7,.48),steel,parent)
	_box("SteelDoorHeader",pos+Vector3(0,2.75,0),Vector3(width,.18,.48),steel,parent)
	_box("Lintel",pos+Vector3(0,3.03,0),Vector3(width,.33,.4),concrete,parent)
	for x in [-width/2+.25,width/2-.25]:
		_box("SafetyPaint",pos+Vector3(x,.3,.245),Vector3(.12,.6,.01),yellow,parent)


func _sign(text: String,pos: Vector3,width: float,height: float,angle := 0.0) -> void:
	var node := _group("FixedSign")
	node.position = pos
	node.rotation.y = angle
	_box("Backplate",Vector3.ZERO,Vector3(width,height,.035),black,node)
	_box("Accent",Vector3(-width/2+.025,0,.025),Vector3(.025,height*.85,.008),yellow,node)
	var label := Label3D.new()
	label.name = "Stencil"
	label.text = text
	label.font_size = 36
	var longest := 1
	for line in text.split("\n"):
		longest = maxi(longest,line.length())
	label.pixel_size = minf(height/(text.count("\n")+1)/48,width/maxf(longest*23,1))
	label.outline_size = 0
	label.modulate = Color("d2ccb2")
	label.position.z = .025
	label.no_depth_test = false
	_add(node,label)


func _model(id: String,pos: Vector3,angle := 0.0) -> Node3D:
	if not models.has(id):
		models[id] = load(MODEL+id+".glb")
	var node := (models[id] as PackedScene).instantiate() as Node3D
	node.name = id.to_pascal_case()
	node.position = pos
	node.rotation.y = angle
	_add(scene,node)
	_set_gi(node)
	return node


func _set_gi(node: Node) -> void:
	if node is GeometryInstance3D:
		node.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	for child in node.get_children():
		_set_gi(child)


func _pbr(id: String,tile: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var prefix := BASE+"assets/textures/"+id+"/"
	mat.albedo_texture = load(prefix+"Diffuse.jpg")
	mat.normal_enabled = true
	mat.normal_texture = load(prefix+"nor_gl.jpg")
	mat.normal_scale = .65
	mat.roughness_texture = load(prefix+"Rough.jpg")
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE*tile
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


func _solid(color: Color,metal: float,rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = rough
	return mat


func _box(title: String,pos: Vector3,size: Vector3,mat: Material,parent: Node = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	node.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.add_uv2 = true
	node.mesh = mesh
	node.material_override = mat
	node.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	_add(scene if parent == null else parent,node)
	return node


func _cylinder(title: String,pos: Vector3,radius: float,height: float,mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	node.position = pos
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.add_uv2 = true
	node.mesh = mesh
	node.material_override = mat
	node.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	_add(scene,node)
	return node


func _group(title: String) -> Node3D:
	var node := Node3D.new()
	node.name = title
	_add(scene,node)
	return node


func _add(parent: Node,node: Node) -> void:
	parent.add_child(node,true)
	node.owner = scene
