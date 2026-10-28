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
		mission.queue_radio("Lam: Ô kính cạnh cửa cho cậu quan sát đường rút. Đợi tuần tra rời hành lang rồi mới tháo niêm phong. Kính không che được người đứng lộ.",5,"projection_file_room")
