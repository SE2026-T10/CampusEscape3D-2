extends SceneTree

const HudTests := preload("res://maps/library/tests/expanded_hud_tests.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var probe_path := "user://vt038-hud-write-probe.cfg"
	var workspace_path := OS.get_environment("VT038_PROBE_FILE")
	var config := ConfigFile.new()
	config.set_value("probe", "value", 42)
	var user_error := config.save(probe_path)
	var workspace_error := config.save(workspace_path)
	print("user:// save: ", user_error, " ", error_string(user_error), " at ", ProjectSettings.globalize_path(probe_path))
	print("workspace save: ", workspace_error, " ", error_string(workspace_error), " at ", workspace_path)
	if user_error == OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(probe_path))
	var host := Node.new()
	root.add_child(host)
	var failures := await HudTests.new().run(host)
	for failure in failures:
		printerr("BASELINE FAIL: ", failure)
	print("Baseline ExpandedHudTests failures: ", failures.size())
	quit(0 if failures.is_empty() else 1)
