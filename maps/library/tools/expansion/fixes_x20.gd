extends SceneTree

## Expanded Library, lobby Kenney furniture polish (approved by the owner): the
## circulation desk's computers become Kenney models (built by build_expansion.gd:
## _build_lobby). A minimal text patch of the existing scene,
## maps/library/scenes/expanded_library.tscn (the level's builder is frozen; see
## fixes_x7.gd): the level's own monitor screen on the desk (x 2.8, the staff side) is
## removed. No collision, guard, route or navmesh change here.
##
##   godot --headless --path . --script res://maps/library/tools/expansion/fixes_x20.gd [-- --dry-run]
## Idempotent: running it again changes nothing. Exits with 0 on success.

const SCENE := "res://maps/library/scenes/expanded_library.tscn"
const PARENTS := ["NavigationRegion3D/Ground/Batched", "Dressing/Batched"]

const SCREEN_AT := Vector3(2.8, 1.3, 15.8)

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
		print("fixes_x20: nothing to change")
	else:
		for c in _changes:
			print("fixes_x20: ", c)
		if not dry:
			var f := FileAccess.open(SCENE, FileAccess.WRITE)
			f.store_string(_text)
			f.close()
			print("fixes_x20: wrote %s" % SCENE)
	quit(0)


func _sorted(xf: Transform3D) -> Vector3:
	var s := [xf.basis.x.length(), xf.basis.y.length(), xf.basis.z.length()]
	s.sort()
	return Vector3(s[0], s[1], s[2])


func _near(v: Vector3, w: Vector3) -> bool:
	return v.distance_to(w) < 0.01


## "remove", a Color (recolour) or null for a box.
func _rule(c: Vector3, hex: String, v: Vector3) -> Variant:
	if hex == "264d6b" and _near(c, SCREEN_AT) and _near(v, Vector3(0.04, 0.32, 0.5)):
		return "remove"        # the desk's monitor screen
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
		push_error("fixes_x20: missing %s" % header)
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
		push_error("fixes_x20: missing %s" % header)
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
