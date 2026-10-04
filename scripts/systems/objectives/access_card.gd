class_name AccessCard
extends Interactable

## The access card the exit needs. Taking it completes its objective. It can
## only be taken while that objective is ACTIVE. It is shown whenever the
## objective is not COMPLETED, so if a checkpoint restores progress from before
## the card was taken, the card is back on the desk.

@export var objective_id: StringName = ObjectiveManager.TAKE_CARD
## Degrees per second the card model spins, so it catches the eye.
@export var spin_speed := 60.0

@onready var _model: Node3D = get_node_or_null("Model")


func _ready() -> void:
	super()
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
	return prompt if can_interact(by) else "Access card (not yet)"


func is_taken() -> bool:
	var manager := ObjectiveManager.find(self)
	return manager != null and manager.is_completed(objective_id)


func _on_interact(_by: Node) -> bool:
	return ObjectiveManager.find(self).complete(objective_id)


func _on_objective_changed(id: StringName, _state: ObjectiveManager.State) -> void:
	if id == objective_id:
		_update()


func _update() -> void:
	var taken := is_taken()
	visible = not taken
	enabled = not taken
