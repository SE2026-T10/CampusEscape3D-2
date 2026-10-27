extends StealthDirector
## K17 surveillance participates in the same visible/hidden HUD state.
func gather_flags(player: Node3D, guards: Array[Guard]) -> Dictionary:
	var flags:=super(player,guards)
	for camera in get_tree().get_nodes_in_group("security_cameras"):
		if camera.is_powered() and camera.can_see(player):
			flags.seen=true
			flags.hidden=false
			break
	return flags
