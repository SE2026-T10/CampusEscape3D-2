extends SceneTree

## Normal-scene QA fixture. Movie: live G3 and staged clip gallery. Benchmark:
## nine live AI actors, uncapped display frames, fixed courtyard camera.
const BASE := "res://maps/isg_museum/"
const ReportPaths := preload("res://maps/isg_museum/tools/report_paths.gd")
const OUT := BASE+"docs/reports/guard-art-v1/"
var level: Node3D
var camera: Camera3D
var g3
var phases := []

var output_dir := OUT

func out_path(filename: String) -> String:
	return ReportPaths.artifact(output_dir,filename)

func _initialize() -> void:
	output_dir = ReportPaths.output_root(OUT)
	run.call_deferred()

func frames(count: int) -> void:
	for i in count:
		await process_frame
		if is_instance_valid(g3):
			var phase: String = g3.phase
			if phases.is_empty() or phases[-1].phase != phase:
				phases.append({"phase":phase,"position":str(g3.position),"animation":g3.get_node("Presentation").current_animation})

func photo(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_path(name+".png"))

func run() -> void:
	root.size = Vector2i(1280,720)
	level = load(BASE+"scenes/museum.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = 65
	level.get_node("Player").set_physics_process(false)
	level.get_node("Player").position = Vector3(18,0,35)
	for node in level.get_children():
		if node is CanvasLayer: node.hide()
	for node in get_nodes_in_group("debug_visuals"):
		if node is Node3D: node.hide()
	if "--benchmark" in OS.get_cmdline_user_args():
		await benchmark()
	elif "--tour" in OS.get_cmdline_user_args():
		await tour()
	else:
		await movie()
	current_scene = null
	level.free()
	camera.free()
	quit()

func tour() -> void:
	var actors := []
	for child in level.get_children():
		if not child is Guard: continue
		for i in 45:
			var target: Vector3 = child.global_position+Vector3(0,.95,0)
			var desired: Vector3 = target-child.global_basis.z*2.3+child.global_basis.x*.7+Vector3.UP*.3
			var hit: Dictionary = child.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(target,desired,1))
			camera.position = target+(hit.position-target)*.85 if not hit.is_empty() else desired
			camera.look_at(target)
			await frames(1)
		await photo("tour-"+String(child.name))
		actors.append({"name":child.name,"physics_active":child.is_physics_processing(),"animation":child.get_node("Presentation").current_animation})
	FileAccess.open(out_path("tour.json"),FileAccess.WRITE).store_string(JSON.stringify(actors,"\t")+"\n")

func movie() -> void:
	# Keep AI/sensors active; disable only the terminal caught overlay in this QA instance.
	level.get_node("StealthDirector").set_physics_process(false)
	g3 = level.get_node("Guard_G3")
	camera.position = Vector3(34,1.45,14.3)
	camera.look_at(Vector3(34.1,.85,12))
	await frames(45)
	await photo("g3-sleep")
	g3.hear_noise(Vector3(31,0,12),1.0)
	await frames(45)
	await photo("g3-observing")
	var player := level.get_node("Player") as Node3D
	# Brief actual sighting triggers the existing suspicious-sight search rule.
	player.position = Vector3(33.8,0,13.6)
	g3.face_yaw(3.0)
	for i in 90:
		await frames(1)
		if g3.phase == &"searching": break
	player.position = Vector3(18,0,35)
	await frames(60)
	await photo("g3-search")
	# A real visible target supplies the chase; do not change its state machine.
	player.position = g3.position-g3.global_basis.z*2.4
	await frames(65)
	await photo("g3-chase")
	player.position = Vector3(18,0,35)
	for i in 1500:
		camera.position = g3.position+Vector3(0,1.45,2.2)
		camera.look_at(g3.position+Vector3(0,.85,0))
		await frames(1)
		if i > 120 and g3.phase==&"sleeping": break
	camera.position = Vector3(34,1.45,14.3)
	camera.look_at(Vector3(34.1,.85,12))
	await frames(15)
	await photo("g3-returned")
	print("Live G3 phases: ",phases)
	FileAccess.open(out_path("g3-phases.json"),FileAccess.WRITE).store_string(JSON.stringify(phases,"\t")+"\n")
	# Isolated poses are labelled clip QA, distinct from the preceding live sequence.
	level.process_mode = Node.PROCESS_MODE_DISABLED
	var visual: Node3D = load(BASE+"scenes/npc/museum_guard_visual.tscn").instantiate()
	root.add_child(visual)
	visual.position = Vector3(18,0,27)
	var anim := visual.get_node("AnimationPlayer") as AnimationPlayer
	camera.position = Vector3(19.9,1.2,24.5)
	camera.look_at(visual.position+Vector3(0,.9,0))
	for name in ["idle","walk","run","look_around","sit_down","stand_up"]:
		anim.play(name,.2)
		await frames(30)
		await photo("clip-"+name)
		await frames(45)
	visual.free()

func percentile(values: Array, q: float) -> float:
	return values[mini(values.size()-1,int(q*values.size()))]

func benchmark() -> void:
	var old_cap := Engine.max_fps
	var old_sync := DisplayServer.window_get_vsync_mode()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	camera.position = Vector3(18,1.65,22.8)
	camera.look_at(Vector3(18,3.7,14))
	await frames(180)
	var intervals := []
	var draws := []
	var primitives := []
	var memory := []
	var start := Time.get_ticks_usec()
	var previous := start
	while Time.get_ticks_usec()-start < 30000000:
		await process_frame
		var now := Time.get_ticks_usec()
		intervals.append((now-previous)/1000.0)
		previous = now
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		memory.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0)
	intervals.sort()
	draws.sort()
	primitives.sort()
	memory.sort()
	var actors := []
	for child in level.get_children():
		if child is Guard: actors.append({"name":child.name,"physics_active":child.is_physics_processing(),"animation":child.get_node("Presentation").current_animation})
	var result := {"renderer":"GL Compatibility","gpu":RenderingServer.get_video_adapter_name(),"cpu":OS.get_processor_name(),"viewport":[1280,720],
		"duration_seconds":30,"vsync":false,"frame_cap":0,"frames":intervals.size(),"guards":actors,
		"process_frame_interval_ms":{"p50":percentile(intervals,.5),"p95":percentile(intervals,.95),"p99":percentile(intervals,.99)},
		"draw_calls_p50":percentile(draws,.5),"primitives_p50":percentile(primitives,.5),"render_memory_mib_p50":percentile(memory,.5),
		"gpu_timing":"not available; process intervals are not GPU times","conditions":"static courtyard camera, 9 AI active, player stationary outside"}
	FileAccess.open(out_path("benchmark.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	Engine.max_fps = old_cap
	DisplayServer.window_set_vsync_mode(old_sync)
	print("Benchmark complete: ",result.process_frame_interval_ms)
