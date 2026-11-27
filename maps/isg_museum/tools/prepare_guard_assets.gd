extends SceneTree

## Offline geometric skin binding and rest-aware Mixamo conversion. No runtime FBX.
const BASE := "res://maps/isg_museum/"
const SOURCE := BASE+"assets/models/characters/low_poly_security_guard/low_poly_security_guard.glb"
const RIG := BASE+"assets/models/characters/low_poly_security_guard/derived/guard_rig.tscn"
const CLIPS := BASE+"assets/animations/mixamo/"
const LIBRARY := CLIPS+"derived/guard_animations.res"
const VISUAL := BASE+"scenes/npc/museum_guard_visual.tscn"
const MANIFEST := BASE+"resources/guard_animation_manifest.json"
const NAMES := ["idle","walk","run","look_around","sitting_idle","sit_down","stand_up"]
var target: Skeleton3D
var reference: Skeleton3D
var bind_a: Array[Transform3D] = []
var bind_t: Array[Transform3D] = []
var errors: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func find_type(node: Node, type: String) -> Node:
	if node.is_class(type): return node
	for child in node.get_children():
		var result := find_type(child,type)
		if result: return result
	return null

func run() -> void:
	if "--check" in OS.get_cmdline_user_args():
		validate()
		quit(0 if errors.is_empty() else 1)
		return
	var ref: Node3D = load(CLIPS+"reference/reference_tpose.fbx").instantiate()
	root.add_child(ref)
	reference = find_type(ref,"Skeleton3D")
	var rig := Node3D.new()
	rig.name = "GuardRig"
	target = Skeleton3D.new()
	target.name = "Skeleton3D"
	rig.add_child(target)
	target.owner = rig
	build_skeleton()
	var source: Node3D = load(SOURCE).instantiate()
	root.add_child(source)
	var skin := target.create_skin_from_rest_transforms()
	for mesh: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
		var derived := bind_mesh(mesh)
		var visual := MeshInstance3D.new()
		visual.name = mesh.name
		visual.mesh = derived
		visual.skin = skin
		target.add_child(visual)
		visual.skeleton = NodePath("..")
		visual.owner = rig
		visual.custom_aabb = AABB(Vector3(-1.5,-.3,-1),Vector3(3,2.8,2))
	save_scene(rig,RIG)
	var library := AnimationLibrary.new()
	var clips := []
	for name in NAMES:
		var clip_root: Node3D = load(CLIPS+"clips/guard_"+name+".fbx").instantiate()
		root.add_child(clip_root)
		var player: AnimationPlayer = find_type(clip_root,"AnimationPlayer")
		var source_skeleton: Skeleton3D = find_type(clip_root,"Skeleton3D")
		var take := "mixamo_com"
		var original := player.get_animation(take)
		if original == null:
			take = String(player.get_animation_list()[0])
			original = player.get_animation(take)
		var anim := convert_clip(original,source_skeleton,name)
		library.add_animation(name,anim)
		var travel := root_travel(original)
		var measured_speed := measure_stance_speed(anim) if name in ["walk","run"] else 0.0
		clips.append({"name":name,"source":"clips/guard_"+name+".fbx","take":take,"sha256":FileAccess.get_sha256(CLIPS+"clips/guard_"+name+".fbx"),
			"loop":anim.loop_mode != Animation.LOOP_NONE,"duration":anim.length,
			"reference_speed":measured_speed,"source_travel":travel,
			"speed_method":"median horizontal foot velocity during low stance, sampled on target skeleton at 120 Hz" if measured_speed>0 else "stationary",
			"root_motion":"XZ ground trajectory removed; hips height retained; local positions rest-adjusted"})
		clip_root.free()
	var sleep := library.get_animation("sitting_idle").duplicate(true) as Animation
	sleep.length = 6.4
	for i in sleep.get_track_count():
		if sleep.track_get_type(i) != Animation.TYPE_ROTATION_3D: continue
		var bone := String(sleep.track_get_path(i).get_subname(0))
		if bone not in ["mixamorig_Head","mixamorig_Spine2"]: continue
		for k in sleep.track_get_key_count(i):
			var q: Quaternion = sleep.track_get_key_value(i,k)
			var t := sleep.track_get_key_time(i,k)
			var angle := (.30 if bone.ends_with("Head") else .10)+.025*sin(TAU*t/sleep.length)
			sleep.track_set_key_value(i,k,q*Quaternion(Vector3.RIGHT,angle))
	library.add_animation("sleep",sleep)
	var reset := Animation.new()
	reset.length = .1
	for i in target.get_bone_count():
		for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D]:
			var track := reset.add_track(type)
			reset.track_set_path(track,NodePath("VisualPivot/GuardRig/Skeleton3D:"+target.get_bone_name(i)))
			reset.track_insert_key(track,0,target.get_bone_rest(i).origin if type == Animation.TYPE_POSITION_3D else target.get_bone_rest(i).basis.get_rotation_quaternion())
	library.add_animation("RESET",reset)
	ResourceSaver.save(library,LIBRARY)
	build_visual(library)
	build_actor()
	var data := {"schema_version":1,"engine":Engine.get_version_info().string,"tool":"prepare_guard_assets.gd",
		"source":SOURCE,"source_sha256":FileAccess.get_sha256(SOURCE),"rig":RIG,"visual":VISUAL,
		"library":LIBRARY,"bones":65,"height":1.78,"triangles":4776,"line_segments":2,
		"binding":"A-pose landmarks; segment-distance smooth weights; baked A-to-T rest conversion; inverse global-rest skin binds",
		"retarget":"Same hierarchy and global axes; source local rest quaternion delta applied to target local rest; translations length-adjusted",
		"front":"source +Z, VisualPivot yaw 180, actor -Z","blend_seconds":.2,
		"seat":{"hips_height":.49,"foot_height":.076,"yaw_anchor":"actor._seat_yaw","forward_offset":0.0},
		"clips":clips,"sleep":{"source":"sitting_idle","loop":true,"duration":6.4,"head_nod_radians":.30,"spine_nod_radians":.10},
		"attribution":"Low poly security guard by Jose Manuel, CC BY 4.0; Mixamo clips under Adobe Mixamo terms"}
	var manifest_file := FileAccess.open(MANIFEST,FileAccess.WRITE)
	manifest_file.store_string(JSON.stringify(data,"\t")+"\n")
	manifest_file.close() # Flush before the same process validates the saved JSON.
	source.free()
	ref.free()
	rig.free()
	validate()
	quit(0 if errors.is_empty() else 1)

