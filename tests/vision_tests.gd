extends RefCounted

## Phase 5 vision and detection tests. Called from tests/test_scene.gd.
##
## Most checks run in a small arena built here (floor, a wall, a low table, a
## tall shelf) with the real guard and player scenes, so distances and angles
## are exact. A final check loads the library itself.

const GUARD_SCENE := "res://scenes/npc/guard.tscn"
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const LIBRARY_SCENE := "res://scenes/level/library_graybox.tscn"
const TestUtils := preload("res://tests/test_utils.gd")
const TIME_SCALE := 4.0

var failures: Array[String] = []
var _host: Node
var _arena: Node3D
var _guard: Guard
var _vision: GuardVision
var _player: FirstPersonPlayer
var _log: Array[String] = []   # signal log for the current scenario


func run(host: Node) -> Array[String]:
	_host = host
	_build_arena()
	await _physics_frames(3)
	var previous_scale := Engine.time_scale
	Engine.time_scale = TIME_SCALE

	_check_view_maths()
	await _check_sees_player_in_front()
	await _check_meter_decays_and_position_is_not_tracked()
	await _check_wall_blocks_sight()
	await _check_outside_fov()
	await _check_distance_limits()
	await _check_cover()
	await _check_configurable_thresholds()
	await _check_debug_cone_stops_at_wall()

	_arena.queue_free()
	await _physics_frames(2)
	await _check_library()
	Engine.time_scale = previous_scale
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[vision] " + message)


# --- Arena --------------------------------------------------------------------

func _build_arena() -> void:
	_arena = Node3D.new()
	_arena.name = "VisionArena"
	_host.add_child(_arena)
	_box("Floor", Vector3(0, -0.1, 0), Vector3(80, 0.2, 80))
	_box("Wall", Vector3(10, 1.5, -8), Vector3(6, 3, 0.3))         # spans x 7..13
	_box("LowTable", Vector3(-10, 0.375, -4), Vector3(2, 0.75, 1))
	_box("TallShelf", Vector3(-20, 1.1, -4), Vector3(2, 2.2, 0.6))
	_guard = (load(GUARD_SCENE) as PackedScene).instantiate()
	_guard.name = "VisionTestGuard"  # No patrol route: it stands still where it is put.
	_arena.add_child(_guard)
	_vision = _guard.vision
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_arena.add_child(_player)
	_vision.awareness_changed.connect(func(_a, b): _log.append(GuardVision.Awareness.keys()[b]))
	_vision.target_spotted.connect(func(): _log.append("spotted"))
	_vision.target_lost.connect(func(): _log.append("lost"))


