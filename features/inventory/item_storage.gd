class_name ItemStorage
extends Interactable

## A storage shelf: the only places the player can leave carried items, and
## take them back or swap them.
##   - Using the shelf leaves the selected carried item (or, if that slot is
##     empty, the first carried item) in a free place on the shelf.
##   - Each stored item lies on the shelf as an ItemPickup: using it takes it
##     back, or, with full hands, swaps it for the selected carried item.
##   - The node's origin is the shelf surface; items are spaced along local X.
##   - Contents are part of the mission state (group "checkpoint_state"), so a
##     checkpoint restore puts the shelf back exactly as it was, matching the
##     player's restored slots.

@export var storage_name := "Storage shelf"
## How many items fit on the shelf.
@export var capacity := 4
## Shelf length in metres (local X); items are spread evenly along it.
@export var shelf_width := 1.6
## Items on the shelf when the level starts (ItemCatalog ids).
@export var initial_items: Array[StringName] = []

## Item id per shelf place, &"" when free.
var contents: Array[StringName] = []
var _pickups: Array[ItemPickup] = []


func _ready() -> void:
	super()
	add_to_group("checkpoint_state")
	add_to_group("item_storage")
	if prompt == "Interact":
		prompt = "Leave an item"
	if get_node_or_null("Model") == null:
		_build_model()
	if not _has_shape():
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(shelf_width, 0.08, 0.42)
		shape.shape = box
		shape.position = Vector3(0, -0.04, 0)
		add_child(shape)
	contents.clear()
	_pickups.clear()
	for i in capacity:
		contents.append(&"")
		_pickups.append(null)
	for i in mini(initial_items.size(), capacity):
		contents[i] = initial_items[i]
	_rebuild.call_deferred()


func count() -> int:
	return capacity - contents.count(&"")


func get_prompt(_by: Node) -> String:
	var inventory := PlayerInventory.find(self)
	if inventory == null or not inventory.enabled:
		return storage_name
	var slot := inventory.slot_to_leave()
	if slot < 0:
		return "%s · %d/%d stored · you carry nothing" % [storage_name, count(), capacity]
	if count() >= capacity:
		return "%s · full" % storage_name
	return "Leave the %s here (%d/%d stored)" % [ItemCatalog.item_name(inventory.get_item(slot)).to_lower(), count(), capacity]


func _on_interact(_by: Node) -> bool:
	var inventory := PlayerInventory.find(self)
	if inventory == null or not inventory.enabled:
		return false
	var slot := inventory.slot_to_leave()
	var place := contents.find(&"")
	if slot < 0 or place < 0:
		inventory.notify("%s is full." % storage_name if slot >= 0 else "You aren't carrying anything.")
		return false
	var id := inventory.take_from_slot(slot)
	contents[place] = id
	_spawn(place)
	inventory.notify("%s left on the %s" % [ItemCatalog.item_name(id), storage_name.to_lower()], true)
	return true


## Called by a shelf pickup with full hands: the selected carried item takes its place.
func swap(pickup: ItemPickup) -> bool:
	var inventory := PlayerInventory.find(self)
	var place := pickup.storage_slot
	if inventory == null or place < 0 or contents[place] != pickup.item_id:
		return false
	var slot := inventory.selected
	var carried := inventory.get_item(slot)
	if carried == &"":
		return false
	inventory.take_from_slot(slot)
	inventory.put_in_slot(slot, pickup.item_id)
	inventory.notify("Swapped the %s for the %s" % [ItemCatalog.item_name(carried).to_lower(), ItemCatalog.item_name(pickup.item_id).to_lower()], true)
	contents[place] = carried
	_spawn(place)
	return true


## Called by a shelf pickup once the player has taken it.
func on_taken(pickup: ItemPickup) -> void:
	var place := pickup.storage_slot
	if place >= 0 and place < capacity and _pickups[place] == pickup:
		contents[place] = &""
		_pickups[place] = null
		pickup.queue_free()


## Local position of shelf place `i`.
func place_position(i: int) -> Vector3:
	var step := shelf_width / float(capacity)
	return Vector3(-shelf_width / 2.0 + step * (i + 0.5), 0.0, 0.0)


func _spawn(place: int) -> void:
	if _pickups[place] != null and is_instance_valid(_pickups[place]):
		_pickups[place].queue_free()
	_pickups[place] = null
	if contents[place] == &"":
		return
	var pickup := ItemPickup.new()
	pickup.name = "Stored%d" % place
	pickup.item_id = contents[place]
	pickup.storage = self
	pickup.storage_slot = place
	pickup.position = place_position(place)
	_pickups[place] = pickup
	add_child(pickup)


func _rebuild() -> void:
	for i in capacity:
		_spawn(i)


func _has_shape() -> bool:
	for child in get_children():
		if child is CollisionShape3D:
			return true
	return false


func _build_model() -> void:
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.3, 0.2)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.3, 0.32, 0.35)
	for part in [[Vector3(shelf_width, 0.05, 0.42), Vector3(0, -0.025, 0), wood],
			[Vector3(shelf_width, 0.05, 0.42), Vector3(0, -0.85, 0), wood],
			[Vector3(0.05, 1.0, 0.42), Vector3(-shelf_width / 2.0, -0.45, 0), metal],
			[Vector3(0.05, 1.0, 0.42), Vector3(shelf_width / 2.0, -0.45, 0), metal]]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		mesh.mesh = box
		mesh.position = part[1]
		mesh.material_override = part[2]
		model.add_child(mesh)
	var label := Label3D.new()
	label.text = storage_name.to_upper()
	label.font_size = 28
	label.pixel_size = 0.004
	label.position = Vector3(0, -0.45, 0.22)
	label.modulate = Color(0.95, 0.85, 0.55)
	model.add_child(label)


# --- Checkpoints -------------------------------------------------------------------------------

func get_checkpoint_state() -> Dictionary:
	return {"contents": contents.duplicate()}


func restore_checkpoint_state(state: Dictionary) -> void:
	var stored: Array = state.get("contents", [])
	for i in capacity:
		contents[i] = StringName(stored[i]) if i < stored.size() else &""
	_rebuild()