func build_skeleton() -> void:
	# Anatomical landmarks measured on the normalized source A-pose, in metres.
	for i in reference.get_bone_count():
		var name := reference.get_bone_name(i)
		target.add_bone(name)
		target.set_bone_parent(i,reference.get_bone_parent(i))
		var t := reference.get_bone_global_rest(i)
		t.origin *= .95
		t.origin.y -= .09
		var short := name.replace("mixamorig_","")
		var heights := {"Hips":.89,"Spine":1.03,"Spine1":1.13,"Spine2":1.24,"Neck":1.47,"Head":1.57,"HeadTop_End":1.77}
		if short in heights: t.origin.y = heights[short]
		for side in ["Left","Right"]:
			var sign_x := 1.0 if side == "Left" else -1.0
			if short == side+"Shoulder": t.origin = Vector3(sign_x*.05,1.43,0)
			if short == side+"Arm": t.origin = Vector3(sign_x*.17,1.43,0)
			if short == side+"ForeArm": t.origin = Vector3(sign_x*.50,1.43,0)
			if short.begins_with(side+"Hand"):
				t.origin = Vector3(sign_x*.80,1.43,0)+(reference.get_bone_global_rest(i).origin-reference.get_bone_global_rest(reference.find_bone("mixamorig_"+side+"Hand")).origin)*.8
			if short == side+"UpLeg": t.origin = Vector3(sign_x*.105,.86,0)
			if short == side+"Leg": t.origin = Vector3(sign_x*.11,.46,.01)
			if short == side+"Foot": t.origin = Vector3(sign_x*.11,.09,-.025)
			if short == side+"ToeBase": t.origin = Vector3(sign_x*.11,.04,.10)
			if short == side+"Toe_End": t.origin = Vector3(sign_x*.11,.04,.19)
		bind_t.append(t)
		var a := t
		for side in ["Left","Right"]:
			if short.begins_with(side) and not short.ends_with("Shoulder") and ("Arm" in short or "Hand" in short):
				var sign_x := 1.0 if side == "Left" else -1.0
				var rotation := Basis(Vector3.FORWARD,deg_to_rad(72)*sign_x)
				var shoulder := Vector3(.17*sign_x,1.43,0)
				a = Transform3D(rotation*t.basis,shoulder+rotation*(t.origin-shoulder))
		bind_a.append(a)
		var parent := target.get_bone_parent(i)
		target.set_bone_rest(i,bind_t[parent].affine_inverse()*t if parent >= 0 else t)
	target.reset_bone_poses()

