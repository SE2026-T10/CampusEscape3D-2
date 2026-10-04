extends RefCounted

## Phase 6 behaviour tests: a guard in the real library with the real player,
## vision and navigation. Runs the full PATROL → INVESTIGATE → CHASE →
## INVESTIGATE → PATROL cycle, then a noise investigation.

const LIBRARY_SCENE := "res://scenes/level/library_graybox.tscn"
const GUARD_SCENE := "res://scenes/npc/guard.tscn"
const TestUtils := preload("res://tests/test_utils.gd")
const TIME_SCALE := 4.0
## Guard post in the open middle of the main room, facing south (+Z).
const POST := Vector3(2, 0, -3)
const PLAYER_START := Vector3(2, 0, 4)
## Out of sight: the east hallway, behind the main room's east wall.
const HIDING_SPOT := Vector3(22.5, 0, -8)
const NOISE_SPOT := Vector3(6, 0, 10)

var failures: Array[String] = []
var _host: Node
var _level: Node3D
var _guard: Guard
var _player: FirstPersonPlayer
var _history: Array[String] = []
var _time := 0.0


func run(host: Node) -> Array[String]:
	_host = host
	_level = (load(LIBRARY_SCENE) as PackedScene).instantiate()
	# Only the test guard: remove the level's own guards.
	var guards := _level.get_node("Guards")
	_level.remove_child(guards)
	guards.free()
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, _level, POST), "Navigation never became ready.")
	_player = _level.get_node("Player")
	_player.global_position = Vector3(0, 0.05, 20)  # entrance, unseen

	var route := PatrolRoute.new()
	var post := PatrolPoint.new()
	post.position = POST
	post.wait_time = 60.0  # Stand at the post facing south.
	route.add_child(post)
	_level.add_child(route)
	_guard = (load(GUARD_SCENE) as PackedScene).instantiate()
	_guard.name = "AITestGuard"
	_guard.patrol_route = route
	_level.add_child(_guard)
	_guard.global_position = POST + Vector3(0, 0.05, 0)
	_guard.rotation.y = PI
	_guard.ai_state_changed.connect(func(f, t, reason): _history.append("%.1fs %s→%s (%s)" % [_time, GuardStateMachine.NAMES[f], GuardStateMachine.NAMES[t], reason]))
	await _run_until(func(): return _guard.machine.current == GuardStateMachine.PATROL, 5.0)

	var previous := Engine.time_scale
	Engine.time_scale = TIME_SCALE
	await _check_detection_cycle()
	await _check_noise_investigation()
	Engine.time_scale = previous

	_level.queue_free()
	await _physics_frames(2)
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[ai-level] " + message)


func _check_detection_cycle() -> void:
	_expect(_guard.machine.current == GuardStateMachine.PATROL, "The guard should start in PATROL.")
	_history.clear()
	_player.global_position = PLAYER_START + Vector3(0, 0.05, 0)

	# PATROL → INVESTIGATE (meter reaches 30) → CHASE (meter reaches 100).
	await _run_until(func(): return _guard.machine.current == GuardStateMachine.INVESTIGATE, 3.0)
	_expect(_guard.machine.current == GuardStateMachine.INVESTIGATE, "Seeing the player should first make the guard INVESTIGATE. History: %s" % [_history])
	await _run_until(func(): return _guard.machine.current == GuardStateMachine.CHASE, 5.0)
	_expect(_guard.machine.current == GuardStateMachine.CHASE, "Continued sight should escalate to CHASE. History: %s" % [_history])
	var start_gap := _guard.global_position.distance_to(_player.global_position)
	await _run(1.0)
	var gap := _guard.global_position.distance_to(_player.global_position)
	_expect(gap < start_gap - 1.0, "The chasing guard should close in (%.1f m → %.1f m)." % [start_gap, gap])

	# Hide: the guard must head for where it last saw the player, not where the player is.
	var seen_at := _guard.vision.last_known_position
	_player.global_position = HIDING_SPOT + Vector3(0, 0.05, 0)
	await _run(0.5)
	var nav_target := _guard.agent.target_position
	_expect(Vector2(nav_target.x - seen_at.x, nav_target.z - seen_at.z).length() < 1.0,
		"After losing sight the guard should go to the last known position %s (target %s)." % [seen_at, nav_target])
	_expect(nav_target.distance_to(_player.global_position) > 10.0,
		"The guard's target must not follow the hidden player (target %s, player %s)." % [nav_target, _player.global_position])

	# CHASE → INVESTIGATE (arrives or times out) → PATROL (search times out).
	await _run_until(func(): return _guard.machine.current == GuardStateMachine.INVESTIGATE, _guard.chase_lose_sight_time + 3.0)
	_expect(_guard.machine.current == GuardStateMachine.INVESTIGATE, "Losing the player should lead to INVESTIGATE. History: %s" % [_history])
	var inv := _guard.machine.get_state(GuardStateMachine.INVESTIGATE) as InvestigateState
	_expect(inv.target.distance_to(seen_at) < 1.0, "The investigation should be at the last known position.")
	await _run_until(func(): return _guard.machine.current == GuardStateMachine.PATROL, _guard.investigate_search_duration + 8.0)
	_expect(_guard.machine.current == GuardStateMachine.PATROL, "The guard should give up and return to PATROL. History: %s" % [_history])
	var expected := ["PATROL→INVESTIGATE (suspicious sighting)", "INVESTIGATE→CHASE (confirmed sighting)",
		"CHASE→INVESTIGATE (lost sight of the player)", "INVESTIGATE→PATROL (investigation timed out)"]
	var got := _history.map(func(h): return h.substr(h.find(" ") + 1))
	_expect(got == expected, "Unexpected transition sequence: %s" % [_history])
	print("  [ai-level] detection cycle: %s" % ", ".join(_history))


func _check_noise_investigation() -> void:
	await _run_until(func(): return _guard.machine.current == GuardStateMachine.PATROL, 5.0)
	_history.clear()
	_guard.hear_noise(NOISE_SPOT)
	await _run(0.2)
	_expect(_guard.machine.current == GuardStateMachine.INVESTIGATE and _guard.machine.last_reason == "noise", "A noise should make a patrolling guard INVESTIGATE.")
	var inv := _guard.machine.get_state(GuardStateMachine.INVESTIGATE) as InvestigateState
	await _run_until(func(): return inv.searching, 15.0)
	var distance := Vector2(_guard.global_position.x - NOISE_SPOT.x, _guard.global_position.z - NOISE_SPOT.z).length()
	_expect(inv.searching and distance < 1.2, "The guard should walk to the noise before searching (%.2f m away)." % distance)
	var search_start := _time
	await _run_until(func(): return _guard.machine.current == GuardStateMachine.PATROL, _guard.investigate_search_duration + 2.0)
	var searched := _time - search_start
	_expect(_guard.machine.current == GuardStateMachine.PATROL, "After searching, the guard should return to PATROL.")
	_expect(absf(searched - _guard.investigate_search_duration) < 0.3,
		"The search should last %.1fs (lasted %.2fs)." % [_guard.investigate_search_duration, searched])
	print("  [ai-level] noise: investigated (%.1f m from the noise), searched %.2fs, back to PATROL" % [distance, searched])


func _run(seconds: float) -> void:
	await _run_until(func(): return false, seconds)


func _run_until(done: Callable, max_seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < max_seconds and not done.call():
		await _host.get_tree().physics_frame
		var step := Engine.time_scale / Engine.physics_ticks_per_second
		elapsed += step
		_time += step


func _physics_frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
