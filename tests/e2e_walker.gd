extends RefCounted

## Expansion Phase 8: walks the player through a level with real input, for the
## end-to-end tests (tests/expanded_e2e_tests.gd). It follows a NavigationServer
## path with the move keys (turning the player toward the next path point, as a
## player turns the mouse), uses things with the interact key when the
## PlayerInteractor focuses them, and turns code dials one press at a time. It
## never teleports. Distance walked and game time are counted.

var player: FirstPersonPlayer
var interactor: PlayerInteractor
var host: Node
var map: RID
## Game seconds and metres walked since setup().
var game_time := 0.0
var walked := 0.0
## Why the last walk_to() or use() failed ("" if it worked).
var last_error := ""
## Positions where the player got stuck and had to step aside.
var stuck_spots: Array[Vector3] = []
## Doors the walker opened with E on its way, and the refusals it met.
var doors_opened: Array[String] = []
var refusals: Array[String] = []
## Where the player walked (a point every 0.5 m), to check which stairs were used.
var trace: Array[Vector3] = []
var _doors: Array[AccessDoor] = []


func setup(level: Node3D, host_node: Node) -> void:
	host = host_node
	player = level.get_node("Player")
	interactor = player.get_node("Interactor")
	map = level.get_world_3d().navigation_map
	game_time = 0.0
	walked = 0.0
	stuck_spots.clear()
	doors_opened.clear()
	refusals.clear()
	trace.clear()
	_doors.clear()
	for node in level.get_tree().get_nodes_in_group("interactables"):
		if node is AccessDoor:
			_doors.append(node)


func frame() -> void:
	await host.get_tree().physics_frame
	game_time += Engine.time_scale / Engine.physics_ticks_per_second


func frames(n: int) -> void:
	for i in n:
		await frame()


## Walks to `target` (a point on the floor). False after `timeout` game seconds,
## no path, or 6 failed attempts to get past an obstacle.
func walk_to(target: Vector3, timeout := 120.0, sprint := false) -> bool:
	last_error = ""
	var path := NavigationServer3D.map_get_path(map, player.global_position, target, true)
	if path.is_empty():
		last_error = "no path from %s to %s" % [_v(player.global_position), _v(target)]
		return false
	var index := 0
	var started := game_time
	var anchor := player.global_position
	var anchor_t := game_time
	var unstuck := 0
	var last := player.global_position
	while game_time - started < timeout:
		await frame()
		var here := player.global_position
		walked += here.distance_to(last)
		last = here
		if trace.is_empty() or trace[-1].distance_to(here) > 0.5:
			trace.append(here)
		if _flat(here, target) < 0.45 and absf(target.y - here.y) < 0.9:
			release()
			return true
		while index < path.size() - 1 and _flat(here, path[index]) < 0.5:
			index += 1
		var to := path[index] - here
		player.rotation.y = atan2(-to.x, -to.z)
		player.head.rotation.x = 0.0
		Input.action_press("move_forward")
		if sprint:
			Input.action_press("sprint")
		# A closed door in the way: a player presses E on it. A refusal ends the walk.
		var door := _closed_door_ahead(here, path, index)
		if door:
			release()
			var opened := await use_door(door)
			if not opened:
				last_error = "%s refused: %s" % [door.door_name, refusals[-1] if not refusals.is_empty() else "?"]
				return false
			path = NavigationServer3D.map_get_path(map, player.global_position, target, true)
			index = 0
			anchor_t = game_time
			continue
		if game_time - anchor_t > 2.0:
			if here.distance_to(anchor) < 0.3:
				unstuck += 1
				stuck_spots.append(here)
				if unstuck > 6:
					release()
					last_error = "stuck at %s on the way to %s" % [_v(here), _v(target)]
					return false
				await _sidestep(unstuck)
				path = NavigationServer3D.map_get_path(map, player.global_position, target, true)
				index = 0
			anchor = player.global_position
			anchor_t = game_time
	release()
	last_error = "did not reach %s in %.0f s (at %s)" % [_v(target), timeout, _v(player.global_position)]
	return false


