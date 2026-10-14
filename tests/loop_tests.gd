extends RefCounted

## Phase 8 stealth-loop tests: crouching, hiding, the player-facing status,
## being caught and reset, escaping, and the HUD. Runs in the real library
## with one controlled test guard (the level's own guards are removed).

const LIBRARY_SCENE := "res://scenes/level/library_graybox.tscn"
const GUARD_SCENE := "res://scenes/npc/guard.tscn"
const TestUtils := preload("res://tests/test_utils.gd")
const S := StealthDirector.Status
const SPAWN := Vector3(0, 0.05, 21)
## Inside the west carrel (open to the east; side panels to the north and south).
const CARREL_WEST := Vector3(-12.6, 0.05, 11.6)

var failures: Array[String] = []
var _host: Node
var _level: Node3D
var _player: FirstPersonPlayer
var _director: StealthDirector
var _hud: StealthHud
var _guard: Guard
var _route: PatrolRoute


func run(host: Node) -> Array[String]:
	_host = host
	_check_status_priority()
	_level = (load(LIBRARY_SCENE) as PackedScene).instantiate()
	var guards := _level.get_node("Guards")
	_level.remove_child(guards)
	guards.free()
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, _level, Vector3(2, 0, -3)), "Navigation never became ready.")
	_player = _level.get_node("Player")
	_director = _level.get_node("StealthDirector")
	_hud = _level.get_node("StealthHud")
	await _check_crouch()
	await _check_carrel_hides_crouched_player()
	await _check_hidden_status_and_giving_up()
	await _check_crouch_walking_is_quiet()
	await _check_hud_indicators()
	await _check_escape_by_sprinting()
	await _check_caught_and_reset()
	_release_inputs()
	_level.queue_free()
	await _frames(2)
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[loop] " + message)


# --- Pure logic ------------------------------------------------------------------

func _check_status_priority() -> void:
	_expect(StealthDirector.status_from({}) == S.NONE, "No facts → NONE.")
	_expect(StealthDirector.status_from({"hidden": true}) == S.HIDDEN, "Hidden only → HIDDEN.")
	_expect(StealthDirector.status_from({"hidden": true, "investigating": true}) == S.INVESTIGATING,
		"An investigating guard outranks being hidden (the player should know someone is looking).")
	_expect(StealthDirector.status_from({"investigating": true, "seen": true}) == S.SPOTTED, "Being seen outranks investigating.")
	_expect(StealthDirector.status_from({"seen": true, "chase": true, "hidden": true}) == S.CHASE, "A chase outranks everything else.")


# --- Helpers to place a single controlled guard ------------------------------------

## Replaces the test guard with a fresh one standing at `at`, facing `yaw`, waiting there.
func _spawn_guard(at: Vector3, yaw: float) -> void:
	if _guard:
		_guard.free()
	if _route:
		_route.free()
	_route = PatrolRoute.new()
	var post := PatrolPoint.new()
	post.position = at
	post.wait_time = 300.0
	_route.add_child(post)
	_level.add_child(_route)
	_guard = (load(GUARD_SCENE) as PackedScene).instantiate()
	_guard.name = "LoopTestGuard"
	_guard.patrol_route = _route
	_guard.position = at + Vector3(0, 0.05, 0)
	_guard.rotation.y = yaw
	_level.add_child(_guard)
	await _until(func(): return _guard.machine.current == GuardStateMachine.PATROL, 120)
	await _frames(5)


func _place_player(at: Vector3, yaw := 0.0, crouch := false) -> void:
	_release_inputs()
	if crouch:
		Input.action_press("crouch")
	_player.global_position = at
	_player.rotation = Vector3(0, yaw, 0)
	_player.velocity = Vector3.ZERO
	await _frames(3)


# --- Crouching -----------------------------------------------------------------------

func _check_crouch() -> void:
	await _place_player(Vector3(-9, 0.05, 6))
	_expect(not _player.is_crouching and is_equal_approx(_player.get_body_height(), 1.8), "The player should start standing.")
	Input.action_press("crouch")
	await _frames(20)
	_expect(_player.is_crouching and is_equal_approx(_player.get_body_height(), 1.0), "Holding crouch should lower the body to 1 m.")
	_expect(absf(_player.head.position.y - _player.crouch_eye_height) < 0.01, "The camera should settle at crouched eye height.")
	_expect(is_equal_approx(_player.get_visibility_factor(), _player.crouch_visibility), "Crouching should make the player harder to notice.")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(40)
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	_expect(absf(speed - _player.crouch_speed) < 0.1, "Crouched movement should be %.1f m/s even with sprint held (was %.2f)." % [_player.crouch_speed, speed])
	_release_inputs()
	await _frames(20)
	_expect(not _player.is_crouching, "Releasing crouch should stand the player up.")
	# Cannot stand up under something low.
	var beam := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(2, 0.2, 2)
	beam.add_child(shape)
	_level.add_child(beam)
	Input.action_press("crouch")
	await _frames(5)
	beam.global_position = _player.global_position + Vector3(0, 1.3, 0)
	await _frames(2)
	Input.action_release("crouch")
	await _frames(10)
	_expect(_player.is_crouching, "The player must stay crouched under a 1.3 m beam.")
	beam.queue_free()
	await _frames(10)
	_expect(not _player.is_crouching, "Once the beam is gone the player should stand up.")


# --- Hiding --------------------------------------------------------------------------

func _check_carrel_hides_crouched_player() -> void:
	# Guard 5.6 m north of the carrel, facing south at its side panel.
	await _spawn_guard(Vector3(-12.6, 0, 6.0), PI)
	await _place_player(CARREL_WEST, 0.0, false)
	var seen_standing := await _seen_within(60)
	_expect(seen_standing, "Standing inside a 1.4 m carrel, the player's head should be visible over the panel.")
	_guard.vision.reset()
	await _place_player(CARREL_WEST, 0.0, true)
	await _frames(30)
	_guard.vision.reset()
	var seen_crouched := await _seen_within(180)
	_expect(not seen_crouched, "Crouched inside the carrel, the side panel should hide the player.")
	# From the open side the crouched player can be seen, but the meter fills at half speed.
	await _spawn_guard(Vector3(-8.0, 0, 11.6), PI / 2.0)  # facing west into the opening
	_guard.vision.reset()
	await _frames(1)
	var seen_open := false
	var frames_seen := 0
	for i in 30:  # half a second
		await _host.get_tree().physics_frame
		if _guard.vision.can_see_target:
			seen_open = true
			frames_seen += 1
	var gained := _guard.vision.detection
	var distance := _guard.vision.global_position.distance_to(_player.get_visibility_points()[0])
	var standing_gain := _guard.vision.rise_rate_at(distance) * frames_seen / Engine.physics_ticks_per_second
	_expect(seen_open and frames_seen > 25, "From the carrel's open side, a crouched player should be visible (seen %d/30 frames)." % frames_seen)
	_expect(gained > standing_gain * 0.35 and gained < standing_gain * 0.65,
		"Crouched, the meter should fill at about half speed (gained %.1f; standing would be %.1f)." % [gained, standing_gain])
	print("  [loop] carrel: standing seen over panel=%s, crouched hidden behind side=%s, from opening seen=%s at half rate (%.1f vs %.1f)" % [
		seen_standing, not seen_crouched, seen_open, gained, standing_gain])
	_release_inputs()


