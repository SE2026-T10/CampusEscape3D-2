extends RefCounted

## Phase 14 QA playthroughs: the whole game played through the real level the
## way a player does it, instead of system by system. Called from tests/test_scene.gd.
##
## A. The full route, walked with real input (W held, the body turned toward
##    the next corner of a navigation path; walking, sprinting and crouching
##    segments), with the guards removed: every objective trigger, both
##    checkpoints, the interaction key on the card and the exit door, victory,
##    and the sounds that go with them.
## B. A real chase and catch with the level's guards: a guard sees the player,
##    gives chase (run animation, alarm, chase music), catches them, the caught
##    screen shows, and the player respawns at the checkpoint they touched with
##    every guard back on patrol and the music off.

const LIBRARY_SCENE := "res://scenes/level/library_graybox.tscn"
const TestUtils := preload("res://tests/test_utils.gd")
const S := StealthDirector.Status
const G := GameStateMachine.State
const AT_CARD := Vector3(-14.2, 0.05, -24.9)
const AT_DOOR := Vector3(26.4, 0.05, -23)

var failures: Array[String] = []
var _host: Node
var _level: Node3D
var _player: FirstPersonPlayer
var _map: RID


func run(host: Node) -> Array[String]:
	_host = host
	await _check_full_route()
	await _check_real_chase_and_catch()
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[qa] " + message)


# --- A. Full route ---------------------------------------------------------------

func _check_full_route() -> void:
	await _load(false)
	var objectives := ObjectiveManager.find(_level)
	var checkpoints := CheckpointManager.find(_level)
	var flow := GameFlow.find(_level)
	var audio := AudioDirector.find(_level)
	var feedback := _player.get_node("Feedback") as PlayerFeedback
	var activated: Array[String] = []
	checkpoints.checkpoint_activated.connect(func(cp: Checkpoint): activated.append(cp.checkpoint_name))
	audio.played.clear()
	var steps_before := feedback.steps_played
	var start_frames := Engine.get_physics_frames()

	var legs := [
		["the main room", Vector3(0, 0, 12.5), ""],
		["Hallway West checkpoint", Vector3(-10.5, 0, -9.5), "sprint"],
		["the Restricted Stacks", Vector3(-9, 0, -20), "crouch"],
		["the card desk", AT_CARD, ""],
	]
	for leg in legs:
		_expect(await _walk_to(leg[1], leg[2]), "Walking to %s got stuck at %s." % [leg[0], _player.global_position])
	_expect(objectives.is_completed(ObjectiveManager.ENTER_LIBRARY), "Walking into the main room should complete 'Enter the library'.")
	_expect(activated.has("Hallway West"), "Walking onto the Hallway West pad should activate its checkpoint (got %s)." % [activated])
	_expect(objectives.is_completed(ObjectiveManager.REACH_RESTRICTED), "Crouch-walking into the stacks should complete 'Reach the Restricted Stacks'.")

	# Take the card with the interaction key.
	var card := _level.get_node("Gameplay/AccessCard") as Node3D
	await _look_at(card.global_position)
	_expect(_interactor().focused == card, "Looking at the card from the desk should focus it.")
	await _press_action("interact")
	_expect(objectives.is_completed(ObjectiveManager.TAKE_CARD), "Pressing E on the card should take it.")

	for leg in [["the Staff Nook checkpoint", Vector3(8, 0, -25.8), "sprint"], ["the exit door", AT_DOOR, ""]]:
		_expect(await _walk_to(leg[1], leg[2]), "Walking to %s got stuck at %s." % [leg[0], _player.global_position])
	_expect(activated.has("Staff Nook"), "Walking onto the Staff Nook pad should activate its checkpoint (got %s)." % [activated])
	_expect(objectives.is_completed(ObjectiveManager.REACH_EXIT), "Walking into the exit area with the card should complete 'Reach the exit'.")

	var door := _level.get_node("Gameplay/ExitDoor") as Node3D
	await _look_at(door.global_position)
	_expect(_interactor().focused == door, "Looking at the exit door should focus it.")
	await _press_action("interact")
	await _frames(5)
	_expect(objectives.is_finished() and flow.state == G.WIN, "Pressing E on the unlocked door should win the game.")
	var menus := _level.get_node("GameMenus") as GameMenus
	_expect(menus.win_panel.visible and menus.get_objectives_text() == "Objectives 5/5 complete",
		"The win screen should show 5/5 objectives (got '%s')." % menus.get_objectives_text())
	for sound in ["objective_complete", "checkpoint", "card_pickup", "door_open", "victory"]:
		_expect(audio.played.has(sound), "The playthrough should have played '%s' (played %s)." % [sound, audio.played])
	_expect(feedback.steps_played - steps_before > 50, "Walking the route should play footsteps (%d)." % (feedback.steps_played - steps_before))
	var seconds := (Engine.get_physics_frames() - start_frames) / 60.0
	print("  [qa] full route walked with real input in %.1f s of play: checkpoints %s, %d footsteps, sounds %s" % [
		seconds, activated, feedback.steps_played - steps_before, _unique(audio.played)])
	await _unload()


# --- B. Real chase and catch ------------------------------------------------------

