extends SceneTree

## Renders the library from fixed viewpoints, so every level version can be
## compared shot for shot (before/after):
##
##   godot --path . --resolution 1280x720 --script res://tools/capture_views.gd -- --out=docs/level/v1/views
##
## Needs a display (or a virtual one); headless runs can't render. The HUD
## layers and the guards are hidden, so shots compare the level itself.

const LEVEL := "res://scenes/level/library_graybox.tscn"
## name: [camera position, look-at point]
const VIEWS := {
	"01_entrance": [Vector3(0, 1.6, 20.8), Vector3(0, 1.3, 8)],
	"02_main_room": [Vector3(0, 1.6, 12.8), Vector3(-7, 0.8, -1)],
	"03_reading_area": [Vector3(2.5, 1.6, 12.5), Vector3(12, 0.8, 0)],
	"04_hallway_west": [Vector3(-10.5, 1.6, -6.5), Vector3(-10.5, 1.2, -16)],
	"05_restricted_stacks": [Vector3(-3.5, 1.6, -15), Vector3(-15, 0.6, -25)],
	"06_back_corridor": [Vector3(-0.5, 1.6, -22.5), Vector3(17, 1.2, -22.5)],
	"07_hallway_east": [Vector3(22.5, 1.6, 4.2), Vector3(22.5, 1.2, -17)],
	"08_exit_area": [Vector3(20.5, 1.6, -19), Vector3(27.8, 1.2, -23)],
}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "res://docs/level/views"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = "res://" + a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var level: Node3D = (load(LEVEL) as PackedScene).instantiate()
	root.add_child(level)
	for node in level.get_children():
		if node is CanvasLayer:
			node.visible = false
	for guard in level.find_children("*", "Guard", true, false):
		guard.visible = false
	for i in 30:
		await physics_frame
	paused = true
	var camera := Camera3D.new()
	camera.fov = 75.0
	level.add_child(camera)
	for name in VIEWS:
		var view: Array = VIEWS[name]
		camera.global_position = view[0]
		camera.look_at(view[1], Vector3.UP)
		camera.current = true
		await _save(out.path_join(name + ".png"))
	var top := level.get_node_or_null("PreviewCamera") as Camera3D
	if top:
		# Ceilings (render layer 2) are hidden from the top-down camera.
		top.cull_mask = top.cull_mask & ~2
		top.current = true
		await _save(out.path_join("00_topdown.png"))
	quit(0)


func _save(path: String) -> void:
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("view → %s" % path)
