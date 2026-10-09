extends RefCounted

## Expanded Library — Phase 3 navigation and guard tests. Called from tests/test_scene.gd.
## The guards are the existing guard scene and AI (PATROL / INVESTIGATE / CHASE),
## unchanged; these tests check that they work on the two-floor map.
##
##   A. Navigation: both floors baked; the level is sealed (nothing outside the
##      building is reachable, nothing baked on walls or railings); every patrol
##      point is on the navmesh and clear of doorways and stairs.
##   B. Patrols: all six level guards run together (time sped up 3×): every
##      guard completes its whole loop in order, nobody gets stuck, nobody
##      leaves PATROL, the connecting guard really changes floors, and no guard
##      sees the player standing at the spawn.
##   C. Vision: open aisle seen; behind a shelf, through the upper slab, and
##      behind the balcony railing not seen; at the railing seen.
##   D. Hearing: a sprint in the open is heard and investigated at an estimate,
##      never the exact spot; through a wall it is not heard at the same
##      distance; through the upper slab the existing rule applies (walls and
##      floors halve the range): a sprint directly overhead is heard, a walk is not.
##   E. Detection, pursuit, loss of contact: PATROL → CHASE → (sight lost)
##      INVESTIGATE at the last seen spot, not at the player → PATROL.
##   F. Pursuit across floors: a guard at the foot of S1 sees the player at the
##      top, chases up the stair, loses them, searches upstairs and walks back
##      down to its patrol.
##   G. Narrow passages: two guards cross head-on in a 2 m doorway and on a
##      stair; one guard tours every gate and all three stairs.

const SCENE := "res://scenes/level/expanded_library.tscn"
const GUARD_SCENE := "res://scenes/npc/guard.tscn"
const Layout := preload("res://tools/expanded/expanded_layout.gd")
const TestUtils := preload("res://tests/test_utils.gd")
const PATROL := GuardStateMachine.PATROL
const INVESTIGATE := GuardStateMachine.INVESTIGATE
const CHASE := GuardStateMachine.CHASE
const U := Layout.UPPER_Y

var failures: Array[String] = []
var _host: Node
var _level: Node3D
var _map: RID
var _player: FirstPersonPlayer


func run(host: Node) -> Array[String]:
	_host = host
	await _load(true)
	_check_navigation()
	await _check_patrols()
	await _unload()
	await _load(false)
	await _check_vision()
	await _check_hearing()
	await _check_chase_and_loss()
	await _check_chase_across_floors()
	await _check_narrow_passages()
	await _unload()
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[expanded-ai] " + message)


# --- A. Navigation ---------------------------------------------------------------------------

func _check_navigation() -> void:
	var nav := (_level.get_node("NavigationRegion3D") as NavigationRegion3D).navigation_mesh
	var vertices := nav.get_vertices()
	var outside := 0
	var too_high := 0
	for v in vertices:
		if v.x < -36.0 or v.x > 36.0 or v.z < -28.0 or v.z > 34.0:
			outside += 1
		if v.y > U + 0.6 or v.y < -0.5:
			too_high += 1
	_expect(outside == 0, "%d navmesh vertices lie outside the building." % outside)
	_expect(too_high == 0, "%d navmesh vertices are above the upper floor or below the ground (baked on walls or railings?)." % too_high)
	# Sealed: points outside are not reachable from the spawn (the exit is a closed door panel).
	for p in [Vector3(40, 0, 24), Vector3(0, 0, 40), Vector3(-40, 0, 0), Vector3(0, 0, -32), Vector3(40, U, -15)]:
		var path := NavigationServer3D.map_get_path(_map, Layout.SPAWN, p, true)
		_expect(path.is_empty() or path[path.size() - 1].distance_to(p) > 3.0, "The outside point %s is reachable: the level is not sealed." % p)
	# Patrol points: on the navmesh, and not standing in a doorway or on a stair.
	var loops := []
	for patrol in Layout.PATROLS:
		var length := 0.0
		var count: int = patrol.points.size()
		for k in count:
			var a := Layout.patrol_point(patrol, k)
			var b := Layout.patrol_point(patrol, (k + 1) % count)
			var closest := NavigationServer3D.map_get_closest_point(_map, a)
			_expect(closest.distance_to(a) < 0.6, "%s point %d %s is not on the navmesh (nearest %s)." % [patrol.id, k, a, closest])
			for wall in Layout.WALLS:
				for o in wall.get("openings", []):
					var c := Layout.opening_centre(wall, o)
					_expect(c.distance_to(a) >= 2.0, "%s point %d stands in the doorway '%s'." % [patrol.id, k, o.name])
			for s in Layout.STAIRS:
				var on_ramp: bool = a.x > s.x0 - 0.5 and a.x < s.x1 + 0.5 and a.z > minf(s.z_low, s.z_high) - 0.5 and a.z < maxf(s.z_low, s.z_high) + 0.5
				_expect(not on_ramp, "%s point %d stands on %s." % [patrol.id, k, s.name])
			var path := NavigationServer3D.map_get_path(_map, a, b, true)
			_expect(not path.is_empty() and path[path.size() - 1].distance_to(b) < 0.6, "%s: no path from point %d to point %d." % [patrol.id, k, (k + 1) % count])
			length += _length(path)
		if patrol.has("guard"):
			loops.append("%s %s %.0f m" % [patrol.id, patrol.guard, length])
	print("  [expanded-ai] navigation: both floors baked, sealed, nothing above the upper floor; loops: %s" % ", ".join(loops))


