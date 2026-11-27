extends "res://maps/isg_museum/tools/capture_courtyard_palette.gd"

## Offline QA fixture only. Nothing in this runner is saved to the product.
const Apply := preload("res://maps/isg_museum/tools/apply_environment_art.gd")
var map: Node3D
var config: Dictionary

func lighting() -> Dictionary:
	var environment: Environment = map.get_node("WorldEnvironment").environment
	var lights := []
	for light in map.find_children("*","Light3D",true,false):
		lights.append({"path":String(map.get_path_to(light)),"transform":str(light.global_transform),"properties":properties(light)})
	return {"environment":properties(environment),"sky":properties(environment.sky),"sky_material":properties(environment.sky.sky_material),
		"lights":lights,"camera_attributes":properties(player.camera.attributes)}

func run() -> void:
	output_dir = BASE+"docs/reports/courtyard-palette-stage-b/"
	if not configure_output():
		quit(1)
		return
	root.size = Vector2i(1280,720)
	config = JSON.parse_string(FileAccess.get_file_as_string(BASE+"resources/courtyard_palette.json"))
	var args := OS.get_cmdline_user_args()
	if "--diagnose-garden" in args and config.stage=="A_preview_only":
		preview = load(BASE+"scenes/previews/courtyard_palette_preview.tscn").instantiate()
		root.add_child(preview)
		current_scene = preview
		map = preview.map
		preview.hint.hide()
	else:
		map = load(BASE+"scenes/"+("museum_editing" if "--editing" in args else "museum")+".tscn").instantiate()
		root.add_child(map)
		current_scene = map
	await frames(15)
	for child in map.get_children():
		if child is CanvasLayer: child.hide()
	for node in get_nodes_in_group("debug_visuals"):
		if node is Node3D: node.hide()
	map.process_mode = Node.PROCESS_MODE_DISABLED
	player = map.get_node("Player")
	player.camera.current = true
	write_collision()
	if "--diagnose-garden" in args:
		await diagnose_garden()
	elif "--gameplay-only" in args:
		await gameplay()
	elif "--details-only" in args:
		for id in detail_views():
			view(detail_views()[id])
			await shot(image_prefix+id)
	else:
		view(config.preview.overview)
		await shot(image_prefix+"overview")
		for id in config.preview.cameras:
			view(config.preview.cameras[id])
			await shot(image_prefix+id)
		for id in extra_views():
			view(extra_views()[id])
			await shot(image_prefix+id)
		if "--measure" in args:
			var old_cap := Engine.max_fps
			var old_sync := DisplayServer.window_get_vsync_mode()
			Engine.max_fps = 0
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			view(config.preview.overview)
			var result := await measure()
			result.merge({"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name(),"viewport":[1280,720],"conditions":"product scene frozen; same overview, 120 display-frame warmup + 8 seconds, VSync/cap off; process intervals, not GPU time"})
			write_json(image_prefix+"benchmark.json",result)
			Engine.max_fps = old_cap
			DisplayServer.window_set_vsync_mode(old_sync)
		if "--gameplay" in args: await gameplay()
	write_json(image_prefix+"camera-metadata.json",metadata)
	map.process_mode = Node.PROCESS_MODE_DISABLED
	current_scene = null
	if preview: preview.free()
	else: map.free()
	await frames(3)
	quit()

func extra_views() -> Dictionary:
	return {"garden-wall-closeup":{"position":[10.5,1.55,12.5],"target":[12.1,.72,12.6]},
		"lobby":{"position":[19.8,1.65,29],"target":[15,1.0,24]},
		"south-buffer":{"position":[19.8,6.15,29],"target":[15,5.5,24]},
		"staff":{"position":[29.8,1.6,14.7],"target":[34.1,.9,12]},
		"teammate":{"position":[21.6,1.6,34],"target":[20.5,1.15,31.5]},
		"receptionist":{"position":[29.8,1.65,28.5],"target":[33.05,1.0,27]}}

func detail_views() -> Dictionary:
	var result := {}
	var directions := {"north":Vector3(0,0,-1),"south":Vector3(0,0,1),"west":Vector3(-1,0,0),"east":Vector3(1,0,0)}
	for side in directions:
		var d: Vector3 = directions[side]
		var lower := Vector3(18,1.65,15)+d*2.5
		var upper := Vector3(18,6.15,15)-d*7.5
		result[side+"-lower"] = {"position":[lower.x,lower.y,lower.z],"target":[18+d.x*7,3.2,15+d.z*7]}
		result[side+"-upper"] = {"position":[upper.x,upper.y,upper.z],"target":[18+d.x*6,6.4,15+d.z*6]}
	result["gallery-a"] = {"position":[5,6.15,10],"target":[8.5,6.0,9]}
	result["gallery-b"] = {"position":[31.5,6.15,9],"target":[27.2,6.3,10]}
	result["gallery-c"] = {"position":[18,6.15,3],"target":[18,6.5,5.7]}
	return result

func diagnose_garden() -> void:
	view(extra_views()["garden-wall-closeup"])
	await shot("diagnostic-current")
	var meshes := []
	for body in map.get_node("NavigationRegion3D/Geometry/Courtyard").get_children():
		if String(body.name).begins_with("Ground"): meshes.append(body.get_node("Mesh"))
	var original := meshes[0].material_override as StandardMaterial3D
	var no_normal: StandardMaterial3D = original.duplicate()
	no_normal.normal_enabled = false
	for mesh in meshes: mesh.material_override = no_normal
	await shot("diagnostic-no-normal")
	var flat: StandardMaterial3D = original.duplicate()
	flat.albedo_texture = null
	var tint: Array = config.roles.garden_wall_stone.tint
	flat.albedo_color = Color(tint[0],tint[1],tint[2])
	for mesh in meshes: mesh.material_override = flat
	await shot("diagnostic-flat-albedo")
	for mesh in meshes: mesh.material_override = original

func write_collision() -> void:
	var rows := []
	for node in map.find_children("*","Node3D",true,false):
		if not node is CollisionObject3D and not node is CollisionShape3D: continue
		var transform := Transform3D.IDENTITY
		var parent: Node = node
		while parent!=map:
			if parent is Node3D: transform = parent.transform*transform
			parent = parent.get_parent()
		var row := String(map.get_path_to(node))+node.get_class()+str(transform)
		if node is CollisionShape3D: row += Apply.resource_key(node.shape)+str(node.disabled)
		if node is CollisionObject3D: row += str(node.collision_layer)+str(node.collision_mask)
		# Actor locations can differ after startup; geometry and interactables are stable.
		if String(map.get_path_to(node)).begins_with("NavigationRegion3D/Geometry/"): rows.append(row)
	rows.sort()
	write_json(image_prefix+"collision.json",{"sha256":"\n".join(rows).sha256_text(),"rows":rows})

func write_json(path: String, data: Variant) -> void:
	var file := FileAccess.open(ReportPaths.artifact(output_dir,path),FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t")+"\n")
	file.close()

func gameplay() -> void:
	# Explicit QA fixture: AI/senses stay active; terminal caught overlay is suppressed.
	# Anchor cuts between sections shorten the recording; interactions use real APIs.
	map.process_mode = Node.PROCESS_MODE_INHERIT
	map.get_node("StealthDirector").set_physics_process(false)
	var results := []
	var n0 := map.get_node("NavigationRegion3D/Teammate")
	pose(Vector3(21,0,33),n0.global_position)
	results.append({"interaction":"N0","ok":n0.interact(player)})
	await frames(35)
	var ui := get_first_node_in_group("museum_contract_ui")
	if ui.accept_button: ui.accept_button.pressed.emit()
	else: ui.close_sheet()
	pose(Vector3(18,0,31.3),Vector3(18,1.4,30))
	results.append({"interaction":"entrance","ok":map.get_node("NavigationRegion3D/Doors/Entrance").interact(player)})
	results.append({"walk":"lobby","ok":await live_walk(Vector3(18,0,27.5),Vector3(14,2,24))})
	map.get_node("NavigationRegion3D/Doors/Service").interact(player)
	var npc := map.get_node("NavigationRegion3D/ServiceExpansion/Receptionist")
	pose(Vector3(30.1,0,27.8),npc.global_position)
	results.append({"interaction":"receptionist","ok":npc.interact(player)})
	await frames(30)
	var service := get_first_node_in_group("museum_service_ui")
	for i in 3:
		service.answer(int(service.questions[service.question_index].correct))
		await frames(20)
	results.append({"interaction":"ticket_after_three_answers","ok":get_first_node_in_group("museum_contract").has_ticket})
	service.close_panel()
	map.get_node("NavigationRegion3D/ServiceExpansion/TicketGate_A").interact(player)
	pose(Vector3(8,0,28.25),Vector3(2,2,28.25))
	for point in [Vector3(7.4,0,28.25),Vector3(1.2,2.25,28.25),Vector3(1.2,2.25,25.75),Vector3(7.5,4.5,25.75),Vector3(8,4.5,27),Vector3(11,4.5,27),Vector3(18,4.5,27)]:
		results.append({"walk":"stair_A_and_south_buffer","target":str(point),"ok":await live_walk(point,point+Vector3(0,1.4,-1))})
	pose(Vector3(25.5,4.5,3),Vector3(27,6,3))
	map.get_node("NavigationRegion3D/ServiceExpansion/TicketGate_B").interact(player)
	for point in [Vector3(28,4.5,3),Vector3(28,4.5,1.75),Vector3(34.8,2.25,1.75),Vector3(34.8,2.25,4.25),Vector3(28,0,4.25)]:
		results.append({"walk":"stair_B_down","target":str(point),"ok":await live_walk(point,point+Vector3(0,1.2,1))})
	var key := map.get_node("Interactables/Key")
	pose(Vector3(34,0,10.2),key.global_position)
	results.append({"interaction":"key_K","ok":key.interact(player)})
	await frames(30)
	map.get_node("NavigationRegion3D/Doors/GalleryB").interact(player)
	var painting := map.get_node("Interactables/Painting_T2")
	pose(Vector3(34.3,4.5,10),painting.global_position)
	results.append({"interaction":"T2_pickup","ok":painting.interact(player)})
	await frames(30)
	for point in [Vector3(31,4.5,10),Vector3(28,4.5,10),Vector3(25.5,4.5,10),Vector3(25.5,4.5,16.5)]:
		results.append({"walk":"carry_T2","target":str(point),"ok":await live_walk(point,Vector3(18,5.5,15))})
	var actors := []
	for child in map.get_children():
		if child is Guard: actors.append({"id":String(child.name),"ai_active":child.is_physics_processing(),"vision_active":child.vision.is_physics_processing(),"animation":child.get_node("Presentation").current_animation})
	write_json("gameplay.json",{"fixture":"Anchor cuts between sections; StealthDirector terminal capture disabled only here. Nine guard AI active; native phase-dependent sensors retained (sleeping G3 vision off). Real NPC/quiz/key/door/T2 APIs, real Player movement; no changes saved.","results":results,"guards":actors})

func pose(feet: Vector3, target: Vector3) -> void:
	player.position = feet
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.camera.look_at(target)

func live_walk(target: Vector3, gaze: Vector3) -> bool:
	player.set_physics_process(true)
	var reached := false
	for tick in 600:
		var offset := target-player.global_position
		offset.y = 0
		if offset.length()<.15:
			reached = true
			break
		player.rotation.y = atan2(-offset.x,-offset.z)
		# Follow travel direction on stairs instead of looking into a side wall.
		var ahead := player.global_position+offset.normalized()*minf(3,offset.length())
		ahead.y = player.global_position.y+1.2+clampf(target.y-player.global_position.y,-.6,.6)
		player.camera.look_at(gaze if player.is_carrying() else ahead)
		Input.action_press("move_forward")
		await physics_frame
	Input.action_release("move_forward")
	player.velocity = Vector3.ZERO
	await physics_frame
	return reached and absf(player.position.y-target.y)<.25
