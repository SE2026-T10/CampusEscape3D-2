extends SceneTree

## Development tool: screenshots of the Phase 4 puzzles, their feedback and the
## journal, HUD included:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x1000 \
##       --script res://tools/expanded/expansion/capture_puzzles.gd -- --out=docs/expanded/expansion/phase-4/screens
## Guards are removed; real input (E, J) drives the player where it matters.

const SCENE := "res://scenes/level/expanded_library.tscn"
const X := preload("res://tools/expanded/expansion/expansion_layout.gd")
const B := X.BF
const U := 4.5

var _level: Node3D
var _player: FirstPersonPlayer
var _out := ""
var _shots := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_out = "docs/expanded/expansion/phase-4/screens"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	if DisplayServer.get_name() == "headless":
		push_error("capture_puzzles needs a display (run under xvfb-run).")
		quit(1)
		return
	var dir := ProjectSettings.globalize_path("res://" + _out)
	DirAccess.make_dir_recursive_absolute(dir)
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
	await _wait(30)
	var m := "Expansion/Gameplay/Mission/"
	var cover: ToolMechanism = _level.get_node(m + "ElectricalPanelCover")
	var breakers: BreakerPanel = _level.get_node(m + "BreakerPanel")
	var keypad: CodeLock = _level.get_node(m + "VaultKeypad")
	var locker: CodeLock = _level.get_node(m + "SecurityLocker")
	var pump: PumpControl = _level.get_node(m + "PumpControl")
	var crank: ToolMechanism = _level.get_node(m + "PumpCrank")
	var docs := "Expansion/Gameplay/Documents/"

	await _stand(Vector3(0, 0, 20), Vector3(0, 1.5, 12))   # enter
	var plaque: Node3D = _level.get_node(docs + "LobbyPlaque")
	await _stand(Vector3(-10.4, 0, 20), plaque.global_position)
	await _shot(dir, "p01_lobby_plaque_clue")
	await _press("interact")
	# The panel without the tool kit.
	await _stand(Vector3(41.0, 0, -25.6), cover.global_position)
	await _shot(dir, "p02_panel_cover_needs_tool_kit")
	_level.get_node("Expansion/Gameplay/Items/ToolKit").interact(_player)
	await _press("interact")
	# A wrong breaker setting: trip and alarm.
	breakers.set_setting([true, true, true, true])
	await _stand(Vector3(41.0, 0, -25.6), breakers.main_switch.global_position)
	await _press("interact")
	await _shot(dir, "p03_breakers_wrong_setting_trips_alarm")
	_level.get_node(m + "SecurityAlarm").clear()
	var chart: Node3D = _level.get_node(docs + "WiringChart")
	await _stand(Vector3(26.0, 0, -26.5), chart.global_position)
	await _press("interact")
	await _shot(dir, "p04_wiring_chart_in_journal")
	await _press("journal")
	await _press("journal")
	breakers.set_setting([true, false, true, true])
	await _stand(Vector3(41.0, 0, -25.6), breakers.main_switch.global_position)
	await _press("interact")
	await _shot(dir, "p05_breakers_power_restored")
	# The keypad: wrong codes, lockout, the right code.
	_level.get_node("Gameplay/StaffAccessCard").interact(_player)
	await _stand(Vector3(26.7, U, -19.3), keypad.global_position)
	keypad.set_entry("1234")
	await _press_on(keypad.enter.global_position)
	await _shot(dir, "p06_keypad_wrong_code_alarm")
	_level.get_node(m + "SecurityAlarm").clear()
	keypad.submit()
	keypad.submit()
	await _stand(Vector3(26.7, U, -19.3), keypad.global_position)
	await _shot(dir, "p07_keypad_locked_out")
	keypad.lockout_left = 0.01
	await _wait(5)
	keypad.set_entry("2691")
	_level.get_node(m + "SecurityAlarm").clear()
	await _press_on(keypad.enter.global_position)
	await _stand(Vector3(26.0, U, -21.0), Vector3(30, 5.5, -22))
	await _shot(dir, "p08_keypad_accepted_vault_open")
	# The pump: a stall, then drained.
	crank.interact(_player)
	await _stand(Vector3(pump.start_lever.global_position.x, B, -15.6), pump.start_lever.global_position)
	await _press("interact")
	await _shot(dir, "p09_pump_stalls")
	pump.set_setting([true, false, true])
	await _press("interact")
	await _stand(Vector3(0, B, -30.0), Vector3(0, B + 1.2, -38.0))
	await _shot(dir, "p10_pump_drained_grate_clear")
	# The locker: rota, then opened.
	var rota: Node3D = _level.get_node(docs + "NightRota")
	await _stand(Vector3(4.6, U, -17.0), rota.global_position)
	await _press("interact")
	await _press("journal")
	locker.set_entry("136")
	await _stand(Vector3(-4.2, U, -21.8), locker.global_position + Vector3(0, -0.6, -0.6))
	locker.submit()
	await _wait(10)
	await _shot(dir, "p11_locker_open_reward")
	# The journal and the objective panel.
	var memo: Node3D = _level.get_node(docs + "ArchivistMemo")
	await _stand(Vector3(10.6, U, -20.0), memo.global_position)
	await _press("interact")
	await _wait(5)
	await _shot(dir, "p12_journal_mission_clues_memo")
	await _press("journal")
	await _press("journal")
	await _press("journal")
	await _press("journal")
	await _stand(Vector3(10.6, U, -18.0), Vector3(10.6, U + 1.6, -14))
	await _wait(240)   # let the messages fade
	await _shot(dir, "p13_objective_panel_optional_section")
	print("Captured %d views → %s" % [_shots, dir])
	_level.queue_free()
	for i in 30:
		await process_frame
	quit(0)


func _stand(at: Vector3, target: Vector3) -> void:
	_player.global_position = at + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = atan2(-(target.x - at.x), -(target.z - at.z))
	var eye := at.y + _player.stand_eye_height
	_player.head.rotation.x = atan2(target.y - eye, Vector2(target.x - at.x, target.z - at.z).length())
	await _wait(12)


## Looks at `target` from where the player stands and presses E.
func _press_on(target: Vector3) -> void:
	var at := _player.global_position
	_player.rotation.y = atan2(-(target.x - at.x), -(target.z - at.z))
	var eye := at.y + _player.stand_eye_height
	_player.head.rotation.x = atan2(target.y - eye, Vector2(target.x - at.x, target.z - at.z).length())
	await _wait(6)
	await _press("interact")


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
	if not shot_name.contains("journal"):
		_level.get_node("ObjectiveHud").close_journal()   # keep the puzzle in view
	await _wait(6)
	root.get_viewport().get_texture().get_image().save_png(dir.path_join(shot_name + ".png"))
	_shots += 1


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame
