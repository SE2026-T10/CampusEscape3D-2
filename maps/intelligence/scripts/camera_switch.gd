extends CircuitSwitch

func get_prompt(_by: Node) -> String:
	var network := PowerNetwork.find(self)
	if network and network.get("backup_active"): return "Camera dùng nguồn dự phòng · công tắc nguồn chính không còn tác dụng"
	return "Nguồn camera: %s · chuyển %s" % ["BẬT" if network and network.is_powered(circuit) else "TẮT","TẮT" if network and network.is_powered(circuit) else "BẬT"]

func _on_interact(by: Node) -> bool:
	var network := PowerNetwork.find(self)
	if network and network.get("backup_active"):
		feedback.emit("Camera đang dùng nguồn dự phòng. Tiếp tục tìm vật che và đường rút.",false)
		return false
	return super(by)
