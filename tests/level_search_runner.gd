extends SceneTree

## Runs only the LevelSearch tests (a few seconds), headless:
##   godot --headless --path . --script res://tests/level_search_runner.gd
## Exits 0 and prints "LEVEL SEARCH TESTS PASSED" when every check passes, 1 otherwise.
## The same tests also run inside the full suite (tests/test_scene.tscn).

const LevelSearchTests := preload("res://tests/level_search_tests.gd")


func _initialize() -> void:
	var failures := LevelSearchTests.new().run(null)
	if failures.is_empty():
		print("LEVEL SEARCH TESTS PASSED")
		quit(0)
	else:
		for f in failures:
			print("  FAIL ", f)
		print("LEVEL SEARCH TESTS FAILED (%d failures)" % failures.size())
		quit(1)
