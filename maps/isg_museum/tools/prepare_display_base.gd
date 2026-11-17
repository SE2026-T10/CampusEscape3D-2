extends "res://maps/isg_museum/tools/prepare_tree_lod.gd"

## Separate the opaque lower part of the single-mesh display case offline.
func run() -> void:
	var art := Art.new()
	var source := art.extract_visual_parts("exhibits/small_museum_display_case/small_museum_display_case.glb",[],false)
	var bounds := art.compute_visual_bounds(source)
	var cut := bounds.position.y+bounds.size.y*.48
	var count := 0
	for visual in source.get_children():
		var mesh := ArrayMesh.new()
		for surface in visual.mesh.get_surface_count():
			var arrays: Array = visual.mesh.surface_get_arrays(surface)
			var selected := PackedInt32Array()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for triangle in indices.size()/3:
				var keep := true
				for corner in 3:
					keep = keep and (visual.transform*vertices[indices[triangle*3+corner]]).y <= cut
				if keep:
					for corner in 3:
						selected.append(indices[triangle*3+corner])
			if selected.is_empty():
				continue
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,compact(arrays,selected))
			mesh.surface_set_material(mesh.get_surface_count()-1,visual.mesh.surface_get_material(surface))
			count += selected.size()/3
		visual.mesh = mesh
	art.assign_owners(source,source)
	var packed := PackedScene.new()
	assert(packed.pack(source) == OK)
	assert(ResourceSaver.save(packed,OUTPUT+"display_case_base.scn") == OK)
	print("Display base triangles: ",count,"; removed glass and upper frame; CC BY source metadata preserved")
	source.free()
	quit()
