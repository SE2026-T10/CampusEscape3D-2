extends SecurityAlarm
## Local incidents have a finite duration. The mission's exfiltration is a
## separate alert condition, without sending the player's position every tick.
func is_active() -> bool:
	var mission := get_tree().get_first_node_in_group("k17_mission") as K17MissionController
	return super() or (mission != null and mission.has_file and not mission.escaped)
