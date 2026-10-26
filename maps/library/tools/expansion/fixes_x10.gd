extends SceneTree

## Expanded Library, lobby polish (approved by the owner): a minimal text patch
## of the existing scene, scenes/level/expanded_library.tscn (the level's builder
## is frozen; see fixes_x7.gd). No collision, guard, route or navmesh change:
##
##   1. The S1 main stair is recoloured as a wooden stair: the step fillers wood
##      panelling, the side panels dark panelled wood, their caps brass, the
##      ramp's surface a red carpet. Its cream nosing is hidden (Ramp/Nosing);
##      the expansion draws brass nosing in its place.
##   2. The lobby staff door G4 draws two wooden leaves (built by the expansion,
##      Expansion/Gameplay/LobbyStaffDoorDressing) that swing into the service
##      corridor, and its card reader LED and light strip show its state; the
##      panel keeps its collision (AccessDoor leaf_paths, status_light_paths).
##
##   godot --headless --path . --script res://maps/library/tools/expansion/fixes_x10.gd [-- --dry-run]
## Idempotent: running it again changes nothing. Exits with 0 on success.

const SCENE := "res://maps/library/scenes/expanded_library.tscn"
const PARENT := "NavigationRegion3D/Ground/Batched"
## The S1 stair's footprint (x0, x1, z0, z1; clear of the wall art on the west wall) and its recolouring.
const STAIR := [-11.0, -8.7, 9.8, 20.3]
const RECOLOUR := {
	"472e1a": Color(0.42, 0.27, 0.16),   # step fillers: wood panelling
	"54361f": Color(0.33, 0.2, 0.12),    # side panels: dark panelled wood
	"b88f3d": Color(0.76, 0.6, 0.27),    # panel caps: brass
	"735438": Color(0.45, 0.11, 0.12),   # ramp surface: red carpet
}
const NOSING := '[node name="Nosing" type="MultiMeshInstance3D" parent="NavigationRegion3D/Stairs/S1_S1MainStair/Ramp"'
const G4 := '[node name="LobbyStaffDoorG4" type="Area3D" parent="Gameplay"'
const G4_DRESSING := "../../Expansion/Gameplay/LobbyStaffDoorDressing/"
const G4_PROPERTIES := [
	'leaf_paths = Array[NodePath]([NodePath("%sLeafNorth"), NodePath("%sLeafSouth")])',
	"leaf_open_angles = PackedFloat32Array(90, -90)",
	'status_light_paths = Array[NodePath]([NodePath("%sStatusStrip"), NodePath("%sCardReader/Led")])',
	"found_colour = Color(0.4, 0.27, 0.16, 1)",
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
			_patch_batch(b)
	_hide_nosing()
	_g4_door()
	level.queue_free()
	if _changes.is_empty():
		print("fixes_x10: nothing to change")
	else:
		for c in _changes:
			print("fixes_x10: ", c)
		if not dry:
			var f := FileAccess.open(SCENE, FileAccess.WRITE)
			f.store_string(_text)
			f.close()
			print("fixes_x10: wrote %s" % SCENE)
	quit(0)


func _patch_batch(node: BatchedBoxes) -> void:
	var remove: Array[int] = []
	var recolour := {}   # index -> Color
	for i in node.box_count():
		var xf := node.global_transform * node.box_transform(i)
		var c := xf.origin
		var hex := node.box_color(i).to_html(false)
		if xf.basis.x.length() > 3.1:
			continue   # longer than the stair is wide: a trim, not part of it
		if RECOLOUR.has(hex) and c.x > STAIR[0] and c.x < STAIR[1] and c.z > STAIR[2] and c.z < STAIR[3] and c.y < 5.6:
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
	_changes.append("%s: %d stair boxes recoloured" % [node.name, recolour.size()])


func _hide_nosing() -> void:
	var start := _text.find(NOSING)
	var end := _text.find("\n[", start + 1)
	var block := _text.substr(start, end - start)
	if block.contains("\nvisible = false"):
		return
	var script_line := block.find("\nscript = ")
	var at := start + block.find("\n", script_line + 1)
	_text = _text.substr(0, at) + "\nvisible = false" + _text.substr(at)
	_changes.append("S1 stair's cream nosing hidden")


func _g4_door() -> void:
	var start := _text.find(G4)
	var end := _text.find("\n[", start + 1)
	var block := _text.substr(start, end - start)
	if block.contains("\nleaf_paths = "):
		return
	var script_line := block.find("\nscript = ")
	var at := start + block.find("\n", script_line + 1)
	var lines: PackedStringArray = []
	for p in G4_PROPERTIES:
		lines.append(p.replace("%s", G4_DRESSING))
	_text = _text.substr(0, at) + "\n" + "\n".join(lines) + _text.substr(at)
	_changes.append("lobby staff door G4: wooden leaves and status lights")


func _f(x: float) -> String:
	var s := "%.6f" % x
	s = s.rstrip("0").rstrip(".")
	return "0" if s == "-0" else s
