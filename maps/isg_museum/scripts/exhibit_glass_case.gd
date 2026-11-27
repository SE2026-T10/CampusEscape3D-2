extends Interactable

## Display base already has world collision; glass is transparent decoration.
## One press breaks the glass, a separate press collects the small sculpture.
@export var objective_id: StringName = &"take_s1"
@export var exhibit_name := "S1 · Tượng chim đồng"
var broken := false
var collected := false
var sound: AudioStreamPlayer3D


func _ready() -> void:
	super()
	sound = AudioStreamPlayer3D.new()
	sound.max_distance = 20
	sound.volume_db = -8
	add_child(sound)


func can_interact(by: Node) -> bool:
	var flow := GameFlow.find(self)
	var objectives := ObjectiveManager.find(self)
	return super(by) and not collected and flow != null \
		and flow.state == GameStateMachine.State.PLAYING and not flow.is_leaving() \
		and objectives != null and objectives.get_state(objective_id) == ObjectiveManager.State.ACTIVE


func get_prompt(_by: Node) -> String:
	return ("Lấy " if broken else "Đập kính tủ ") + exhibit_name


func _on_interact(_by: Node) -> bool:
	if not broken:
		broken = true
		$Glass.hide()
		$Shards.show()
		$Label3D.text = exhibit_name + "\nKính đã vỡ · E lấy hiện vật"
		var noise := NoiseSystem.find(self)
		if noise:
			noise.emit_noise(global_position,NoiseEvent.Type.INTERACTION,"environment",1.0,16.0,1.0,"Kính tủ trưng bày vỡ")
		var contract := get_tree().get_first_node_in_group("museum_contract")
		if contract and contract.has_method("record_alarm"):
			contract.record_alarm("glass_" + String(objective_id))
		if contract and contract.has_method("record_glass_break"):
			contract.record_glass_break()
		_play_break()
		return true
	var objectives := ObjectiveManager.find(self)
	if objectives == null or not objectives.complete(objective_id):
		return false
	collected = true
	$Artifact.hide()
	$Label3D.text = exhibit_name + "\nTủ trống · kính đã vỡ"
	enabled = false
	collision_layer = 0
	return true


func _play_break() -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := PackedByteArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for i in 6615:
		var t := float(i)/22050.0
		var wave := rng.randf_range(-1,1)*0.6 + sin(TAU*1900*t)*0.25 + sin(TAU*3100*t)*0.15
		var sample := int(wave*exp(-t*14)*18000)
		samples.append(sample & 255)
		samples.append((sample >> 8) & 255)
	stream.data = samples
	sound.stream = stream
	sound.play()
