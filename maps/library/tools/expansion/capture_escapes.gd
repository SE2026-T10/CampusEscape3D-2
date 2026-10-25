extends SceneTree

## Development tool: screenshots of the Phase 6 escape routes and the capture
## screen, HUD included:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x1000 \
##       --script res://maps/library/tools/expansion/capture_escapes.gd -- --out=maps/library/docs/expansion/phase-6/screens
## Guards are removed (a test guard makes the capture); E is pressed with real input.

const SCENE := "res://maps/library/scenes/expanded_library.tscn"
const GUARD_SCENE := "res://shared/scenes/npc/guard.tscn"
const X := preload("res://maps/library/tools/expansion/expansion_layout.gd")
const B := X.BF
const U := 4.5
const M := "Expansion/Gameplay/Mission/"
const E := "Expansion/Gameplay/Escape/"

var _level: Node3D
var _player: FirstPersonPlayer
var _shots := 0
var _dir := ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "maps/library/docs/expansion/phase-6/screens"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	if DisplayServer.get_name() == "headless":
		push_error("capture_escapes needs a display (run under xvfb-run).")
		quit(1)
		return
	_dir = ProjectSettings.globalize_path("res://" + out)
	DirAccess.make_dir_recursive_absolute(_dir)
	await _fresh()
	var main: ExitDoor = _level.get_node(E + "MainEntranceExit")
	var reader: Node3D = _level.get_node(E + "BadgeReader")
	# Route A.
	await _stand(Vector3(0, 0, 20), Vector3(0, 1.4, 27))
	await _wait(10)
	await _shot("e01_main_entrance_lockdown")
	await _stand(Vector3(1.6, 0, 26.6), reader.global_position)
	await _press("interact")
	await _shot("e02_badge_reader_needs_badge")
	var locker: CodeLock = _level.get_node(M + "SecurityLocker")
	locker.set_entry("136")
	locker.submit()
	await _wait(3)
	_level.get_node("Expansion/Gameplay/Items/LockerBadge").interact(_player)
	await _stand(Vector3(1.6, 0, 26.6), reader.global_position)
	await _press("interact")
	await _wait(100)
	await _shot("e03_badge_reader_override")
	await _wait(200)
	await _stand(Vector3(-1.2, 0, 26.0), Vector3(0.3, 1.2, 29.5))
	await _shot("e04_main_entrance_open")
	await _get_manuscript()
	await _walk(Vector3(0, 0, 26.6), Vector3(0, 0, 31), 1.5)
	await _wait(60)
	await _shot("e05_win_main_entrance")
	# Route B.
	await _fresh()
	var shutter: Node3D = _level.get_node(E + "DockShutterControl")
	var release: Node3D = _level.get_node(E + "DockShutterRelease")
	await _stand(Vector3(0, 0, 20), Vector3(0, 1, 15))
	await _stand(Vector3(33.4, 0, 24.0), Vector3(36, 1.4, 24))
	await _shot("e06_dock_shutter_no_power")
	_level.get_node("Expansion/Gameplay/Security/ServiceExitSwitch").interact(_player)
	_level.get_node("Expansion/Gameplay/Items/ToolKit").interact(_player)
	await _stand(Vector3(34.6, 0, 21.4), release.global_position)
	await _press("interact")
	await _shot("e07_dock_release_freed")
	await _stand(Vector3(34.6, 0, 26.4), shutter.global_position)
	await _press("interact")
	await _shot("e08_dock_shutter_open")
	await _get_manuscript()
	await _walk(Vector3(34.6, 0, 24), Vector3(39, 0, 24), 1.5)
	await _wait(60)
	await _shot("e09_win_loading_dock")
	# Route C.
	await _fresh()
	var panel: Node3D = _level.get_node("Expansion/Gameplay/MaintenancePanel")
	await _stand(Vector3(0, 0, 20), Vector3(0, 1, 15))
	await _stand(Vector3(0, B, -23.8), panel.global_position + Vector3(0, 0.4, 0))
	await _shot("e10_hidden_panel_undiscovered")
	await _stand(Vector3(-23.5, B, -18.2), _level.get_node("Expansion/Gameplay/Documents/CulvertAccessPlan").global_position)
	await _press("interact")
	await _wait(10)
	await _shot("e11_culvert_access_plan")
	_level.get_node("ObjectiveHud").close_journal()
	await _stand(Vector3(0, B, -25.2), panel.global_position + Vector3(0, 0.4, 0))
	await _shot("e12_hidden_panel_found")
	await _press("interact")
	await _stand(Vector3(0, B, -25.2), Vector3(0, B + 1.2, -37))
	await _shot("e13_passage_open_grate_jammed")
	# The capture screen.
	var cp: Checkpoint = null
	for c in _level.get_tree().get_nodes_in_group("checkpoints"):
		if c.checkpoint_name == "Study Rooms":
			cp = c
	CheckpointManager.find(_level).activate(cp)
	await _stand(Vector3(0, 0, 18), Vector3(0, 1.5, 15))
	var guard: Guard = (load(GUARD_SCENE) as PackedScene).instantiate()
	var route := PatrolRoute.new()
	var post := PatrolPoint.new()
	post.position = Vector3(0, 0, 16.6)
	post.wait_time = 300.0
	route.add_child(post)
	_level.add_child(route)
	guard.patrol_route = route
	guard.position = Vector3(0, 0.05, 16.6)
	guard.rotation.y = PI   # facing +z, toward the player
	_level.add_child(guard)
	var director := StealthDirector.find(_level)
	for i in 600:
		await process_frame
		if director.status == StealthDirector.Status.CAUGHT:
			break
	await _wait(2)   # the overlay shows for reset_delay; shoot at once (rendering can be slow here)
	await _shot("e14_caught_screen")
	print("Captured %d views → %s" % [_shots, _dir])
	_level.queue_free()
	for i in 30:
		await process_frame
	quit(0)


