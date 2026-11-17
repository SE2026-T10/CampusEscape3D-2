extends SceneTree

const BASE := "res://maps/isg_museum/"
const OUT := BASE+"docs/courtyard-palette-v1/"
var output_dir := OUT
var image_prefix := "after-"
var preview: Node3D
var player: FirstPersonPlayer
var metadata := []

func _initialize() -> void:
	run.call_deferred()

func configure_output() -> bool:
	# Optional revision folders keep the original A1 capture behavior intact.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_dir = argument.trim_prefix("--output=").trim_suffix("/")+"/"
		elif argument.begins_with("--prefix="):
			image_prefix = argument.trim_prefix("--prefix=")
	if not output_dir.begins_with(BASE+"docs/") or ".." in output_dir or "/" in image_prefix or "\\" in image_prefix:
		push_error("Capture output must stay in museum docs; prefix must be a filename prefix")
		return false
	var error := DirAccess.make_dir_recursive_absolute(output_dir)
	if error!=OK:
		push_error("Cannot create capture directory: "+output_dir)
		return false
	return true

func frames(n: int) -> void:
	for i in n: await process_frame

func vec(a: Array) -> Vector3:
	return Vector3(a[0],a[1],a[2])

func view(data: Dictionary) -> void:
	player.global_position = vec(data.position)-Vector3.UP*player.stand_eye_height
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.camera.global_position = vec(data.position)
	player.camera.look_at(vec(data.target))
	player.camera.fov = 75

func properties(object: Object) -> Dictionary:
	var values := {}
	if object==null: return values
	for property in object.get_property_list():
		if not property.usage&PROPERTY_USAGE_STORAGE or String(property.name).begins_with("resource_"): continue
		var value = object.get(property.name)
		if typeof(value) in [TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING,TYPE_COLOR,TYPE_VECTOR2,TYPE_VECTOR3]: values[property.name] = var_to_str(value)
	return values

func lighting() -> Dictionary:
	var map: Node3D = preview.map
	var environment: Environment = map.get_node("WorldEnvironment").environment
	var lights := []
	for light in map.find_children("*","Light3D",true,false):
		lights.append({"path":String(map.get_path_to(light)),"transform":str(light.global_transform),"properties":properties(light)})
	return {"environment":properties(environment),"sky":properties(environment.sky),
		"sky_material":properties(environment.sky.sky_material) if environment.sky else {},"lights":lights,
		"camera_attributes":properties(player.camera.attributes)}

