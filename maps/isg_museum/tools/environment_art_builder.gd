extends RefCounted

## Offline authoring only. Generated nodes have stable names and unit-scale roots.
## Imported geometry is flattened with ALL ancestor transforms before fitting.
const BASE := "res://maps/isg_museum/"
const MODELS := BASE + "assets/models/"
const LAYOUT := BASE + "resources/environment_art_layout.json"
const STONE := preload("res://maps/isg_museum/assets/materials/presets/marble.tres")
var sources: Dictionary = {}
var stone_meshes: Dictionary = {}
const DERIVED := {
	"vegetation/shrub_04/shrub_04_2k.gltf":"derived/shrub_04.scn",
	"vegetation/potted_plant_01/potted_plant_01_2k.gltf":"derived/potted_plant_01.scn",
	"exhibits/terpsichore_lyran/terpsichore_lyran_by_canova.glb":"derived/terpsichore.scn",
	"vegetation/tree_small_02/tree_small_02_2k.gltf":"derived/tree_small_02_near.scn"}

func load_layout() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	assert(data is Dictionary and data.schema_version == 1, "Invalid environment art layout")
	for entry in data.geometry_props:
		assert(entry.id is String and entry.position.size() == 3 and entry.size.size() == 3)
		assert(ResourceLoader.exists(MODELS + entry.source), "Missing art source: " + entry.source)
	return data

func vec(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

func add(parent: Node, child: Node, id: String) -> void:
	child.name = id
	parent.add_child(child)
	child.owner = parent.owner if parent.owner else parent

func group(parent: Node, id: String) -> Node3D:
	var result := Node3D.new()
	add(parent, result, id)
	return result

func replace_owned_visual(parent: Node, id: String) -> Node3D:
	var old := parent.get_node_or_null(id)
	if old:
		assert(old.get_meta("environment_art", false), "Refuse to replace unowned node")
		old.free()
	var result := group(parent, id)
	result.set_meta("environment_art", true)
	result.set_meta("preserve_source_material", true)
	return result

func compute_visual_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = relative_transform(root, mesh) * mesh.get_aabb()
		result = bounds if first else result.merge(bounds)
		first = false
	return result

func relative_transform(root: Node3D, child: Node3D) -> Transform3D:
	var result := child.transform
	var parent := child.get_parent()
	while parent != root:
		if parent is Node3D:
			result = parent.transform * result
		parent = parent.get_parent()
	return result

func extract_visual_parts(source: String, selectors: Array = [], use_derived := true) -> Node3D:
	var imported := (load(MODELS + (DERIVED.get(source,source) if use_derived else source)) as PackedScene).instantiate()
	var result := Node3D.new()
	for original in imported.find_children("*", "MeshInstance3D", true, false):
		var surface_selection := not selectors.is_empty() and str(selectors[0]).begins_with("material:")
		if not selectors.is_empty() and not surface_selection and not str(original.name) in selectors:
			continue
		var visual := MeshInstance3D.new()
		visual.mesh = original.mesh
		if surface_selection:
			var extracted := ArrayMesh.new()
			for surface in original.mesh.get_surface_count():
				var material: Material = original.mesh.surface_get_material(surface)
				if material and ("material:"+material.resource_name) in selectors:
					extracted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,original.mesh.surface_get_arrays(surface))
					extracted.surface_set_material(extracted.get_surface_count()-1,material)
			visual.mesh = extracted
		visual.transform = relative_transform(imported, original)
		visual.material_override = original.material_override
		result.add_child(visual)
		visual.name = original.name
	imported.free()
	return result

func prepare_visual(source: String, size: Vector3, yaw := 0.0, selectors: Array = [],
		mat: Material = null) -> Node3D:
	var wrapper := Node3D.new()
	wrapper.set_meta("preserve_source_material", true)
	wrapper.set_meta("source", source)
	var pivot := extract_visual_parts(source, selectors)
	pivot.name = "VisualPivot"
	wrapper.add_child(pivot)
	# Rotate before measuring, so target dimensions describe the map axes.
	pivot.rotation.y = deg_to_rad(yaw)
	var bounds := compute_visual_bounds(wrapper)
	assert(bounds.size.x > 0 and bounds.size.y > 0 and bounds.size.z > 0)
	var fit := size / bounds.size
	pivot.transform = Transform3D(Basis.from_scale(fit), Vector3.ZERO) * pivot.transform
	pivot.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * fit
	if mat:
		for mesh in pivot.get_children():
			# Drop unused original texture references on lit stone adaptations.
			var key: String = source+str(mesh.name)
			if not stone_meshes.has(key):
				var adapted: ArrayMesh = mesh.mesh.duplicate()
				for surface in adapted.get_surface_count():
					adapted.surface_set_material(surface,null)
				stone_meshes[key] = adapted
			mesh.mesh = stone_meshes[key]
			mesh.material_override = mat
	_record_source(source, pivot)
	return wrapper

