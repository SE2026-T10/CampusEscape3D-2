extends "res://maps/isg_museum/scripts/museum_door.gd"

## The staff calendar and note explain this code; reading them is optional.
var wrong_attempts := 0
var alarm_count := 0
var keypad: CanvasLayer
var audio: AudioStreamPlayer3D
## One door instance per attempt. Each entry binds an ID to its original code.
var _submissions: Dictionary = {}
var _active_submission := false
var _pending_id := ""
var _keypad_sequence := 0


func _ready() -> void:
	super()
	unlocked = false
	keypad = preload("res://maps/isg_museum/scripts/storage_keypad.gd").new()
	add_child(keypad)
	audio = AudioStreamPlayer3D.new()
	audio.max_distance = 18
	add_child(audio)
	_indicator(Color(0.8,0.15,0.08))


func get_prompt(_by: Node) -> String:
	if not unlocked:
		return "Nhập mã cửa kho phụ"
	return "Đóng cửa kho phụ" if is_open else "Mở cửa kho phụ"


func _on_interact(by: Node) -> bool:
	if _active_submission:
		return false
	if unlocked:
		return super(by)
	keypad.open_for(self,by)
	return true


func _blocked_reason(_by: Node) -> String:
	return "" if unlocked else "Cần mã kho phụ — xem lịch C và ghi chú G"


func submit_code(value: String, by: Node) -> bool:
	if _active_submission:
		return false
	_active_submission = true
	var result := _apply_submission(value, by)
	_active_submission = false
	return result == &"UNLOCKED"


func next_keypad_request_id() -> String:
	_keypad_sequence += 1
	var id := "keypad-%d" % _keypad_sequence
	while _submissions.has(id):
		_keypad_sequence += 1
		id = "keypad-%d" % _keypad_sequence
	return id


## Scope is the door instance ID; callers retain it and the ID for retries.
func submit_code_request(scope: Variant, request_id: Variant, code: Variant, by: Node) -> Dictionary:
	var id: String = request_id if request_id is String else ""
	if not scope is int or not _valid_request_id(id) or not code is String or not _is_code(code):
		return _receipt(&"INVALID_REQUEST", id)
	if scope != get_instance_id() or not is_inside_tree() \
			or not is_instance_valid(by) or by != get_tree().get_first_node_in_group("player"):
		return _receipt(&"STALE_SCOPE", id)
	var entry: Dictionary = _submissions.get(id, {})
	if not entry.is_empty():
		if entry.code != code:
			return _receipt(&"CONFLICT", id)
		if entry.has("receipt"):
			return entry.receipt.duplicate()
		if _pending_id == id:
			return _receipt(&"IN_PROGRESS", id)
	if _active_submission:
		return _receipt(&"BUSY", id)

	# The shared operation emits synchronous signals. Reserve before calling it.
	if entry.is_empty():
		entry = {"code": code}
		_submissions[id] = entry
	_active_submission = true
	_pending_id = id
	var result := _apply_submission(code, by)
	var alarm := result == &"WRONG_CODE_ALARM"
	var receipt := _receipt(&"WRONG_CODE" if alarm else result, id, alarm)
	if receipt.status in [&"UNLOCKED", &"WRONG_CODE"]:
		entry.receipt = receipt
	_pending_id = ""
	_active_submission = false
	return receipt.duplicate()


func _receipt(status: StringName, id: String, alarm := false) -> Dictionary:
	var processed := status in [&"UNLOCKED", &"WRONG_CODE"]
	return {"status": status, "request_id": id, "alarm_triggered": alarm,
		"wrong_attempts_after": wrong_attempts if processed else null,
		"alarm_count_after": alarm_count if processed else null}


static func _valid_request_id(id: String) -> bool:
	if id.is_empty() or id.length() > 64:
		return false
	for i in id.length():
		var c := id.unicode_at(i)
		if not ((c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 45 or c == 95):
			return false
	return true


static func _is_code(value: String) -> bool:
	if value.length() != 4:
		return false
	for i in value.length():
		var c := value.unicode_at(i)
		if c < 48 or c > 57:
			return false
	return true


func _apply_submission(value: String, by: Node) -> StringName:
	if unlocked or is_open:
		return &"ALREADY_UNLOCKED"
	if not can_interact(by) or not by is Node3D \
			or (by as Node3D).global_position.distance_to(global_position) > 3.0:
		return &"RETRYABLE"
	if value == current_code():
		unlocked = true
		wrong_attempts = 0
		_indicator(Color(0.15,0.8,0.3))
		beep(900,0.12)
		# Closed and now unlocked: the parent takes its successful opening branch.
		super._on_interact(by)
		return &"UNLOCKED"
	wrong_attempts += 1
	var alarm := wrong_attempts >= 3
	if alarm:
		wrong_attempts = 0
		alarm_count += 1
		var contract := get_tree().get_first_node_in_group("museum_contract")
		if contract:
			contract.record_alarm("storage")
	beep(300 if alarm else 520,0.65 if alarm else 0.1)
	var noise := NoiseSystem.find(self)
	if noise:
		noise.emit_noise(global_position+Vector3.UP,NoiseEvent.Type.INTERACTION,"environment",
			1.0 if alarm else 0.15,14.0 if alarm else 2.0,1.0,
			"Cảnh báo nhập sai mã kho phụ" if alarm else "Bíp bàn phím kho phụ")
	rejected.emit("Sai mã ba lần — tiếng cảnh báo có thể thu hút bảo vệ!" if alarm else "Sai mã kho phụ")
	return &"WRONG_CODE_ALARM" if alarm else &"WRONG_CODE"


func current_code() -> String:
	var calendar := get_tree().get_first_node_in_group("staff_calendar")
	return calendar.get_code()


func _indicator(colour: Color) -> void:
	var screen := get_node_or_null("../../Geometry/StorageInterior/KeypadScreen") as MeshInstance3D
	if screen:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colour
		mat.emission_enabled = true
		mat.emission = colour
		screen.material_override = mat


func beep(frequency: float, duration: float) -> void:
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = 22050
	var samples := PackedByteArray()
	for i in int(duration*22050):
		var t := float(i)/22050
		var sample := int(sin(TAU*frequency*t)*minf(1,(duration-t)*40)*7000)
		samples.append(sample & 255)
		samples.append((sample >> 8) & 255)
	clip.data = samples
	audio.stream = clip
	audio.play()
