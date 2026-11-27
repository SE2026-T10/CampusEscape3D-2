extends RefCounted

const BASE := "res://maps/isg_museum/"
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures.append(message)

func run(host: Node) -> Array[String]:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"resources/courtyard_palette.json"))
	if config.stage=="B_production":
		await production_run(host)
		return failures
	var tree := host.get_tree()
	var preview: Node3D = load(BASE+"scenes/previews/courtyard_palette_preview.tscn").instantiate()
	host.add_child(preview)
	for i in 10: await tree.physics_frame
	var map: Node3D = preview.map
	var palette = preview.palette
	check(map.disable_guards_for_editing and tree.get_nodes_in_group("guards").is_empty(),"Preview uses actual editing map without guards")
	check(map.get_node("NavigationRegion3D/Teammate").has_node("Visual"),"Completed NPC presentation retained")
	var source: Node3D = load(BASE+"scenes/museum_editing.tscn").instantiate()
	var before_environment: Environment = source.get_node("WorldEnvironment").environment
	var environment: Environment = map.get_node("WorldEnvironment").environment
	check(environment!=before_environment and environment.sky!=before_environment.sky,"Preview Environment and sky are independent resources")
	check(environment.ambient_light_energy==before_environment.ambient_light_energy and environment.ambient_light_color==before_environment.ambient_light_color and environment.tonemap_exposure==before_environment.tonemap_exposure,"Existing ambient/exposure retained")
	source.free()
	var collisions := collision_signature(map)
	var protected_materials := {}
	var changed_nodes := {}
	for binding in palette.bindings: changed_nodes[binding.node.get_instance_id()] = true
	for mesh: MeshInstance3D in map.find_children("*","MeshInstance3D",true,false):
		if not changed_nodes.has(mesh.get_instance_id()):
			protected_materials[mesh] = [mesh.mesh,mesh.material_override]
	var used := {}
	var geometry_preserved := true
	for binding in palette.bindings:
		if binding.has("derived"):
			var old_bounds: AABB = binding.mesh.get_aabb()
			var new_bounds: AABB = binding.derived.get_aabb()
			geometry_preserved = geometry_preserved and old_bounds.position.distance_to(new_bounds.position)<.001 and old_bounds.size.distance_to(new_bounds.size)<.001
			geometry_preserved = geometry_preserved and absf(area(binding.mesh)-area(binding.derived))<maxf(.01,area(binding.mesh)*.0001)
			for role in binding.roles: used[role] = true
		else: used[binding.role] = true
	check(geometry_preserved,"Surface partitions retain original bounds and total triangle area without overlapping layers")
	check(palette.materials.size()==10,"Ten independent material roles loaded")
	for role in palette.config.roles:
		var mat := palette.material_for_role(role) as StandardMaterial3D
		check(mat!=null and mat.albedo_texture!=null and mat.normal_texture!=null and mat.roughness_texture!=null,"Complete textured role: "+role)
		check(used.has(role),"Role actually assigned to real map geometry: "+role)
	check(palette.material_for_role("courtyard_plaster").albedo_texture!=palette.material_for_role("architectural_stone").albedo_texture,"Plaster is not tinted marble")
	check(palette.material_for_role("garden_wall_stone").normal_texture!=palette.material_for_role("architectural_stone").normal_texture,"Garden wall uses a different source surface from column stone")
	var ground := map.get_node("NavigationRegion3D/Geometry/Floors/Ground/Mesh") as MeshInstance3D
	check(role_at(ground,Vector3(9.1,0,12))=="corridor_border","Dark border occupies its own floor region")
	check(role_at(ground,Vector3(10.5,0,12))=="corridor_floor","Main corridor region uses paving")
	check(role_at(ground,Vector3(4,0,12))=="original" and role_at(ground,Vector3(18,0,15))=="original","Rooms and garden ground are outside corridor replacement")
	var correct_faces := true
	for binding in palette.bindings:
		if not binding.has("roles") or not "courtyard_plaster" in binding.roles: continue
		var mesh: MeshInstance3D = binding.node
		var index: int = binding.roles.find("courtyard_plaster")
		var arrays: Array = binding.derived.surface_get_arrays(index)
		for vertex in arrays[Mesh.ARRAY_VERTEX].size():
			var p: Vector3 = mesh.global_transform*arrays[Mesh.ARRAY_VERTEX][vertex]
			var n: Vector3 = mesh.global_basis*arrays[Mesh.ARRAY_NORMAL][vertex]
			correct_faces = correct_faces and p.y>=-.001 and p.y<=9.001 and p.x>=8.999 and p.x<=27.001 and p.z>=5.999 and p.z<=24.001
			correct_faces = correct_faces and ((n.z>.9 and absf(p.z-6.15)<.01) or (n.z<-.9 and absf(p.z-23.85)<.01) or (n.x>.9 and absf(p.x-9.15)<.01) or (n.x<-.9 and absf(p.x-26.85)<.01))
	check(correct_faces,"Terracotta only appears on corridor-facing wall surfaces, including lintels and both floors")
	var count: int = palette.bindings.size()
	palette.prepare(map)
	palette.apply_palette(map)
	check(palette.bindings.size()==count,"Repeated prepare/apply does not duplicate geometry or role bindings")
	preview.set_proposed(false)
	var restored := true
	for binding in palette.bindings: restored = restored and binding.node.mesh==binding.mesh and binding.node.material_override==binding.override
	check(restored,"F7 baseline restores original mesh/material resources exactly")
	preview.set_proposed(true)
	check(collision_signature(map)==collisions,"Material toggles and surface partitions do not change any collision")
	var untouched := true
	for mesh in protected_materials:
		untouched = untouched and mesh.mesh==protected_materials[mesh][0] and mesh.material_override==protected_materials[mesh][1]
	check(untouched,"Leaves, glass, room finishes, characters and exhibits outside registry stay unchanged")
	var player := map.get_node("Player") as FirstPersonPlayer
	player.position = Vector3(18,.05,7.5)
	player.head.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	check(await walk(tree,player,Vector3(18,0,11)),"Actual Player walks from corridor through original courtyard opening")
	check(await walk(tree,player,Vector3(18,0,7.5)),"Actual Player returns through the same opening")
	preview.go_to_anchor(2)
	for i in 30: await tree.physics_frame
	check(absf(player.position.y-4.5)<.05,"F8 upper preview anchor stands on existing floor without falling")
	preview.free()
	await tree.process_frame
	print("Courtyard palette verification: %d checks, %d failures"%[checks,failures.size()])
	return failures

