extends Interactable

func _on_interact(_by: Node) -> bool:
	var ui := get_tree().get_first_node_in_group("museum_contract_ui")
	if ui:
		ui.open_contract(self)
		return true
	return false
