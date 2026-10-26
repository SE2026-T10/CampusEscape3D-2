extends SceneTree

## Development tool: screenshots of the Expanded Library as the player sees it,
## from a fixed set of viewpoints on both floors (every zone, the stairs, the
## mission objects, the exit), plus two overviews with the roof hidden. Used to
## compare visual passes: run it on two builds with the same viewpoints.
## The guards stay where the level starts them but are frozen (no AI), so the
## pictures also show how readable a guard is under the lighting.
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x1000 \
##       --script res://maps/library/tools/capture_views.gd -- --out=maps/library/docs/v4/views
## Options: --out=PATH (default maps/library/docs/<layout version>/views),
##          --only=name1,name2 (just those views)
##
## Needs a display (xvfb-run works; software rendering is fine).

const Layout := preload("res://maps/library/tools/expanded_layout.gd")
const SCENE := "res://maps/library/scenes/expanded_library.tscn"
const U := Layout.UPPER_Y

## [name, player position (floor level), look-at point]
const VIEWS := [
	["01_porch", Vector3(0, 0, 32.5), Vector3(0, 1.6, 20)],
	["02_lobby", Vector3(8, 0, 26.5), Vector3(-6, 1.8, 14)],
	["03_lobby_stair_S1", Vector3(-3, 0, 24), Vector3(-10.35, 2.6, 12)],
	["04_browsing_hall", Vector3(-13.5, 0, 26.5), Vector3(-30, 1.4, 14)],
	["05_main_stacks", Vector3(-13.5, 0, -9), Vector3(-34, 1.3, -9)],
	["06_reading_hall", Vector3(0, 0, 8.5), Vector3(0, 1.2, -12)],
	["07_study_room", Vector3(3, 0, -15.3), Vector3(3, 1.0, -27)],
	["08_service_corridor", Vector3(14.5, 0, -26.5), Vector3(14.5, 1.5, 10)],
	["09_storage_S2", Vector3(18.5, 0, 3), Vector3(34, 1.8, 3)],
	["10_dock_exit", Vector3(21, 0, 20), Vector3(36, 1.4, 24)],
	["11_balcony", Vector3(-8.5, U, 7), Vector3(8, U + 1.0, -6)],
	["12_lobby_from_balcony", Vector3(-4, U, 8.6), Vector3(2, 0.5, 22)],
	["13_upper_stacks", Vector3(-12.5, U, -10), Vector3(-34, U + 1.3, -10)],
	["14_staff_corridor", Vector3(-4.5, U, -11), Vector3(12, U + 1.2, -11)],
	["15_office_card", Vector3(3, U, -15.4), Vector3(3, U + 0.9, -24)],
	["16_archive_hall", Vector3(26, U, -16.5), Vector3(13, U + 1.0, -9)],
	["17_archive_stacks", Vector3(19.5, U, -12.5), Vector3(19.5, U + 1.0, -26)],
	["18_vault_manuscript", Vector3(27, U, -21), Vector3(32, U + 1.0, -25)],
	["19_back_gate_landing", Vector3(33.5, U, -8), Vector3(29, U + 1.4, -9)],
	["20_down_S2", Vector3(34.35, U, -8.2), Vector3(34.35, 0.0, 0.5)],
]
## [name, camera position, look-at point]: free-camera overviews, roof and ceilings (layer 2) hidden.
const OVERVIEWS := [
	["21_overview_upper", Vector3(-4, 34, 46), Vector3(0, 2, -6)],
	["22_overview_ground_east", Vector3(46, 26, 30), Vector3(18, 0, 4)],
]

var _level: Node3D
var _player: FirstPersonPlayer
var _out := ""
var _only: PackedStringArray = []
var _shots := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_out = "maps/library/docs/%s/views" % Layout.VERSION
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			_only = a.trim_prefix("--only=").split(",")
	if DisplayServer.get_name() == "headless":
		push_error("capture_views needs a display (run without --headless, e.g. under xvfb-run).")
		quit(1)
		return
	var dir := ProjectSettings.globalize_path("res://" + _out)
	DirAccess.make_dir_recursive_absolute(dir)
	_level = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_level)
	GameFlow.find(_level).change_scene = func(_path: String): pass
	_player = _level.get_node("Player")
	await _wait(5)
	for g in _level.get_node("Guards").get_children():
		if g is Guard:
			g.process_mode = Node.PROCESS_MODE_DISABLED
	await _wait(25)
	for v in VIEWS:
		if _only.is_empty() or _only.has(v[0]):
			await _stand(v[1], v[2])
			await _shot(dir, v[0])
	var camera := Camera3D.new()
	camera.cull_mask = camera.cull_mask & ~2
	camera.fov = 60.0
	camera.far = 300.0
	_level.add_child(camera)
	for v in OVERVIEWS:
		if _only.is_empty() or _only.has(v[0]):
			camera.global_position = v[1]
			camera.look_at(v[2])
			camera.make_current()
			await _shot(dir, v[0])
	print("Captured %d views → %s" % [_shots, dir])
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


func _shot(dir: String, shot_name: String) -> void:
	await _wait(10)
	root.get_viewport().get_texture().get_image().save_png(dir.path_join(shot_name + ".png"))
	_shots += 1


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame
