extends SceneTree
const Art = preload("res://maps/isg_museum/tools/environment_art_builder.gd")
func _initialize():
	var art = Art.new()
	var tree = art.extract_visual_parts("vegetation/tree_small_02/tree_small_02_2k.gltf",[],false)
	print("BOUNDS ",art.compute_visual_bounds(tree))
	for node in tree.get_children():
		for s in node.mesh.get_surface_count():
			var arrays = node.mesh.surface_get_arrays(s)
			var im = ImporterMesh.new()
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
			im.generate_lods(25,60,[])
			var counts = []
			for i in im.get_surface_lod_count(0):
				counts.append(im.get_surface_lod_indices(0,i).size()/3)
			print(node.mesh.surface_get_material(s).resource_name, " original=",arrays[Mesh.ARRAY_INDEX].size()/3, " LODS ",counts)
	tree.free()
	quit()
