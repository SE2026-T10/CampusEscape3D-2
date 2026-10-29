extends SceneTree
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var failures: Array[String]=await preload("res://maps/intelligence/tests/k17_navigation_tests.gd").new().run(root)
	await preload("res://tests/test_utils.gd").settle_async_audio(self)
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
