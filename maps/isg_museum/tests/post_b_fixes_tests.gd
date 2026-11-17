extends RefCounted

const BASE := "res://maps/isg_museum/"
const Registry := preload("res://maps/isg_museum/tools/courtyard_palette.gd")
const Apply := preload("res://maps/isg_museum/tools/apply_environment_art.gd")
const Art := preload("res://maps/isg_museum/tools/environment_art_builder.gd")
var checks := 0
var failures: Array[String] = []
var teardown_samples: Array[Dictionary] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)

func frames(tree: SceneTree, n: int) -> void:
	for i in n: await tree.physics_frame

func collision_rows(scene: Node3D) -> Dictionary:
	var result := {}
	for node in scene.find_children("*","Node3D",true,false):
		if not node is CollisionShape3D and not node is CollisionObject3D: continue
		var row := node.get_class()+str(Registry.relative_transform(scene,node))
		if node is CollisionShape3D: row += Apply.resource_key(node.shape)+str(node.disabled)
		if node is CollisionObject3D: row += str(node.collision_layer)+str(node.collision_mask)
		result[String(scene.get_path_to(node))] = row
	return result

func run(host: Node) -> Array[String]:
	var tree := host.get_tree()
	var geometry: Node3D = load(BASE+"scenes/museum_geometry.tscn").instantiate()
	var baseline: Node3D = load(BASE+"docs/reports/post-b-fixes-v1/snapshots/before-source/museum_geometry.tscn").instantiate()
	var old := collision_rows(baseline)
	var current := collision_rows(geometry)
	var preserved := true
	for path in old: preserved = preserved and current.get(path,"")==old[path]
	check(preserved,"Every pre-fix body/shape keeps its exact path, transform, layer and shape")
	var extra := 0
	var additions_valid := true
	for path in current:
		if old.has(path): continue
		extra += 1
		var node := geometry.get_node(path)
		var body := node if node is StaticBody3D else node.get_parent()
		additions_valid = additions_valid and body is StaticBody3D and body.get_meta("arch_spandrel_collision",false)
		additions_valid = additions_valid and String(path).begins_with("EnvironmentArt/Arcade/") and ("/Spandrel/World" in path or "/SpandrelCorner" in path)
	check(additions_valid and extra==104,"Exactly 48 new masonry bodies and 56 shapes are permitted; no other collision additions")
	check(Art.new().validate_arcade_joints(geometry.get_node("EnvironmentArt/Arcade")).is_empty(),"Original columns, spring points and arch joints remain aligned")
	var role_count := 0
	for node in geometry.get_node("EnvironmentArt/Arcade").get_children():
		if not node is MeshInstance3D or not node.get_meta("art_batch",false): continue
		if node.material_override.get_meta("material_role","")=="courtyard_plaster": role_count += 1
	check(role_count==1,"All spandrel plaster is batched separately from ivory ribbons")
	var welded_joints := true
	for batch in geometry.get_node("EnvironmentArt/Arcade").get_children():
		if not batch is MeshInstance3D or batch.get_meta("material_role","")!="courtyard_plaster": continue
		var vertices: PackedVector3Array = batch.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for axis in [0,2]:
			for joint in ([14.5,16.72,19.28,21.5] if axis==0 else [11.5,13.72,16.28,18.5]):
				var coordinates := {}
				for point in vertices:
					if absf(point[axis]-joint)<.00002: coordinates["%.10f" % point[axis]] = true
				welded_joints = welded_joints and coordinates.size()==1
	check(welded_joints,"Transformed, batched and reloaded masonry bays meet at identical horizontal coordinates")
	var palette := Registry.new()
	var thresholds := palette.threshold_bounds(geometry)
	check(thresholds.size()==5,"Five thresholds come from the actual A/B/C lintel bounds")
	var single_surface := true
	var level := true
	for portal in portal_data():
		for offset in [-.30,-.08,.08,.30]:
			var at: Vector3 = portal.center+portal.normal*offset+portal.normal.cross(Vector3.UP)*.137
			var hits := visible_floor_hits(geometry,at)
			single_surface = single_surface and hits.size()==1
			if hits.size()==1: level = level and absf(hits[0]-4.5)<.0001
	check(single_surface,"Both sides and full depth of every gallery threshold have one visible floor surface")
	check(level,"Wood, stone and thresholds share the physical upper-floor height without a visual step")
	var source_bounds_kept := true
	for body in geometry.get_node("Floors").get_children():
		var source := body.get_node("Mesh") as MeshInstance3D
		source_bounds_kept = source_bounds_kept and source.mesh is BoxMesh
		if source.get_meta("floor_partition_hidden",false):
			var shell := geometry.get_node("GardnerPalette/UpperFloorShells/"+String(body.name)) as MeshInstance3D
			var source_box: AABB = Registry.relative_transform(geometry,source)*source.get_aabb()
			var shell_box: AABB = Registry.relative_transform(geometry,shell)*shell.get_aabb()
			source_bounds_kept = source_bounds_kept and not source.visible and source_box.position.distance_to(shell_box.position)<.001 and source_box.size.distance_to(shell_box.size)<.001
	check(source_bounds_kept,"Primitive slab bounds, underside and side faces survive top-face partitioning")
	var cores_valid := true
	for core in geometry.get_node("EnvironmentArt/Arcade").find_children("MasonryCore","CollisionShape3D",true,false):
		var at: Transform3D = Registry.relative_transform(geometry,core)
		var base_y := 0.0 if at.origin.y<4.5 else 4.5
		cores_valid = cores_valid and core.shape.size.x<=.301 and core.shape.size.z<=.301 and at.origin.y-core.shape.size.y/2>=base_y+3.549
	check(cores_valid,"Numerical corner seals stay strictly inside the visible masonry, above every opening")
	var navigation := load(BASE+"resources/museum_navigation.tres") as NavigationMesh
	var baseline_navigation := load(BASE+"docs/reports/post-b-fixes-v1/snapshots/before-source/museum_navigation.tres") as NavigationMesh
	var old_max_y := -INF
	for vertex in baseline_navigation.vertices: old_max_y = maxf(old_max_y,vertex.y)
	var nav_valid := true
	for vertex in navigation.vertices:
		nav_valid = nav_valid and vertex.y<=old_max_y+.001
		if vertex.y>4: nav_valid = nav_valid and not (vertex.x>12.2 and vertex.x<23.8 and vertex.z>9.2 and vertex.z<20.8)
	check(nav_valid,"Rebaked navigation has no roof/spandrel walks or upper courtyard surface")
	baseline.free()
	geometry.free()
	for id in ["museum_door","entrance_door"]:
		var door: Node3D = load(BASE+"scenes/"+id+".tscn").instantiate()
		var counts := {"door_wood":0,"door_trim":0,"door_brass":0}
		var lit := true
		var visible := 0
		for mesh in door.get_node("Panel").find_children("*","MeshInstance3D",true,false):
			var role: String = mesh.get_meta("material_role","")
			if counts.has(role) and not mesh.get_meta("art_batch",false): counts[role] += 1
			if Registry.visible_in_hierarchy(mesh,door): visible += 1
			var material := mesh.get_active_material(0) as StandardMaterial3D
			lit = lit and material!=null and material.shading_mode==BaseMaterial3D.SHADING_MODE_PER_PIXEL and not material.emission_enabled
		check(lit and counts.door_wood==5 and counts.door_trim==16 and counts.door_brass==6,"Both door faces have lit wood, sixteen trim bars, two lock plates and four handle pieces: "+id)
		check(visible==4,"Door detail batches render with body plus three role meshes: "+id)
		check(door.get_node("Panel/EnvironmentArt").find_children("*","CollisionShape3D",true,false).is_empty(),"Door trim/handles add no collision: "+id)
		var before := Apply.signature(door)
		load(BASE+"tools/material_palette.gd").apply_door(door)
		Art.new().apply_to_door(door,Art.new().load_layout())
		check(Apply.signature(door)==before,"Door material/art rebuild preserves functional roles: "+id)
		door.free()
	var map: Node3D = load(BASE+"scenes/museum_editing.tscn").instantiate()
	host.add_child(map)
	await frames(tree,12)
	var player := map.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	var physics := map.get_world_3d().direct_space_state
	var blocked := 0
	var open := 0
	for arch in map.get_node("NavigationRegion3D/Geometry/EnvironmentArt/Arcade").get_children():
		if not String(arch.name).begins_with("Arch"): continue
		var fill := arch.get_node("Spandrel")
		var profile: Array = fill.get_meta("outer_profile")
		var top: float = fill.get_meta("top_y")
		var sample: Vector3 = profile[profile.size()/4]
		var normal: Vector3 = arch.global_basis.z
		if normal.dot(Vector3(18,0,15)-arch.global_position)<0: normal = -normal
		var at: Vector3 = arch.global_transform*Vector3(sample.x,(sample.y+top)/2,0)
		var hit := physics.intersect_ray(PhysicsRayQueryParameters3D.create(at+normal*.7,at-normal*.7,1))
		if not hit.is_empty() and hit.collider.get_meta("arch_spandrel_collision",false): blocked += 1
		at = arch.global_transform*Vector3(sample.x,sample.y-.35,0)
		if physics.intersect_ray(PhysicsRayQueryParameters3D.create(at+normal*.7,at-normal*.7,1)).is_empty(): open += 1
	check(blocked==40,"Actual world sight rays hit new plaster in all forty bays on both floors")
	check(open==40,"The opening below every curved ribbon remains ray-open")
	var corners_blocked := 0
	for base_y in [0.0,4.5]:
		for corner in [Vector3(12,0,9),Vector3(24,0,9),Vector3(12,0,21),Vector3(24,0,21)]:
			var normal: Vector3 = (Vector3(18,0,15)-corner).normalized()
			for height in [3.7,4.0]:
				var at: Vector3 = corner+Vector3.UP*(base_y+height)
				var hit := physics.intersect_ray(PhysicsRayQueryParameters3D.create(at+normal*.7,at-normal*.7,1))
				if not hit.is_empty() and hit.collider.get_meta("arch_spandrel_collision",false): corners_blocked += 1
	check(corners_blocked==16,"Low/high diagonal corner rays see closed miter joints on both floors")
	map.get_node("Interactables/Key").interact(player)
	var door := map.get_node("NavigationRegion3D/Doors/GalleryB")
	check(door.interact(player) and door.is_open and door.get_node("Panel").collision_layer==0 and door.get_node("Passage").enabled,"K opens B with unchanged collision/link behavior")
	var walks := true
	for portal in portal_data():
		player.position = portal.center-portal.normal*.9+Vector3.UP*.05
		player.velocity = Vector3.ZERO
		walks = await walk(tree,player,portal.center+portal.normal*.9) and walks
		player.set_crouching(true)
		walks = await walk(tree,player,portal.center-portal.normal*.9) and walks
		player.set_crouching(false)
	check(walks,"Actual standing/crouched Player crosses all five gallery openings in both directions")
	player.position = Vector3(27,4.5,10)
	await frames(tree,3)
	check(not door.interact(player) and door.is_open,"Occupied B doorway still refuses to close")
	player.position = Vector3(25,4.5,10)
	await frames(tree,3)
	check(door.interact(player) and not door.is_open and door.get_node("Panel").collision_layer==1 and not door.get_node("Passage").enabled,"Clear B doorway closes and restores its world body/link")
	await _free_fixture(tree,map)
	var gameplay: Node3D = load(BASE+"scenes/museum.tscn").instantiate()
	host.add_child(gameplay)
	await frames(tree,12)
	gameplay.get_node("StealthDirector").set_physics_process(false)
	var player_actor := gameplay.get_node("Player") as FirstPersonPlayer
	player_actor.set_physics_process(false)
	player_actor.get_node("Noise").set_physics_process(false)
	for child in gameplay.get_children():
		if child is Guard:
			child.set_physics_process(false)
			child.vision.set_physics_process(false)
			child.hearing.set_physics_process(false)
			child.agent.avoidance_enabled = false
	gameplay.get_node("Interactables/Key").interact(player_actor)
	gameplay.get_node("NavigationRegion3D/Doors/GalleryB").interact(player_actor)
	await frames(tree,10)
	var guard := gameplay.get_node("Guard_G4") as Guard
	guard.machine.current = GuardStateMachine.NONE
	for portal in portal_data():
		guard.position = portal.center-portal.normal*1.5+Vector3.UP*.05
		guard.velocity = Vector3.ZERO
		guard.set_physics_process(true)
		var reached_both := true
		for target in [portal.center+portal.normal*1.5,portal.center-portal.normal*1.5]:
			guard.navigate_to(target,guard.patrol_speed)
			var reached := false
			for tick in 300:
				await tree.physics_frame
				if guard.position.distance_to(target)<.6:
					reached = true
					break
			if not reached: print("Guard threshold diagnostic: ",guard.position," -> ",target," navigating=",guard._navigating)
			reached_both = reached_both and reached
		check(reached_both,"Real guard navigation crosses gallery threshold in both directions: "+str(portal.center))
		guard.set_physics_process(false)
	await _free_fixture(tree,gameplay)
	print("Post-B fixes verification: %d checks, %d failures" % [checks,failures.size()])
	return failures