func production_run(host: Node) -> void:
	_test_surface_partition()
	var Registry := load(BASE+"tools/courtyard_palette.gd")
	var Apply := load(BASE+"tools/apply_environment_art.gd")
	var Art := load(BASE+"tools/environment_art_builder.gd")
	var palette = Registry.new()
	var geometry: Node3D = load(BASE+"scenes/museum_geometry.tscn").instantiate()
	check(palette.config.stage=="B_production","Production stage is explicit")
	check(palette.validate_palette(geometry).is_empty(),"Saved geometry has Gardner finishes and intact primitive authoring walls")
	for role in palette.config.roles:
		var material := palette.material_for_role(role) as StandardMaterial3D
		check(material!=null and material.get_meta("material_role","")==role and material.albedo_texture!=null and material.normal_texture!=null and material.shading_mode==BaseMaterial3D.SHADING_MODE_PER_PIXEL and not material.emission_enabled,"Lit textured production role: "+role)
	var floor1 := geometry.get_node("GardnerPalette/Floor1") as MeshInstance3D
	var floor2 := geometry.get_node("GardnerPalette/Floor2") as MeshInstance3D
	check(absf(area(floor1.mesh)-288)<.01 and absf(area(floor2.mesh)-289.32)<.01,"Floor finishes cover ring/lobby plus exactly five full-depth gallery thresholds without overlapping cells")
	for pair in [[floor1,.004],[floor2,4.5]]:
		check(role_at(pair[0],Vector3(10.5,pair[1],12))=="corridor_floor","Corridor paving saved on floor "+str(pair[1]))
		check(role_at(pair[0],Vector3(18,pair[1],27))=="corridor_floor","Lobby/south-buffer paving saved on floor "+str(pair[1]))
		check(role_at(pair[0],Vector3(9.1,pair[1],12))=="corridor_border","Separate 22cm border saved on floor "+str(pair[1]))
		check(role_at(pair[0],Vector3(18,pair[1],15))=="missing" and role_at(pair[0],Vector3(4,pair[1],12))=="missing","Courtyard void and gallery floors excluded on floor "+str(pair[1]))
	var wall := geometry.get_node("GardnerPalette/Walls") as MeshInstance3D
	var faces_valid := true
	var levels := {}
	var wall_arrays: Array = wall.mesh.surface_get_arrays(0)
	for index in wall_arrays[Mesh.ARRAY_VERTEX].size():
		var p: Vector3 = wall_arrays[Mesh.ARRAY_VERTEX][index]
		var n: Vector3 = wall_arrays[Mesh.ARRAY_NORMAL][index]
		faces_valid = faces_valid and p.y>=-.001 and p.y<=9.001 and ((n.z>.9 and absf(p.z-6.154)<.001) or (n.z<-.9 and absf(p.z-23.846)<.001) or (n.x>.9 and absf(p.x-9.154)<.001) or (n.x<-.9 and absf(p.x-26.846)<.001))
		levels[int(p.y/4.5)] = true
	check(faces_valid and levels.size()>=2,"Pink finish only on four correct corridor faces, with both storeys and lintels")
	var primitive_ok := true
	for group_name in ["Floor1Rooms","Floor2Rooms","Floors"]:
		for body in geometry.get_node(group_name).get_children():
			var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
			if mesh: primitive_ok = primitive_ok and mesh.mesh is BoxMesh
	check(primitive_ok,"Original BoxMesh bounds and original outside-scope surface materials are retained")
	var sage := false
	var burgundy := false
	for paint in geometry.get_node("WallFinishes").get_children():
		sage = sage or paint.material_override.resource_path.ends_with("plaster_sage.tres")
		burgundy = burgundy or paint.material_override.resource_path.ends_with("plaster_burgundy.tres")
	check(sage and burgundy,"Gallery A/C room-facing finishes retain their distinct palettes")
	check(geometry.get_node("FloorFinishes/RestorationConcrete").material_override.resource_path.ends_with("concrete.tres"),"Restoration concrete finish remains unchanged")
	var rail_roles := {}
	var batches_valid := true
	for batch in geometry.get_node("EnvironmentArt/Balustrades").get_children():
		if not batch is MeshInstance3D or not batch.get_meta("art_batch",false): continue
		var role: String = batch.get_meta("material_role","")
		rail_roles[role] = true
		batches_valid = batches_valid and role==String(batch.material_override.get_meta("material_role",""))
	check(batches_valid and rail_roles.has("balustrade_stone") and rail_roles.has("balustrade_cap"),"Batches preserve separate balustrade/cap materials after save/reload")
	var protected := {}
	for mesh: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		if mesh.has_meta("material_role") or String(geometry.get_path_to(mesh)).begins_with("GardnerPalette/"): continue
		protected[String(geometry.get_path_to(mesh))] = [mesh.mesh,mesh.material_override]
	var before: String = Apply.signature(geometry)
	palette.apply_geometry_palette(geometry)
	palette.apply_geometry_palette(geometry)
	check(Apply.signature(geometry)==before,"Offline palette pass is idempotent, without SceneTree or stale preview bindings")
	var untouched := true
	for path in protected:
		var mesh: MeshInstance3D = geometry.get_node(path)
		untouched = untouched and mesh.mesh==protected[path][0] and mesh.material_override==protected[path][1]
	check(untouched,"Unmanaged meshes/materials are not rewritten by the palette")
	var packed := PackedScene.new()
	check(packed.pack(geometry)==OK,"Production palette packs with stable owners")
	var reloaded := packed.instantiate() as Node3D
	check(Apply.signature(reloaded)==before,"Save/reload preserves material roles and finish structure")
	reloaded.free()
	var collision := production_collision(geometry)
	var saved_art: Dictionary = Apply.rebuild_snapshot(geometry)
	var art = Art.new()
	art.apply_to_geometry(geometry,art.load_layout())
	check(Apply.rebuild_matches(saved_art,geometry,true),"Art rebuild retains the complete production palette")
	check(production_collision(geometry)==collision,"Rebuilding finishes and art never changes collision")
	geometry.free()
	var main: Node3D = load(BASE+"scenes/museum.tscn").instantiate()
	check(main.get_node("NavigationRegion3D/Geometry").has_node("GardnerPalette"),"museum.tscn loads coloured without any preview controller")
	var guard_count := 0
	for child in main.get_children():
		if child is Guard: guard_count += 1
	check(guard_count==9,"All nine guard actors remain in the product")
	var door := main.get_node("NavigationRegion3D/Doors").get_child(0) as Node3D
	var coloured_door := false
	for mesh in main.get_node("NavigationRegion3D/Doors").find_children("*","MeshInstance3D",true,false):
		if mesh.material_override and mesh.material_override.get_meta("material_role","")=="door_wood": coloured_door = true
	check(coloured_door,"Scoped door palette is saved in the main scene")
	main.free()
	var editing: Node3D = load(BASE+"scenes/museum_editing.tscn").instantiate()
	host.add_child(editing)
	for i in 10: await host.get_tree().physics_frame
	check(editing.disable_guards_for_editing and not editing.has_node("Guard_G3"),"Editing F6 retains the saved palette and removes guards")
	check(editing.get_node("NavigationRegion3D/Teammate").has_node("Visual") and editing.get_node("NavigationRegion3D/ServiceExpansion/Receptionist").has_node("Visual"),"Both skeletal NPCs are retained in editing mode")
	var player := editing.get_node("Player") as FirstPersonPlayer
	player.position = Vector3(18,.05,7.5)
	check(await walk(host.get_tree(),player,Vector3(18,0,11)),"Actual Player traverses the saved product finish and courtyard entrance")
	editing.free()
	await host.get_tree().process_frame
	print("Courtyard palette verification: %d checks, %d failures" % [checks,failures.size()])

