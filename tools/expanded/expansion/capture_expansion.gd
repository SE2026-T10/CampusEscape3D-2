extends SceneTree

## Development tool: screenshots of the Expanded Library expansion as the
## player sees it, plus two top-down plans, to compare builds (as
## tools/expanded/capture_views.gd does for the existing views).
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x1000 \
##       --script res://tools/expanded/expansion/capture_expansion.gd -- --out=docs/expanded/expansion/phase-2/after
## Options: --out=PATH (relative to the project), --only=name1,name2.
## The "cut_*" views look at the three doorways and work on a build without
## the expansion too (the "before" pictures). Guards are frozen where they start.

const X := preload("res://tools/expanded/expansion/expansion_layout.gd")
const SCENE := "res://scenes/level/expanded_library.tscn"
const B := X.BF

## [name, player position (floor level), look-at point]
const VIEWS := [
	["cut1_stacks_to_west_service_door", Vector3(-29.5, 0, -9.0), Vector3(-37.0, 1.4, -9.0)],
	["cut2_processing_to_electrical_door", Vector3(29.0, 0, -23.0), Vector3(37.0, 1.4, -23.0)],
	["cut3_stacks_to_study1_door", Vector3(-14.5, 0, -16.5), Vector3(-11.0, 1.2, -21.5)],
	["g01_west_landing_down_the_stair", Vector3(-37.2, 0, -4.0), Vector3(-42.2, -1.5, -16.0)],
	["g02_west_stair_from_the_tunnel", Vector3(-41.5, B, -26.0), Vector3(-42.2, B + 2.6, -12.0)],
	["g03_tunnel_looking_east", Vector3(-35.0, B, -25.0), Vector3(10.0, B + 1.4, -25.0)],
	["g04_maintenance_bay", Vector3(-24.0, B, -24.6), Vector3(-25.5, B + 0.8, -18.0)],
	["g05_pump_room", Vector3(0.0, B, -24.5), Vector3(0.0, B + 1.4, -15.0)],
	["g06_storm_drain_grate", Vector3(0.0, B, -26.0), Vector3(0.0, B + 1.4, -37.0)],
	["g07_tunnel_looking_west", Vector3(30.0, B, -25.0), Vector3(-10.0, B + 1.4, -25.0)],
	["g08_east_corridor", Vector3(39.0, B, -24.0), Vector3(39.0, B + 1.4, -7.0)],
	["g09_east_stair_up", Vector3(44.2, B, -6.8), Vector3(44.2, 0.8, -18.0)],
	["d01_electrical_room", Vector3(37.2, 0, -19.2), Vector3(44.0, 1.0, -26.5)],
	["d02_electrical_card_door_from_inside", Vector3(41.5, 0, -22.0), Vector3(35.0, 1.4, -23.0)],
]
## [name, ortho size, camera height, layers shown]: top-down plans.
const PLANS := [
	["plan_basement", 100.0, 3.0, X.LAYER_BASEMENT | 1],
	["plan_ground", 100.0, 4.15, X.LAYER_GROUND | 1],
]

var _level: Node3D
var _player: FirstPersonPlayer
var _out := ""
var _only: PackedStringArray = []
var _shots := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_out = "docs/expanded/expansion/phase-2/after"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			_only = a.trim_prefix("--only=").split(",")
	if DisplayServer.get_name() == "headless":
		push_error("capture_expansion needs a display (run under xvfb-run).")
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
	for hud in ["ObjectiveHud", "StealthHud", "DetectionDebugHud"]:
		var n := _level.get_node_or_null(hud)
		if n:
			n.visible = false
	await _wait(25)
	var has_expansion := _level.has_node("Expansion/Geometry")
	for v in VIEWS:
		if not _only.is_empty() and not _only.has(v[0]):
			continue
		if not has_expansion and not String(v[0]).begins_with("cut"):
			continue
		await _stand(v[1], v[2])
		await _shot(dir, v[0])
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 60.0
	_level.add_child(camera)
	for p in PLANS:
		if not _only.is_empty() and not _only.has(p[0]):
			continue
		if not has_expansion and p[0] == "plan_basement":
			continue
		camera.size = p[1]
		camera.cull_mask = p[3]
		camera.global_position = Vector3(1, p[2] if p[0] == "plan_ground" else -0.35, -3)
		camera.global_rotation = Vector3(-PI / 2.0, 0, 0)
		camera.near = 0.05
		camera.make_current()
		await _shot(dir, p[0])
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


func _shot(dir: String, shot_name: String) -> void:
	await _wait(10)
	root.get_viewport().get_texture().get_image().save_png(dir.path_join(shot_name + ".png"))
	_shots += 1


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame
