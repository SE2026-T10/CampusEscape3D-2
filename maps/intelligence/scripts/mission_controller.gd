class_name K17MissionController
extends MapHudProvider

## Scene-local mission state. AI, player, interaction and HUD stay shared.
const ENTER := &"enter_k17"
const PASS := &"take_pass"
const CODE := &"take_vault_code"
const ARCHIVE := &"reach_archive"
const VAULT := &"open_vault"
const FILE := &"take_intelligence"
const ESCAPE := &"extract_k17"
const PREPARED := &"prepare_backdoor"
const CAMERAS_OFF := &"disable_cameras"
const SABOTAGE := &"sabotage_k17"
const SabotageConfig := preload("res://maps/intelligence/resources/layout/k17_sabotage.gd")
const OBJECTIVES := [
	{"id": ENTER, "requires": [], "title": "Vào cơ sở K17", "hint": "Qua sân tiếp vận hoặc hành lang kỹ thuật.", "done": "Đã vào K17"},
	{"id": PASS, "requires": [ENTER], "title": "Lấy giấy thông hành", "hint": "Trên bàn phòng trực phía tây. Có thể tìm chỉ dẫn trước.", "done": "Đã mang giấy thông hành"},
	{"id": CODE, "requires": [ENTER], "title": "Đọc chỉ dẫn kho mật", "hint": "Bàn vô tuyến ở khối chỉ huy. J xem lại tài liệu đã đọc.", "done": "Đã lưu chỉ dẫn kho B1"},
	{"id": ARCHIVE, "requires": [PASS,CODE], "title": "Đến checkpoint khu mật", "hint": "Qua cửa hồ sơ, đi hành lang phải đến điểm chuẩn bị.", "done": "Đã lưu checkpoint trước kho mật"},
	{"id": VAULT, "requires": [ARCHIVE], "title": "Giải mã cửa kho B1", "hint": "Đối chiếu bảng ca trực tại checkpoint với chỉ dẫn trong nhật ký. E đổi chữ số và xác nhận.", "done": "Đã mở kho mật B1"},
	{"id": FILE, "requires": [VAULT], "title": "Thu hồi Mật lệnh 04", "hint": "Qua cảm biến tới hốc B1. Dùng màn chiếu đánh lừa chốt, tránh tuần tra bên hông, tới phòng hồ sơ.", "done": "Đã lấy Mật lệnh 04 — rút lui!"},
	{"id": ESCAPE, "requires": [FILE], "title": "Đến điểm tập kết", "hint": "Trở ra ngoài qua sân hoặc bảo trì. Tìm đèn xanh trước khi hết giờ.", "done": "Đã đưa hồ sơ ra khỏi K17"},
	{"id": PREPARED, "requires": [ENTER], "optional":true,"title":"Chuẩn bị cửa hậu","hint":"Chốt cơ trong trạm điện.","done":"Cửa hậu đã được chuẩn bị"},
	{"id": CAMERAS_OFF,"requires": [ENTER],"optional":true,"title":"Ngắt nguồn camera chính","hint":"Công tắc ở trạm điện.","done":"Đã ngắt camera trước khi lấy hồ sơ"},
	{"id": SABOTAGE,"requires": [FILE],"optional":true,"title":"Phá hủy cụm tình báo dự phòng","hint":"Tùy chọn: sau hồ sơ, giữ E 5 giây tại tủ trong xưởng phía đông rồi rút trước khi hết 120 giây. Kích hoạt sau khi thoát.","done":"Đã phá hủy cụm tình báo dự phòng"},
]