func weights(v: Vector3, object_name: String) -> Dictionary:
	if object_name == "Object_3" or v.y > 1.53: return {target.find_bone("mixamorig_Head"):1.0}
	if object_name in ["Object_9","Object_10"]: return {target.find_bone("mixamorig_RightHand"):1.0}
	var candidates: Array[String] = []
	# Garments must not bind across nearby limbs in the source A-pose: the
	# forearms sit close to the waist, but cannot pull the vest/trouser surface.
	if object_name == "Object_4" and v.y > .78:
		return {target.find_bone("mixamorig_Hips"):1.0}
	if object_name == "Object_8" or (v.y < .88 and absf(v.x) < .26):
		var side := "Left" if v.x >= 0 else "Right"
		candidates = ["Hips",side+"UpLeg",side+"Leg",side+"Foot"]
	else:
		candidates = ["Hips","Spine","Spine1","Spine2","Neck","Head"]
		if object_name != "Object_6" and absf(v.x) > .205:
			var side := "Left" if v.x >= 0 else "Right"
			candidates.append_array([side+"Arm",side+"ForeArm",side+"Hand"])
	var ranked := []
	for name in candidates:
		var i := target.find_bone("mixamorig_"+name)
		var end := bind_a[i].origin+Vector3.UP*.12
		for c in target.get_bone_children(i):
			end = bind_a[c].origin
			break
		var nearest := Geometry3D.get_closest_point_to_segment(v,bind_a[i].origin,end)
		ranked.append([i,v.distance_to(nearest)])
	ranked.sort_custom(func(a,b): return a[1] < b[1])
	var result := {}
	var total := 0.0
	for k in mini(3,ranked.size()):
		var w := 1.0/pow(maxf(ranked[k][1],.018),6)
		result[ranked[k][0]] = w
		total += w
	for i in result: result[i] /= total
	return result

func bind_mesh(source: MeshInstance3D) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for s in source.mesh.get_surface_count():
		var arrays := source.mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals := PackedVector3Array()
		if arrays[Mesh.ARRAY_NORMAL] != null:
			normals = arrays[Mesh.ARRAY_NORMAL]
		else:
			normals.resize(vertices.size())
			normals.fill(Vector3.UP)
		var bones := PackedInt32Array()
		var influence := PackedFloat32Array()
		for i in vertices.size():
			var v: Vector3 = source.global_transform*vertices[i]
			v = (v+Vector3(0,.967602,0))*(1.78/1.910836)
			var normal: Vector3 = source.global_basis*normals[i]
			var ws := weights(v,String(source.name))
			var point := Vector3.ZERO
			var direction := Vector3.ZERO
			for b in ws:
				var transform := bind_t[b]*bind_a[b].affine_inverse()
				point += (transform*v)*ws[b]
				direction += (transform.basis*normal)*ws[b]
				bones.append(b)
				influence.append(ws[b])
			for unused in 4-ws.size():
				bones.append(0)
				influence.append(0)
			vertices[i] = point
			normals[i] = direction.normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = null # Source has flat colours; stale A-pose tangents must not survive.
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = influence
		mesh.add_surface_from_arrays(source.mesh.surface_get_primitive_type(s),arrays)
		mesh.surface_set_material(s,source.mesh.surface_get_material(s))
	return mesh