# --- B. All six patrols together -------------------------------------------------------------

func _check_patrols() -> void:
	var guards := _level_guards()
	_expect(guards.size() == 6, "Expected six guards in the Expanded Library, found %d." % guards.size())
	var log := {}
	for g in guards:
		var entry := {"reached": [], "stuck": 0, "changes": 0, "saw": false, "ymin": INF, "ymax": -INF, "points": g.patrol_route.get_point_count()}
		log[g] = entry
		g.patrol_point_reached.connect(func(i): entry.reached.append(i))
		g.got_stuck.connect(func(_i): entry.stuck += 1)
		g.ai_state_changed.connect(func(_a, _b, _r): entry.changes += 1)
	# The player stands at the spawn the whole time.
	_player.global_position = Layout.SPAWN
	var scale := 3.0
	Engine.time_scale = scale
	var game_time := 0.0
	while game_time < 240.0:
		await _host.get_tree().physics_frame
		game_time += scale / Engine.physics_ticks_per_second
		var all_done := true
		for g in guards:
			var e: Dictionary = log[g]
			e.ymin = minf(e.ymin, g.global_position.y)
			e.ymax = maxf(e.ymax, g.global_position.y)
			e.saw = e.saw or g.vision.can_see_target
			all_done = all_done and _full_loop(e.reached, e.points)
		if all_done:
			break
	Engine.time_scale = 1.0
	var summary := []
	for g in guards:
		var e: Dictionary = log[g]
		_expect(_full_loop(e.reached, e.points), "%s did not complete its loop in order within %.0f s (reached %s)." % [g.name, game_time, e.reached])
		_expect(e.stuck == 0, "%s got stuck %d time(s)." % [g.name, e.stuck])
		_expect(e.changes == 0 and g.machine.current == PATROL, "%s left PATROL during the patrol run." % g.name)
		_expect(not e.saw, "%s saw the player standing at the spawn." % g.name)
		summary.append("%s %d pts y %.1f–%.1f" % [g.name, e.points, e.ymin, e.ymax])
	var connector: Node3D = _level.get_node("Guards/GuardConnector")
	var c: Dictionary = log[connector]
	_expect(c.ymax > U - 0.2 and c.ymin < 0.2, "GuardConnector should patrol both floors (y %.2f…%.2f)." % [c.ymin, c.ymax])
	print("  [expanded-ai] patrols: 6 guards completed their loops in order in %.0f s game time, 0 stuck, all stayed in PATROL, spawn never seen; %s" % [
		game_time, ", ".join(summary)])


## True once `reached` holds every point 0…count-1 in order, followed by 0 again.
func _full_loop(reached: Array, count: int) -> bool:
	var expect := 0
	var done := 0
	for i in reached:
		if i == expect:
			expect = (expect + 1) % count
			done += 1
	return done >= count + 1


# --- C. Vision ---------------------------------------------------------------------------------

