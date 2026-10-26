extends SceneTree
const Suite := preload("res://maps/intelligence/tests/k17_mission_tests.gd")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var failures: Array[String] = await Suite.new().run(root)
	for failure in failures:
		printerr(failure)
	print("K17 TESTS PASSED" if failures.is_empty() else "K17 TESTS FAILED")
	quit(0 if failures.is_empty() else 1)
