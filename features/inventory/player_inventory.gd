class_name PlayerInventory
extends Node

## The player's carried items and journal (child "Inventory" of the player
## scene). The only inventory in the game: pickups, storage shelves, card
## doors, tool mechanisms and the HUD all go through this node.
##
##   - `slot_count` carried slots (3). Each item takes one slot; add() refuses
##     when they are all full, so there are never more.
##   - Tools and cards are reusable: doors and mechanisms only check has().
##     Only distractions are removed, by use_selected(), and only when the
##     throw succeeds (one item per successful use).
##   - Clue documents go to the journal, which is separate from the slots and
##     holds each document once.
##   - Items can only be left behind (or swapped) at an ItemStorage shelf.
##   - Checkpoints: the carried slots are part of the mission state (group
##     "checkpoint_state"), so being caught puts back exactly what was carried
##     at the checkpoint. Pickups and shelves are restored from the same
##     snapshot, so nothing is duplicated or lost. The journal is knowledge and
##     is kept.
## Off by default (the tutorial has no items); the Expanded Library turns it on
## with the player's use_inventory.
##
## Keys: 1–3 select a slot, F uses the selected item (throws a distraction),
## J opens the journal (ObjectiveHud).

signal changed
signal selected_changed(slot: int)
signal document_added(document: Dictionary)
## The player read a document (new or already in the journal): the HUD opens the journal at it.
signal document_opened(id: StringName)
## A short message for the HUD; `good` = green, otherwise a warning.
signal notice(text: String, good: bool)
## A distraction was thrown: where it will land.
signal thrown(item_id: StringName, landing: Vector3)

## Off: nothing can be carried and nothing is shown (the tutorial).
## Set with set_enabled() (FirstPersonPlayer.use_inventory).
var enabled := false
@export var slot_count := 3
@export_group("Throwing")
## Furthest a distraction can be thrown (metres from the camera).
@export var throw_range := 14.0
## A throw must land at least this far away (horizontally), so it isn't wasted at your feet.
@export var min_throw_distance := 2.0
## Seconds the throw takes to land (the noise is made on landing).
@export var throw_flight_time := 0.45

## Item id per slot, &"" for an empty slot.
var slots: Array[StringName] = []
var selected := 0
## Journal: {id, title, text, kind} in the order found (documents and clues).
var documents: Array[Dictionary] = []
## Distractions used up by successful throws (for tests).
var distractions_used := 0

@onready var _player: FirstPersonPlayer = get_parent() as FirstPersonPlayer


func _ready() -> void:
	add_to_group("player_inventory")
	_clear_slots()


## Turns the inventory on or off. Only a level that uses items stores them at
## checkpoints (the tutorial's checkpoint snapshots stay as they were).
func set_enabled(on: bool) -> void:
	enabled = on
	if on:
		add_to_group("checkpoint_state")
	elif is_in_group("checkpoint_state"):
		remove_from_group("checkpoint_state")


static func find(node: Node) -> PlayerInventory:
	if not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group("player_inventory") as PlayerInventory


func _unhandled_input(event: InputEvent) -> void:
	# Like the interact key: menus pause the level, so no item is used behind them.
	if not enabled or _player == null:
		return
	for i in slot_count:
		var action := "item_slot_%d" % (i + 1)
		if InputMap.has_action(action) and event.is_action_pressed(action):
			select(i)
			get_viewport().set_input_as_handled()
			return
	if InputMap.has_action("use_item") and event.is_action_pressed("use_item"):
		use_selected()
		get_viewport().set_input_as_handled()


# --- Slots -------------------------------------------------------------------------------------

## Puts `id` in the first empty slot. False if off, unknown or full.
func add(id: StringName) -> bool:
	if not enabled or not ItemCatalog.has_item(id) or is_full():
		return false
	var slot := slots.find(&"")
	slots[slot] = id
	changed.emit()
	return true


func has(id: StringName) -> bool:
	return slots.has(id)


func count() -> int:
	return slot_count - slots.count(&"")


func is_full() -> bool:
	return count() >= slot_count


func get_item(slot: int) -> StringName:
	return slots[slot] if slot >= 0 and slot < slots.size() else &""


func selected_item() -> StringName:
	return get_item(selected)


func select(slot: int) -> void:
	if slot < 0 or slot >= slot_count or slot == selected:
		return
	selected = slot
	selected_changed.emit(slot)


## The slot an item would be left from at a shelf: the selected one, or the
## first carried item if the selected slot is empty. -1 if carrying nothing.
func slot_to_leave() -> int:
	if selected_item() != &"":
		return selected
	for i in slots.size():
		if slots[i] != &"":
			return i
	return -1


