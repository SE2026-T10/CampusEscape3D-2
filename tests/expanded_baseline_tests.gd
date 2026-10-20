extends RefCounted

## Expanded Library expansion baseline tests (expansion Phase 1). Called from
## tests/test_scene.gd.
##
##   A. Integration point: the Expanded Library instances the expansion
##      sub-scene (scenes/level/expanded_library_expansion.tscn) exactly once,
##      as "Expansion" right after "Gameplay", with an identity transform; the
##      tutorial does not.
##   B. The existing level is intact: outside "Expansion", the collision
##      geometry, the batched decoration (door frames included), the guards
##      and patrol points, and the mission set-up match the baseline: commit
##      7d73492 (docs/expanded/expansion/phase-1-baseline.md) plus the three
##      doorways approved in expansion Phase 2 (phase-2-layout.md). New
##      content goes into the sub-scene; a change here means the existing map
##      was edited or rebuilt (tools/expanded/build_expanded_graybox.gd is
##      frozen: a rebuild reverts the door-frame fix and fails this check).
##   C. The two maps stay independent: loaded alternately (tutorial, expanded,
##      tutorial, expanded), each has its own systems once, its own guards and
##      objectives, and leaves nothing behind.

const TestUtils := preload("res://tests/test_utils.gd")
const EXPANDED := "res://scenes/level/expanded_library.tscn"
const TUTORIAL := "res://scenes/level/library_graybox.tscn"
const EXPANSION_SCENE := "res://scenes/level/expanded_library_expansion.tscn"

## Baseline digests (SHA-256 of the canonical listings built below) of the
## Expanded Library outside "Expansion". Update them only for an approved
## change to the existing map, and record why in docs/expanded/expansion/.
##   Phase 1 (commit 7d73492, layout v4 with the door-frame fix):
##     geometry 50ea7f0f…a3230f86, decoration f710f056…abe446b3, 263 collision
##     objects, navmesh 898 polygons.
##   Phase 2 (approved): three doorways cut (B west wall z -9, D east wall
##     z -23, B/C wall z -21): 3 wall bodies shortened, 3 wall pieces and 3
##     headers added, 12 decoration boxes split around the openings; the
##     navmesh rebaked with the expansion's geometry. Guards, routes and the
##     mission set-up unchanged (same actors digest).
##   Phase 5 (approved): one guard added, GuardBasement with its route
##     P9_Basement (security_x4.py). The digests and counts above are checked
##     with those two nodes left out, so every existing node is still proven
##     unchanged; the additions are checked on their own (PHASE5_ADDED).
##   Phase 9 follow-up (approved, fixes_x7.gd): two ground-floor batches split
##     so no piece is reached by more than 8 lights (Batch_1_0 into 5, Batch_5_2
##     into 9: the same boxes, shared out; batched nodes 295 → 307, decoration
##     digest updated); render layers of four upper-floor props and the Staff
##     Offices respawn point (not in the digests); the navmesh rebaked with the
##     expansion's tunnel niche and balcony nook (1020 → 1031 polygons).
const BASELINE_GEOMETRY_SHA := "3d161e931fe655f4f5c8dbe035674ae2a8dcad7e5688dd83feffaf3a7379eb12"
const BASELINE_DECORATION_SHA := "553bfc8219042a8aa93c88d12f81a6a5b481e9c939e4d7a8b0a7667528e83da3"
const BASELINE_ACTORS_SHA := "5b21b05f6a85f8092db260a4459314cf7d3fdd9acc10a4d430530fdd5c9ea305"
const BASELINE_COUNTS := {"collision_objects": 269, "collision_shapes": 269, "batched_nodes": 307,
	"guards": 6, "patrol_points": 41, "hiding_spots": 13, "access_doors": 4, "checkpoints": 3, "lights": 90}
## Expansion Phase 4 (approved): the mission became an objective graph (mission_x3.py).
## Before: [enter_library, take_card, take_manuscript, unlock_shortcut, escape].
const BASELINE_OBJECTIVES := [&"enter_library", &"take_card", &"find_toolkit", &"open_panel", &"restore_power", &"open_vault",
	&"take_manuscript", &"escape", &"unlock_shortcut", &"drain_culvert", &"security_locker"]
