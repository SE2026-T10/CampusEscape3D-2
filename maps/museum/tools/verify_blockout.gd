extends SceneTree

## Runtime integration checks: actual player movement, map paths, closed/open
## doors, courtyard void, and two complete patrol loops for every guard.
## Run with --headless --fixed-fps 60 --script res://maps/museum/tools/verify_blockout.gd
const SCENE := "res://maps/museum/scenes/museum.tscn"
var level: Node3D
var failures := 0
var checks := 0
var arrivals := [[], [], []]
var stuck := [0, 0, 0]


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, caption: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", caption)
	else:
		failures += 1
		push_error(caption)


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func ray(from: Vector3, to: Vector3) -> Dictionary:
	return level.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to, 1))


func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(level.get_world_3d().navigation_map, from, to, true)


func connected(from: Vector3, to: Vector3) -> bool:
	var points := path(from, to)
	return not points.is_empty() and points[-1].distance_to(to) < 0.8


func walk(player: FirstPersonPlayer, points: Array) -> bool:
	player.set_physics_process(true)
	var success := true
	for destination: Vector3 in points:
		var reached := false
		for tick in 480:
			var offset := destination-player.position
			offset.y = 0
			if offset.length() < 0.16:
				reached = absf(player.position.y-destination.y) < 0.22
				break
			player.rotation.y = atan2(-offset.x, -offset.z)
			Input.action_press("move_forward")
			await physics_frame
		Input.action_release("move_forward")
		await frames(10)
		if not reached:
			print("WALK FAILED: wanted ", destination, " actual ", player.position)
			success = false
			break
	player.set_physics_process(false)
	return success


func push_against_door(player: FirstPersonPlayer, at: Vector3, yaw: float) -> void:
	player.position = at
	player.rotation.y = yaw
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	Input.action_press("move_forward")
	await frames(90)
	Input.action_release("move_forward")
	await frames(10)
	player.set_physics_process(false)