func _fresh() -> void:
	if _level:
		_level.queue_free()
		for i in 20:
			await process_frame
	_level = (load(SCENE) as PackedScene).instantiate()
	for g in _level.get_node("Guards").get_children():
		if g is Guard:
			g.get_parent().remove_child(g)
			g.free()
	root.add_child(_level)
	GameFlow.find(_level).change_scene = func(_path: String): pass
	_player = _level.get_node("Player")
	var debug := _level.get_node_or_null("DetectionDebugHud")
	if debug:
		debug.visible = false
	await _wait(40)


func _get_manuscript() -> void:
	var inventory: PlayerInventory = _player.get_node("Inventory")
	var toolkit := _level.get_node("Expansion/Gameplay/Items/ToolKit") as ItemPickup
	if not inventory.has(ItemCatalog.TOOLKIT) and toolkit.available:
		toolkit.interact(_player)
	_level.get_node("Gameplay/StaffAccessCard").interact(_player)
	(_level.get_node(M + "ElectricalPanelCover") as ToolMechanism).interact(_player)
	var breakers: BreakerPanel = _level.get_node(M + "BreakerPanel")
	breakers.set_setting([true, false, true, true])
	breakers.engage()
	var keypad: CodeLock = _level.get_node(M + "VaultKeypad")
	keypad.set_entry("2691")
	keypad.submit()
	await _wait(3)
	_level.get_node("Gameplay/RareManuscript").interact(_player)
	await _wait(3)


func _stand(at: Vector3, target: Vector3) -> void:
	_player.global_position = at + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = atan2(-(target.x - at.x), -(target.z - at.z))
	var eye := at.y + _player.stand_eye_height
	_player.head.rotation.x = atan2(target.y - eye, Vector2(target.x - at.x, target.z - at.z).length())
	await _wait(12)


func _walk(from: Vector3, toward: Vector3, seconds: float) -> void:
	await _stand(from, toward + Vector3(0, 1.6, 0))
	_player.head.rotation.x = 0.0
	Input.action_press("move_forward")
	var t := 0.0
	while t < seconds:
		await process_frame
		t += 1.0 / 60.0
	Input.action_release("move_forward")


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


func _shot(shot_name: String) -> void:
	await _wait(6)
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(shot_name + ".png"))
	_shots += 1


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame
