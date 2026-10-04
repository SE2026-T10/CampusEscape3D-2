extends RefCounted

## Phase 4 guard patrol tests. Called from tests/test_scene.gd.
##
## Behaviour runs use real physics frames with Engine.time_scale raised so a
## full patrol loop takes seconds instead of a minute. Each physics step then
## moves a guard at most 0.2 m, well below the 0.3 m wall thickness.

const LIBRARY_SCENE := "res://scenes/level/library_graybox.tscn"
const GUARD_SCENE := "res://scenes/npc/guard.tscn"
const TestUtils := preload("res://tests/test_utils.gd")
const TIME_SCALE := 6.0
const WAIT_TOLERANCE := 0.15     # seconds of simulated time
const MAX_NAV_OFFSET := 0.35     # guard centre distance from the navmesh, metres

var failures: Array[String] = []
var _host: Node
var _level: Node3D
var _map: RID
var _previous_time_scale := 1.0


func run(host: Node) -> Array[String]:
	_host = host
	_check_route_logic()
	_check_guard_scene()

	_level = (load(LIBRARY_SCENE) as PackedScene).instantiate()
	var entrance := Vector3(0, 0, 18)
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, _level, entrance), "Navigation map never became ready.")
	_map = (_level.get_node("NavigationRegion3D") as NavigationRegion3D).get_navigation_map()
	_check_level_guards()

	_previous_time_scale = Engine.time_scale
	Engine.time_scale = TIME_SCALE
	await _check_level_patrols()
	_remove_level_guards()
	await _check_guards_crossing_paths()
	await _check_stuck_guard_moves_on()
	await _check_guard_without_route()
	await _check_non_looping_route()
	Engine.time_scale = _previous_time_scale

	_level.queue_free()
	await _physics_frames(1)
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[guard] " + message)


# --- Pure logic ---------------------------------------------------------------

func _check_route_logic() -> void:
	var route := PatrolRoute.new()
	var custom := PatrolPoint.new()
	custom.wait_time = 3.0
	var inherits := PatrolPoint.new()  # wait_time -1: use the guard default
	var plain := Marker3D.new()
	for point in [custom, inherits, plain]:
		route.add_child(point)
	route.add_child(Node3D.new())  # Non-marker children are ignored.

	_expect(route.get_point_count() == 3, "PatrolRoute should count only Marker3D children.")
	_expect(is_equal_approx(route.get_wait_time(0, 2.0), 3.0), "A PatrolPoint's own wait_time should be used.")
	_expect(is_equal_approx(route.get_wait_time(1, 2.0), 2.0), "wait_time -1 should fall back to the guard default.")
	_expect(is_equal_approx(route.get_wait_time(2, 1.5), 1.5), "A plain Marker3D should use the guard default.")
	route.loop = true
	_expect(route.next_index(0) == 1 and route.next_index(2) == 0, "A looping route should wrap from the last point to the first.")
	route.loop = false
	_expect(route.next_index(2) == -1, "A non-looping route should end after its last point.")
	route.free()
	var empty := PatrolRoute.new()
	_expect(empty.next_index(0) == -1, "An empty route has no next point.")
	empty.free()


func _check_guard_scene() -> void:
	var guard := (load(GUARD_SCENE) as PackedScene).instantiate()
	_expect(guard is Guard and guard is CharacterBody3D, "Guard scene root must be a CharacterBody3D with guard.gd.")
	_expect(guard.get_node_or_null("NavigationAgent3D") is NavigationAgent3D, "Guard needs a NavigationAgent3D.")
	_expect(guard.get_node_or_null("CollisionShape3D") is CollisionShape3D, "Guard needs a collision shape.")
	_expect(guard.get_node_or_null("DebugLabel") is Label3D, "Guard needs a DebugLabel.")
	_expect(guard.collision_layer == 4, "Guard should be on the 'npc' physics layer (3).")
	_expect(guard.collision_mask & 1 != 0, "Guard must collide with the world layer.")
	guard.free()


# --- Guards placed in the library ---------------------------------------------

