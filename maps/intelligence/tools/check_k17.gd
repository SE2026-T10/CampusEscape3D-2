extends SceneTree
const Suite := preload("res://maps/intelligence/tests/k17_mission_tests.gd")
const SecuritySuite := preload("res://maps/intelligence/tests/k17_security_tests.gd")
const TestModeSuite := preload("res://maps/intelligence/tests/k17_test_mode_tests.gd")
const ExpansionSuite := preload("res://maps/intelligence/tests/k17_expansion_tests.gd")
const HoldSuite := preload("res://tests/hold_interaction_tests.gd")
const Utils := preload("res://tests/test_utils.gd")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var failures: Array[String] = await Suite.new().run(root)
	failures.append_array(await HoldSuite.new().run(root))
	failures.append_array(await SecuritySuite.new().run(root))
	failures.append_array(await TestModeSuite.new().run(root))
	failures.append_array(await ExpansionSuite.new().run(root))
	await Utils.settle_async_audio(self)
	for failure in failures:
		printerr(failure)
	print("K17 TESTS PASSED" if failures.is_empty() else "K17 TESTS FAILED")
	quit(0 if failures.is_empty() else 1)
