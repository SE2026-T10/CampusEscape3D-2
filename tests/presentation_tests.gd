extends RefCounted

## Phase 12 presentation tests. Called from tests/test_scene.gd.
##   - audio assets: every sound loads, loops are loops and one-shots are not,
##     and the audio buses exist
##   - pure presentation rules: movement kind, head bob, guard animation choice,
##     interaction prompt split, the guard animation library
##   - in the real library: the player's strides play footsteps and bob the
##     camera, which settles when standing still; guards animate per AI state
##     and play footsteps; the AudioDirector reacts to stealth, objective,
##     pause and door events; UI sounds work while paused; the detection meter
##     follows the guards
##   - presentation never changes gameplay: the guard model has no collision,
##     the guard's collision capsule and speeds are unchanged

const LIBRARY_SCENE := "res://scenes/level/library_graybox.tscn"
const GUARD_SCENE := "res://scenes/npc/guard.tscn"
const TestUtils := preload("res://tests/test_utils.gd")
const S := StealthDirector.Status

var failures: Array[String] = []
var _host: Node
var _level: Node3D
var _audio: AudioDirector
var _player: FirstPersonPlayer


func run(host: Node) -> Array[String]:
	_host = host
	_check_assets_and_buses()
	_check_pure_rules()
	_check_guard_scene()
	_level = (load(LIBRARY_SCENE) as PackedScene).instantiate()
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, _level, Vector3(0, 0, 18)), "Library navigation never became ready.")
	await _frames(3)
	_audio = AudioDirector.find(_level)
	_player = _level.get_node("Player")
	_expect(_audio != null, "The library needs an AudioDirector.")
	if _audio:
		_check_ambience()
		await _check_player_feedback()
		await _check_guard_presentation()
		await _check_stealth_audio()
		await _check_objective_and_ui_audio()
		_check_detection_meter()
		await _check_door_audio()
	Input.action_release("move_forward")
	_host.get_tree().paused = false
	_level.queue_free()
	# Stopped sounds are released by the audio server a few frames later.
	await _frames(30)
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[presentation] " + message)


func _check_assets_and_buses() -> void:
	var files := SoundBank.all_files()
	_expect(files.size() == 32, "Expected 32 sound files, found %d." % files.size())
	for path in files:
		var stream := load(path) as AudioStreamWAV
		_expect(stream != null and stream.get_length() > 0.02, "%s should load as a sound." % path)
		if stream == null:
			continue
		var looped := path.get_file().get_basename() in SoundBank.LOOPED
		_expect((stream.loop_mode != AudioStreamWAV.LOOP_DISABLED) == looped,
			"%s should %sloop." % [path, "" if looped else "not "])
	for bus in ["Music", "SFX", "Ambience", "UI"]:
		var index := AudioServer.get_bus_index(bus)
		_expect(index > 0 and AudioServer.get_bus_send(index) == &"Master", "The '%s' bus should exist and send to Master." % bus)
	_expect(SoundBank.pick("player_step") != null and SoundBank.pick("music_chase") != null, "SoundBank should pick known sounds.")


func _check_pure_rules() -> void:
	_expect(PlayerFeedback.movement_kind(0.2, false, true) == &"idle", "Standing still is idle.")
	_expect(PlayerFeedback.movement_kind(3.5, false, false) == &"idle", "In the air is idle.")
	_expect(PlayerFeedback.movement_kind(1.8, true, true) == &"crouch", "Crouch-walking is crouch.")
	_expect(PlayerFeedback.movement_kind(3.5, false, true) == &"walk", "Walking is walk.")
	_expect(PlayerFeedback.movement_kind(5.5, false, true) == &"run", "Sprinting is run.")
	var biggest := 0.0
	for i in 64:
		var phase := TAU * i / 64.0
		_expect(PlayerFeedback.bob_offset(phase, PlayerFeedback.BOB[&"run"], 0.0) == Vector3.ZERO, "No bob when the amount is zero.")
		biggest = maxf(biggest, PlayerFeedback.bob_offset(phase, PlayerFeedback.BOB[&"run"], 1.0).length())
	_expect(biggest > 0.01 and biggest < 0.05, "The head bob should be gentle (largest offset %.3f m)." % biggest)
	_expect(GuardPresentation.choose_animation(GuardStateMachine.PATROL, 0.0) == "idle", "A waiting patrol guard idles.")
	_expect(GuardPresentation.choose_animation(GuardStateMachine.PATROL, 2.0) == "walk", "A patrolling guard walks.")
	_expect(GuardPresentation.choose_animation(GuardStateMachine.INVESTIGATE, 2.6) == "walk", "An investigating guard walks to the noise.")
	_expect(GuardPresentation.choose_animation(GuardStateMachine.INVESTIGATE, 0.0) == "search", "An investigating guard at the noise searches.")
	_expect(GuardPresentation.choose_animation(GuardStateMachine.CHASE, 4.2) == "run", "A chasing guard runs.")
	_expect(GuardPresentation.choose_animation(GuardStateMachine.NONE, 0.0) == "idle", "A guard that hasn't started idles.")
	_expect(ObjectiveHud.split_prompt("[E] Take the access card") == PackedStringArray(["E", "Take the access card"]), "Prompt key and action should split.")
	_expect(ObjectiveHud.split_prompt("Hello") == PackedStringArray(["", "Hello"]), "A prompt without a key keeps its text.")