func _level_guards() -> Array[Guard]:
	var guards: Array[Guard] = []
	for node in _host.get_tree().get_nodes_in_group("guards"):
		if _level.is_ancestor_of(node):
			guards.append(node)
	return guards


func _check_level_guards() -> void:
	var guards := _level_guards()
	_expect(guards.size() >= 2, "The library should have at least two guards, found %d." % guards.size())
	var routes := {}
	for guard in guards:
		_expect(guard.patrol_route != null, "%s has no patrol route." % guard.name)
		if guard.patrol_route == null:
			continue
		routes[guard.patrol_route] = true
		var route := guard.patrol_route
		_expect(route.get_point_count() >= 2, "%s's route needs at least two points." % guard.name)
		for i in route.get_point_count():
			var point := route.get_point_position(i)
			var closest := NavigationServer3D.map_get_closest_point(_map, point)
			_expect(Vector2(closest.x - point.x, closest.z - point.z).length() < 0.3,
				"%s point %d at %s is not on walkable floor." % [route.name, i + 1, point])
			var path := NavigationServer3D.map_get_path(_map, guard.global_position, point, true)
			_expect(path.size() > 0 and path[path.size() - 1].distance_to(point) < 0.6,
				"%s cannot reach %s point %d." % [guard.name, route.name, i + 1])
	_expect(routes.size() == guards.size(), "Each library guard should have its own route.")


func _check_level_patrols() -> void:
	var guards := _level_guards()
	var watch := {}
	for guard in guards:
		watch[guard] = _watch(guard)
	# Long enough for the longest route (about 60 m at 2 m/s plus waits) to loop.
	await _run_watched(watch, 55.0, func(): return watch.values().all(func(w): return w.laps >= 1))

	for guard in guards:
		var w: Dictionary = watch[guard]
		var count := guard.patrol_route.get_point_count()
		_expect(w.laps >= 1, "%s did not complete a patrol loop (reached %s)." % [guard.name, w.reached])
		_expect(w.order_ok, "%s visited points out of order: %s." % [guard.name, w.reached])
		_expect(w.max_step <= guard.walk_speed * _step() * 1.25 + 0.01,
			"%s moved %.2f m in one step (teleport?), limit %.2f." % [guard.name, w.max_step, guard.walk_speed * _step() * 1.25])
		_expect(w.max_nav_offset <= MAX_NAV_OFFSET, "%s left the navigation mesh by %.2f m." % [guard.name, w.max_nav_offset])
		_expect(w.stuck == 0, "%s got stuck %d times on its own route." % [guard.name, w.stuck])
		for wait in w.waits:
			var expected := guard.patrol_route.get_wait_time(wait.point, guard.default_wait_time)
			_expect(absf(wait.duration - expected) <= WAIT_TOLERANCE,
				"%s waited %.2fs at point %d, expected %.2fs." % [guard.name, wait.duration, wait.point + 1, expected])
		_expect(w.waits.size() >= count, "%s should have waited at every point (%d waits)." % [guard.name, w.waits.size()])
		_expect(guard.get_debug_text().begins_with(guard.name) and ("PATROL" in guard.get_debug_text() or "WAIT" in guard.get_debug_text()),
			"%s debug text should name the guard and its state: %s" % [guard.name, guard.get_debug_text()])
		print("  [guard] %s: %d loop(s), reached %s, %d waits, max step %.3f m, max navmesh offset %.2f m" % [
			guard.name, w.laps, w.reached, w.waits.size(), w.max_step, w.max_nav_offset])
	_expect(_min_separation(watch) > 0.7, "Two guards overlapped (closest %.2f m)." % _min_separation(watch))

	# Debug visuals follow the F3 toggle.
	var debug := _level.get_node("NavigationDebug")
	debug.set_debug_visible(true)
	_expect(guards[0].debug_label.visible, "Guard labels should show when debug is on.")
	debug.set_debug_visible(false)
	_expect(not guards[0].debug_label.visible, "Guard labels should hide when debug is off.")


# --- Extra scenarios with guards created by the test --------------------------

