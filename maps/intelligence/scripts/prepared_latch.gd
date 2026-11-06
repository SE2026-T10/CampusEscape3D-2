class_name K17PreparedLatch
extends Interactable

func _ready() -> void:
	super()
	hold_duration = 2.5

func can_interact(by: Node) -> bool:
	var mission := MapHudProvider.find_for(self) as K17MissionController
	return super(by) and mission != null and not mission.has_file and not mission.backdoor_prepared

func get_prompt(_by: Node) -> String:
	var mission := MapHudProvider.find_for(self) as K17MissionController
	if mission == null: return "Chốt cửa hậu"
	if mission.backdoor_prepared: return "Đã chuẩn bị cửa hậu · mở nhanh khi rút"
	if mission.has_file: return "Đang phong tỏa · mở trực tiếp ở cửa hậu"
	return "Chuẩn bị chốt mở nhanh cửa hậu"

func _on_interact(_by: Node) -> bool:
	var mission := MapHudProvider.find_for(self) as K17MissionController
	mission.backdoor_prepared = true
	ObjectiveManager.find(self).try_complete(K17MissionController.PREPARED)
	mission.queue_radio("Lam: Chốt cửa hậu đã chuẩn bị. Khi báo động, em có thể mở ngay tại cổng phía đông.",2,"prepared")
	$Latch.play()
	return true