## Empties `slot` and returns what was in it. Only for storage shelves and
## used distractions: reusable items are never removed any other way.
func take_from_slot(slot: int) -> StringName:
	var id := get_item(slot)
	if id == &"":
		return &""
	slots[slot] = &""
	changed.emit()
	return id


## Puts `id` into `slot` (which must be empty), for shelf swaps.
func put_in_slot(slot: int, id: StringName) -> bool:
	if not enabled or get_item(slot) != &"" or slot >= slot_count or not ItemCatalog.has_item(id):
		return false
	slots[slot] = id
	changed.emit()
	return true


func notify(text: String, good := false) -> void:
	notice.emit(text, good)


# --- Using items -------------------------------------------------------------------------------

## Uses the selected item. Distractions are thrown (and used up) if there is
## somewhere to throw them; tools and cards are never used up here: they work
## when you use a mechanism or door. Returns true if something was used.
func use_selected() -> bool:
	if not enabled:
		return false
	var id := selected_item()
	if id == &"":
		notify("Nothing in slot %d." % (selected + 1))
		return false
	match ItemCatalog.get_kind(id):
		ItemCatalog.Kind.DISTRACTION:
			return throw_selected()
		ItemCatalog.Kind.TOOL:
			notify("%s: look at a marked mechanism and press E to use it." % ItemCatalog.item_name(id))
		ItemCatalog.Kind.CARD:
			notify("%s: walk up to a staff door and press E." % ItemCatalog.item_name(id))
	return false


## Throws the selected distraction where the camera points. Used up only if
## it has somewhere to land; otherwise it stays in the slot.
func throw_selected() -> bool:
	var id := selected_item()
	if id == &"" or ItemCatalog.get_kind(id) != ItemCatalog.Kind.DISTRACTION:
		return false
	var landing = find_landing()
	if landing == null:
		notify("Nowhere to throw it there. Aim at the floor further away.")
		return false
	take_from_slot(selected)
	distractions_used += 1
	var item := ThrownItem.new()
	item.setup(id, _player.camera.global_position + _player.camera.global_basis * Vector3(0.25, -0.25, -0.4),
		landing, throw_flight_time)
	_player.get_parent().add_child(item)
	thrown.emit(id, landing)
	return true


## Where a throw from the camera would land, or null if nowhere valid: the
## first surface hit within throw_range (pulled back off a wall), dropped to
## the floor below; at least min_throw_distance away.
func find_landing() -> Variant:
	if _player == null:
		return null
	var camera := _player.camera
	var from := camera.global_position
	var direction := -camera.global_basis.z
	var space := _player.get_world_3d().direct_space_state
	var to := from + direction * throw_range
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1, [_player.get_rid()]))
	var point := to
	if not hit.is_empty():
		point = hit.position
		if hit.normal.y < 0.7:
			point -= direction * 0.3
	# Down to the floor.
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.1, point + Vector3.DOWN * 8.0, 1, [_player.get_rid()]))
	if down.is_empty() or down.normal.y < 0.7:
		return null
	var landing: Vector3 = down.position
	var flat := Vector2(landing.x - _player.global_position.x, landing.z - _player.global_position.z)
	if flat.length() < min_throw_distance:
		return null
	return landing


# --- Journal -----------------------------------------------------------------------------------

## Adds a document to the journal once. Returns false if it was already there.
## `kind`: "document" (a note or notice, shown in full) or "clue" (a short
## environmental detail, e.g. a plaque).
func add_document(id: StringName, title: String, text: String, kind := "document") -> bool:
	if has_document(id):
		return false
	var document := {"id": id, "title": title, "text": text, "kind": kind}
	documents.append(document)
	document_added.emit(document)
	return true


func open_document(id: StringName) -> void:
	if has_document(id):
		document_opened.emit(id)


func has_document(id: StringName) -> bool:
	for d in documents:
		if d.id == id:
			return true
	return false


# --- Checkpoints -------------------------------------------------------------------------------

func get_checkpoint_state() -> Dictionary:
	return {"slots": slots.duplicate(), "selected": selected}


## Puts back the carried slots as stored. Thrown items still in the air are
## discarded (the throw is undone with the rest of the progress since then).
func restore_checkpoint_state(state: Dictionary) -> void:
	_clear_slots()
	var stored: Array = state.get("slots", [])
	for i in mini(stored.size(), slot_count):
		slots[i] = StringName(stored[i])
	selected = clampi(int(state.get("selected", 0)), 0, slot_count - 1)
	for item in get_tree().get_nodes_in_group("thrown_items"):
		item.queue_free()
	changed.emit()
	selected_changed.emit(selected)


func _clear_slots() -> void:
	slots.clear()
	for i in slot_count:
		slots.append(&"")
