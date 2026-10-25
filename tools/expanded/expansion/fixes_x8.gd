extends SceneTree

## Expanded Library, loading dock polish (approved by the owner): a minimal text
## patch of the existing scene, scenes/level/expanded_library.tscn (the level's
## builder is frozen; see fixes_x7.gd). The expansion builds the new roller
## shutter, its frame and the wall over the door; this hides what they replace:
##
##   1. The red shutter panel's mesh (ExitDoorPanel/Mesh). The panel itself, its
##      collision and its open / closed switching are unchanged.
##   2. The glowing green header over the dock door (its one-box batch,
##      Batch_6_4_exit_L4_S1). The header's collision body is unchanged; the
##      expansion draws the wall in its place.
##   3. The exit's floating sign (ExitDoor show_sign = false); the shutter
##      control's screen shows the state.
##
##   godot --headless --path . --script res://tools/expanded/expansion/fixes_x8.gd [-- --dry-run]
## Idempotent: running it again changes nothing. Exits with 0 on success.

const SCENE := "res://scenes/level/expanded_library.tscn"
const PATCHES := [
	['[node name="Mesh" type="MeshInstance3D" parent="NavigationRegion3D/Ground/D_ServiceCorridor/ExitDoorPanel"', "visible = false", "the dock shutter panel's mesh hidden"],
	['[node name="Batch_6_4_exit_L4_S1" type="MultiMeshInstance3D" parent="NavigationRegion3D/Ground/Batched"', "visible = false", "the green header over the dock door hidden"],
	['[node name="ExitDoor" type="Area3D" parent="Gameplay"', "show_sign = false", "the dock exit's floating sign hidden"],
]

var _text := ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var dry := "--dry-run" in OS.get_cmdline_user_args()
	_text = FileAccess.get_file_as_string(SCENE)
	var changes: Array[String] = []
	for p in PATCHES:
		var start := _text.find(p[0])
		if start < 0:
			push_error("fixes_x8: node missing: %s" % p[0])
			quit(1)
			return
		var line_end := _text.find("\n", start)
		var end := _text.find("\n[", start + 1)
		var block := _text.substr(start, end - start)
		if block.contains("\n" + p[1] + "\n") or block.ends_with("\n" + p[1]):
			continue
		# After the node's `script = ` line if it has one (a script's property set before it is dropped).
		var at := line_end
		var script_line := block.find("\nscript = ")
		if script_line >= 0:
			at = start + block.find("\n", script_line + 1)
		_text = _text.substr(0, at) + "\n" + p[1] + _text.substr(at)
		changes.append(p[2])
	if changes.is_empty():
		print("fixes_x8: nothing to change")
	else:
		for c in changes:
			print("fixes_x8: ", c)
		if not dry:
			var f := FileAccess.open(SCENE, FileAccess.WRITE)
			f.store_string(_text)
			f.close()
			print("fixes_x8: wrote %s" % SCENE)
	quit(0)
