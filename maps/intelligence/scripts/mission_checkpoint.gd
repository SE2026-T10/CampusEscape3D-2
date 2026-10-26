extends Checkpoint

## Keep the pre-document snapshot intact when returning during extraction.
func _physics_process(_delta: float) -> void:
	var mission := MapHudProvider.find_for(self) as K17MissionController
	var manager := CheckpointManager.find(self)
	var objectives := ObjectiveManager.find(self)
	var flow := GameFlow.find(self)
	if mission == null or manager == null or flow == null or mission.has_file or manager.active == self:
		return
	if flow.state != GameStateMachine.State.PLAYING or not manager.can_activate() or not contains_player():
		return
	if not objectives.is_completed(K17MissionController.PASS):
		return
	# Complete the reach objective first: the saved progress starts at FILE.
	objectives.try_complete(K17MissionController.ARCHIVE)
	manager.activate(self)
