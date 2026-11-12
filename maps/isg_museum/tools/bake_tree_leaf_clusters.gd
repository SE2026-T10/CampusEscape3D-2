extends "res://maps/isg_museum/tools/prepare_tree_lod.gd"

## Render-only offline atlas baker. Source LOD0 is used here, never in gameplay.
## Run with GL Compatibility, not --headless, then import before prepare_tree_lod.
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Leaf atlas requires a rendering viewport; run with --rendering-method gl_compatibility")
		quit(1)
		return
	var art := Art.new()
	var config := art.load_layout()
	var source := art.extract_visual_parts("vegetation/tree_small_02/tree_small_02_2k.gltf",[],false)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128,128)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var visual := MeshInstance3D.new()
	world.add_child(visual)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	var atlas := Image.create(2048,1024,false,Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var records: Array = []
	var tile := 0
	for node in source.get_children():
		for surface in node.mesh.get_surface_count():
			var original: Material = node.mesh.surface_get_material(surface)
			if not original.resource_name.contains("leaves"):
				continue
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var grid: Array = config.quality.leaf_cluster_grid
			var cells := _cells(arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_INDEX],_bounds(arrays[Mesh.ARRAY_VERTEX]),Vector3i(grid[0],grid[1],grid[2]))
			var material := original.duplicate() as BaseMaterial3D
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			for cell in cells:
				var local := compact(arrays,cells[cell])
				var mesh := ArrayMesh.new()
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,local)
				visual.mesh = mesh
				visual.material_override = material
				var bounds := _bounds(local[Mesh.ARRAY_VERTEX])
				var center := bounds.get_center()
				for direction in [Vector3.BACK,Vector3.RIGHT,Vector3.UP]:
					camera.position = center+direction*8
					camera.look_at(center,Vector3.FORWARD if direction == Vector3.UP else Vector3.UP)
					var right := camera.basis.x
					var up := camera.basis.y
					var size := maxf(bounds.size.dot(right.abs()),bounds.size.dot(up.abs()))*1.06
					camera.size = maxf(.03,size)
					for frame in 2:
						await process_frame
					await RenderingServer.frame_post_draw
					var pixels := viewport.get_texture().get_image()
					if not pixels.get_used_rect().has_area():
						push_error("Empty leaf bake tile "+str(tile))
						quit(1)
						return
					atlas.blit_rect(pixels,Rect2i(0,0,128,128),Vector2i(tile%16*128,tile/16*128))
					records.append({"center":[center.x,center.y,center.z],"right":[right.x,right.y,right.z],
						"up":[up.x,up.y,up.z],"normal":[direction.x,direction.y,direction.z],"size":size,
						"depth":bounds.size.dot(direction.abs()),"tile":tile,"cluster":str(cell)})
					tile += 1
	assert(atlas.save_png(OUTPUT+"tree_leaf_clusters.png") == OK)
	var file := FileAccess.open(OUTPUT+"tree_leaf_clusters.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"tile_size":128,"atlas_size":[2048,1024],"views":records,
		"source":"vegetation/tree_small_02/tree_small_02_2k.gltf","license":"CC0",
		"method":"39 spatial clusters; three orthographic unlit source albedo views each; transparent background; no AI imagery"},"\t"))
	print("Baked leaf atlas: ",tile," source views")
	source.free()
	viewport.free()
	quit()
