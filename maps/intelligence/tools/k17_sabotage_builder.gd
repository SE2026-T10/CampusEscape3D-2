extends RefCounted
## Detailed, grounded equipment; its replaceable meshes are never statically merged/baked.
const C := preload("res://maps/intelligence/resources/layout/k17_sabotage.gd")
const BASE := "res://maps/intelligence/"
var b: SceneTree
var materials := {}

func navigation(builder: SceneTree, region: Node3D) -> void:
	# Runtime collider lives under Gameplay; bake the same footprint, then remove this cut.
	var cut: StaticBody3D = builder._box(region, "SabotageNavCut", C.TARGET+Vector3(0,1.18,0), Vector3(2,2.36,1.05), Color.BLACK)
	cut.set_meta("bake_cut", true)
	cut.get_node("Mesh").visible = false

func build(builder: SceneTree, gameplay: Node3D) -> bool:
	b = builder
	var rack := Node3D.new()
	rack.name = "Sabotage"
	rack.position = C.TARGET
	rack.rotation.y = C.TARGET_ANGLE
	rack.set_script(load(BASE+"scripts/sabotage_controller.gd"))
	b._add(gameplay, rack)
	var body := StaticBody3D.new()
	body.name = "CabinetCollision"
	body.position = Vector3(0,1.18,0)
	body.collision_layer = 1
	body.collision_mask = 0
	b._add(rack, body)
	b._shape(body, Vector3(2,2.36,1.05))
	_box(rack, "Plinth", Vector3(0,.10,0), Vector3(2,.2,1.05), "steel")
	for x in [-.94,.94]:
		_box(rack,"Frame",Vector3(x,1.27,0),Vector3(.12,2.14,.95),"steel")
	_box(rack,"Back",Vector3(0,1.2,-.46),Vector3(1.8,2,.08),"olive")
	_box(rack,"Top",Vector3(0,2.32,0),Vector3(2,.08,1),"steel")
	var intact: Node3D = b._group(rack,"Intact")
	for i in 6:
		var y := .42+i*.27
		_box(intact,"RelayModule",Vector3(0,y,.12),Vector3(1.74,.23,.68),"olive")
		for x in [-.75,.75]: _box(intact,"Handle",Vector3(x,y,.5),Vector3(.045,.13,.055),"steel")
		for x in [-.58,-.46,-.34,-.22]: _box(intact,"Vent",Vector3(x,y,.469),Vector3(.055,.13,.025),"dark")
		for x in [.25,.39,.53]: _box(intact,"Signal",Vector3(x,y,.473),Vector3(.05,.04,.025),"signal")
	var damaged: Node3D = b._group(rack,"Damaged")
	damaged.visible = false
	for i in 5:
		var panel := _box(damaged,"BurntModule",Vector3(.04,.39+i*.32,.18),Vector3(1.65,.20,.68),"burnt")
		panel.rotation.z = .04 if i%2 else -.07
	for x in [-.55,.45]: _box(damaged,"BrokenRelay",Vector3(x,.18,.17),Vector3(.45,.12,.45),"burnt")
	# Plate is attached to the top cross-member, with front-facing, fixed text.
	_box(rack,"Nameplate",Vector3(0,2.14,.52),Vector3(1.78,.29,.06),"dark")
	_label(rack,"Name",Vector3(0,2.14,.555),"TÌNH BÁO / DỰ PHÒNG 04",26,.0026)
	_box(rack,"Status",Vector3(.72,1.96,.50),Vector3(.10,.08,.06),"signal")
	_box(rack,"DeviceBracket",Vector3(0,1.12,.58),Vector3(.58,.42,.14),"steel")
	_box(rack,"InstructionPlate",Vector3(0,.82,.515),Vector3(.78,.24,.05),"dark")
	_label(rack,"BracketLabel",Vector3(0,.82,.546),"ĐIỂM PHÁ HOẠI\nTÙY CHỌN · SAU HỒ SƠ",22,.0023)
	var device: Node3D = b._group(rack,"Device")
	device.visible = false
	_box(device,"Case",Vector3(0,1.12,.72),Vector3(.48,.31,.19),"device")
	for x in [-.16,.16]: _box(device,"Clamp",Vector3(x,1.12,.825),Vector3(.045,.36,.025),"steel")
	_box(device,"Indicator",Vector3(0,1.12,.825),Vector3(.10,.06,.025),"signal")
	# Cable rises directly from the rear enclosure into a grounded roof vent.
	_box(rack,"CableConduit",Vector3(.70,2.65,-.3),Vector3(.08,.65,.08),"steel")
	_box(rack,"ConduitToCeiling",Vector3(.70,3.10,-.3),Vector3(.08,.30,.08),"steel")
	_box(rack,"CeilingGland",Vector3(.70,3.25,-.3),Vector3(.22,.1,.22),"olive")
	_box(rack,"RoofVent",Vector3(0,3.5,0),Vector3(1.1,.30,.85),"steel")
	for x in [-.4,-.2,0,.2,.4]: _box(rack,"RoofLouvre",Vector3(x,3.67,0),Vector3(.08,.04,.7),"dark")
	var target := Area3D.new()
	target.name = "Target"
	target.set_script(load(BASE+"scripts/sabotage_target.gd"))
	target.position = Vector3(0,1.12,.77)
	b._add(rack,target)
	b._shape(target,Vector3(.75,.70,.24))
	# Batch each visual state independently. Keep the mutable indicator separate.
	for group in [intact,damaged,device,rack]: _batch_group(group)
	# Serialize the editable equipment scene with local ownership, then instance it.
	var path := BASE+"scenes/props/k17_sabotage_target.tscn"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	for node in rack.find_children("*","",true,false): node.owner = rack
	var packed := PackedScene.new()
	if packed.pack(rack) != OK or ResourceSaver.save(packed,path) != OK: return false
	rack.free()
	b._add(gameplay,(load(path) as PackedScene).instantiate())
	var finale := Node3D.new()
	finale.name = "ExtractionFinale"
	finale.set_script(load(BASE+"scripts/extraction_finale.gd"))
	var finale_path := BASE+"scenes/effects/k17_sabotage_finale.tscn"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(finale_path.get_base_dir()))
	var finale_scene := PackedScene.new()
	if finale_scene.pack(finale) != OK or ResourceSaver.save(finale_scene,finale_path) != OK:
		finale.free()
		return false
	finale.free()
	b._add(gameplay,(load(finale_path) as PackedScene).instantiate())
	return true

