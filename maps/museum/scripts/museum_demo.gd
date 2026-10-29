extends Node3D

## Museum-only objectives. Only T2 requires the staff-room key.
const OBJECTIVES := [
	{"id": &"take_key", "title": "Tìm chìa K cho phòng B",
	 "hint": "Phòng nhân viên ở phía đông tầng 1; chìa ở gần (31.5, 13).",
	 "done": "Đã lấy chìa K — có thể mở cửa phòng B ở tầng 2", "requires": []},
	{"id": &"take_t1", "title": "Lấy tác phẩm T1",
	 "hint": "Phòng tranh A, phía tây tầng 2. Có thể lên bằng thang A hoặc B.",
	 "done": "Đã lấy tác phẩm T1", "requires": []},
	{"id": &"take_t2", "title": "Lấy tác phẩm T2",
	 "hint": "Dùng chìa K mở phòng B ở phía đông tầng 2; T2 treo trên tường phía đông.",
	 "done": "Đã lấy tác phẩm T2", "requires": [&"take_key"]},
	{"id": &"take_t3", "title": "Lấy tác phẩm T3",
	 "hint": "Phòng tranh C, phía bắc tầng 2.", "done": "Đã lấy tác phẩm T3", "requires": []},
	{"id": &"take_rope", "title": "Tìm dây thoát",
	 "hint": "Kho phục chế ở góc đông nam tầng 2; có lối vào tự do từ phòng đệm phía nam.",
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
	# Keep the caught overlay, then reload everything, including hidden pickups.
	$StealthDirector.level_reset.connect(_restart_demo)


func _restart_demo() -> void:
	if _restarting:
		return
	_restarting = true
	$GameFlow.restart.call_deferred()
