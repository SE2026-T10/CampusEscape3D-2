extends RefCounted

## Museum Heist navigation and exit regressions. Called from tests/test_scene.gd.

const LEVEL_SCENE := "res://maps/museum/scenes/museum_heist.tscn"
const GUARD_SCENE := "res://shared/scenes/npc/guard.tscn"
const TestUtils := preload("res://tests/test_utils.gd")

var failures: Array[String] = []
var _host: Node


func run(host: Node) -> Array[String]:
	_host = host
	await _check_full_playthrough()
	await _check_navigation_and_guards()
	await _check_exit_interaction()
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[museum-heist] " + message)


func _check_navigation_and_guards() -> void:
	var level := (load(LEVEL_SCENE) as PackedScene).instantiate()
	for node_name in ["Guards", "StealthDirector", "Player"]:
		var node := level.get_node(node_name)
		level.remove_child(node)
		node.free()
	var ready: bool = await TestUtils.add_level_and_wait_for_navigation(_host, level, Vector3(0, 0.05, 0))
	_expect(ready, "Navigation map did not sync.")
	var region := level.get_node("NavigationRegion3D") as NavigationRegion3D
	var nav_mesh := region.navigation_mesh
	var map := region.get_navigation_map()
	_expect(nav_mesh.get_polygon_count() > 1, "The saved navmesh must be baked around static obstacles.")
	_expect(nav_mesh.geometry_parsed_geometry_type == NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS,
		"Museum navigation must be baked from static colliders.")
	_expect(nav_mesh.geometry_source_geometry_mode == NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
		and nav_mesh.geometry_source_group_name == &"museum_navmesh_sources",
		"Navmesh bake must include both NavigationRegion3D and MuseumDecor source groups.")
	_expect(nav_mesh.geometry_collision_mask == 1, "Navmesh bake must use the static obstacle collision layer.")
	_check_fresh_bake(level, nav_mesh)
	_check_display_case_path(map)
	await _check_guard_states_and_movement(level, map)
	level.queue_free()
	await _physics_frames(2)


func _check_fresh_bake(level: Node3D, saved: NavigationMesh) -> void:
	var fresh := saved.duplicate(true) as NavigationMesh
	fresh.clear_polygons()
	fresh.vertices = PackedVector3Array()
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(fresh, source, level)
	NavigationServer3D.bake_from_source_geometry_data(fresh, source)
	var saved_area := _navmesh_area(saved)
	var fresh_area := _navmesh_area(fresh)
	_expect(fresh.get_polygon_count() > 1, "A fresh collision bake must produce obstacle-aware polygons.")
	_expect(absf(saved_area - fresh_area) <= 0.01 * maxf(fresh_area, 1.0),
		"Saved Museum navmesh is stale (%.2f m² saved, %.2f m² fresh)." % [saved_area, fresh_area])
	for vertex in saved.get_vertices():
		_expect(vertex.y < 1.0, "Navmesh must remain at floor height (found vertex at y=%.2f)." % vertex.y)


func _check_display_case_path(map: RID) -> void:
	var center := Vector3(-9, 0.225, -1)
	var start := NavigationServer3D.map_get_closest_point(map, Vector3(-13, 0.225, -1))
	var finish := NavigationServer3D.map_get_closest_point(map, Vector3(-5, 0.225, -1))
	var path := NavigationServer3D.map_get_path(map, start, finish, true)
	_expect(path.size() >= 3, "The path across LobbyDisplayCase must route around the obstacle.")
	if path.size() < 2:
		return
	var minimum_clearance := INF
	for index in path.size() - 1:
		minimum_clearance = minf(minimum_clearance, _distance_to_segment_2d(
			Vector2(center.x, center.z),
			Vector2(path[index].x, path[index].z),
			Vector2(path[index + 1].x, path[index + 1].z)))
	_expect(minimum_clearance > 1.5,
		"Navigation path crosses LobbyDisplayCase (closest path clearance %.2f m)." % minimum_clearance)
	_expect(_path_length(path) > start.distance_to(finish) + 0.3,
		"Path across LobbyDisplayCase should detour rather than cut through it.")


