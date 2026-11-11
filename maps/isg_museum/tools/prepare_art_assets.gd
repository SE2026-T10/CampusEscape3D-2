extends "res://maps/isg_museum/tools/prepare_tree_lod.gd"

## Additional repeated props reduced offline; originals and attribution stay intact.
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var manifest := {}
	for entry in [
		["vegetation/shrub_04/shrub_04_2k.gltf","shrub_04",1800],
		["vegetation/potted_plant_01/potted_plant_01_2k.gltf","potted_plant_01",10000],
		["exhibits/terpsichore_lyran/terpsichore_lyran_by_canova.glb","terpsichore",28000]]:
		var art := Art.new()
		var source := art.extract_visual_parts(entry[0],[],false)
		var output := Node3D.new()
		var total := 0
		for instance in source.get_children():
			for i in instance.mesh.get_surface_count():
				total += instance.mesh.surface_get_array_index_len(i)/3
		var count := 0
		for instance in source.get_children():
			var mesh := ArrayMesh.new()
			for surface in instance.mesh.get_surface_count():
				var arrays: Array = instance.mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var budget: int = maxi(60,int(float(indices.size())/3/total*entry[2]))
				var importer := ImporterMesh.new()
				importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
				importer.generate_lods(25,60,[])
				var selected := indices
				for lod in importer.get_surface_lod_count(0):
					var candidate := importer.get_surface_lod_indices(0,lod)
					if absi(candidate.size()/3-budget) < absi(selected.size()/3-budget):
						selected = candidate
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,compact(arrays,selected))
				mesh.surface_set_material(surface,instance.mesh.surface_get_material(surface))
				count += selected.size()/3
			var visual := MeshInstance3D.new()
			visual.name = instance.name
			visual.mesh = mesh
			visual.transform = instance.transform
			output.add_child(visual)
			visual.owner = output
		var packed := PackedScene.new()
		assert(packed.pack(output) == OK)
		assert(ResourceSaver.save(packed,OUTPUT+entry[1]+".scn") == OK)
		manifest[entry[0]] = {"source_triangles":total,"derived_triangles":count,"derived":OUTPUT+entry[1]+".scn"}
		source.free()
		output.free()
	var file := FileAccess.open(OUTPUT+"prop_lod_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	print(manifest)
	quit()
