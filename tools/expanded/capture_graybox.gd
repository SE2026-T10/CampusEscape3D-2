extends SceneTree

## Development tool: screenshots of the built Expanded Library graybox.
##   - top_ground.png / top_upper.png: orthographic views from above of each
##     floor (the upper floor is hidden for the ground view)
##   - navmesh_ground.png / navmesh_upper.png: the same with that floor's baked
##     navmesh drawn in cyan (ramps appear on both)
##   - views/*.png: eye-height views at representative spots
##
##   godot --path . --resolution 1600x1000 --script res://tools/expanded/capture_graybox.gd -- --out=docs/expanded/v0
##
## Needs a display (xvfb-run works; software rendering is fine).

const Layout := preload("res://tools/expanded/expanded_layout.gd")
const SCENE := "res://scenes/level/expanded_library.tscn"
const EYE := 1.65
const U := Layout.UPPER_Y

## [name, camera position, look-at point]
const VIEWS := [
	["01_porch_main_entrance", Vector3(0, EYE, 33.5), Vector3(0, 1.6, 18)],
	["02_lobby_s1_main_stair", Vector3(7, EYE, 26), Vector3(-10, 2.6, 13)],
	["03_main_stacks_aisle", Vector3(-26.5, EYE, 8.5), Vector3(-26.5, 1.4, -20)],
	["04_browsing_hall_s3", Vector3(-16, EYE, 26), Vector3(-34, 2.4, 13)],
	["05_reading_hall", Vector3(9, EYE, 8.5), Vector3(-6, 1.0, -12)],
	["06_study_room_3", Vector3(3, EYE, -15), Vector3(3, 0.8, -27)],
	["07_service_corridor", Vector3(14.5, EYE, 26.5), Vector3(14.5, 1.5, -20)],
	["08_storage_s2_staff_stair", Vector3(22, EYE, 10.5), Vector3(34.3, 2.6, -3)],
	["09_loading_dock_exit", Vector3(19, EYE, 19), Vector3(36, 1.4, 24)],
	["10_upper_stacks_from_s1", Vector3(-10.35, U + EYE, 8.5), Vector3(-22, U + 1.0, -12)],
	["11_balcony_over_lobby", Vector3(2, U + EYE, 8.6), Vector3(0, 0.0, 22)],
	["12_staff_corridor_gates", Vector3(-4.5, U + EYE, -11), Vector3(12, U + 1.2, -11)],
	["13_office_2_o2_card", Vector3(3, U + EYE, -15), Vector3(3, U + 0.6, -24)],
	["14_archive_hall", Vector3(16.5, U + EYE, -7), Vector3(27, U + 0.8, -24)],
	["15_vault_o3_manuscript", Vector3(29, U + EYE, -19.5), Vector3(33, U + 0.6, -26)],
	["16_s2_landing_down", Vector3(34.35, U + EYE, -7.0), Vector3(34.35, 0.5, 8)],
	["17_archive_back_gate_g3", Vector3(24, U + EYE, -9), Vector3(31, U + 1.2, -9)],
	["18_loading_dock_exit_door", Vector3(31, EYE, 24), Vector3(36, 1.3, 24)],
]

var _level: Node3D
var _camera: Camera3D
var _out := ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_out = "docs/expanded/" + Layout.VERSION
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	if DisplayServer.get_name() == "headless":
		push_error("capture_graybox needs a display (run without --headless, e.g. under xvfb-run).")
		quit(1)
		return
	var dir := ProjectSettings.globalize_path("res://" + _out)
	DirAccess.make_dir_recursive_absolute(dir.path_join("views"))
	_level = (load(SCENE) as PackedScene).instantiate()
	# Only the geometry and markers: no game flow, menus or player input.
	for n in ["GameFlow", "GameMenus", "ObjectiveHud"]:
		_level.get_node(n).free()
	(_level.get_node("Player") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(_level)
	_camera = Camera3D.new()
	_camera.far = 300.0
	_level.add_child(_camera)
	_camera.make_current()
	await _wait(10)
	(_level.get_node("Layout") as Node3D).visible = true   # design markers (hidden in play, F3)

	var upper := _level.get_node("NavigationRegion3D/Upper") as Node3D
	var upper_labels: Array[Node3D] = []
	for n in _all_nodes(_level.get_node("Layout")) + _all_nodes(_level.get_node("Gameplay")):
		if n is Node3D and n.global_position.y > U - 0.5 and (n is Label3D or n is MeshInstance3D):
			upper_labels.append(n)
	# Top views.
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 74.0
	_camera.global_transform = Transform3D(Basis.from_euler(Vector3(-PI / 2, 0, 0)), Vector3(0, 40, 3))
	upper.visible = false
	for n in upper_labels:
		n.visible = false
	await _shot(dir.path_join("top_ground.png"))
	var overlay := _navmesh_overlay(false)
	await _shot(dir.path_join("navmesh_ground.png"))
	overlay.queue_free()
	upper.visible = true
	for n in upper_labels:
		n.visible = true
	await _shot(dir.path_join("top_upper.png"))
	overlay = _navmesh_overlay(true)
	await _shot(dir.path_join("navmesh_upper.png"))
	overlay.queue_free()
	# Eye-height views.
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 75.0
	for v in VIEWS:
		_camera.global_position = v[1]
		_camera.look_at(v[2], Vector3.UP)
		await _shot(dir.path_join("views/%s.png" % v[0]))
	print("Captured %d views → %s" % [VIEWS.size() + 4, dir])
	quit(0)


## Draws the baked navmesh polygons of one floor (ramps on both) in translucent cyan.
func _navmesh_overlay(upper: bool) -> MeshInstance3D:
	var nav: NavigationMesh = (_level.get_node("NavigationRegion3D") as NavigationRegion3D).navigation_mesh
	var vertices := nav.get_vertices()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in nav.get_polygon_count():
		var poly := nav.get_polygon(i)
		var c := Vector3.ZERO
		for k in poly:
			c += vertices[k]
		c /= poly.size()
		if (upper and c.y < 0.6) or (not upper and c.y > U - 0.6):
			continue   # the other floor (ramp polygons, in between, are drawn on both)
		for k in range(1, poly.size() - 1):
			for idx in [poly[0], poly[k], poly[k + 1]]:
				mesh.surface_add_vertex(vertices[idx] + Vector3(0, 0.08, 0))
	mesh.surface_end()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.0, 0.95, 1.0, 0.6)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_level.add_child(node)
	return node


func _shot(path: String) -> void:
	await _wait(6)
	root.get_viewport().get_texture().get_image().save_png(path)


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _all_nodes(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(_all_nodes(child))
	return out