func _check_hidden_status_and_giving_up() -> void:
	await _spawn_guard(Vector3(2, 0, -3), PI)  # facing south
	var statuses: Array[int] = []
	_director.status_changed.connect(func(_a, b): statuses.append(b))
	await _place_player(Vector3(2, 0.05, 4))
	await _until(func(): return _guard.machine.current == GuardStateMachine.INVESTIGATE, 240)
	_expect(_guard.machine.current == GuardStateMachine.INVESTIGATE, "Being seen should make the guard investigate.")
	_expect(S.SPOTTED in statuses, "The HUD status should have shown SPOTTED while seen.")
	# Slip away and hide crouched in the west carrel, out of sight.
	await _place_player(CARREL_WEST, 0.0, true)
	await _frames(10)
	_expect(_director.status == S.INVESTIGATING, "While the guard investigates, the status should be INVESTIGATING (was %s)." % S.keys()[_director.status])
	var timeout := int((_guard.investigate_search_duration + 15.0) * Engine.physics_ticks_per_second)
	await _until(func(): return _guard.machine.current == GuardStateMachine.PATROL, timeout)
	_expect(_guard.machine.current == GuardStateMachine.PATROL, "After an unsuccessful search the guard should return to PATROL.")
	await _frames(5)
	_expect(_director.status == S.HIDDEN, "Crouched in a carrel with nobody looking, the status should be HIDDEN (was %s)." % S.keys()[_director.status])
	_expect(_director.catches == 0, "The hidden player must not have been caught.")
	print("  [loop] spotted → guard investigated → player hid in carrel → guard returned to patrol; statuses %s" % [statuses.map(func(s): return S.keys()[s])])
	_release_inputs()


func _check_crouch_walking_is_quiet() -> void:
	await _spawn_guard(Vector3(2, 0, -3), 0.0)  # facing north: the player is behind it
	var hearing := _guard.hearing
	# Crouch-walk 3 m behind the guard: under the 2 m crouch noise radius → not heard.
	await _place_player(Vector3(-1, 0.05, 0), -PI / 2.0, true)  # facing +X
	Input.action_press("move_forward")
	await _frames(90)
	_release_inputs()
	await _frames(10)
	var heard_crouched := hearing.reported_count
	_expect(heard_crouched == 0 and _guard.machine.current == GuardStateMachine.PATROL, "Crouch-walking 3 m behind a guard should not be heard.")
	# Walking normally along the same line is heard (5 m radius).
	await _place_player(Vector3(-1, 0.05, 0), -PI / 2.0, false)
	Input.action_press("move_forward")
	await _frames(60)
	_release_inputs()
	await _frames(5)
	_expect(hearing.reported_count > heard_crouched, "Walking normally 3 m behind the guard should be heard.")
	_expect(_guard.machine.current == GuardStateMachine.INVESTIGATE, "Hearing the footsteps should make the guard investigate.")


func _check_hud_indicators() -> void:
	await _spawn_guard(Vector3(2, 0, -3), PI)  # facing south
	await _place_player(Vector3(2, 0.05, 4))
	# Face the guard exactly.
	_player.look_at(Vector3(_guard.global_position.x, _player.global_position.y, _guard.global_position.z), Vector3.UP)
	await _until(func(): return _guard.vision.detection > 10.0, 120)
	var ind := _hud.get_indicators()
	_expect(ind.size() == 1 and absf(ind[0].angle) < 10.0, "A guard straight ahead should be indicated near 0° (got %s)." % [ind.map(func(e): return snappedf(e.angle, 0.1))])
	_player.rotate_y(-PI / 2.0)  # turn right 90°: the guard is now on the left
	await _frames(2)
	ind = _hud.get_indicators()
	_expect(ind.size() == 1 and absf(ind[0].angle + 90.0) < 10.0, "After turning right, the guard should be indicated at about -90° (left), got %s." % [ind.map(func(e): return snappedf(e.angle, 0.1))])
	_expect(ind.size() == 1 and ind[0].fill > 0.0, "The indicator should fill with the guard's meter.")
	await _until(func(): return _guard.machine.current == GuardStateMachine.INVESTIGATE, 240)
	ind = _hud.get_indicators()
	_expect(ind.size() == 1 and ind[0].icon == "?" and ind[0].colour == StealthHud.COLOUR_SUSPICIOUS, "An investigating guard should show a yellow '?'.")
	await _place_player(SPAWN)
	_expect(_hud.get_stance_text().begins_with("STANDING"), "Stance text should say STANDING.")
	Input.action_press("crouch")
	await _frames(5)
	_expect(_hud.get_stance_text() == "CROUCHED · noise: SILENT", "Stance text should say 'CROUCHED · noise: SILENT', got '%s'." % _hud.get_stance_text())
	_release_inputs()
	await _frames(70)


