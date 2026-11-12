extends SceneTree

## Render and real-time gameplay measurement only. No screenshots or project edits.
const BASE := "res://maps/isg_museum/"
const OUT := BASE+"docs/environment-art-v1_1/"
const VIEWS := [
	["courtyard",Vector3(18,1.65,22.5),Vector3(18,4.8,12)],
	["cover",Vector3(13.55,.78,12.05),Vector3(14,1.15,10)],
	["staff",Vector3(28.8,1.65,16),Vector3(33,1.2,11.7)],
	["sculpture",Vector3(7,1.7,19.6),Vector3(4.3,1.7,18)]]
var level: Node3D
var player: FirstPersonPlayer
var rows: Array = []
var events: Array = []
var stopped := false
var old_fps: int
var old_vsync: int
var old_low_usage: bool
var old_sleep: int
var old_window_mode: int
var old_window_size: Vector2i
var old_window_position: Vector2i
var chase_frames := 0
var carry_frames := 0
var visited: Array[String] = []
var live := false
var before := false

func _initialize() -> void:
	run.call_deferred()

func percentile(values: Array, fraction: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(ceil(sorted.size()*fraction))-1,0,sorted.size()-1)] if not sorted.is_empty() else 0.0

func sample(seconds: float, id: String) -> Dictionary:
	var times: Array = []
	var gpu: Array = []
	var draw: Array = []
	var primitives: Array = []
	var memory: Array = []
	var started := Time.get_ticks_usec()
	var previous := started
	while Time.get_ticks_usec()-started < seconds*1000000:
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now-previous)/1000.0
		previous = now
		var calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var count := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var mem := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
		var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		var chasing := 0
		for guard in get_nodes_in_group("guards"):
			chasing += int(guard.machine.current == GuardStateMachine.CHASE)
		var carried: bool = player.is_carrying()
		chase_frames += int(chasing > 0)
		carry_frames += int(carried)
		rows.append([id,ms,calls,count,mem,gpu_ms,chasing,int(carried)])
		times.append(ms)
		gpu.append(gpu_ms)
		draw.append(calls)
		primitives.append(count)
		memory.append(mem)
	var total := 0.0
	for ms in times:
		total += ms
	return {"view":id,"seconds":seconds,"frames":times.size(),"mean_fps":times.size()*1000.0/total,
		"frame_interval_ms":{"p50":percentile(times,.5),"p95":percentile(times,.95),"p99":percentile(times,.99)},
		"draw_calls":{"p50":percentile(draw,.5),"p95":percentile(draw,.95)},
		"primitives":{"p50":percentile(primitives,.5),"p95":percentile(primitives,.95)},
		"render_memory_bytes_peak":percentile(memory,1),
		"gpu_render_ms_p95":percentile(gpu,.95) if percentile(gpu,1) > 0 else null}

func wait_seconds(seconds: float) -> void:
	var until := Time.get_ticks_usec()+int(seconds*1000000)
	while Time.get_ticks_usec() < until:
		await process_frame

