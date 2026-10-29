extends SceneTree

## Expanded Library, surface detail polish (phase B, approved by the owner): the level's
## plain batched boxes (floors, walls, wainscot, ceilings and furniture boxes drawn by
## BatchedBoxes in their own colours) use the surface detail material,
## maps/library/assets/materials/surface_detail.tres (their colour times a subtle
## texture by rule; written by make_surface_detail.gd), as the expansion's do. A minimal
## text patch of the existing scene, maps/library/scenes/expanded_library.tscn (the
## level's builder is frozen; see fixes_x7.gd): the scene's plain vertex-colour material
## is replaced by that one. No colour, collision, guard, route or navmesh change.
##
##   godot --headless --path . --script res://maps/library/tools/expansion/fixes_x22.gd [-- --dry-run]
## Idempotent: running it again changes nothing. Exits with 0 on success.

const SCENE := "res://maps/library/scenes/expanded_library.tscn"
const MATERIAL := "res://maps/library/assets/materials/surface_detail.tres"
const EXT_ID := "surface_detail"
const OLD := 'SubResource("Material_batched_plain")'
const OLD_HEADER := '[sub_resource type="StandardMaterial3D" id="Material_batched_plain"]'


func _init() -> void:
	var dry := "--dry-run" in OS.get_cmdline_user_args()
	var text := FileAccess.get_file_as_string(SCENE)
	var changes: Array[String] = []
	if not text.contains('id="%s"]' % EXT_ID):
		var last := text.rfind("\n[ext_resource ")
		var at := text.find("\n", last + 1)
		text = text.substr(0, at) + '\n[ext_resource type="Material" path="%s" id="%s"]' % [MATERIAL, EXT_ID] + text.substr(at)
		changes.append("surface detail material added")
	var uses := text.count(OLD)
	if uses > 0:
		text = text.replace(OLD, 'ExtResource("%s")' % EXT_ID)
		changes.append("%d plain batches now use it" % uses)
	var start := text.find(OLD_HEADER)
	if start >= 0:
		var end := text.find("\n[", start + 1)
		text = text.substr(0, start) + text.substr(end + 1)
		changes.append("the old plain material removed")
	if changes.is_empty():
		print("fixes_x22: nothing to change")
	else:
		for c in changes:
			print("fixes_x22: ", c)
		if not dry:
			var f := FileAccess.open(SCENE, FileAccess.WRITE)
			f.store_string(text)
			f.close()
			print("fixes_x22: wrote %s" % SCENE)
	quit(0)
