extends SceneTree

## Flaky-test review for the LevelSearch tests (assignment VT-041). Headless:
##   godot --headless --path . --script res://tools/level_search_flaky.gd
## Four hazards, each checked by repetition:
##   ORDER / SHARED STATE  the 14 test functions run in 100 random orders (fixed seeds); none may fail,
##                         and LevelCatalog.LEVELS must be identical before and after.
##   RANDOM DATA           T06's shuffle property over 300 different seeds: order must never depend on input order.
##   CONCURRENCY           60 threads call search() with the same params at once, 5 rounds: every result must
##                         equal the single-thread result.
##   TIME                  the test file must not read the clock or sleep (checked in the source text).
## Prints "FLAKY REVIEW PASSED" and exits 0 only if every check holds.

const LevelSearchTests := preload("res://tests/level_search_tests.gd")

var _problems: Array[String] = []


func _initialize() -> void:
	_check_order_and_shared_state()
	_check_random_data()
	_check_concurrency()
	_check_time()
	if _problems.is_empty():
		print("FLAKY REVIEW PASSED")
		quit(0)
	else:
		for p in _problems:
			print("  PROBLEM ", p)
		print("FLAKY REVIEW FAILED")
		quit(1)


func _test_names() -> Array:
	var names: Array = []
	for m in LevelSearchTests.new().get_method_list():
		if String(m.name).begins_with("_t") and String(m.name).substr(2, 2).is_valid_int():
			names.append(m.name)
	return names


func _check_order_and_shared_state() -> void:
	var names := _test_names()
	var catalog_hash := LevelCatalog.LEVELS.duplicate(true).hash()
	var rng := RandomNumberGenerator.new()
	var bad := 0
	for seed in 100:
		rng.seed = 1000 + seed
		var order := names.duplicate()
		for j in range(order.size() - 1, 0, -1):
			var k := rng.randi_range(0, j)
			var tmp = order[j]
			order[j] = order[k]
			order[k] = tmp
		var t := LevelSearchTests.new()
		for n in order:
			t.call(n)
		if not t.failures.is_empty():
			bad += 1
			_problems.append("order seed %d: %s" % [1000 + seed, t.failures[0]])
	if LevelCatalog.LEVELS.duplicate(true).hash() != catalog_hash:
		_problems.append("LevelCatalog.LEVELS changed during the order runs (shared state leak)")
	print("  [flaky] order/shared state: %d test functions x 100 random orders, %d orders failed, catalog unchanged: %s" % [
		names.size(), bad, LevelCatalog.LEVELS.duplicate(true).hash() == catalog_hash])


func _check_random_data() -> void:
	var base: Array = []
	for i in 12:
		base.append({"id": StringName("id%02d" % i), "title": ["Alpha", "alpha", "Beta", "BETA"][i % 4],
			"scene": "res://x%d.tscn" % i, "description": "d"})
	var reference: Array = LevelSearch.search({"page_size": 50}, base).items.map(func(x): return x.id)
	var bad := 0
	var rng := RandomNumberGenerator.new()
	for seed in 300:
		rng.seed = seed
		var shuffled := base.duplicate()
		for j in range(shuffled.size() - 1, 0, -1):
			var k := rng.randi_range(0, j)
			var tmp = shuffled[j]
			shuffled[j] = shuffled[k]
			shuffled[k] = tmp
		if LevelSearch.search({"page_size": 50}, shuffled).items.map(func(x): return x.id) != reference:
			bad += 1
	if bad > 0:
		_problems.append("%d of 300 shuffles changed the result order" % bad)
	print("  [flaky] random data: 300 shuffle seeds, %d changed the order" % bad)


func _check_concurrency() -> void:
	var catalog: Array = []
	for i in 500:
		catalog.append({"id": StringName("m%04d" % i), "title": "Map %d" % (i % 37), "scene": "res://m%d.tscn" % i, "description": "text %d" % i})
	var params := {"query": "map 1", "page": 2, "page_size": 7}
	var reference: int = LevelSearch.search(params, catalog).hash()
	var bad := 0
	for round in 5:
		var threads: Array[Thread] = []
		var results: Array = []
		results.resize(60)
		var gate := Semaphore.new()
		for t in 60:
			var th := Thread.new()
			th.start(func():
				gate.wait()
				results[t] = LevelSearch.search(params, catalog).hash())
			threads.append(th)
		for t in 60:
			gate.post()
		for th in threads:
			th.wait_to_finish()
		for r in results:
			if r != reference:
				bad += 1
	if bad > 0:
		_problems.append("%d of 300 concurrent results differed from the single-thread result" % bad)
	print("  [flaky] concurrency: 5 rounds x 60 threads, %d of 300 results differed" % bad)


func _check_time() -> void:
	var src := FileAccess.get_file_as_string("res://tests/level_search_tests.gd")
	var hits: Array[String] = []
	for word in ["Time.", "OS.delay", "create_timer", "get_ticks", "await", "randf", "randi()", "randomize"]:
		if src.contains(word):
			hits.append(word)
	if not hits.is_empty():
		_problems.append("tests/level_search_tests.gd uses time or unseeded randomness: %s" % [hits])
	print("  [flaky] time: tests/level_search_tests.gd uses none of the clock, sleep, await or unseeded random calls checked: %s" % ["ok" if hits.is_empty() else str(hits)])
