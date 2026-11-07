extends SceneTree

## Runtime integration checks: actual player movement, map paths, closed/open
## doors, courtyard void, and two complete patrol loops for every guard.
## Run with --headless --fixed-fps 60 --script res://maps/isg_museum/tools/verify_blockout.gd
const SCENE := "res://maps/isg_museum/scenes/museum.tscn"
var level: Node3D
var failures := 0
var checks := 0
var arrivals := [[], [], [], [], [], [], [], [], []]
var stuck := [0, 0, 0, 0, 0, 0, 0, 0, 0]
var stayed_inside := [true, true, true, true, true, true, true, true, true]


func inside_patrol_area(index: int, at: Vector3) -> bool:
	var base := 0.0 if index < 5 else 4.5
	if absf(at.y-base) > 0.3:
		return false
	match index:
		0, 5:
			return at.x > 0.5 and at.x < 8.6 and at.z > 6.4 and at.z < 23.6
		1, 6:
			return at.x > 0.5 and at.x < 26.6 and at.z > 0.5 and at.z < 5.6
		2, 7:
			return at.x > 27.4 and at.x < 35.5 and at.z > 6.4 and at.z < 17.6
		4:
			return at.x > 9.4 and at.x < 26.6 and at.z > 24.4 and at.z < 29.5
		3, 8:
			var in_ring := at.x > 9.4 and at.x < 26.6 and at.z > 6.4 and at.z < 23.6 \
				and not (at.x > 11.8 and at.x < 24.2 and at.z > 8.8 and at.z < 21.2)
			var in_buffer := index == 8 and at.x > 9.4 and at.x < 26.6 and at.z >= 23.6 and at.z < 29.5
			return in_ring or in_buffer
	return false


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


func use_door(door: Node3D, feet: Vector3) -> void:
	var player := level.get_node("Player") as FirstPersonPlayer
	player.position = feet
	player.velocity = Vector3.ZERO
	player.camera.look_at(door.global_position+Vector3(0,1.4,0))
	await frames(3)
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = &"interact"
	Input.parse_input_event(event)
	await process_frame
	await frames(5)


