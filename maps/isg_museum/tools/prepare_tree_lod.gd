extends SceneTree

## Offline Godot meshoptimizer reduction. Only reduced meshes enter gameplay.
const Art := preload("res://maps/isg_museum/tools/environment_art_builder.gd")
const OUTPUT := "res://maps/isg_museum/assets/models/derived/"

func _initialize() -> void:
	run.call_deferred()

static func lod_profiles(layout: Dictionary) -> Array:
	var result: Array = layout.quality.tree_lods.duplicate(true)
	result[0].budget = int(layout.quality.tree_near_triangle_budget)
	return result

static func leaf_grid_resolution(budget: int, views: int) -> int:
	return maxi(1,int(sqrt(float(budget)/(views*2))))

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

func _bounds(vertices: PackedVector3Array) -> AABB:
	var result := AABB(vertices[0],Vector3.ZERO)
	for vertex in vertices:
		result = result.expand(vertex)
	return result

func _cells(vertices: PackedVector3Array, indices: PackedInt32Array, bounds: AABB, grid: Vector3i) -> Dictionary:
	var cells := {}
	for triangle in indices.size()/3:
		var center := (vertices[indices[triangle*3]]+vertices[indices[triangle*3+1]]+vertices[indices[triangle*3+2]])/3
		var unit := (center-bounds.position)/bounds.size
		var key := Vector3i(clampi(int(unit.x*grid.x),0,grid.x-1),clampi(int(unit.y*grid.y),0,grid.y-1),clampi(int(unit.z*grid.z),0,grid.z-1))
		if not cells.has(key):
			cells[key] = []
		for corner in 3:
			cells[key].append(indices[triangle*3+corner])
	for key in cells:
		cells[key] = PackedInt32Array(cells[key])
	return cells

func _coverage(vertices: PackedVector3Array, indices: PackedInt32Array, bounds: AABB) -> Dictionary:
	var occupied := {}
	# Vertex occupancy is sampled deterministically; no faces are discarded here.
	var stride := maxi(1,indices.size()/1200)
	for i in range(0,indices.size(),stride):
		var unit := (vertices[indices[i]]-bounds.position)/bounds.size
		occupied[Vector3i(int(unit.x*5),int(unit.y*5),int(unit.z*5))] = true
	return occupied

func _candidates(arrays: Array, indices: PackedInt32Array) -> Array:
	var local := compact(arrays,indices)
	var lookup: Array[int] = []
	var seen := {}
	for index in indices:
		if not seen.has(index):
			seen[index] = true
			lookup.append(index)
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,local)
	importer.generate_lods(25,60,[])
	var result: Array = [indices]
	for lod in importer.get_surface_lod_count(0):
		var mapped := PackedInt32Array()
		for index in importer.get_surface_lod_indices(0,lod):
			mapped.append(lookup[index])
		result.append(mapped)
	return result

func _choose(candidates: Array, arrays: Array, budget: int, coverage_weight: float) -> Dictionary:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var local_bounds := _bounds(compact(arrays,candidates[0])[Mesh.ARRAY_VERTEX])
	# Avoid division by zero on thin leaves.
	local_bounds.size = local_bounds.size.max(Vector3(.001,.001,.001))
	var original := _coverage(vertices,candidates[0],local_bounds)
	var best := INF
	var chosen: PackedInt32Array = candidates[-1]
	var cover := 0.0
	for indices: PackedInt32Array in candidates:
		var triangles := indices.size()/3
		if triangles > maxi(budget*2,60):
			continue
		var occupied := _coverage(vertices,indices,local_bounds)
		var kept := 0
		for cell in original:
			kept += int(occupied.has(cell))
		var coverage := float(kept)/maxi(1,original.size())
		var score := absf(log(maxf(1,triangles)/maxi(1,budget)))+coverage_weight*(1-coverage)
		if score < best:
			best = score
			chosen = indices
			cover = coverage
	return {"indices":chosen,"coverage":cover}

