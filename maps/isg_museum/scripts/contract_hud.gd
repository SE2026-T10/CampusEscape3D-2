extends ObjectiveHud

func _contract():
	return get_tree().get_first_node_in_group("museum_contract")


func get_header_text() -> String:
	var contract = _contract()
	if contract == null or not contract.accepted:
		return "HỢP ĐỒNG · CHƯA NHẬN"
	var summary: Dictionary = contract.report()
	return "HỢP ĐỒNG · %d/%d"%[summary.required.size()-summary.missing.size(),summary.required.size()]


func get_current_text() -> String:
	return "Gặp đồng đội N0 ngoài cổng" if _contract() == null or not _contract().accepted else "J: hợp đồng / giấy hẹn\nM: bản đồ đã lưu"


func get_lines() -> Array[String]:
	var lines: Array[String] = []
	var contract = _contract()
	var manager := ObjectiveManager.find(self)
	if contract and contract.accepted:
		var found: Array = contract.collected_ids()
		for id in contract.selected_ids:
			lines.append(("[x] " if id in found else "[ ] ")+contract.catalog[id].name)
	lines.append("[x] Dây thoát" if manager and manager.is_completed(&"take_rope") else "[ ] Dây — kho phụ tầng 1")
	lines.append("[x] Vé tầng 2" if contract and contract.has_ticket else "[ ] Vé — phòng dịch vụ")
	lines.append("Có dây: được rút lui.")
	lines.append("Mục tiêu thiếu: kết quả một phần.")
	return lines


func _update_panel(_objectives: ObjectiveManager) -> void:
	_header.text = get_header_text()
	_current.text = get_current_text()
	_hint.text = "Phụ: tránh truy đuổi (+200 điểm)"
	_list.text = "\n".join(get_lines())


func _update_prompt(delta: float) -> void:
	super(delta)
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var target = player.get_node("Interactor").focused
	if target and target.has_method("get_open_progress") and not target.is_open:
		_hold_bar.visible = true
		_hold_bar.value = target.get_open_progress()*100
