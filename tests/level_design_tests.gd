extends RefCounted

## Phase 11 level-design tests: the final library keeps the structure and
## readability the design relies on. Called from tests/test_scene.gd.
##   - required spaces exist (entrance, reading area, bookshelves, corridors,
##     objective area, alternative route, checkpoints, escape route)
##   - two independent routes to the card (west via Hallway West; east via
##     Hallway East and the back corridor) and two ways from the card to the exit
##   - every carrel is reachable, and the study alcove carrel is on the east route
##   - readability: room signs, red RESTRICTED signs on both objective entrances,
##     EXIT signs along both escape routes, a light on the card
##   - decoration never changes gameplay: books, chairs, signs, lights and
##     ceilings have no collision; ceilings sit on render layer 2
##   - books are generated the same way every time

const LIBRARY_SCENE := "res://scenes/level/library_graybox.tscn"
const TestUtils := preload("res://tests/test_utils.gd")
const HALLWAY_WEST := Rect2(-12, -14, 3, 8)
const HALLWAY_EAST := Rect2(21, -18, 3, 20)

var failures: Array[String] = []
var _host: Node
var _level: Node3D
var _map: RID


func run(host: Node) -> Array[String]:
	_host = host
	_level = (load(LIBRARY_SCENE) as PackedScene).instantiate()
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, _level, Vector3(0, 0, 18)), "Library navigation never became ready.")
	_map = _level.get_world_3d().navigation_map
	_check_spaces()
	_check_routes()
	_check_readability()
	_check_decoration_has_no_gameplay_effect()
	_check_books_are_deterministic()
	_level.queue_free()
	await _host.get_tree().physics_frame
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[level] " + message)


func _check_spaces() -> void:
	var areas := _level.get_node("NavigationRegion3D/Areas")
	for name in ["Entrance", "MainRoom", "ReadingArea", "MainStacks", "HallwayWest", "RestrictedStacks", "BackCorridor", "HallwayEast", "ExitArea"]:
		_expect(areas.has_node(name), "Missing space '%s'." % name)
	var shelves := 0
	for body in _level.find_children("Shelf*", "StaticBody3D", true, false):
		shelves += 1
	_expect(shelves >= 7, "Expected at least 7 tall bookcases, found %d." % shelves)
	_expect(_level.find_children("*", "Checkpoint", true, false).size() >= 2, "The level needs its checkpoints.")
	_expect(_level.find_children("*", "HidingSpot", true, false).size() >= 5, "The level needs its 5 carrels.")
	_expect(_level.get_node_or_null("Gameplay/AccessCard") != null and _level.get_node_or_null("Gameplay/ExitDoor") != null,
		"The objective (card) and the escape (exit door) must exist.")


func _check_routes() -> void:
	var spawn: Vector3 = _level.get_node("Player").global_position
	var card := (_level.get_node("Gameplay/AccessCard") as Node3D).global_position + Vector3(1.2, -0.9, 0)
	var door := (_level.get_node("Gameplay/ExitDoor") as Node3D).global_position + Vector3(-1.2, -1.2, 0)
	var west := _path([spawn, Vector3(-10.5, 0, -10), card])
	var east := _path([spawn, Vector3(22.5, 0, -5), Vector3(8, 0, -22.5), card])
	_expect(_reaches(west, card) and _passes(west, HALLWAY_WEST), "The west route (Hallway West) must reach the card.")
	_expect(_reaches(east, card) and not _passes(east, HALLWAY_WEST) and _passes(east, HALLWAY_EAST),
		"The east route must reach the card without using Hallway West.")
	var out_back := _path([card, Vector3(8, 0, -22.5), door])
	var out_round := _path([card, Vector3(-10.5, 0, -10), Vector3(22.5, 0, -5), door])
	_expect(_reaches(out_back, door) and not _passes(out_back, HALLWAY_EAST), "The back corridor must lead from the card to the exit.")
	_expect(_reaches(out_round, door) and _passes(out_round, HALLWAY_EAST), "The long way round (main room, Hallway East) must also reach the exit.")
	for spot in _level.find_children("*", "HidingSpot", true, false):
		var at: Vector3 = spot.global_position
		var closest := NavigationServer3D.map_get_closest_point(_map, Vector3(at.x, 0, at.z))
		_expect(Vector2(closest.x - at.x, closest.z - at.z).length() < 2.0, "The carrel %s must be next to walkable floor." % spot.get_parent().name)
	var alcove := _level.get_node_or_null("NavigationRegion3D/Areas/HallwayEast/CarrelHallway") as Node3D
	_expect(alcove != null, "The study alcove carrel on the east route is missing.")
	print("  [level] routes to the card: west %.0f m, east %.0f m; card to exit: back corridor %.0f m, long way %.0f m" % [
		_length(west), _length(east), _length(out_back), _length(out_round)])