## Expansion Phase 5 (approved): the nodes added to the existing map, and what they add.
const PHASE5_ADDED := [^"Guards/GuardBasement", ^"Guards/P9_Basement"]
const PHASE5_ADDED_COUNTS := {"guards": 1, "patrol_points": 5}
const BASELINE_NAVMESH := "res://scenes/level/expanded_library_navmesh.tres"
const BASELINE_NAV_POLYGONS := 1031

const SYSTEM_GROUPS := ["game_flow", "stealth_director", "noise_system", "audio_director", "player",
	"objective_manager", "checkpoint_manager"]
const NAV_PROBE := {EXPANDED: Vector3(0, 0.05, 32), TUTORIAL: Vector3(0, 0, 18)}

var failures: Array[String] = []
var _host: Node


func run(host: Node) -> Array[String]:
	_host = host
	_check_integration_point()
	_check_existing_level()
	await _check_alternating_loads()
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[expansion] " + message)


# --- A. Integration point ----------------------------------------------------------------------

func _check_integration_point() -> void:
	var expansion_root := (load(EXPANSION_SCENE) as PackedScene).instantiate()
	_expect(expansion_root is Node3D and expansion_root.name == &"Expansion", "The expansion sub-scene's root must be a Node3D named Expansion.")
	_expect((expansion_root as Node3D).transform == Transform3D.IDENTITY, "The expansion root must keep an identity transform (content is placed in level coordinates).")
	expansion_root.free()

	var level := (load(EXPANDED) as PackedScene).instantiate()
	var instances := _instances_of(level, EXPANSION_SCENE)
	_expect(instances.size() == 1, "The Expanded Library must instance the expansion sub-scene exactly once (found %d)." % instances.size())
	var node := level.get_node_or_null("Expansion")
	_expect(node != null and node.scene_file_path == EXPANSION_SCENE, "The Expanded Library needs the sub-scene as its child \"Expansion\".")
	if node:
		var gameplay := level.get_node("Gameplay")
		_expect(node.get_index() == gameplay.get_index() + 1, "\"Expansion\" must come right after \"Gameplay\".")
		_expect((node as Node3D).transform == Transform3D.IDENTITY, "\"Expansion\" must not be moved in the level.")
		print("  [expansion] integration point: Expansion (%s) after Gameplay, %d child node(s)" % [EXPANSION_SCENE.get_file(), node.get_child_count()])
	level.free()

	var tutorial := (load(TUTORIAL) as PackedScene).instantiate()
	_expect(_instances_of(tutorial, EXPANSION_SCENE).is_empty() and not tutorial.has_node("Expansion"),
		"The tutorial must not contain the Expanded Library's expansion.")
	tutorial.free()


func _instances_of(root: Node, path: String) -> Array[Node]:
	var found: Array[Node] = []
	for n in [root] + root.find_children("*", "", true, false):
		if n.scene_file_path == path:
			found.append(n)
	return found


# --- B. The existing level is intact -----------------------------------------------------------

func _check_existing_level() -> void:
	var level := (load(EXPANDED) as PackedScene).instantiate()
	var d := digests(level, PHASE5_ADDED)
	_expect(d.geometry == BASELINE_GEOMETRY_SHA, "Collision geometry outside Expansion differs from the baseline (digest %s)." % d.geometry)
	_expect(d.decoration == BASELINE_DECORATION_SHA, "Batched decoration (door frames, trims, furniture dressing) outside Expansion differs from the baseline (digest %s)." % d.decoration)
	_expect(d.actors == BASELINE_ACTORS_SHA, "Guards, patrol routes or mission nodes outside Expansion differ from the baseline (digest %s)." % d.actors)
	for key in BASELINE_COUNTS:
		_expect(d.counts.get(key, -1) == BASELINE_COUNTS[key], "Baseline count '%s' is %s, expected %s." % [key, d.counts.get(key), BASELINE_COUNTS[key]])
	var all := digests(level)
	for key in BASELINE_COUNTS:
		var expected: int = BASELINE_COUNTS[key] + PHASE5_ADDED_COUNTS.get(key, 0)
		if key in ["collision_objects", "collision_shapes"]:
			continue   # the guard's body and shape are checked below
		_expect(all.counts.get(key, -1) == expected, "With the Phase 5 additions, count '%s' is %s, expected %s." % [key, all.counts.get(key), expected])
	var basement: Node = level.get_node_or_null("Guards/GuardBasement")
	_expect(basement is Guard and basement.patrol_route == level.get_node_or_null("Guards/P9_Basement"), "Phase 5: GuardBasement should patrol P9_Basement.")
	var objectives := level.get_node("Gameplay/ObjectiveManager")
	var ids: Array = objectives.objectives.map(func(o): return StringName(o.id))
	_expect(ids == BASELINE_OBJECTIVES, "The mission's objectives changed: %s." % [ids])
	var region := level.get_node("NavigationRegion3D") as NavigationRegion3D
	_expect(region.navigation_mesh and region.navigation_mesh.resource_path == BASELINE_NAVMESH
		and region.navigation_mesh.get_polygon_count() == BASELINE_NAV_POLYGONS,
		"The navmesh must stay %s with %d polygons." % [BASELINE_NAVMESH, BASELINE_NAV_POLYGONS])
	print("  [expansion] existing level matches the baseline (7d73492 + the 3 approved Phase 2 doorways): %d collision objects, %d shapes, %d batched decoration nodes, %d lights, 6 guards, 41 patrol points (+ the Phase 5 basement guard and its 5 points), 13 hiding spots, 4 access doors, 3 checkpoints, %d objectives (Phase 4 graph), navmesh %d polygons" % [
		d.counts.collision_objects, d.counts.collision_shapes, d.counts.batched_nodes, d.counts.lights, BASELINE_OBJECTIVES.size(), BASELINE_NAV_POLYGONS])
	level.free()