## Presses E on a closed door the player stands in front of. True if it opened.
func use_door(door: AccessDoor) -> bool:
	var reason := [""]
	var on_rejected := func(r: String): reason[0] = r
	door.rejected.connect(on_rejected)
	for attempt in 4:
		look_at(door.global_position + Vector3(0, 1.0, 0))
		await frames(3)
		if interactor.focused == door:
			await press("interact")
			await frames(4)
			break
	door.rejected.disconnect(on_rejected)
	if door.is_open:
		doors_opened.append(door.door_name)
		return true
	refusals.append(reason[0] if reason[0] != "" else "no prompt (%s)" % door.door_name)
	return false


## The closed, discovered door within 1.6 m that the path goes through next.
func _closed_door_ahead(here: Vector3, path: PackedVector3Array, index: int) -> AccessDoor:
	for door in _doors:
		if door.is_open or not door.is_discovered() or not door.is_inside_tree():
			continue
		var d := door.global_position
		if _flat(here, d) > 1.6 or absf(here.y - d.y) > 1.5:
			continue
		# Does the path between here and the next few points pass the door?
		var prev := here
		for k in range(index, mini(index + 3, path.size())):
			if _segment_dist(Vector2(d.x, d.z), Vector2(prev.x, prev.z), Vector2(path[k].x, path[k].z)) < 1.0:
				return door
			prev = path[k]
	return null


func _segment_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 0.0001 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Walks to `stand`, looks at `node` and presses E `times` times while it is
## focused. False if it could not get there or never focused `node`.
func use(node: Node3D, stand: Vector3, times := 1) -> bool:
	if not await walk_to(stand):
		return false
	for attempt in 6:
		look_at(node.global_position)
		await frames(3)
		if interactor.focused == node:
			for k in times:
				await press("interact")
			return true
		# Not focused yet: shuffle a little toward it.
		var to: Vector3 = node.global_position - player.global_position
		to.y = 0
		Input.action_press("move_forward")
		player.rotation.y = atan2(-to.x, -to.z)
		await frames(3)
		release()
	last_error = "could not focus %s from %s (focused %s)" % [node.name, _v(player.global_position),
		interactor.focused.name if interactor.focused else "nothing"]
	return false


## Turns each dial of `lock` to `code` with E, then presses ENTER.
func enter_code(lock: CodeLock, code: String, stand: Vector3) -> bool:
	for i in code.length():
		var dial := lock.dials[i]
		var turns := (int(code[i]) - dial.index + 10) % 10
		if turns > 0 and not await use(dial, stand, turns):
			return false
	return await use(lock.enter, stand)


## Walks straight on from `from` toward `toward` for up to `seconds` (through an
## exit trigger), stopping early when `done` returns true.
func walk_through(from: Vector3, toward: Vector3, seconds: float, done: Callable) -> bool:
	if not await walk_to(from):
		return false
	var to := toward - player.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = 0.0
	Input.action_press("move_forward")
	var t := 0.0
	while t < seconds:
		await frame()
		t += Engine.time_scale / Engine.physics_ticks_per_second
		if done.call():
			break
	release()
	await frames(3)
	return done.call()


func look_at(target: Vector3) -> void:
	var at := player.global_position
	player.rotation.y = atan2(-(target.x - at.x), -(target.z - at.z))
	var eye := player.camera.global_position.y
	player.head.rotation.x = atan2(target.y - eye, Vector2(target.x - at.x, target.z - at.z).length())


func press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await frames(2)


func release() -> void:
	for a in ["move_forward", "move_backward", "move_left", "move_right", "sprint", "crouch"]:
		Input.action_release(a)


func _sidestep(n: int) -> void:
	release()
	Input.action_press("move_backward")
	await frames(int(0.4 * Engine.physics_ticks_per_second / Engine.time_scale) + 1)
	Input.action_release("move_backward")
	var side := "move_left" if n % 2 == 1 else "move_right"
	Input.action_press(side)
	await frames(int(0.5 * Engine.physics_ticks_per_second / Engine.time_scale) + 1)
	Input.action_release(side)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _v(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]
