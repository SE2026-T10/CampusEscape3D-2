extends "res://maps/isg_museum/scripts/museum_door.gd"

## The staff calendar and note explain this code; reading them is optional.
const CODE := "1403"
var wrong_attempts := 0
var alarm_count := 0
var keypad: CanvasLayer
var audio: AudioStreamPlayer3D


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
	if unlocked:
		return super(by)
	keypad.open_for(self,by)
	return true


func _blocked_reason(_by: Node) -> String:
	return "" if unlocked else "Cần mã kho phụ — xem lịch C và ghi chú G"


func submit_code(value: String, by: Node) -> bool:
	if not can_interact(by) or unlocked or not by is Node3D \
			or (by as Node3D).global_position.distance_to(global_position) > 3.0:
		return false
	if value == CODE:
		unlocked = true
		wrong_attempts = 0
		_indicator(Color(0.15,0.8,0.3))
		beep(900,0.12)
		return super._on_interact(by)
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
	return false


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