## Canonical listings of the level outside "Expansion", and their SHA-256.
## Public so the baseline can be recomputed (see the phase-1 baseline doc).
## `exclude`: node paths (relative to the level) left out with everything under them.
func digests(level: Node, exclude: Array = []) -> Dictionary:
	var geometry: PackedStringArray = []
	var decoration: PackedStringArray = []
	var actors: PackedStringArray = []
	var counts := {"collision_objects": 0, "collision_shapes": 0, "batched_nodes": 0, "guards": 0,
		"patrol_points": 0, "hiding_spots": 0, "access_doors": 0, "checkpoints": 0, "lights": 0}
	var expansion := level.get_node_or_null("Expansion")
	for n: Node in level.find_children("*", "", true, false):
		if expansion and (n == expansion or expansion.is_ancestor_of(n)):
			continue
		var path := String(level.get_path_to(n))
		if exclude.any(func(e): return path == String(e) or path.begins_with(String(e) + "/")):
			continue
		if n is CollisionObject3D:
			var c := n as CollisionObject3D
			counts.collision_objects += 1
			geometry.append("body %s %s %d %d %s" % [path, c.get_class(), c.collision_layer, c.collision_mask, _xf(_global(level, c))])
		elif n is CollisionShape3D:
			var s := n as CollisionShape3D
			counts.collision_shapes += 1
			geometry.append("shape %s %s %s %s" % [path, _xf(s.transform), _shape(s.shape), s.disabled])
		if n is Light3D:
			counts.lights += 1
			decoration.append("light %s %s %s" % [path, n.get_class(), _xf(_global(level, n))])
		if n.get("boxes") is PackedFloat32Array:
			counts.batched_nodes += 1
			var values: PackedStringArray = []
			for x in (n.get("boxes") as PackedFloat32Array):
				values.append(_f(x))
			decoration.append("boxes %s %s %s" % [path, _xf(_global(level, n)), ",".join(values)])
		if n is Guard:
			counts.guards += 1
			var route: Node = n.get("patrol_route")
			actors.append("guard %s %s route=%s chase=%s" % [path, _xf(_global(level, n)), level.get_path_to(route) if route else "-", _f(n.get("chase_speed"))])
		if n is HidingSpot:
			counts.hiding_spots += 1
		if n is AccessDoor:
			counts.access_doors += 1
			actors.append("door %s mode=%d key=%s completes=%s from=%s" % [path, n.mode, n.key_objective_id, n.complete_objective_id, _v(n.open_from)])
		if n is Checkpoint:
			counts.checkpoints += 1
			actors.append("checkpoint %s %s %s" % [path, n.checkpoint_name, _xf(_global(level, n))])
		if n.get_script() and String((n.get_script() as Script).resource_path).ends_with("patrol_point.gd"):
			counts.patrol_points += 1
			actors.append("point %s %s wait=%s" % [path, _v((n as Node3D).position), _f(n.get("wait_time"))])
	geometry.sort()
	decoration.sort()
	actors.sort()
	return {"geometry": "\n".join(geometry).sha256_text(), "decoration": "\n".join(decoration).sha256_text(),
		"actors": "\n".join(actors).sha256_text(), "counts": counts,
		"listings": {"geometry": geometry, "decoration": decoration, "actors": actors}}


