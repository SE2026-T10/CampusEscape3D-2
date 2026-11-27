extends Interactable

func can_interact(by: Node) -> bool:
	var flow := GameFlow.find(self)
	return super(by) and flow != null and flow.state == GameStateMachine.State.PLAYING and not flow.is_leaving()


func _on_interact(by: Node) -> bool:
	var ui := get_tree().get_first_node_in_group("museum_service_ui")
	return ui != null and ui.open_map(self,by)