func _check_real_chase_and_catch() -> void:
	await _load(true)
	var director := StealthDirector.find(_level)
	var audio := AudioDirector.find(_level)
	var hud := _level.get_node("StealthHud") as StealthHud
	var flow := GameFlow.find(_level)
	var guard := _level.get_node("Guards/GuardMain") as Guard
	var show := guard.get_node("Presentation") as GuardPresentation
	# Touch the Hallway West checkpoint first (by walking onto it, guards unaware).
	_teleport(Vector3(-10.5, 0.05, -8.5), 0.0)
	_expect(await _walk_to(Vector3(-10.5, 0, -9.5), ""), "Could not reach the Hallway West pad.")
	await _frames(5)
	_expect(CheckpointManager.find(_level).get_respawn_name() == "Hallway West", "The Hallway West checkpoint should be the respawn point.")
	audio.played.clear()

	# Stand in plain sight in front of the guard.
	var seen := {}
	var music := {}
	var caught_overlay := false
	var flow_states := {}
	for i in 1200:
		if director.status == S.CAUGHT:
			break
		if guard.machine.current != GuardStateMachine.CHASE:
			_teleport(guard.global_position - guard.global_basis.z * 5.0, 0.0)
		_face(guard.global_position + Vector3(0, 1.4, 0))
		await _host.get_tree().physics_frame
		seen[show.current_animation] = true
		music[audio.music_layer] = true
		flow_states[GameStateMachine.name_of(flow.state)] = true
	_expect(director.status == S.CAUGHT, "Standing in front of a guard should get the player caught (status %s)." % S.keys()[director.status])
	await _frames(2)
	caught_overlay = hud._caught.visible
	_expect(caught_overlay and flow.state == G.CAUGHT, "The caught screen should show.")
	_expect(seen.has("run"), "A chasing guard should play its run animation (saw %s)." % [seen.keys()])
	_expect(music.has("chase"), "The chase music should play during a chase (layers %s)." % [music.keys()])
	for sound in ["notice", "alarm", "caught"]:
		_expect(audio.played.has(sound), "A real chase should play '%s' (played %s)." % [sound, audio.played])

	# Respawn.
	for i in 300:
		if director.status != S.CAUGHT:
			break
		await _host.get_tree().physics_frame
	await _frames(5)
	var spawn := (_level.get_node("Gameplay/CheckpointHallwayWest/Spawn") as Node3D).global_position
	_expect(flow.state == G.PLAYING and not hud._caught.visible, "Play should resume after the caught screen.")
	_expect(Vector2(_player.global_position.x - spawn.x, _player.global_position.z - spawn.z).length() < 0.5,
		"The player should respawn at the Hallway West checkpoint (at %s)." % _player.global_position)
	for g in _level.find_children("*", "Guard", true, false):
		_expect(g.machine.current == GuardStateMachine.PATROL, "%s should be back on patrol after the respawn." % g.name)
	await _frames(90)
	_expect(audio.music_layer == "", "The music should stop after the respawn (layer '%s')." % audio.music_layer)
	print("  [qa] real chase: guard animations %s, music %s, sounds %s, respawned at Hallway West" % [
		seen.keys(), music.keys(), _unique(audio.played)])
	await _unload()


# --- Helpers ----------------------------------------------------------------------

func _load(keep_guards: bool) -> void:
	_level = (load(LIBRARY_SCENE) as PackedScene).instantiate()
	if not keep_guards:
		for g in _level.get_node("Guards").get_children():
			if g is Guard:
				_level.get_node("Guards").remove_child(g)
				g.free()
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, _level, Vector3(0, 0, 18)), "Library navigation never became ready.")
	_player = _level.get_node("Player")
	_map = _level.get_world_3d().navigation_map
	GameFlow.find(_level).change_scene = func(_path: String): pass
	await _frames(3)


func _unload() -> void:
	_release_all()
	_host.get_tree().paused = false
	_level.queue_free()
	await _frames(30)


## Walks to `target` with real input: W held, the body turned toward the next
## corner of a navigation path. `mode` is "", "sprint" or "crouch".
## Returns false if the player moves less than 0.3 m in 1.5 seconds (stuck).
func _walk_to(target: Vector3, mode: String) -> bool:
	var path := NavigationServer3D.map_get_path(_map, _player.global_position, target, true)
	if path.is_empty():
		return false
	var index := 0
	var anchor := _player.global_position
	var anchor_frame := 0
	if mode != "":
		Input.action_press(mode)
	Input.action_press("move_forward")
	var arrived := false
	for frame in 60 * 90:
		var here := _player.global_position
		while index < path.size() - 1 and Vector2(path[index].x - here.x, path[index].z - here.z).length() < 0.45:
			index += 1
		var to := path[index] - here
		var remaining := Vector2(target.x - here.x, target.z - here.z).length()
		if remaining < 0.4:
			arrived = true
			break
		_player.rotation.y = atan2(-to.x, -to.z)
		if frame - anchor_frame >= 90:
			if here.distance_to(anchor) < 0.3:
				break
			anchor = here
			anchor_frame = frame
		await _host.get_tree().physics_frame
	_release_all()
	await _frames(12)
	return arrived


func _look_at(target: Vector3) -> void:
	_face(target)
	await _frames(3)


func _face(target: Vector3) -> void:
	var flat := target - _player.global_position
	_player.rotation.y = atan2(-flat.x, -flat.z)
	var eye := _player.camera.global_position
	_player.head.rotation.x = atan2(target.y - eye.y, Vector2(target.x - eye.x, target.z - eye.z).length())


func _teleport(at: Vector3, yaw: float) -> void:
	_player.global_position = at
	_player.rotation.y = yaw
	_player.velocity = Vector3.ZERO


func _press_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_host.get_viewport().push_input(event)
	await _frames(1)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	_host.get_viewport().push_input(release)
	await _frames(2)


func _interactor() -> PlayerInteractor:
	return _player.get_node("Interactor") as PlayerInteractor


func _release_all() -> void:
	for a in ["move_forward", "move_backward", "move_left", "move_right", "sprint", "crouch"]:
		Input.action_release(a)


func _unique(list: Array) -> Array:
	var out := []
	for x in list:
		if not out.has(x):
			out.append(x)
	return out


func _frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
