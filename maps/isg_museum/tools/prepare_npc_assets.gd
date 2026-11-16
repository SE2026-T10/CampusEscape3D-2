extends "res://maps/isg_museum/tools/prepare_guard_assets.gd"

## Reuse the existing rest-aware converter only. Never rebuild or save guard assets.
const NPC_LIBRARY := BASE+"assets/animations/mixamo/derived/npc_animations.res"
const NPC_VISUAL := BASE+"scenes/npc/museum_npc_visual.tscn"
const NPC_MANIFEST := BASE+"resources/npc_animation_manifest.json"

func _initialize() -> void:
	prepare.call_deferred()

func prepare() -> void:
	if "--check" in OS.get_cmdline_user_args():
		check_npc()
		quit(0 if errors.is_empty() else 1)
		return
	var rig: Node3D = load(RIG).instantiate()
	target = find_type(rig,"Skeleton3D")
	var guards := load(LIBRARY) as AnimationLibrary
	var library := AnimationLibrary.new()
	library.add_animation("standing_idle",guards.get_animation("idle"))
	library.add_animation("seated_idle",guards.get_animation("sitting_idle"))
	library.add_animation("seated_watch",guards.get_animation("sitting_idle"))
	library.add_animation("RESET",guards.get_animation("RESET"))
	var clips := []
	for entry in [["standing_talk","npc_talking"],["seated_talk","receptionist_talking"]]:
		var path: String = CLIPS+"clips/"+entry[1]+".fbx"
		var root_clip: Node3D = load(path).instantiate()
		var player: AnimationPlayer = find_type(root_clip,"AnimationPlayer")
		var sk: Skeleton3D = find_type(root_clip,"Skeleton3D")
		var original := player.get_animation("mixamo_com")
		var converted := convert_clip(original,sk,entry[0])
		if entry[0]=="seated_talk":
			# Match the mean seated hip height while retaining breathing/gestures.
			align_seated(converted,guards.get_animation("sitting_idle"))
		close_loop(converted,.35)
		library.add_animation(entry[0],converted)
		clips.append({"name":entry[0],"source":path,"take":"mixamo_com","duration":converted.length,
			"loop":true,"sha256":FileAccess.get_sha256(path),"root_motion":"fixed XZ; vertical hips retained; seated mean height matched"})
		root_clip.free()
	ResourceSaver.save(library,NPC_LIBRARY)
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.set_meta("preserve_source_material",true)
	var pivot := Node3D.new()
	pivot.name = "VisualPivot"
	pivot.rotation.y = PI
	visual.add_child(pivot)
	pivot.owner = visual
	var instance: Node3D = load(RIG).instantiate()
	pivot.add_child(instance)
	instance.owner = visual
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	visual.add_child(player)
	player.owner = visual
	player.add_animation_library("",load(NPC_LIBRARY))
	save_scene(visual,NPC_VISUAL)
	visual.free()
	var data := {"schema_version":1,"rig":RIG,"rig_sha256":FileAccess.get_sha256(RIG),"library":NPC_LIBRARY,
		"visual":NPC_VISUAL,"blend_seconds":.2,"clips":clips,"guard_library_sha256":FileAccess.get_sha256(LIBRARY),
		"loop_seam_seconds":.35,"teammate":{"offset":[0,-1,0],"yaw_degrees":180},
		"receptionist":{"offset":[.35,-1.15,0],"yaw_degrees":90,"chair_yaw_degrees":-90},
		"watch":{"max_yaw":.65,"max_pitch":.18,"smoothing":5.0},
		"source_terms":"Jose Manuel CC BY 4.0 rig; Adobe Mixamo animations, original files unchanged"}
	var file := FileAccess.open(NPC_MANIFEST,FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t")+"\n")
	file.close()
	rig.free()
	check_npc()
	quit(0 if errors.is_empty() else 1)

func hips_track(anim: Animation) -> int:
	for t in anim.get_track_count():
		if anim.track_get_type(t)==Animation.TYPE_POSITION_3D and String(anim.track_get_path(t)).ends_with(":mixamorig_Hips"): return t
	return -1

func align_seated(anim: Animation, idle: Animation) -> void:
	var t := hips_track(anim)
	var idle_t := hips_track(idle)
	var average := 0.0
	var idle_average := 0.0
	for k in anim.track_get_key_count(t): average += anim.track_get_key_value(t,k).y
	for k in idle.track_get_key_count(idle_t): idle_average += idle.track_get_key_value(idle_t,k).y
	var correction := idle_average/idle.track_get_key_count(idle_t)-average/anim.track_get_key_count(t)
	for k in anim.track_get_key_count(t):
		var value: Vector3 = anim.track_get_key_value(t,k)
		value.y += correction
		anim.track_set_key_value(t,k,value)

func close_loop(anim: Animation, window: float) -> void:
	# Bake the tail into the first pose over a short window; no last-frame snap.
	for t in anim.get_track_count():
		var type := anim.track_get_type(t)
		var start = anim.track_get_key_value(t,0)
		var values := []
		for k in anim.track_get_key_count(t):
			var time := anim.track_get_key_time(t,k)
			var value = anim.track_get_key_value(t,k)
			var blend := smoothstep(anim.length-window,anim.length,time)
			values.append(value.slerp(start,blend) if type==Animation.TYPE_ROTATION_3D else value.lerp(start,blend))
		for k in values.size(): anim.track_set_key_value(t,k,values[k])

func check_npc() -> void:
	for path in [NPC_LIBRARY,NPC_VISUAL,NPC_MANIFEST,RIG]:
		if not FileAccess.file_exists(path): errors.append("Missing "+path)
	if not errors.is_empty():
		for error in errors: push_error(error)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(NPC_MANIFEST))
	if not data is Dictionary or not data.has_all(["rig_sha256","guard_library_sha256","clips"]) \
			or not data.clips is Array or data.get("schema_version")!=1:
		errors.append("Invalid NPC manifest")
	else:
		if data.rig_sha256!=FileAccess.get_sha256(RIG) or data.guard_library_sha256!=FileAccess.get_sha256(LIBRARY): errors.append("Guard resources changed; regenerate NPC clips")
		if data.clips.size()!=2: errors.append("Manifest must describe both talking sources")
		for clip in data.clips:
			if not clip is Dictionary or not clip.has_all(["name","source","sha256"]) \
					or not clip.source is String or not clip.sha256 is String:
				errors.append("Invalid clip manifest entry")
				continue
			if clip.sha256!=FileAccess.get_sha256(clip.source): errors.append("Changed clip "+clip.name)
	var packed := load(NPC_VISUAL) as PackedScene
	var library := load(NPC_LIBRARY) as AnimationLibrary
	if packed==null or library==null:
		errors.append("Invalid NPC visual/library")
	else:
		var visual := packed.instantiate()
		var sk: Skeleton3D = find_type(visual,"Skeleton3D")
		if sk==null or sk.get_bone_count()!=65: errors.append("Invalid target rig")
		else:
			for mesh: MeshInstance3D in sk.get_children():
				if mesh.skin==null or mesh.skin.get_bind_count()!=65: errors.append("Invalid skin bind")
				for s in mesh.mesh.get_surface_count():
					var arrays := mesh.mesh.surface_get_arrays(s)
					if arrays[Mesh.ARRAY_WEIGHTS]==null or arrays[Mesh.ARRAY_WEIGHTS].size()!=arrays[Mesh.ARRAY_VERTEX].size()*4: errors.append("Missing skin weights")
			for name in ["standing_idle","standing_talk","seated_idle","seated_talk","seated_watch","RESET"]:
				if not library.has_animation(name):
					errors.append("Missing "+name)
					continue
				var anim := library.get_animation(name)
				if anim.length<=0 or anim.get_track_count()<2: errors.append("Empty clip "+name)
				if name!="RESET" and anim.loop_mode!=Animation.LOOP_LINEAR: errors.append("Invalid loop "+name)
				for t in anim.get_track_count():
					var path := anim.track_get_path(t)
					if path.get_subname_count()!=1 or sk.find_bone(path.get_subname(0))<0 or visual.get_node_or_null(NodePath(path.get_concatenated_names()))!=sk: errors.append("Invalid bone track")
					if anim.track_get_type(t)==Animation.TYPE_POSITION_3D and String(path).ends_with(":mixamorig_Hips"):
						var anchor := sk.get_bone_rest(0).origin
						for k in anim.track_get_key_count(t):
							var point: Vector3 = anim.track_get_key_value(t,k)
							if absf(point.x-anchor.x)>.0001 or absf(point.z-anchor.z)>.0001: errors.append("Horizontal root drift in "+name)
		visual.free()
	for error in errors: push_error(error)
	print("NPC assets: ","PASSED" if errors.is_empty() else "FAILED"," (",errors.size()," errors)")
