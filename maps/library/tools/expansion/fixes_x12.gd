extends SceneTree

## Expanded Library, browsing hall, main stacks and upper stacks polish (approved by
## the owner): a minimal text patch of the existing scene,
## scenes/level/expanded_library.tscn (the level's builder is frozen; see fixes_x7.gd).
## The expansion builds the new dressing (build_expansion.gd: _build_browsing_hall,
## _build_stacks); this makes room for it. No collision, guard, route or navmesh
## change here (the expansion's new solid props are baked with it):
##
##   1. Browsing hall: the four reading tables' old look (body, top, books) and the
##      teal rugs are removed from the batches (their collision bodies stay), the
##      floor becomes the carpet's ground colour and the eight old chairs are hidden.
##   2. S3 stacks stair: the open side's balustrade panels and caps are removed from
##      the batches (the Handrail bodies stay), the step fillers become oak panelling,
##      the ramp's surface dark oak, its cream nosing is hidden (oak treads in its place),
##      the cream mats at its foot and top dark red and rubber grey.
##   3. Main stacks: carpet-tile floor colour; the round ceiling fixtures are hidden
##      (strip lights in their place; the lamps themselves are unchanged).
##   4. Upper stacks (steel mezzanine): the shelves, the edge railing and the floor
##      steel grey, the wainscot painted, the round fixtures hidden, the lamps a
##      little dimmer (1.1 → 0.95). (The expansion adds its lighter ceiling and beams.)
##   5. The bookcases' books get bays (uprights) and some half-empty bays
##      (ShelfBooks.bay / sparse), the upper stacks' boards steel grey.
##
##   godot --headless --path . --script res://maps/library/tools/expansion/fixes_x12.gd [-- --dry-run]
## Idempotent: running it again changes nothing. Exits with 0 on success.

const SCENE := "res://maps/library/scenes/expanded_library.tscn"
const PARENTS := ["NavigationRegion3D/Ground/Batched", "NavigationRegion3D/Upper/Batched", "Dressing/Batched"]

const HALL := [-36.0, 10.0, -12.0, 28.0]          # browsing hall (x0, z0, x1, z1)
const STACKS := [-36.0, -28.0, -12.0, 10.0]       # main stacks
const UPPER := [-36.2, -28.0, -6.0, 10.4]         # upper stacks (y 4.3…8.3)
const S3 := [-35.95, 9.9, -32.7, 20.1]            # the S3 stair's footprint
const S3_MATS := [-35.95, 9.0, -32.7, 21.0]       # with its foot and top mats

const CARPET_HALL := Color(0.15, 0.25, 0.22)      # browsing hall carpet (deep green)
const CARPET_TILE := Color(0.37, 0.38, 0.4)       # main stacks carpet tiles
const OAK_PANEL := Color(0.45, 0.3, 0.17)         # S3 step fillers (panelling)
const OAK_DARK := Color(0.3, 0.19, 0.1)           # S3 ramp surface (under the treads)
const STEEL := Color(0.5, 0.53, 0.56)             # upper shelving, railing
const STEEL_DARK := Color(0.33, 0.35, 0.38)       # their caps
const DECK := Color(0.4, 0.41, 0.4)               # upper floor
const WAINSCOT := Color(0.4, 0.45, 0.42)          # upper wainscot (painted)
const DADO := Color(0.25, 0.27, 0.27)

const MAT_FOOT := Color(0.42, 0.13, 0.12)         # the S3 foot mat (was cream)
const MAT_TOP := Color(0.2, 0.2, 0.21)            # the S3 top mat, rubber on the deck

const HIDE := [
	'[node name="Nosing" type="MultiMeshInstance3D" parent="NavigationRegion3D/Stairs/S3_S3StacksStair/Ramp"',
]
const CHAIRS := 8   # Dressing/Props/Chair00…07 (the browsing hall's)
const LIGHTS := ["B_MainStacks_%d", "E_UpperStacks_%d"]
const LIGHT_COUNT := 12
const BOOKS_GROUND := {"bay": "1.0", "sparse": "0.15"}
const BOOKS_UPPER := {"bay": "1.0", "sparse": "0.22", "board_colour": "Color(0.36, 0.38, 0.4, 1)"}

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
	for h in HIDE:
		_hide(h, h.get_slice('"', 1))
	for i in CHAIRS:
		_hide('[node name="Chair%02d" parent="Dressing/Props"' % i, "Chair%02d" % i)
	for l in LIGHTS:
		for i in LIGHT_COUNT:
			var lamp: String = l % i
			_hide('[node name="Fixture" parent="Dressing/Lights/%s" index="0"]' % lamp, lamp + " fixture")
			if lamp.begins_with("E_"):
				_set_in_block('[node name="Light" parent="Dressing/Lights/%s" index="1"]' % lamp, "light_energy = 1.1", "light_energy = 0.95", lamp + " dimmer")
	for shelf in level.get_node("NavigationRegion3D/Ground/B_MainStacks").get_children():
		if shelf.has_node("Books"):
			_set_books("NavigationRegion3D/Ground/B_MainStacks/%s" % shelf.name, BOOKS_GROUND)
	for shelf in level.get_node("NavigationRegion3D/Upper/E_StaffUpperStacks").get_children():
		if shelf.has_node("Books") and _inside((shelf as Node3D).global_position, UPPER):
			_set_books("NavigationRegion3D/Upper/E_StaffUpperStacks/%s" % shelf.name, BOOKS_UPPER)
	level.queue_free()
	if _changes.is_empty():
		print("fixes_x12: nothing to change")
	else:
		for c in _changes:
			print("fixes_x12: ", c)
		if not dry:
			var f := FileAccess.open(SCENE, FileAccess.WRITE)
			f.store_string(_text)
			f.close()
			print("fixes_x12: wrote %s" % SCENE)
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


