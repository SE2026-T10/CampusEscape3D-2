extends RefCounted

## Phase 7 hearing and noise tests. Called from tests/test_scene.gd.
## Arena checks use exact geometry (floor, one wall, two guards that stand
## still); library checks run hearing together with the AI state machine.

const GUARD_SCENE := "res://scenes/npc/guard.tscn"
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const LIBRARY_SCENE := "res://scenes/level/library_graybox.tscn"
const TestUtils := preload("res://tests/test_utils.gd")
const T := NoiseEvent.Type

var failures: Array[String] = []
var _host: Node
var _arena: Node3D
var _noise: NoiseSystem
var _a: Guard
var _b: Guard
var _player: FirstPersonPlayer
var _reports := {}   # guard name -> Array of {estimate, loudness, event}


func run(host: Node) -> Array[String]:
	_host = host
	_check_event_presets()
	_build_arena()
	await _frames(3)
	await _check_range()
	await _check_walls_muffle()
	await _check_estimates()
	await _check_stale_and_expired()
	await _check_duplicates_and_merging()
	await _check_multiple_guards_and_sources()
	await _check_player_footsteps()
	await _check_noise_maker()
	_arena.queue_free()
	await _frames(2)
	await _check_with_ai_in_library()
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[hearing] " + message)


# --- Arena ----------------------------------------------------------------------

func _build_arena() -> void:
	_arena = Node3D.new()
	_arena.name = "HearingArena"
	_host.add_child(_arena)
	_box(Vector3(0, -0.1, 0), Vector3(100, 0.2, 100))
	_box(Vector3(10, 1.5, -8), Vector3(6, 3, 0.3))   # wall spanning x 7..13
	_noise = NoiseSystem.new()
	_arena.add_child(_noise)
	_a = _guard("GuardA", Vector3(0, 0, 0))
	_b = _guard("GuardB", Vector3(22, 0, 0))
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_player.position = Vector3(-30, 0.05, 30)  # Set before entering the tree so bodies never overlap.
	_arena.add_child(_player)