func _check_vision() -> void:
	var guard := await _spawn_guard("VisionGuard", [Vector3(-33.5, 0, -9)], Vector3(1, 0, 0))
	guard.set_physics_process(false)   # stand still, facing east along the cross aisle
	var cases := [
		["open cross aisle, 13.5 m", Vector3(-20, 0, -9), true],
		["behind a shelf row", Vector3(-22, 0, -14), false],
		["upstairs, through the slab", Vector3(-24, U, -9), false],
	]
	for c in cases:
		_expect(await _sees(guard, c[1]) == c[2], "Vision, %s: the guard should %s the player." % [c[0], "see" if c[2] else "not see"])
		_expect(guard.vision.is_in_view(c[1] + Vector3(0, 1.5, 0)), "Vision test '%s' should be inside the cone and range, so only walls decide." % c[0])
	guard.global_position = Vector3(0, 0.05, 21)
	guard.rotation.y = 0.0   # facing north, up toward the balcony
	_expect(await _sees(guard, Vector3(2, U, 9.5)), "Vision: a player at the balcony railing should be seen from the lobby.")
	_expect(not await _sees(guard, Vector3(2, U, 6.5)), "Vision: a player 3 m back from the railing should be hidden by it.")
	await _free_guard(guard)
	print("  [expanded-ai] vision: open aisle seen; behind a shelf, through the slab and behind the balcony railing not seen; at the railing seen")


func _sees(guard: Guard, at: Vector3) -> bool:
	_player.global_position = at + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	await _frames(4)
	return guard.vision.can_see_target


# --- D. Hearing ---------------------------------------------------------------------------------

func _check_hearing() -> void:
	_player.global_position = Vector3(0, 0.05, 32)   # out of everyone's way
	var noise := NoiseSystem.find(_level)
	# 1. A sprint in the open, 8 m away: heard, investigated at an estimate.
	var guard := await _spawn_guard("HearingGuard", [Vector3(-24, 0, -9)], Vector3(1, 0, 0))
	var source := Vector3(-16, 0, -9)
	noise.emit_noise(source, NoiseEvent.Type.RUN, "player")
	await _frames(4)
	var heard: bool = guard.machine.current == INVESTIGATE
	var target := guard.agent.target_position
	_expect(heard, "Hearing: a sprint 8 m away in the open should be investigated.")
	_expect(target.distance_to(source) > 0.2 and target.distance_to(source) < 3.5,
		"Hearing: the guard should go to an estimate near the noise, not the exact spot (target %s, noise %s)." % [target, source])
	await _free_guard(guard)
	# 2. The same kind of noise 10.5 m away behind a wall (reading hall → Study 2, between the doors): not heard.
	guard = await _spawn_guard("HearingGuard2", [Vector3(0, 0, -6)], Vector3(0, 0, -1))
	noise.emit_noise(Vector3(-1, 0, -16.5), NoiseEvent.Type.RUN, "player")
	await _frames(4)
	_expect(guard.machine.current == PATROL, "Hearing: a sprint 10 m away behind a wall should not be heard (walls halve the range).")
	await _free_guard(guard)
	# 3. Through the upper slab (it counts as a wall): a sprint straight overhead is heard, a walk is not.
	guard = await _spawn_guard("HearingGuard3", [Vector3(-24, 0, -9)], Vector3(1, 0, 0))
	noise.emit_noise(Vector3(-24, U, -9), NoiseEvent.Type.WALK, "player")
	await _frames(4)
	_expect(guard.machine.current == PATROL, "Hearing: walking upstairs should not be heard by a guard directly below.")
	noise.emit_noise(Vector3(-24, U, -9), NoiseEvent.Type.RUN, "player")
	await _frames(4)
	_expect(guard.machine.current == INVESTIGATE and guard.agent.target_position.y > U - 1.0,
		"Hearing: a sprint straight overhead (2.9 m from the guard's ears, inside the halved 6 m range) should be investigated upstairs.")
	await _free_guard(guard)
	print("  [expanded-ai] hearing: open sprint investigated at an estimate (not the spot); through a wall not heard; through the slab a walk is not heard, a sprint overhead is")


# --- E. Detection, pursuit, losing the player -----------------------------------------------------

