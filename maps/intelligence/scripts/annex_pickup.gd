extends AccessCard

@onready var _seal: Node3D = $"../Tray/Seal"


func can_interact(by: Node) -> bool:
	var mission := MapHudProvider.find_for(self) as K17MissionController
	var flow := GameFlow.find(self)
	return super(by) and mission != null and mission.has_file and not mission.escaped and mission.time_left > 0.0 \
		and flow != null and flow.state == GameStateMachine.State.PLAYING and not flow.is_leaving()


func _update() -> void:
	var objectives := ObjectiveManager.find(self)
	var state := objectives.get_state(objective_id) if objectives else ObjectiveManager.State.LOCKED
	enabled = state == ObjectiveManager.State.ACTIVE
	visible = enabled
	_seal.visible = state == ObjectiveManager.State.LOCKED
	# Disabled pickup bounds must not hide any live target behind them.
	set_deferred("collision_layer", LAYER if enabled else 0)
