extends Area3D

@export var cooldown := 3.0
var triggers := 0
var _next_noise := 0.0
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_bumped)
	_audio = AudioStreamPlayer3D.new()
	_audio.max_distance = 14
	_audio.volume_db = -9
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = 22050
	var samples := PackedByteArray()
	for i in 3308:
		var t := float(i)/22050
		var value := int((sin(TAU*1350*t)+sin(TAU*2170*t)*0.4)*exp(-t*32)*11000)
		samples.append(value & 255)
		samples.append((value >> 8) & 255)
	clip.data = samples
	_audio.stream = clip
	add_child(_audio)


func _bumped(by: Node3D) -> void:
	if not by.is_in_group("player"):
		return
	var flow := GameFlow.find(self)
	var system := NoiseSystem.find(self)
	if system == null or flow == null or flow.state != GameStateMachine.State.PLAYING or system.now < _next_noise:
		return
	_next_noise = system.now+cooldown
	triggers += 1
	system.emit_noise(global_position,NoiseEvent.Type.INTERACTION,"environment",1.0,10.0,0.8,"Chai/lon va vào nhau")
	_audio.play()
