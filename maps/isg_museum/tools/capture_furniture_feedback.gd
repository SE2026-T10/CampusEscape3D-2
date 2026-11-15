extends SceneTree

## Offline visual QA: capture the normal scene after real G3 establishes its pose.
## Freeze only the capture instance; AI behavior is exercised by verify_staff_room.
const Art := preload("res://maps/isg_museum/tools/environment_art_builder.gd")
const OUT := "res://maps/isg_museum/docs/visual-feedback-2026-11-15/"
var camera: Camera3D
var prefix := "furniture-before-"

func _initialize() -> void:
	run.call_deferred()

func shot(id: String, position: Vector3, target: Vector3) -> void:
	camera.position = position
	camera.look_at(target)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+prefix+id+".png")
	print("Captured ",prefix,id)

func run() -> void:
	prefix = "furniture-after-" if "--after" in OS.get_cmdline_user_args() else "furniture-before-"
	root.size = Vector2i(1280,720)
	var level := load(Art.BASE+"scenes/museum.tscn").instantiate() as Node3D
	root.add_child(level)
	current_scene = level
	for i in 12:
		await physics_frame
	for i in 8:
		await process_frame # Let the real G3 presentation establish its seated pose.
	print("G3 phase=",level.get_node("Guard_G3").phase," yaw=",level.get_node("Guard_G3").rotation_degrees)
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in level.get_children():
		if node is CanvasLayer:
			node.hide()
	for node in get_nodes_in_group("debug_visuals"):
		if node is Node3D:
			node.hide()
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = 65
	await shot("cabinet",Vector3(31.5,1.65,20.7),Vector3(31.5,1.1,23.5))
	await shot("g3-side",Vector3(34,1.45,14.3),Vector3(34.1,.7,12))
	await shot("g3-oblique",Vector3(35.3,1.5,13.8),Vector3(34.1,.7,12))
	var art := Art.new()
	var layout := art.load_layout()
	var audit := {"scene": "museum.tscn", "guards": get_nodes_in_group("guards").size(),
		"g3_phase": level.get_node("Guard_G3").phase,
		"g3_position": str(level.get_node("Guard_G3").position),
		"g3_yaw": level.get_node("Guard_G3").rotation_degrees.y,
		"visuals": {}, "legacy_visible": {}}
	for entry in layout.geometry_props:
		if entry.id in ["storage_cabinet","g3_chair","restoration_cabinet"]:
			var visual := level.get_node("NavigationRegion3D/Geometry/EnvironmentArt/Interiors/"+entry.id)
			print(entry.id," yaw=",entry.yaw," pivot=",visual.get_node("VisualPivot").transform," world_bounds=",art.compute_visual_bounds(visual))
			audit.visuals[entry.id] = {"yaw": entry.yaw, "position": str(visual.position),
				"normalized_bounds": str(art.compute_visual_bounds(visual)),
				"pivot": str(visual.get_node("VisualPivot").transform)}
	var geometry := level.get_node("NavigationRegion3D/Geometry")
	for path in ["StorageInterior/SteelCabinet/Mesh", "StorageInterior/CabinetDoor",
		"StorageInterior/CabinetHandle", "StaffInterior/ChairSeat", "StaffInterior/ChairBack"]:
		audit.legacy_visible[path] = geometry.get_node(path).visible
	FileAccess.open(OUT+prefix+"audit.json", FileAccess.WRITE).store_string(JSON.stringify(audit,"\t")+"\n")
	level.hide()
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	sun.rotation_degrees = Vector3(-35,-25,0)
	for entry in layout.geometry_props:
		if not entry.id in ["storage_cabinet","g3_chair"]:
			continue
		var model := art.prepare_visual(entry.source,art.vec(entry.size),0)
		root.add_child(model)
		print("SOURCE ",entry.id," bounds=",art.compute_visual_bounds(model))
		for part in model.get_node("VisualPivot").get_children():
			print("part ",part.name," bounds=",art.relative_transform(model,part)*part.get_aabb())
		await shot("source-"+entry.id+"-minus-z",Vector3(0,1.6,-4),Vector3(0,.85,0))
		await shot("source-"+entry.id+"-plus-z",Vector3(0,1.6,4),Vector3(0,.85,0))
		model.free()
	level.free()
	camera.free()
	sun.free()
	quit()
