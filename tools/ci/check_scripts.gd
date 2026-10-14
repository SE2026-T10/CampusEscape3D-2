extends SceneTree

## CI check: loads every GDScript in the project and fails if any of them
## doesn't compile. Runs on its own, so a broken script can't hang the test
## runner (a test file that fails to parse would stop it from starting).
##
##   godot --headless --path . --script res://tools/ci/check_scripts.gd

func _init() -> void:
	var failed: Array[String] = []
	var checked := 0
	for path in _scripts("res://"):
		checked += 1
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			failed.append(path)
	if failed.is_empty():
		print("CHECK SCRIPTS PASSED (%d scripts)" % checked)
		quit(0)
	else:
		for path in failed:
			printerr("Script does not compile: ", path)
		quit(1)


func _scripts(folder: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		if sub.begins_with(".") or FileAccess.file_exists(folder.path_join(sub).path_join(".gdignore")):
			continue
		found.append_array(_scripts(folder.path_join(sub)))
	return found