func run() -> void:
	before = "--before" in OS.get_cmdline_user_args()
	live = "--gameplay" in OS.get_cmdline_user_args() or "--course-check" in OS.get_cmdline_user_args()
	var seconds := 180.0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seconds="):
			seconds = float(argument.get_slice("=",1))
	seed(110012)
	var scene_path := OUT+"before-source/museum.tscn" if before else BASE+"scenes/museum.tscn"
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	level = load(scene_path).instantiate()
	root.add_child(level)
	current_scene = level
	for i in 8:
		await physics_frame
	var flow := level.get_node("GameFlow") as GameFlow
	if flow.state == GameStateMachine.State.PAUSED:
		flow.resume()
	player = level.get_node("Player")
	old_fps = Engine.max_fps
	old_vsync = DisplayServer.window_get_vsync_mode()
	old_low_usage = OS.low_processor_usage_mode
	old_sleep = OS.low_processor_usage_mode_sleep_usec
	old_window_mode = DisplayServer.window_get_mode()
	old_window_size = DisplayServer.window_get_size()
	old_window_position = DisplayServer.window_get_position()
	if "--exclusive" in OS.get_cmdline_user_args():
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	await process_frame
	if flow.state == GameStateMachine.State.PAUSED:
		flow.resume()
	var summary := {"before":before,"mode":"gameplay" if live else "render_only",
		"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),
		"gpu":RenderingServer.get_video_adapter_name(),"viewport":[1280,720],"warmup_seconds":3,
		"vsync_mode":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,
		"low_processor_usage_mode":OS.low_processor_usage_mode,"samples":[],"guards":get_nodes_in_group("guards").size()}
	summary["window_mode"] = DisplayServer.window_get_mode()
	summary["viewport"] = [root.get_texture().get_width(),root.get_texture().get_height()]
	if live:
		# Controlled continuous course: only terminal capture is suppressed in this
		# temporary instance. All 9 guard AI, vision, hearing and body collisions run.
		var director := level.get_node("StealthDirector")
		var catch_distance: float = director.catch_distance
		director.catch_distance = -1
		get_first_node_in_group("museum_contract").accept_contract()
		get_first_node_in_group("museum_contract_ui").close_sheet()
		get_first_node_in_group("museum_contract").grant_ticket()
		level.get_node("ObjectiveManager").complete(&"take_key")
		summary["fixture"] = "V and K access granted; terminal catch disabled; actual input movement, T2 pickup/delivery; all actor collisions and perception unchanged"
		player.camera.current = true
		_drive.call_deferred()
		await wait_seconds(3)
		summary.samples.append(await sample(seconds,"active_9_guards"))
		stopped = true
		Input.action_release("move_forward")
		Input.action_release("sprint")
		# Let the input coroutine return before freeing its player/guard references.
		await physics_frame
		await process_frame
		director.catch_distance = catch_distance
		summary["visited"] = visited
		summary["events"] = events
		summary["chase_render_frames"] = chase_frames
		summary["carried_render_frames"] = carry_frames
		summary["t2_delivered"] = level.get_node("Interactables/Painting_T2").state == 3
		var active_guards: Array = []
		for guard in get_nodes_in_group("guards"):
			active_guards.append({"id":str(guard.name),"state":guard.machine.current,
				"physics_enabled":guard.is_physics_processing() and guard.process_mode != Node.PROCESS_MODE_DISABLED})
		summary["guard_states_at_end"] = active_guards
		summary["scene_tree_paused"] = paused
		summary["course_valid"] = "stair_a_top" in visited and "stair_b_bottom" in visited and "courtyard" in visited \
			and "depot" in visited and summary.t2_delivered and carry_frames > 0 and chase_frames > 0 and not paused
	else:
		level.process_mode = Node.PROCESS_MODE_DISABLED
		var diagnostic := ""
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--diagnostic-"):
				diagnostic = argument.trim_prefix("--diagnostic-")
		var measurement_views: Array = VIEWS
		if not diagnostic.is_empty():
			measurement_views = [VIEWS[0],VIEWS[2]]
			var art := level.get_node("NavigationRegion3D/Geometry/EnvironmentArt")
			if diagnostic == "no-fill":
				for node in art.get_children():
					if node is OmniLight3D:
						node.hide()
			elif diagnostic == "no-new-foliage":
				for node in art.get_children():
					if str(node.name).begins_with("Tree") or str(node.name).begins_with("HedgeLeaves_"):
						node.hide()
			elif diagnostic == "v1-sun":
				var baseline := load(OUT+"before-source/museum.tscn").instantiate() as Node3D
				level.get_node("DirectionalLight3D").rotation = baseline.get_node("DirectionalLight3D").rotation
				baseline.free()
			summary["mode"] = "render_diagnostic_"+diagnostic
		for child in level.get_children():
			if child is CanvasLayer:
				child.hide()
		for node in get_nodes_in_group("debug_visuals"):
			if node is Node3D:
				node.hide()
		var camera := Camera3D.new()
		level.add_child(camera)
		camera.current = true
		camera.fov = 78
		for view in measurement_views:
			camera.position = view[1]
			camera.look_at(view[2])
			await wait_seconds(3)
			summary.samples.append(await sample(6,view[0]))
	var id := ("before-" if before else "after-")+("gameplay" if live else "render")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--diagnostic-"):
			id = "after-render-"+argument.trim_prefix("--diagnostic-")
	if "--course-check" in OS.get_cmdline_user_args():
		id = "course-check"
		summary["mode"] = "headless_fixed_fps_course_check_not_a_benchmark"
	var output := FileAccess.open(OUT+id+".json",FileAccess.WRITE)
	var csv := FileAccess.open(OUT+id+"-frames.csv",FileAccess.WRITE)
	csv.store_line("view,frame_interval_ms,draw_calls,primitives,render_memory_bytes,gpu_render_ms,guards_chasing,carrying")
	for row in rows:
		var fields := PackedStringArray()
		for value in row:
			fields.append(str(value))
		csv.store_line(",".join(fields))
	Engine.max_fps = old_fps
	DisplayServer.window_set_vsync_mode(old_vsync)
	OS.low_processor_usage_mode = old_low_usage
	OS.low_processor_usage_mode_sleep_usec = old_sleep
	DisplayServer.window_set_mode(old_window_mode)
	DisplayServer.window_set_size(old_window_size)
	DisplayServer.window_set_position(old_window_position)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),false)
	summary["settings_restored"] = Engine.max_fps == old_fps and DisplayServer.window_get_vsync_mode() == old_vsync \
		and OS.low_processor_usage_mode == old_low_usage and OS.low_processor_usage_mode_sleep_usec == old_sleep \
		and DisplayServer.window_get_mode() == old_window_mode
	output.store_string(JSON.stringify(summary,"\t"))
	print("Museum benchmark ",id,": ",JSON.stringify(summary))
	level.free()
	quit(0 if not live or summary.course_valid else 1)

