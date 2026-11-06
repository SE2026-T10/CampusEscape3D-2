extends Node

signal changed
signal ended(summary: Dictionary)

const CATALOG := {
	"s1": {"objective":"take_s1","name":"Tượng chim đồng","room":"Điêu khắc · tầng 1","detail":"Chim có cánh xòe, kim loại màu đồng; tủ S1.","points":300,"icon":"bird"},
	"s2": {"objective":"take_s2","name":"Tượng bán thân","room":"Điêu khắc · tầng 1","detail":"Đầu tượng đá sáng; tủ S2.","points":200,"icon":"bust"},
	"h1": {"objective":"take_h1","name":"Huy chương bạc","room":"Lịch sử · tầng 1","detail":"Huy chương tròn màu bạc, dải ruy băng xanh; ngăn H1.","points":250,"icon":"medal"},
	"h2": {"objective":"take_h2","name":"Đồng hồ bỏ túi","room":"Lịch sử · tầng 1","detail":"Đồng hồ vàng trong ngăn H2.","points":200,"icon":"watch"},
	"t1": {"objective":"take_t1","name":"Tranh T1","room":"Phòng A · tầng 2","detail":"Tranh trên tường tây; để lại khung trống khi lấy.","points":400,"icon":"painting"},
	"a2": {"objective":"take_a2","name":"Phác thảo A2","room":"Phòng A · tầng 2","detail":"Tranh nhỏ phía nam T1.","points":180,"icon":"painting"},
	"t2": {"objective":"take_t2","name":"Tranh lớn T2","room":"Phòng B · tầng 2","detail":"Chỉ tính sau khi giao tại thảm tập kết kho phục chế.","points":600,"icon":"painting"},
	"b2": {"objective":"take_b2","name":"Tranh cuộn B2","room":"Phòng B · tầng 2","detail":"Bản phác thảo nhỏ, không cần vận chuyển bằng tay.","points":180,"icon":"scroll"},
	"t3": {"objective":"take_t3","name":"Tranh T3","room":"Phòng C · tầng 2","detail":"Niêm phong báo động; kiểm tra công tắc trước khi lấy.","points":250,"icon":"painting"},
	"c2": {"objective":"take_c2","name":"Tĩnh vật C2","room":"Phòng C · tầng 2","detail":"Tranh phụ cùng hệ thống báo động với T3.","points":200,"icon":"painting"},
}

var catalog: Dictionary = CATALOG.duplicate(true)
var selected_ids: Array[String] = ["s1","h1","t1"]
var accepted := false
var has_ticket := false
var ticket_scanned := false
var alarms := 0
var detections := 0
var glass_broken := 0
var last_report: Dictionary = {}
var _finished := false


func _enter_tree() -> void:
	add_to_group("museum_contract")


func _ready() -> void:
	_connect.call_deferred()


func _connect() -> void:
	ObjectiveManager.find(self).objective_completed.connect(_completed)
	var flow := GameFlow.find(self)
	flow.state_changed.connect(func(_from: int,to: int):
		if to == GameStateMachine.State.WIN:
			finish(true))
	var director := StealthDirector.find(self)
	director.player_caught.connect(_caught)
	# Count confirmed encounters, never every frame of partial suspicion.
	for guard in get_tree().get_nodes_in_group("guards"):
		guard.ai_state_changed.connect(func(_old: int,to: int,_reason: String):
			if to == GuardStateMachine.CHASE and not _finished:
				detections += 1
				changed.emit())


func accept_contract() -> void:
	if accepted or _finished:
		return
	accepted = true
	ObjectiveManager.find(self).complete(&"accept_contract")
	changed.emit()
	show_message("Đã nhận S1 + H1 + T1 · J xem giấy hẹn.")


func grant_ticket() -> void:
	if _finished:
		return
	has_ticket = true
	ObjectiveManager.find(self).complete(&"get_ticket")
	changed.emit()


func scan_ticket() -> bool:
	if not has_ticket or _finished:
		return false
	ticket_scanned = true
	changed.emit()
	return true


func collected_ids() -> Array[String]:
	var found: Array[String] = []
	var manager := ObjectiveManager.find(self)
	for id in catalog:
		if manager.is_completed(StringName(catalog[id].objective)):
			found.append(id)
	return found


func report(escaped := true) -> Dictionary:
	var found := collected_ids()
	var required: Array = selected_ids.duplicate() if accepted else []
	var missing: Array = []
	var extras: Array = []
	var correct := 0
	var score := 0
	for id in required:
		if id in found:
			correct += 1
			score += int(catalog[id].points)
		else:
			missing.append(id)
	for id in found:
		if id not in required:
			extras.append(id)
			score += 50
	var rating := "unassigned" if not accepted else ("complete" if missing.is_empty() else ("partial" if correct > 0 else "empty"))
	if not escaped:
		rating = "caught"
	var bonus := escaped and accepted and detections == 0
	if bonus:
		score += 200
	var labels := {"complete":"Hoàn thành hợp đồng","partial":"Hoàn thành một phần","empty":"Rút lui tay trắng","unassigned":"Chưa nhận hợp đồng","caught":"Bị bắt"}
	return {"rating":rating,"rating_text":labels[rating],"required":required,"collected":found,
		"missing":missing,"extras":extras,"score":score if escaped else 0,"alarms":alarms,
		"detections":detections,"time":GameFlow.find(self).play_time,"bonus":bonus,"glass_broken":glass_broken}


func record_alarm(_source: String) -> void:
	if _finished:
		return
	alarms += 1
	changed.emit()


func record_glass_break() -> void:
	glass_broken += 1
	changed.emit()


func show_message(text: String) -> void:
	var hud := get_parent().get_node_or_null("ObjectiveHud")
	if hud:
		hud.show_message(text,Color(1,.85,.5))


func _completed(id: StringName) -> void:
	if id in [&"take_t3",&"take_c2"]:
		var alarm := get_tree().get_first_node_in_group("museum_gallery_alarm")
		if alarm:
			alarm.artwork_taken(id)
	changed.emit()


func _caught(_guard: Guard) -> void:
	# Keep the attempt summary until the player chooses Restart.
	StealthDirector.find(self).set_physics_process(false)
	finish(false)


func finish(escaped: bool) -> void:
	if _finished:
		return
	last_report = report(escaped)
	_finished = true
	ended.emit(last_report)
