extends Checkpoint
@export var complete_archive := true

## Keep the pre-document snapshot intact when returning during extraction.
func _physics_process(_delta: float) -> void:
	var mission := MapHudProvider.find_for(self) as K17MissionController
	var manager := CheckpointManager.find(self)
	var objectives := ObjectiveManager.find(self)
	var flow := GameFlow.find(self)
	if mission == null or manager == null or flow == null or mission.has_file:
		return
	if manager.active == self and objectives.get_progress() == manager.saved_progress: return
	if flow.state != GameStateMachine.State.PLAYING or not manager.can_activate() or not contains_player():
		return
	if not objectives.is_completed(K17MissionController.CODE) or not objectives.is_completed(K17MissionController.PASS):
		return
	# Complete the reach objective before capturing this checkpoint's progress.
	if complete_archive: objectives.try_complete(K17MissionController.ARCHIVE)
	manager.activate(self)
