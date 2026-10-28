extends Interactable

## ObjectiveHud automatically displays feedback from this signal.
signal rejected(reason: String)


func get_prompt(_by: Node) -> String:
	var reason := _blocked_reason()
	return reason if reason != "" else prompt


func _on_interact(_by: Node) -> bool:
	var reason := _blocked_reason()
	if reason != "":
		rejected.emit(reason)
		return false
	var objectives := ObjectiveManager.find(self)
	objectives.record_escape_route(&"museum_rope", "Dây thoát bảo tàng")
	return objectives.complete(&"escape")


func _blocked_reason() -> String:
	var flow := GameFlow.find(self)
	if flow == null or flow.state != GameStateMachine.State.PLAYING:
		return "Lối thoát chưa sẵn sàng"
	var objectives := ObjectiveManager.find(self)
	if objectives == null or objectives.get_state(&"escape") != ObjectiveManager.State.ACTIVE:
		return "Cần lấy đủ 3 tác phẩm và dây trước"
	var director := StealthDirector.find(self)
	if director != null and director.status in [StealthDirector.Status.SPOTTED,
			StealthDirector.Status.CHASE, StealthDirector.Status.CAUGHT]:
		return "Hãy cắt đuôi và tránh tầm nhìn bảo vệ trước"
	# Check the guards too: the director's aggregate can lag by one frame.
	for guard in get_tree().get_nodes_in_group("guards"):
		if guard.vision != null and guard.vision.can_see_target:
			return "Hãy tránh tầm nhìn bảo vệ trước"
		if guard.machine != null and guard.machine.current == GuardStateMachine.CHASE:
			return "Hãy cắt đuôi bảo vệ trước"
	return ""
