extends PlayerInteractor
## Release works while looking sideways; a hold-to-use cannot provide this.
func _unhandled_input(event: InputEvent) -> void:
	var rig = _player.get("projection_rig")
	if is_instance_valid(rig) and event.is_action_pressed("interact") and not event.is_echo():
		rig.release_grip()
		cancel_hold()
		get_viewport().set_input_as_handled()
		return
	super(event)

func find_target() -> Interactable:
	if is_instance_valid(_player.get("projection_rig")): return null
	return super()

func get_prompt_text() -> String:
	if is_instance_valid(_player.get("projection_rig")): return "[E] Thả tay đẩy · WASD đẩy/lùi · chuột quan sát"
	return super()
