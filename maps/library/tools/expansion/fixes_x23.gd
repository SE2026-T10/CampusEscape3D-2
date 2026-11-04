extends SceneTree

## Expanded Library, lobby layout change (approved by the owner): the circulation desk
## moves to where the north-west planter stood and turns 180°, so its panelled front
## faces the main entrance like the cornerstone; the planter is removed. A minimal text
## patch of the existing scene, maps/library/scenes/expanded_library.tscn (the level's
## builder is frozen; see fixes_x7.gd):
##
##   1. The desk's collider (Low18, with its globe) turns 180° about its centre (4, 16)
##      and moves to (−5.5, 13.6): x −8.5…−2.5, z 13.0…14.2 (the full 6 m desk, 0.5 m
##      east of the planter's centre, clear of the S1 stair and the reading hall doors).
##   2. The desk's own boxes in the batches move the same way, into the batches of their
##      new cell; the planter's boxes are removed and its collider (Low19) deleted.
##   3. The desk's hiding spot (Gameplay and Layout "Circulationdesk") moves with it, to
##      the same place behind the desk: (−5.5, 12.3), the staff side now facing north.
## The expansion moves the desk's dressing, computers, lamp and chair (build_expansion.gd);
## the navmesh is rebaked afterwards.
##
##   godot --headless --path . --script res://maps/library/tools/expansion/fixes_x23.gd [-- --dry-run]
## Idempotent: running it again changes nothing. Exits with 0 on success.

const SCENE := "res://maps/library/scenes/expanded_library.tscn"
const PARENTS := ["NavigationRegion3D/Ground/Batched", "Dressing/Batched"]
const OLD_CENTRE := Vector3(4, 0, 16)
const NEW_CENTRE := Vector3(-5.5, 0, 13.6)
const DESK := AABB(Vector3(0.85, 0.0, 15.3), Vector3(6.3, 1.35, 1.4))
const PLANTER := AABB(Vector3(-7.1, 0.0, 12.9), Vector3(2.2, 1.4, 1.2))
const TARGET := {false: "Batch_2_3_plain_L4_S0_1", true: "Batch_2_3_plain_L4_S1_1"}   # by casts-shadow
const DESK_BODY := '[node name="Low18" type="StaticBody3D" parent="NavigationRegion3D/Ground/A_EntranceLobby"'
const PLANTER_BODY := '[node name="Low19" type="StaticBody3D" parent="NavigationRegion3D/Ground/A_EntranceLobby"'
const PLANTER_SHAPE := '[node name="Shape" type="CollisionShape3D" parent="NavigationRegion3D/Ground/A_EntranceLobby/Low19"'
const SPOTS := ['[node name="Circulationdesk" type="Area3D" parent="Gameplay/HidingSpots"',
	'[node name="Circulationdesk" type="Marker3D" parent="Layout/HidingSpots"']

var _text := ""
var _changes: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _move() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI), NEW_CENTRE) * Transform3D(Basis(), -OLD_CENTRE)


func _run() -> void:
	var dry := "--dry-run" in OS.get_cmdline_user_args()
	_text = FileAccess.get_file_as_string(SCENE)
	if _text.contains("Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, -5.5, 0.55, 13.6)"):
		print("fixes_x23: nothing to change")
		quit(0)
		return
	var level: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(level)
	var move := _move()
	# 2. The batches: the desk's boxes out (moved to TARGET), the planter's out.
	var moved := {true: PackedStringArray(), false: PackedStringArray()}
	var targets := {}
	for p in PARENTS:
		for b in level.get_node(p).get_children():
			if not b is BatchedBoxes:
				continue
			if p == PARENTS[0] and b.name in TARGET.values():
				targets[b.name] = b
			var remove: Array[int] = []
			for i in b.box_count():
				var xf: Transform3D = b.global_transform * b.box_transform(i)
				if DESK.has_point(xf.origin):
					remove.append(i)
					var shadow: bool = b.name.contains("_S1")
					moved[shadow].append_array(_pack(move * xf, b.box_color(i)))
				elif PLANTER.has_point(xf.origin):
					remove.append(i)
			if not remove.is_empty():
				_edit_batch(b, p, remove, PackedStringArray())
	for shadow in [false, true]:
		var t: BatchedBoxes = targets[TARGET[shadow]]
		var local := PackedStringArray()
		var vals: PackedStringArray = moved[shadow]
		for i in vals.size() / 16:
			var box := vals.slice(i * 16, i * 16 + 16)
			local.append_array(_localise(box, t))
		_edit_batch(t, PARENTS[0], [], local)
	level.queue_free()
	# 1. The desk's collider (its children, the globe, follow it).
	_replace_transform(DESK_BODY, "Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, -5.5, 0.55, 13.6)", "desk collider Low18 moved and turned")
	# The planter's collider.
	_remove_block(PLANTER_SHAPE, "planter shape")
	_remove_block(PLANTER_BODY, "planter collider Low19")
	# 3. The hiding spot.
	_replace_transform(SPOTS[0], "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -5.5, 0.6, 12.3)", "hiding spot moved")
	_replace_transform(SPOTS[1], "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -5.5, 0, 12.3)", "hiding spot marker moved")
	for c in _changes:
		print("fixes_x23: ", c)
	if not dry:
		var f := FileAccess.open(SCENE, FileAccess.WRITE)
		f.store_string(_text)
		f.close()
		print("fixes_x23: wrote %s" % SCENE)
	quit(0)


