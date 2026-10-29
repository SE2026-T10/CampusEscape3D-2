extends SceneTree
const Suite := preload("res://maps/intelligence/tests/k17_sabotage_tests.gd")
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var failures: Array[String] = await Suite.new().run(root)
	await preload("res://tests/test_utils.gd").settle_async_audio(self)
	for failure in failures: printerr(failure)
	print("K17 SABOTAGE PASSED" if failures.is_empty() else "K17 SABOTAGE FAILED")
	quit(0 if failures.is_empty() else 1)
