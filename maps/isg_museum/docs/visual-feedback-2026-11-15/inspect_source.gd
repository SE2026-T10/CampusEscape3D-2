extends SceneTree
func _initialize() -> void:
	var art := preload("res://maps/isg_museum/tools/environment_art_builder.gd").new()
	for id in ["Object_4","Object_5"]:
		var part := art.extract_visual_parts("architecture/gothic_architectural_structures/gothic_architectural_structures.glb",[id],false)
		print(id," ancestor-transformed bounds: ",art.compute_visual_bounds(part))
		for mesh in part.get_children():
			print("mesh transform: ",mesh.transform," native bounds: ",mesh.mesh.get_aabb())
		part.free()
	quit()
