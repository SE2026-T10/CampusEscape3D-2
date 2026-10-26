extends SceneTree

## Expanded Library, lobby polish (requested by the owner): the S1 main stair and the
## circulation desk in oak like the browsing hall's S3 and tables. A minimal text patch
## of the existing scene, scenes/level/expanded_library.tscn (the level's builder is
## frozen; see fixes_x7.gd). The expansion draws the oak stair and the desk's front
## (build_expansion.gd: _dress_oak_stair, _build_lobby). No collision, guard, route or
## navmesh change:
##
##   1. S1: the open side's balustrade panels and caps are removed from the batches (the
##      Handrail bodies stay), the step fillers become oak panelling, the ramp's surface
##      dark oak (under the treads), the cream mats at its foot and top red and grey.
##   2. The circulation desk: its body dark oak, its top and its back panel oak.
##   3. The upper floor railing's end post and its cap at the top of S3 (x −36, z 10) are
##      removed from the batches: they sat inside the west wall, face to face with it, and
##      flickered through it (its Railing body stays).
##   4. The upper floor's outer wall pieces at the S3 top (x −36) and the S2 top (x 36)
##      overlapped the single-height rooms' upper wall pieces (browsing hall, storage) by
##      0.3 m, face to face but lit by different lamps, and flickered there as a stripe:
##      they now end where those begin (z 9.85 and −6.15; the 0.3 m piece wholly inside the
##      storage's is removed). Decoration only; no collider.
##
##   godot --headless --path . --script res://maps/library/tools/expansion/fixes_x14.gd [-- --dry-run]
## Idempotent: running it again changes nothing. Exits with 0 on success.

const SCENE := "res://maps/library/scenes/expanded_library.tscn"
const PARENTS := ["NavigationRegion3D/Ground/Batched", "NavigationRegion3D/Upper/Batched", "Dressing/Batched"]
## Upper wall pieces (x ±36, 0.3 thick, y 4.5…8.0) to end earlier along z: [x, old z end, new z end].
const TRIM := [[-36.0, 10.15, 9.85], [36.0, -5.85, -6.15]]

const S1 := [-11.95, 9.0, -8.7, 21.0]             # the S1 stair's footprint, with its mats
const DESK := [0.8, 15.2, 7.2, 16.8]              # the circulation desk (x 1…7, z 15.4…16.6)

const OAK := Color(0.58, 0.4, 0.23)
const OAK_PANEL := Color(0.45, 0.3, 0.17)         # as fixes_x12.gd (S3)
const OAK_DARK := Color(0.3, 0.19, 0.1)
const DESK_BODY := Color(0.4, 0.26, 0.14)
const MAT_FOOT := Color(0.42, 0.13, 0.12)
const MAT_TOP := Color(0.2, 0.2, 0.21)

var _text := ""
var _changes: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var dry := "--dry-run" in OS.get_cmdline_user_args()
	_text = FileAccess.get_file_as_string(SCENE)
	var level: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(level)
	for p in PARENTS:
		for b in level.get_node(p).get_children():
			if b is BatchedBoxes:
				_patch_batch(b, p)
	level.queue_free()
	if _changes.is_empty():
		print("fixes_x14: nothing to change")
	else:
		for c in _changes:
			print("fixes_x14: ", c)
		if not dry:
			var f := FileAccess.open(SCENE, FileAccess.WRITE)
			f.store_string(_text)
			f.close()
			print("fixes_x14: wrote %s" % SCENE)
	quit(0)


func _inside(c: Vector3, r: Array) -> bool:
	return c.x > r[0] and c.x < r[2] and c.z > r[1] and c.z < r[3]


func _sorted(xf: Transform3D) -> Vector3:
	var s := [xf.basis.x.length(), xf.basis.y.length(), xf.basis.z.length()]
	s.sort()
	return Vector3(s[0], s[1], s[2])


func _has(v: Vector3, a: float) -> bool:
	return absf(v.x - a) < 0.01 or absf(v.y - a) < 0.01 or absf(v.z - a) < 0.01


func _near(v: Vector3, w: Vector3) -> bool:
	return v.distance_to(w) < 0.01


