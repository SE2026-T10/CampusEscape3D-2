extends SceneTree

## Expanded Library, restricted archive polish (approved by the owner): an old
## rare-books archive. A minimal text patch of the existing scene,
## scenes/level/expanded_library.tscn (the level's builder is frozen; see fixes_x7.gd).
## The expansion builds the new dressing (build_expansion.gd: _build_archive); this
## makes room for it. No collision, guard, route or navmesh change here:
##
##   1. The archive's wainscot, dado rails and the G2 / G3 door frames walnut, the vault
##      doorway's frame steel; the archive shelves walnut (their books in bays, some half
##      empty, walnut boards).
##   2. The old look of the hall's reading table (body, top, book), the vault pedestal
##      (stone, brass top) and the alcove's crate (body, bands) and the hall's red runner
##      strips are removed from the batches (their colliders stay).
##   3. The round light fixtures are hidden (brass pendants in their place; the lamps
##      themselves are unchanged); the cream mat at the S2 top becomes rubber grey.
##   4. The back gate G3 draws the expansion's steel leaves and status lamps
##      (AccessDoor leaf_paths, as the lobby's G4).
##
##   godot --headless --path . --script res://maps/library/tools/expansion/fixes_x15.gd [-- --dry-run]
## Idempotent: running it again changes nothing. Exits with 0 on success.

const SCENE := "res://maps/library/scenes/expanded_library.tscn"
const PARENTS := ["NavigationRegion3D/Upper/Batched", "Dressing/Batched"]

const ARCHIVE := [11.95, -28.2, 36.2, -5.8]      # zone F (x0, z0, x1, z1), y 4.3…8.3

const WALNUT := Color(0.3, 0.19, 0.11)
const WALNUT_DARK := Color(0.2, 0.12, 0.06)
const VAULT_STEEL := Color(0.4, 0.42, 0.44)
const MAT_TOP := Color(0.2, 0.2, 0.21)

const LIGHTS := ["F_ArchiveHall_0", "F_ArchiveHall_1", "F_ArchiveStacks_0", "F_ArchiveStacks_1", "F_Vault_0", "F_Alcove_0", "F_StaffStairLanding_0"]
const SHELVES := ["Shelf80", "Shelf81", "Shelf82", "Shelf83", "Shelf84", "Shelf85"]
const BOOKS := {"bay": "1.125", "sparse": "0.2", "board_colour": "Color(0.2, 0.12, 0.06, 1)"}
const G3 := '[node name="ArchiveBackGateG3" type="Area3D" parent="Gameplay"'
const G3_DRESSING := "../../Expansion/Gameplay/ArchiveBackGateDressing/"
const G3_PROPERTIES := [
	'leaf_paths = Array[NodePath]([NodePath("%sLeafNorth"), NodePath("%sLeafSouth")])',
	"leaf_open_angles = PackedFloat32Array(90, -90)",
	'status_light_paths = Array[NodePath]([NodePath("%sLampWest"), NodePath("%sLampEast")])',
]

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
	for shelf in SHELVES:
		_set_props('[node name="Books" type="Node3D" parent="NavigationRegion3D/Upper/F_RestrictedArchive/%s"' % shelf, BOOKS, shelf + "/Books")
	_wire_g3()
	level.queue_free()
	if _changes.is_empty():
		print("fixes_x15: nothing to change")
	else:
		for c in _changes:
			print("fixes_x15: ", c)
		if not dry:
			var f := FileAccess.open(SCENE, FileAccess.WRITE)
			f.store_string(_text)
			f.close()
			print("fixes_x15: wrote %s" % SCENE)
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
	if not _inside(c, ARCHIVE) or c.y < 4.3 or c.y > 8.3:
		return null
	if hex == "6b211c" and _near(Vector3(v.x, v.y, 0), Vector3(0.03, 1.0, 0)):
		return WALNUT          # wainscot
	if hex == "991f1a" and _near(Vector3(v.x, v.y, 0), Vector3(0.06, 0.06, 0)):
		return WALNUT_DARK     # dado rails
	if hex == "991f1a" and (_near(v, Vector3(0.16, 0.38, 2.6)) or _near(v, Vector3(0.14, 0.42, 2.32))):
		return WALNUT_DARK     # G2 / G3 frames
	if hex == "5c3d24" and absf(c.x - 28.0) < 0.05 and (_near(v, Vector3(0.16, 0.38, 2.6)) or _near(v, Vector3(0.14, 0.42, 2.32))):
		return VAULT_STEEL     # the vault doorway's frame
	if hex == "472e1a" and _near(v, Vector3(0.6, 2.4, 4.5)):
		return WALNUT          # archive shelves
	if hex == "472e1a" and _near(v, Vector3(0.04, 0.66, 4.56)):
		return WALNUT_DARK     # their caps
	if _near(Vector3(c.x, 0, c.z), Vector3(20.0, 0, -9.4)) or absf(c.x - 20.0) < 1.3 and absf(c.z + 9.4) < 0.7:
		if hex == "543821" and _near(v, Vector3(0.8, 1.2, 4.0)):
			return "remove"    # reading table body
		if hex == "8c5e36" and _near(v, Vector3(0.06, 1.28, 4.08)):
			return "remove"    # its top
		if hex == "33618c":
			return "remove"    # its book
	if absf(c.x - 32.0) < 1.2 and absf(c.z + 25.0) < 0.7 and (hex == "8c8780" or hex == "b88f3d"):
		return "remove"        # the vault pedestal (stone, brass top)
	if absf(c.x - 32.5) < 1.2 and absf(c.z + 15.5) < 1.2 and (hex == "664d2e" or hex == "b88f3d"):
		return "remove"        # the alcove crate (body, bands)
	if hex == "731c1c" and absf(c.z + 11.0) < 0.1 and v.x < 0.02:
		return "remove"        # the hall's red runner strips
	if hex == "dbcc9e" and absf(c.x - 34.35) < 0.1:
		return MAT_TOP         # the S2 top mat
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
		push_error("fixes_x15: missing %s" % header)
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
		push_error("fixes_x15: missing %s" % header)
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


func _wire_g3() -> void:
	var b := _block(G3)
	if b.is_empty():
		return
	var block := _text.substr(b[0], b[1] - b[0])
	if block.contains("\nleaf_paths = "):
		return
	var lines: PackedStringArray = []
	for p in G3_PROPERTIES:
		lines.append(p.replace("%s", G3_DRESSING))
	var script_line := block.find("\nscript = ")
	var at: int = b[0] + block.find("\n", script_line + 1)
	_text = _text.substr(0, at) + "\n" + "\n".join(lines) + _text.substr(at)
	_changes.append("archive back gate G3: steel leaves and status lamps")


func _f(x: float) -> String:
	var s := "%.6f" % x
	s = s.rstrip("0").rstrip(".")
	return "0" if s == "-0" else s
