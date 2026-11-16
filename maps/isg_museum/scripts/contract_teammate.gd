extends Interactable

func _on_interact(_by: Node) -> bool:
	var ui := get_tree().get_first_node_in_group("museum_contract_ui")
	if ui:
		return ui.open_contract(self)
	return false

func set_conversation_active(active: bool) -> void:
	$Presentation.set_talking(active)
