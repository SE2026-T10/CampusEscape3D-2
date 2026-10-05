extends RefCounted

## Phase 13 performance checks. Called from tests/test_scene.gd.
##   - the measured rendering optimisation stays in place: the sun keeps its
##     shadows, with 2 cascades, and the directional shadow atlas is 2048
##   - the benchmark tool's scenarios and statistics are what the docs say

const LIBRARY_SCENE := "res://scenes/level/library_graybox.tscn"
const Benchmark := preload("res://tools/benchmark.gd")

var failures: Array[String] = []


func run(_host: Node) -> Array[String]:
	_check_shadow_settings()
	_check_benchmark_tool()
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[performance] " + message)


func _check_shadow_settings() -> void:
	var level := (load(LIBRARY_SCENE) as PackedScene).instantiate()
	var sun := level.get_node_or_null("KeyLight") as DirectionalLight3D
	_expect(sun != null and sun.shadow_enabled, "The sun (KeyLight) should keep its shadows.")
	if sun:
		_expect(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
			"The sun shadow should use 2 cascades (measured: 4 cascades cost about 22% of the frame on the test machine).")
	_expect(int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size")) == 2048,
		"The directional shadow atlas should be 2048 (measured in docs/phase-13-performance.md).")
	level.free()


func _check_benchmark_tool() -> void:
	_expect(Benchmark.SCENARIOS == {"normal": 3, "several": 8, "stress": 24}, "Benchmark scenarios should be 3, 8 and 24 guards.")
	_expect(Benchmark.COLUMNS.size() == 24 and Benchmark.COLUMNS[0] == "frame_ms", "Benchmark columns changed; update the docs and analyse.py.")
	var values := PackedFloat64Array([5, 1, 4, 2, 3, 10, 6, 7, 9, 8])
	_expect(Benchmark._percentile(values, 50.0) == 5.0 and Benchmark._percentile(values, 95.0) == 10.0
		and Benchmark._percentile(values, 10.0) == 1.0, "Benchmark percentiles are wrong.")
	_expect(is_equal_approx(Benchmark._mean(values), 5.5) and Benchmark._max(values) == 10.0 and Benchmark._sum(values) == 55.0,
		"Benchmark mean / max / sum are wrong.")
	_expect(Benchmark._percentile(PackedFloat64Array(), 50.0) == 0.0, "An empty sample should give 0.")
