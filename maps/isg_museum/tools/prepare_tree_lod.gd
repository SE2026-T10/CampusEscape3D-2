extends SceneTree

## Offline Godot meshoptimizer reduction. Only reduced meshes enter gameplay.
const Art := preload("res://maps/isg_museum/tools/environment_art_builder.gd")
const OUTPUT := "res://maps/isg_museum/assets/models/derived/"

func _initialize() -> void:
	run.call_deferred()

func compact(arrays: Array, indices: PackedInt32Array) -> Array:
	var output := arrays.duplicate()
	var remap := {}
	var old_indices: Array[int] = []
	var new_indices := PackedInt32Array()
	for index in indices:
		if not remap.has(index):
			remap[index] = old_indices.size()
			old_indices.append(index)
		new_indices.append(remap[index])
	for slot in Mesh.ARRAY_INDEX:
		if arrays[slot] == null or arrays[slot].is_empty():
			continue
		var stride := 4 if slot == Mesh.ARRAY_TANGENT else 1
		var reduced = arrays[slot].duplicate()
		reduced.resize(old_indices.size()*stride)
		for i in old_indices.size():
			for component in stride:
				reduced[i*stride+component] = arrays[slot][old_indices[i]*stride+component]
		output[slot] = reduced
	output[Mesh.ARRAY_INDEX] = new_indices
	return output

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var art := Art.new()
	var source := art.extract_visual_parts("vegetation/tree_small_02/tree_small_02_2k.gltf",[],false)
	var near := Node3D.new()
	var far := Node3D.new()
	var stats := {"source_triangles":0,"near_triangles":0,"far_triangles":0}
	for instance in source.get_children():
		var near_mesh := ArrayMesh.new()
		var far_mesh := ArrayMesh.new()
		for surface in instance.mesh.get_surface_count():
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var original_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			stats.source_triangles += original_indices.size()/3
			var importer := ImporterMesh.new()
			importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
			importer.generate_lods(25,60,[])
			var selected := original_indices
			var distant := original_indices
			# Proportional per-surface budgets preserve both bark and leaf surfaces.
			var budget: int = maxi(300,int(original_indices.size()*.024))
			for lod in importer.get_surface_lod_count(0):
				var indices := importer.get_surface_lod_indices(0,lod)
				if indices.size() < selected.size():
					selected = indices
				if indices.size() <= budget:
					break
			budget = maxi(120,int(original_indices.size()*.006))
			for lod in importer.get_surface_lod_count(0):
				var indices := importer.get_surface_lod_indices(0,lod)
				if indices.size() < distant.size():
					distant = indices
				if indices.size() <= budget:
					break
			stats.near_triangles += selected.size()/3
			stats.far_triangles += distant.size()/3
			for pair in [[near_mesh,selected],[far_mesh,distant]]:
				pair[0].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,compact(arrays,pair[1]))
				var material: Material = instance.mesh.surface_get_material(surface)
				if material:
					material = material.duplicate()
				pair[0].surface_set_material(surface,material)
		for pair in [[near,near_mesh],[far,far_mesh]]:
			var visual := MeshInstance3D.new()
			visual.mesh = pair[1]
			visual.transform = instance.transform
			pair[0].add_child(visual)
			visual.owner = pair[0]
			visual.name = instance.name
	for pair in [[near,"tree_small_02_near"],[far,"tree_small_02_far"]]:
		var packed := PackedScene.new()
		assert(packed.pack(pair[0]) == OK)
		assert(ResourceSaver.save(packed,OUTPUT+pair[1]+".scn") == OK)
	assert(stats.near_triangles <= 60000,"Tree exceeds runtime budget")
	var file := FileAccess.open(OUTPUT+"tree_lod_manifest.json",FileAccess.WRITE)
	stats["source"] = Art.MODELS+"vegetation/tree_small_02/source.json"
	stats["method"] = "Godot ImporterMesh.generate_lods; compact referenced vertices; source transforms retained; CC0"
	file.store_string(JSON.stringify(stats,"\t"))
	print(stats)
	source.free()
	near.free()
	far.free()
	quit()
