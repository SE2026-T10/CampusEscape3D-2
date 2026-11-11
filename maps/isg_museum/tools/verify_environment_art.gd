extends "res://maps/isg_museum/tools/verify_blockout.gd"

## Additional environment checks. Existing focused suites exercise contracts,
## G3, two actual patrol loops, drawers, carrying, doors and restart end-to-end.
const Art := preload("res://maps/isg_museum/tools/environment_art_builder.gd")
const Apply := preload("res://maps/isg_museum/tools/apply_environment_art.gd")

func _run() -> void:
	var builder := Art.new()
	var layout := builder.load_layout()
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
		scene.free()
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
