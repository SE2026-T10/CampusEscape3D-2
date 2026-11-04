extends Node3D

## The inherited test scene uses the same map and mission. Remove guards before
## any child enters the tree: no AI, bodies, hearing or navigation agents remain.
func _enter_tree() -> void:
	add_to_group("k17_no_guards")
	var guards := get_node("Guards")
	for guard in guards.get_children():
		guards.remove_child(guard)
		guard.free()
