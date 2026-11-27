extends SceneTree

## Run this external script against the exported PCK, not the source project:
## From an empty directory, so missing pack files cannot fall back to source:
## godot --headless --main-pack /absolute/path/game.pck --script /absolute/path/to/check_pack.gd
const Catalog := preload("res://shared/scripts/game/level_catalog.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	# Check the mounted pack's paths. Asset metadata may name tools that are not packed.
	var development_dirs: Array[String] = ["res://tests", "res://tools", "res://ci-logs",
		"res://maps/isg_museum/scenes/previews"]
	for map_dir in DirAccess.get_directories_at("res://maps"):
		development_dirs.append("res://maps/%s/tests" % map_dir)
		development_dirs.append("res://maps/%s/tools" % map_dir)
	for directory in development_dirs:
		if DirAccess.dir_exists_absolute(directory):
			failures.append("Development-only directory in exported pack: " + directory)
	var preview_script := "res://maps/isg_museum/scripts/courtyard_palette_preview.gd"
	if FileAccess.file_exists(preview_script) or FileAccess.file_exists(preview_script + ".remap"):
		failures.append("Development-only file in exported pack: " + preview_script)
	var scenes: Array[String] = [ProjectSettings.get_setting("application/run/main_scene")]
	for entry in Catalog.LEVELS:
		scenes.append(entry.scene)
		if entry.get("test_scene", "") != "":
			scenes.append(entry.test_scene)
	for scene_path in scenes:
		var packed := load(scene_path) as PackedScene
		if packed == null:
			failures.append("Exported scene missing: " + scene_path)
			continue
		var scene := packed.instantiate()
		root.add_child(scene)
		current_scene = scene
		for i in 30:
			await physics_frame
		print("  [pack] loaded ", scene_path)
		current_scene = null
		scene.queue_free()
		packed = null
		for i in 30:
			await process_frame
	# Accelerated runs may outpace the audio server's asynchronous release of
	# stopped WAV playback. Allow its real-time worker to finish before exit.
	for i in 4:
		OS.delay_msec(50)
		await process_frame
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("PACK CHECK PASSED (%d scenes; development files excluded)" % scenes.size())
	quit(0 if failures.is_empty() else 1)
