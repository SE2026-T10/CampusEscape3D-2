extends SceneTree

## Expanded Library, service corridor polish (approved by the owner): back-of-house
## utility. A minimal text patch of the existing scene, scenes/level/expanded_library.tscn
## (the level's builder is frozen; see fixes_x7.gd). The expansion builds the new dressing
## (build_expansion.gd: _build_service_corridor); this makes room for it. No collision,
## guard, route or navmesh change here:
##
##   1. The corridor's floor becomes pale sheet vinyl (seams and safety lines on top,
##      from the expansion); its red wainscot a grey-green painted band, the rails on top
##      dark grey; the processing, storage and dock door frames steel grey (G4 and SC1
##      keep their colours).
##   2. The corridor's round light fixtures are hidden and the pendant rods of the south
##      part removed (strip lights in their place; the lamps themselves are unchanged).
##
##   godot --headless --path . --script res://tools/expanded/expansion/fixes_x17.gd [-- --dry-run]
## Idempotent: running it again changes nothing. Exits with 0 on success.

const SCENE := "res://scenes/level/expanded_library.tscn"
const PARENTS := ["NavigationRegion3D/Ground/Batched", "Dressing/Batched"]

const CORRIDOR := [12.14, -27.86, 16.86, 27.86]   # inside (x0, z0, x1, z1), y −0.3…2.7

const VINYL := Color(0.56, 0.57, 0.55)
const BAND := Color(0.42, 0.5, 0.46)
const RAIL := Color(0.25, 0.27, 0.28)
const STEEL := Color(0.45, 0.47, 0.5)

const LIGHTS := ["D_ServiceCorridor_0", "D_ServiceCorridor_1", "D_ServiceCorridor_2", "D_ServiceCorridor_3", "D_ServiceCorridor_4", "D_ServiceCorridor_5"]

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
	level.queue_free()
	if _changes.is_empty():
		print("fixes_x17: nothing to change")
	else:
		for c in _changes:
			print("fixes_x17: ", c)
		if not dry:
			var f := FileAccess.open(SCENE, FileAccess.WRITE)
			f.store_string(_text)
			f.close()
			print("fixes_x17: wrote %s" % SCENE)
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
	if hex == "1a1a1c" and _near(v, Vector3(0.03, 0.03, 3.3)) and absf(c.x - 14.5) < 0.05 and c.z > -28.0 and c.z < 28.0:
		return "remove"        # the south part's pendant rods
	var frame := _near(v, Vector3(0.16, 0.38, 2.6)) or _near(v, Vector3(0.14, 0.42, 2.32)) or _near(v, Vector3(0.14, 0.42, 3.32))
	if hex == "5c3d24" and frame and absf(c.x - 17.0) < 0.05 and c.z > -28.0 and c.z < 28.0:
		return STEEL           # processing, storage and dock door frames
	if not _inside(c, CORRIDOR) or c.y < -0.3 or c.y > 2.7:
		return null
	if hex == "4d5461" and _near(v, Vector3(0.2, 5.0, 5.6)):
		return VINYL           # floors
	if hex == "6b211c" and _near(Vector3(v.x, v.y, 0), Vector3(0.03, 1.0, 0)):
		return BAND            # wainscot
	if hex == "991f1a" and _near(Vector3(v.x, v.y, 0), Vector3(0.06, 0.06, 0)):
		return RAIL            # dado rails
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
		push_error("fixes_x17: missing %s" % header)
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
		push_error("fixes_x17: missing %s" % header)
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
