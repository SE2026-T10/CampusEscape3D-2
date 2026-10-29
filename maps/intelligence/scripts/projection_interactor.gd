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
	if is_instance_valid(_player.get("projection_rig")):
		var camera:=get_tree().get_first_node_in_group("k17_b1_surveillance")
		var hint: String="V camera trước/C1" if camera and camera.hacked and not camera.revoked else "Camera: cần chiếm kênh B1" if camera and not camera.revoked else "Camera: mất kết nối"
		return "[E] Thả tay đẩy · WASD đẩy/lùi · "+hint
	return super()
