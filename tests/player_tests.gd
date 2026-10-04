extends RefCounted

## Phase 2 first-person player tests. Called from tests/test_scene.gd.
## Logic checks call the player's functions directly; movement checks load
## the real library level, hold InputMap actions and step real physics frames.

const LIBRARY_SCENE := "res://scenes/level/library_graybox.tscn"
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const SPEED_TOLERANCE := 0.1
const TEST_AREA := "NavigationRegion3D/PlayerTestArea"
const PLAYER_RADIUS := 0.35

var failures: Array[String] = []
var _host: Node


func run(host: Node) -> Array[String]:
	_host = host
	_check_input_map()
	_check_player_scene()
	_check_movement_math()
	await _check_movement_in_level()
	_release_all_actions()
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[player] " + message)


func _check_input_map() -> void:
	var expected := {
		"move_forward": KEY_W, "move_backward": KEY_S,
		"move_left": KEY_A, "move_right": KEY_D,
		"sprint": KEY_SHIFT, "release_mouse": KEY_ESCAPE,
	}
	for action in expected:
		_expect(InputMap.has_action(action), "InputMap is missing '%s'." % action)
		if not InputMap.has_action(action):
			continue
		var bound := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and event.physical_keycode == expected[action]:
				bound = true
		_expect(bound, "'%s' is not bound to %s." % [action, OS.get_keycode_string(expected[action])])
	_expect(not InputMap.has_action("jump"), "A jump action exists, but jumping is out of scope for this level.")


func _check_player_scene() -> void:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate()
	_expect(player is CharacterBody3D, "Player root must be a CharacterBody3D.")
	_expect(player.get_node_or_null("CollisionShape3D") is CollisionShape3D, "Player needs a collision shape.")
	var camera := player.get_node_or_null("Head/Camera3D") as Camera3D
	_expect(camera != null and camera.current, "Player needs a current first-person camera at Head/Camera3D.")
	_expect(player.sprint_speed > player.walk_speed, "Sprint speed must be higher than walk speed.")
	player.free()


func _check_movement_math() -> void:
	var player: FirstPersonPlayer = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.walk_speed = 3.5
	player.acceleration = 20.0
	player.deceleration = 25.0
	# Inside the tree so global_basis and the @onready Head reference are valid.
	_host.add_child(player)

	var accelerated := player.calculate_horizontal_velocity(Vector3.ZERO, Vector3(3.5, 0, 0), 0.1)
	_expect(is_equal_approx(accelerated.x, 2.0), "Acceleration step should be 20 m/s² × 0.1 s = 2.0, got %.3f." % accelerated.x)
	var capped := player.calculate_horizontal_velocity(Vector3(3.0, 0, 0), Vector3(3.5, 0, 0), 0.1)
	_expect(is_equal_approx(capped.x, 3.5), "Acceleration must not overshoot the target speed.")
	var decelerated := player.calculate_horizontal_velocity(Vector3(3.5, 0, 0), Vector3.ZERO, 0.1)
	_expect(is_equal_approx(decelerated.x, 1.0), "Deceleration step should leave 1.0 m/s, got %.3f." % decelerated.x)

	# The player has no rotation yet, so forward is -Z.
	var forward := player.get_target_velocity(Vector2(0, -1), false)
	_expect(forward.is_equal_approx(Vector3(0, 0, -3.5)), "W should move toward -Z at walk speed, got %s." % forward)
	var sprint := player.get_target_velocity(Vector2(0, -1), true)
	_expect(is_equal_approx(sprint.length(), player.sprint_speed), "Sprinting should use sprint speed.")
	var diagonal := player.get_target_velocity(Vector2(1, -1), false)
	_expect(diagonal.length() <= player.walk_speed + 0.001, "Diagonal movement must not be faster than walking.")

	# Mouse look.
	player.apply_look(Vector2(0, -10.0))
	_expect(is_equal_approx(player.head.rotation.x, deg_to_rad(player.max_pitch_degrees)),
		"Looking up must clamp at max_pitch_degrees.")
	player.apply_look(Vector2(0, 20.0))
	_expect(is_equal_approx(player.head.rotation.x, -deg_to_rad(player.max_pitch_degrees)),
		"Looking down must clamp at -max_pitch_degrees.")
	var yaw_before := player.rotation.y
	player.apply_look(Vector2(0.5, 0))
	_expect(is_equal_approx(player.rotation.y, yaw_before - 0.5), "Horizontal mouse movement must turn the body.")
	_host.remove_child(player)
	player.free()