func _run() -> void:
	level = (load(SCENE) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	var player := level.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	player.get_node("Noise").set_physics_process(false)
	level.get_node("StealthDirector").set_physics_process(false)
	var guards: Array[Guard] = []
	for i in 3:
		var guard := level.get_node("Guard_G%d" % (i+1)) as Guard
		guards.append(guard)
		guard.set_physics_process(false)
		guard.agent.avoidance_enabled = false
		guard.vision.set_physics_process(false)
		guard.vision.reset()
		guard.hearing.set_physics_process(false)
		guard.get_node("Presentation").process_mode = Node.PROCESS_MODE_DISABLED
		guard.patrol_point_reached.connect(func(index: int): arrivals[i].append(index))
		guard.got_stuck.connect(func(_index: int): stuck[i] += 1)
	await frames(12)
	var navigation := level.get_node("NavigationRegion3D").navigation_mesh as NavigationMesh
	check(navigation.geometry_parsed_geometry_type == NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		and navigation.geometry_collision_mask == 1, "Navigation bakes only world static colliders")
	print("Slope limits: Player %.1f, Guard %.1f, Navigation %.1f degrees" % [
		rad_to_deg(player.floor_max_angle), rad_to_deg(guards[0].floor_max_angle), navigation.agent_max_slope])
	for stair_name in ["StairA", "StairB"]:
		for flight_name in ["LowerRamp", "UpperRamp"]:
			var ramp := level.get_node("NavigationRegion3D/Geometry/%s/%s" % [stair_name,flight_name]) as StaticBody3D
			var angle := ramp.global_basis.y.angle_to(Vector3.UP)
			check(angle < player.floor_max_angle and angle < guards[0].floor_max_angle
				and rad_to_deg(angle) < navigation.agent_max_slope and ramp.collision_layer == 1,
				"%s/%s smooth collision slope %.2f degrees is below all climb limits" % [stair_name,flight_name,rad_to_deg(angle)])
	check(player.position.is_equal_approx(Vector3(18,0.1,28.5)) and player.rotation.is_zero_approx(), "Player starts in southern lobby facing -Z")
	var hit := ray(Vector3(18,8,18), Vector3(18,-1,18))
	check(not hit.is_empty() and absf(hit.position.y) < 0.01, "Courtyard has ground floor and no upper slab")
	for sample in [Vector3(18,8,4.5),Vector3(18,8,25.5),Vector3(6,8,15),Vector3(30,8,15)]:
		hit = ray(sample, sample-Vector3(0,10,0))
		check(not hit.is_empty() and absf(hit.position.y-4.5) < 0.01, "Upper floor band at " + str(sample))
	for sample in [Vector3(4.5,8,28.25),Vector3(4.5,8,25.75),Vector3(31.5,8,4.25),Vector3(31.5,8,1.75)]:
		hit = ray(sample, sample-Vector3(0,10,0))
		check(not hit.is_empty() and hit.position.y < 4, "Open stair headroom above " + str(sample))
	for edge in [[Vector3(18,5,8),Vector3(18,5,10)], [Vector3(18,5,22),Vector3(18,5,20)], [Vector3(11,5,15),Vector3(13,5,15)], [Vector3(25,5,15),Vector3(23,5,15)]]:
		check(not ray(edge[0],edge[1]).is_empty(), "Upper courtyard collision railing " + str(edge[0]))
	var spawn := player.position
	for target in [Vector3(31.5,.1,13),Vector3(6.5,.1,12),Vector3(18,.1,3),Vector3(18,.1,18),Vector3(30,.1,21),Vector3(30,.1,27),Vector3(3,4.6,12),Vector3(18,4.6,2),Vector3(32,4.6,24),Vector3(34,4.6,27)]:
		check(connected(spawn,target), "Navmesh reaches room/goal " + str(target))
	var corridor := Vector3(25.5,4.6,10)
	var gallery := Vector3(29,4.6,10)
	var store := Vector3(32,4.6,19.5)
	check(not connected(corridor,gallery) and not connected(store,gallery), "Closed doors isolate B from both corridor and restoration")
	var doors := level.get_node("NavigationRegion3D/Doors")
	player.position = Vector3(24.5,4.6,27)
	player.velocity = Vector3.ZERO
	check(await walk(player,[Vector3(28.5,4.5,27),Vector3(32,4.5,27),Vector3(32,4.5,24.5)])
		and not level.get_node("ObjectiveManager").is_completed(&"take_key")
		and not doors.get_node("GalleryB").is_open and not doors.get_node("RestorationShortcut").is_open,
		"Player reaches rope aisle through southern restoration entrance before key or either door opens")
	await push_against_door(player,corridor,-PI/2)
	check(player.position.x < 26.7 and absf(player.position.z-10) < 0.2,
		"Locked gallery panel physically stops Player walking east")
	await push_against_door(player,store,0.0)
	check(player.position.z > 18.3 and absf(player.position.x-32) < 0.2,
		"Unopened shortcut physically blocks entry from restoration")
	level.get_node("ObjectiveManager").complete(&"take_key")
	player.position = corridor
	check(doors.get_node("GalleryB").interact(player), "Key opens gallery door")
	await frames(5)
	check(connected(corridor,gallery), "Opening gallery door enables traversable navigation link")
	player.position = corridor
	player.velocity = Vector3.ZERO
	check(await walk(player,[Vector3(29,4.5,10)]), "Player physically passes through opened gallery door")
	player.position = Vector3(32,4.5,16.5)
	check(doors.get_node("RestorationShortcut").interact(player), "B-side latch opens shortcut")
	await frames(5)
	var shortcut_path := path(Vector3(32,4.6,16.5),store)
	check(connected(Vector3(32,4.6,16.5),store) and shortcut_path.size() <= 6, "Opened shortcut supplies a direct path into restoration")
	player.position = Vector3(32,4.5,16.5)
	player.velocity = Vector3.ZERO
	check(await walk(player,[Vector3(32,4.5,19.5),Vector3(32,4.5,16.5)]), "Player physically crosses opened shortcut in both directions")
	# Two stairs must each work locally, rather than silently using the other stair.
	for mirror in [false,true]:
		var lower := Vector3(8,0.1,28.25) if not mirror else Vector3(28,0.1,4.25)
		var upper := Vector3(8,4.6,25.75) if not mirror else Vector3(28,4.6,1.75)
		var points := path(lower,upper)
		var local := connected(lower,upper)
		for point in points:
			local = local and (point.x < 9.5 and point.z > 23.5 if not mirror else point.x > 26.5 and point.z < 6.5)
		var stair_name := "A" if not mirror else "B"
		check(local, "Stair " + stair_name + " navmesh connects both levels locally")
		player.position = lower
		player.velocity = Vector3.ZERO
		var waypoints := [Vector3(7.4,0,28.25),Vector3(1.2,2.25,28.25),Vector3(1.2,2.25,25.75),Vector3(7.5,4.5,25.75),Vector3(8,4.5,27),Vector3(10,4.5,27)]
		if mirror:
			for i in waypoints.size():
				var p: Vector3 = waypoints[i]
				waypoints[i] = Vector3(36-p.x,p.y,p.z-24)
		check(await walk(player,waypoints), "Real standing Player walks UP stair " + stair_name + " through upper doorway")
		waypoints.reverse()
		waypoints.append(lower-Vector3(0,.1,0))
		check(await walk(player,waypoints), "Real standing Player walks DOWN stair " + stair_name)
		# Keep the player capsule away from the guard's ground-floor destination.
		player.position = spawn
		var test_guard := guards[0]
		test_guard.machine.current = GuardStateMachine.NONE
		test_guard.position = lower
		test_guard.velocity = Vector3.ZERO
		test_guard.set_physics_process(true)
		for destination in [upper,lower]:
			test_guard.navigate_to(destination, test_guard.patrol_speed)
			var reached := false
			for tick in 1500:
				await physics_frame
				if test_guard.position.distance_to(destination) < 0.6:
					reached = true
					break
			check(reached, "Guard follows stair " + stair_name + " navigation to " + str(destination))
		test_guard.set_physics_process(false)
	# Patrol at real speed with perception/noise isolated from traversal tests.
	player.position = Vector3(18,0.1,28.5)
	for guard in guards:
		guard.agent.avoidance_enabled = true
		guard.reset_to_start()
		guard.set_physics_process(true)
	for tick in 18000:
		await physics_frame
		var done := true
		for i in 3:
			done = done and arrivals[i].size() >= guards[i].patrol_route.get_point_count()*2+1
		if done:
			break
	for i in 3:
		var count := guards[i].patrol_route.get_point_count()
		var ordered: bool = arrivals[i].size() >= count*2+1
		for n in mini(arrivals[i].size(),count*2+1):
			ordered = ordered and arrivals[i][n] == n%count
		check(ordered and stuck[i] == 0, "Guard G%d completes two ordered patrol loops with no stuck events (%d arrivals)" % [i+1,arrivals[i].size()])
	check(guards[2].position.x > 27 and guards[2].position.z < 18 and guards[2].position.y > 4, "G3 remains inside gallery B on patrol")
	current_scene = null
	level.free()
	await frames(3)
	print("Museum blockout: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