func _check_chase_and_loss() -> void:
	var post := Vector3(0, 0, 24)
	var guard := await _spawn_guard("ChaseGuard", [post], Vector3(0, 0, -1))
	var states: Array[int] = []
	guard.ai_state_changed.connect(func(_from, to, _r): states.append(to))
	var seen_at := Vector3(0, 0, 15)
	_player.global_position = seen_at + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	_expect(await _wait_state(guard, CHASE, 8.0), "Pursuit: a guard facing a player 9 m away in the open lobby should start a chase.")
	# The player slips away out of sight (into Study 1).
	var hidden := Vector3(-9, 0, -20)
	_player.global_position = hidden + Vector3(0, 0.05, 0)
	_expect(await _wait_state(guard, INVESTIGATE, 12.0), "Pursuit: after losing sight the guard should investigate.")
	var target := guard.agent.target_position
	_expect(target.distance_to(seen_at) < 4.0 and target.distance_to(hidden) > 20.0,
		"Pursuit: the guard should search where it last saw the player %s, not where the player is now (target %s)." % [seen_at, target])
	_expect(await _wait_state(guard, PATROL, 25.0), "Pursuit: after searching the guard should go back to patrol.")
	# A sighting first raises suspicion (INVESTIGATE) and then confirms it (CHASE); from the chase on:
	var from_chase := states.slice(states.find(CHASE)) if states.has(CHASE) else []
	_expect(from_chase == [CHASE, INVESTIGATE, PATROL], "Pursuit: from the chase on, states should go CHASE → INVESTIGATE → PATROL (got %s)." % [states])
	await _free_guard(guard)
	print("  [expanded-ai] pursuit: PATROL → CHASE → INVESTIGATE at the last seen spot (not the player's hiding place) → PATROL")


# --- F. Pursuit across floors ------------------------------------------------------------------

func _check_chase_across_floors() -> void:
	var post := Vector3(-10.35, 0, 21.4)   # at the foot of S1, facing up the stair
	var guard := await _spawn_guard("StairGuard", [post], Vector3(0, 0, -1))
	var top := Vector3(-10.35, U, 8.5)
	_player.global_position = top + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	_expect(await _wait_state(guard, CHASE, 8.0), "Stair pursuit: a guard at the foot of S1 should see the player at the top and chase.")
	_player.global_position = Vector3(-25, U + 0.05, -18)   # gone into the upper stacks
	var highest := -INF
	var lowest_after := INF
	var went_up := false
	var back_on_patrol := false
	for i in 60 * 70:
		await _host.get_tree().physics_frame
		highest = maxf(highest, guard.global_position.y)
		if highest > U - 0.3:
			went_up = true
		if went_up:
			lowest_after = minf(lowest_after, guard.global_position.y)
		if went_up and guard.machine.current == PATROL and guard.global_position.distance_to(post) < 1.5:
			back_on_patrol = true
			break
	_expect(went_up, "Stair pursuit: the guard should follow up S1 to the upper floor (highest y %.2f)." % highest)
	_expect(back_on_patrol, "Stair pursuit: after searching upstairs the guard should walk back down to its post (now at %s, %s)." % [
		guard.global_position, GuardStateMachine.NAMES[guard.machine.current] if guard.machine.current >= 0 else "NONE"])
	_expect(lowest_after < 0.3, "Stair pursuit: the guard should end on the ground floor again.")
	await _free_guard(guard)
	print("  [expanded-ai] stair pursuit: chased up S1, searched the upper floor, walked back down to its post")


# --- G. Narrow passages -----------------------------------------------------------------------