func _box(centre: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	_arena.add_child(body)
	body.global_position = centre


func _guard(guard_name: String, at: Vector3) -> Guard:
	var guard: Guard = (load(GUARD_SCENE) as PackedScene).instantiate()
	guard.name = guard_name  # No route and no navigation here: it stands still and just listens.
	guard.position = at
	_arena.add_child(guard)
	_reports[guard_name] = []
	guard.hearing.noise_reported.connect(func(est, loud, ev): _reports[guard_name].append({"estimate": est, "loudness": loud, "event": ev}))
	return guard


func _clear() -> void:
	for key in _reports:
		_reports[key].clear()
	for guard in [_a, _b]:
		guard.hearing.has_report = false
		guard.hearing.reported_count = 0
		guard.hearing.merged_count = 0
		guard.hearing.stale_count = 0
		guard.hearing.duplicate_count = 0


## Emits a noise and lets listeners process it. Returns the event.
func _emit(at: Vector3, type: T, source := "player") -> NoiseEvent:
	var event := _noise.emit_noise(at, type, source)
	await _frames(2)
	return event


func _heard(guard: Guard) -> int:
	return _reports[guard.name].size()


# --- Checks ---------------------------------------------------------------------

func _check_event_presets() -> void:
	var p := NoiseEvent.PRESETS
	_expect(p[T.WALK].radius < p[T.INTERACTION].radius and p[T.INTERACTION].radius < p[T.RUN].radius,
		"Radii should rank walk < interaction < run.")
	_expect(p[T.WALK].intensity < p[T.RUN].intensity, "Running should be louder than walking.")
	var e := NoiseEvent.new()
	e.intensity = 1.0
	_expect(e.loudness_at(2.0, 10.0) > e.loudness_at(6.0, 10.0) and e.loudness_at(10.0, 10.0) == 0.0,
		"Loudness should fall with distance and reach 0 at the radius.")


func _check_range() -> void:
	_clear()
	await _emit(Vector3(0, 0, -4), T.WALK)
	_expect(_heard(_a) == 1, "A walking step 4 m away (radius 5) should be heard.")
	await _frames(70)  # past the merge window
	_clear()
	await _emit(Vector3(0, 0, -6), T.WALK)
	_expect(_heard(_a) == 0, "A walking step 6 m away (radius 5) should not be heard.")
	await _emit(Vector3(-11, 0, 0), T.RUN)
	_expect(_heard(_a) == 1, "A running step 11 m away (radius 12) should be heard.")
	_clear()
	await _frames(70)
	await _emit(Vector3(-13, 0, 0), T.RUN)
	_expect(_heard(_a) == 0, "A running step 13 m away should not be heard.")


func _check_walls_muffle() -> void:
	_a.global_position = Vector3(10, 0, -3)
	await _frames(70)
	_clear()
	await _emit(Vector3(10, 0, -12), T.RUN)  # 9 m, behind the wall: radius halved to 6
	_expect(_heard(_a) == 0, "A running step 9 m away behind a wall should be muffled out of range.")
	await _emit(Vector3(16, 0, -12), T.RUN)  # same distance, clear of the wall
	_expect(_heard(_a) == 1, "Control: the same step clear of the wall should be heard.")
	_a.global_position = Vector3.ZERO
	await _frames(70)


func _check_estimates() -> void:
	var h := _a.hearing
	var errors_near: Array[float] = []
	var errors_far: Array[float] = []
	var exact := 0
	var out_of_bounds := 0
	for i in 20:
		var angle := TAU * i / 20.0
		for distance in [2.0, 10.0]:
			var event := NoiseEvent.new()
			event.id = 10000 + i * 2 + int(distance)
			event.position = Vector3(cos(angle), 0, sin(angle)) * distance
			var estimate := h.estimate_position(event, distance, false)
			var error := estimate.distance_to(event.position)
			var bound := minf(h.error_base + h.error_per_metre * distance, h.error_max)
			if error < 0.01:
				exact += 1
			if error < 0.6 * bound - 0.001 or error > bound + 0.001:
				out_of_bounds += 1
			(errors_near if distance == 2.0 else errors_far).append(error)
			_expect(estimate == h.estimate_position(event, distance, false), "Estimates must be deterministic.")
	_expect(exact == 0, "%d estimates were exactly the source position." % exact)
	_expect(out_of_bounds == 0, "%d estimates fell outside 60–100%% of the error bound." % out_of_bounds)
	var near := _mean(errors_near)
	var far := _mean(errors_far)
	_expect(far > near, "Estimates should be less accurate far away (mean %.2f m at 2 m, %.2f m at 10 m)." % [near, far])
	# Two guards hearing the same noise estimate it differently.
	_clear()
	var shared := await _emit(Vector3(11, 0, 0), T.RUN)  # 11 m from both guards
	var ea: Vector3 = _reports["GuardA"][0].estimate if _heard(_a) > 0 else Vector3.ZERO
	var eb: Vector3 = _reports["GuardB"][0].estimate if _heard(_b) > 0 else Vector3.ZERO
	_expect(_heard(_a) == 1 and _heard(_b) == 1 and ea.distance_to(eb) > 0.1,
		"Two guards should both hear a run 11 m away and estimate it differently.")
	_expect(ea.distance_to(shared.position) > 0.2 and eb.distance_to(shared.position) > 0.2, "Neither guard may get the exact source.")
	print("  [hearing] estimate error: mean %.2f m at 2 m, %.2f m at 10 m; never exact; two guards differ by %.2f m" % [
		near, far, ea.distance_to(eb)])
	await _frames(70)


func _check_stale_and_expired() -> void:
	_clear()
	var h := _a.hearing
	var old := NoiseEvent.new()
	old.id = 50001
	old.type = T.RUN
	old.position = Vector3(0, 0, -3)
	old.intensity = 1.0
	old.radius = 12.0
	old.lifetime = 0.5
	old.timestamp = _noise.now - 2.0
	_expect(not h.process_event(old, _noise.now), "A 2-second-old noise must be ignored as stale.")
	_expect(h.stale_count == 1, "The stale noise should be counted as stale.")
	# A real noise that waits too long before this listener processes it is stale too.
	h.process_mode = Node.PROCESS_MODE_DISABLED
	_noise.emit_noise(Vector3(0, 0, -3), T.RUN, "player")
	await _frames(int(Engine.physics_ticks_per_second * 1.0))
	h.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(2)
	_expect(_heard(_a) == 0 and h.stale_count == 2, "A noise processed 1 s late should be dropped as stale.")
	_expect(_noise.get_active_events().is_empty(), "Expired events should leave the NoiseSystem's active list.")
	await _frames(70)


func _check_duplicates_and_merging() -> void:
	_clear()
	var h := _a.hearing
	var event := _noise.emit_noise(Vector3(0, 0, -3), T.RUN, "player")
	h.receive(event)  # Delivered a second time.
	await _frames(2)
	_expect(_heard(_a) == 1 and h.duplicate_count == 1, "The same event delivered twice must be processed once.")
	await _frames(70)
	_clear()
	for i in 5:
		_noise.emit_noise(Vector3(0.2 * i, 0, -3), T.RUN, "player")  # Footsteps in one spot
		await _frames(8)
	_expect(_heard(_a) == 1 and h.merged_count == 4, "Five footsteps in one spot within 1 s should give 1 report (got %d, merged %d)." % [_heard(_a), h.merged_count])
	await _emit(Vector3(0, 0, 7), T.RUN)  # A different place right away
	_expect(_heard(_a) == 2, "A noise far from the last report should be reported even inside the merge window.")
	await _frames(70)
	await _emit(Vector3(0.1, 0, 7.1), T.RUN)  # Same place again, but after the merge window
	_expect(_heard(_a) == 3, "After the merge window the same spot should be reported again.")
	await _frames(70)


func _check_multiple_guards_and_sources() -> void:
	_clear()
	await _emit(Vector3(19, 0, 0), T.WALK)
	_expect(_heard(_b) == 1 and _heard(_a) == 0, "A step near GuardB should be heard by B only.")
	await _frames(70)
	_clear()
	await _emit(Vector3(0, 0, -3), T.RUN, "guards")
	_expect(_heard(_a) == 0, "Guards should ignore noises from their own source group.")


func _check_player_footsteps() -> void:
	var counts := {}
	var heard_estimates: Array = []
	var emitted_at: Array = []
	_noise.noise_emitted.connect(func(e: NoiseEvent):
		counts[e.type_name()] = counts.get(e.type_name(), 0) + 1
		emitted_at.append(e.position))
	_player.global_position = Vector3(-20, 0.05, 10)
	_player.rotation = Vector3.ZERO
	await _frames(30)
	counts.clear()
	await _frames(60)
	_expect(counts.is_empty(), "A player standing still must make no noise (made %s)." % [counts])
	_player.global_position = Vector3(-20, 0.05, 20)  # teleport
	await _frames(5)
	_expect(counts.is_empty(), "Teleporting must not make footsteps.")
	Input.action_press("move_forward")
	await _frames(120)
	Input.action_release("move_forward")
	await _frames(20)
	var walk_steps: int = counts.get("WALK", 0)
	_expect(walk_steps >= 6 and walk_steps <= 10 and not counts.has("RUN"),
		"Walking 2 s (~7 m) should make about 8 WALK steps and no RUN (made %s)." % [counts])
	counts.clear()
	_player.global_position = Vector3(-20, 0.05, 25)
	await _frames(10)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(120)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _frames(20)
	var run_steps: int = counts.get("RUN", 0)
	_expect(run_steps >= 6 and run_steps <= 11, "Sprinting 2 s (~11 m) should make about 9 RUN steps (made %s)." % [counts])
	print("  [hearing] player footsteps: walking 2 s → %d WALK, sprinting 2 s → %s, standing → none" % [walk_steps, counts])
	# Footsteps heard by a guard are only ever estimates.
	_clear()
	_a.global_position = Vector3(-26, 0, 30)
	await _frames(70)
	emitted_at.clear()
	_player.global_position = Vector3(-20, 0.05, 32)
	await _frames(10)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(60)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _frames(10)
	var closest_to_truth := INF
	for report in _reports["GuardA"]:
		closest_to_truth = minf(closest_to_truth, report.estimate.distance_to(report.event.position))
	_expect(_heard(_a) >= 1, "A guard 6 m away should hear the player sprinting.")
	_expect(closest_to_truth > 0.2, "Heard footsteps must never give the exact position (closest estimate %.2f m off)." % closest_to_truth)
	_a.global_position = Vector3.ZERO


func _check_noise_maker() -> void:
	var maker := NoiseMaker.new()
	_arena.add_child(maker)
	maker.global_position = Vector3(5, 0, 5)
	var event := maker.make_noise()
	_expect(event != null and event.type == T.INTERACTION and event.position == Vector3(5, 0, 5)
		and is_equal_approx(event.radius, NoiseEvent.PRESETS[T.INTERACTION].radius),
		"NoiseMaker should emit an INTERACTION noise at its position with the preset radius.")
	_expect(event.timestamp == _noise.now and event.lifetime > 0.0, "Events should carry a timestamp and lifetime.")
	maker.queue_free()


# --- With the AI, in the library ----------------------------------------------------

func _check_with_ai_in_library() -> void:
	var level: Node3D = (load(LIBRARY_SCENE) as PackedScene).instantiate()
	for node_name in ["Guards", "StealthDirector"]:  # Being caught is tested in loop_tests.gd.
		var node := level.get_node(node_name)
		level.remove_child(node)
		node.free()
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, level, Vector3(2, 0, -3)), "Navigation never became ready.")
	var player: FirstPersonPlayer = level.get_node("Player")
	player.global_position = Vector3(0, 0.05, 20)
	var route := PatrolRoute.new()
	var post := PatrolPoint.new()
	post.position = Vector3(2, 0, -3)
	post.wait_time = 120.0
	route.add_child(post)
	level.add_child(route)
	var guard: Guard = (load(GUARD_SCENE) as PackedScene).instantiate()
	guard.name = "HearingTestGuard"
	guard.patrol_route = route
	level.add_child(guard)
	guard.global_position = Vector3(2, 0.05, -3)
	guard.rotation.y = 0.0  # Facing north (-Z), toward the wall: the player will be behind it.
	var transitions: Array[String] = []
	guard.ai_state_changed.connect(func(f, t, r): transitions.append("%s→%s (%s)" % [GuardStateMachine.NAMES[f], GuardStateMachine.NAMES[t], r]))
	var noise: NoiseSystem = level.get_node("NoiseSystem")
	var step_positions: Array[Vector3] = []
	noise.noise_emitted.connect(func(e): step_positions.append(e.position))
	for i in 60:
		await _host.get_tree().physics_frame
		if guard.machine.current == GuardStateMachine.PATROL:
			break
	await _frames(30)

	# Walking quietly 7 m behind the guard: out of hearing range (walk radius 5).
	player.global_position = Vector3(-1.5, 0.05, 4)
	player.rotation.y = -PI / 2  # Facing +X: walks across behind the guard.
	await _frames(10)
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_release("move_forward")
	await _frames(20)
	_expect(guard.machine.current == GuardStateMachine.PATROL and guard.hearing.reported_count == 0,
		"Walking 7 m behind a guard should not be heard (state %s)." % guard.machine.get_state_name())

	# Sprinting behind the guard: heard, guard investigates an estimate near the steps.
	player.global_position = Vector3(-1.5, 0.05, 4)
	step_positions.clear()
	await _frames(10)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(30)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _frames(3)
	_expect(transitions.size() >= 1 and transitions[0] == "PATROL→INVESTIGATE (noise)",
		"Sprinting behind a guard should make it INVESTIGATE because of the noise (transitions %s)." % [transitions])
	if guard.machine.current == GuardStateMachine.INVESTIGATE:
		var target := (guard.machine.get_current_state() as InvestigateState).target
		var nearest := INF
		for p in step_positions:
			nearest = minf(nearest, Vector2(target.x - p.x, target.z - p.z).length())
		var to_player := Vector2(target.x - player.global_position.x, target.z - player.global_position.z).length()
		_expect(nearest > 0.2 and nearest < 2.0, "The investigation should target an estimate near a footstep, not the exact spot (%.2f m off)." % nearest)
		_expect(to_player > 0.2, "The investigation target must not be the player's exact position.")
		print("  [hearing] sprint behind guard → %s; target %.2f m from nearest footstep" % [transitions[0], nearest])

	# Priority: a confirmed sighting is not overridden by a loud noise elsewhere.
	# A fresh guard posted facing south toward the player 7 m away.
	guard.queue_free()
	var watcher: Guard = (load(GUARD_SCENE) as PackedScene).instantiate()
	watcher.name = "PriorityGuard"
	watcher.patrol_route = route
	watcher.position = Vector3(2, 0.05, -3)
	watcher.rotation.y = PI
	level.add_child(watcher)
	guard = watcher
	player.global_position = Vector3(2, 0.05, 4)
	for i in 400:
		await _host.get_tree().physics_frame
		if guard.machine.current == GuardStateMachine.CHASE:
			break
	_expect(guard.machine.current == GuardStateMachine.CHASE, "Facing the player at 7 m should lead to CHASE (state %s)." % guard.machine.get_state_name())
	var chase_target := guard.agent.target_position
	noise.emit_noise(Vector3(10, 0, 10), T.RUN, "environment")
	noise.emit_noise(Vector3(8, 0, 9), T.INTERACTION, "environment")
	await _frames(10)
	_expect(guard.machine.current == GuardStateMachine.CHASE, "Loud noises elsewhere must not interrupt a chase.")
	_expect(guard.agent.target_position.distance_to(Vector3(10, 0, 10)) > 5.0 and guard.agent.target_position.distance_to(chase_target) < 2.0,
		"The chase target must keep following sight, not the noise.")
	level.queue_free()
	await _frames(2)


# --- Helpers -----------------------------------------------------------------------

func _mean(values: Array[float]) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / maxf(values.size(), 1)


func _frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
