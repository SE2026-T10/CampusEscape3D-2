extends Node3D

## Museum-only objectives. All pickups can be collected in any order.
const OBJECTIVES := [
	{"id": &"take_t1", "title": "Lấy tác phẩm T1",
	 "hint": "T1 treo trên tường phía tây.", "done": "Đã lấy tác phẩm T1", "requires": []},
	{"id": &"take_t2", "title": "Lấy tác phẩm T2",
	 "hint": "T2 treo trên tường phía đông.", "done": "Đã lấy tác phẩm T2", "requires": []},
	{"id": &"take_t3", "title": "Lấy tác phẩm T3",
	 "hint": "T3 treo trên tường phía bắc.", "done": "Đã lấy tác phẩm T3", "requires": []},
	{"id": &"take_rope", "title": "Tìm dây thoát",
	 "hint": "Dây nằm gần góc tây nam của phòng.", "done": "Đã lấy dây thoát", "requires": []},
	{"id": &"escape", "title": "Buộc dây và thoát",
	 "hint": "Đến điểm màu xanh ở phía nam, sau khi cắt đuôi bảo vệ.", "done": "Đã thoát khỏi bảo tàng!",
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
