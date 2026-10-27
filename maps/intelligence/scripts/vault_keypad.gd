extends CodeLock
## Reuses the common puzzle, while access policy and wording belong to K17.
func _ready() -> void:
	super()
	_display.font_size=26
	_display.pixel_size=.0013
	_display.position.y=.58
	get_node("NoPowerTag").text="CHƯA CẤP QUYỀN"
	for mesh in find_children("*","GeometryInstance3D",true,false): mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
	for i in dials.size(): dials[i].control_name="Chữ số %d"%(i+1)
	enter.control_name="Xác nhận"
	enter.get_node("Model/Cap/Mark").text="XÁC NHẬN"
	enter.action_text="Xác nhận mã kho"

func has_power() -> bool:
	var objectives := ObjectiveManager.find(self)
	var inventory := PlayerInventory.find(self)
	return objectives != null and objectives.is_completed(K17MissionController.ARCHIVE) and inventory != null and inventory.has(ItemCatalog.STAFF_CARD)

func _on_objective_changed(id: StringName,state: ObjectiveManager.State) -> void:
	super(id,state)
	# Access policy depends on other objectives too, so controls must refresh
	# when the player reaches the checkpoint, not only after solving the lock.
	_refresh()

func _refresh() -> void:
	super()
	get_node("NoPowerTag").visible=not has_power()
	var reason: String="Đã mở" if is_solved else "Khóa tạm (%d giây)"%ceili(lockout_left) if lockout_left>0 else "Cần thẻ và checkpoint" if not has_power() else ""
	for control in dials+[enter]: control.blocked_reason=reason
	if is_solved: _set_display("KHO B1 / ĐÃ MỞ",Color(.4,1,.55))
	elif not has_power(): _set_display("KHO B1 / CẦN THẺ VÀ CHECKPOINT",Color(.9,.65,.3))
	elif lockout_left>0: _set_display("KHO B1 / KHÓA TẠM %d GIÂY"%ceili(lockout_left),Color(1,.35,.3))
	else: _set_display("KHO B1 / NHẬP MÃ · CÒN %d LẦN"%attempts_left)