func _leaf_cards(budget: int) -> Dictionary:
	var atlas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"tree_leaf_clusters.json"))
	var divisions := leaf_grid_resolution(budget,atlas.views.size())
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for view in atlas.views:
		var center := Vector3(view.center[0],view.center[1],view.center[2])
		var right := Vector3(view.right[0],view.right[1],view.right[2])
		var up := Vector3(view.up[0],view.up[1],view.up[2])
		var normal := Vector3(view.normal[0],view.normal[1],view.normal[2])
		var tile := Vector2(int(view.tile)%16,int(view.tile)/16)
		for y in divisions:
			for x in divisions:
				for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
					var uv := Vector2(x+corner.x,y+corner.y)/divisions
					# Curved cards retain cluster volume/parallax; tessellation is reduced
					# across LODs while the source atlas, cluster centers and bounds agree.
					var depth: float = view.depth*.04
					var bend := depth*sin(uv.x*PI)*sin(uv.y*PI)
					var n: Vector3 = (normal-right*(depth*PI*cos(uv.x*PI)*sin(uv.y*PI)/view.size)
						-up*(depth*PI*sin(uv.x*PI)*cos(uv.y*PI)/view.size)).normalized()
					surface.set_normal(n)
					surface.set_uv((tile+Vector2(uv.x,1-uv.y))/Vector2(16,8))
					surface.add_vertex(center+right*(uv.x-.5)*view.size+up*(uv.y-.5)*view.size+normal*bend)
	var material := StandardMaterial3D.new()
	material.resource_name = "tree_source_leaf_clusters"
	material.albedo_texture = load(OUTPUT+"tree_leaf_clusters.png")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = .4
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = .88
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var mesh := surface.commit()
	return {"arrays":mesh.surface_get_arrays(0),"material":material,"divisions":divisions,
		"triangles":atlas.views.size()*divisions*divisions*2,"clusters":atlas.views.size()/3}

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var art := Art.new()
	var layout := art.load_layout()
	var levels := lod_profiles(layout)
	var source := art.extract_visual_parts("vegetation/tree_small_02/tree_small_02_2k.gltf",[],false)
	var reference := art.compute_visual_bounds(source)
	var stats := {"source_triangles":0,"levels":[],"reference_bounds":{"position":[reference.position.x,reference.position.y,reference.position.z],
		"size":[reference.size.x,reference.size.y,reference.size.z]},"normalization":"shared source bounds; uniform height/canopy constrained scale; base-center anchor",
		"method":"Native nearest-budget wood LODs plus source-baked curved leaf cluster cards; no random face deletion; shared atlas/anchor across all levels",
		"config":Art.LAYOUT,"leaf_cluster_grid":layout.quality.leaf_cluster_grid,"source":Art.MODELS+"vegetation/tree_small_02/source.json"}
	var roots: Array[Node3D] = []
	var meshes: Array[ArrayMesh] = []
	for level in levels:
		roots.append(Node3D.new())
		meshes.append(ArrayMesh.new())
		stats.levels.append({"id":level.id,"requested_budget":level.budget,"actual_triangles":0,"parts":{},"begin":level.begin,"end":level.end})
	for instance in source.get_children():
		for surface in instance.mesh.get_surface_count():
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var original: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var material: Material = instance.mesh.surface_get_material(surface)
			var is_leaf := material.resource_name.contains("leaves")
			var trunk := material.resource_name.contains("trunk")
			stats.source_triangles += original.size()/3
			if is_leaf:
				for i in levels.size():
					var cards := _leaf_cards(int(levels[i].budget*levels[i].foliage_fraction))
					meshes[i].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,cards.arrays)
					meshes[i].surface_set_material(surface,cards.material)
					stats.levels[i].actual_triangles += cards.triangles
					stats.levels[i].parts[material.resource_name] = {"triangles":cards.triangles,
						"clusters":cards.clusters,"curved_card_divisions":cards.divisions,"atlas":"tree_leaf_clusters.png"}
				continue
			var grid := Vector3i(1,1,1)
			if is_leaf:
				var g: Array = layout.quality.leaf_cluster_grid
				grid = Vector3i(g[0],g[1],g[2])
			var cells := _cells(arrays[Mesh.ARRAY_VERTEX],original,_bounds(arrays[Mesh.ARRAY_VERTEX]),grid)
			var selected: Array[PackedInt32Array] = []
			var coverages: Array[float] = []
			for level in levels:
				selected.append(PackedInt32Array())
				coverages.append(0.0)
			for cell in cells:
				var candidates := _candidates(arrays,cells[cell])
				for i in levels.size():
					var fraction: float = levels[i].foliage_fraction if is_leaf else (1.0-levels[i].foliage_fraction)*(.3 if trunk else .7)
					var budget := maxi(30,int(levels[i].budget*fraction*float(cells[cell].size())/original.size()))
					var chosen := _choose(candidates,arrays,budget,levels[i].coverage_weight if is_leaf else .15)
					var assembled: PackedInt32Array = selected[i]
					assembled.append_array(chosen.indices)
					selected[i] = assembled
					coverages[i] += chosen.coverage/cells.size()
			for i in levels.size():
				meshes[i].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,compact(arrays,selected[i]))
				meshes[i].surface_set_material(surface,material)
				var triangles := selected[i].size()/3
				stats.levels[i].actual_triangles += triangles
				stats.levels[i].parts[material.resource_name] = {"triangles":triangles,"clusters":cells.size(),"mean_occupancy_retained":coverages[i]}
		for i in levels.size():
			var visual := MeshInstance3D.new()
			visual.mesh = meshes[i]
			visual.transform = instance.transform
			roots[i].add_child(visual)
			visual.name = instance.name
			visual.owner = roots[i]
	for i in levels.size():
		roots[i].set_meta("reference_bounds",reference)
		roots[i].set_meta("requested_budget",levels[i].budget)
		var packed := PackedScene.new()
		assert(packed.pack(roots[i]) == OK)
		assert(ResourceSaver.save(packed,OUTPUT+"tree_small_02_"+levels[i].id+".scn") == OK)
		roots[i].free()
	var file := FileAccess.open(OUTPUT+"tree_lod_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(stats,"\t"))
	print(JSON.stringify(stats))
	source.free()
	quit()
