extends Node3D

## Scene-local authoring mode; inherited editing scene enables it at startup.
@export var disable_guards_for_editing: bool = false

## Map-only progress flags; escape is the sole mandatory objective.
const OBJECTIVES := [
	{"id": &"take_key", "title": "Tìm chìa K cho phòng B",
	 "hint": "E mở cửa phòng nhân viên tầng 1; chìa treo ngoài tủ D. Cúi sau bàn A, tránh chai/lon F.",
	 "done": "Đã lấy chìa K — có thể mở cửa phòng B ở tầng 2", "requires": []},
	{"id": &"take_t1", "title": "Lấy tác phẩm T1",
	 "hint": "Phòng A phía tây tầng 2. Quan sát G6 kiểm tra tranh trước khi lấy T1.",
	 "done": "Đã lấy tác phẩm T1", "requires": []},
	{"id": &"take_t2", "title": "Mang tranh lớn T2 tới điểm tập kết",
	 "hint": "E nhấc T2 trong phòng B; Q đặt xuống. Đi qua hành lang và phòng đệm phía nam, E vào kho để giao tranh tại thảm xanh.",
	 "done": "T2 đã được vận chuyển tới điểm tập kết trong kho", "requires": [&"take_key"]},
	{"id": &"take_t3", "title": "Lấy tác phẩm T3",
	 "hint": "Phòng tranh C, phía bắc tầng 2.", "done": "Đã lấy tác phẩm T3", "requires": []},
	{"id": &"take_rope", "title": "Tìm dây thoát",
	 "hint": "Kho phụ phía đông tầng 1. Lịch C và giấy G trong phòng nhân viên gợi ý mã cửa; E lấy dây trên giá.",
	 "done": "Đã lấy dây thoát", "requires": []},
	{"id": &"escape", "title": "Buộc dây và thoát",
	 "hint": "Cắt đuôi bảo vệ rồi dùng cửa sổ phía đông kho phục chế, tầng 2.",
	 "done": "Đã thoát khỏi bảo tàng!",
	 "requires": []},
]

var _restarting := false


func _enter_tree() -> void:
	# Parent enters first: remove actors synchronously before their AI, perception
	# and noise listeners can enter/ready. This non-tool script leaves editor nodes.
	if disable_guards_for_editing:
		_remove_runtime_guards_for_editing()
	# Configure before the manager's _ready(), avoiding the library defaults.
	var definitions: Array[Dictionary] = []
	for entry in OBJECTIVES:
		var item: Dictionary = entry.duplicate(true)
		item.requires = []
		if item.id != &"escape":
			item.optional = true
		if item.id == &"take_t2":
			item.requires = [&"take_key"]
		definitions.append(item)
	for id in preload("res://maps/isg_museum/scripts/museum_contract.gd").CATALOG:
		var info: Dictionary = preload("res://maps/isg_museum/scripts/museum_contract.gd").CATALOG[id]
		if id in ["t1","t2","t3"]:
			continue
		definitions.append({"id":StringName(info.objective),"title":info.name,"hint":info.room,"requires":[],"optional":true})
	definitions.append({"id":&"accept_contract","title":"Nhận hợp đồng từ N0","requires":[],"optional":true})
	definitions.append({"id":&"get_ticket","title":"Nhận vé lên tầng 2","requires":[],"optional":true})
	$ObjectiveManager.objectives.assign(definitions)


func _remove_runtime_guards_for_editing() -> int:
	var removed := 0
	for child in get_children():
		if child is Guard:
			remove_child(child)
			child.free()
			removed += 1
	return removed


func _ready() -> void:
	$NavigationRegion3D/Doors/Storage.rejected.connect(_on_guard_notice)
	$ObjectiveManager.level_completed.connect($StealthDirector.finish_level)
	for guard_path in [^"Guard_G6", ^"Guard_G3"]:
		var guard := get_node_or_null(guard_path)
		if guard != null:
			guard.connect(&"notice", _on_guard_notice)
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
