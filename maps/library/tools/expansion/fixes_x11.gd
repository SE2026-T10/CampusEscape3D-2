extends SceneTree

## Expanded Library, no wall decor (requested by the owner): a minimal text patch
## of the existing scene, scenes/level/expanded_library.tscn (the level's builder
## is frozen; see fixes_x7.gd). The clue documents and the lobby plaque are not
## touched; no collision, guard, route or navmesh change:
##
##   1. The windows (frame, glass, sill), the posters and the clocks are removed
##      from the dressing's batches (their boxes only), and the window glass
##      batches and the Windows / Landmarks groups (the clocks' rims and faces)
##      are hidden.
##   2. The signs (Dressing/Signs) are hidden.
##
##   godot --headless --path . --script res://maps/library/tools/expansion/fixes_x11.gd [-- --dry-run]
## Idempotent: running it again changes nothing. Exits with 0 on success.

const SCENE := "res://maps/library/scenes/expanded_library.tscn"
const PARENT := "Dressing/Batched"
## Box sizes (sorted) of the window frames and sills, the posters' frames, prints and
## captions and the clocks' hands (tools/expanded/build_expanded_graybox.gd).
const WALL_DECOR_SIZES := [
	Vector3(0.04, 1.5, 1.7), Vector3(0.06, 0.12, 1.8),
	Vector3(0.03, 0.86, 1.16), Vector3(0.03, 0.74, 0.86), Vector3(0.03, 0.1, 0.6),
	Vector3(0.01, 0.04, 0.2), Vector3(0.01, 0.03, 0.28),
]
const HIDE := [
	'[node name="Signs" type="Node3D" parent="Dressing"',
	'[node name="Windows" type="Node3D" parent="Dressing"',
	'[node name="Landmarks" type="Node3D" parent="Dressing"',
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
	for b in level.get_node(PARENT).get_children():
		if b is BatchedBoxes:
			if String(b.name).contains("_window_"):
				_hide('[node name="%s" type="MultiMeshInstance3D" parent="%s"' % [b.name, PARENT], "%s (window glass)" % b.name)
			else:
				_patch_batch(b)
	for h in HIDE:
		_hide(h, h.get_slice('"', 1))
	level.queue_free()
	if _changes.is_empty():
		print("fixes_x11: nothing to change")
	else:
		for c in _changes:
			print("fixes_x11: ", c)
		if not dry:
			var f := FileAccess.open(SCENE, FileAccess.WRITE)
			f.store_string(_text)
			f.close()
			print("fixes_x11: wrote %s" % SCENE)
	quit(0)


func _is_wall_decor(xf: Transform3D) -> bool:
	var sz := [xf.basis.x.length(), xf.basis.y.length(), xf.basis.z.length()]
	sz.sort()
	var v := Vector3(sz[0], sz[1], sz[2])
	for w in WALL_DECOR_SIZES:
		if v.distance_to(w) < 0.004:
			return true
	return false


func _patch_batch(node: BatchedBoxes) -> void:
	var remove: Array[int] = []
	for i in node.box_count():
		if _is_wall_decor(node.box_transform(i)):
			remove.append(i)
	if remove.is_empty():
		return
	var header := '[node name="%s" type="MultiMeshInstance3D" parent="%s"' % [node.name, PARENT]
	var start := _text.find(header)
	var end := _text.find("\n[", start + 1)
	var block := _text.substr(start, end - start)
	var key := "boxes = PackedFloat32Array("
	var vs := block.find(key) + key.length()
	var ve := block.find(")", vs)
	var values := block.substr(vs, ve - vs).split(", ")
	var stride := BatchedBoxes.STRIDE
	var kept: PackedStringArray = []
	for i in node.box_count():
		if not i in remove:
			kept.append_array(values.slice(i * stride, (i + 1) * stride))
	_text = _text.substr(0, start) + block.substr(0, vs) + ", ".join(kept) + block.substr(ve) + _text.substr(end)
	_changes.append("%s: %d wall decor boxes removed" % [node.name, remove.size()])


func _hide(header: String, what: String) -> void:
	var start := _text.find(header)
	if start < 0:
		push_error("fixes_x11: missing %s" % header)
		return
	var end := _text.find("\n[", start + 1)
	var block := _text.substr(start, end - start)
	if block.contains("\nvisible = false"):
		return
	var script_line := block.find("\nscript = ")
	var at := start + (block.find("\n", script_line + 1) if script_line >= 0 else block.find("\n"))
	_text = _text.substr(0, at) + "\nvisible = false" + _text.substr(at)
	_changes.append("%s hidden" % what)
