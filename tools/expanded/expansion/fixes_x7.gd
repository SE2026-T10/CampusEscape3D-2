extends SceneTree

## Expanded Library expansion, Phase 9 follow-up (approved by the owner): a
## minimal text patch of the existing scene, scenes/level/expanded_library.tscn
## (the level's builder is frozen; see cut_doorways.py):
##
##   1. Lights per mesh (item 11). Two ground-floor batches of the existing
##      level were reached by 9 lights (the renderer draws at most 8 per mesh;
##      the 9th is one of the expansion's annex lamps, whose range cube reaches
##      across the annex wall): each is split, along its longer side, until no
##      piece is reached by more than 8. The boxes are kept exactly (same text),
##      only shared out between nodes; the first piece keeps the node's name and id.
##   2. Small upper-floor props on render layer 1 (actors) were lit by the
##      ground and basement lamps below them too (up to 11 lights): the staff
##      access card's model, the Staff Offices checkpoint pad, the upper stacks
##      hiding spot's floor mark and Office 2's chair (an instanced prop) go to
##      the upper floor's layer (8), lit by the upper floor's lamps only.
##   3. Staff Offices respawn (P1c). The checkpoint's pad stays in front of the
##      card desk (taking the card always saves), its respawn point moves from
##      the back of Office 2 to the back of Office 1, facing the door: the way
##      out by the stacks staff door G1b and the quiet back stair S3, away from
##      the balcony and the archive gate where the playtests were caught most.
##
##   godot --headless --path . --script res://tools/expanded/expansion/fixes_x7.gd [-- --dry-run]
## Idempotent: running it again changes nothing. Exits with 0 on success.

const SCENE := "res://scenes/level/expanded_library.tscn"
const MAX_LIGHTS := 8
const BATCHES := [
	["NavigationRegion3D/Ground/Batched", "Batch_1_0_plain_L4_S0"],
	["NavigationRegion3D/Ground/Batched", "Batch_5_2_plain_L4_S0"],
]
const UPPER_LAYER := 8
const UPPER_PROPS := ["Gameplay/StaffAccessCard/Model/Mesh", "Gameplay/CheckpointStaffOffices/Pad",
	"Gameplay/HidingSpots/Upperstacksaisle/FloorMark"]
const UPPER_INSTANCE := "Dressing/Props/Chair25"
const UPPER_INSTANCE_PARTS := ["Legs", "Seat", "Back"]
## Staff Offices respawn: the back of Office 1 (x -6…0), beside its desk, facing north (the door).
const STAFF_SPAWN := Vector3(-1.8, 4.5, -26.3)

var _text := ""
var _changes: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var dry := "--dry-run" in OS.get_cmdline_user_args()
	_text = FileAccess.get_file_as_string(SCENE)
	var level: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(level)
	var lights := []
	for l in level.find_children("*", "OmniLight3D", true, false):
		var omni := l as OmniLight3D
		lights.append([AABB(omni.global_position - Vector3.ONE * omni.omni_range, Vector3.ONE * omni.omni_range * 2.0), omni.light_cull_mask])
	for b in BATCHES:
		_split_batch(level, b[0], b[1], lights)
	for p in UPPER_PROPS:
		_set_layers(p)
	_set_instance_layers()
	_move_staff_spawn(level)
	level.queue_free()
	if _changes.is_empty():
		print("fixes_x7: nothing to change")
	else:
		for c in _changes:
			print("fixes_x7: ", c)
		if not dry:
			var f := FileAccess.open(SCENE, FileAccess.WRITE)
			f.store_string(_text)
			f.close()
			print("fixes_x7: wrote %s" % SCENE)
	quit(0)


# --- 1. Lights per mesh --------------------------------------------------------------------

func _split_batch(level: Node, parent: String, node_name: String, lights: Array) -> void:
	var node := level.get_node_or_null(parent + "/" + node_name) as BatchedBoxes
	if node == null:
		push_error("fixes_x7: %s/%s missing" % [parent, node_name])
		quit(1)
		return
	var items := []   # [index, world AABB]
	for i in node.box_count():
		items.append([i, node.global_transform * (node.box_transform(i) * AABB(-Vector3.ONE / 2.0, Vector3.ONE))])
	var pieces := _split(items, node.layers, lights)
	if pieces.size() == 1:
		return
	# The node's text block and its box values, exactly as saved.
	var header := '[node name="%s" type="MultiMeshInstance3D" parent="%s"' % [node_name, parent]
	var start := _text.find(header)
	var end := _text.find("\n[", start + 1)
	var block := _text.substr(start, end - start)
	var key := "boxes = PackedFloat32Array("
	var vs := block.find(key) + key.length()
	var ve := block.find(")", vs)
	var values := block.substr(vs, ve - vs).split(", ")
	var stride := BatchedBoxes.STRIDE
	var blocks: PackedStringArray = []
	for k in pieces.size():
		var picked: PackedStringArray = []
		for it in pieces[k]:
			var i: int = it[0]
			picked.append_array(values.slice(i * stride, (i + 1) * stride))
		var b := block.substr(0, vs) + ", ".join(picked) + block.substr(ve)
		if k > 0:
			var first_line := b.find("\n")
			b = '[node name="%s_%d" type="MultiMeshInstance3D" parent="%s" unique_id=%d]' % [node_name, k, parent,
				_new_id("%s/%s_%d" % [parent, node_name, k])] + b.substr(first_line)
		blocks.append(b)
	_text = _text.substr(0, start) + "\n".join(blocks) + _text.substr(end)
	_changes.append("%s/%s: %d boxes split into %d pieces (%s boxes)" % [parent, node_name, items.size(), pieces.size(),
		"+".join(pieces.map(func(p): return str(p.size())))])


