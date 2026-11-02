class_name ReserveShelf
extends Puzzle

## The Study 4 reserve shelf (Expanded Library, approved by the owner on 2026-10-31), an
## optional puzzle. Three reserve books are out on return trolleys around the library;
## each goes back into its own gap on the reserve shelf, marked with its call-number range
## (the reserve slip on the wall beside it lists the books). When the third is in, the
## cabinet below the shelf opens and `reveal_paths` become available (the loading dock's
## manual release key, the reward).
##   - A gap (a ReserveGap child "Gap<i>") takes its book from the player's inventory.
##   - A wrong book is refused, quietly (shelving makes no noise, no alarm); without a
##     reserve book a gap only says which range goes there.
## Persistence (group "checkpoint_state"): which gaps are filled, and so whether it is
## solved; the books' pickups and the player's slots restore themselves, so being caught
## puts a book shelved since the last checkpoint back in the player's hands.

## The book (ItemCatalog id) each gap takes, left to right.
@export var gap_books: Array[StringName] = []
## Each gap's call-number label, e.g. "500–599 Science".
@export var gap_labels: PackedStringArray = []
## Shown (set_available) once the shelf is complete.
@export var reveal_paths: Array[NodePath] = []
## The cabinet's door (a Node3D hinged at its origin, opening about its local Y).
@export var cabinet_door_path: NodePath
@export var door_open_angle := -100.0

## Which gaps hold their book.
var filled: Array[bool] = []

var _books: Array[Node3D] = []
var _gaps: Array[ReserveGap] = []
var _door_tween: Tween
var _snap := true


func _ready() -> void:
	filled.clear()
	for i in gap_books.size():
		filled.append(false)
		var gap := get_node_or_null("Gap%d" % i) as ReserveGap
		if gap:
			_gaps.append(gap)
			_books.append(_book_model(gap, gap_books[i]))
	super()


## A book standing in the gap, spine out (hidden until shelved).
func _book_model(gap: Node3D, id: StringName) -> Node3D:
	var info: Dictionary = ItemCatalog.ITEMS.get(id, {})
	var mesh := MeshInstance3D.new()
	mesh.name = "Book"
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.27, 0.2)
	mesh.mesh = box
	mesh.position = Vector3(0, 0.135, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = info.get("colour", Color(0.5, 0.4, 0.3))
	material.roughness = 0.8
	mesh.material_override = material
	mesh.visible = false
	gap.add_child(mesh)
	return mesh


func shelved_count() -> int:
	return filled.count(true)


func gap_prompt(i: int) -> String:
	var label := gap_labels[i] if i < gap_labels.size() else "gap %d" % (i + 1)
	if filled[i]:
		return ""
	if _carried_reserve_books().is_empty():
		return "Reserve shelf, %s · empty" % label
	return "Reserve shelf, %s: shelve a reserve book" % label


func use_gap(i: int) -> bool:
	if i < 0 or i >= filled.size() or filled[i]:
		return false
	var label := gap_labels[i] if i < gap_labels.size() else "gap %d" % (i + 1)
	var inventory := PlayerInventory.find(self)
	var want := gap_books[i]
	if inventory != null and inventory.has(want):
		inventory.take_from_slot(inventory.slots.find(want))
		filled[i] = true
		if shelved_count() == filled.size():
			feedback.emit("%s shelved. The reserve shelf is complete: the cabinet below it unlocks." % ItemCatalog.item_name(want), true)
			_mark_solved()
		else:
			feedback.emit("%s shelved (%d of %d)." % [ItemCatalog.item_name(want), shelved_count(), filled.size()], true)
			_refresh()
		return true
	if not _carried_reserve_books().is_empty():
		wrong_attempts += 1
		feedback.emit("That call number doesn't belong under %s." % label, false)
		return false
	feedback.emit("Reserve shelf, %s: a reserve book goes here." % label, false)
	return false


## The reserve books the player carries that still have an empty gap.
func _carried_reserve_books() -> Array[StringName]:
	var out: Array[StringName] = []
	var inventory := PlayerInventory.find(self)
	if inventory == null:
		return out
	for i in gap_books.size():
		if not filled[i] and inventory.has(gap_books[i]):
			out.append(gap_books[i])
	return out


func _refresh() -> void:
	is_solved = not filled.is_empty() and shelved_count() == filled.size()
	for i in _gaps.size():
		_gaps[i].enabled = not filled[i]
		_books[i].visible = filled[i]
	for path in reveal_paths:
		var node := get_node_or_null(path)
		if node and node.has_method("set_available"):
			node.set_available(is_solved)
	_set_door(is_solved)
	if is_solved:
		_set_display("RESERVE SHELF\nCOMPLETE", Color(0.1, 0.42, 0.2))   # dark ink: the display is a cream card
	else:
		_set_display("RESERVE SHELF\n%d / %d BOOKS" % [shelved_count(), filled.size()], Color(0.18, 0.12, 0.06))
	_snap = false


func _set_door(open: bool) -> void:
	var door := get_node_or_null(cabinet_door_path) as Node3D
	if door == null:
		return
	var angle := deg_to_rad(door_open_angle if open else 0.0)
	if _door_tween:
		_door_tween.kill()
	if _snap or not is_inside_tree() or is_equal_approx(door.rotation.y, angle):
		door.rotation.y = angle
		return
	_door_tween = create_tween()
	_door_tween.tween_property(door, "rotation:y", angle, 0.8).set_trans(Tween.TRANS_SINE)


func get_checkpoint_state() -> Dictionary:
	return {"filled": filled.duplicate()}


func restore_checkpoint_state(state: Dictionary) -> void:
	var stored: Array = state.get("filled", [])
	for i in filled.size():
		filled[i] = i < stored.size() and bool(stored[i])
	_snap = true
	_refresh()