func _check_readability() -> void:
	var signs := _level.get_node_or_null("Dressing/Signs")
	_expect(signs != null, "The level needs its signs.")
	if signs == null:
		return
	var texts: Array[String] = []
	for label in signs.find_children("*", "Label3D", true, false):
		texts.append(label.text)
	_expect(texts.count("RESTRICTED · STAFF ONLY") >= 2, "Both entrances to the objective room need a RESTRICTED sign.")
	var exits := texts.filter(func(t): return t.begins_with("EXIT")).size()
	_expect(exits >= 5, "The escape routes need EXIT signs (found %d)." % exits)
	for name in ["MAIN LIBRARY", "READING ROOM", "ARCHIVE", "HALLWAY EAST"]:
		_expect(name in texts, "Missing room sign '%s'." % name)
	_expect(_level.get_node_or_null("Dressing/Landmarks/CardSpotlight") is SpotLight3D, "The access card needs its spotlight.")
	_expect(_level.get_node_or_null("Dressing/Landmarks/Clock") != null, "The clock landmark is missing.")
	for area in _level.get_node("NavigationRegion3D/Areas").get_children():
		var label := area.get_node_or_null("Label") as Label3D
		if label:
			_expect(not label.visible, "The floating debug label in %s should be hidden (signs replace it)." % area.name)


func _check_decoration_has_no_gameplay_effect() -> void:
	var dressing := _level.get_node("Dressing")
	var bodies := dressing.find_children("*", "CollisionObject3D", true, false)
	_expect(bodies.is_empty(), "Decoration must not collide (found %s)." % [bodies.map(func(b): return b.name)])
	var ceilings := dressing.get_node_or_null("Ceilings")
	_expect(ceilings != null and ceilings.get_child_count() >= 9, "Every room needs a ceiling.")
	if ceilings:
		for c in ceilings.get_children():
			_expect((c as VisualInstance3D).layers == 2, "Ceiling %s must be on render layer 2 (hidden from the top-down camera)." % c.name)
	var books := _level.find_children("Books", "ShelfBooks", true, false)
	_expect(books.size() >= 10, "Every bookcase should have books (found %d)." % books.size())
	for b in books:
		_expect(b.find_children("*", "CollisionObject3D", true, false).is_empty(), "Books must not collide.")
	var plants := _level.find_children("Plant*", "StaticBody3D", true, false)
	_expect(plants.size() >= 5, "Expected the potted plants (found %d)." % plants.size())


func _check_books_are_deterministic() -> void:
	var a := ShelfBooks.new()
	a.size = Vector3(0.6, 2.2, 4.0)
	a.book_seed = 7
	var b := ShelfBooks.new()
	b.size = Vector3(0.6, 2.2, 4.0)
	b.book_seed = 7
	var c := ShelfBooks.new()
	c.size = Vector3(0.6, 2.2, 4.0)
	c.book_seed = 8
	# The layout is checked directly (a headless run can't read MultiMesh data back).
	var la := a.compute_layout()
	var lb := b.compute_layout()
	var lc := c.compute_layout()
	_expect(la[0] == lb[0] and la[1] == lb[1] and la[0].size() > 100, "The same seed must give the same books (%d books)." % la[0].size())
	_expect(la[0] != lc[0], "A different seed should give different books.")
	_expect(a.build_multimesh().instance_count == la[0].size(), "The MultiMesh should hold every book and board.")
	# Every book stays inside the bookcase's footprint plus a 3 cm lip.
	var outside := 0
	for t: Transform3D in la[0]:
		if absf(t.origin.x) + t.basis.get_scale().x / 2.0 > 0.33 or absf(t.origin.z) > 2.0 or absf(t.origin.y) > 1.1:
			outside += 1
	_expect(outside == 0, "%d books stick out of their bookcase." % outside)
	a.free()
	b.free()
	c.free()


func _path(points: Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	for i in range(1, points.size()):
		result.append_array(NavigationServer3D.map_get_path(_map, points[i - 1], points[i], true))
	return result


func _reaches(path: PackedVector3Array, target: Vector3) -> bool:
	return not path.is_empty() and Vector2(path[-1].x - target.x, path[-1].z - target.z).length() < 0.8


func _passes(path: PackedVector3Array, rect: Rect2) -> bool:
	for i in range(1, path.size()):
		for k in 5:
			var p := path[i - 1].lerp(path[i], k / 5.0)
			if rect.has_point(Vector2(p.x, p.z)):
				return true
	return false


func _length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total