func _run() -> void:
	level = (load(SCENE) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	var player := level.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	player.get_node("Noise").set_physics_process(false)
	level.get_node("StealthDirector").set_physics_process(false)
	var guards: Array[Guard] = []
	for i in 9:
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
	check(player.position.is_equal_approx(Vector3(18,0.1,35)) and player.rotation.is_zero_approx(), "Player starts outside in front yard facing main entrance (-Z)")
	var entrance := level.get_node("NavigationRegion3D/Doors/Entrance") as Interactable
	var exterior_spawn := player.get_spawn_transform().origin
	check(not connected(exterior_spawn,Vector3(18,.1,28.5)), "Closed main entrance separates front yard from indoor navigation")
	var yard_hit := ray(Vector3(18,1,35),Vector3(18,-1,35))
	check(not yard_hit.is_empty() and absf(yard_hit.position.y) < 0.01, "New spawn has solid ground at Y=0")
	check(not ray(Vector3(1,.6,34),Vector3(-1,.6,34)).is_empty()
		and not ray(Vector3(35,.6,34),Vector3(37,.6,34)).is_empty()
		and not ray(Vector3(18,.6,37),Vector3(18,.6,39)).is_empty(), "Yard sides and street gate block walking off the level")
	check(await walk(player,[Vector3(18,0,31.4)]), "Player walks from exterior spawn up to main door")
	await push_against_door(player,Vector3(18,0,31.4),0)
	check(player.position.z > 30.3, "Closed main door physically stops Player before E")
	player.position = Vector3(18,0,31.4)
	player.camera.look_at(entrance.position+Vector3(0,1.4,0))
	await frames(3)
	check(player.get_node("Interactor").find_target() == entrance, "Main door is selectable by camera ray from outside")
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = &"interact"
	Input.parse_input_event(event)
	await frames(5)
	check(entrance.is_open and entrance.get_node("Panel").collision_layer == 0
		and not level.get_node("ObjectiveManager").is_completed(&"take_key"), "E opens main door freely without museum key")
	check(connected(exterior_spawn,Vector3(18,.1,28.5)), "Open main door links exterior and interior navmesh")
	check(await walk(player,[Vector3(18,0,28.5)]), "Player walks through opened main entrance into lobby")
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
	var spawn := exterior_spawn
	# This suite verifies traversal after access is earned; service/contract
	# suites separately exercise refusal without V and the dialogue that grants it.
	get_first_node_in_group("museum_contract").grant_ticket()
	for gate in get_nodes_in_group("museum_ticket_doors"):
		var approach := Vector3(10.5,4.5,27) if gate.name == &"TicketGate_A" else Vector3(25.5,4.5,3)
		await use_door(gate,approach)
	for target in [Vector3(34,.1,10.2),Vector3(6.5,.1,12),Vector3(18,.1,3),Vector3(18,.1,18),Vector3(30,.1,21),Vector3(30,.1,27),Vector3(3,4.6,12),Vector3(18,4.6,2),Vector3(32,4.6,24),Vector3(34,4.6,27)]:
		var door_id := ""
		if target.is_equal_approx(Vector3(30,0.1,27)):
			door_id = "Service"
		elif target.is_equal_approx(Vector3(34,0.1,10.2)):
			door_id = "Staff"
		elif target.is_equal_approx(Vector3(30,0.1,21)):
			door_id = "Storage"
		elif target.is_equal_approx(Vector3(32,4.6,24)) or target.is_equal_approx(Vector3(34,4.6,27)):
			door_id = "RestorationEntrance"
		if door_id != "":
			var entry: Interactable = level.get_node("NavigationRegion3D/Doors/"+door_id)
			check(not connected(spawn,target),"Closed " + door_id + " door isolates room navigation")
			if door_id == "Storage":
				player.position = Vector3(25.5,0,21)
				entry.submit_code(level.get_node("NavigationRegion3D/Doors/Storage").current_code(),player)
			else:
				entry.interact(player)
			# NavigationServer applies newly enabled links on a later physics tick.
			await frames(12)
			check(connected(spawn,target),"Opened " + door_id + " door connects room navigation")
			entry.interact(player)
			await frames(5)
		else:
			check(connected(spawn,target), "Navmesh reaches room/goal " + str(target))
	check(not ray(Vector3(25.5,1.4,15),Vector3(28.5,1.4,15)).is_empty(),"Former southern staff entrance is now solid wall")
	for sample in [["Staff",Vector3(25.5,0,10),Vector3(28.5,0,10)],
			["RestorationEntrance",Vector3(25.5,4.5,27),Vector3(28.5,4.5,27)]]:
		var entry: Interactable = level.get_node("NavigationRegion3D/Doors/"+sample[0])
		await push_against_door(player,sample[1],-PI/2)
		check(player.position.x < 26.7,"Closed " + sample[0] + " door physically stops player")
		await use_door(entry,sample[1])
		check(entry.is_open,"Camera E opens " + sample[0] + " from corridor")
		check(await walk(player,[sample[2]]),"Player crosses opened " + sample[0] + " doorway")
		await use_door(entry,sample[2])
		check(not entry.is_open and not ray(sample[1]+Vector3(0,1.4,0),sample[2]+Vector3(0,1.4,0)).is_empty(),
			"Camera E closes " + sample[0] + " from inside and blocks sight")
		await use_door(entry,sample[2])
		check(entry.is_open,"Camera E reopens " + sample[0] + " from inside")
		check(await walk(player,[sample[1]]),"Player returns through " + sample[0] + " doorway")
		await use_door(entry,sample[1])
	var corridor := Vector3(25.5,4.6,10)
	var gallery := Vector3(29,4.6,10)
	var store := Vector3(32,4.6,19.5)
	check(not connected(corridor,gallery) and not connected(store,gallery), "Closed doors isolate B from both corridor and restoration")
	var doors := level.get_node("NavigationRegion3D/Doors")
	player.position = Vector3(24.5,4.6,27)
	player.velocity = Vector3.ZERO
	await use_door(doors.get_node("RestorationEntrance"),Vector3(25.5,4.5,27))
	check(await walk(player,[Vector3(28.5,4.5,27),Vector3(32,4.5,27),Vector3(32,4.5,24.5)])
		and not level.get_node("ObjectiveManager").is_completed(&"take_key")
		and not doors.get_node("GalleryB").is_open and not doors.has_node("RestorationShortcut"),
		"Player opens free restoration entrance and reaches T2 depot before key or either locked door opens")
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
	check(not doors.has_node("RestorationShortcut"), "B-to-restoration shortcut has been removed")
	await frames(5)
	var shortcut_path := path(Vector3(32,4.6,16.5),store)
	check(connected(Vector3(32,4.6,16.5),store) and shortcut_path.size() > 6, "Navigation reaches restoration by corridor detour")
	player.position = Vector3(32,4.5,16.5)
	player.velocity = Vector3.ZERO
	await push_against_door(player,Vector3(32,4.5,16.5),PI)
	check(player.position.z < 17.7,"Solid wall blocks the former shortcut from inside B")
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
	# Four entrances now connect by a circular detour around the central fountain.
	check(level.get_node("NavigationRegion3D/Geometry/Courtyard/FountainBase").position.is_equal_approx(Vector3(18,0.3,15)), "Fountain is restored to courtyard centre")
	var courtyard_axes := [
		[Vector3(18,0.1,7.5),Vector3(18,0,22.5),"north-south",[Vector3(18,0,11.9),Vector3(20.2,0,12.8),Vector3(21.1,0,15),Vector3(20.2,0,17.2),Vector3(18,0,18.1)]],
		[Vector3(10.5,0.1,15),Vector3(25.5,0,15),"west-east",[Vector3(14.9,0,15),Vector3(15.8,0,12.8),Vector3(18,0,11.9),Vector3(20.2,0,12.8),Vector3(21.1,0,15)]],
	]
	for axis in courtyard_axes:
		var start: Vector3 = axis[0]
		var finish: Vector3 = axis[1]
		check(not ray(start+Vector3(0,0.3,0),finish+Vector3(0,0.3,0)).is_empty(),"Central fountain remains a solid obstacle on " + axis[2])
		var direct_path := path(start,finish+Vector3(0,0.1,0))
		var around := connected(start,finish)
		for point in direct_path:
			around = around and point.y < 1.0 and not (absf(point.x-18) < 1.5 and absf(point.z-15) < 1.5)
		check(around,"Navigation goes around the fountain on " + axis[2])
		player.position = start
		player.velocity = Vector3.ZERO
		var waypoints: Array = axis[3].duplicate()
		waypoints.append(finish)
		check(await walk(player,waypoints),"Player traverses circular courtyard path " + axis[2])
		player.position = Vector3(18,0.1,35)
		var courtyard_guard := guards[0]
		courtyard_guard.machine.current = GuardStateMachine.NONE
		courtyard_guard.position = start
		courtyard_guard.velocity = Vector3.ZERO
		courtyard_guard.set_physics_process(true)
		courtyard_guard.navigate_to(finish,courtyard_guard.patrol_speed)
		var reached := false
		for tick in 1400:
			await physics_frame
			if courtyard_guard.position.distance_to(finish) < 0.5:
				reached = true
				break
		check(reached,"Guard navigates around fountain on " + axis[2])
		courtyard_guard.set_physics_process(false)
	# Patrol at real speed with perception/noise isolated from traversal tests.
	player.position = Vector3(18,0.1,35)
	check(get_nodes_in_group("guards").size() == 9, "Exactly nine guards are present")
	# Restore the starting door configuration; patrol must not depend on opened locks.
	for gate in get_nodes_in_group("museum_ticket_doors"):
		if gate.is_open:
			gate.interact(player)
	for door in level.get_node("NavigationRegion3D/Doors").get_children():
		door.is_open = false
		door.enabled = true
		door.collision_layer = Interactable.LAYER
		door.get_node("Panel").collision_layer = 1
		door.get_node("Panel").show()
		door.get_node("Passage").enabled = false
	check(not level.get_node("NavigationRegion3D/Doors/GalleryB").is_open
		and not level.get_node("NavigationRegion3D/Doors").has_node("RestorationShortcut"),
		"Patrol verification starts with gallery and shortcut closed")
	for guard in guards:
		guard.agent.avoidance_enabled = true
		guard.reset_to_start()
		guard.set_physics_process(true)
	for tick in 18000:
		await physics_frame
		var done := true
		for i in 9:
			stayed_inside[i] = stayed_inside[i] and inside_patrol_area(i, guards[i].position)
			if i != 2:
				done = done and arrivals[i].size() >= guards[i].patrol_route.get_point_count()*2+1
		if done:
			break
	for i in 9:
		if i == 2:
			check(guards[i].get("phase") == &"sleeping" and guards[i].position.distance_to(Vector3(34.1,0,12)) < 0.15
				and arrivals[i].is_empty(),"G3 stays asleep at chair instead of walking patrol loops")
			check(stayed_inside[i],"G3 stays in staff room")
			continue
		var count := guards[i].patrol_route.get_point_count()
		var ordered: bool = arrivals[i].size() >= count*2+1
		for n in mini(arrivals[i].size(),count*2+1):
			ordered = ordered and arrivals[i][n] == n%count
		check(ordered and stuck[i] == 0, "Guard G%d completes two ordered patrol loops with no stuck events (%d arrivals)" % [i+1,arrivals[i].size()])
		check(stayed_inside[i], "Guard G%d stays on its assigned floor and patrol area" % (i+1))
	check(guards[7].position.x > 27 and guards[7].position.z < 18 and guards[7].position.y > 4, "G8 remains inside gallery B on patrol")
	current_scene = null
	level.free()
	await frames(3)
	print("Museum blockout: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
