extends SceneTree

## Development tool: screenshots of the Phase 5 security systems (switches,
## cameras, alarm, the dock shutter's power, the basement guard), HUD included:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x1000 \
##       --script res://maps/library/tools/expansion/capture_security.gd -- --out=maps/library/docs/expansion/phase-5/screens
## Every guard but GuardBasement is removed; E is pressed with real input.

const SCENE := "res://maps/library/scenes/expanded_library.tscn"
const X := preload("res://maps/library/tools/expansion/expansion_layout.gd")
const B := X.BF
const U := 4.5
const SEC := "Expansion/Gameplay/Security/"

var _level: Node3D
var _player: FirstPersonPlayer
var _shots := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "maps/library/docs/expansion/phase-5/screens"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	if DisplayServer.get_name() == "headless":
		push_error("capture_security needs a display (run under xvfb-run).")
		quit(1)
		return
	var dir := ProjectSettings.globalize_path("res://" + out)
	DirAccess.make_dir_recursive_absolute(dir)
	_level = (load(SCENE) as PackedScene).instantiate()
	for g in _level.get_node("Guards").get_children():
		if g is Guard and g.name != &"GuardBasement":
			g.get_parent().remove_child(g)
			g.free()
	root.add_child(_level)
	GameFlow.find(_level).change_scene = func(_path: String): pass
	_player = _level.get_node("Player")
	var debug := _level.get_node_or_null("DetectionDebugHud")
	if debug:
		debug.visible = false
	await _wait(40)
	var guard: Guard = _level.get_node("Guards/GuardBasement")
	var surveillance: CircuitSwitch = _level.get_node(SEC + "SurveillanceSwitch")
	var service: CircuitSwitch = _level.get_node(SEC + "ServiceExitSwitch")
	var cam: SecurityCamera = _level.get_node(SEC + "Cameras/CameraArchiveHall")
	var tunnel_cam: SecurityCamera = _level.get_node(SEC + "Cameras/CameraTunnel")

	# The basement guard on its patrol, seen from the tunnel's east part.
	Input.action_press("crouch")
	await _stand(Vector3(-14, B, -24.0), guard.global_position + Vector3(0, 1.4, 0))
	await _wait(60)
	await _stand(Vector3(-14, B, -24.0), guard.global_position + Vector3(0, 1.4, 0))
	await _shot(dir, "s01_basement_guard_patrol")
	Input.action_release("crouch")
	guard.get_parent().remove_child(guard)
	guard.free()
	# The tunnel camera, powered (green, cone).
	await _stand(Vector3(2, B, -25.4), tunnel_cam.global_position)
	await _shot(dir, "s02_tunnel_camera_scanning")
	# The switch board in the electrical room: SURVEILLANCE ON, SERVICE EXIT OFF.
	await _stand(Vector3(41.0, 0, -24.6), Vector3(41.0, 1.6, -27.0))
	await _shot(dir, "s03_switch_board_default")
	# The archive hall camera sees the player: its meter fills, then the alarm.
	cam.sweep_speed = 0.0
	cam._sweep = 0.0
	var forward := -cam.global_basis.z
	forward.y = 0.0
	var spot := cam.global_position + forward.normalized() * 4.0
	spot.y = U
	await _stand(spot, cam.global_position)
	while cam.alarms == 0:
		await _wait(5)
	await _wait(4)
	await _shot(dir, "s05_camera_alarm_hud")
	_level.get_node("Expansion/Gameplay/Mission/SecurityAlarm").clear()
	# Surveillance OFF: the message, then the camera dark.
	await _stand(Vector3(38.8, 0, -25.6), surveillance.global_position)
	await _press("interact")
	await _shot(dir, "s06_surveillance_off_message")
	await _stand(spot, cam.global_position)
	await _wait(30)
	await _shot(dir, "s07_camera_dark_no_power")
	# The dock with the manuscript but no service power.
	var objectives := ObjectiveManager.find(_level)
	for id in [&"enter_library", &"take_card", &"find_toolkit", &"open_panel", &"restore_power", &"open_vault", &"take_manuscript"]:
		objectives.complete(id)
	var dock: Node3D = _level.get_node("Gameplay/ExitDoor")
	await _wait(200)   # let the objective messages fade
	await _stand(Vector3(34.3, 0, 24), dock.global_position)
	await _press("interact")
	await _stand(Vector3(33.0, 0, 21.5), dock.global_position + Vector3(0, 0.6, 0))
	await _shot(dir, "s08_dock_shutter_no_power")
	# SERVICE EXIT ON: the reboot message, the surveillance switch locked.
	await _stand(Vector3(43.2, 0, -25.6), service.global_position)
	await _press("interact")
	await _shot(dir, "s09_service_on_reboot_message")
	await _stand(Vector3(38.8, 0, -25.6), surveillance.global_position)
	await _press("interact")
	await _shot(dir, "s10_surveillance_switch_locked")
	await _stand(Vector3(33.0, 0, 21.5), dock.global_position + Vector3(0, 0.6, 0))
	await _shot(dir, "s11_dock_shutter_unlocked")
	print("Captured %d views → %s" % [_shots, dir])
	_level.queue_free()
	for i in 30:
		await process_frame
	quit(0)


func _stand(at: Vector3, target: Vector3) -> void:
	_player.global_position = at + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = atan2(-(target.x - at.x), -(target.z - at.z))
	var eye := at.y + (_player.crouch_eye_height if _player.is_crouching else _player.stand_eye_height)
	_player.head.rotation.x = atan2(target.y - eye, Vector2(target.x - at.x, target.z - at.z).length())
	await _wait(12)


func _press(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await _wait(2)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await _wait(3)


func _shot(dir: String, shot_name: String) -> void:
	await _wait(6)
	root.get_viewport().get_texture().get_image().save_png(dir.path_join(shot_name + ".png"))
	_shots += 1


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame
