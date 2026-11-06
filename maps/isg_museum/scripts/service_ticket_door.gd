extends "res://maps/isg_museum/scripts/museum_door.gd"

func _ready() -> void:
	super()
	add_to_group("museum_ticket_doors")
	unlocked = false


func _blocked_reason(_by: Node) -> String:
	var contract := get_tree().get_first_node_in_group("museum_contract")
	if contract == null or not contract.has_ticket:
		return "Cần vé V — gặp nhân viên phòng dịch vụ tầng 1"
	return ""


func _on_interact(by: Node) -> bool:
	var contract := get_tree().get_first_node_in_group("museum_contract")
	if contract == null or not contract.has_ticket:
		rejected.emit("Cần vé V — trả lời nhân viên phòng dịch vụ tầng 1")
		return false
	if not contract.ticket_scanned and not contract.scan_ticket():
		return false
	for door in get_tree().get_nodes_in_group("museum_ticket_doors"):
		door.unlocked = true
	return super(by)