func place(parent: Node3D, id: String, source: String, size: Vector3, at: Vector3,
		yaw := 0.0, selectors: Array = [], mat: Material = null) -> Node3D:
	var module := ""
	if selectors == ["Object_4"] and size.is_equal_approx(Vector3(.55,3.05,.55)):
		module = "gothic_column"
	var wrapper: Node3D
	if not module.is_empty():
		wrapper = load(BASE+"scenes/art/modules/"+module+".tscn").instantiate()
		_record_source(source,wrapper.get_node("VisualPivot"))
	else:
		wrapper = prepare_visual(source, size, yaw, selectors, mat)
	add(parent, wrapper, id)
	wrapper.position = at
	if module.is_empty():
		assign_owners(wrapper, parent.owner if parent.owner else parent)
	return wrapper

func assign_owners(node: Node, owner_root: Node) -> void:
	for child in node.get_children():
		child.owner = owner_root
		assign_owners(child, owner_root)

func colour(value: Color, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = value
	mat.roughness = 0.78
	mat.metallic = metallic
	return mat

func box(parent: Node3D, id: String, size: Vector3, at: Vector3, mat: Material,
		collision := false) -> Node3D:
	var holder: Node3D = StaticBody3D.new() if collision else Node3D.new()
	add(parent, holder, id)
	holder.position = at
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = mat
	add(holder, mesh, "Mesh")
	if collision:
		holder.collision_layer = 1
		holder.collision_mask = 0
		var collider := CollisionShape3D.new()
		var form := BoxShape3D.new()
		form.size = size
		collider.shape = form
		add(holder, collider, "Collision")
	return holder

func hide_legacy(root: Node, path: String) -> void:
	var old := root.get_node_or_null(path)
	if old is GeometryInstance3D:
		old.hide()
		old.set_meta("art_hidden", true)

func apply_to_geometry(scene: Node3D, layout: Dictionary) -> void:
	var art := replace_owned_visual(scene, "EnvironmentArt")
	build_courtyard(scene, art, layout.courtyard)
	var props := group(art, "Interiors")
	for entry in layout.geometry_props:
		place(props, entry.id, entry.source, vec(entry.size), vec(entry.position), entry.yaw)
		for path in entry.get("hide", []):
			hide_legacy(scene, path)
	for planter in scene.get_node("FrontYard").get_children():
		if str(planter.name).begins_with("Planter"):
			place(props,"FrontFern%d" % props.get_child_count(),"vegetation/fern_02/fern_02_2k.gltf",
				Vector3(1.25,.8,1.25),planter.position+Vector3(0,.4,0))
	# Keep original solid desk cover and locker/key anchors; only visuals change.
	for i in 2:
		var id := "WestNorth0" if i == 0 else "WestSouth0"
		hide_legacy(scene,"Cover/"+id+"/Mesh")
		place(props,"DisplayBase%d" % i,"derived/display_case_base.scn",Vector3(2.2,1.2,3),
			Vector3(4.3,0,11.5 if i == 0 else 18))
	for child in scene.get_node("StaffInterior").get_children():
		if str(child.name).begins_with("ChairLeg") or str(child.name).begins_with("Radio"):
			hide_legacy(scene, "StaffInterior/" + str(child.name))
	for child in scene.get_node("StorageInterior").get_children():
		if str(child.name).begins_with("Shelf") or str(child.name).begins_with("ToolBox"):
			hide_legacy(scene, "StorageInterior/" + str(child.name))
	var ceilings := group(art, "Ceilings")
	# No collision/navigation above the existing walkable volume.
	for r in [Rect2(0,0,36,9), Rect2(0,21,36,9), Rect2(0,9,12,12), Rect2(24,9,12,12)]:
		box(ceilings, "Ceiling%d" % ceilings.get_child_count(), Vector3(r.size.x,.15,r.size.y),
			Vector3(r.get_center().x,9.12,r.get_center().y), colour(Color(.71,.68,.59)))
	# Room B receives a separate blue-grey finish without changing its solid wall.
	var palette = load(BASE + "tools/material_palette.gd")
	for wall_group in ["Exterior", "Floor2Rooms"]:
		for body in scene.get_node(wall_group).get_children():
			var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
			if mesh and mesh.mesh is BoxMesh:
				palette._room_wall_faces(art, str(body.name), AABB(body.position-mesh.mesh.size/2, mesh.mesh.size),
					Rect2(27.15,6.15,8.7,11.7), colour(Color(.27,.34,.36)))
	batch_visuals(art.get_node("Arcade"))
	batch_visuals(art.get_node("Balustrades"))
	var finishes := group(art,"InteriorFinishes")
	for rect in [Rect2(9,6,18,3),Rect2(9,21,18,3),Rect2(9,9,3,12),Rect2(24,9,3,12),Rect2(9,24,18,6)]:
		palette._floor(finishes,"Marble%d" % finishes.get_child_count(),rect,4.504,STONE)
	var wood := preload("res://maps/isg_museum/assets/materials/presets/dark_wood.tres")
	for floor_index in 2:
		for room in [Rect2(.15,.15,26.7,5.7),Rect2(.15,6.15,8.7,17.7),Rect2(27.15,6.15,8.7,11.7)]:
			for wall_group in ["Exterior","Floor%dRooms" % (floor_index+1)]:
				for body in scene.get_node(wall_group).get_children():
					var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
					if not mesh or not mesh.mesh is BoxMesh:
						continue
					var bounds := AABB(body.position-mesh.mesh.size/2,mesh.mesh.size)
					var base := floor_index*4.5
					if bounds.position.y > base+.1 or bounds.end.y < base+.9:
						continue
					# Reuse face clipping, with a temporary shifted wall: helper clips at 4.5.
					var clipped := bounds
					clipped.position.y = 4.5
					clipped.size.y = .85
					var panel := group(finishes,"Wainscot%d" % finishes.get_child_count())
					palette._room_wall_faces(panel,str(body.name),clipped,room,wood)
					panel.position.y = base-4.5

func batch_visuals(parent: Node3D) -> void:
	# Static batching also works with Godot's headless dummy renderer, which does
	# not retain MultiMesh transform buffers when serializing offline resources.
	# Collision bodies remain separate so the real gaps still pass sight rays.
	var batches := {}
	for visual in parent.find_children("*","MeshInstance3D",true,false):
		if not visual.visible:
			continue
		var key := str(visual.mesh.get_rid())+str(visual.material_override.get_rid() if visual.material_override else "")
		# Identical primitive spindles are created separately by box().
		if visual.get_parent().get_meta("rail_spindle",false):
			key = "spindles"
		if not batches.has(key):
			batches[key] = []
		batches[key].append(visual)
	for key in batches:
		var members: Array = batches[key]
		if members.size() < 2:
			continue
		var batch := MeshInstance3D.new()
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in members.size():
			for part in members[i].mesh.get_surface_count():
				surface.append_from(members[i].mesh,part,relative_transform(parent,members[i]))
			var hidden_root: Node3D = members[i]
			var ancestor: Node = members[i].get_parent()
			while ancestor != parent:
				if ancestor is Node3D and not ancestor.scene_file_path.is_empty():
					hidden_root = ancestor
				ancestor = ancestor.get_parent()
			hidden_root.hide()
			hidden_root.set_meta("art_hidden",true)
		batch.mesh = surface.commit()
		batch.material_override = members[0].material_override
		batch.set_meta("art_batch",true)
		add(parent,batch,"Batch%d" % parent.get_child_count())

func build_courtyard(scene: Node3D, art: Node3D, config: Dictionary) -> void:
	var stone := colour(Color(.82,.77,.63))
	var statue_mat := colour(Color(.86,.83,.73)) # Lit override replaces source unlit shader.
	var leaves := colour(Color(.12,.24,.065))
	var metal := colour(Color(.16,.19,.19), .55)
	var garden := scene.get_node("Courtyard")
	var arcade := group(art, "Arcade")
	var gothic := "architecture/gothic_architectural_structures/gothic_architectural_structures.glb"
	var occupied_columns := {}
	# The central 2 m opening is bounded at 17/19 or 14/16, never filled by a post.
	for side in 4:
		for base_y in [0.0, 4.5]:
			for offset in [0.0, 2.5, 5.0, 7.0, 9.5, 12.0]:
				var p := Vector3(12+offset,base_y,9 if side == 0 else 21)
				if side >= 2:
					p = Vector3(12 if side == 2 else 24,base_y,9+offset)
				# Posts touching an entrance sit OUTSIDE its clear width.
				if offset == 5.0:
					p.x -= .28 if side < 2 else 0.0
					p.z -= .28 if side >= 2 else 0.0
				if offset == 7.0:
					p.x += .28 if side < 2 else 0.0
					p.z += .28 if side >= 2 else 0.0
				# The two neighbouring arcades share a single corner column.
				if occupied_columns.has(p):
					continue
				occupied_columns[p] = true
				place(arcade,"Column%d" % arcade.get_child_count(),gothic,Vector3(.55,3.05,.55),p,
					0,["Object_4"],stone)
				var body := StaticBody3D.new()
				add(arcade,body,"ColumnBody%d" % arcade.get_child_count())
				body.position = p
				body.collision_layer = 1
				body.collision_mask = 0
				var shaft := CollisionShape3D.new()
				var form := CylinderShape3D.new()
				form.radius = .15
				form.height = 2.85
				shaft.shape = form
				shaft.position.y = 1.625
				add(body,shaft,"Shaft")
				var foot := CollisionShape3D.new()
				var foot_shape := BoxShape3D.new()
				foot_shape.size = Vector3(.55,.2,.55)
				foot.shape = foot_shape
				foot.position.y = .1
				add(body,foot,"Foot")
			for pair in [[.0,2.5],[2.5,4.72],[4.72,7.28],[7.28,9.5],[9.5,12.0]]:
				var mid: float = (pair[0]+pair[1])/2
				var p := Vector3(12+mid,base_y+3.05,9 if side == 0 else 21)
				var size := Vector3(pair[1]-pair[0],1.4,.39)
				if side >= 2:
					p = Vector3(12 if side == 2 else 24,base_y+3.05,9+mid)
					size = Vector3(.39,1.4,pair[1]-pair[0])
				place(arcade,"Arch%d" % arcade.get_child_count(),gothic,size,p,
					90 if side < 2 else 0,["Object_5"],stone)
	# Existing cover colliders remain exactly 1.3 x 1.2 x 1.3 m.
	for index in config.statues.size():
		var at := vec(config.statues[index])
		var pedestal := garden.get_node("Planter%d" % index)
		pedestal.get_node("Mesh").material_override = stone
		box(art,"PedestalCap%d" % index,Vector3(1.3,.08,1.3),at+Vector3(0,1.16,0),stone)
		place(art,"Statue%d" % index,"exhibits/terpsichore_lyran/terpsichore_lyran_by_canova.glb",
			Vector3(.72,1.27,.64),at+Vector3(0,1.2,0),rad_to_deg(atan2(18-at.x,15-at.z)),[],statue_mat)
	for child in garden.get_children():
		var id := str(child.name)
		if id.begins_with("Ground") and child is StaticBody3D:
			var mesh := child.get_node("Mesh") as MeshInstance3D
			mesh.mesh = mesh.mesh.duplicate()
			mesh.mesh.size.y = .9
			mesh.position.y = -.15
			mesh.material_override = stone
			var size: Vector3 = child.get_node("Collision").shape.size
			# Dense visible foliage core matches the top 0.3 m of solid sight cover.
			box(art,"HedgeCore"+id,Vector3(size.x,.3,size.z),child.position+Vector3(0,.45,0),leaves)
			var length := maxf(size.x,size.z)
			for i in int(ceil(length/.65)):
				var p: Vector3 = child.position + Vector3(0,.3,0)
				if size.x > size.z:
					p.x += -length/2+.33+i*.65
					p.z += .09 if p.z < 15 else -.09
				else:
					p.z += -length/2+.33+i*.65
					p.x += .09 if p.x < 18 else -.09
				place(art,"Shrub%d" % art.get_child_count(),"vegetation/shrub_04/shrub_04_2k.gltf",
					Vector3(.6,.3,.48) if size.x > size.z else Vector3(.48,.3,.6),p)
		elif id.begins_with("UpperRail"):
			# Replace solid wall with real bars and spindles. Rays pass the visible gaps.
			child.get_node("Mesh").hide()
			child.get_node("Mesh").set_meta("art_hidden",true)
			child.get_node("Collision").disabled = true
	build_railings(art, stone)
	# Extract basin only, preserving its vertical proportions. Upper tiers omitted.
	var fountain := garden.get_node("FountainBase")
	fountain.get_node("Mesh").hide()
	fountain.get_node("Mesh").set_meta("art_hidden",true)
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 1.5
	cylinder.height = .6
	fountain.get_node("Collision").shape = cylinder
	place(art,"FountainBasin","architecture/italian_fountain/fountain.glb",Vector3(3,.48,3),
		Vector3(18,0,15),0,["Object002_Material #2_0"],stone)
	var water := colour(Color(.17,.4,.42,.62), .2)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var surface := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.27
	disc.bottom_radius = 1.27
	disc.height = .025
	surface.mesh = disc
	surface.material_override = water
	add(art,surface,"Water")
	surface.position = Vector3(18,.29,15)
	var jet := MeshInstance3D.new()
	var nozzle := CylinderMesh.new()
	nozzle.top_radius = .025
	nozzle.bottom_radius = .06
	nozzle.height = .55
	jet.mesh = nozzle
	jet.material_override = water
	add(art,jet,"SmallJet")
	jet.position = Vector3(18,.57,15)
	for p in [Vector3(13,.02,12.8),Vector3(23,.02,12.8),Vector3(13,.02,17.2),Vector3(23,.02,17.2)]:
		place(art,"Fern%d" % art.get_child_count(),"vegetation/fern_02/fern_02_2k.gltf",Vector3(.9,.65,.9),p)
	for p in [Vector3(13.1,0,10.1),Vector3(22.9,0,19.9)]:
		var tree := place(art,"Tree%d" % art.get_child_count(),"vegetation/tree_small_02/tree_small_02_2k.gltf",
			Vector3(2.1,5.8,2.1),p)
		for mesh in tree.get_node("VisualPivot").get_children():
			mesh.visibility_range_end = 19
			mesh.visibility_range_end_margin = 1
		var far_tree := place(art,"TreeFar%d" % art.get_child_count(),"derived/tree_small_02_far.scn",Vector3(2.1,5.8,2.1),p)
		for mesh in far_tree.get_node("VisualPivot").get_children():
			mesh.visibility_range_begin = 19
			mesh.visibility_range_begin_margin = 1
	build_roof(art,config,metal)
	for x in [12.5,23.5]:
		for z in [10,20]:
			var light := OmniLight3D.new()
			add(art,light,"CourtyardLight%d" % art.get_child_count())
			light.position = Vector3(x,3.4,z)
			light.light_color = Color(1,.84,.62)
			light.light_energy = 1.2
			light.omni_range = 6
			light.shadow_enabled = false

func build_railings(art: Node3D, stone: Material) -> void:
	var rails := group(art,"Balustrades")
	for side in 4:
		var rail := group(rails,"Side%d" % side)
		rail.position = Vector3(12,4.5,9 if side == 0 else 21)
		if side >= 2:
			rail.position = Vector3(12 if side == 2 else 24,4.5,21)
			rail.rotation.y = PI/2
		for y in [.12,1.08]:
			box(rail,"Bar%d" % rail.get_child_count(),Vector3(12,.24,.3),Vector3(6,y,0),stone,true)
		for i in 5:
			box(rail,"Post%d" % i,Vector3(.32,1.2,.32),Vector3(i*3,.6,0),stone,true)
		for i in 4:
			place(rail,"Balusters%d" % i,"architecture/balustrade_balcony/balustrade_balcony.glb",
				Vector3(2.6,.72,.2),Vector3(i*3+1.5,.24,0),0,["Baluster 001_Baluster Texture_0"],stone)
		# Small spindle colliders keep capsule inside while leaving truthful ray gaps.
		for i in 48:
			var spindle := box(rail,"Spindle%d" % i,Vector3(.12,.72,.2),Vector3(.125+i*.25,.6,0),stone,true)
			spindle.set_meta("rail_spindle",true)

func build_roof(art: Node3D, config: Dictionary, metal: Material) -> void:
	var roof := group(art,"Roof")
	var glass := colour(Color(.55,.74,.84,.16))
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.roughness = .16
	var rise: float = config.roof_ridge-config.roof_eave
	var slope := atan2(rise,6)
	for side in [-1,1]:
		var pane := box(roof,"Glass%d" % side,Vector3(sqrt(36+rise*rise),.025,12),
			Vector3(18+side*3,config.roof_eave+rise/2,15),glass)
		pane.rotation.z = -side*slope
		for z in range(9,22,2):
			var beam := box(roof,"Rafter%d" % roof.get_child_count(),Vector3(sqrt(36+rise*rise),.1,.1),
				Vector3(18+side*3,config.roof_eave+rise/2,z),metal)
			beam.rotation.z = -side*slope
		for x in [0.0,2.0,4.0,6.0]:
			box(roof,"Purlin%d" % roof.get_child_count(),Vector3(.08,.1,12),
				Vector3(18+side*x,config.roof_ridge-rise*x/6,15),metal)

func apply_to_exhibits(scene: Node3D, _layout: Dictionary) -> void:
	var bird := replace_owned_visual(scene.get_node("S1/Artifact"),"EnvironmentArt")
	var bronze := colour(Color(.36,.22,.08),.72)
	for side in [-1,1]:
		for i in 7:
			var feather := MeshInstance3D.new()
			var shape := SphereMesh.new()
			shape.radius = .05
			shape.height = .4
			shape.radial_segments = 8
			shape.rings = 4
			feather.mesh = shape
			feather.material_override = bronze
			add(bird,feather,"Feather%d" % bird.get_child_count())
			feather.position = Vector3(side*(.18+i*.055),.08+i*.015,.07)
			feather.rotation.z = side*(.45+i*.13)
			feather.scale.z = .42
	var bust := replace_owned_visual(scene.get_node("S2/Artifact"),"EnvironmentArt")
	for id in ["BustBase","Shoulders","Neck","Head"]:
		hide_legacy(scene,"S2/Artifact/"+id)
	place(bust,"Bust","exhibits/modern_abstract_bust/modern-abstract-bust.glb",
		Vector3(.58,.78,.42),Vector3(0,-.3,0))
	var watch := replace_owned_visual(scene.get_node("H2/Artifact"),"EnvironmentArt")
	for id in ["Watch","Face","HourHand","MinuteHand"]:
		hide_legacy(scene,"H2/Artifact/"+id)
	place(watch,"PocketWatch","exhibits/pocket_watch/pocket_watch_2k.gltf",
		Vector3(.4,.12,.44),Vector3(0,0,0))
	var alarm := replace_owned_visual(scene.get_node("GalleryAlarmSwitch"),"EnvironmentArt")
	place(alarm,"PowerBox","security/power_box_01/power_box_01_2k.gltf",Vector3(.6,.55,.12),Vector3(0,-.275,0))
	hide_legacy(scene,"GalleryAlarmSwitch/Panel")
	for id in ["A2","C2"]:
		apply_painting(scene.get_node(id))

func apply_painting(scene: Node3D) -> void:
	# Preserve Canvas as the script's visibility target, and preserve T2's Visual.
	var visual := scene.get_node_or_null("Visual")
	if visual == null:
		visual = scene
	var large := visual != scene
	var frame_parent: Node = visual
	if not large and scene.has_node("Frame"):
		frame_parent = scene.get_node("Frame")
		var previous := scene.get_node_or_null("EnvironmentArt")
		if previous and previous.get_meta("environment_art",false):
			previous.free()
	var frame := replace_owned_visual(frame_parent,"EnvironmentArt")
	var size := Vector3(1.54,1.18,.07) if large else Vector3(1.14,.92,.07)
	var small := str(scene.name) in ["A2","C2"]
	var fitted_frame := place(frame,"Frame","frames/hanging_picture_frame_01/hanging_picture_frame_01_2k.gltf" if small else
		"frames/fancy_picture_frame_01/fancy_picture_frame_01_2k.gltf",size,
		Vector3(0,-size.y/2,0),0,["material:hanging_picture_frame_01"] if small else ["fancy_picture_frame_01"])
	# T1's anchor is 3 cm off the wall. Keep the deeper imported frame in front
	# of its backing, rather than allowing 5 mm of stone-wall penetration.
	fitted_frame.position.z = .015
	# Legacy frame nodes remain named, but no longer render duplicate geometry.
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		if mesh.get_parent() == visual and str(mesh.name).begins_with("Frame"):
			mesh.hide()
	var old_frame := scene.get_node_or_null("Frame")
	if old_frame:
		for child in old_frame.get_children():
			if child is MeshInstance3D:
				child.hide()
	var canvas := visual.get_node_or_null("Canvas")
	if canvas is MeshInstance3D:
		var mat := colour(Color.WHITE)
		mat.albedo_texture = load(BASE+"assets/images/artworks/turner_venice/turner_venice_original.jpg")
		canvas.material_override = mat
		for child in canvas.get_children():
			if child is GeometryInstance3D:
				child.hide()
	elif canvas:
		var picture := replace_owned_visual(canvas,"EnvironmentArt")
		var image := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(.98,.76)
		image.mesh = quad
		var mat := colour(Color.WHITE)
		mat.albedo_texture = load(BASE+"assets/images/artworks/turner_venice/turner_venice_original.jpg")
		image.material_override = mat
		add(picture,image,"Artwork")
		image.position.z = .035
		for child in canvas.get_children():
			if child is GeometryInstance3D:
				child.hide()
	if large:
		for id in ["Hill","Moon"]:
			hide_legacy(visual,id)
	if canvas == null:
		var image := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(.99,.77)
		image.mesh = quad
		var mat := colour(Color.WHITE)
		mat.albedo_texture = load(BASE+"assets/images/artworks/turner_venice/turner_venice_original.jpg")
		image.material_override = mat
		add(frame,image,"Artwork")
		image.position.z = .06

func apply_to_service(scene: Node3D, _layout: Dictionary) -> void:
	var art := replace_owned_visual(scene,"EnvironmentArt")
	place(art,"Chair","furniture/dining_chair_02/dining_chair_02_2k.gltf",Vector3(.7,1.2,.7),Vector3(33.05,0,27),90)
	hide_legacy(scene,"ReceptionChair/Visual")
	hide_legacy(scene,"ChairBack")
	place(art,"ServicePlant","vegetation/potted_plant_01/potted_plant_01_2k.gltf",Vector3(.8,1.6,.8),Vector3(34.9,0,29))
	place(art,"CeilingLamp","lighting/modern_ceiling_lamp_01/modern_ceiling_lamp_01_2k.gltf",Vector3(.8,.35,.8),Vector3(32,3.8,27))
	var map_art := replace_owned_visual(scene.get_node("WallMap"),"EnvironmentArt")
	place(map_art,"MapFrame","frames/hanging_picture_frame_01/hanging_picture_frame_01_2k.gltf",
		Vector3(2.3,1.5,.1),Vector3(0,-.75,0),0,["material:hanging_picture_frame_01"])
	hide_legacy(scene,"WallMap/Frame")

func apply_to_main(scene: Node3D, _layout: Dictionary) -> void:
	var rope := scene.get_node("Interactables/Rope")
	var visual := replace_owned_visual(rope,"EnvironmentArt")
	for id in ["MeshInstance3D","Coil2","Coil3"]:
		hide_legacy(rope,id)
	place(visual,"RopeCoil","storage/rope_coil/rope-coil.glb",Vector3(.16,.65,.65),Vector3(0,-.32,0),90)
	var environment: Environment = scene.get_node("WorldEnvironment").environment.duplicate()
	environment.background_color = Color(.17,.23,.31)
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(.13,.23,.4)
	sky_material.sky_horizon_color = Color(.5,.57,.64)
	sky_material.ground_horizon_color = Color(.5,.48,.4)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_energy = .58
	scene.get_node("WorldEnvironment").environment = environment
	var sunlight := scene.get_node("DirectionalLight3D") as DirectionalLight3D
	sunlight.light_energy = .55
	sunlight.light_color = Color(1,.9,.76)

func apply_to_door(scene: Node3D, _layout: Dictionary) -> void:
	var panel := scene.get_node("Panel") as Node3D
	var art := replace_owned_visual(panel,"EnvironmentArt")
	var mesh := panel.get_node("MeshInstance3D") as MeshInstance3D
	var size: Vector3 = mesh.mesh.size
	var wood := colour(Color(.25,.14,.07))
	var brass := colour(Color(.65,.47,.17),.7)
	# Decorations inherit Panel rotation and opening state; no additional collider.
	for y in [-size.y*.22,size.y*.22]:
		for face in [-1,1]:
			var p := mesh.position+Vector3(0,y,face*(size.z/2+.015))
			box(art,"Inset%d" % art.get_child_count(),Vector3(size.x*.72,size.y*.32,.025),p,wood)
	for face in [-1,1]:
		box(art,"Handle%d" % art.get_child_count(),Vector3(.14,.055,.05),
			mesh.position+Vector3(size.x*.32,0,face*(size.z/2+.04)),brass)

func validate_clearances(geometry: Node3D) -> Array[String]:
	var errors: Array[String] = []
	var openings := [AABB(Vector3(17,.05,8.7),Vector3(2,2.45,.6)),
		AABB(Vector3(17,.05,20.7),Vector3(2,2.45,.6)),
		AABB(Vector3(11.7,.05,14),Vector3(.6,2.45,2)),
		AABB(Vector3(23.7,.05,14),Vector3(.6,2.45,2))]
	for collider in geometry.find_children("*","CollisionShape3D",true,false):
		if collider.disabled or not collider.get_parent() is StaticBody3D:
			continue
		var shape: Shape3D = collider.shape
		var bounds := AABB()
		if shape is BoxShape3D:
			bounds = AABB(-shape.size/2,shape.size)
		elif shape is CylinderShape3D:
			var size := Vector3(shape.radius*2,shape.height,shape.radius*2)
			bounds = AABB(-size/2,size)
		else:
			continue
		bounds = relative_transform(geometry,collider)*bounds
		for opening in openings:
			if bounds.intersects(opening):
				errors.append("Blocked courtyard entrance: "+str(geometry.get_path_to(collider)))
	return errors

func _record_source(source: String, pivot: Node3D) -> void:
	var canonical: String = {"derived/display_case_base.scn":"exhibits/small_museum_display_case/small_museum_display_case.glb",
		"derived/tree_small_02_far.scn":"vegetation/tree_small_02/tree_small_02_2k.gltf"}.get(source,source)
	var triangles := 0
	for instance in pivot.get_children():
		for i in instance.mesh.get_surface_count():
			var count: int = instance.mesh.surface_get_array_index_len(i)
			triangles += (count if count > 0 else instance.mesh.surface_get_array_len(i))/3
	if not sources.has(canonical):
		sources[canonical] = {"selected_triangles_total":0, "instances":0,"variants":{},
			"source_metadata": MODELS+canonical.get_base_dir()+"/source.json"}
	var key := str(triangles)+":"+str(DERIVED.get(source,source))
	if not sources[canonical].variants.has(key):
		sources[canonical].variants[key] = {"triangles":triangles,"instances":0,
			"runtime_source":MODELS+DERIVED.get(source,source)}
	sources[canonical].variants[key].instances += 1
	sources[canonical].instances += 1
	sources[canonical].selected_triangles_total += triangles

func write_manifest() -> void:
	var file := FileAccess.open(BASE+"resources/environment_art_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version":1,"sources":sources,
		"tree_lod0_instanced":false,"derived":DERIVED,
		"tree_reduction":JSON.parse_string(FileAccess.get_file_as_string(MODELS+"derived/tree_lod_manifest.json")),
		"prop_reduction":JSON.parse_string(FileAccess.get_file_as_string(MODELS+"derived/prop_lod_manifest.json")),
		"notes":["Ancestor transforms baked into VisualPivot; source files unchanged.",
		"Gothic and balustrade stone overrides; Terpsichore lit stone adaptation CC BY-SA 4.0.",
		"Fountain basin extracted without upper tiers. No automatic trimesh colliders.",
		"Trees use compact offline LOD meshes; runtime never instances original tree LOD0."]},"\t"))