func shot(id: String) -> void:
	await frames(15)
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output_dir+id+".png")
	if error!=OK:
		push_error("Capture failed: "+id)
		quit(1)
		return
	metadata.append({"id":id,"position":str(player.camera.global_position),"rotation":str(player.camera.global_rotation),
		"fov":player.camera.fov,"near":player.camera.near,"far":player.camera.far,"resolution":[root.size.x,root.size.y],
		"renderer":RenderingServer.get_current_rendering_method(),"lighting":lighting(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	print("Captured ",id)

func run() -> void:
	var palette_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"resources/courtyard_palette.json"))
	if palette_config.stage=="B_production":
		push_error("Stage A capture is archived. Use capture_courtyard_stage_b.gd for the saved product; A1/A2 evidence must remain unchanged.")
		quit(1)
		return
	if not configure_output():
		quit(1)
		return
	root.size = Vector2i(1280,720)
	preview = load(BASE+"scenes/previews/courtyard_palette_preview.tscn").instantiate()
	root.add_child(preview)
	current_scene = preview
	await frames(15)
	preview.hint.hide()
	preview.map.process_mode = Node.PROCESS_MODE_DISABLED
	player = preview.map.get_node("Player")
	player.camera.current = true
	if "--benchmark" in OS.get_cmdline_user_args():
		await benchmark()
	else:
		var config: Dictionary = preview.palette.config.preview
		view(config.overview)
		preview.set_proposed(false)
		await shot("before-overview")
		preview.set_proposed(true)
		await shot(image_prefix+"overview")
		for id in config.cameras:
			view(config.cameras[id])
			await shot(image_prefix+id)
		if "--garden-wall" in OS.get_cmdline_user_args():
			# A new fixed closeup is captured for BOTH A1 and A2, without moving geometry.
			view({"position":[10.5,1.55,12.5],"target":[12.1,.72,12.6]})
			await shot(image_prefix+"garden-wall-closeup")
		var file := FileAccess.open(output_dir+"camera-metadata.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(metadata,"\t")+"\n")
		file.close()
		file = FileAccess.open(output_dir+"capture-parameters.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"palette":preview.palette.config,"arguments":OS.get_cmdline_user_args(),"engine_arguments":OS.get_cmdline_args(),"engine":Engine.get_version_info()},"\t")+"\n")
		file.close()
		if "--walk" in OS.get_cmdline_user_args() or "--review-walk" in OS.get_cmdline_user_args(): await walk_video()
	preview.map.process_mode = Node.PROCESS_MODE_DISABLED
	preview.set_proposed(false)
	preview.palette.bindings.clear()
	preview.palette.materials.clear()
	await frames(3)
	current_scene = null
	preview.free()
	await frames(2)
	quit()

func walk_to(destination: Vector3, gaze: Vector3) -> bool:
	for tick in 600:
		var offset := destination-player.position
		offset.y = 0
		if offset.length()<.15:
			Input.action_release("move_forward")
			return true
		player.rotation.y = atan2(-offset.x,-offset.z)
		player.camera.look_at(gaze)
		Input.action_press("move_forward")
		await physics_frame
	Input.action_release("move_forward")
	return false

func walk_video() -> void:
	preview.map.process_mode = Node.PROCESS_MODE_INHERIT
	var results := []
	player.position = Vector3(18,.05,7.5)
	player.camera.rotation = Vector3.ZERO
	results.append({"section":"corridor_to_garden","reached":await walk_to(Vector3(18,0,11),Vector3(18,3,15))})
	results.append({"section":"garden_path","reached":await walk_to(Vector3(16,0,11.7),Vector3(14,1.7,11))})
	player.position = Vector3(16,.05,7.5)
	player.velocity = Vector3.ZERO
	results.append({"section":"along_column_wall","reached":await walk_to(Vector3(10.5,0,7.5),Vector3(12,2,9))})
	results.append({"section":"west_corridor","reached":await walk_to(Vector3(10.5,0,13),Vector3(12,1.2,13))})
	if "--review-walk" in OS.get_cmdline_user_args():
		player.camera.look_at(Vector3(10.9,.1,11))
		await frames(40)
		player.camera.look_at(Vector3(12.1,.7,12.7))
		await frames(40)
		player.camera.look_at(Vector3(20,5.4,10))
		await frames(50)
	preview.go_to_anchor(2)
	player.camera.look_at(Vector3(18,1.5,15))
	for i in 90:
		player.camera.rotate_y(.002)
		await process_frame
	var file := FileAccess.open(output_dir+"walk.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t")+"\n")
	file.close()
	print("Player input walk: ",results)

func measure() -> Dictionary:
	await frames(120)
	var intervals := []
	var draws := []
	var primitives := []
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec()-start<8000000:
		await process_frame
		var now := Time.get_ticks_usec()
		intervals.append((now-last)/1000.0)
		last = now
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	intervals.sort()
	draws.sort()
	primitives.sort()
	return {"frames":intervals.size(),"process_interval_ms":{"p50":intervals[int(intervals.size()*.5)],"p95":intervals[int(intervals.size()*.95)],"p99":intervals[int(intervals.size()*.99)]},
		"draw_calls_p50":draws[draws.size()/2],"primitives_p50":primitives[primitives.size()/2],"render_memory_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0}

func benchmark() -> void:
	var old_cap := Engine.max_fps
	var old_sync := DisplayServer.window_get_vsync_mode()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	view(preview.palette.config.preview.overview)
	preview.set_proposed(false)
	var before := await measure()
	preview.set_proposed(true)
	var after := await measure()
	var result := {"before":before,"after":after,"gpu":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),"viewport":[1280,720],
		"renderer":RenderingServer.get_current_rendering_method(),"conditions":"same camera/light, editing map frozen, 120 display-frame warmup and 8 s each, VSync/cap disabled, not GPU timing"}
	var file := FileAccess.open(output_dir+"benchmark.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t")+"\n")
	file.close()
	Engine.max_fps = old_cap
	DisplayServer.window_set_vsync_mode(old_sync)
	print("Palette benchmark: ",result)
