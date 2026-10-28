extends SceneTree

## Expanded Library, reading hall Kenney furniture polish (approved by the owner): the
## reading tables get Kenney library chairs (built by build_expansion.gd:
## _build_reading_hall). A minimal text patch of the existing scene,
## maps/library/scenes/expanded_library.tscn (the level's builder is frozen; see
## fixes_x7.gd): the level's twelve box chairs at the six reading tables
## (Dressing/Props/Chair08…Chair19, decoration without collision) are hidden. No
## collision, guard, route or navmesh change here.
##
##   godot --headless --path . --script res://maps/library/tools/expansion/fixes_x21.gd [-- --dry-run]
## Idempotent: running it again changes nothing. Exits with 0 on success.

const SCENE := "res://maps/library/scenes/expanded_library.tscn"
const CHAIRS := ["Chair08", "Chair09", "Chair10", "Chair11", "Chair12", "Chair13", "Chair14", "Chair15", "Chair16", "Chair17", "Chair18", "Chair19"]

var _text := ""
var _changes: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var dry := "--dry-run" in OS.get_cmdline_user_args()
	_text = FileAccess.get_file_as_string(SCENE)
	for chair in CHAIRS:
		_hide('[node name="%s" parent="Dressing/Props"' % chair, chair)
	if _changes.is_empty():
		print("fixes_x21: nothing to change")
	else:
		for c in _changes:
			print("fixes_x21: ", c)
		if not dry:
			var f := FileAccess.open(SCENE, FileAccess.WRITE)
			f.store_string(_text)
			f.close()
			print("fixes_x21: wrote %s" % SCENE)
	quit(0)


func _block(header: String) -> Array:
	var start := _text.find(header)
	if start < 0:
		push_error("fixes_x21: missing %s" % header)
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
