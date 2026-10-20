extends SceneTree

## Development tool: screenshots of the Phase 7 HUD and accessibility features.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 \
##       --script res://tools/expanded/expansion/capture_hud.gd -- --out=docs/expanded/expansion/phase-7/screens [--scale=1.25] [--set=full|layout]
## "full" (default): the feature views. "layout": one busy Expanded Library view
## and the tutorial at the given resolution and interface scale (file names
## carry both). Settings are not saved (a scratch settings file is used).
## Guards are removed except where a view needs one.

const SCENE := "res://scenes/level/expanded_library.tscn"
const TUTORIAL := "res://scenes/level/library_graybox.tscn"
const MENU := "res://scenes/ui/main_menu.tscn"
const GUARD_SCENE := "res://scenes/npc/guard.tscn"
const X := preload("res://tools/expanded/expansion/expansion_layout.gd")
const B := X.BF
const U := 4.5
const M := "Expansion/Gameplay/Mission/"
const E := "Expansion/Gameplay/Escape/"

var _level: Node
var _player: FirstPersonPlayer
var _dir := ""
var _scale := 1.0
var _tag := ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "docs/expanded/expansion/phase-7/screens"
	var set_name := "full"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--scale="):
			_scale = float(a.trim_prefix("--scale="))
		elif a.begins_with("--set="):
			set_name = a.trim_prefix("--set=")
	if DisplayServer.get_name() == "headless":
		push_error("capture_hud needs a display (run under xvfb-run).")
		quit(1)
		return
	GameSettings.path = "user://capture_hud_settings.cfg"
	GameSettings.reset_to_defaults()
	GameSettings.hud_scale = _scale
	_dir = ProjectSettings.globalize_path("res://" + out)
	DirAccess.make_dir_recursive_absolute(_dir)
	var size := DisplayServer.window_get_size()
	_tag = "%dx%d_%d" % [size.x, size.y, int(round(_scale * 100))]
	if set_name == "layout":
		await _layout_set()
	else:
		await _full_set()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.path))
	quit(0)


func _full_set() -> void:
	# Main menu and its settings screen.
	await _open(MENU)
	await _shot("h01_main_menu_settings_button")
	(_level as MainMenu).open_settings()
	await _shot("h02_settings_panel")
	# Expanded Library: the tracker learns the ways out.
	await _open(SCENE)
	await _stand(Vector3(0, 0, 20), Vector3(0, 1.4, 12))
	await _wait(260)   # messages fade
	await _shot("h03_tracker_ways_out_after_entering")
	# Some progress: tool kit, switches seen, the locker, the plan, the dock control.
	_level.get_node("Expansion/Gameplay/Items/ToolKit").interact(_player)
	_level.get_node("Expansion/Gameplay/Security/ServiceExitSwitch").interact(_player)
	var locker: CodeLock = _level.get_node(M + "SecurityLocker")
	locker.set_entry("136")
	locker.submit()
	await _wait(3)
	_level.get_node("Expansion/Gameplay/Items/LockerBadge").interact(_player)
	(_level.get_node(E + "DockShutterControl") as DockShutter).button.interact(_player)
	_level.get_node("Expansion/Gameplay/Documents/CulvertAccessPlan").interact(_player)
	await _wait(5)
	await _shot("h04_journal_clues_and_documents")
	_level.get_node("ObjectiveHud").close_journal()
	CheckpointManager.find(_level).activate(_checkpoint("Storage"))
	await _stand(Vector3(30, 0, 20), Vector3(36, 1.4, 24))
	await _wait(260)
	await _shot("h05_tracker_ways_out_power_checkpoint")
	# Captions: an alarm behind, a bottle to the left, a breaker clunk ahead.
	await _stand(Vector3(0, 0, 0), Vector3(0, 1.4, -10))
	var noise := NoiseSystem.find(_level)
	SecurityAlarm.find(_level).raise_alarm(Vector3(0, 0, 8), "test", 22.0)
	noise.emit_noise(Vector3(-6, 0, 0), NoiseEvent.Type.INTERACTION, "distraction", 1.0, 14.0, -1.0, "Glass smashes")
	noise.emit_noise(Vector3(0, 0, -6), NoiseEvent.Type.INTERACTION, "environment", 0.6, 9.0, -1.0, "Breaker clunk")
	await _wait(10)
	await _shot("h06_sound_captions")
	SecurityAlarm.find(_level).clear()
	# A guard walking nearby: footsteps captioned; then a short sprint until the
	# stamina runs out, still holding Shift: exhausted.
	await _stand(Vector3(0, 0, 0), Vector3(0, 1.4, -10))
	# This screenshot guard is blind (vision range 0): the sprint is loud, and a
	# guard that turned and saw the player would catch them mid-shot. Its
	# footsteps are captioned as for any guard.
	var guard := _spawn_guard([Vector3(4, 0, 3), Vector3(4, 0, 11)])
	guard.vision.detection_distance = 0.0
	await _wait(150)
	_player.head.rotation.x = 0.0
	_player.stamina.stamina = _player.stamina.min_to_start + 1.0
	Input.action_press("sprint")
	Input.action_press("move_forward")
	# The shot is taken as the stamina runs dry (frames are slow under xvfb, and
	# the caption lasts 3.5 s of game time).
	await _player.stamina.exhausted
	await _shot("h07_footsteps_caption_exhausted")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	guard.queue_free()
	# The completion screen.
	await _get_manuscript()
	await _walk(Vector3(34.6, 0, 24), Vector3(39, 0, 24), 1.5)
	await _wait(60)
	await _shot("h08_completion_route_time_optional")
	# Pause menu settings.
	await _open(SCENE)
	await _stand(Vector3(0, 0, 20), Vector3(0, 1.4, 12))
	GameFlow.find(_level).pause()
	await _wait(10)
	await _shot("h09_pause_menu_settings_button")
	(_level.get_node("GameMenus") as GameMenus).open_settings()
	await _shot("h10_pause_settings_panel")
	# The tutorial HUD.
	await _open(TUTORIAL)
	await _stand(Vector3(0, 0, 14), Vector3(0, 1.4, 6))
	await _wait(60)
	await _shot("h11_tutorial_hud")


