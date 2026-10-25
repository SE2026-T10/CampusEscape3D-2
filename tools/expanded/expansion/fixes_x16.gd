extends SceneTree

## Expanded Library, study rooms polish (approved by the owner): a modern quiet study.
## A minimal text patch of the existing scene, scenes/level/expanded_library.tscn (the
## level's builder is frozen; see fixes_x7.gd). The expansion builds the new dressing
## (build_expansion.gd: _build_study_rooms); this makes room for it. No collision,
## guard, route or navmesh change here:
##
##   1. The old look of the eight carrels (desks, tops, side panels, lamp shades) and of
##      the O1 desk in Study 3 is removed from the batches (their colliders stay); their
##      lamp stems are hidden.
##   2. The study floors become a grey-blue carpet (tiles and a border on top, from the
##      expansion); the rooms' wainscot oak, the dado rails and the five study door frames
##      dark oak.
##   3. The round light fixtures are hidden (flat ceiling panels in their place; the
##      lamps themselves are unchanged).
##
##   godot --headless --path . --script res://tools/expanded/expansion/fixes_x16.gd [-- --dry-run]
## Idempotent: running it again changes nothing. Exits with 0 on success.

const SCENE := "res://scenes/level/expanded_library.tscn"
const PARENTS := ["NavigationRegion3D/Ground/Batched", "Dressing/Batched"]

const STUDY := [-11.86, -27.86, 11.86, -14.14]   # Study 1…4 inside (x0, z0, x1, z1), y −0.3…2.7

const CARPET := Color(0.34, 0.38, 0.42)
const OAK := Color(0.58, 0.4, 0.23)
const OAK_DARK := Color(0.4, 0.26, 0.14)

const LIGHTS := ["C_Study1_0", "C_Study2_0", "C_Study3_0", "C_Study4_0"]
const STEMS := ["CarrelDesk28", "CarrelDesk29", "CarrelDesk30", "CarrelDesk31", "CarrelDesk32", "CarrelDesk33", "CarrelDesk34", "CarrelDesk35", "Low52"]

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
	for lamp in LIGHTS:
		_hide('[node name="Fixture" parent="Dressing/Lights/%s" index="0"]' % lamp, lamp + " fixture")
	for d in STEMS:
		_hide('[node name="LampStem" type="MeshInstance3D" parent="NavigationRegion3D/Ground/C_ReadingStudy/%s"' % d, d + " lamp stem")
	level.queue_free()
	if _changes.is_empty():
		print("fixes_x16: nothing to change")
	else:
		for c in _changes:
			print("fixes_x16: ", c)
		if not dry:
			var f := FileAccess.open(SCENE, FileAccess.WRITE)
			f.store_string(_text)
			f.close()
			print("fixes_x16: wrote %s" % SCENE)
	quit(0)


func _inside(c: Vector3, r: Array) -> bool:
	return c.x > r[0] and c.x < r[2] and c.z > r[1] and c.z < r[3]


func _sorted(xf: Transform3D) -> Vector3:
	var s := [xf.basis.x.length(), xf.basis.y.length(), xf.basis.z.length()]
	s.sort()
	return Vector3(s[0], s[1], s[2])


func _near(v: Vector3, w: Vector3) -> bool:
	return v.distance_to(w) < 0.01


