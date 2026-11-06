extends Interactable

func get_prompt(_by: Node) -> String:
	var contract := get_tree().get_first_node_in_group("museum_contract")
	return "Nói chuyện với nhân viên tiếp đón" if contract == null or not contract.has_ticket else "Hỏi lại nhân viên tiếp đón"


func can_interact(by: Node) -> bool:
	var flow := GameFlow.find(self)
	return super(by) and flow != null and flow.state == GameStateMachine.State.PLAYING and not flow.is_leaving()


func _on_interact(by: Node) -> bool:
	var ui := get_tree().get_first_node_in_group("museum_service_ui")
	return ui != null and ui.open_quiz(self,by)