## One busy view per map at this resolution and scale.
func _layout_set() -> void:
	await _open(SCENE)
	await _stand(Vector3(0, 0, 20), Vector3(0, 1.4, 12))
	_level.get_node("Expansion/Gameplay/Items/ToolKit").interact(_player)
	_level.get_node("Gameplay/StaffAccessCard").interact(_player)
	_level.get_node("Expansion/Gameplay/Security/ServiceExitSwitch").interact(_player)
	_level.get_node("Expansion/Gameplay/Documents/CulvertAccessPlan").interact(_player)
	(_level.get_node(E + "DockShutterControl") as DockShutter).button.interact(_player)
	_level.get_node("ObjectiveHud").close_journal()
	var noise := NoiseSystem.find(_level)
	await _wait(200)
	noise.emit_noise(Vector3(-6, 0, 20), NoiseEvent.Type.INTERACTION, "distraction", 1.0, 14.0, -1.0, "Glass smashes")
	noise.emit_noise(Vector3(0, 0, 14), NoiseEvent.Type.INTERACTION, "environment", 0.6, 9.0, -1.0, "Breaker clunk")
	_player.stamina.stamina = 30.0
	await _wait(8)
	await _shot("l_expanded_" + _tag)
	_level.get_node("ObjectiveHud").open_journal(&"")
	await _shot("l_expanded_journal_" + _tag)
	var hud := _level.get_node("ObjectiveHud")
	hud.next_journal_page()
	if hud.is_journal_open():
		await _shot("l_expanded_journal_p2_" + _tag)
		hud.close_journal()
	await _open(TUTORIAL)
	await _stand(Vector3(0, 0, 14), Vector3(0, 1.4, 6))
	await _wait(60)
	await _shot("l_tutorial_" + _tag)


func _open(path: String, remove_guards := true) -> void:
	if _level:
		_level.queue_free()
		for i in 20:
			await process_frame
	_level = (load(path) as PackedScene).instantiate()
	if remove_guards and _level.has_node("Guards"):
		for g in _level.get_node("Guards").get_children():
			if g is Guard:
				g.get_parent().remove_child(g)
				g.free()
	root.add_child(_level)
	if _level is MainMenu:
		(_level as MainMenu).change_scene = func(_p): pass
	else:
		GameFlow.find(_level).change_scene = func(_p): pass
		_player = _level.get_node("Player")
		var debug := _level.get_node_or_null("DetectionDebugHud")
		if debug:
			debug.visible = false
	GameSettings.hud_scale = _scale
	GameSettings.apply(self)
	await _wait(40)


func _checkpoint(cp_name: String) -> Checkpoint:
	for cp in _level.get_tree().get_nodes_in_group("checkpoints"):
		if cp.checkpoint_name == cp_name:
			return cp
	return null


func _spawn_guard(points: Array) -> Guard:
	var route := PatrolRoute.new()
	for p in points:
		var marker := PatrolPoint.new()
		marker.position = p
		marker.wait_time = 0.2
		route.add_child(marker)
	_level.add_child(route)
	var guard: Guard = (load(GUARD_SCENE) as PackedScene).instantiate()
	guard.patrol_route = route
	guard.position = points[0] + Vector3(0, 0.05, 0)
	_level.add_child(guard)
	return guard


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
	(_level.get_node(E + "DockShutterRelease") as ToolMechanism).interact(_player)
	(_level.get_node(E + "DockShutterControl") as DockShutter).button.interact(_player)
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


func _shot(shot_name: String) -> void:
	await _wait(6)
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(shot_name + ".png"))


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame
