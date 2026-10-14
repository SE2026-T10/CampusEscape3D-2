extends RefCounted

## Phase 14 QA regression tests: one check per bug the QA pass confirmed and
## fixed, so it can't come back. Called from tests/test_scene.gd.
##   QA-1  The win screen's "ESCAPED" title never popped in: it sits in a
##         container, which resets a child's scale, and its pivot used the
##         label's size from before the panel was laid out.
##   QA-2  The benchmark started some extra guards on exactly the same spot as
##         the level's own guards (13+ guards), so they blocked each other.

const LIBRARY_SCENE := "res://scenes/level/library_graybox.tscn"
const TestUtils := preload("res://tests/test_utils.gd")

var failures: Array[String] = []
var _host: Node


func run(host: Node) -> Array[String]:
	_host = host
	await _check_win_title_pops()
	_check_benchmark_start_slots()
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[qa-regression] " + message)


func _check_win_title_pops() -> void:
	var level := (load(LIBRARY_SCENE) as PackedScene).instantiate() as Node3D
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, level, Vector3(0, 0, 18)), "Library navigation never became ready.")
	var menus := level.get_node("GameMenus") as GameMenus
	var flow := GameFlow.find(level)
	flow.change_scene = func(_p: String): pass
	var objectives := ObjectiveManager.find(level)
	for id in objectives.get_ids():
		objectives.complete(id)
	await _host.get_tree().create_timer(0.12).timeout
	var title := menus.win_title
	_expect(flow.state == GameStateMachine.State.WIN and menus.win_panel.visible, "Completing every objective should show the win screen.")
	_expect(title.scale.x > 1.05, "QA-1: the ESCAPED title should be popping in shortly after the win (scale %.2f)." % title.scale.x)
	_expect(title.pivot_offset.distance_to(title.size / 2.0) < 1.0,
		"QA-1: the title should pop from its centre (pivot %s, size %s)." % [title.pivot_offset, title.size])
	await _host.get_tree().create_timer(0.7).timeout
	_expect(is_equal_approx(title.scale.x, 1.0), "QA-1: the title should settle at full size (scale %.2f)." % title.scale.x)
	var holder := title.get_parent() as Control
	_expect(holder.size.y >= title.get_combined_minimum_size().y - 0.5,
		"QA-1: the title's holder must be as tall as the title, or the title overlaps the line below (%.0f < %.0f)." % [
		holder.size.y, title.get_combined_minimum_size().y])
	level.queue_free()
	await _host.get_tree().create_timer(0.3).timeout


func _check_benchmark_start_slots() -> void:
	# Same arithmetic as tools/benchmark.gd _add_extra_guards(): 3 routes of 4 points.
	for npcs: int in [8, 24, 48]:
		var used := {}
		var clash := false
		for i in npcs - 3:
			var route: int = i % 3
			var lap: int = i / 3
			var slot: int = lap % (4 * 4 - 1) + 1
			var key := Vector3i(route, (slot / 4) % 4, slot % 4)
			if used.has(key) or key == Vector3i(route, 0, 0):
				clash = true
			used[key] = true
		_expect(not clash, "QA-2: with %d guards, two benchmark guards (or a level guard) would start on the same spot." % npcs)
	var source := FileAccess.get_file_as_string("res://tools/benchmark.gd")
	_expect(source.contains("var slots := count * 4 - 1") and source.contains("var slot := lap % slots + 1"),
		"QA-2: tools/benchmark.gd should use the start-slot scheme this test checks.")
