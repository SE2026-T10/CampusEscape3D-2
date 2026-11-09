class_name Loot
extends Interactable

## The item to steal this run (GroceryHeist picks which item it is and where it lies).
## Taking it completes the STEAL objective, and it can only be taken while that objective is
## ACTIVE. Like AccessCard it is shown whenever the objective is not COMPLETED, so a checkpoint
## restore from before the theft puts it back on the shelf.

@export var objective_id: StringName = GroceryHeist.STEAL
@export var waiting_prompt := "Shelf item (not yet)"
@export var spin_speed := 45.0
@export var marker_offset := Vector3(0, 0.55, 0)

var item: Dictionary = {}
var _model: Node3D


func _ready() -> void:
	super()
	if _find_shape() == null:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.5, 0.5, 0.5)
		shape.shape = box
		shape.position.y = 0.25
		add_child(shape)
	add_child(PickupMarker.new(marker_offset))
	_connect_manager.call_deferred()


## Builds the model for `entry` (a GroceryHeist.ITEMS dictionary) and the prompt.
func set_item(entry: Dictionary) -> void:
	item = entry
	if _model:
		_model.queue_free()
	_model = GroceryHeist.make_model(entry)
	add_child(_model)
	prompt = "Take the %s" % String(entry.name).to_lower()
	_update()


func _connect_manager() -> void:
	var manager := ObjectiveManager.find(self)
	if manager and not manager.objective_changed.is_connected(_on_objective_changed):
		manager.objective_changed.connect(_on_objective_changed)
	_update()


func _process(delta: float) -> void:
	if _model and visible:
		_model.rotate_y(deg_to_rad(spin_speed) * delta)


func can_interact(by: Node) -> bool:
	var manager := ObjectiveManager.find(self)
	return super(by) and manager != null and manager.get_state(objective_id) == ObjectiveManager.State.ACTIVE


func get_prompt(by: Node) -> String:
	return prompt if can_interact(by) else waiting_prompt


func is_taken() -> bool:
	var manager := ObjectiveManager.find(self)
	return manager != null and manager.is_completed(objective_id)


func _on_interact(_by: Node) -> bool:
	var manager := ObjectiveManager.find(self)
	return manager != null and manager.complete(objective_id)


func _on_objective_changed(id: StringName, _state: ObjectiveManager.State) -> void:
	if id == objective_id:
		_update()


func _update() -> void:
	var taken := is_taken()
	visible = not taken
	enabled = not taken


func _find_shape() -> CollisionShape3D:
	for child in get_children():
		if child is CollisionShape3D:
			return child
	return null