func _box(box_name: String, centre: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	_arena.add_child(body)
	body.global_position = centre


## Places guard and player and clears the guard's memory.
func _setup(guard_at: Vector3, guard_yaw_degrees: float, player_at: Vector3) -> void:
	_guard.global_position = guard_at
	_guard.rotation = Vector3(0, deg_to_rad(guard_yaw_degrees), 0)
	_player.global_position = player_at
	_player.velocity = Vector3.ZERO
	_vision.detection = 0.0
	_vision.awareness = GuardVision.Awareness.UNAWARE
	_vision.can_see_target = false
	_vision.has_last_known_position = false
	_vision.time_since_seen = INF
	_log.clear()


## Steps physics for `seconds` of simulated time; returns true if the player was ever seen.
func _run(seconds: float) -> bool:
	var seen := false
	var t := 0.0
	while t < seconds:
		await _host.get_tree().physics_frame
		t += _step()
		seen = seen or _vision.can_see_target
	return seen


# --- Scenarios ----------------------------------------------------------------

func _check_view_maths() -> void:
	_setup(Vector3.ZERO, 0.0, Vector3(50, 0, 50))
	var eye := Vector3(0, 1.6, 0)
	_expect(_vision.is_in_view(eye + Vector3(0, 0, -5)), "Straight ahead should be in view.")
	_expect(_vision.is_in_view(eye + Vector3(0, 0, -5).rotated(Vector3.UP, deg_to_rad(-44))), "44° off-axis should be in a 90° cone.")
	_expect(not _vision.is_in_view(eye + Vector3(0, 0, -5).rotated(Vector3.UP, deg_to_rad(-46))), "46° off-axis should be outside a 90° cone.")
	_expect(not _vision.is_in_view(eye + Vector3(0, 0, 3)), "Behind the guard should be out of view.")
	_expect(not _vision.is_in_view(eye + Vector3(0, 0, -_vision.detection_distance - 0.5)), "Beyond detection_distance should be out of view.")
	_expect(is_equal_approx(_vision.rise_rate_at(1.0), _vision.max_rise_rate), "Inside near_distance the meter should rise at max_rise_rate.")
	_expect(is_equal_approx(_vision.rise_rate_at(_vision.detection_distance), _vision.min_rise_rate), "At max distance the meter should rise at min_rise_rate.")
	_expect(_vision.rise_rate_at(_vision.detection_distance + 1.0) == 0.0, "Out of range the meter should not rise.")
	_expect(_vision.rise_rate_at(6.0) > _vision.rise_rate_at(10.0), "Closer targets should fill the meter faster.")


func _check_sees_player_in_front() -> void:
	_setup(Vector3.ZERO, 0.0, Vector3(0, 0, -6))
	var t := 0.0
	var first_seen := -1.0
	var suspicious_at := -1.0
	var previous := 0.0
	var monotonic := true
	while t < 5.0 and _vision.detection < 100.0:
		await _host.get_tree().physics_frame
		t += _step()
		if _vision.can_see_target and first_seen < 0.0:
			first_seen = t
		if _vision.awareness == GuardVision.Awareness.SUSPICIOUS and suspicious_at < 0.0:
			suspicious_at = t
		monotonic = monotonic and _vision.detection >= previous
		previous = _vision.detection
	var distance := Vector3(0, 1.6, 0).distance_to(Vector3(0, 1.5, -6))
	var expected := 100.0 / _vision.rise_rate_at(distance)
	_expect(first_seen >= 0.0 and first_seen <= 2.0 * _step(), "Player straight ahead at 6 m should be seen at once (first seen %.2fs)." % first_seen)
	_expect(monotonic, "The meter should only rise while the player is visible.")
	_expect(absf(t - expected) <= 2.0 * _step(), "Meter reached 100 in %.2fs; expected %.2fs at %.1f m." % [t, expected, distance])
	_expect(_log == ["spotted", "SUSPICIOUS", "ALERTED"], "Expected spotted → SUSPICIOUS → ALERTED, got %s." % [_log])
	_expect(_vision.has_last_known_position and _vision.last_known_position.distance_to(_player.global_position) < 0.05,
		"Last known position should be where the player stands.")
	print("  [vision] player 6 m ahead: seen after %.2fs, SUSPICIOUS at %.2fs, ALERTED (100) at %.2fs (expected %.2fs)" % [
		first_seen, suspicious_at, t, expected])


## Continues from the previous scenario: the meter is full and the player steps out of view.
func _check_meter_decays_and_position_is_not_tracked() -> void:
	var seen_at := _vision.last_known_position
	_log.clear()
	_player.global_position = Vector3(0, 0, 4)  # Behind the guard.
	await _run(_vision.decay_delay * 0.8)
	_expect(not _vision.can_see_target, "A player behind the guard should not be visible.")
	_expect(is_equal_approx(_vision.detection, 100.0), "The meter should hold during decay_delay (was %.1f)." % _vision.detection)
	await _run(_vision.decay_delay * 0.2 + 2.0)
	var expected := 100.0 - 2.0 * _vision.decay_rate
	_expect(absf(_vision.detection - expected) <= 2.0, "After 2 s of decay the meter should be about %.0f, was %.1f." % [expected, _vision.detection])
	# Walk the player around out of sight: the guard must not learn where they are.
	for spot in [Vector3(3, 0, 3), Vector3(-4, 0, 5), Vector3(6, 0, 1)]:
		_player.global_position = spot
		await _run(0.5)
	_expect(_vision.last_known_position.distance_to(seen_at) < 0.001,
		"Last known position changed while the player was hidden (now %s, last seen %s)." % [_vision.last_known_position, seen_at])
	await _run(100.0 / _vision.decay_rate)
	_expect(_vision.detection == 0.0, "The meter should drain to 0 (was %.1f)." % _vision.detection)
	_expect(_vision.awareness == GuardVision.Awareness.UNAWARE, "Awareness should return to UNAWARE.")
	_expect(_log == ["lost", "SUSPICIOUS", "UNAWARE"], "Expected lost → SUSPICIOUS → UNAWARE, got %s." % [_log])
	print("  [vision] after losing sight: held 100 for %.1fs, %.1f after 2 s of decay, back to 0 and UNAWARE; last known position unchanged" % [
		_vision.decay_delay, expected])


func _check_wall_blocks_sight() -> void:
	# Player 9 m ahead, inside the cone and in range, but behind the wall.
	_setup(Vector3(10, 0, -3), 0.0, Vector3(10, 0, -12))
	var seen := await _run(2.0)
	_expect(not seen, "The guard saw the player through a wall.")
	_expect(_vision.detection == 0.0 and not _vision.has_last_known_position, "No detection or position should leak through a wall.")
	# Control: same distance, moved just clear of the wall's edge.
	_setup(Vector3(10, 0, -3), 0.0, Vector3(16, 0, -12))
	_expect(await _run(0.5), "Control failed: the player beside the wall should be visible.")


func _check_outside_fov() -> void:
	var cases := {
		"3 m to the right": Vector3(3, 0, 0),
		"2 m behind": Vector3(0, 0, 2),
		"50° off-axis": Vector3(0, 0, -5).rotated(Vector3.UP, deg_to_rad(-50)),
	}
	for label in cases:
		_setup(Vector3.ZERO, 0.0, cases[label])
		_expect(not await _run(1.0), "Player %s should be outside a %.0f° cone." % [label, _vision.fov_degrees])
	_setup(Vector3.ZERO, 0.0, Vector3(0, 0, -5).rotated(Vector3.UP, deg_to_rad(-40)))
	_expect(await _run(0.5), "Player 40° off-axis should be inside a %.0f° cone." % _vision.fov_degrees)
	# The cone turns with the guard.
	_setup(Vector3.ZERO, -90.0, Vector3(5, 0, 0))
	_expect(await _run(0.5), "After turning to face +X, the guard should see a player on its new forward side.")


func _check_distance_limits() -> void:
	_setup(Vector3.ZERO, 0.0, Vector3(0, 0, -(_vision.detection_distance + 1.5)))
	_expect(not await _run(2.0), "A player beyond detection_distance should not be seen.")
	# Just inside range: seen, but slowly.
	_setup(Vector3.ZERO, 0.0, Vector3(0, 0, -(_vision.detection_distance - 1.0)))
	await _run(1.0)
	_expect(_vision.can_see_target, "A player just inside detection_distance should be seen.")
	_expect(_vision.detection < _vision.suspicious_threshold,
		"At %.0f m, one second of sight should not reach SUSPICIOUS (meter %.1f)." % [_vision.detection_distance - 1.0, _vision.detection])
	print("  [vision] far detection: 1 s at %.0f m → meter %.1f (no instant detection); nothing at %.1f m" % [
		_vision.detection_distance - 1.0, _vision.detection, _vision.detection_distance + 1.5])


func _check_cover() -> void:
	_setup(Vector3(-10, 0, 0), 0.0, Vector3(-10, 0, -5.5))
	_expect(await _run(0.5), "A standing player behind a low table should still be visible (head above it).")
	_setup(Vector3(-20, 0, 0), 0.0, Vector3(-20, 0, -5.5))
	_expect(not await _run(1.0), "A player behind a tall shelf should be hidden.")


func _check_configurable_thresholds() -> void:
	var old := [_vision.suspicious_threshold, _vision.alert_threshold]
	_vision.suspicious_threshold = 10.0
	_vision.alert_threshold = 50.0
	_setup(Vector3.ZERO, 0.0, Vector3(0, 0, -2))
	var alerted_value := -1.0
	var t := 0.0
	while t < 3.0 and alerted_value < 0.0:
		await _host.get_tree().physics_frame
		t += _step()
		if _vision.awareness == GuardVision.Awareness.ALERTED:
			alerted_value = _vision.detection
	var step_gain := _vision.max_rise_rate * _step()
	_expect(alerted_value >= 50.0 and alerted_value < 50.0 + step_gain + 0.01,
		"With alert_threshold 50 the guard should become ALERTED at about 50 (was %.1f)." % alerted_value)
	_vision.suspicious_threshold = old[0]
	_vision.alert_threshold = old[1]


func _check_debug_cone_stops_at_wall() -> void:
	if not OS.is_debug_build():
		return
	_setup(Vector3(10, 0, -3), 0.0, Vector3(50, 0, 50))
	await _run(0.3)
	var outline := _vision.cone_outline
	_expect(outline.size() == _vision.debug_cone_rays + 1, "The debug cone should have one point per ray.")
	if outline.size() < 3:
		return
	var origin := Vector2(10, -3)
	var middle := Vector2(outline[outline.size() / 2].x, outline[outline.size() / 2].z).distance_to(origin)
	var edge := Vector2(outline[0].x, outline[0].z).distance_to(origin)
	_expect(middle < 4.9 and middle > 4.7, "The cone straight ahead should stop at the wall 4.85 m away (was %.2f m)." % middle)
	_expect(absf(edge - _vision.detection_distance) < 0.1, "The cone edge clear of the wall should reach full range (was %.2f m)." % edge)


func _check_library() -> void:
	var level: Node3D = (load(LIBRARY_SCENE) as PackedScene).instantiate()
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, level, Vector3(0, 0, 18)), "Library navigation never became ready.")
	var guards: Array[Guard] = []
	for node in _host.get_tree().get_nodes_in_group("guards"):
		if level.is_ancestor_of(node):
			guards.append(node)
	var visions := 0
	for guard in guards:
		if guard.vision:
			visions += 1
	_expect(guards.size() >= 3 and visions == guards.size(), "Every library guard should have a Vision node (%d of %d)." % [visions, guards.size()])
	# The player starts in the entrance, which no guard may see during a full
	# patrol loop of every guard (the longest loop takes about 36 s).
	Engine.time_scale = 6.0
	var seen := false
	var t := 0.0
	while t < 45.0:
		await _host.get_tree().physics_frame
		t += _step()
		for guard in guards:
			seen = seen or guard.vision.can_see_target or guard.vision.detection > 0.0
	Engine.time_scale = TIME_SCALE
	_expect(not seen, "A guard detected the player standing at the spawn point within 45 s.")
	var hud := level.get_node_or_null("DetectionDebugHud")
	if OS.is_debug_build():
		_expect(hud != null and hud.get_text().count("Guard") >= guards.size(), "The detection HUD should list every guard.")
	level.queue_free()
	await _physics_frames(2)


# --- Helpers ------------------------------------------------------------------

func _step() -> float:
	return Engine.time_scale / Engine.physics_ticks_per_second


func _physics_frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
