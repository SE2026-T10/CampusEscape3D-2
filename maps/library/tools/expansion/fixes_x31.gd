extends SceneTree

## Expanded Library, the S2 staff stair as a steel stair (polish, requested by the owner on
## 2026-11-02): a minimal text patch of the existing scene,
## scenes/level/expanded_library.tscn (the level's builder is frozen; see fixes_x7.gd).
## The expansion builds the stair's new dressing (build_expansion.gd _dress_s2: steel treads
## and risers, a stringer and a guardrail, hazard stripes); this makes room for it, in the
## level's batches only (no collision, guard, route or navmesh change):
##
##   1. The open (west) side's stepped panels and their yellow caps are removed (their
##      Handrail bodies stay, under the new guardrail).
##   2. The east wall's red wainscot and dado rail stop at the stair's foot (z 4) instead of
##      running on behind the steps (they ran 16 m, z −6…10; now z 4…10).
##   3. The cream mat at the foot becomes rubber grey, like the one at the top.
##
##   godot --headless --path . --script res://maps/library/tools/expansion/fixes_x31.gd [-- --dry-run]
## Idempotent: running it again changes nothing. Exits with 0 on success.

const SCENE := "res://maps/library/scenes/expanded_library.tscn"
const PARENTS := ["NavigationRegion3D/Ground/Batched", "Dressing/Batched"]
## The S2 stair's footprint (x0, z0, x1, z1) with its foot mat.
const S2 := [32.7, -6.2, 35.95, 5.0]
const PANEL := "8f9496"      # the side panels (galvanised, fixes_x9.gd)
const CAP := "e6b81a"        # their caps (safety yellow, fixes_x9.gd)
const MAT := "dbcc9e"        # the cream foot mat
const MAT_RUBBER := Color(0.2, 0.2, 0.21)
const WAINSCOT := ["6b211c", "991f1a"]   # the east wall's wainscot and dado rail
const WALL_X := 35.8
## Where the wainscot now runs (z), from the stair's foot.
const WAINSCOT_Z := [4.0, 10.0]

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
		print("fixes_x31: nothing to change")
	else:
		for c in _changes:
			print("fixes_x31: ", c)
		if not dry:
			var f := FileAccess.open(SCENE, FileAccess.WRITE)
			f.store_string(_text)
			f.close()
			print("fixes_x31: wrote %s" % SCENE)
	quit(0)


func _inside(c: Vector3, r: Array) -> bool:
	return c.x > r[0] and c.x < r[2] and c.z > r[1] and c.z < r[3]


## "remove", a Color (recolour), a Transform3D (new world transform) or null for a box.
func _rule(xf: Transform3D, hex: String) -> Variant:
	var c := xf.origin
	var size := Vector3(xf.basis.x.length(), xf.basis.y.length(), xf.basis.z.length())
	if _inside(c, S2) and c.y < 6.0:
		if hex == PANEL and absf(c.x - 32.85) < 0.02 and absf(size.x - 0.1) < 0.01:
			return "remove"
		if hex == CAP and absf(c.x - 32.85) < 0.02:
			return "remove"
		if hex == MAT and c.y < 0.1:
			return MAT_RUBBER
	if hex in WAINSCOT and c.x > WALL_X and c.x < 35.9 and absf(c.z - 2.0) < 0.01 and absf(size.z - 16.0) < 0.01:
		var length: float = WAINSCOT_Z[1] - WAINSCOT_Z[0]
		var out := xf
		out.basis.z = xf.basis.z.normalized() * length
		out.origin.z = (WAINSCOT_Z[0] + WAINSCOT_Z[1]) / 2.0
		return out
	return null


func _patch_batch(node: BatchedBoxes, parent: String) -> void:
	var remove: Array[int] = []
	var changed := {}
	for i in node.box_count():
		var xf := node.global_transform * node.box_transform(i)
		var r: Variant = _rule(xf, node.box_color(i).to_html(false))
		if r is String:
			remove.append(i)
		elif r is Color or r is Transform3D:
			changed[i] = r
	if remove.is_empty() and changed.is_empty():
		return
	var header := '[node name="%s" type="MultiMeshInstance3D" parent="%s"' % [node.name, parent]
	var start := _text.find(header)
	if start < 0:
		push_error("fixes_x31: missing %s" % header)
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
		if changed.has(i) and changed[i] is Color:
			var col: Color = changed[i]
			box[12] = _f(col.r)
			box[13] = _f(col.g)
			box[14] = _f(col.b)
		elif changed.has(i):
			var local: Transform3D = node.global_transform.affine_inverse() * (changed[i] as Transform3D)
			var nums := [local.basis.x, local.basis.y, local.basis.z, local.origin]
			for k in 4:
				var v: Vector3 = nums[k]
				box[k * 3] = _f(v.x)
				box[k * 3 + 1] = _f(v.y)
				box[k * 3 + 2] = _f(v.z)
		kept.append_array(box)
	_text = _text.substr(0, start) + block.substr(0, vs) + ", ".join(kept) + block.substr(ve) + _text.substr(end)
	_changes.append("%s/%s: %d boxes removed, %d changed" % [parent, node.name, remove.size(), changed.size()])


func _f(x: float) -> String:
	var s := "%.6f" % x
	s = s.rstrip("0").rstrip(".")
	return "0" if s == "-0" else s