func _split(items: Array, layers: int, lights: Array) -> Array:
	var bounds: AABB = items[0][1]
	for it in items:
		bounds = bounds.merge(it[1])
	var reached := 0
	for l in lights:
		if (l[1] & layers) != 0 and (l[0] as AABB).intersects(bounds):
			reached += 1
	if reached <= MAX_LIGHTS or items.size() == 1:
		return [items]
	var axis := 0 if bounds.size.x >= bounds.size.z else 2
	var sorted := items.duplicate()
	sorted.sort_custom(func(a, b): return (a[1] as AABB).get_center()[axis] < (b[1] as AABB).get_center()[axis])
	var half := sorted.size() / 2
	return _split(sorted.slice(0, half), layers, lights) + _split(sorted.slice(half), layers, lights)


## A unique_id not used in the scene (deterministic, from the node's path).
func _new_id(path: String) -> int:
	var id := absi(path.hash()) % 2000000000 + 1
	while _text.contains("unique_id=%d]" % id):
		id += 1
	return id


# --- 2. Upper-floor props ------------------------------------------------------------------

func _set_layers(path: String) -> void:
	var slash := path.rfind("/")
	var header := '[node name="%s" type="MeshInstance3D" parent="%s"' % [path.substr(slash + 1), path.substr(0, slash)]
	var start := _text.find(header)
	if start < 0:
		push_error("fixes_x7: %s missing" % path)
		return
	var line_end := _text.find("\n", start)
	var end := _text.find("\n[", start + 1)
	var block := _text.substr(start, end - start)
	if block.contains("\nlayers = "):
		return
	_text = _text.substr(0, line_end) + "\nlayers = %d" % UPPER_LAYER + _text.substr(line_end)
	_changes.append("%s: render layer %d" % [path, UPPER_LAYER])


## Chair25 is an instanced prop: its parts get layer overrides (editable children).
func _set_instance_layers() -> void:
	var marker := '[editable path="%s"]' % UPPER_INSTANCE
	if _text.contains(marker):
		return
	var slash := UPPER_INSTANCE.rfind("/")
	var start := _text.find('[node name="%s" parent="%s"' % [UPPER_INSTANCE.substr(slash + 1), UPPER_INSTANCE.substr(0, slash)])
	var end := _text.find("\n[", start + 1)
	var overrides := ""
	for i in UPPER_INSTANCE_PARTS.size():
		overrides += '\n[node name="%s" parent="%s" index="%d"]\nlayers = %d\n' % [UPPER_INSTANCE_PARTS[i], UPPER_INSTANCE, i, UPPER_LAYER]
	_text = _text.substr(0, end) + overrides + _text.substr(end)
	_text = _text.rstrip("\n") + "\n" + marker + "\n"
	_changes.append("%s (%s): render layer %d" % [UPPER_INSTANCE, ", ".join(UPPER_INSTANCE_PARTS), UPPER_LAYER])


# --- 3. Staff Offices respawn --------------------------------------------------------------

func _move_staff_spawn(level: Node) -> void:
	var cp := level.get_node("Gameplay/CheckpointStaffOffices") as Node3D
	var local := STAFF_SPAWN - cp.global_position + Vector3(0, 0.05, 0)
	var header := '[node name="Spawn" type="Marker3D" parent="Gameplay/CheckpointStaffOffices"'
	var start := _text.find(header)
	var line_end := _text.find("\n", start)
	var end := _text.find("\n", line_end + 1)
	var wanted := "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)" % [_f(local.x), _f(local.y), _f(local.z)]
	if _text.substr(line_end + 1, end - line_end - 1) == wanted:
		return
	_text = _text.substr(0, line_end + 1) + wanted + _text.substr(end)
	_changes.append("Staff Offices respawn: Office 1 at %s, facing the door" % STAFF_SPAWN)


func _f(x: float) -> String:
	var s := "%.4f" % x
	s = s.rstrip("0").rstrip(".")
	return "0" if s == "-0" else s