## "remove", a Color (recolour) or null for a box.
func _rule(c: Vector3, hex: String, v: Vector3) -> Variant:
	if _inside(c, S1) and c.y < 6.0:
		if hex == "54331f" and absf(c.x + 8.85) < 0.02 and absf(v.x - 0.1) < 0.01:
			return "remove"   # balustrade panels (their Handrail bodies stay)
		if hex == "c29945" and absf(c.x + 8.85) < 0.02:
			return "remove"   # their caps
		if hex == "6b4529" and _has(v, 3.0) and _has(v, 1.0):
			return OAK_PANEL   # step fillers
		if hex == "731c1f":
			return OAK_DARK    # the ramp's surface
		if hex == "dbcc9e" and c.y < 0.1:
			return MAT_FOOT
		if hex == "dbcc9e" and absf(c.y - 4.5) < 0.05:
			return MAT_TOP
	if absf(c.x + 36.0) < 0.02 and absf(c.z - 10.0) < 0.02 and c.y > 4.5 and c.y < 5.8 and (hex == "80878f" or hex == "545961"):
		return "remove"   # the railing's end post and cap inside the west wall
	if _inside(c, DESK) and c.y < 1.3:
		if hex == "4d331f" and _near(v, Vector3(1.1, 1.2, 6.0)):
			return DESK_BODY
		if hex == "8c5e36" and _near(v, Vector3(0.06, 1.3, 6.1)):
			return OAK
		if hex == "5c3d24" and _near(v, Vector3(0.03, 0.8, 5.7)):
			return OAK
	return null


func _patch_batch(node: BatchedBoxes, parent: String) -> void:
	var remove: Array[int] = []
	var recolour := {}
	var trim := {}   # index -> [new z length, new local z]
	for i in node.box_count():
		var xf := node.global_transform * node.box_transform(i)
		var ab: AABB = xf * AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
		for t in TRIM:
			if parent == "NavigationRegion3D/Upper/Batched" and absf(ab.get_center().x - t[0]) < 0.02 and absf(ab.size.x - 0.3) < 0.01 \
					and absf(ab.position.y - 4.5) < 0.02 and absf(ab.end.y - 8.0) < 0.02 and absf(ab.end.z - t[1]) < 0.005 and xf.basis.z.z > 0.0:
				var length: float = t[2] - ab.position.z
				if length < 0.05:
					remove.append(i)   # wholly inside the other piece
				else:
					var local := node.box_transform(i)
					trim[i] = [length, local.origin.z + ((ab.position.z + t[2]) / 2.0 - ab.get_center().z)]
		var r: Variant = _rule(xf.origin, node.box_color(i).to_html(false), _sorted(xf))
		if r is String:
			remove.append(i)
		elif r is Color:
			recolour[i] = r
	if remove.is_empty() and recolour.is_empty() and trim.is_empty():
		return
	var header := '[node name="%s" type="MultiMeshInstance3D" parent="%s"' % [node.name, parent]
	var start := _text.find(header)
	if start < 0:
		push_error("fixes_x14: missing %s" % header)
		return
	var end := _text.find("\n[", start + 1)
	var block := _text.substr(start, end - start)
	var key := "boxes = PackedFloat32Array("
	var vs := block.find(key) + key.length()
	var ve := block.find(")", vs)
	var values := block.substr(vs, ve - vs).split(", ")
	var stride := BatchedBoxes.STRIDE
	var kept: PackedStringArray = []
	for i in node.box_count():
		if i in remove:
			continue
		var box := values.slice(i * stride, (i + 1) * stride)
		if trim.has(i):
			box[8] = _f(trim[i][0])
			box[11] = _f(trim[i][1])
		if recolour.has(i):
			var col: Color = recolour[i]
			box[12] = _f(col.r)
			box[13] = _f(col.g)
			box[14] = _f(col.b)
		kept.append_array(box)
	_text = _text.substr(0, start) + block.substr(0, vs) + ", ".join(kept) + block.substr(ve) + _text.substr(end)
	_changes.append("%s/%s: %d boxes removed, %d recoloured, %d trimmed" % [parent, node.name, remove.size(), recolour.size(), trim.size()])


func _f(x: float) -> String:
	var s := "%.6f" % x
	s = s.rstrip("0").rstrip(".")
	return "0" if s == "-0" else s
