extends Node3D

## Museum-only objectives. Only T2 requires the staff-room key.
const OBJECTIVES := [
	{"id": &"take_key", "title": "Tìm chìa K cho phòng B",
	 "hint": "E mở cửa phòng nhân viên tầng 1; chìa treo ngoài tủ D. Cúi sau bàn A, tránh chai/lon F.",
	 "done": "Đã lấy chìa K — có thể mở cửa phòng B ở tầng 2", "requires": []},
	{"id": &"take_t1", "title": "Lấy tác phẩm T1",
	 "hint": "Phòng A phía tây tầng 2. Quan sát G6 kiểm tra tranh trước khi lấy T1.",
	 "done": "Đã lấy tác phẩm T1", "requires": []},
	{"id": &"take_t2", "title": "Mang tranh lớn T2 tới điểm tập kết",
	 "hint": "E nhấc T2 trong phòng B; Q đặt xuống. Mở chốt B → kho để đi ngắn, rồi E giao tranh tại thảm xanh trong kho.",
	 "done": "T2 đã được vận chuyển tới điểm tập kết trong kho", "requires": [&"take_key"]},
	{"id": &"take_t3", "title": "Lấy tác phẩm T3",
	 "hint": "Phòng tranh C, phía bắc tầng 2.", "done": "Đã lấy tác phẩm T3", "requires": []},
	{"id": &"take_rope", "title": "Tìm dây thoát",
	 "hint": "Kho phục chế góc đông nam tầng 2; E mở cửa từ phòng đệm phía nam, không cần chìa.",
	 "done": "Đã lấy dây thoát", "requires": []},
	{"id": &"escape", "title": "Buộc dây và thoát",
	 "hint": "Cắt đuôi bảo vệ rồi dùng cửa sổ phía đông kho phục chế, tầng 2.",
	 "done": "Đã thoát khỏi bảo tàng!",
	 "requires": [&"take_t1", &"take_t2", &"take_t3", &"take_rope"]},
]

var _restarting := false


func _enter_tree() -> void:
	# Configure before the manager's _ready(), avoiding the library defaults.
	$ObjectiveManager.objectives.assign(OBJECTIVES)


func _ready() -> void:
	$ObjectiveManager.level_completed.connect($StealthDirector.finish_level)
	$Guard_G6.notice.connect(_on_guard_notice)
	$Guard_G3.notice.connect(_on_guard_notice)
	$Interactables/Painting_T2.notice.connect(_on_carry_notice)
	# Keep the caught overlay, then reload everything, including hidden pickups.
	$StealthDirector.level_reset.connect(_restart_demo)


func _on_guard_notice(message: String) -> void:
	$ObjectiveHud.show_message(message, Color(1,0.7,0.3))


func _on_carry_notice(message: String) -> void:
	$ObjectiveHud.show_message(message, Color(0.7,0.9,1))


func _restart_demo() -> void:
	if _restarting:
		return
	_restarting = true
	$GameFlow.restart.call_deferred()
