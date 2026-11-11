extends SceneTree

## Real GL Compatibility frames, captured offline; never used by the game.
const OUT := "res://maps/isg_museum/docs/environment-art-v1/"
var level: Node3D
var camera: Camera3D
var measurements: Array = []

func _initialize() -> void:
	run.call_deferred()

func shot(id: String, at: Vector3, target: Vector3) -> void:
	camera.position = at
	camera.look_at(target)
	for i in 90:
		await process_frame
	var frame_times: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in 180:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times.append((now-previous)/1000.0)
		previous = now
	var mean := 0.0
	for sample in frame_times:
		mean += sample/frame_times.size()
	frame_times.sort()
	await RenderingServer.frame_post_draw
	var prefix := "baseline-" if "--baseline" in OS.get_cmdline_user_args() else ""
	root.get_texture().get_image().save_png(OUT + prefix + id + ".png")
	measurements.append({"shot": id, "mean_fps": 1000.0/mean,
		"mean_frame_ms": mean,"p95_frame_ms":frame_times[int(frame_times.size()*.95)],
		"viewport": [root.get_texture().get_width(),root.get_texture().get_height()],
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"video_memory": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
	print("Captured ", prefix, id)

func run() -> void:
	root.size = Vector2i(1280, 720)
	var scene_path := "res://maps/isg_museum/scenes/museum.tscn"
	if "--baseline" in OS.get_cmdline_user_args():
		scene_path = OUT+"baseline-source/museum.tscn"
	level = load(scene_path).instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	level.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false
	for child in level.get_children():
		if child is CanvasLayer:
			child.hide()
	for node in get_nodes_in_group("debug_visuals"):
		if node is Node3D:
			node.hide()
	camera = Camera3D.new()
	level.add_child(camera)
	camera.current = true
	camera.fov = 78
	await shot("01-courtyard", Vector3(18,1.65,22.5), Vector3(18,4.8,12))
	var player := level.get_node("Player") as FirstPersonPlayer
	player.position = Vector3(14,0,12.1)
	player.set_crouching(true)
	player.head.position.y = player.crouch_eye_height
	await shot("02-cover", Vector3(13.55,0.78,12.05), Vector3(14,1.15,10))
	# Cutaway is a capture-only visibility change. Saved runtime floors stay intact.
	var geometry := level.get_node("NavigationRegion3D/Geometry")
	var original_visibility := {}
	var original_transforms := {}
	for node in level.find_children("*","Node3D",true,false):
		original_visibility[node] = node.visible
		original_transforms[node] = node.transform
	for group in ["EnvironmentArt/Roof", "EnvironmentArt/Ceilings"]:
		if geometry.has_node(group):
			geometry.get_node(group).hide()
	root.size = Vector2i(1280,1280)
	root.content_scale_size = Vector2i(1280,1280)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 43
	await shot("04-floor-2", Vector3(18,44,35), Vector3(18,4.5,16))
	for node in geometry.find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = node.global_transform * node.get_aabb()
		if bounds.position.y >= 4.1 or (node.get_meta("art_batch",false) and bounds.end.y > 4.6):
			node.hide()
		elif node.get_parent().get_parent() == geometry.get_node("Exterior") and bounds.size.y > 8.5:
			node.scale.y *= .5
			node.position.y -= 2.25
	if geometry.has_node("EnvironmentArt/Arcade"):
		var arcade := geometry.get_node("EnvironmentArt/Arcade")
		for node in arcade.find_children("*","MeshInstance3D",true,false):
			var bounds: AABB = node.global_transform*node.get_aabb()
			if not node.get_meta("art_batch",false) and bounds.end.y <= 4.6:
				node.show()
				var parent := node.get_parent()
				while parent != arcade:
					parent.show()
					parent = parent.get_parent()
	for node in level.find_children("*","Area3D",true,false):
		if node.global_position.y >= 4.1:
			node.hide()
	for id in ["Guard_G6","Guard_G7","Guard_G8","Guard_G9"]:
		level.get_node(id).hide()
	await shot("03-floor-1", Vector3(18,44,35), Vector3(18,0,16))
	# Restore visuals for eye-level room evidence.
	for node in original_visibility:
		node.visible = original_visibility[node]
		node.transform = original_transforms[node]
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	var seated := level.get_node("Guard_G3")
	seated.go_to_sleep()
	seated.get_node("Presentation")._process(0)
	await shot("05-staff", Vector3(28.8,1.65,16), Vector3(33,1.2,11.7))
	var exhibit := level.get_node("NavigationRegion3D/ExhibitsExpansion/S2")
	level.get_node("MuseumContract").accept_contract()
	player.position = Vector3(7,0,18)
	player.set_crouching(false)
	player.head.position.y = player.stand_eye_height
	# Invoke the production interaction, preserving the independent case states.
	assert(exhibit.interact(player) and exhibit.broken,"Capture requires a real glass-break interaction")
	await shot("06-broken-glass", Vector3(7,1.7,19.6), exhibit.global_position)
	var map_ui := get_first_node_in_group("museum_service_ui")
	map_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	var wall_map := level.get_node("NavigationRegion3D/ServiceExpansion/WallMap")
	player.position = Vector3(32,0,26)
	assert(wall_map.interact(player),"Capture requires the real map interaction")
	await shot("07-map-ui",Vector3(32,1.65,26),wall_map.global_position)
	map_ui.close_panel()
	var calendar := get_first_node_in_group("staff_calendar")
	player.position = Vector3(28.7,0,16)
	get_first_node_in_group("staff_reader").show()
	assert(calendar.interact(player),"Capture requires the real calendar interaction")
	await shot("08-calendar-ui",Vector3(28.7,1.65,16),calendar.global_position)
	get_first_node_in_group("staff_reader").close_document()
	var prefix := "baseline-" if "--baseline" in OS.get_cmdline_user_args() else ""
	var file := FileAccess.open(OUT + prefix + "render-metrics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "samples": measurements}, "\t"))
	level.free()
	quit()