## Global transform of a node of a scene that is not in the tree.
func _global(root: Node, node: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _f(x: float) -> String:
	var r := snappedf(x, 0.001)
	return "%.3f" % (0.0 if absf(r) < 0.0005 else r)


func _v(v: Vector3) -> String:
	return "(%s,%s,%s)" % [_f(v.x), _f(v.y), _f(v.z)]


func _xf(t: Transform3D) -> String:
	return "%s %s %s %s" % [_v(t.origin), _v(t.basis.x), _v(t.basis.y), _v(t.basis.z)]


func _shape(shape: Shape3D) -> String:
	if shape is BoxShape3D:
		return "box" + _v((shape as BoxShape3D).size)
	if shape is CapsuleShape3D:
		return "capsule(%s,%s)" % [_f(shape.radius), _f(shape.height)]
	if shape is CylinderShape3D:
		return "cylinder(%s,%s)" % [_f(shape.radius), _f(shape.height)]
	if shape is SphereShape3D:
		return "sphere(%s)" % _f(shape.radius)
	return shape.get_class() if shape else "none"


# --- C. Alternating loads ----------------------------------------------------------------------

func _check_alternating_loads() -> void:
	var start_nodes := _host.get_tree().get_node_count()
	var summary: PackedStringArray = []
	for path in [TUTORIAL, EXPANDED, TUTORIAL, EXPANDED]:
		var level: Node3D = (load(path) as PackedScene).instantiate()
		var ready: bool = await TestUtils.add_level_and_wait_for_navigation(_host, level, NAV_PROBE[path])
		_expect(ready, "%s: navigation never became ready." % path.get_file())
		await _frames(3)
		var tree := _host.get_tree()
		for g in SYSTEM_GROUPS:
			var all := tree.get_nodes_in_group(g)
			_expect(all.size() == 1 and level.is_ancestor_of(all[0]), "%s: expected exactly one '%s', in this map (found %d)." % [path.get_file(), g, all.size()])
		var expanded: bool = path == EXPANDED
		var guards := tree.get_nodes_in_group("guards").filter(func(n): return level.is_ancestor_of(n)).size()
		_expect(guards == tree.get_nodes_in_group("guards").size() and guards == (7 if expanded else 3),
			"%s: expected %d guards of its own, found %d (%d in the tree)." % [path.get_file(), 7 if expanded else 3, guards, tree.get_nodes_in_group("guards").size()])
		_expect(level.has_node("Expansion") == expanded, "%s: the Expansion node must exist only in the Expanded Library." % path.get_file())
		var objectives := ObjectiveManager.find(level)
		var first: StringName = objectives.get_ids()[1] if objectives else &""
		_expect(first == (&"take_card" if expanded else &"reach_restricted"), "%s: wrong objective list (second objective %s)." % [path.get_file(), first])
		_expect(objectives and objectives.current() == &"enter_library" and objectives.completed_count() == 0,
			"%s: a fresh load must start the mission from the beginning." % path.get_file())
		summary.append("%s (%d guards)" % ["expanded" if expanded else "tutorial", guards])
		var ref: WeakRef = weakref(level)
		level.queue_free()
		await _frames(3)
		_expect(ref.get_ref() == null, "%s: not freed when left." % path.get_file())
		for g in SYSTEM_GROUPS + ["guards", "interactables", "checkpoint_state"]:
			_expect(tree.get_nodes_in_group(g).is_empty(), "%s: group '%s' still has nodes after leaving." % [path.get_file(), g])
	_expect(_host.get_tree().get_node_count() == start_nodes, "Alternating loads left %d extra node(s) in the tree." % (_host.get_tree().get_node_count() - start_nodes))
	# This suite runs last: give the audio server time to release the freed map's
	# room-tone playback, or the run ends with it reported as leaked.
	for i in 30:
		await _host.get_tree().process_frame
	print("  [expansion] maps loaded alternately: %s; each on its own, nothing left behind" % " → ".join(summary))


func _frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