func _free_fixture(tree: SceneTree, fixture: Node) -> void:
	# Physics-only freezing leaves presentation audio alive. Stop it explicitly
	# before disposing the fixture; the audio thread owns playback until a mix.
	fixture.process_mode = Node.PROCESS_MODE_DISABLED
	var stopped := 0
	for node in fixture.find_children("*","Node",true,false):
		if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
			node.stop()
			node.stream = null
			stopped += 1
	fixture.free()
	await tree.process_frame
	var previous := AudioServer.get_time_since_last_mix()
	var mixes := 0
	var started := Time.get_ticks_msec()
	var deadline := started+250
	while mixes<2 and Time.get_ticks_msec()<deadline:
		await tree.process_frame
		var current := AudioServer.get_time_since_last_mix()
		if current<previous: mixes += 1
		previous = current
	teardown_samples.append({"audio_players_stopped":stopped,"mixes_observed":mixes,"elapsed_wall_ms":Time.get_ticks_msec()-started})
	print("Fixture audio teardown: ",teardown_samples[-1])

func portal_data() -> Array[Dictionary]:
	return [{"center":Vector3(9,4.5,9),"normal":Vector3.RIGHT},{"center":Vector3(9,4.5,19),"normal":Vector3.RIGHT},
		{"center":Vector3(27,4.5,10),"normal":Vector3.LEFT},{"center":Vector3(15,4.5,6),"normal":Vector3.BACK},{"center":Vector3(23,4.5,6),"normal":Vector3.BACK}]