func _check_guard_scene() -> void:
	var guard := (load(GUARD_SCENE) as PackedScene).instantiate() as Guard
	var model := guard.get_node_or_null("Model")
	_expect(model != null and guard.get_node_or_null("Presentation") is GuardPresentation, "The guard needs its Model and Presentation.")
	_expect(guard.get_node_or_null("Body") == null, "The old capsule body should be replaced by the model.")
	if model:
		_expect(model.find_children("*", "CollisionObject3D", true, false).is_empty(), "The guard model must not collide.")
		_expect(model.find_children("*", "MeshInstance3D", true, false).size() >= 15, "The model should be built from simple parts.")
	var capsule := (guard.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	_expect(is_equal_approx(capsule.radius, 0.35) and is_equal_approx(capsule.height, 1.8), "The guard's collision capsule must not change.")
	_expect(guard.patrol_speed == 2.0 and guard.investigate_speed == 2.6 and guard.chase_speed == 4.2, "Guard speeds must not change.")
	var lib := GuardPresentation.build_library()
	for anim_name in GuardPresentation.ANIMATIONS:
		var anim := lib.get_animation(anim_name)
		_expect(anim != null and anim.loop_mode == Animation.LOOP_LINEAR, "Animation '%s' should exist and loop." % anim_name)
		if anim == null:
			continue
		for t in anim.get_track_count():
			var path := anim.track_get_path(t)
			_expect(guard.get_node_or_null(NodePath(path.get_concatenated_names())) != null, "Animation '%s' animates a missing joint %s." % [anim_name, path])
	guard.free()


func _check_ambience() -> void:
	var emitters := _level.find_children("*", "AmbientEmitter", true, false)
	_expect(emitters.size() >= 4, "The library needs its ambient sounds (found %d)." % emitters.size())
	var clock := _level.get_node_or_null("Ambience/ClockTick") as AmbientEmitter
	_expect(clock != null and clock.playing and clock.bus == &"Ambience", "The clock should tick on the Ambience bus.")
	for e in emitters:
		_expect(e.find_children("*", "CollisionObject3D", true, false).is_empty(), "Ambient sounds must not collide.")


func _check_player_feedback() -> void:
	var feedback := _player.get_node_or_null("Feedback") as PlayerFeedback
	var noise := _player.get_node("Noise") as PlayerNoise
	_expect(feedback != null, "The player needs its Feedback node.")
	if feedback == null:
		return
	var steps_before := feedback.steps_played
	var noise_before := noise.steps_emitted
	var largest_bob := 0.0
	Input.action_press("move_forward")
	for i in 70:
		await _host.get_tree().physics_frame
		largest_bob = maxf(largest_bob, _player.camera.position.length())
	_expect(feedback.movement == &"walk", "Walking should count as walk, got %s." % feedback.movement)
	Input.action_release("move_forward")
	var steps := feedback.steps_played - steps_before
	_expect(steps > 0 and steps == noise.steps_emitted - noise_before, "Every stride should play one footstep (%d sounds, %d noises)." % [steps, noise.steps_emitted - noise_before])
	_expect(largest_bob > 0.005, "Walking should bob the camera (largest %.3f m)." % largest_bob)
	await _frames(60)
	_expect(feedback.movement == &"idle" and _player.camera.position.length() < 0.002, "Standing still should settle the camera (%.4f m)." % _player.camera.position.length())
	_expect(absf(_player.camera.fov - PlayerFeedback.BASE_FOV) < 0.1, "The FOV should be back to normal when not sprinting.")
	print("  [presentation] player: %d footsteps over %d strides, largest head bob %.3f m" % [steps, steps, largest_bob])


func _check_guard_presentation() -> void:
	var guard := _level.get_node("Guards/GuardMain") as Guard
	var show := guard.get_node("Presentation") as GuardPresentation
	var seen := {}
	for i in 240:
		await _host.get_tree().physics_frame
		seen[show.current_animation] = true
	_expect(seen.has("walk"), "A patrolling guard should play its walk animation (saw %s)." % [seen.keys()])
	_expect(show.footsteps_played > 0, "A walking guard should make footstep sounds.")
	# Investigation: walking to the spot, then searching there.
	var spot := NavigationServer3D.map_get_closest_point(guard.get_world_3d().navigation_map, guard.global_position + Vector3(2.5, 0, 0))
	_expect(guard.machine.request_transition(GuardStateMachine.INVESTIGATE, "presentation test", spot), "Investigation should start.")
	seen = {}
	for i in 300:
		await _host.get_tree().physics_frame
		if guard.machine.current != GuardStateMachine.INVESTIGATE:
			break
		seen[show.current_animation] = true
	_expect(seen.has("search"), "An investigating guard should search at the spot (saw %s)." % [seen.keys()])
	_expect(show.radio_played > 0, "Starting an investigation should play the radio call.")
	print("  [presentation] guard: animations seen while investigating %s, %d footsteps, %d radio, %d keys" % [
		seen.keys(), show.footsteps_played, show.radio_played, show.keys_played])


func _check_stealth_audio() -> void:
	var director := StealthDirector.find(_level)
	await _frames(2)
	_audio.played.clear()
	_audio._on_status_changed(S.NONE, S.INVESTIGATING)
	_expect(_audio.played == ["suspicious"] and _audio.music_layer == "tension", "An investigation should sting and start the tension music.")
	_audio._on_status_changed(S.INVESTIGATING, S.SPOTTED)
	_audio._on_status_changed(S.SPOTTED, S.CHASE)
	_expect(_audio.played == ["suspicious", "notice", "alarm"] and _audio.music_layer == "chase", "Being seen then chased should sting each time, got %s." % [_audio.played])
	_audio._on_status_changed(S.CHASE, S.SPOTTED)
	_audio._on_status_changed(S.SPOTTED, S.CHASE)
	_expect(_audio.played.count("alarm") == 1, "A flickering chase must not repeat the alarm within %.1f s." % AudioDirector.STING_COOLDOWN)
	_audio._on_status_changed(S.CHASE, S.NONE)
	_expect(_audio.played.back() == "lost_track" and _audio.music_layer == "", "Losing the guards should play lost track and stop the music.")
	_audio._on_status_changed(S.CHASE, S.CAUGHT)
	_expect(_audio.played.back() == "caught", "Being caught should play the caught sound.")
	_audio._on_status_changed(S.CAUGHT, S.NONE)
	# The director's real signal reaches the AudioDirector.
	_expect(_audio.music_layer == "", "No music after the reset.")
	director.status_changed.emit(S.NONE, S.SPOTTED)
	_expect(_audio.music_layer == "tension", "The AudioDirector should listen to the StealthDirector.")
	director.status_changed.emit(S.SPOTTED, S.NONE)


func _check_objective_and_ui_audio() -> void:
	var objectives := ObjectiveManager.find(_level)
	var flow := GameFlow.find(_level)
	var menus := _level.get_node("GameMenus") as GameMenus
	var hud := _level.get_node("ObjectiveHud") as ObjectiveHud
	_audio.played.clear()
	objectives.complete(ObjectiveManager.ENTER_LIBRARY)
	_expect(_audio.played.has("objective_complete"), "Completing an objective should play its sound.")
	_expect(hud.get_header_text() == "OBJECTIVE 2/5", "The objective header should count progress, got '%s'." % hud.get_header_text())
	flow.pause()
	await _frames(2)
	_expect(_audio.played.back() == "ui_pause", "Pausing should play the pause sound.")
	_audio.played.clear()
	menus.resume_button.mouse_entered.emit()
	_expect(_audio.played == ["ui_hover"] and _audio._ui.can_process(), "Hovering a pause-menu button should tick, even while paused.")
	menus.resume_button.pressed.emit()
	await _frames(2)
	_expect(_audio.played.has("ui_click") and _audio.played.has("ui_resume") and not _host.get_tree().paused,
		"The Resume button should click and play the resume sound, got %s." % [_audio.played])


func _check_detection_meter() -> void:
	var hud := _level.get_node("StealthHud") as StealthHud
	var guards := _level.find_children("*", "Guard", true, false)
	for g in guards:
		g.vision.detection = 0.0
	_expect(hud.get_detection_level() == 0.0, "The meter should be empty when no guard notices the player.")
	(guards[0] as Guard).vision.detection = 50.0
	(guards[1] as Guard).vision.detection = 20.0
	_expect(is_equal_approx(hud.get_detection_level(), 0.5), "The meter should follow the most aware guard (got %.2f)." % hud.get_detection_level())
	for g in guards:
		g.vision.detection = 0.0
	# A chasing guard fills the meter, whatever its detection value.
	var chaser := guards[0] as Guard
	_expect(chaser.machine.request_transition(GuardStateMachine.CHASE, "presentation test", chaser.global_position), "The test chase should start.")
	_expect(hud.get_detection_level() == 1.0, "The meter should be full during a chase.")
	chaser.reset_to_start()


func _check_door_audio() -> void:
	var door: ExitDoor = _level.get_node("Gameplay/ExitDoor")
	_audio.played.clear()
	door.interact(_player)
	_expect(_audio.played.has("door_locked"), "A locked exit should rattle.")


func _frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