func _check_narrow_passages() -> void:
	_player.global_position = Vector3(0, 0.05, 32)
	for crossing in [["Study 3 door (2 m)", Vector3(3, 0, -10.5), Vector3(3, 0, -18)],
			["S2 staff stair (3 m)", Vector3(34.35, 0, 7.5), Vector3(34.35, U, -9.5)]]:
		var a := await _spawn_guard("CrossA", [crossing[2]], Vector3.ZERO, crossing[1], false)
		var b := await _spawn_guard("CrossB", [crossing[1]], Vector3.ZERO, crossing[2], false)
		var stuck := [0]
		a.got_stuck.connect(func(_i): stuck[0] += 1)
		b.got_stuck.connect(func(_i): stuck[0] += 1)
		var ok := false
		for i in 60 * 40:
			await _host.get_tree().physics_frame
			if a.global_position.distance_to(crossing[2]) < 0.9 and b.global_position.distance_to(crossing[1]) < 0.9:
				ok = true
				break
		_expect(ok and stuck[0] == 0, "Narrow passage, %s: two guards crossing head-on should both get through (ok %s, stuck %d)." % [crossing[0], ok, stuck[0]])
		await _free_guard(a)
		await _free_guard(b)
	# One guard tours every gate and all three stairs (faster than patrol pace, time sped up 2×).
	var tour: Array[Vector3] = [Vector3(14.5, 0, 10), Vector3(25, 0, 3), Vector3(33, U, -9), Vector3(20, U, -11),
		Vector3(3, U, -11), Vector3(-20, U, -10), Vector3(-30, U, 6), Vector3(-24, 0, 19), Vector3(0, 0, 20),
		Vector3(4, U, 1), Vector3(3, U, -11.5), Vector3(-8, U, -11), Vector3(-10, U, 3), Vector3(-3, 0, 15), Vector3(8, 0, 4), Vector3(14.5, 0, 4)]
	var guard := await _spawn_guard("TourGuard", tour, Vector3.ZERO, Vector3(0, 0, 20), false)
	guard.patrol_speed = 3.5
	var reached := []
	var stuck := [0]
	guard.patrol_point_reached.connect(func(i): reached.append(i))
	guard.got_stuck.connect(func(_i): stuck[0] += 1)
	var passed := {}
	Engine.time_scale = 2.0
	for i in 60 * 120:
		await _host.get_tree().physics_frame
		for g in Layout.GATES:
			if guard.global_position.distance_to(Layout.find_opening(g.opening).centre) < 1.2:
				passed[g.opening] = true
		if reached.size() == tour.size():
			break
	Engine.time_scale = 1.0
	_expect(reached.size() == tour.size() and stuck[0] == 0, "Tour: the guard should reach all %d points without getting stuck (reached %d, stuck %d)." % [
		tour.size(), reached.size(), stuck[0]])
	for name in ["Lobby Staff Door G4", "Archive Back Gate G3", "Archive Front Gate G2", "Staff Wing Door G1a", "Staff Door (Stacks) G1b", "Service Shortcut SC1"]:
		_expect(passed.has(name), "Tour: the guard never went through %s." % name)
	await _free_guard(guard)
	print("  [expanded-ai] narrow passages: head-on crossings in a 2 m door and on S2; tour through G1a, G1b, G2, G3, G4, SC1, up S2, down S3, up and down S1, with 0 stuck")


# --- Helpers ------------------------------------------------------------------------------------

func _load(keep_guards: bool) -> void:
	_level = (load(SCENE) as PackedScene).instantiate()
	if not keep_guards:
		for g in _level.get_node("Guards").get_children():
			if g is Guard:
				g.get_parent().remove_child(g)
				g.free()
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, _level, Layout.SPAWN), "Navigation never became ready.")
	_map = _level.get_world_3d().navigation_map
	_player = _level.get_node("Player")
	GameFlow.find(_level).change_scene = func(_path: String): pass
	await _frames(10)


func _unload() -> void:
	Engine.time_scale = 1.0
	_level.queue_free()
	await _frames(30)


func _level_guards() -> Array[Guard]:
	var out: Array[Guard] = []
	for g in _level.get_node("Guards").get_children():
		if g is Guard:
			out.append(g)
	return out


## A test guard with its own route through `points`, starting at `start`
## (default: the first point) and facing `facing` (default: toward the first point).
func _spawn_guard(guard_name: String, points: Array, facing: Vector3, start = null, loop := true) -> Guard:
	var route := PatrolRoute.new()
	route.name = guard_name + "Route"
	route.loop = loop
	for p in points:
		var marker := PatrolPoint.new()
		marker.position = p
		route.add_child(marker)
	_level.add_child(route)
	var guard: Guard = (load(GUARD_SCENE) as PackedScene).instantiate()
	guard.name = guard_name
	guard.patrol_route = route
	var at: Vector3 = start if start != null else points[0]
	var look: Vector3 = facing if facing != Vector3.ZERO else (points[0] - at)
	guard.position = at + Vector3(0, 0.05, 0)
	if look.length_squared() > 0.001:
		guard.rotation.y = atan2(-look.x, -look.z)
	_level.add_child(guard)
	for i in 30:
		await _host.get_tree().physics_frame
		if guard.machine != null and guard.machine.current != GuardStateMachine.NONE:
			break
	return guard


func _free_guard(guard: Guard) -> void:
	var route := guard.patrol_route
	guard.queue_free()
	if route:
		route.queue_free()
	await _frames(3)


func _wait_state(guard: Guard, state: int, seconds: float) -> bool:
	for i in int(seconds * 60):
		if guard.machine.current == state:
			return true
		await _host.get_tree().physics_frame
	return guard.machine.current == state


func _length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


func _frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
