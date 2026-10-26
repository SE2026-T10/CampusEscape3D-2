class_name K17Radio
extends Interactable
@export var activation_delay := 4.0
@export var cooldown_duration := 20.0
@export var noise_radius := 36.0
@export var indoor_noise_radius := 24.0
var pending_left := 0.0
var cooldown_left := 0.0
var uses := 0

func _ready() -> void:
	super()
	add_to_group("checkpoint_state")

func can_interact(by: Node) -> bool:
	var flow := GameFlow.find(self)
	return super(by) and pending_left <= 0.0 and cooldown_left <= 0.0 and flow != null and flow.state == GameStateMachine.State.PLAYING

func get_prompt(_by: Node) -> String:
	if pending_left > 0.0: return "Radio sẽ phát sau %d giây" % ceili(pending_left)
	if cooldown_left > 0.0: return "Radio đang hồi · %d giây" % ceili(cooldown_left)
	return "Hẹn radio gây nhiễu qua loa sau 4 giây"

func _on_interact(_by: Node) -> bool:
	pending_left = activation_delay
	cooldown_left = cooldown_duration
	var mission := MapHudProvider.find_for(self) as K17MissionController
	if mission: mission.queue_radio("An: Đã hẹn tiếng rè. Rời khỏi bàn radio trước khi nó phát.",2,"radio_armed")
	return true

func _physics_process(delta: float) -> void:
	var flow := GameFlow.find(self)
	if flow == null or flow.state != GameStateMachine.State.PLAYING: return
	cooldown_left = maxf(cooldown_left-delta,0.0)
	if pending_left <= 0.0: return
	pending_left = maxf(pending_left-delta,0.0)
	if pending_left > 0.0: return
	uses += 1
	$Static.play()
	$IndoorStatic.play()
	var noise := NoiseSystem.find(self)
	if noise:
		for speaker in [$Static,$IndoorStatic]:
			var radius := noise_radius if speaker == $Static else indoor_noise_radius
			noise.emit_noise(speaker.global_position,NoiseEvent.Type.INTERACTION,&"radio",1.0,radius,-1.0,"Loa radio rè")
	var mission := MapHudProvider.find_for(self) as K17MissionController
	if mission: mission.radio_uses += 1

func get_checkpoint_state() -> Dictionary:
	# A delayed transmission from the old attempt is never replayed on retry.
	return {"cooldown":cooldown_left}

func restore_checkpoint_state(saved: Dictionary) -> void:
	pending_left = 0.0
	cooldown_left = float(saved.get("cooldown",0.0))
	$Static.stop()
	$IndoorStatic.stop()
