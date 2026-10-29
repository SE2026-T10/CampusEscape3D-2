extends StealthDirector
## K17 surveillance participates in the same visible/hidden HUD state.
func gather_flags(player: Node3D, guards: Array[Guard]) -> Dictionary:
	var flags:=super(player,guards)
	for camera in get_tree().get_nodes_in_group("security_cameras"):
		if camera.is_powered() and camera.can_see(player):
			flags.seen=true
			flags.hidden=false
			break
	var b1:=get_tree().get_first_node_in_group("k17_b1_surveillance")
	if b1 and (not b1.hacked or b1.revoked) and b1.cctv_sees(player):
		flags.seen=true
		flags.hidden=false
	return flags