## "remove", a Color (recolour) or null for a box.
func _rule(c: Vector3, hex: String, v: Vector3) -> Variant:
	# The study doors' frames (jambs, heads) straddle the wall z −14 and x 0.
	var frame := _near(v, Vector3(0.16, 0.38, 2.6)) or _near(v, Vector3(0.14, 0.42, 2.32))
	if hex == "5c3d24" and frame and (absf(c.z + 14.0) < 0.05 and absf(c.x) < 11.9 or absf(c.x) < 0.05 and absf(c.z + 24.0) < 1.3):
		return OAK_DARK
	if not _inside(c, STUDY) or c.y < -0.3 or c.y > 2.7:
		return null
	if hex == "425254" and _near(v, Vector3(0.2, 4.67, 6.0)):
		return CARPET          # floors
	if hex == "5c3d24" and _near(Vector3(v.x, v.y, 0), Vector3(0.03, 1.0, 0)):
		return OAK             # wainscot
	if hex == "472e1a" and _near(Vector3(v.x, v.y, 0), Vector3(0.06, 0.06, 0)):
		return OAK_DARK        # dado rails
	if hex == "6b4d33" and _near(v, Vector3(0.7, 0.75, 1.2)):
		return "remove"        # carrel desks
	if hex == "8c5e36" and _near(v, Vector3(0.05, 0.74, 1.2)):
		return "remove"        # their tops
	if hex == "543821" and _near(v, Vector3(0.1, 1.2, 1.5)):
		return "remove"        # their side panels
	if hex == "543821" and _near(v, Vector3(0.75, 0.8, 1.6)):
		return "remove"        # the O1 desk
	if hex == "8c5e36" and _near(v, Vector3(0.06, 0.88, 1.68)):
		return "remove"        # its top
	if hex == "1a7340":
		return "remove"        # the green lamp shades
	return null


func _patch_batch(node: BatchedBoxes, parent: String) -> void:
	var remove: Array[int] = []
	var recolour := {}
	for i in node.box_count():
		var xf := node.global_transform * node.box_transform(i)
		var r: Variant = _rule(xf.origin, node.box_color(i).to_html(false), _sorted(xf))
		if r is String:
			remove.append(i)
		elif r is Color:
			recolour[i] = r
	if remove.is_empty() and recolour.is_empty():
		return
	var header := '[node name="%s" type="MultiMeshInstance3D" parent="%s"' % [node.name, parent]
	var start := _text.find(header)
	if start < 0:
		push_error("fixes_x16: missing %s" % header)
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
		if recolour.has(i):
			var col: Color = recolour[i]
			box[12] = _f(col.r)
			box[13] = _f(col.g)
			box[14] = _f(col.b)
		kept.append_array(box)
	_text = _text.substr(0, start) + block.substr(0, vs) + ", ".join(kept) + block.substr(ve) + _text.substr(end)
	_changes.append("%s/%s: %d boxes removed, %d recoloured" % [parent, node.name, remove.size(), recolour.size()])


func _block(header: String) -> Array:
	var start := _text.find(header)
	if start < 0:
		push_error("fixes_x16: missing %s" % header)
		return []
	var end := _text.find("\n[", start + 1)
	return [start, end]


func _hide(header: String, what: String) -> void:
	var b := _block(header)
	if b.is_empty():
		return
	var block := _text.substr(b[0], b[1] - b[0])
	if block.contains("\nvisible = false"):
		return
	var script_line := block.find("\nscript = ")
	var at: int = b[0] + (block.find("\n", script_line + 1) if script_line >= 0 else block.find("\n"))
	_text = _text.substr(0, at) + "\nvisible = false" + _text.substr(at)
	_changes.append("%s hidden" % what)


func _set_props(header: String, props: Dictionary, what: String) -> void:
	var b := _block(header)
	if b.is_empty():
		return
	var block := _text.substr(b[0], b[1] - b[0])
	var add := ""
	for k in props:
		if not block.contains("\n%s = " % k):
			add += "\n%s = %s" % [k, props[k]]
	if add == "":
		return
	var script_line := block.find("\nscript = ")
	var at: int = b[0] + block.find("\n", script_line + 1)
	_text = _text.substr(0, at) + add + _text.substr(at)
	_changes.append("%s: %s" % [what, add.strip_edges().replace("\n", ", ")])


func _f(x: float) -> String:
	var s := "%.6f" % x
	s = s.rstrip("0").rstrip(".")
	return "0" if s == "-0" else s
