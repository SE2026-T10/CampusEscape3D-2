extends "res://maps/isg_museum/tools/capture_courtyard_stage_b.gd"

## Render/interaction QA only. No temporary visibility/unlock is saved.
func portals() -> Dictionary:
	return {"a-north":{"center":Vector3(9,4.5,9),"normal":Vector3.RIGHT},
		"a-south":{"center":Vector3(9,4.5,19),"normal":Vector3.RIGHT},
		"b":{"center":Vector3(27,4.5,10),"normal":Vector3.LEFT},
		"c-west":{"center":Vector3(15,4.5,6),"normal":Vector3.BACK},
		"c-east":{"center":Vector3(23,4.5,6),"normal":Vector3.BACK}}

func fixed_views() -> Dictionary:
	var result := {"arcade-lower":{"position":[18,1.65,17.8],"target":[18,4.1,9]},
		"arcade-upper":{"position":[18,6.15,20.7],"target":[18,8.7,9]},
		"corner-lower":{"position":[15,1.65,12.5],"target":[12,4.1,9]},
		"corner-upper":{"position":[15,6.15,7.5],"target":[12,8.8,9]}}
	for id in portals():
		var portal: Dictionary = portals()[id]
		for side in [-1,1]:
			var p: Vector3 = portal.center+portal.normal*side*1.3+Vector3.UP*1.15
			var t: Vector3 = portal.center-portal.normal*side*.4+Vector3.UP*.01
			result["threshold-"+id+("-hall" if side==1 else "-room")] = {"position":[p.x,p.y,p.z],"target":[t.x,t.y,t.z]}
	for id in ["Entrance","Staff","Storage","Service"]:
		var door := map.get_node("NavigationRegion3D/Doors/"+id) as Node3D
		for side in [-1,1]:
			var p := door.to_global(Vector3(.25,1.65,side*1.5))
			var t := door.to_global(Vector3(0,1.25,0))
			result["door-"+id.to_lower()+("-front" if side==1 else "-back")] = {"position":[p.x,p.y,p.z],"target":[t.x,t.y,t.z]}
	var staff := map.get_node("NavigationRegion3D/Doors/Staff") as Node3D
	var p := staff.to_global(Vector3(.4,1.25,.8))
	var t := staff.to_global(Vector3(.45,1.25,.15))
	result["door-handle"] = {"position":[p.x,p.y,p.z],"target":[t.x,t.y,t.z]}
	return result

func run() -> void:
	output_dir = BASE+"docs/reports/post-b-fixes-v1/"
	if not configure_output():
		quit(1)
		return
	root.size = Vector2i(1280,720)
	var gameplay_capture := "--gameplay" in OS.get_cmdline_user_args()
	map = load(BASE+"scenes/"+("museum" if gameplay_capture else "museum_editing")+".tscn").instantiate()
	root.add_child(map)
	current_scene = map
	await frames(15)
	for child in map.get_children():
		if child is CanvasLayer: child.hide()
	for node in get_nodes_in_group("debug_visuals"):
		if node is Node3D: node.hide()
	player = map.get_node("Player")
	player.camera.current = true
	map.process_mode = Node.PROCESS_MODE_DISABLED
	write_collision()
	# Inspect the real B threshold while holding its panel open in this QA instance.
	var door := map.get_node("NavigationRegion3D/Doors/GalleryB")
	if not gameplay_capture:
		door.unlocked = true
		door.interact(player)
	if gameplay_capture:
		await gameplay()
	elif "--joint-diagnose" in OS.get_cmdline_user_args():
		view(detail_views()["east-lower"])
		await shot("joint-current")
		for mesh in map.get_node("NavigationRegion3D/Geometry/EnvironmentArt/Arcade").get_children():
			if not mesh is MeshInstance3D or mesh.get_meta("material_role","")!="courtyard_plaster": continue
			var mat: StandardMaterial3D = mesh.material_override.duplicate()
			mat.normal_enabled = false
			mesh.material_override = mat
			await shot("joint-no-normal")
			mat.albedo_texture = null
			mat.albedo_color = Color(.67,.43,.36)
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			await shot("joint-flat-unlit-diagnostic")
	elif "--arcade-details" in OS.get_cmdline_user_args():
		for id in detail_views():
			if String(id).begins_with("gallery-"): continue
			view(detail_views()[id])
			await shot(image_prefix+id)
		for floor_y in [0.0,4.5]:
			for corner in [Vector3(12,0,9),Vector3(24,0,9),Vector3(12,0,21),Vector3(24,0,21)]:
				var p := Vector3(corner.x+(3 if corner.x==12 else -3),floor_y+1.65,corner.z+((3 if corner.z==9 else -3) if floor_y==0 else (-1.5 if corner.z==9 else 1.5)))
				var target: Vector3 = corner+Vector3.UP*(floor_y+4.0)
				view({"position":[p.x,p.y,p.z],"target":[target.x,target.y,target.z]})
				await shot(image_prefix+"corner-%d-%d-floor-%d" % [corner.x,corner.z,int(floor_y/4.5)+1])
	elif "--diagnostic-movie" in OS.get_cmdline_user_args():
		await diagnostic_movie()
	elif "--diagnose" in OS.get_cmdline_user_args():
		await diagnose_thresholds()
	elif "--movie" in OS.get_cmdline_user_args():
		await inspection_movie()
	else:
		for id in fixed_views():
			view(fixed_views()[id])
			await shot(image_prefix+id)
	write_json(image_prefix+("details-camera-metadata.json" if "--arcade-details" in OS.get_cmdline_user_args() else "camera-metadata.json"),metadata)
	current_scene = null
	map.free()
	await frames(3)
	quit()