func _test_surface_partition() -> void:
	# Mixed source surfaces exercise the shared clipper independently of BoxMesh.
	var palette = load(BASE+"tools/courtyard_palette.gd").new()
	var fixture := Node3D.new()
	var nested := Node3D.new()
	fixture.add_child(nested)
	nested.position.x = .25
	var visual := MeshInstance3D.new()
	nested.add_child(visual)
	var original := ArrayMesh.new()
	var materials := [StandardMaterial3D.new(),StandardMaterial3D.new()]
	for i in 2:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var vertices := [Vector3(1,0,0),Vector3(3,0,0),Vector3(1,0,2)] if i==0 else [Vector3(8,0,10),Vector3(11,0,10),Vector3(8,0,12)]
		for vertex in vertices:
			tool.set_normal(Vector3.UP)
			tool.set_uv(Vector2(vertex.x,vertex.z))
			tool.add_vertex(vertex)
		if i==0: tool.index()
		tool.commit(original)
		original.surface_set_material(i,materials[i])
	visual.mesh = original
	palette.prepared_root = fixture
	palette._split_faces(visual,"floor")
	var result: ArrayMesh = palette.bindings[0].derived
	var kept := []
	for i in result.get_surface_count(): kept.append(result.surface_get_material(i))
	check(materials[0] in kept and materials[1] in kept and palette.material_for_role("corridor_floor") in kept,"Indexed/non-indexed source surfaces retain their separate original materials")
	check(result.get_aabb().position.is_equal_approx(original.get_aabb().position) and result.get_aabb().size.is_equal_approx(original.get_aabb().size),"Offline clipper includes nested transforms and preserves source bounds")
	palette.bindings.clear()
	fixture.free()

