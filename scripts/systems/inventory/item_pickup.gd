class_name ItemPickup
extends Interactable

## A carried item lying in the level (or on a storage shelf). Using it puts it
## into the player's PlayerInventory, if a slot is free.
##   - Hands full: refused, with a hint to leave something at a storage shelf,
##     except on a shelf, where the selected carried item is swapped for it.
##   - The model and interaction box are made from ItemCatalog if the scene
##     gives none.
##   - A pickup placed in the level is part of the mission state (group
##     "checkpoint_state"): taken or not is restored with the player's slots, so
##     being caught never duplicates or loses it. Shelf pickups are created and
##     restored by their ItemStorage instead.

@export var item_id: StringName = ItemCatalog.TOOLKIT

## True once taken (a level pickup stays hidden until a checkpoint restores it).
var taken := false
## Set by ItemStorage for items on its shelf.
var storage: ItemStorage = null
var storage_slot := -1


func _ready() -> void:
	super()
	if storage == null:
		add_to_group("checkpoint_state")
		add_to_group("item_pickups")
	if get_node_or_null("Model") == null:
		add_child(ItemCatalog.make_model(item_id))
	if _find_shape() == null:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var size: Vector3 = ItemCatalog.ITEMS.get(item_id, ItemCatalog.ITEMS[ItemCatalog.TOOLKIT]).size
		box.size = Vector3(maxf(size.x, 0.4), maxf(size.y, 0.3), maxf(size.z, 0.4))
		shape.shape = box
		shape.position.y = box.size.y / 2.0
		add_child(shape)
	_apply()


func get_item_name() -> String:
	return ItemCatalog.item_name(item_id)


func get_prompt(_by: Node) -> String:
	var inventory := PlayerInventory.find(self)
	if inventory == null or not inventory.enabled:
		return "%s (can't carry it)" % get_item_name()
	if not inventory.is_full():
		return "Take the %s" % get_item_name().to_lower()
	if storage != null:
		return "Swap the %s for the %s" % [ItemCatalog.item_name(inventory.selected_item()).to_lower(), get_item_name().to_lower()]
	return "%s · hands full (%d/%d)" % [get_item_name(), inventory.count(), inventory.slot_count]


func _on_interact(_by: Node) -> bool:
	var inventory := PlayerInventory.find(self)
	if taken or inventory == null or not inventory.enabled:
		return false
	if inventory.is_full():
		if storage != null:
			return storage.swap(self)
		inventory.notify("Hands full (%d/%d). Leave something at a storage shelf, or throw a distraction." % [inventory.count(), inventory.slot_count])
		return false
	if not inventory.add(item_id):
		return false
	taken = true
	inventory.notify("%s taken" % get_item_name(), true)
	if storage != null:
		storage.on_taken(self)
	else:
		_apply()
	return true


func _apply() -> void:
	visible = not taken
	enabled = not taken


func _find_shape() -> CollisionShape3D:
	for child in get_children():
		if child is CollisionShape3D:
			return child
	return null


# --- Checkpoints -------------------------------------------------------------------------------

func get_checkpoint_state() -> Dictionary:
	return {"taken": taken}


func restore_checkpoint_state(state: Dictionary) -> void:
	taken = bool(state.get("taken", false))
	_apply()
