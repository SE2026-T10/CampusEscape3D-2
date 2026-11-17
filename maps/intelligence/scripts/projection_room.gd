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
		var surveillance := get_tree().get_first_node_in_group("k17_b1_surveillance")
		if surveillance: surveillance.hide_feed()
		var cue := "Lấy xong, rút qua cửa vừa vào." if mission.is_test_mode() \
			else "Muốn lấy cả 04-B, bắt đầu khi nghe bước chân tiến đến W2."
		mission.queue_radio("Lam: Mật lệnh 04 ở trên bàn. "+cue,5,"projection_file_room")
