extends RefCounted

const BASE := "res://maps/isg_museum/"
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
	print("PASS: " if ok else "FAIL: ",message)

func run(host: Node) -> Array[String]:
	var tree := host.get_tree()
	var level: Node3D = load(BASE+"scenes/museum.tscn").instantiate()
	host.add_child(level)
	for i in 15: await tree.physics_frame
	var guards := []
	for node in level.get_children():
		if node is Guard:
			guards.append(node)
			node.set_physics_process(false)
			node.vision.set_physics_process(false)
			node.hearing.set_physics_process(false)
			node.agent.avoidance_enabled = false
			node.get_node("Presentation").set_process(false)
			node.velocity = Vector3.ZERO
	level.get_node("StealthDirector").set_physics_process(false)
	check(guards.size()==9,"Nine original guard actors contain skeletal visuals")
	var first = guards[0].get_node("Presentation")
	var second = guards[1].get_node("Presentation")
	check(first.skeleton != second.skeleton,"Skeleton pose instances are independent")
	var skin_ok := true
	var paths_ok := true
	var triangles := 0
	var garment_weights_ok := true
	for actor in guards:
		var p = actor.get_node("Presentation")
		check(actor.scale.is_equal_approx(Vector3.ONE) and not actor.has_node("Model/Hips"),String(actor.name)+" has unit scale and no old box model")
		check(p.skeleton.get_bone_count()==65,"65 target bones: "+actor.name)
		for mesh: MeshInstance3D in p.skeleton.get_children():
			skin_ok = skin_ok and mesh.skin != null and mesh.skin.get_bind_count()==65
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				skin_ok = skin_ok and weights.size()==arrays[Mesh.ARRAY_VERTEX].size()*4
				for v in arrays[Mesh.ARRAY_VERTEX].size():
					var sum := 0.0
					for k in 4:
						sum += weights[v*4+k]
						skin_ok = skin_ok and bones[v*4+k]>=0 and bones[v*4+k]<65 and weights[v*4+k]>=0
						if mesh.name in ["Object_6","Object_8"] and weights[v*4+k]>.001:
							var bone_name: String = p.skeleton.get_bone_name(bones[v*4+k])
							garment_weights_ok = garment_weights_ok and not ("Arm" in bone_name or "Hand" in bone_name)
					skin_ok = skin_ok and absf(sum-1)<.001
				if actor == guards[0] and mesh.mesh.surface_get_primitive_type(surface)==Mesh.PRIMITIVE_TRIANGLES:
					triangles += arrays[Mesh.ARRAY_INDEX].size()/3
		for name in p._anim.get_animation_list():
			var anim: Animation = p._anim.get_animation(name)
			for track in anim.get_track_count():
				var path := anim.track_get_path(track)
				paths_ok = paths_ok and not String(path).contains("Model/Hips") and path.get_subname_count()==1 and p.skeleton.find_bone(path.get_subname(0))>=0
	check(skin_ok,"Every rendered vertex has normalized valid weights and inverse-rest Skin binds")
	check(garment_weights_ok,"Vest and trousers cannot be pulled by nearby A-pose arms")
	check(paths_ok,"All clips resolve to target bones, no procedural object tracks")
	var original_model: Node3D = load(BASE+"assets/models/characters/low_poly_security_guard/low_poly_security_guard.glb").instantiate()
	var original_triangles := 0
	for mesh: MeshInstance3D in original_model.find_children("*","MeshInstance3D",true,false):
		for s in mesh.mesh.get_surface_count():
			if mesh.mesh.surface_get_primitive_type(s)==Mesh.PRIMITIVE_TRIANGLES:
				original_triangles += mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size()/3
	print("TRIANGLES source=",original_triangles," derived=",triangles)
	check(triangles==original_triangles and triangles>4000,"All actual imported source triangles retained; no X Bot mesh substituted")
	original_model.free()
	check(first.skeleton.get_child(0).mesh == second.skeleton.get_child(0).mesh,"Immutable skin mesh resource shared across actors")
	var fixed_pose: Transform3D = second.skeleton.get_bone_pose(8)
	first._anim.play("walk")
	first._anim.seek(.1,true)
	var start_pose: Transform3D = first.skeleton.get_bone_pose(56)
	var deformed_a := deform_vertex(first.skeleton,first.skeleton.get_child(6),0)
	first._anim.seek(.65,true)
	check(not start_pose.is_equal_approx(first.skeleton.get_bone_pose(56)),"Walk animation rotates actual knee bones")
	var deformed_b := deform_vertex(first.skeleton,first.skeleton.get_child(6),0)
	check(deformed_a.distance_to(deformed_b)>.001,"Weighted mesh vertex actually deforms with skeleton")
	check(fixed_pose.is_equal_approx(second.skeleton.get_bone_pose(8)),"Animating one guard leaves another pose unchanged")
	for name in ["walk","run"]:
		var anim: Animation = first._anim.get_animation(name)
		var root_fixed := true
		for t in anim.get_track_count():
			if anim.track_get_type(t)==Animation.TYPE_POSITION_3D and String(anim.track_get_path(t)).ends_with(":mixamorig_Hips"):
				for k in anim.track_get_key_count(t):
					var value: Vector3 = anim.track_get_key_value(t,k)
					var rest: Vector3 = first.skeleton.get_bone_rest(0).origin
					root_fixed = root_fixed and absf(value.x-rest.x)<.0001 and absf(value.z-rest.z)<.0001
		check(root_fixed,"No horizontal root drift: "+name)
	var actor: Guard = guards[0]
	var original := actor.transform
	actor.velocity = Vector3(2,0,0)
	first.current_animation = ""
	first._process(.016)
	var changes: int = first.playback_changes
	for i in 60:
		first._process(.016)
		first._anim.advance(.016)
	check(first.playback_changes==changes,"Repeated locomotion updates do not restart same clip")
	check(actor.transform.is_equal_approx(original),"Presentation never moves world actor or adds double root motion")
	check(first.choose_visual_state(GuardStateMachine.CHASE,0,&"")==&"look_around","Stopped chase observes instead of running in place")
	check(first.choose_visual_state(GuardStateMachine.CHASE,4.2,&"sleeping")==&"run","Actual chase movement overrides seated phase")
	first._anim.play("walk")
	await tree.process_frame
	var paused_time: float = first._anim.current_animation_position
	tree.paused = true
	for i in 5: await tree.process_frame
	check(is_equal_approx(paused_time,first._anim.current_animation_position),"Pause stops skeletal playback")
	tree.paused = false
	first.reset_presentation()
	check(first.current_animation=="idle" and first._transition.is_empty(),"Reset clears transition and reestablishes visual state")
	var g3 = level.get_node("Guard_G3")
	var seated = g3.get_node("Presentation")
	g3.velocity = Vector3.ZERO
	g3.go_to_sleep()
	seated.reset_presentation()
	seated._anim.advance(.3)
	var hips: Vector3 = seated.bone_position("Hips")-g3.global_position
	var knee: Vector3 = seated.bone_position("LeftLeg")-g3.global_position
	var foot: Vector3 = seated.bone_position("LeftFoot")-g3.global_position
	print("SEAT hips=",hips," knee=",knee," foot=",foot)
	check(hips.y>.4 and hips.y<.75 and foot.y>-.03 and foot.y<.22,"G3 hips rest at chair height and feet near floor")
	var anchor: Transform3D = seated.visual.global_transform
	g3.rotation.y += .6
	g3.set_phase(&"observing")
	seated._process(0)
	check(seated.visual.global_basis.is_equal_approx(anchor.basis),"Observing AI yaw does not rotate seated body away from chair")
	var sounds: int = seated.footsteps_played
	for i in 15: seated._process(.016)
	check(seated.footsteps_played==sounds,"Seated guard emits no footsteps")
	for cycle in 3:
		g3.set_phase(&"settling")
		seated._process(0)
		seated._anim.advance(2.3)
		g3.go_to_sleep()
		seated._process(0)
		seated._anim.advance(.3)
	check(seated.visual.position==Vector3.ZERO,"Repeated sit/stand cycles never accumulate root offsets")
	g3.set_phase(&"searching")
	g3.velocity = Vector3(4.2,0,0)
	seated._process(.016)
	check(seated._transition.is_empty() and seated.current_animation in ["walk","run"],"Moving G3 interrupts one-shot immediately without locking AI")
	for sound in level.find_children("*","AudioStreamPlayer3D",true,false): sound.stop()
	level.free()
	var editing: Node3D = load(BASE+"scenes/museum_editing.tscn").instantiate()
	host.add_child(editing)
	await tree.physics_frame
	var orphan_guard := false
	for sk: Skeleton3D in editing.find_children("*","Skeleton3D",true,false):
		var path := String(editing.get_path_to(sk))
		orphan_guard = orphan_guard or not (path.begins_with("NavigationRegion3D/Teammate/Visual/") or path.begins_with("NavigationRegion3D/ServiceExpansion/Receptionist/Visual/"))
	check(not orphan_guard and editing.get_tree().get_nodes_in_group("guards").is_empty(),"Editing mode removes guard actors/skins while preserving civilian NPCs")
	editing.free()
	print("Guard visual verification: %d checks, %d failures"%[checks,failures.size()])
	return failures

func deform_vertex(sk: Skeleton3D, mesh: MeshInstance3D, index: int) -> Vector3:
	sk.force_update_all_bone_transforms()
	var arrays := mesh.mesh.surface_get_arrays(0)
	var out := Vector3.ZERO
	for k in 4:
		var bone: int = arrays[Mesh.ARRAY_BONES][index*4+k]
		var weight: float = arrays[Mesh.ARRAY_WEIGHTS][index*4+k]
		out += sk.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bone)*arrays[Mesh.ARRAY_VERTEX][index]*weight
	return out

