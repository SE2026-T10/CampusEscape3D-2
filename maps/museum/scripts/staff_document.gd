extends Interactable

@export var title := "Ghi chú"
@export_multiline var content := ""


func can_interact(by: Node) -> bool:
	var flow := GameFlow.find(self)
	return super(by) and flow != null and flow.state == GameStateMachine.State.PLAYING and not flow.is_leaving()


func _on_interact(_by: Node) -> bool:
	var reader := get_tree().get_first_node_in_group("staff_reader")
	if reader == null:
		return false
	reader.open_document(title,get_content(),self)
	return true


func get_content() -> String:
	return content