## "remove", a Color (recolour) or null for box `i`.
func _rule(c: Vector3, hex: String, v: Vector3) -> Variant:
	if _inside(c, HALL) and c.y < 1.2:
		if hex == "543821" and _near(v, Vector3(0.8, 1.4, 3.0)):
			return "remove"   # table body
		if hex == "8c5e36" and _near(v, Vector3(0.06, 1.48, 3.08)):
			return "remove"   # table top
		if hex == "33618c" and _near(v, Vector3(0.1, 0.24, 0.32)):
			return "remove"   # books on the tables
		if hex == "215454" and v.x < 0.02:
			return "remove"   # teal rugs
		if hex == "664d38" and absf(c.y + 0.1) < 0.02:
			return CARPET_HALL
		if hex == "dbcc9e" and c.y < 0.1:
			return MAT_FOOT
	if _inside(c, S3) and c.y < 6.0:
		if hex == "472e1a" and _has(v, 3.0) and _has(v, 1.0):
			return OAK_PANEL   # step fillers (3.0 wide, 1.0 long)
		if hex == "735438":
			return OAK_DARK
		if hex == "54361f" and absf(c.x + 32.85) < 0.02 and absf(v.x - 0.1) < 0.01:
			return "remove"   # balustrade panels (their Handrail bodies stay)
		if hex == "b88f3d" and absf(c.x + 32.85) < 0.02:
			return "remove"   # their caps
	if hex == "dbcc9e" and _inside(c, S3_MATS) and absf(c.y - 4.5) < 0.05:
		return MAT_TOP
	if _inside(c, STACKS) and hex == "664d38" and absf(c.y + 0.1) < 0.02:
		return CARPET_TILE
	if _inside(c, UPPER) and c.y > 4.3 and c.y < 8.3:
		if hex == "54361f" and _near(Vector3(v.x, v.y, 0), Vector3(0.6, 2.2, 0)) and v.z > 5.0:
			return STEEL   # shelf bodies
		if hex == "472e1a" and _near(Vector3(v.x, v.y, 0), Vector3(0.04, 0.66, 0)) and v.z > 5.0:
			return STEEL_DARK   # their caps
		if hex == "54361f" and c.z > 9.5 and c.x < -9.0:
			return STEEL   # the edge railing over the browsing hall
		if hex == "5c3d24" and c.z > 9.5 and c.x < -9.0 and c.y > 5.5:
			return STEEL_DARK   # its cap
		if hex == "664d38" and absf(c.y - 4.4) < 0.02:
			return DECK
		if hex == "5c3d24" and _near(Vector3(v.x, v.y, 0), Vector3(0.03, 1.0, 0)):
			return WAINSCOT
		if hex == "472e1a" and _near(Vector3(v.x, v.y, 0), Vector3(0.06, 0.06, 0)):
			return DADO
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
		push_error("fixes_x12: missing %s" % header)
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
		push_error("fixes_x12: missing %s" % header)
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


func _set_in_block(header: String, old: String, new: String, what: String) -> void:
	var b := _block(header)
	if b.is_empty():
		return
	var block := _text.substr(b[0], b[1] - b[0])
	if not block.contains("\n" + old + "\n"):
		return
	_text = _text.substr(0, b[0]) + block.replace("\n" + old + "\n", "\n" + new + "\n") + _text.substr(b[1])
	_changes.append(what)


func _set_books(shelf_path: String, props: Dictionary) -> void:
	var b := _block('[node name="Books" type="Node3D" parent="%s"' % shelf_path)
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
	_changes.append("%s/Books: %s" % [shelf_path, add.strip_edges().replace("\n", ", ")])


func _f(x: float) -> String:
	var s := "%.6f" % x
	s = s.rstrip("0").rstrip(".")
	return "0" if s == "-0" else s