@export_range(1.0, 600.0) var escape_duration := 120.0
@export var courtyard_warning_at := 70.0
@export var courtyard_close_at := 90.0
@export var reinforcement_at := 100.0
var has_file := false
var time_left := 120.0
var escaped := false
var timeouts := 0
var backdoor_prepared := false
var sensor_trips := 0
var radio_uses := 0
var lockdown_warned := false
var lockdown_closed := false
var reinforcement_sent := false
var radio_message := "Lam: Thu hồi Mật lệnh 04 ở B1. Bộ màn chiếu cấp sẵn dùng tại hốc hiệu chỉnh. Chuẩn bị đường rút; phá niêm phong mới bắt đầu hai phút."
var _dialogue_left := 5.0
var _dialogue_priority := 0
var _dialogue_queue: Array[Dictionary] = []
var _dialogue_keys: Array[String] = []
var run_id := 0
var extraction_play_time := 0.0
var finale_pending := false
var _finale_left := 0.0
var _result_complete := false


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
			queue_radio("Lam: Phòng trực ở phía tây. Bảng chốt trong khu kỹ thuật giúp mở nhanh cửa hậu.",1,"entered")
		PASS:
			queue_radio("Lam: Có thẻ rồi. Đọc chỉ dẫn kho ở bàn vô tuyến; có thể ngắt camera và chuẩn bị cửa hậu trước.",2,"pass")
		CODE:
			queue_radio("Lam: J xem lại chỉ dẫn. Tại checkpoint khu mật có bảng đối chiếu để suy ra mã cửa B1.",3,"code")
		ARCHIVE:
			queue_radio("Lam: Đọc bảng ca trực bên cạnh, đối chiếu với chỉ dẫn rồi nhập mã tại cửa kho.",2,"archive")
		VAULT:
			queue_radio("Lam: Kho đã mở. Qua cảm biến lúc xanh, tới hốc hiệu chỉnh B1. Màn chiếu chỉ che hướng chốt chính; nghe tuần tra bên hông. Lấy hồ sơ mới bắt đầu hai phút.",3,"vault")
		FILE:
			if has_file:
				return
			has_file = true
			time_left = escape_duration
			_dialogue_queue.clear()
			_dialogue_left = 0.0
			_dialogue_priority = -1
			queue_radio("Lam: Niêm phong đã bị phá! Cửa hậu đang khóa cơ, cổng sân đóng sau %d giây."%ceili(courtyard_close_at),6,"file")
			queue_radio("Lam: Tùy chọn: đặt thiết bị ở tủ tình báo trong xưởng phía đông. Đồng hồ vẫn chạy; chỉ kích hoạt khi đã về tập kết!",3,"sabotage_offer")
			_set_alarm_lights(true)
			var back_gate := get_security_node("MaintenanceGate")
			if back_gate: back_gate.call("request_close")
			var audio := AudioDirector.find(self)
			if audio:
				audio.play_sfx("alarm", -8.0)


func _physics_process(delta: float) -> void:
	var flow := GameFlow.find(self)
	if flow == null or flow.state != GameStateMachine.State.PLAYING:
		return
	if flow.is_leaving(): return
	if finale_pending:
		_finale_left -= delta
		if _finale_left <= 0.0: complete_finale(run_id)
		return
	_update_dialogue(delta)
	if not has_file or escaped: return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0:
		if flow.fail("Đã hết thời gian rút lui. Cơ sở K17 bị phong tỏa."): timeouts += 1
		return
	var elapsed := escape_duration - time_left
	if elapsed >= courtyard_warning_at and not lockdown_warned:
		lockdown_warned = true
		queue_radio("Loa K17: Cổng sân đóng sau %d giây. Lam: Nếu không kịp, chuyển sang cửa hậu phía đông!"%ceili(courtyard_close_at-elapsed),7,"warning")
		_play_cue("relay")
	if elapsed >= courtyard_close_at and not lockdown_closed:
		lockdown_closed = true
		var gate := get_security_node("CourtyardGate")
		if gate: gate.call("request_close")
		queue_radio("Loa K17: Đóng cổng sân! Lam: Dùng chốt mở cơ ở cửa hậu nếu cổng đã khóa.",8,"closed")
	if elapsed >= reinforcement_at and not reinforcement_sent:
		reinforcement_sent = true
		# A real loudspeaker position, heard through the existing hearing rules.
		var noise := NoiseSystem.find(self)
		var radio := get_security_node("Radio")
		if noise and radio:
			noise.emit_noise(radio.get_node("Static").global_position,NoiseEvent.Type.INTERACTION,&"lockdown",.9,16.0,-1.0,"Loa chốt cửa hậu")
		queue_radio("Loa K17: Tăng kiểm soát chốt phía đông. Lam: Còn %d giây, tiếp tục về đèn tập kết!"%ceili(time_left),6,"reinforce")