func root_travel(anim: Animation) -> float:
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_POSITION_3D and String(anim.track_get_path(i)).ends_with(":mixamorig_Hips"):
			var first: Vector3 = anim.track_get_key_value(i,0)
			var last: Vector3 = anim.track_get_key_value(i,anim.track_get_key_count(i)-1)
			return Vector2(last.x-first.x,last.z-first.z).length()
	return 0.0

func measure_stance_speed(anim: Animation) -> float:
	var samples := []
	var lowest := INF
	var frames := ceili(anim.length*120)
	for frame in frames+1:
		target.reset_bone_poses()
		var time := minf(frame/120.0,anim.length)
		for t in anim.get_track_count():
			var index := target.find_bone(anim.track_get_path(t).get_subname(0))
			if anim.track_get_type(t)==Animation.TYPE_ROTATION_3D:
				target.set_bone_pose_rotation(index,anim.rotation_track_interpolate(t,time))
			elif anim.track_get_type(t)==Animation.TYPE_POSITION_3D:
				target.set_bone_pose_position(index,anim.position_track_interpolate(t,time))
		# Offline skeleton is not in SceneTree; compose FK explicitly rather than
		# relying on deferred renderer updates of global bone pose caches.
		var posed: Array[Transform3D] = []
		for bone in target.get_bone_count():
			var parent := target.get_bone_parent(bone)
			posed.append(posed[parent]*target.get_bone_pose(bone) if parent>=0 else target.get_bone_pose(bone))
		var feet := []
		for side in ["Left","Right"]:
			var foot := posed[target.find_bone("mixamorig_"+side+"Foot")].origin
			feet.append(foot)
			lowest = minf(lowest,foot.y)
		samples.append(feet)
	var speeds := []
	for i in range(1,samples.size()):
		for side in 2:
			var a: Vector3 = samples[i-1][side]
			var b: Vector3 = samples[i][side]
			if maxf(a.y,b.y) < lowest+.05:
				var velocity := absf(b.z-a.z)*120
				if velocity>.15: speeds.append(velocity)
	target.reset_bone_poses()
	if speeds.is_empty():
		errors.append("No target foot-stance samples for locomotion")
		return 1.0
	speeds.sort()
	return speeds[speeds.size()/2]

func convert_clip(source: Animation, sk: Skeleton3D, name: String) -> Animation:
	var anim := Animation.new()
	anim.length = source.length
	anim.loop_mode = Animation.LOOP_NONE if name in ["sit_down","stand_up"] else Animation.LOOP_LINEAR
	for i in source.get_track_count():
		var path := source.track_get_path(i)
		if path.get_subname_count() == 0: continue
		var bone := String(path.get_subname(0))
		var index := target.find_bone(bone)
		if index < 0: continue
		var src := sk.find_bone(bone)
		if src < 0:
			errors.append("Missing source bone "+bone)
			continue
		var src_parent := sk.get_bone_parent(src)
		var target_parent := target.get_bone_parent(index)
		if (src_parent < 0) != (target_parent < 0) or (src_parent >= 0 and sk.get_bone_name(src_parent) != target.get_bone_name(target_parent)):
			errors.append("Incompatible bone hierarchy: "+bone)
			continue
		var type := source.track_get_type(i)
		if type not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D]: continue
		var track := anim.add_track(type)
		anim.track_set_path(track,NodePath("VisualPivot/GuardRig/Skeleton3D:"+bone))
		var rest := target.get_bone_rest(index)
		var old_rest := sk.get_bone_rest(src)
		for k in source.track_get_key_count(i):
			var time := source.track_get_key_time(i,k)
			var value = source.track_get_key_value(i,k)
			if type == Animation.TYPE_ROTATION_3D:
				value = rest.basis.get_rotation_quaternion()*old_rest.basis.get_rotation_quaternion().inverse()*value
			else:
				value = rest.origin+(value-old_rest.origin)*.95
				if bone == "mixamorig_Hips":
					# Fixed chair/locomotion anchor; retain vertical crouching and breathing.
					value.x = rest.origin.x
					value.z = rest.origin.z
			if anim.loop_mode != Animation.LOOP_NONE and k > 0 and k == source.track_get_key_count(i)-1:
				value = anim.track_get_key_value(track,0)
			anim.track_insert_key(track,time,value)
	return anim

