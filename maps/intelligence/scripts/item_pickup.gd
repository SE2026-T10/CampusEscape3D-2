extends ItemPickup
func get_item_name() -> String: return "Chai rỗng"
func get_prompt(_by: Node) -> String:
	var inventory := PlayerInventory.find(self)
	return "Túi đầy · ném bớt chai bằng F" if inventory and inventory.is_full() else "Lấy chai rỗng · F để gây tiếng động"
