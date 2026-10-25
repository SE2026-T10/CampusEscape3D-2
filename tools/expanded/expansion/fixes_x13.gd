extends SceneTree

## Expanded Library, staff wing polish (offices, staff corridor, staff balcony; approved
## by the owner): a minimal text patch of the existing scene,
## scenes/level/expanded_library.tscn (the level's builder is frozen; see fixes_x7.gd).
## The expansion builds the new dressing (build_expansion.gd: _build_staff_wing); this
## makes room for it. No collision, guard, route or navmesh change here:
##
##   1. Offices: the three desks' old look (body, top, papers, monitors) is removed from
##      the batches (their collision bodies stay) and the floor becomes carpet tiles.
##   2. Corridor and balcony: the deck floor of the upper stacks; the balcony tables' old
##      look and teal rugs are removed (their bodies stay).
##   3. The balcony railing's boxes (over the lobby, x −8.85…12) are removed (its
##      Railing body stays; the expansion draws a steel railing in their place).
##   4. The wainscot painted like the upper stacks, the door frames oak.
##   5. The seven old chairs (Chair20…26) and the round light fixtures hidden (strip
##      lights in their place; the lamps themselves are unchanged).
##
##   godot --headless --path . --script res://tools/expanded/expansion/fixes_x13.gd [-- --dry-run]
## Idempotent: running it again changes nothing. Exits with 0 on success.

const SCENE := "res://scenes/level/expanded_library.tscn"
const PARENTS := ["NavigationRegion3D/Upper/Batched", "Dressing/Batched"]

const STAFF := [-6.05, -28.2, 12.0, 10.4]         # the staff wing (x0, z0, x1, z1), y 4.3…8.3
const OFFICES := [-6.0, -28.2, 12.0, -14.0]
const CORRIDOR := [-6.0, -14.0, 12.0, -8.0]
const BALCONY := [-6.2, -8.0, 12.0, 10.4]

const OFFICE_CARPET := Color(0.33, 0.36, 0.4)
const DECK := Color(0.4, 0.41, 0.4)               # as fixes_x12.gd (the upper stacks)
const WAINSCOT := Color(0.4, 0.45, 0.42)
const DADO := Color(0.25, 0.27, 0.27)
const OAK_FRAME := Color(0.4, 0.26, 0.14)

const CHAIRS := [20, 21, 22, 23, 24, 25, 26]
const LIGHTS := ["E_StaffBalcony_0", "E_StaffBalcony_1", "E_StaffBalcony_2", "E_StaffBalcony_3",
	"E_StaffCorridor_0", "E_StaffCorridor_1", "E_Office1_0", "E_Office2_0", "E_Office3_0"]

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
	for i in CHAIRS:
		_hide('[node name="Chair%02d" parent="Dressing/Props"' % i, "Chair%02d" % i)
	for lamp in LIGHTS:
		_hide('[node name="Fixture" parent="Dressing/Lights/%s" index="0"]' % lamp, lamp + " fixture")
	level.queue_free()
	if _changes.is_empty():
		print("fixes_x13: nothing to change")
	else:
		for c in _changes:
			print("fixes_x13: ", c)
		if not dry:
			var f := FileAccess.open(SCENE, FileAccess.WRITE)
			f.store_string(_text)
			f.close()
			print("fixes_x13: wrote %s" % SCENE)
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
	if c.y < 4.3 or c.y > 8.3:
		return null
	# The balcony railing (its body Railing19_2 spans x −8.85…12.15) and its cap.
	if absf(c.z - 10.0) < 0.05 and c.x > -9.0 and c.x < 12.3:
		if hex == "54361f" and absf(c.y - 5.05) < 0.05:
			return "remove"
		if hex == "5c3d24" and absf(c.y - 5.625) < 0.05:
			return "remove"
	if not _inside(c, STAFF):
		return null
	if _inside(c, OFFICES):
		if hex == "543821" and _near(v, Vector3(0.8, 1.0, 3.0)):
			return "remove"   # desk body
		if hex == "8c5e36" and _near(v, Vector3(0.06, 1.08, 3.08)):
			return "remove"   # desk top
		if hex == "dbd4bd" and _near(v, Vector3(0.02, 0.22, 0.3)):
			return "remove"   # papers
		if hex == "264d6b" and _near(v, Vector3(0.04, 0.32, 0.5)):
			return "remove"   # monitors
		if hex == "425254" and absf(c.y - 4.4) < 0.02:
			return OFFICE_CARPET
	if _inside(c, CORRIDOR) and hex == "425254" and absf(c.y - 4.4) < 0.02:
		return DECK
	if _inside(c, BALCONY):
		if hex == "543821" and _near(v, Vector3(0.8, 1.4, 3.0)):
			return "remove"   # table body
		if hex == "8c5e36" and _near(v, Vector3(0.06, 1.48, 3.08)):
			return "remove"   # table top
		if hex == "33618c" and _near(v, Vector3(0.1, 0.24, 0.32)):
			return "remove"   # books
		if hex == "215454" and v.x < 0.02:
			return "remove"   # teal rugs
		if hex == "664d38" and absf(c.y - 4.4) < 0.02:
			return DECK
	if hex == "5c3d24" and _near(Vector3(v.x, v.y, 0), Vector3(0.03, 1.0, 0)):
		return WAINSCOT
	if hex == "472e1a" and _near(Vector3(v.x, v.y, 0), Vector3(0.06, 0.06, 0)):
		return DADO
	if hex == "5c3d24" and (_near(v, Vector3(0.16, 0.38, 2.6)) or _near(v, Vector3(0.14, 0.42, 2.32))):
		return OAK_FRAME   # door jambs and heads
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
		push_error("fixes_x13: missing %s" % header)
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
		push_error("fixes_x13: missing %s" % header)
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


func _f(x: float) -> String:
	var s := "%.6f" % x
	s = s.rstrip("0").rstrip(".")
	return "0" if s == "-0" else s