func try_extract(route: StringName, title: String) -> bool:
	var flow := GameFlow.find(self)
	var objectives := ObjectiveManager.find(self)
	if flow == null or flow.state != GameStateMachine.State.PLAYING or flow.is_leaving() or not has_file or escaped or time_left <= 0.0:
		return false
	var director := StealthDirector.find(self)
	if director == null or director.status == StealthDirector.Status.CAUGHT: return false
	if objectives.current() != ESCAPE:
		return false
	escaped = true
	extraction_play_time = flow.play_time
	var player := get_tree().get_first_node_in_group("player")
	if player: player.get_node("Interactor").cancel_hold()
	objectives.record_escape_route(route, title)
	director.finish_level()
	_freeze_security(true)
	var sabotage := get_parent().get_node_or_null("Sabotage")
	if sabotage and sabotage.armed:
		finale_pending = true
		_finale_left = SabotageConfig.FINALE_WATCHDOG
		var finale := get_parent().get_node_or_null("ExtractionFinale")
		if finale == null or not finale.start(route, run_id): complete_finale(run_id)
	else:
		_finish_result()
	return true


func detonate_sabotage(token: int) -> bool:
	var flow := GameFlow.find(self)
	if token != run_id or not escaped or not finale_pending or flow == null or flow.is_leaving() or flow.state != GameStateMachine.State.PLAYING: return false
	var sabotage := get_parent().get_node_or_null("Sabotage")
	if sabotage == null: return false
	if not sabotage.detonated and not sabotage.detonate(): return false
	ObjectiveManager.find(self).try_complete(SABOTAGE)
	return true


func complete_finale(token: int) -> void:
	var flow := GameFlow.find(self)
	if token != run_id or not escaped or not finale_pending or flow == null or flow.is_leaving() or flow.state != GameStateMachine.State.PLAYING: return
	detonate_sabotage(token)
	finale_pending = false
	var finale := get_parent().get_node_or_null("ExtractionFinale")
	if finale: finale.cancel()
	_finish_result()


func _finish_result() -> void:
	if _result_complete: return
	_result_complete = true
	ObjectiveManager.find(self).try_complete(ESCAPE)


func _freeze_security(frozen: bool) -> void:
	# Stop pending radio/sensor/camera events, not just the actors frozen by the director.
	for path in ["Security", "Cameras"]:
		var node := get_parent().get_node_or_null(path)
		if node: node.process_mode = Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT


func get_status_lines() -> Array[String]:
	var clock := "Chưa kích hoạt"
	if has_file:
		var seconds := ceili(time_left)
		clock = "%02d:%02d" % [seconds / 60, seconds % 60]
	var title := "K17 V6 / TEST MAP — KHÔNG LÍNH GÁC" if is_test_mode() else "K17 V6 / CHIẾN DỊCH TÌNH BÁO"
	var power:=get_parent().get_node_or_null("PowerNetwork")
	var source: String="dự phòng" if power and power.get("backup_active") else "nguồn chính"
	var cameras: String="BẬT" if power and power.is_powered(&"surveillance") else "TẮT"
	var sabotage := get_parent().get_node_or_null("Sabotage")
	var lines: Array[String] = [title, "Hồ sơ: " + ("đang mang Mật lệnh 04" if has_file else "chưa thu hồi"),
		"Phong tỏa: " + clock + _reinforcement_status(),
		"Camera: "+cameras+" · "+source,
		"Cổng sân: " + ("sắp đóng" if lockdown_warned and not lockdown_closed else _gate_status("CourtyardGate")),
		"Cửa hậu: " + _gate_status("MaintenanceGate") + (" · đã chuẩn bị" if backdoor_prepared else " · khóa cơ 8 giây")]
	if sabotage: lines.append("Phá hoại: " + sabotage.status_text())
	lines.append(radio_message)
	return lines


func show_objective_checklist() -> bool:
	return false


func get_result_lines() -> Array[String]:
	var objectives := ObjectiveManager.find(self)
	var team:=get_parent().get_node_or_null("Reinforcements")
	var dispatched: int=int(team.get("spawned_count")) if team else 0
	var summary := "TEST MAP · Đã đưa hồ sơ ra khỏi K17." if is_test_mode() else "Mật lệnh 04 đã được đưa ra khỏi K17."
	var sabotage := get_parent().get_node_or_null("Sabotage")
	var destroyed: bool = sabotage != null and sabotage.detonated
	if destroyed: summary = ("TEST MAP · " if is_test_mode() else "") + "Mật lệnh 04 an toàn; cụm tình báo dự phòng đã bị phá hủy."
	return [summary, "Phá hoại: " + ("hoàn tất" if destroyed else "chưa thực hiện · tùy chọn"), "Còn lại: %d giây · Hết giờ: %d lần" % [ceili(time_left), timeouts],
		"Đường rút: " + objectives.escape_route_name,
		"Cảm biến: %d lần · Radio: %d lần" % [sensor_trips,radio_uses],
		"Cửa hậu: " + ("đã chuẩn bị" if backdoor_prepared else "chưa chuẩn bị")+" · Tiếp viện: %d/4"%dispatched]