func _drive() -> void:
	# Explicit player waypoints cross each doorway from its approach side. The
	# player's route must not replan through a different floor when a link is shut.
	# Guards retain their production NavigationAgents and perception throughout.
	var course := [
		["lobby",Vector3(18,0,28.5)],["stair_a_entry",Vector3(10.5,0,27)],
		["stair_a_door",Vector3(8,0,27)],["stair_a_bottom",Vector3(7.4,0,28.25)],
		["stair_a_landing_s",Vector3(1.2,2.25,28.25)],["stair_a_landing_n",Vector3(1.2,2.25,25.75)],
		["stair_a_top",Vector3(7.5,4.5,25.75)],["stair_a_exit",Vector3(8,4.5,27)],
		["upper_south_entry",Vector3(10.5,4.5,27)],["south_buffer",Vector3(18,4.5,27)],
		["south_portal",Vector3(18,4.5,22.5)],["upper_southeast",Vector3(25.5,4.5,22.5)],
		["gallery_b_approach",Vector3(25.5,4.5,10)],["gallery_b",Vector3(28.7,4.5,10)],
		["pickup_t2",Vector3(34.3,4.5,10)],["carry_wall_north",Vector3(34.3,4.5,8.5)],
		["carry_room_west",Vector3(28.7,4.5,8.5)],["carry_room_exit",Vector3(28.7,4.5,10)],
		["carry_corridor",Vector3(25.5,4.5,10)],["carry_southeast",Vector3(25.5,4.5,22.5)],
		["carry_south",Vector3(18,4.5,22.5)],["carry_buffer",Vector3(18,4.5,27)],
		["depot_approach",Vector3(25.5,4.5,27)],
		["warehouse_entry",Vector3(28.5,4.5,27)],["depot",Vector3(32,4.5,27.5)],
		["warehouse_exit",Vector3(25.5,4.5,27)],["return_buffer",Vector3(18,4.5,27)],
		["return_south",Vector3(18,4.5,22.5)],["return_southeast",Vector3(25.5,4.5,22.5)],
		["upper_north_ring",Vector3(25.5,4.5,7.5)],["gallery_c_approach",Vector3(23,4.5,7.5)],
		["gallery_c",Vector3(23,4.5,4.5)],["north_room_east",Vector3(25.5,4.5,4.5)],
		["stair_b_approach",Vector3(25.5,4.5,3)],
		["stair_b_entry",Vector3(28,4.5,3)],["stair_b_top",Vector3(28.5,4.5,1.75)],
		["stair_b_landing_n",Vector3(34.8,2.25,1.75)],["stair_b_landing_s",Vector3(34.8,2.25,4.25)],
		["stair_b_bottom",Vector3(28.6,0,4.25)],["history_approach",Vector3(28,0,3)],
		["history_entry",Vector3(25.5,0,3)],["history_east",Vector3(25.5,0,4.5)],
		["history_south",Vector3(15,0,4.5)],["history",Vector3(15,0,3)],
		["history_south_portal",Vector3(15,0,7.5)],["courtyard_approach",Vector3(18,0,7.5)],
		["courtyard",Vector3(18,0,11.5)],
		["ring_east",Vector3(21.1,0,15)],["ring_south",Vector3(18,0,18.1)],
		["ring_west",Vector3(14.9,0,15)],["ring_north",Vector3(18,0,11.9)],
		["yard_exit",Vector3(18,0,7.5)],["ground_northeast",Vector3(25.5,0,7.5)],
		["staff_approach",Vector3(25.5,0,10)],["staff_entry",Vector3(29,0,10)],
		["staff",Vector3(29,0,12)],["staff_exit",Vector3(29,0,10)],
		["ground_east",Vector3(25.5,0,10)],["south_ring",Vector3(25.5,0,22.5)],
		["lobby_approach",Vector3(18,0,22.5)]]
	var index := 0
	var next_trace := Time.get_ticks_msec()+10000
	while not stopped:
		await physics_frame
		if stopped:
			break
		var target: Vector3 = course[index][1]
		if Time.get_ticks_msec() >= next_trace:
			print("Course progress: ",course[index][0]," at ",player.position," carrying=",player.is_carrying())
			next_trace = Time.get_ticks_msec()+10000
		for door in get_nodes_in_group("museum_doors")+get_nodes_in_group("museum_ticket_doors"):
			if door.name == &"Storage" or door.is_open or absf(door.global_position.y-player.position.y) > .6:
				continue
			if Vector2(door.global_position.x-player.position.x,door.global_position.z-player.position.z).length() < 1.9:
				door.interact(player)
		if Vector2(target.x-player.position.x,target.z-player.position.z).length() < .25 and absf(target.y-player.position.y) < .4:
			var id: String = course[index][0]
			if not id in visited:
				visited.append(id)
				events.append({"event":id,"position":str(player.position),"time_usec":Time.get_ticks_usec()})
				print("Course reached: ",id," ",player.position)
			if id == "pickup_t2":
				var painting := level.get_node("Interactables/Painting_T2")
				if painting.state == 0:
					player.camera.look_at(painting.global_position)
					painting.interact(player)
			if id == "depot" and player.is_carrying():
				level.get_node("Interactables/T2Depot").interact(player)
			index = (index+1)%course.size()
			target = course[index][1]
		var offset := target-player.position
		offset.y = 0
		if offset.length() > .06:
			var direction := clear_direction(offset.normalized())
			player.rotation.y = atan2(-direction.x,-direction.z)
			player.head.rotation = Vector3.ZERO
			player.camera.rotation = Vector3.ZERO
			Input.action_press("move_forward")
			if not player.is_carrying():
				Input.action_press("sprint")
			else:
				Input.action_release("sprint")
		else:
			Input.action_release("move_forward")

func clear_direction(wanted: Vector3) -> Vector3:
	# Reactive input steering checks the real capsule against both world and NPCs.
	# Lifting this look-ahead query 30 cm avoids rejecting a walkable stair slope;
	# actual movement still uses the untouched grounded player controller.
	var shape := player.get_node("CollisionShape3D") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.collision_mask = 5
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	for angle in [0.0,.35,-.35,.7,-.7,1.05,-1.05,1.4,-1.4,1.75,-1.75,2.1,-2.1,2.8,-2.8,PI]:
		var direction := wanted.rotated(Vector3.UP,angle)
		query.transform = shape.global_transform
		query.transform.origin += direction*.6+Vector3.UP*.3
		if level.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			return direction
	return wanted
