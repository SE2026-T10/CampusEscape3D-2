extends SceneTree

## Expanded Library, storage room polish (approved by the owner): a minimal text
## patch of the existing scene, scenes/level/expanded_library.tscn (the level's
## builder is frozen; see fixes_x7.gd). The expansion builds the new shelving
## and the S2 staff stair's dressing; this makes room for them, in the level's
## batches only (no collision, guard, route or navmesh change):
##
##   1. The four storage racks' old look (grey frame and cardboard boxes, 40
##      boxes in the ground floor's batches) is removed; the racks' collision
##      bodies (Rack57–Rack60) stay. Their boxes are only shared out of the
##      batches, every other box keeps its exact text.
##   2. The S2 staff stair is recoloured as a steel stair: the step fillers dark
##      (the storage cage's backing), the side panels galvanised grey, their caps
##      safety yellow, the ramp's surface steel. Its cream nosing is hidden
##      (Ramp/Nosing); the expansion draws yellow nosing in its place.
##
##   godot --headless --path . --script res://tools/expanded/expansion/fixes_x9.gd [-- --dry-run]
## Idempotent: running it again changes nothing. Exits with 0 on success.

const SCENE := "res://scenes/level/expanded_library.tscn"
const PARENT := "NavigationRegion3D/Ground/Batched"
const RACKS := [[20, -2, 22, 0], [20, 6, 22, 8], [26, -2, 28, 0], [26, 6, 28, 8]]
const RACK_COLOURS := ["8c6b40", "9e7a4d", "6b7078"]
## The S2 stair's footprint (x0, x1, z0, z1) and its recolouring (old colour → new).
const STAIR := [32.7, 35.9, -6.2, 4.2]
const RECOLOUR := {
	"472e1a": Color(0.2, 0.21, 0.22),    # step fillers: the cage's dark backing
	"54361f": Color(0.56, 0.58, 0.59),   # side panels: galvanised
	"b88f3d": Color(0.9, 0.72, 0.1),     # panel caps: safety yellow
	"735438": Color(0.45, 0.46, 0.47),   # ramp surface: steel tread
}
const NOSING := '[node name="Nosing" type="MultiMeshInstance3D" parent="NavigationRegion3D/Stairs/S2_S2StaffStair/Ramp"'

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
			_patch_batch(b)
	_hide_nosing()
	level.queue_free()
	if _changes.is_empty():
		print("fixes_x9: nothing to change")
	else:
		for c in _changes:
			print("fixes_x9: ", c)
		if not dry:
			var f := FileAccess.open(SCENE, FileAccess.WRITE)
			f.store_string(_text)
			f.close()
			print("fixes_x9: wrote %s" % SCENE)
	quit(0)


func _patch_batch(node: BatchedBoxes) -> void:
	var remove: Array[int] = []
	var recolour := {}   # index -> Color
	for i in node.box_count():
		var c := (node.global_transform * node.box_transform(i)).origin
		var hex := node.box_color(i).to_html(false)
		if hex in RACK_COLOURS and c.y < 2.2:
			for r in RACKS:
				if c.x > r[0] - 0.1 and c.x < r[2] + 0.1 and c.z > r[1] - 0.1 and c.z < r[3] + 0.1:
					remove.append(i)
					break
		elif RECOLOUR.has(hex) and c.x > STAIR[0] and c.x < STAIR[1] and c.z > STAIR[2] and c.z < STAIR[3] and c.y < 5.6:
			recolour[i] = RECOLOUR[hex]
	if remove.is_empty() and recolour.is_empty():
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
	_changes.append("%s: %d rack boxes removed, %d stair boxes recoloured" % [node.name, remove.size(), recolour.size()])


func _hide_nosing() -> void:
	var start := _text.find(NOSING)
	var end := _text.find("\n[", start + 1)
	var block := _text.substr(start, end - start)
	if block.contains("\nvisible = false"):
		return
	var script_line := block.find("\nscript = ")
	var at := start + block.find("\n", script_line + 1)
	_text = _text.substr(0, at) + "\nvisible = false" + _text.substr(at)
	_changes.append("S2 stair's cream nosing hidden")


func _f(x: float) -> String:
	var s := "%.6f" % x
	s = s.rstrip("0").rstrip(".")
	return "0" if s == "-0" else s
