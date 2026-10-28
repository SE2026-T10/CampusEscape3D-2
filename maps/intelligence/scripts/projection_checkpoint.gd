extends "res://maps/intelligence/scripts/mission_checkpoint.gd"

func _physics_process(delta: float) -> void:
	var objectives := ObjectiveManager.find(self)
	if objectives==null or not objectives.is_completed(K17MissionController.VAULT): return
	super(delta)