func _check_escape_by_sprinting() -> void:
	# Guard at the north end of the east hallway facing south (-Z); the player
	# stands 8 m south of it, also facing south, with ~20 m of hallway and exit area ahead.
	await _spawn_guard(Vector3(22.5, 0, 0), 0.0)
	await _place_player(Vector3(22.5, 0.05, -8), 0.0)
	await _until(func(): return _guard.machine.current == GuardStateMachine.CHASE, 400)
	_expect(_guard.machine.current == GuardStateMachine.CHASE, "Standing in front of the guard should end in CHASE.")
	var gap_start := _gap()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(120)
	var gap_end := _gap()
	_release_inputs()
	_expect(_director.catches == 0, "A sprinting player should not be caught by a chasing guard on open ground.")
	_expect(gap_end > gap_start + 1.5, "Sprinting (5.5 m/s) should outpace the guard (4.2 m/s): gap %.1f m → %.1f m." % [gap_start, gap_end])
	print("  [loop] escape: chase started %.1f m behind, gap after 2 s of sprinting %.1f m, not caught" % [gap_start, gap_end])


func _check_caught_and_reset() -> void:
	await _spawn_guard(Vector3(2, 0, -3), PI)
	var guard_start := _guard.global_position
	var caught_by: Array = []
	_director.player_caught.connect(func(g): caught_by.append(g), CONNECT_ONE_SHOT)
	await _place_player(Vector3(2, 0.05, 2))  # stands still in front of the guard
	await _until(func(): return _director.status == S.CAUGHT, 600)
	_expect(_director.status == S.CAUGHT and caught_by.size() == 1, "A guard reaching a standing player should catch them.")
	_expect(_hud._caught.visible, "The CAUGHT overlay should show.")
	var frozen_at := _player.global_position
	await _frames(30)
	_expect(_player.global_position.distance_to(frozen_at) < 0.01, "The player should be frozen while caught.")
	await _until(func(): return _director.status != S.CAUGHT, int(_director.reset_delay * Engine.physics_ticks_per_second) + 30)
	await _frames(3)
	_expect(_player.global_position.distance_to(_player._spawn_transform.origin) < 0.3, "After the reset the player should be back at the entrance.")
	_expect(_guard.machine.current == GuardStateMachine.PATROL and _guard.vision.detection == 0.0 and not _guard.vision.has_last_known_position,
		"After the reset the guard should be patrolling with a clear memory.")
	_expect(Vector2(_guard.global_position.x - guard_start.x, _guard.global_position.z - guard_start.z).length() < 0.5, "After the reset the guard should be back at its start.")
	_expect(not _hud._caught.visible and _director.catches >= 1, "The overlay should hide again after the reset.")
	print("  [loop] caught by %s, frozen for %.1fs, reset: player at entrance, guard patrolling from its start" % [
		caught_by[0].name if caught_by.size() > 0 else "-", _director.reset_delay])


# --- Helpers ---------------------------------------------------------------------------

func _gap() -> float:
	return Vector2(_guard.global_position.x - _player.global_position.x, _guard.global_position.z - _player.global_position.z).length()


func _seen_within(frames: int) -> bool:
	for i in frames:
		await _host.get_tree().physics_frame
		if _guard.vision.can_see_target:
			return true
	return false


func _until(done: Callable, max_frames: int) -> void:
	for i in max_frames:
		if done.call():
			return
		await _host.get_tree().physics_frame


func _release_inputs() -> void:
	for action in ["move_forward", "move_backward", "move_left", "move_right", "sprint", "crouch"]:
		Input.action_release(action)


func _frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