func _check_guard_states_and_movement(level: Node3D, map: RID) -> void:
	var start := NavigationServer3D.map_get_closest_point(map, Vector3(-13, 0.225, -1))
	var finish := NavigationServer3D.map_get_closest_point(map, Vector3(-5, 0.225, -1))
	var route := PatrolRoute.new()
	route.loop = false
	for point_position in [start, finish]:
		var point := PatrolPoint.new()
		point.position = point_position
		point.wait_time = 0.1
		route.add_child(point)
	level.add_child(route)

	var guard := (load(GUARD_SCENE) as PackedScene).instantiate() as Guard
	guard.name = "MuseumNavigationTestGuard"
	guard.patrol_route = route
	guard.patrol_speed = 3.5
	guard.investigate_speed = 3.5
	guard.stuck_timeout = 8.0
	guard.chase_lose_sight_time = 60.0
	var reached_finish := [false]
	var stuck := [false]
	guard.patrol_point_reached.connect(func(index: int) -> void:
		if index == 1:
			reached_finish[0] = true)
	guard.got_stuck.connect(func(_index: int) -> void: stuck[0] = true)
	level.add_child(guard)
	guard.global_position = start + Vector3(0, 0.05, 0)

	_expect(await _wait_until(func(): return guard.machine.current == GuardStateMachine.PATROL, 4.0),
		"Test guard did not enter PATROL.")
	_expect(await _wait_until(func(): return reached_finish[0], 12.0),
		"Patrolling guard could not route around LobbyDisplayCase.")
	_expect(not stuck[0], "Patrolling guard reported stuck at LobbyDisplayCase.")

	guard.hear_noise(start, 2.0)
	_expect(await _wait_until(func(): return guard.machine.current == GuardStateMachine.INVESTIGATE, 2.0),
		"Guard did not enter INVESTIGATE after hearing a noise.")
	var investigate := guard.machine.get_state(GuardStateMachine.INVESTIGATE) as InvestigateState
	_expect(await _wait_until(func(): return investigate.searching, 12.0),
		"Investigating guard could not reach the noise around LobbyDisplayCase.")
	_expect(not stuck[0], "Investigating guard reported stuck at LobbyDisplayCase.")

	var sighting := GuardPerception.new()
	sighting.confirmed_sighting = true
	sighting.has_sighting_position = true
	sighting.sighting_position = finish
	guard.machine.tick(sighting, 1.0 / Engine.physics_ticks_per_second)
	_expect(guard.machine.current == GuardStateMachine.CHASE,
		"A confirmed sighting should transition INVESTIGATE to CHASE.")
	var chase := guard.machine.get_state(GuardStateMachine.CHASE) as ChaseState
	var chase_start_distance := guard.global_position.distance_to(finish)
	await _physics_frames(30)
	var chase_end_distance := guard.global_position.distance_to(finish)
	_expect(chase.target.distance_to(finish) < 0.1 and chase_end_distance < chase_start_distance - 0.5,
		"Chasing guard should make progress around LobbyDisplayCase (%.2f m → %.2f m)." % [
			chase_start_distance, chase_end_distance])
	_expect(not stuck[0], "Chasing guard reported stuck at LobbyDisplayCase.")


func _check_exit_interaction() -> void:
	var level := (load(LEVEL_SCENE) as PackedScene).instantiate()
	var guards := level.get_node("Guards")
	level.remove_child(guards)
	guards.free()
	var ready: bool = await TestUtils.add_level_and_wait_for_navigation(_host, level, Vector3(0, 0.05, 0))
	_expect(ready, "Navigation map did not sync for the exit test.")
	await _physics_frames(3)

	var player := level.get_node("Player") as FirstPersonPlayer
	var door := level.get_node("ExitDoor") as ExitDoor
	var objectives := level.get_node("Gameplay/ObjectiveManager") as ObjectiveManager
	var flow := level.get_node("GameFlow") as GameFlow
	var interactor := player.get_node("Interactor") as PlayerInteractor
	player.global_position = Vector3(-15, 0.05, 13)
	player.velocity = Vector3.ZERO
	player.camera.look_at(door.global_position)
	await _physics_frames(3)

	_expect(not door.is_unlocked(), "Exit must remain locked before required objectives are completed.")
	_expect(interactor.find_target() == door, "Player raycast must focus the exit from the interior.")
	_expect(interactor.focused == door, "Exit must become the focused interactable.")
	await _press_physical_e()
	_expect(door.rejections == 1 and flow.state == GameStateMachine.State.PLAYING,
		"Pressing E while locked must reject the exit without winning.")

	for objective_id in [ObjectiveManager.ENTER_LIBRARY, ObjectiveManager.REACH_RESTRICTED, ObjectiveManager.TAKE_CARD]:
		_expect(objectives.complete(objective_id), "Could not complete prerequisite objective '%s'." % objective_id)
	await _physics_frames(3)
	_expect(objectives.is_completed(ObjectiveManager.REACH_EXIT),
		"Being inside the exit trigger should complete the final reach objective.")
	_expect(door.is_unlocked(), "Exit must unlock when the card is obtained and escape becomes active.")
	_expect(interactor.find_target() == door, "Unlocked exit must still be detected by the player raycast.")
	await _press_physical_e()
	await _physics_frames(5)
	_expect(objectives.is_finished(), "Using the unlocked exit should finish all Museum Heist objectives.")
	_expect(flow.state == GameStateMachine.State.WIN, "Using E on the unlocked exit should transition GameFlow to WIN.")
	level.queue_free()
	await _physics_frames(2)


