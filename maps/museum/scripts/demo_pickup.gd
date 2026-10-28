extends Interactable

@export var objective_id: StringName = &"take_t1"


func can_interact(by: Node) -> bool:
	var objectives := ObjectiveManager.find(self)
	var flow := GameFlow.find(self)
	return super(by) and objectives != null \
		and objectives.get_state(objective_id) == ObjectiveManager.State.ACTIVE \
		and flow != null and flow.state == GameStateMachine.State.PLAYING


func _on_interact(_by: Node) -> bool:
	var objectives := ObjectiveManager.find(self)
	if objectives == null or not objectives.complete(objective_id):
		return false
	enabled = false
	# Hidden Area3Ds still intercept interaction rays unless the layer is cleared.
	collision_layer = 0
	hide()
	return true
