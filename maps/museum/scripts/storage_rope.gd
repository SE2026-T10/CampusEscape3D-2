extends "res://maps/museum/scripts/demo_pickup.gd"

func can_interact(by: Node) -> bool:
	var door := get_node("../../NavigationRegion3D/Doors/Storage")
	return super(by) and door.unlocked