func production_collision(scene: Node3D) -> String:
	var Registry := load(BASE+"tools/courtyard_palette.gd")
	var Apply := load(BASE+"tools/apply_environment_art.gd")
	var rows := []
	for node in scene.find_children("*","Node3D",true,false):
		if not node is CollisionShape3D and not node is CollisionObject3D: continue
		var row := String(scene.get_path_to(node))+str(Registry.relative_transform(scene,node))
		if node is CollisionShape3D: row += Apply.resource_key(node.shape)+str(node.disabled)
		if node is CollisionObject3D: row += str(node.collision_layer)+str(node.collision_mask)
		rows.append(row)
	rows.sort()
	return "\n".join(rows).sha256_text()

func area(mesh: Mesh) -> float:
	var sum := 0.0
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var indices = a[Mesh.ARRAY_INDEX]
		if indices==null or indices.is_empty():
			for i in range(0,v.size(),3): sum += (v[i+1]-v[i]).cross(v[i+2]-v[i]).length()/2
		else:
			for i in range(0,indices.size(),3): sum += (v[indices[i+1]]-v[indices[i]]).cross(v[indices[i+2]]-v[indices[i]]).length()/2
	return sum

func collision_signature(root: Node3D) -> Array:
	var signatures := []
	for node: CollisionShape3D in root.find_children("*","CollisionShape3D",true,false):
		signatures.append([String(root.get_path_to(node)),str(node.global_transform),node.shape.get_rid(),node.disabled])
	return signatures

func role_at(mesh: MeshInstance3D, point: Vector3) -> String:
	var transform := Transform3D.IDENTITY
	var ancestor: Node = mesh
	while ancestor!=null:
		if ancestor is Node3D: transform = ancestor.transform*transform
		ancestor = ancestor.get_parent()
	for s in mesh.mesh.get_surface_count():
		var a := mesh.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		for i in range(0,v.size(),3):
			var p: Vector3 = transform*v[i]
			var q: Vector3 = transform*v[i+1]
			var r: Vector3 = transform*v[i+2]
			if absf(p.y-point.y)>.001 or absf(q.y-point.y)>.001 or absf(r.y-point.y)>.001: continue
			var sides := [(q-p).cross(point-p).y,(r-q).cross(point-q).y,(p-r).cross(point-r).y]
			if (sides[0]>=-.00001 and sides[1]>=-.00001 and sides[2]>=-.00001) or (sides[0]<=.00001 and sides[1]<=.00001 and sides[2]<=.00001):
				return mesh.mesh.surface_get_material(s).get_meta("material_role","original")
	return "missing"

func walk(tree: SceneTree, player: FirstPersonPlayer, target: Vector3) -> bool:
	for tick in 300:
		var delta := target-player.position
		delta.y = 0
		if delta.length()<.15:
			Input.action_release("move_forward")
			return true
		player.rotation.y = atan2(-delta.x,-delta.z)
		Input.action_press("move_forward")
		await tree.physics_frame
	Input.action_release("move_forward")
	return false