func visible_floor_hits(geometry: Node3D, point: Vector3) -> Array:
	var hits := []
	for group_name in ["Floors","Floor1Rooms","FloorFinishes","GardnerPalette"]:
		for mesh: MeshInstance3D in geometry.get_node(group_name).find_children("*","MeshInstance3D",true,false):
			if not Registry.visible_in_hierarchy(mesh,geometry): continue
			var transform := Registry.relative_transform(geometry,mesh)
			for surface in mesh.mesh.get_surface_count():
				var found := false
				var height := 0.0
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
				if indices.is_empty(): indices = PackedInt32Array(range(vertices.size()))
				for i in range(0,indices.size(),3):
					if (transform.basis*normals[indices[i]]).y<.9: continue
					var a: Vector3 = transform*vertices[indices[i]]
					var b: Vector3 = transform*vertices[indices[i+1]]
					var c: Vector3 = transform*vertices[indices[i+2]]
					if absf(a.y-4.5)>.01 or absf(b.y-4.5)>.01 or absf(c.y-4.5)>.01: continue
					var signs := [(b-a).cross(point-a).y,(c-b).cross(point-b).y,(a-c).cross(point-c).y]
					if (signs[0]>=-.00001 and signs[1]>=-.00001 and signs[2]>=-.00001) or (signs[0]<=.00001 and signs[1]<=.00001 and signs[2]<=.00001):
						found = true
						height = a.y
				if found: hits.append(height)
	return hits

func walk(tree: SceneTree, player: FirstPersonPlayer, target: Vector3) -> bool:
	player.set_physics_process(true)
	for tick in 300:
		var offset := target-player.position
		offset.y = 0
		if offset.length()<.15:
			Input.action_release("move_forward")
			player.set_physics_process(false)
			return absf(player.position.y-target.y)<.1
		player.rotation.y = atan2(-offset.x,-offset.z)
		Input.action_press("move_forward")
		await tree.physics_frame
	Input.action_release("move_forward")
	player.set_physics_process(false)
	return false