func diagnose_thresholds() -> void:
	var geometry := map.get_node("NavigationRegion3D/Geometry")
	for id in ["a-north","b","c-west"]:
		view(fixed_views()["threshold-"+id+"-hall"])
		await shot("diagnostic-"+id+"-current")
		geometry.get_node("GardnerPalette/Floor2").hide()
		await shot("diagnostic-"+id+"-no-stone")
		geometry.get_node("GardnerPalette/Floor2").show()
		var sources := []
		for body in geometry.get_node("Floors").get_children():
			if String(body.name).begins_with("Upper"):
				var mesh := body.get_node("Mesh") as MeshInstance3D
				sources.append([mesh,mesh.visible])
				mesh.hide()
		await shot("diagnostic-"+id+"-no-wood")
		for record in sources: record[0].visible = record[1]

func inspection_movie() -> void:
	map.process_mode = Node.PROCESS_MODE_INHERIT
	var results := []
	pose(Vector3(25.4,.05,22.5),Vector3(18,4.0,9))
	results.append({"section":"walk_arcade","ok":await walk_to(Vector3(10.6,0,22.5),Vector3(18,4.1,9))})
	for frame in 45:
		player.camera.look_at(Vector3(12+frame*.08,8.7,9))
		await process_frame
	for id in portals():
		var portal: Dictionary = portals()[id]
		pose(portal.center-portal.normal*.9+Vector3.UP*.05,portal.center)
		player.set_crouching(false)
		results.append({"portal":id,"stance":"standing","ok":await walk_to(portal.center+portal.normal*.9,portal.center)})
		await turn_at_threshold(portal.center,portal.normal)
		player.set_crouching(true)
		await frames(20)
		results.append({"portal":id,"stance":"crouched","ok":await walk_to(portal.center-portal.normal*.9,portal.center)})
		await turn_at_threshold(portal.center,portal.normal)
		player.set_crouching(false)
	for id in ["Entrance","Staff","Storage","Service"]:
		var door := map.get_node("NavigationRegion3D/Doors/"+id) as Node3D
		pose(door.to_global(Vector3(.25,.05,1.5)),door.to_global(Vector3(0,1.3,0)))
		await frames(15)
		var opened: bool = door.submit_code(door.current_code(),player) if id=="Storage" else door.interact(player)
		results.append({"door":id,"action":"open","ok":opened and door.is_open})
		await frames(30)
		await shot("movie-"+id.to_lower()+"-open")
		results.append({"door":id,"action":"close","ok":door.interact(player) and not door.is_open})
		await frames(30)
		await shot("movie-"+id.to_lower()+"-closed")
	write_json("inspection-movie.json",{"fixture":"Actual editing scene / Player camera and input. Anchor cuts between portals. B held open for QA; storage opens with the current calendar code. No temporary state saved.","results":results})

func turn_at_threshold(center: Vector3, normal: Vector3) -> void:
	for frame in 30:
		player.camera.look_at(center+normal.cross(Vector3.UP)*sin(frame*TAU/29)*.45)
		await process_frame

func diagnostic_movie() -> void:
	var geometry := map.get_node("NavigationRegion3D/Geometry")
	var wood := []
	for body in geometry.get_node("Floors").get_children():
		if String(body.name).begins_with("Upper"): wood.append(body.get_node("Mesh"))
	var segments := []
	for id in portals():
		var portal: Dictionary = portals()[id]
		for mode in ["current","no_stone","no_wood"]:
			geometry.get_node("GardnerPalette/Floor2").visible = mode!="no_stone"
			for mesh in wood: mesh.visible = mode!="no_wood"
			for frame in 45:
				var t := float(frame)/44
				var side: Vector3 = portal.normal.cross(Vector3.UP)
				var p: Vector3 = portal.center+portal.normal*(1.5-.3*t)+Vector3.UP*1.15+side*(t-.5)*.25
				var target: Vector3 = portal.center-portal.normal*.25
				view({"position":[p.x,p.y,p.z],"target":[target.x,target.y,target.z]})
				await process_frame
			segments.append({"portal":id,"mode":mode,"frames":45})
	geometry.get_node("GardnerPalette/Floor2").show()
	for mesh in wood: mesh.show()
	write_json("threshold-isolation.json",segments)