## A box (world transform, colour) as BatchedBoxes' 16 floats, as text (world space).
func _pack(xf: Transform3D, c: Color) -> PackedStringArray:
	var out := PackedStringArray()
	for v in [xf.basis.x, xf.basis.y, xf.basis.z, xf.origin]:
		out.append_array([_f(v.x), _f(v.y), _f(v.z)])
	out.append_array([_f(c.r), _f(c.g), _f(c.b), _f(c.a)])
	return out


func _localise(box: PackedStringArray, b: BatchedBoxes) -> PackedStringArray:
	var v := []
	for s in box:
		v.append(float(s))
	var xf := Transform3D(Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5]), Vector3(v[6], v[7], v[8]), Vector3(v[9], v[10], v[11]))
	return _pack(b.global_transform.affine_inverse() * xf, Color(v[12], v[13], v[14], v[15]))


func _edit_batch(node: BatchedBoxes, parent: String, remove: Array, add: PackedStringArray) -> void:
	var header := '[node name="%s" type="MultiMeshInstance3D" parent="%s"' % [node.name, parent]
	var start := _text.find(header)
	if start < 0:
		push_error("fixes_x23: missing %s" % header)
		return
	var end := _text.find("\n[", start + 1)
	var block := _text.substr(start, end - start)
	var key := "boxes = PackedFloat32Array("
	var vs := block.find(key) + key.length()
	var ve := block.find(")", vs)
	var raw := block.substr(vs, ve - vs)
	var values := raw.split(", ") if raw != "" else PackedStringArray()
	var kept := PackedStringArray()
	for i in values.size() / BatchedBoxes.STRIDE:
		if i in remove:
			continue
		kept.append_array(values.slice(i * BatchedBoxes.STRIDE, (i + 1) * BatchedBoxes.STRIDE))
	kept.append_array(add)
	_text = _text.substr(0, start) + block.substr(0, vs) + ", ".join(kept) + block.substr(ve) + _text.substr(end)
	_changes.append("%s/%s: %d boxes out, %d in" % [parent, node.name, remove.size(), add.size() / BatchedBoxes.STRIDE])


func _block(header: String) -> Array:
	var start := _text.find(header)
	if start < 0:
		push_error("fixes_x23: missing %s" % header)
		return []
	var end := _text.find("\n[", start + 1)
	return [start, end]


func _replace_transform(header: String, value: String, what: String) -> void:
	var b := _block(header)
	if b.is_empty():
		return
	var block := _text.substr(b[0], b[1] - b[0])
	var ts := block.find("\ntransform = ")
	var te := block.find("\n", ts + 1)
	block = block.substr(0, ts) + "\ntransform = " + value + block.substr(te)
	_text = _text.substr(0, b[0]) + block + _text.substr(b[1])
	_changes.append(what)


func _remove_block(header: String, what: String) -> void:
	var b := _block(header)
	if b.is_empty():
		return
	_text = _text.substr(0, b[0]) + _text.substr(b[1] + 1)
	_changes.append(what + " removed")


func _f(x: float) -> String:
	var s := "%.6f" % x
	s = s.rstrip("0").rstrip(".")
	return "0" if s == "-0" else s