func _batch_group(parent: Node3D) -> void:
	var groups := {}
	for child in parent.get_children():
		if not child is MeshInstance3D or child.name == "Status": continue
		var mat: Material = child.get_active_material(0)
		var key := mat.get_instance_id()
		if not groups.has(key): groups[key] = []
		groups[key].append(child)
	var count := 0
	for key in groups:
		var entries: Array = groups[key]
		if entries.size()<2: continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mesh in entries: surface.append_from(mesh.mesh,0,mesh.transform)
		var batch := MeshInstance3D.new()
		batch.name = "EquipmentBatch%d"%count
		batch.mesh = surface.commit()
		batch.material_override = entries[0].get_active_material(0)
		batch.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		for mesh in entries: mesh.free()
		b._add(parent,batch)
		count += 1

func _box(parent: Node3D, title: String, pos: Vector3, size: Vector3, material: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	mesh.position = pos
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(material)
	mesh.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	b._add(parent,mesh)
	return mesh

func _label(parent: Node3D,title: String,pos: Vector3,text: String,font: int,pixel: float) -> void:
	var label := Label3D.new()
	label.name = title
	label.position = pos
	label.text = text
	label.font_size = font
	label.pixel_size = pixel
	label.outline_size = 2
	label.double_sided = false
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	b._add(parent,label)

func _material(id: String) -> StandardMaterial3D:
	if materials.has(id): return materials[id]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = {"olive":Color("414e48"),"steel":Color("777b72"),"dark":Color("151f22"),"signal":Color("62cfa3"),"burnt":Color("272925"),"device":Color("a37f48")}[id]
	mat.roughness = .8
	mat.metallic = .45 if id == "steel" else .15
	if id == "signal":
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = .5
	materials[id] = mat
	return mat
