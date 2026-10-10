extends SceneTree

## Development tool: screenshots of the Expanded Library mission as the player
## sees it (HUD included), at each step of the five objectives:
##   01 start, 02 card door refused, 03 the staff card, 04 card door opened,
##   05 the manuscript, 06 back gate unlocked, 07 the exit, 08 the win screen.
## The level guards are removed; the player is placed and the interact action
## used through the real PlayerInteractor, so the HUD shows the real prompts
## and messages.
##
##   godot --path . --resolution 1600x1000 --script res://tools/expanded/capture_mission.gd -- --out=docs/expanded/v2/mission
##
## Needs a display (xvfb-run works; software rendering is fine).

const Layout := preload("res://tools/expanded/expanded_layout.gd")
const SCENE := "res://scenes/level/expanded_library.tscn"
const U := Layout.UPPER_Y

var _level: Node3D
var _player: FirstPersonPlayer
var _interactor: PlayerInteractor
var _out := ""
var _shots := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_out = "docs/expanded/%s/mission" % Layout.VERSION
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	if DisplayServer.get_name() == "headless":
		push_error("capture_mission needs a display (run without --headless, e.g. under xvfb-run).")
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
	_interactor = _player.get_node("Interactor")
	await _wait(30)
	var g2: Node3D = _level.get_node("Gameplay/ArchiveFrontGateG2")
	var g3: Node3D = _level.get_node("Gameplay/ArchiveBackGateG3")
	var card: Node3D = _level.get_node("Gameplay/StaffAccessCard")
	var item: Node3D = _level.get_node("Gameplay/RareManuscript")
	var exit: Node3D = _level.get_node("Gameplay/ExitDoor")

	await _stand(Vector3(0, 0, 30), Vector3(0, 1.6, 18))
	await _shot(dir, "01_start")
	await _stand(Vector3(0, 0, 20), Vector3(0, 1.6, 10))   # enters the lobby: O1
	await _stand(Vector3(10.0, U, -11), g2.global_position)
	_interactor.try_interact()
	await _shot(dir, "02_card_door_refused")
	await _stand(Vector3(3, U, -22.2), card.global_position)
	await _shot(dir, "03_staff_card")
	_interactor.try_interact()
	await _stand(Vector3(9.4, U, -11), g2.global_position)
	_interactor.try_interact()
	await _stand(Vector3(8.5, U, -11), Vector3(20, U + 1.2, -11))
	await _shot(dir, "04_card_door_opened")
	await _stand(Vector3(32, U, -23.6), item.global_position)
	await _shot(dir, "05_manuscript")
	_interactor.try_interact()
	await _stand(Vector3(28.6, U, -9), g3.global_position)
	_interactor.try_interact()
	await _stand(Vector3(27.5, U, -9), Vector3(36, U + 1.0, -9))
	await _shot(dir, "06_back_gate_unlocked")
	await _stand(Vector3(33.5, 0, 24), exit.global_position)
	await _shot(dir, "07_exit")
	_interactor.try_interact()
	await _wait(150)
	await _shot(dir, "08_win")
	print("Captured %d mission views → %s" % [_shots, dir])
	_level.queue_free()
	for i in 30:
		await process_frame
	quit(0)


## Puts the player at `at` (floor level) looking at `target`.
func _stand(at: Vector3, target: Vector3) -> void:
	_player.global_position = at + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = atan2(-(target.x - at.x), -(target.z - at.z))
	var eye := at.y + _player.stand_eye_height
	_player.head.rotation.x = atan2(target.y - eye, Vector2(target.x - at.x, target.z - at.z).length())
	await _wait(12)


func _shot(dir: String, name: String) -> void:
	await _wait(10)
	root.get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	_shots += 1


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame
