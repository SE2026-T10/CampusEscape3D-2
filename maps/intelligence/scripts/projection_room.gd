extends Area3D
## Static, truthful guidance on entering the room; no live enemy telemetry.
func _ready() -> void:
	collision_layer=0
	collision_mask=2
	body_entered.connect(_entered)

func _entered(body: Node3D) -> void:
	if not body.is_in_group("player"): return
	var mission := MapHudProvider.find_for(self) as K17MissionController
	if mission and not mission.has_file:
		mission.queue_radio("Lam: Khi lấy tài liệu, ra chính cửa vừa vào rồi quay về sảnh. Màn nằm phía chốt. Nghe bước chân rời W2 trước khi tháo niêm phong; hai phút không chờ ai.",5,"projection_file_room")
