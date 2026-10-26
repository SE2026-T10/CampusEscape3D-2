class_name K17MissionController
extends MapHudProvider

## Scene-local mission state. AI, player, interaction and HUD stay shared.
const ENTER := &"enter_k17"
const PASS := &"take_pass"
const ARCHIVE := &"reach_archive"
const FILE := &"take_intelligence"
const ESCAPE := &"extract_k17"
const OBJECTIVES := [
	{"id": ENTER, "title": "Vào cơ sở K17", "hint": "Qua sân tiếp vận hoặc hành lang kỹ thuật.", "done": "Đã vào K17"},
	{"id": PASS, "title": "Lấy giấy thông hành", "hint": "Trên bàn trong phòng trực phía tây.", "done": "Đã lấy giấy thông hành"},
	{"id": ARCHIVE, "title": "Đến điểm chuẩn bị", "hint": "Mở cửa khu hồ sơ bằng E, tìm biển checkpoint bên phải.", "done": "Đã lưu checkpoint trước khu hồ sơ"},
	{"id": FILE, "title": "Thu hồi Mật lệnh 04", "hint": "Giá hồ sơ ở cuối phòng. Lấy hồ sơ sẽ khởi động 120 giây.", "done": "Đã lấy Mật lệnh 04 — rút lui!"},
	{"id": ESCAPE, "title": "Đến điểm tập kết", "hint": "Trở ra ngoài qua sân hoặc hành lang bảo trì. Tìm đèn xanh.", "done": "Đã đưa hồ sơ ra khỏi K17"},
]

@export_range(1.0, 600.0) var escape_duration := 120.0
var has_file := false
var time_left := 120.0
var escaped := false
var timeouts := 0
var radio_message := "Lam: Vào phòng trực lấy giấy thông hành. Ghi nhớ đường về điểm tập kết."


func _ready() -> void:
	super()
	add_to_group("k17_mission")
	add_to_group("checkpoint_state")
	# Resolve the deadline before extraction areas in the same physics tick.
	process_physics_priority = -20
	time_left = escape_duration
	_connect.call_deferred()


func _connect() -> void:
	ObjectiveManager.find(self).objective_completed.connect(_on_objective_completed)
	CheckpointManager.find(self).respawned.connect(_on_respawned)


func _on_objective_completed(id: StringName) -> void:
	match id:
		ENTER:
			radio_message = "Lam: Phòng trực ở phía tây. Lối bảo trì nằm phía đông."
		PASS:
			radio_message = "Lam: Dùng giấy thông hành mở cửa khu hồ sơ. Điểm chuẩn bị ở bên phải, sau tủ che."
		ARCHIVE:
			radio_message = "Lam: Nhấc hồ sơ khỏi giá sẽ kích hoạt phong tỏa. Chuẩn bị đường rút."
		FILE:
			if has_file:
				return
			has_file = true
			time_left = escape_duration
			radio_message = "Lam: Niêm phong đã bị phá! Mang hồ sơ đến đèn tập kết ngoài hàng rào."
			_set_alarm_lights(true)
			var audio := AudioDirector.find(self)
			if audio:
				audio.play_sfx("alarm", -8.0)


func _physics_process(delta: float) -> void:
	var flow := GameFlow.find(self)
	if flow == null or flow.state != GameStateMachine.State.PLAYING or not has_file or escaped:
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0 and flow.fail("Đã hết thời gian rút lui. Cơ sở K17 bị phong tỏa."):
		timeouts += 1


func try_extract(route: StringName, title: String) -> bool:
	var flow := GameFlow.find(self)
	var objectives := ObjectiveManager.find(self)
	if flow == null or flow.state != GameStateMachine.State.PLAYING or not has_file or escaped or time_left <= 0.0:
		return false
	if objectives.current() != ESCAPE:
		return false
	escaped = true
	objectives.record_escape_route(route, title)
	StealthDirector.find(self).finish_level()
	objectives.complete(ESCAPE)
	return true


func get_status_lines() -> Array[String]:
	var clock := "Chưa kích hoạt"
	if has_file:
		var seconds := ceili(time_left)
		clock = "%02d:%02d" % [seconds / 60, seconds % 60]
	return ["K17 / CHIẾN DỊCH TÌNH BÁO", "Hồ sơ: " + ("đang mang Mật lệnh 04" if has_file else "chưa thu hồi"),
		"Phong tỏa: " + clock, radio_message]


func show_objective_checklist() -> bool:
	return false


func get_result_lines() -> Array[String]:
	var objectives := ObjectiveManager.find(self)
	return ["Mật lệnh 04 đã được đưa ra khỏi K17.", "Còn lại: %d giây · Hết giờ: %d lần" % [ceili(time_left), timeouts],
		"Đường rút: " + objectives.escape_route_name]


func get_checkpoint_state() -> Dictionary:
	return {"has_file": has_file, "time_left": time_left, "escaped": escaped}


func restore_checkpoint_state(saved: Dictionary) -> void:
	has_file = bool(saved.get("has_file", false))
	time_left = float(saved.get("time_left", escape_duration))
	escaped = bool(saved.get("escaped", false))
	_set_alarm_lights(has_file)


func _on_respawned(_checkpoint: Checkpoint) -> void:
	radio_message = "Lam: Thử lại. Hồ sơ vẫn ở trên giá, đồng hồ chưa chạy."


func _set_alarm_lights(active: bool) -> void:
	for light in get_tree().get_nodes_in_group("k17_alarm_lights"):
		light.light_color = Color(1.0, 0.18, 0.1) if active else Color(0.55, 0.75, 1.0)
		if light.has_meta("alarm_only"):
			light.visible = active