func is_test_mode() -> bool:
	return owner != null and owner.is_in_group("k17_no_guards")


func _reinforcement_status() -> String:
	var team:=get_parent().get_node_or_null("Reinforcements")
	return " · tiếp viện %d/4"%team.get("spawned_count") if team and has_file and not is_test_mode() else ""


func get_checkpoint_state() -> Dictionary:
	return {"has_file": has_file, "time_left": time_left, "escaped": escaped,
		"prepared":backdoor_prepared,"warned":lockdown_warned,"closed":lockdown_closed,"reinforced":reinforcement_sent}


func restore_checkpoint_state(saved: Dictionary) -> void:
	run_id += 1
	finale_pending = false
	_result_complete = false
	extraction_play_time = 0.0
	_finale_left = 0.0
	var finale := get_parent().get_node_or_null("ExtractionFinale")
	if finale: finale.cancel()
	_freeze_security(false)
	has_file = bool(saved.get("has_file", false))
	time_left = float(saved.get("time_left", escape_duration))
	escaped = bool(saved.get("escaped", false))
	backdoor_prepared = bool(saved.get("prepared",false))
	lockdown_warned = bool(saved.get("warned",false))
	lockdown_closed = bool(saved.get("closed",false))
	reinforcement_sent = bool(saved.get("reinforced",false))
	_dialogue_queue.clear()
	_dialogue_keys.clear()
	_dialogue_left = 0.0
	_dialogue_priority = -1
	_set_alarm_lights(has_file)


func _on_respawned(_checkpoint: Checkpoint) -> void:
	queue_radio("Lam: Thử lại. Hồ sơ vẫn niêm phong; màn trở về hốc chuẩn bị, cảm biến về nhịp đã lưu.",9,"retry")
	var player := get_tree().get_first_node_in_group("player")
	if player: player.get_node("Interactor").cancel_hold()


func get_security_node(node_name: String) -> Node:
	return get_parent().get_node_or_null("Security/"+node_name)


func _gate_status(node_name: String) -> String:
	var gate := get_security_node(node_name)
	if gate == null: return "đang mở"
	return "đã khóa" if gate.get("is_closed") else "chờ đóng an toàn" if gate.get("closing_pending") else "đang mở"


func record_sensor_trip(at: Vector3) -> void:
	sensor_trips += 1
	var alarm := SecurityAlarm.find(self)
	if alarm: alarm.raise_alarm(at,"Cắt dải cảm biến phòng hồ sơ",18.0)
	queue_radio("Lam: Cảm biến vừa báo động. Lính đang kiểm tra nguồn tín hiệu; tìm vật che!",4,"sensor_"+str(sensor_trips))
	_play_cue("alarm")


func _play_cue(cue: String) -> void:
	var audio := AudioDirector.find(self)
	if audio: audio.play_sfx("alarm" if cue == "alarm" else "door_locked",-10.0)


func queue_radio(text: String, priority := 0, key := "") -> void:
	if key != "" and _dialogue_keys.has(key): return
	if key != "": _dialogue_keys.append(key)
	if priority >= _dialogue_priority or _dialogue_left <= 0.0:
		radio_message = text
		_dialogue_left = 5.0
		_dialogue_priority = priority
	else:
		_dialogue_queue.append({"text":text,"priority":priority})
		if _dialogue_queue.size() > 6: _dialogue_queue.pop_front()


func _update_dialogue(delta: float) -> void:
	_dialogue_left = maxf(_dialogue_left-delta,0.0)
	if _dialogue_left > 0.0: return
	_dialogue_priority = -1
	if not _dialogue_queue.is_empty():
		_dialogue_queue.sort_custom(func(a,b): return a.priority > b.priority)
		var next := _dialogue_queue.pop_front() as Dictionary
		queue_radio(next.text,next.priority)


func _set_alarm_lights(active: bool) -> void:
	for light in get_tree().get_nodes_in_group("k17_alarm_lights"):
		light.light_color = Color(1.0, 0.18, 0.1) if active else Color(0.55, 0.75, 1.0)
		if light.has_meta("alarm_only"):
			light.visible = active
