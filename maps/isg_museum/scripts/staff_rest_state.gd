extends PatrolState

var _actor: Guard

## The shared PATROL slot means resting/returning for G3, not a walking loop.
func enter(actor, previous: int, _position: Vector3) -> void:
	_actor = actor
	if previous == GuardStateMachine.NONE:
		actor.go_to_sleep()
	else:
		actor.forget_suspicion()
		actor.return_to_seat()


func update(actor, _perception: GuardPerception, delta: float) -> void:
	actor.update_rest(delta)


func exit(actor, _next: int) -> void:
	actor.stand_up()


func get_debug_text() -> String:
	if not is_instance_valid(_actor):
		return "staff rest"
	return "staff rest / " + String(_actor.phase)
