extends Interactable

## Completing a protected artwork's objective is forwarded here by the map root.
## The event identifies the room, never the player's current position.
var alarm_enabled := true
var alarm_count := 0
var _reported := {}
var sound: AudioStreamPlayer3D


func _ready() -> void:
	super()
	add_to_group("museum_gallery_alarm")
	sound = AudioStreamPlayer3D.new()
	sound.max_distance = 25
	sound.volume_db = -7
	add_child(sound)
	_update_indicator()


func can_interact(by: Node) -> bool:
	var flow := GameFlow.find(self)
	return super(by) and flow != null and flow.state == GameStateMachine.State.PLAYING and not flow.is_leaving()


func get_prompt(_by: Node) -> String:
	return "Tắt niêm phong báo động phòng C" if alarm_enabled else "Niêm phong phòng C đã tắt"


func _on_interact(_by: Node) -> bool:
	disable_alarm()
	return true


func disable_alarm() -> void:
	alarm_enabled = false
	_update_indicator()
	$Label3D.text = "PHÒNG C\nBáo động đã tắt"


func artwork_taken(id: StringName) -> void:
	if not id in [&"take_t3",&"take_c2"] or _reported.has(id):
		return
	_reported[id] = true
	if not alarm_enabled:
		return
	alarm_count += 1
	var system := NoiseSystem.find(self)
	if system:
		system.emit_noise(global_position,NoiseEvent.Type.INTERACTION,"environment",1.0,22.0,1.0,"Báo động niêm phong phòng C")
	var contract := get_tree().get_first_node_in_group("museum_contract")
	if contract and contract.has_method("record_alarm"):
		contract.record_alarm("gallery_c_" + String(id))
	$Label3D.text = "PHÒNG C\nBÁO ĐỘNG · thiếu tác phẩm"
	_play_alarm()


func _update_indicator() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.8,0.15,0.08) if alarm_enabled else Color(0.15,0.8,0.25)
	material.emission_enabled = true
	material.emission = material.albedo_color
	$Indicator.material_override = material


func _play_alarm() -> void:
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = 22050
	var data := PackedByteArray()
	for i in 22050:
		var t := float(i)/22050.0
		var sample := int(sin(TAU*(650+sin(TAU*3*t)*180)*t)*7000)
		data.append(sample & 255)
		data.append((sample >> 8) & 255)
	clip.data = data
	sound.stream = clip
	sound.play()