func build_visual(library: AnimationLibrary) -> void:
	var visual := Node3D.new()
	visual.name = "MuseumGuardVisual"
	var pivot := Node3D.new()
	pivot.name = "VisualPivot"
	pivot.rotation.y = PI
	visual.add_child(pivot)
	pivot.owner = visual
	var rig: Node3D = load(RIG).instantiate()
	pivot.add_child(rig)
	rig.owner = visual
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	visual.add_child(player)
	player.owner = visual
	player.add_animation_library("",load(LIBRARY))
	var tree := AnimationTree.new()
	tree.name = "AnimationTree"
	visual.add_child(tree)
	tree.owner = visual
	tree.anim_player = NodePath("../AnimationPlayer")
	var blend := AnimationNodeBlendTree.new()
	var clip := AnimationNodeAnimation.new()
	clip.animation = "idle"
	blend.add_node("Clip",clip)
	blend.connect_node("output",0,"Clip")
	tree.tree_root = blend
	tree.active = false # AnimationPlayer owns playback/blending; never evaluate two mixers.
	save_scene(visual,VISUAL)
	visual.free()

func save_scene(node: Node, path: String) -> void:
	var packed := PackedScene.new()
	packed.pack(node)
	ResourceSaver.save(packed,path)

func build_actor() -> void:
	# Snapshot the unchanged shared physics/sensors into a map-local base scene.
	var actor: Node3D = load("res://shared/scenes/npc/guard.tscn").instantiate()
	actor.name = "MuseumGuard"
	actor.get_node("Model").free()
	var visual: Node3D = load(VISUAL).instantiate()
	visual.name = "Model"
	actor.add_child(visual)
	actor.move_child(visual,1)
	visual.owner = actor
	actor.get_node("Presentation").set_script(load(BASE+"scripts/museum_guard_presentation.gd"))
	save_scene(actor,BASE+"scenes/npc/museum_guard.tscn")
	actor.free()

func validate() -> void:
	for path in [RIG,LIBRARY,VISUAL,MANIFEST]:
		if not FileAccess.file_exists(path): errors.append("Missing "+path)
	if errors.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if not parsed is Dictionary or not parsed.has_all(["source_sha256","clips"]):
			errors.append("Invalid or incomplete manifest JSON")
			return
		var manifest: Dictionary = parsed
		if manifest.source_sha256 != FileAccess.get_sha256(SOURCE): errors.append("Source GLB changed; rebuild required")
		for clip in manifest.clips:
			if clip.sha256 != FileAccess.get_sha256(CLIPS+clip.source): errors.append("Source clip changed: "+clip.name)
		var library := load(LIBRARY) as AnimationLibrary
		var packed := load(RIG) as PackedScene
		if library == null or packed == null:
			errors.append("Unreadable derived rig or animation library")
			return
		var rig: Node3D = packed.instantiate()
		var sk: Skeleton3D = find_type(rig,"Skeleton3D")
		if sk == null or sk.get_bone_count() != 65: errors.append("Skeleton mismatch")
		for mesh: MeshInstance3D in rig.find_children("*","MeshInstance3D",true,false):
			if mesh.skin == null: errors.append("Missing skin "+mesh.name)
			if mesh.mesh == null:
				errors.append("Missing mesh "+mesh.name)
				continue
			for s in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(s)
				if arrays[Mesh.ARRAY_WEIGHTS].size() != arrays[Mesh.ARRAY_VERTEX].size()*4: errors.append("Missing weights")
		for name in NAMES+["sleep","RESET"]:
			if not library.has_animation(name):
				errors.append("Missing clip "+name)
				continue
			var anim := library.get_animation(name)
			if name in ["sit_down","stand_up"] and anim.loop_mode != Animation.LOOP_NONE: errors.append("Transition loops")
			for t in anim.get_track_count():
				var path := anim.track_get_path(t)
				if path.get_subname_count()!=1 or sk.find_bone(path.get_subname(0))<0: errors.append("Unresolved bone "+String(path))
		rig.free()
	for error in errors: push_error(error)
	print("Guard assets: ", "PASSED" if errors.is_empty() else "FAILED", " (",errors.size()," errors)")

