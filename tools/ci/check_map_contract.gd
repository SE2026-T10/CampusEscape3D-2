extends SceneTree

const ContractTests := preload("res://tests/map_hud_provider_tests.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = await ContractTests.new().run(root)
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("MAP CONTRACT PASSED")
	quit(0 if failures.is_empty() else 1)