func _check_full_playthrough() -> void:
	var level := (load(LEVEL_SCENE) as PackedScene).instantiate()
	var guards := level.get_node("Guards")
	level.remove_child(guards)
	guards.free()
	var ready: bool = await TestUtils.add_level_and_wait_for_navigation(_host, level, Vector3(0, 0.05, 0))
	_expect(ready, "Navigation map did not sync for the full playthrough.")
	await _physics_frames(3)

	var player := level.get_node("Player") as FirstPersonPlayer
	var map: RID = level.get_world_3d().navigation_map
	var objectives := level.get_node("Gameplay/ObjectiveManager") as ObjectiveManager
	var flow := level.get_node("GameFlow") as GameFlow
	var card := level.get_node("MuseumAccessCard") as Node3D
	var door := level.get_node("ExitDoor") as ExitDoor
	var interactor := player.get_node("Interactor") as PlayerInteractor

	player.global_position = Vector3(-15, 0.05, 0)
	player.velocity = Vector3.ZERO
	for route_point in [
		Vector3(-15, 0.05, 4),
		Vector3(14, 0.05, -7),
		Vector3(14, 0.05, -3),
	]:
		_expect(await _walk_to(player, map, route_point), "Player got stuck walking to %s." % route_point)
		await _physics_frames(3)
	_expect(objectives.is_completed(ObjectiveManager.ENTER_LIBRARY),
		"Walking into the museum should complete the entrance objective.")
	_expect(objectives.is_completed(ObjectiveManager.REACH_RESTRICTED),
		"Walking into the restricted area should complete its objective.")

	player.camera.look_at(card.global_position)
	await _physics_frames(3)
	_expect(interactor.find_target() == card, "The access card should be reachable with the interaction raycast.")
	await _press_physical_e()
	_expect(objectives.is_completed(ObjectiveManager.TAKE_CARD),
		"Pressing E on the access card should complete the card objective.")

	_expect(await _walk_to(player, map, Vector3(-15, 0.05, 13)),
		"Player got stuck returning to the main exit.")
	await _physics_frames(3)
	_expect(objectives.is_completed(ObjectiveManager.REACH_EXIT),
		"Walking into the exit area should activate the escape objective.")
	_expect(door.is_unlocked(), "The exit should unlock after all required objectives are completed.")
	player.camera.look_at(door.global_position)
	await _physics_frames(3)
	_expect(interactor.find_target() == door, "The unlocked exit should be reachable with the interaction raycast.")
	await _press_physical_e()
	await _physics_frames(5)
	_expect(objectives.is_finished() and flow.state == GameStateMachine.State.WIN,
		"Walking the Museum route and pressing E at the exit should reach WIN.")
	var menus := level.get_node("GameMenus") as GameMenus
	_expect(menus.win_panel.visible and menus.get_objectives_text() == "Objectives 5/5 complete",
		"The completed playthrough should show the 5/5 win screen.")
	level.queue_free()
	await _physics_frames(2)


func _walk_to(player: FirstPersonPlayer, map: RID, target: Vector3) -> bool:
	var path := NavigationServer3D.map_get_path(map, player.global_position, target, true)
	if path.is_empty():
		return false
	var index := 0
	var anchor := player.global_position
	var anchor_frame := 0
	var arrived := false
	Input.action_press("move_forward")
	for frame in 60 * 90:
		var here := player.global_position
		while index < path.size() - 1 and Vector2(path[index].x - here.x, path[index].z - here.z).length() < 0.45:
			index += 1
		var to := path[index] - here
		if Vector2(target.x - here.x, target.z - here.z).length() < 0.4:
			arrived = true
			break
		player.rotation.y = atan2(-to.x, -to.z)
		if frame - anchor_frame >= 90:
			if here.distance_to(anchor) < 0.3:
				break
			anchor = here
			anchor_frame = frame
		await _host.get_tree().physics_frame
	Input.action_release("move_forward")
	await _physics_frames(3)
	return arrived


func _press_physical_e() -> void:
	var press := InputEventKey.new()
	press.physical_keycode = KEY_E
	press.pressed = true
	_host.get_viewport().push_input(press)
	await _physics_frames(1)
	var release := InputEventKey.new()
	release.physical_keycode = KEY_E
	release.pressed = false
	_host.get_viewport().push_input(release)
	await _physics_frames(2)


func _wait_until(condition: Callable, timeout_seconds: float) -> bool:
	var frames := ceili(timeout_seconds * Engine.physics_ticks_per_second)
	for _frame in frames:
		if condition.call():
			return true
		await _host.get_tree().physics_frame
	return condition.call()


func _physics_frames(count: int) -> void:
	for _frame in count:
		await _host.get_tree().physics_frame


func _navmesh_area(nav_mesh: NavigationMesh) -> float:
	var area := 0.0
	var vertices := nav_mesh.get_vertices()
	for polygon_index in nav_mesh.get_polygon_count():
		var polygon := nav_mesh.get_polygon(polygon_index)
		for index in range(1, polygon.size() - 1):
			var a := Vector2(vertices[polygon[0]].x, vertices[polygon[0]].z)
			var b := Vector2(vertices[polygon[index]].x, vertices[polygon[index]].z)
			var c := Vector2(vertices[polygon[index + 1]].x, vertices[polygon[index + 1]].z)
			area += absf((b - a).cross(c - a)) / 2.0
	return area


func _distance_to_segment_2d(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if is_zero_approx(length_squared):
		return point.distance_to(start)
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)


func _path_length(path: PackedVector3Array) -> float:
	var length := 0.0
	for index in path.size() - 1:
		length += path[index].distance_to(path[index + 1])
	return length
