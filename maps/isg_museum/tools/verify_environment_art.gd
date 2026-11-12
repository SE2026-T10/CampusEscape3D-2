extends "res://maps/isg_museum/tools/verify_blockout.gd"

## Additional environment checks. Existing focused suites exercise contracts,
## G3, two actual patrol loops, drawers, carrying, doors and restart end-to-end.
const Art := preload("res://maps/isg_museum/tools/environment_art_builder.gd")
const Apply := preload("res://maps/isg_museum/tools/apply_environment_art.gd")
const TreeLod := preload("res://maps/isg_museum/tools/prepare_tree_lod.gd")

func collision_signature(scene: Node3D) -> String:
	var rows: Array[String] = []
	for node in scene.find_children("*","Node3D",true,false):
		if not node is CollisionObject3D and not node is CollisionShape3D:
			continue
		var row := str(scene.get_path_to(node))+str(node.get_class())+str(Art.new().relative_transform(scene,node))
		if node is CollisionShape3D:
			row += Apply.resource_key(node.shape)+str(node.disabled)
		if node is CollisionObject3D:
			row += str(node.collision_layer)+str(node.collision_mask)
		rows.append(row)
	rows.sort()
	return "\n".join(rows).sha256_text()

func _run() -> void:
	var builder := Art.new()
	var layout := builder.load_layout()
	var column := load(Art.BASE+"scenes/art/modules/gothic_column.tscn").instantiate() as Node3D
	check(column.get_node("VisualPivot").get_child(0).material_override == Art.COURTYARD_STONE,
		"Prepared Gothic module keeps the shared textured cream stone preset")
	column.free()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Art.MODELS+"derived/tree_lod_manifest.json"))
	var fit := Transform3D.IDENTITY
	for i in manifest.levels.size():
		var lod: Dictionary = manifest.levels[i]
		var profile: Dictionary = TreeLod.lod_profiles(layout)[i]
		check(int(lod.requested_budget) == int(profile.budget),"LOD reads the configured budget: "+lod.id)
		check(lod.actual_triangles <= profile.budget*1.1,"LOD stays within its budget tolerance: "+lod.id)
		var visual := builder.prepare_visual("derived/tree_small_02_%s.scn" % lod.id,
			Vector3(4.4,5.2,4.8),0,[],null,layout.courtyard.tree)
		var scale: Vector3 = visual.get_meta("fit_scale")
		check(is_equal_approx(scale.x,scale.y) and is_equal_approx(scale.y,scale.z),"Vegetation uses uniform scale: "+lod.id)
		if i == 0:
			fit = visual.get_node("VisualPivot").transform
		check(visual.get_node("VisualPivot").transform.is_equal_approx(fit),"LOD normalization/anchor matches near: "+lod.id)
		visual.free()
	var changed := layout.duplicate(true)
	changed.quality.tree_near_triangle_budget = 32000
	check(TreeLod.lod_profiles(changed)[0].budget == 32000 and TreeLod.leaf_grid_resolution(24000,117) < TreeLod.leaf_grid_resolution(36000,117),
		"Changing JSON budget changes the generator policy and leaf tessellation")
	for id in ["museum_geometry","exhibits_expansion","service_expansion"]:
		var scene := (load(Art.BASE+"scenes/"+id+".tscn") as PackedScene).instantiate()
		var method: String = {"museum_geometry":"apply_to_geometry","exhibits_expansion":"apply_to_exhibits",
			"service_expansion":"apply_to_service"}[id]
		var saved := Apply.signature(scene)
		builder.call(method,scene,layout)
		check(saved == Apply.signature(scene),"Saved art matches authoring: "+id)
		var once := Apply.signature(scene)
		builder.call(method,scene,layout)
		check(once == Apply.signature(scene),"Second art pass preserves nodes, resources and colliders: "+id)
		if id == "museum_geometry":
			var baseline := load(Art.BASE+"docs/environment-art-v1_1/before-source/museum_geometry.tscn").instantiate() as Node3D
			check(collision_signature(baseline) == collision_signature(scene),"All collision shapes/transforms/layers match v1; no navigation rebake needed")
			baseline.free()
			var light := scene.get_node("EnvironmentArt/CourtyardLight_NW") as OmniLight3D
			check(is_equal_approx(light.light_energy,layout.lighting.courtyard.energy) and is_equal_approx(light.omni_range,layout.lighting.courtyard.range),
				"Courtyard light energy and range come from JSON")
			check(scene.get_node("EnvironmentArt/Statue0/VisualPivot").get_child(0).material_override == Art.STATUE_STONE,"Statue uses the lit textured preset")
			for batch in scene.get_node("EnvironmentArt/Arcade").get_children():
				if batch is MeshInstance3D and batch.get_meta("art_batch",false):
					check(batch.material_override == Art.COURTYARD_STONE and batch.material_override.normal_enabled,"Batch keeps detailed stone preset")
			var palette = load(Art.BASE+"tools/material_palette.gd")
			palette.apply_geometry(scene)
			builder.apply_to_geometry(scene,layout)
			check(once == Apply.signature(scene),"Palette plus art rebuild keeps materials, trees and lamps without duplication")
			var shadows := layout.duplicate(true)
			shadows.quality.shadows = false
			shadows.lighting.courtyard.shadows = true
			builder.apply_to_geometry(scene,shadows)
			check(not scene.get_node("EnvironmentArt/CourtyardLight_NW").shadow_enabled,"Quality shadow switch controls local fixtures")
		scene.free()
	var main := load(SCENE).instantiate() as Node3D
	builder.apply_to_main(main,layout)
	check(is_equal_approx(main.get_node("WorldEnvironment").environment.ambient_light_energy,layout.lighting.ambient.energy),"Ambient energy comes from JSON")
	var environment: Environment = main.get_node("WorldEnvironment").environment
	var sun := main.get_node("DirectionalLight3D") as DirectionalLight3D
	check(environment.ambient_light_color == builder.rgb(layout.lighting.ambient.color) and sun.light_color == builder.rgb(layout.lighting.sun.color)
		and is_equal_approx(sun.light_energy,layout.lighting.sun.energy)
		and environment.sky.sky_material.sky_top_color == builder.rgb(layout.lighting.sky.top),"Ambient, sun and sky colors come from JSON")
	check(main.get_node("DirectionalLight3D").shadow_enabled and main.get_node("DirectionalLight3D").rotation_degrees.is_equal_approx(builder.vec(layout.lighting.sun.rotation_degrees)),"Sun direction and directional shadows come from JSON")
	changed.lighting.ambient.energy = .27
	changed.lighting.sun.energy = .63
	changed.quality.shadows = false
	builder.apply_to_main(main,changed)
	check(is_equal_approx(main.get_node("WorldEnvironment").environment.ambient_light_energy,.27) and is_equal_approx(main.get_node("DirectionalLight3D").light_energy,.63) and not main.get_node("DirectionalLight3D").shadow_enabled,
		"Lighting edits and master shadow switch actually change generated scene")
	main.free()
	level = load(SCENE).instantiate()
	root.add_child(level)
	current_scene = level
	await frames(8)
	var flow := level.get_node("GameFlow") as GameFlow
	if flow.state == GameStateMachine.State.PAUSED:
		flow.resume()
	for guard in get_nodes_in_group("guards"):
		guard.process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("StealthDirector").set_physics_process(false)
	var player := level.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	var geometry := level.get_node("NavigationRegion3D/Geometry")
	for batch in geometry.get_node("EnvironmentArt/Arcade").get_children():
		if batch is MeshInstance3D and batch.get_meta("art_batch",false):
			var bounds: AABB = batch.transform*batch.get_aabb()
			check(bounds.size.x >= 12 and bounds.end.y > 7.4 and bounds.position.z >= 8.5,
				"Saved arcade batch retains real geometry and all instance transforms")
	check(builder.validate_clearances(geometry).is_empty(),"Offline collision bounds preserve four full-width entrances")
	var observer := level.get_node("Guard_G4")
	for i in 4:
		var p := builder.vec(layout.courtyard.statues[i])
		var pedestal := geometry.get_node("Courtyard/Planter%d" % i)
		check(pedestal.get_node("Collision").shape.size.is_equal_approx(Vector3(1.3,1.2,1.3)),
			"Pedestal visible footprint equals preserved cover collider %d" % i)
		check(not ray(p+Vector3(0,1.6,3),p+Vector3(0,.85,-1)).is_empty(),
			"Crouched player is covered from same-floor observer at pedestal %d" % i)
		check(ray(p+Vector3(0,1.7,3),p+Vector3(0,1.7,-1)).is_empty(),
			"Standing player can be seen over pedestal %d" % i)
		check(ray(p+Vector3(1.1,1.6,3),p+Vector3(1.1,.85,-1)).is_empty(),
			"Player stepping out of cover becomes exposed %d" % i)
		observer.position = p+Vector3(0,0,3)
		observer.face_yaw(0)
		player.position = p+Vector3(0,0,-1)
		player.set_crouching(true)
		player.head.position.y = player.crouch_eye_height
		await frames(3)
		check(not observer.vision._check_sight(),"Actual guard vision cannot see crouched player behind pedestal %d" % i)
		player.set_crouching(false)
		player.head.position.y = player.stand_eye_height
		await frames(3)
		check(observer.vision._check_sight(),"Actual guard vision sees standing player over pedestal %d" % i)
	for pair in [[Vector3(18,0,8),Vector3(18,0,11)], [Vector3(18,0,22),Vector3(18,0,19)],
		[Vector3(11,0,15),Vector3(14,0,15)], [Vector3(25,0,15),Vector3(22,0,15)]]:
		player.position = pair[0]
		player.velocity = Vector3.ZERO
		await frames(3)
		check(ray(pair[0]+Vector3.UP,pair[1]+Vector3.UP).is_empty(),"Entrance has no invisible wall: "+str(pair[0]))
		check(await walk(player,[pair[1]]),"Player walks through courtyard entrance: "+str(pair[0]))
	var route: Array = []
	for i in range(1,33):
		var angle := TAU*i/32
		route.append(Vector3(18+3.1*cos(angle),0,15+3.1*sin(angle)))
	player.position = Vector3(21.1,0,15)
	player.velocity = Vector3.ZERO
	check(await walk(player,route),"Player completes the full fountain ring without snagging or falling")
	check(not ray(Vector3(15,1,8),Vector3(15,1,10)).is_empty(),"Dense hedge blocks actual sight ray")
	check(ray(Vector3(18.5,5.1,8),Vector3(18.5,5.1,10)).is_empty(),"Visible balustrade gap passes sight ray")
	check(not ray(Vector3(18,5.1,8),Vector3(18,5.1,10)).is_empty(),"Stone balustrade post blocks sight ray")
	var correct_layers := true
	for body in geometry.find_children("*","CollisionObject3D",true,false):
		correct_layers = correct_layers and (body.collision_layer == 1 or body is Area3D)
	check(correct_layers,"Decoration uses world collision and never steals interaction rays")
	var statue := geometry.get_node("EnvironmentArt/Statue0/VisualPivot").get_child(0) as MeshInstance3D
	check(statue.material_override.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL,"Statues receive lighting")
	for mesh in geometry.get_node("EnvironmentArt/Roof").find_children("*","CollisionShape3D",true,false):
		check(false,"Roof must have no navigation collider: "+str(mesh.name))
	var t1 := level.get_node("Interactables/Painting_T1")
	check(t1.has_node("Frame/EnvironmentArt/Frame") and t1.has_node("Canvas") and t1.has_node("InspectionTarget"),"T1 imported frame and gameplay anchors preserved")
	var t2 := level.get_node("Interactables/Painting_T2")
	check(t2.has_node("Visual/EnvironmentArt/Frame"),"T2 frame remains inside reparented Visual")
	var t2_bounds := builder.compute_visual_bounds(t2.get_node("Visual"))
	check(t2_bounds.size.x <= 1.57 and t2_bounds.size.y <= 1.19 and t2_bounds.size.z <= .18,
		"T2 remains inside carry placement envelope")
	for id in ["S1","S2"]:
		var exhibit := level.get_node("NavigationRegion3D/ExhibitsExpansion/"+id)
		check(exhibit.has_node("Glass") and exhibit.has_node("Shards") and exhibit.has_node("Artifact"),"Independent case states: "+id)
	var source_text := FileAccess.get_file_as_string(Art.BASE+"scenes/museum_geometry.tscn")
	var has_tree_source_dependency := false
	for line in source_text.split("\n"):
		if line.begins_with("[ext_resource") and "tree_small_02_2k.gltf" in line:
			has_tree_source_dependency = true
	check(not has_tree_source_dependency,"Runtime scene has no original tree LOD0 dependency")
	for id in Apply.SCENES:
		var text := FileAccess.get_file_as_string(Art.BASE+"scenes/"+id+".tscn")
		check(not ".local/" in text and not "asset-design-preview" in text,"No authoring-only runtime dependency: "+id)
	print("Environment art verification: %d checks, %d failures" % [checks,failures])
	for sound in level.find_children("*","AudioStreamPlayer3D",true,false):
		sound.stop()
		sound.stream = null
	current_scene = null
	level.free()
	await process_frame
	quit(0 if failures == 0 else 1)
