extends "res://maps/isg_museum/scripts/staff_document.gd"

@export_enum("event","host") var document_kind := "event"

func _ready() -> void:
	super()
	refresh.call_deferred()

func refresh() -> void:
	var contract := get_tree().get_first_node_in_group("museum_contract")
	if contract == null:
		return
	if document_kind == "host":
		title = "Bảng tên nhân viên tiếp đón"
		prompt = "Đọc bảng tên nhân viên"
		$Caption.text = contract.contract_info.host.to_upper()+"\nNhân viên tiếp đón"
	else:
		title = "Áp phích sự kiện"
		$Caption.text = contract.contract_info.event.to_upper()+"\nTiếp đón tại phòng dịch vụ"

func get_content() -> String:
	var contract := get_tree().get_first_node_in_group("museum_contract")
	if contract == null:
		return ""
	if document_kind == "host":
		return contract.contract_info.host+"\nNhân viên tiếp đón"
	return contract.contract_info.event.to_upper()+"\n\nKhách có giấy hẹn vui lòng tới quầy dịch vụ để xác nhận thông tin."
