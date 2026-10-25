extends SceneTree

## Expanded Library, archive front gate polish (approved by the owner): G2 in the back
## gate's style. A minimal text patch of the existing scene,
## scenes/level/expanded_library.tscn (the level's builder is frozen; see fixes_x7.gd):
## the front gate G2 draws the expansion's steel leaves, status lamps and card reader LED
## (built by build_expansion.gd: _dress_archive_gate; AccessDoor leaf_paths, as G3 and
## the lobby's G4). No collision, guard, route or navmesh change.
##
##   godot --headless --path . --script res://tools/expanded/expansion/fixes_x18.gd [-- --dry-run]
## Idempotent: running it again changes nothing. Exits with 0 on success.

const SCENE := "res://scenes/level/expanded_library.tscn"
const G2 := '[node name="ArchiveFrontGateG2" type="Area3D" parent="Gameplay"'
const DRESSING := "../../Expansion/Gameplay/ArchiveFrontGateDressing/"
const PROPERTIES := [
	'leaf_paths = Array[NodePath]([NodePath("%sLeafNorth"), NodePath("%sLeafSouth")])',
	"leaf_open_angles = PackedFloat32Array(90, -90)",
	'status_light_paths = Array[NodePath]([NodePath("%sLampWest"), NodePath("%sLampEast"), NodePath("%sCardReader/Led")])',
]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var dry := "--dry-run" in OS.get_cmdline_user_args()
	var text := FileAccess.get_file_as_string(SCENE)
	var start := text.find(G2)
	if start < 0:
		push_error("fixes_x18: missing %s" % G2)
		quit(1)
		return
	var end := text.find("\n[", start + 1)
	var block := text.substr(start, end - start)
	if block.contains("\nleaf_paths = "):
		print("fixes_x18: nothing to change")
		quit(0)
		return
	var lines: PackedStringArray = []
	for p in PROPERTIES:
		lines.append(p.replace("%s", DRESSING))
	var script_line := block.find("\nscript = ")
	var at: int = start + block.find("\n", script_line + 1)
	text = text.substr(0, at) + "\n" + "\n".join(lines) + text.substr(at)
	print("fixes_x18: archive front gate G2: steel leaves, status lamps and the card reader LED")
	if not dry:
		var f := FileAccess.open(SCENE, FileAccess.WRITE)
		f.store_string(text)
		f.close()
		print("fixes_x18: wrote %s" % SCENE)
	quit(0)
