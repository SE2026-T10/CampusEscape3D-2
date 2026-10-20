class_name AccessCard
extends Interactable

## The access card the exit needs. Taking it completes its objective. It can
## only be taken while that objective is ACTIVE. It is shown whenever the
## objective is not COMPLETED, so if a checkpoint restores progress from before
## the card was taken, the card is back on the desk.
##
## With `grants_item` set (the Expanded Library's staff card), taking it also
## puts that item into the player's PlayerInventory: it needs a free slot
## (refused with full hands) and is carried from then on (doors whose
## key_item matches check for it). The objective and the carried card are
## stored at the same checkpoints, so they never disagree after a restore.

@export var objective_id: StringName = ObjectiveManager.TAKE_CARD
## Prompt while the objective is not ACTIVE yet. (The pickup prompt is the
## Interactable's `prompt`; left at its default it reads "Take the access card".)
@export var waiting_prompt := "Access card (not yet)"
## Degrees per second the card model spins, so it catches the eye.
@export var spin_speed := 60.0
## ItemCatalog id also given to the player's inventory when taken (empty: none, as in the tutorial).
@export var grants_item: StringName = &""

@onready var _model: Node3D = get_node_or_null("Model")


func _ready() -> void:
	super()
	if prompt == "Interact":
		prompt = "Take the access card"
	_connect_manager.call_deferred()


func _connect_manager() -> void:
	var manager := ObjectiveManager.find(self)
	if manager:
		manager.objective_changed.connect(_on_objective_changed)
	_update()


func _process(delta: float) -> void:
	if _model and visible:
		_model.rotate_y(deg_to_rad(spin_speed) * delta)


func can_interact(by: Node) -> bool:
	var manager := ObjectiveManager.find(self)
	return super(by) and manager != null and manager.get_state(objective_id) == ObjectiveManager.State.ACTIVE


func get_prompt(by: Node) -> String:
	if not can_interact(by):
		return waiting_prompt
	var inventory := _inventory()
	if inventory and inventory.is_full():
		return "%s · hands full (%d/%d)" % [ItemCatalog.item_name(grants_item), inventory.count(), inventory.slot_count]
	return prompt


func is_taken() -> bool:
	var manager := ObjectiveManager.find(self)
	return manager != null and manager.is_completed(objective_id)


func _on_interact(_by: Node) -> bool:
	var inventory := _inventory()
	if inventory and inventory.is_full():
		inventory.notify("Hands full (%d/%d). Leave something at a storage shelf, or throw a distraction." % [inventory.count(), inventory.slot_count])
		return false
	if not ObjectiveManager.find(self).complete(objective_id):
		return false
	if inventory:
		inventory.add(grants_item)
	return true


## The player's inventory if this card is also an item, else null.
func _inventory() -> PlayerInventory:
	if grants_item == &"":
		return null
	var inventory := PlayerInventory.find(self)
	return inventory if inventory and inventory.enabled else null


func _on_objective_changed(id: StringName, _state: ObjectiveManager.State) -> void:
	if id == objective_id:
		_update()


func _update() -> void:
	var taken := is_taken()
	visible = not taken
	enabled = not taken