func _check_movement_in_level() -> void:
	var level: Node3D = (load(LIBRARY_SCENE) as PackedScene).instantiate()
	# Guards walk around on their own; remove them so they cannot bump the player.
	for moving in ["Guards", "NavigationProbe"]:
		var node := level.get_node_or_null(moving)
		if node:
			level.remove_child(node)
			node.free()
	_host.add_child(level)
	var player := level.get_node_or_null("Player") as FirstPersonPlayer
	var test_area := level.get_node_or_null(TEST_AREA)
	_expect(player != null, "The library must contain the Player.")
	_expect(test_area != null, "The library must contain the PlayerTestArea.")
	if player == null or test_area == null:
		level.queue_free()
		return
	_expect(player.camera.is_current(), "The player camera must be the active camera in the level.")
	var spawn := player.global_position

	# Gravity and floor collision.
	await _physics_frames(30)
	_expect(player.is_on_floor(), "Player should land on the floor after spawning.")
	_expect(absf(player.global_position.y) < 0.05, "Player should rest on the floor (y≈0), got y=%.3f." % player.global_position.y)

	# Walking forward along the sprint lane (spawn faces -Z).
	Input.action_press("move_forward")
	await _physics_frames(45)
	var walk_speed := _horizontal_speed(player)
	_expect(absf(walk_speed - player.walk_speed) < SPEED_TOLERANCE,
		"Walking speed should be %.2f m/s, got %.2f." % [player.walk_speed, walk_speed])
	_expect(player.global_position.z < spawn.z - 2.0, "Holding W should move the player forward (-Z).")

	# Sprinting.
	Input.action_press("sprint")
	await _physics_frames(30)
	var sprint_speed := _horizontal_speed(player)
	_expect(absf(sprint_speed - player.sprint_speed) < SPEED_TOLERANCE,
		"Sprint speed should be %.2f m/s, got %.2f." % [player.sprint_speed, sprint_speed])

	# Deceleration after releasing input.
	_release_all_actions()
	await _physics_frames(20)
	_expect(_horizontal_speed(player) < 0.05, "Player should stop within 20 frames of releasing input.")

	# Collision: walk into the crate, then sprint into a wall. Each probe marker faces its
	# obstacle and stores the distance to it, so the player should stop one radius short.
	var crate_travel := await _walk_from_probe(player, test_area.get_node("CrateProbe"), false, 60)
	var wall_travel := await _walk_from_probe(player, test_area.get_node("WallProbe"), true, 90)
	print("  [player] measured: walk %.2f m/s, sprint %.2f m/s, travel to crate %.3f m, to wall %.3f m" % [
		walk_speed, sprint_speed, crate_travel, wall_travel])

	# Fall safety: dropping below the level returns the player to the spawn point.
	_teleport(player, spawn + Vector3(0, -30, 0), 0.0)
	await _physics_frames(2)
	_expect(player.global_position.distance_to(spawn) < 0.1, "Falling out of the level should respawn the player.")

	level.queue_free()
	await _physics_frames(1)


## Places the player on a probe marker, holds W (and Shift) and returns the distance travelled.
func _walk_from_probe(player: FirstPersonPlayer, probe: Marker3D, sprint: bool, frames: int) -> float:
	var start := probe.global_position
	_teleport(player, start, probe.global_rotation.y)
	Input.action_press("move_forward")
	if sprint:
		Input.action_press("sprint")
	await _physics_frames(frames)
	_release_all_actions()
	var travel := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	var expected: float = probe.get_meta("distance_to_obstacle") - PLAYER_RADIUS
	_expect(travel < expected + 0.05,
		"%s: player passed into the obstacle (travelled %.3f m, obstacle surface at %.3f m)." % [probe.name, travel, expected])
	_expect(travel > expected - 0.1, "%s: player should reach the obstacle (travelled %.3f m of %.3f m)." % [probe.name, travel, expected])
	_expect(player.global_position.y > -0.1, "%s: player should stay on the floor." % probe.name)
	return travel


func _teleport(player: FirstPersonPlayer, position: Vector3, yaw: float) -> void:
	player.global_position = position
	player.rotation = Vector3(0, yaw, 0)
	player.velocity = Vector3.ZERO


func _horizontal_speed(player: CharacterBody3D) -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


func _physics_frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame


func _release_all_actions() -> void:
	for action in ["move_forward", "move_backward", "move_left", "move_right", "sprint"]:
		Input.action_release(action)