## Two guards walk the same corridor in opposite directions.
func _check_guards_crossing_paths() -> void:
	var a := Vector3(1, 0, -3)
	var b := Vector3(1, 0, 9)
	var g1 := _spawn_guard("CrossA", _make_route("RouteAB", [a, b], 0.5, true), a)
	var g2 := _spawn_guard("CrossB", _make_route("RouteBA", [b, a], 0.5, true), b)
	var watch := {g1: _watch(g1), g2: _watch(g2)}
	await _run_watched(watch, 60.0, func(): return watch.values().all(func(w): return w.reached.size() >= 4))
	for guard in [g1, g2]:
		var w: Dictionary = watch[guard]
		_expect(w.reached.size() >= 4 and w.order_ok, "%s should keep patrolling past another guard (reached %s)." % [guard.name, w.reached])
		_expect(w.stuck == 0, "%s got stuck passing the other guard." % guard.name)
	var closest := _min_separation(watch)
	_expect(closest > 0.6, "Crossing guards overlapped (closest %.2f m)." % closest)
	print("  [guard] two guards crossing head-on: reached %s and %s in %.1fs, closest approach %.2f m" % [
		watch[g1].reached, watch[g2].reached, watch[g1].time, closest])
	await _free_test_nodes()


## A wall that navigation does not know about blocks the guard: it should give up and move on.
func _check_stuck_guard_moves_on() -> void:
	var a := Vector3(1, 0, -3)
	var b := Vector3(1, 0, 9)
	var wall := StaticBody3D.new()
	wall.name = "TestBlockingWall"
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(28, 3, 0.4)
	wall.add_child(shape)
	_level.add_child(wall)
	wall.global_position = Vector3(0, 1.5, 3)
	var guard := _spawn_guard("StuckGuard", _make_route("BlockedRoute", [a, b], 0.2, true), a)
	var watch := {guard: _watch(guard)}
	await _run_watched(watch, guard.stuck_timeout + 8.0, func(): return watch[guard].stuck >= 1 and watch[guard].reached.size() >= 2)
	var w: Dictionary = watch[guard]
	_expect(w.stuck >= 1, "A blocked guard should report got_stuck.")
	# Started at point 1 (index 0), stuck on the way to point 2, so it moves on to point 1 again.
	_expect(w.reached.size() >= 2, "After getting stuck the guard should continue its route (reached %s)." % [w.reached])
	print("  [guard] blocked guard: got_stuck after %.1fs, then reached %s" % [w.first_stuck_time, w.reached])
	await _free_test_nodes()


func _check_guard_without_route() -> void:
	var guard := _spawn_guard("NoRouteGuard", null, Vector3(1, 0, 2))
	await _physics_frames(30)
	var start := guard.global_position
	await _physics_frames(30)
	_expect(Vector2(guard.global_position.x - start.x, guard.global_position.z - start.z).length() < 0.05,
		"A guard without a route should stand still.")
	_expect("IDLE" in guard.get_debug_text(), "A guard without a route should show IDLE.")
	await _free_test_nodes()


## The guard starts away from its first point, so it must walk there first
## (an empty path right after loading must not count as arriving).
func _check_non_looping_route() -> void:
	var a := Vector3(1, 0, -3)
	var b := Vector3(1, 0, 3)
	var guard := _spawn_guard("OneWayGuard", _make_route("OneWay", [a, b], 0.2, false), b)
	var watch := {guard: _watch(guard)}
	var first_reach := {"time": -1.0}
	guard.patrol_point_reached.connect(func(_i): if first_reach.time < 0.0: first_reach.time = watch[guard].time, CONNECT_ONE_SHOT)
	await _run_watched(watch, 15.0, func(): return false)
	var min_time := a.distance_to(b) / guard.walk_speed * 0.8
	_expect(first_reach.time >= min_time,
		"The guard reported reaching its first point after %.2fs, faster than walking there (%.2fs)." % [first_reach.time, min_time])
	_expect(watch[guard].reached == [0, 1], "A non-looping route should be walked once (reached %s)." % [watch[guard].reached])
	_expect(guard.global_position.distance_to(b) < 0.8, "A non-looping guard should stay at its last point.")
	_expect("route finished" in guard.get_debug_text(), "Debug text should say the route finished.")
	await _free_test_nodes()


