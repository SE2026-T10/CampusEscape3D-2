extends Interactable
@export var action := "grip"

func _rig() -> Node3D:
	return get_parent() as Node3D

func can_interact(by: Node) -> bool:
	var mission := MapHudProvider.find_for(self) as K17MissionController
	var objectives := ObjectiveManager.find(self)
	return super(by) and mission != null and objectives != null and objectives.is_completed(K17MissionController.VAULT) and _rig().holder == null and (action == "grip" or _rig().deployed)

func get_prompt(_by: Node) -> String:
	var mission := MapHudProvider.find_for(self) as K17MissionController
	if mission and mission.has_file and action=="grip": return "Có thể bỏ lại màn — nắm nếu cần dời" if _rig().deployed else "Dựng để dời màn nếu cần — có thể bỏ lại"
	match action:
		"power": return "Tắt hình chiếu" if _rig().powered else "Bật hình chiếu"
		"fold": return "Thu màn — giải phóng đường đi"
	return "Nắm tay đẩy — tiến/lùi và quan sát" if _rig().deployed else "Dựng màn và hiệu chỉnh góc chốt gác"

func get_hold_duration(_by: Node) -> float:
	return 2.0 if action == "fold" or not _rig().deployed else 0.0

func _on_interact(by: Node) -> bool:
	match action:
		"power":
			_rig().powered = not _rig().powered
			return true
		"fold": return _rig().fold()
	return _rig().begin_grip(by) if _rig().deployed else _rig().deploy()