# --- Helpers ------------------------------------------------------------------

func _watch(guard: Guard) -> Dictionary:
	var w := {"reached": [], "laps": 0, "order_ok": true, "waits": [], "stuck": 0, "first_stuck_time": -1.0,
		"max_step": 0.0, "max_nav_offset": 0.0, "last_pos": guard.global_position, "wait_start": -1.0,
		"wait_point": -1, "time": 0.0}
	guard.patrol_point_reached.connect(func(index: int):
		var count := guard.patrol_route.get_point_count()
		if not w.reached.is_empty() and index != (w.reached[-1] + 1) % count:
			w.order_ok = false
		w.reached.append(index)
		# A lap = returning to the first point observed, after visiting all the others.
		w.laps = (w.reached.size() - 1) / count)
	guard.state_changed.connect(func(_previous, current):
		if current == Guard.State.WAIT:
			w.wait_start = w.time
			w.wait_point = guard.current_point
		elif w.wait_start >= 0.0:
			w.waits.append({"point": w.wait_point, "duration": w.time - w.wait_start})
			w.wait_start = -1.0)
	guard.got_stuck.connect(func(_index):
		w.stuck += 1
		if w.first_stuck_time < 0.0:
			w.first_stuck_time = w.time)
	return w


## Steps physics until done() or max_seconds of simulated time, recording movement.
func _run_watched(watch: Dictionary, max_seconds: float, done: Callable) -> void:
	var elapsed := 0.0
	while elapsed < max_seconds and not done.call():
		await _host.get_tree().physics_frame
		elapsed += _step()
		for guard in watch:
			var w: Dictionary = watch[guard]
			w.time = elapsed
			var p: Vector3 = guard.global_position
			w.max_step = maxf(w.max_step, Vector2(p.x - w.last_pos.x, p.z - w.last_pos.z).length())
			w.last_pos = p
			var closest := NavigationServer3D.map_get_closest_point(_map, p)
			w.max_nav_offset = maxf(w.max_nav_offset, Vector2(closest.x - p.x, closest.z - p.z).length())
			var others: Array = w.get("positions", [])
			others.append(p)
			w["positions"] = others


func _min_separation(watch: Dictionary) -> float:
	var guards := watch.keys()
	var best := INF
	for i in guards.size():
		for j in range(i + 1, guards.size()):
			var pa: Array = watch[guards[i]].positions
			var pb: Array = watch[guards[j]].positions
			for k in mini(pa.size(), pb.size()):
				best = minf(best, Vector2(pa[k].x - pb[k].x, pa[k].z - pb[k].z).length())
	return best


func _make_route(route_name: String, points: Array, wait: float, loop: bool) -> PatrolRoute:
	var route := PatrolRoute.new()
	route.name = route_name
	route.loop = loop
	route.add_to_group("guard_test_nodes")
	for p in points:
		var point := PatrolPoint.new()
		point.wait_time = wait
		point.position = p
		route.add_child(point)
	_level.add_child(route)
	return route


func _spawn_guard(guard_name: String, route: PatrolRoute, at: Vector3) -> Guard:
	var guard: Guard = (load(GUARD_SCENE) as PackedScene).instantiate()
	guard.name = guard_name
	guard.patrol_route = route
	guard.add_to_group("guard_test_nodes")
	_level.add_child(guard)
	guard.global_position = at + Vector3(0, 0.05, 0)
	return guard


func _free_test_nodes() -> void:
	for node in _host.get_tree().get_nodes_in_group("guard_test_nodes"):
		node.queue_free()
	var wall := _level.get_node_or_null("TestBlockingWall")
	if wall:
		wall.queue_free()
	await _physics_frames(2)


func _remove_level_guards() -> void:
	var guards := _level.get_node_or_null("Guards")
	if guards:
		_level.remove_child(guards)
		guards.free()


## Simulated seconds per physics frame.
func _step() -> float:
	return Engine.time_scale / Engine.physics_ticks_per_second


func _physics_frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
