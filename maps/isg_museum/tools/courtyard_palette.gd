extends RefCounted

## Offline role registry. Primitive authoring meshes remain intact in production.
const CONFIG := "res://maps/isg_museum/resources/courtyard_palette.json"
var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
var materials := {}
var bindings: Array[Dictionary] = []
var proposed := false
var prepared_root: Node3D

func material_for_role(role: StringName) -> Material:
	if not config.roles.has(String(role)): return null
	if not materials.has(role): materials[role] = load(config.roles[String(role)].material)
	return materials[role]

func apply_palette(root: Node3D, _palette: Dictionary = {}) -> void:
	if not is_instance_valid(prepared_root): prepare(root)
	set_proposed(true)

func prepare(root: Node3D) -> void:
	if prepared_root==root: return
	prepared_root = root
	bindings.clear()
	if config.stage=="B_production":
		# Saved product is already coloured; preview must not partition it again.
		for role in config.roles: material_for_role(role)
		proposed = true
		return
	var geometry := root.get_node("NavigationRegion3D/Geometry") as Node3D
	for group_name in ["Floor1Rooms","Floor2Rooms"]:
		for body in geometry.get_node(group_name).get_children():
			var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
			if mesh and mesh.mesh is BoxMesh: _split_faces(mesh,"walls")
	_split_faces(geometry.get_node("Floors/Ground/Mesh"),"floor")
	for mesh in geometry.get_node("EnvironmentArt/InteriorFinishes").get_children():
		if mesh is MeshInstance3D and mesh.mesh is PlaneMesh and String(mesh.name).begins_with("Marble"):
			_split_faces(mesh,"floor")
	var art := geometry.get_node("EnvironmentArt")
	for mesh: MeshInstance3D in art.get_node("Arcade").find_children("*","MeshInstance3D",true,false):
		_stone(mesh,"architectural_stone")
	for mesh: MeshInstance3D in art.get_node("Balustrades").find_children("*","MeshInstance3D",true,false):
		var bounds: AABB = mesh.global_transform*mesh.get_aabb()
		var cap := String(mesh.get_parent().name).begins_with("Bar") and bounds.get_center().y>5.4
		_stone(mesh,"balustrade_cap" if cap else "balustrade_stone")
	for body in geometry.get_node("Courtyard").get_children():
		var name := String(body.name)
		if name.begins_with("Ground"): _stone(body.get_node("Mesh"),"garden_wall_stone")
		elif name.begins_with("Planter"): _stone(body.get_node("Mesh"),"architectural_stone")
	for child in art.get_children():
		var id := String(child.name)
		if id.begins_with("PedestalCap") or id.begins_with("Statue") or id=="FountainBasin":
			for mesh: MeshInstance3D in child.find_children("*","MeshInstance3D",true,false):
				_stone(mesh,"sculpture_stone" if id.begins_with("Statue") or id=="FountainBasin" else "architectural_stone")
		if id=="Roof" or id.begins_with("Lantern"):
			for mesh: MeshInstance3D in child.find_children("*","MeshInstance3D",true,false):
				var mat := mesh.material_override as StandardMaterial3D
				if mat and mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and not mat.emission_enabled and mat.metallic>.2:
					_bind(mesh,"dark_metal")
	for door in root.get_node("NavigationRegion3D/Doors").get_children():
		if not door is Node3D: continue
		var p: Vector3 = door.global_position
		if p.x<8.9 or p.x>27.1 or p.z<5.9 or p.z>24.1: continue
		var panel := door.get_node_or_null("Panel")
		if not panel: continue
		for mesh: MeshInstance3D in panel.find_children("*","MeshInstance3D",true,false):
			var mat := mesh.get_active_material(0) as StandardMaterial3D
			if mat: _bind(mesh,"dark_metal" if mat.metallic>.3 else "walnut_wood")
	set_proposed(false)

func _stone(mesh: MeshInstance3D, role: String) -> void:
	if not visible_in_hierarchy(mesh,prepared_root): return
	# Only replace the existing lit stone adaptation, never an imported source
	# material. Foliage/glass/artwork/characters are outside this exact allowlist.
	var current := mesh.material_override
	if not is_adapted_stone(current): return
	_bind(mesh,role)

func is_adapted_stone(material: Material) -> bool:
	return material!=null and (material.resource_path.get_file() in ["courtyard_stone_cream.tres","courtyard_statue_stone.tres"] or String(material.get_meta("material_role","")) in ["architectural_stone","balustrade_stone","balustrade_cap","garden_wall_stone","sculpture_stone"])

static func relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var parent: Node = node
	while parent!=root:
		assert(parent!=null,"Palette anchor must be an ancestor")
		if parent is Node3D: result = parent.transform*result
		parent = parent.get_parent()
	return result

static func visible_in_hierarchy(node: Node3D, stop: Node) -> bool:
	var parent: Node = node
	while parent!=null:
		if parent is Node3D and not parent.visible: return false
		if parent==stop: break
		parent = parent.get_parent()
	return true

func assign_architecture_roles(geometry: Node3D) -> void:
	if config.stage!="B_production": return
	var art := geometry.get_node_or_null("EnvironmentArt")
	if art==null: return
	for section in ["Arcade","Balustrades"]:
		for mesh: MeshInstance3D in art.get_node(section).find_children("*","MeshInstance3D",true,false):
			if mesh.get_meta("arch_spandrel",false) or mesh.get_meta("material_role","")=="courtyard_plaster":
				set_role(mesh,"courtyard_plaster")
				continue
			if not is_adapted_stone(mesh.material_override): continue
			var role := "architectural_stone"
			if section=="Balustrades":
				var bounds: AABB = relative_transform(geometry,mesh)*mesh.get_aabb()
				role = "balustrade_cap" if String(mesh.get_parent().name).begins_with("Bar") and bounds.get_center().y>5.4 else "balustrade_stone"
				# Retain the pre-batch role on subsequent passes over the baked batch.
				if mesh.get_meta("art_batch",false): role = mesh.get_meta("material_role",role)
			set_role(mesh,role)
	for body in geometry.get_node("Courtyard").get_children():
		var id := String(body.name)
		if id.begins_with("Ground"): set_role(body.get_node("Mesh"),"garden_wall_stone")
		elif id.begins_with("Planter"): set_role(body.get_node("Mesh"),"architectural_stone")
	for child in art.get_children():
		var id := String(child.name)
		if id.begins_with("PedestalCap") or id.begins_with("Statue") or id=="FountainBasin":
			for mesh: MeshInstance3D in child.find_children("*","MeshInstance3D",true,false):
				if is_adapted_stone(mesh.material_override): set_role(mesh,"sculpture_stone" if id.begins_with("Statue") or id=="FountainBasin" else "architectural_stone")
		if id=="Roof" or id.begins_with("Lantern"):
			for mesh: MeshInstance3D in child.find_children("*","MeshInstance3D",true,false):
				var mat := mesh.material_override as StandardMaterial3D
				if mat and mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and not mat.emission_enabled and mat.metallic>.2: set_role(mesh,"dark_metal")

func set_role(mesh: MeshInstance3D, role: String) -> void:
	mesh.material_override = material_for_role(role)
	mesh.set_meta("material_role",role)

func apply_geometry_palette(geometry: Node3D, data: Dictionary = {}) -> void:
	if not data.is_empty(): config = data
	if config.stage!="B_production": return
	# Replace exactly the owned finish layer; never replace primitive wall/floor data.
	var old := geometry.get_node_or_null("GardnerPalette")
	if old:
		assert(old.get_meta("gardner_palette",false),"Unowned palette layer")
		old.free()
	var layer := Node3D.new()
	layer.name = "GardnerPalette"
	layer.set_meta("gardner_palette",true)
	layer.set_meta("preserve_source_material",true)
	geometry.add_child(layer)
	layer.owner = geometry
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	for group_name in ["Floor1Rooms","Floor2Rooms"]:
		for body in geometry.get_node(group_name).get_children():
			var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
			if mesh==null or not mesh.mesh is BoxMesh: continue
			var bounds: AABB = relative_transform(geometry,mesh)*mesh.mesh.get_aabb()
			append_wall_faces(walls,bounds)
	_finish_mesh(layer,"Walls",walls.commit(),["courtyard_plaster"])
	var thresholds := threshold_bounds(geometry)
	for floor_index in 2:
		var builders := {}
		var w: float = config.border_width
		var xs := [9.0,9+w,12-w,12.0,24.0,24+w,27-w,27.0]
		var zs := [6.0,6+w,9-w,9.0,21.0,21+w,24-w,24.0,24+w,30-w,30.0]
		for xi in xs.size()-1:
			for zi in zs.size()-1:
				var p := Vector2((xs[xi]+xs[xi+1])/2,(zs[zi]+zs[zi+1])/2)
				if p.x>12 and p.x<24 and p.y>9 and p.y<21: continue
				var in_lobby := p.y>24
				var outer := minf(minf(p.x-9,27-p.x),minf(p.y-(24 if in_lobby else 6),(30 if in_lobby else 24)-p.y))
				var inner := maxf(maxf(12-p.x,p.x-24),maxf(9-p.y,p.y-21))
				var role := "corridor_border" if outer<w+.001 or (not in_lobby and inner<w+.001) else "corridor_floor"
				var y: float = .004 if floor_index==0 else config.floor_finish.upper_y
				var polygon := []
				for corner in [Vector2(xs[xi],zs[zi]),Vector2(xs[xi+1],zs[zi]),Vector2(xs[xi+1],zs[zi+1]),Vector2(xs[xi],zs[zi+1])]:
					polygon.append({"p":Vector3(corner.x,y,corner.y),"n":Vector3.UP,"uv":corner})
				var parts := [polygon]
				if floor_index==1:
					for threshold in thresholds:
						var remaining := []
						for part in parts: remaining.append_array(_subtract_rect(part,threshold.bounds))
						parts = remaining
				for part in parts: _emit(builders,part,role,Transform3D.IDENTITY)
		if floor_index==1:
			for threshold in thresholds:
				var r: Rect2 = threshold.bounds
				var polygon := []
				for p in [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]:
					polygon.append({"p":Vector3(p.x,config.floor_finish.upper_y,p.y),"n":Vector3.UP,"uv":p})
				_emit(builders,polygon,config.floor_finish.threshold_role,Transform3D.IDENTITY)
		var result := ArrayMesh.new()
		var roles := []
		for role in builders:
			builders[role].generate_tangents()
			builders[role].commit(result)
			roles.append(role)
		_finish_mesh(layer,"Floor%d" % (floor_index+1),result,roles)
	var shells := Node3D.new()
	shells.name = "UpperFloorShells"
	layer.add_child(shells)
	shells.owner = geometry
	var regions := [Rect2(9,6,18,3),Rect2(9,21,18,9),Rect2(9,9,3,12),Rect2(24,9,3,12)]
	for threshold in thresholds: regions.append(threshold.bounds)
	for body in geometry.get_node("Floors").get_children():
		if String(body.name).begins_with("Upper"):
			_partition_upper_slab(geometry,body.get_node("Mesh"),shells,regions)
	# Lower-storey lintel/wall caps meet the same slab plane. Hide their contact
	# top faces wherever an actual upper slab already owns the visible surface.
	var caps := Node3D.new()
	caps.name = "LowerWallShells"
	layer.add_child(caps)
	caps.owner = geometry
	var slabs := []
	for body in geometry.get_node("Floors").get_children():
		if not String(body.name).begins_with("Upper"): continue
		var source := body.get_node("Mesh") as MeshInstance3D
		var bounds: AABB = relative_transform(geometry,source)*source.get_aabb()
		slabs.append(Rect2(bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z))
	for body in geometry.get_node("Floor1Rooms").get_children():
		var source := body.get_node_or_null("Mesh") as MeshInstance3D
		if source and source.mesh is BoxMesh:
			var bounds: AABB = relative_transform(geometry,source)*source.get_aabb()
			if absf(bounds.end.y-4.5)<.001: _partition_upper_slab(geometry,source,caps,slabs)
	assign_architecture_roles(geometry)

func threshold_bounds(geometry: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for body in geometry.get_node("Floor2Rooms").get_children():
		var id := String(body.name)
		if not (id.begins_with("WestPartition_Lintel") or id.begins_with("GalleryBPartition_Lintel") or id.begins_with("NorthPartition_Lintel")): continue
		var mesh := body.get_node("Mesh") as MeshInstance3D
		var bounds: AABB = relative_transform(geometry,mesh)*mesh.mesh.get_aabb()
		result.append({"id":id,"bounds":Rect2(bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z)})
	return result

func _subtract_rect(polygon: Array, rect: Rect2) -> Array:
	var outside := []
	var inside := polygon
	for edge in [[0,rect.position.x,true],[0,rect.end.x,false],[2,rect.position.y,true],[2,rect.end.y,false]]:
		var part := _clip(inside,edge[0],edge[1],not edge[2])
		if part.size()>=3: outside.append(part)
		inside = _clip(inside,edge[0],edge[1],edge[2])
	return outside

func _partition_upper_slab(geometry: Node3D, source: MeshInstance3D, parent: Node3D, regions: Array) -> void:
	assert(source.mesh is BoxMesh,"Retain primitive authoring bounds")
	var transform := relative_transform(geometry,source)
	var inverse := transform.affine_inverse()
	var builders := {}
	var changed := false
	for surface in source.mesh.get_surface_count():
		var arrays := source.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty(): indices = PackedInt32Array(range(vertices.size()))
		for index in range(0,indices.size(),3):
			var polygon := []
			for j in 3:
				var k := indices[index+j]
				polygon.append({"p":transform*vertices[k],"n":normals[k],"uv":uvs[k]})
			var parts := [polygon]
			if (transform.basis.inverse().transposed()*normals[indices[index]]).y>.9:
				for region in regions:
					var remaining := []
					for part in parts:
						var clipped := _clip(_clip(_clip(_clip(part,0,region.position.x,true),0,region.end.x,false),2,region.position.y,true),2,region.end.y,false)
						if clipped.size()>=3:
							for i in range(1,clipped.size()-1):
								changed = changed or (clipped[i].p-clipped[0].p).cross(clipped[i+1].p-clipped[0].p).length()>.000001
						remaining.append_array(_subtract_rect(part,region))
					parts = remaining
			for part in parts: _emit(builders,part,str(surface),inverse)
	if not changed:
		if source.get_meta("floor_partition_hidden",false): source.show()
		return
	var result := ArrayMesh.new()
	for key in builders:
		builders[key].generate_tangents()
		builders[key].commit(result)
		result.surface_set_material(result.get_surface_count()-1,source.get_active_material(int(key)))
	var visual := MeshInstance3D.new()
	visual.name = source.get_parent().name
	visual.transform = transform
	visual.mesh = result
	visual.set_meta("floor_shell",true)
	parent.add_child(visual)
	visual.owner = parent.owner
	source.hide()
	source.set_meta("floor_partition_hidden",true)

func append_wall_faces(tool: SurfaceTool, wall: AABB) -> void:
	var z0 := maxf(6.15,wall.position.z)
	var z1 := minf(23.85,wall.end.z)
	var x0 := maxf(9.15,wall.position.x)
	var x1 := minf(26.85,wall.end.x)
	var y := wall.get_center().y
	var offset := .004
	if z1>z0:
		if is_equal_approx(wall.end.x,9.15): _wall_quad(tool,Vector2(z1-z0,wall.size.y),Vector3(9.15+offset,y,(z0+z1)/2),PI/2)
		if is_equal_approx(wall.position.x,26.85): _wall_quad(tool,Vector2(z1-z0,wall.size.y),Vector3(26.85-offset,y,(z0+z1)/2),-PI/2)
	if x1>x0:
		if is_equal_approx(wall.end.z,6.15): _wall_quad(tool,Vector2(x1-x0,wall.size.y),Vector3((x0+x1)/2,y,6.15+offset),0)
		if is_equal_approx(wall.position.z,23.85): _wall_quad(tool,Vector2(x1-x0,wall.size.y),Vector3((x0+x1)/2,y,23.85-offset),PI)

func _wall_quad(tool: SurfaceTool, size: Vector2, at: Vector3, yaw: float) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	tool.append_from(quad,0,Transform3D(Basis(Vector3.UP,yaw),at))

func _finish_mesh(parent: Node3D, id: String, mesh: ArrayMesh, roles: Array) -> void:
	var visual := MeshInstance3D.new()
	visual.name = id
	visual.mesh = mesh
	for i in roles.size(): mesh.surface_set_material(i,material_for_role(roles[i]))
	visual.set_meta("material_roles",roles)
	parent.add_child(visual)
	visual.owner = parent.owner

func apply_door_palette(door: Node3D, data: Dictionary = {}) -> void:
	if not data.is_empty(): config = data
	if config.stage!="B_production": return
	var panel := door.get_node_or_null("Panel")
	if panel==null: return
	set_role(panel.get_node("MeshInstance3D"),"door_wood")
	for mesh: MeshInstance3D in panel.find_children("*","MeshInstance3D",true,false):
		var role: String = mesh.get_meta("material_role","")
		if role in ["door_wood","door_trim","door_brass"]: set_role(mesh,role)

func validate_palette(root: Node3D) -> Array[String]:
	var errors: Array[String] = []
	var geometry := root if root.name==&"Geometry" else root.get_node("NavigationRegion3D/Geometry") as Node3D
	if not geometry.has_node("GardnerPalette"): errors.append("Missing saved Gardner finish layer")
	for group_name in ["Floor1Rooms","Floor2Rooms"]:
		for body in geometry.get_node(group_name).get_children():
			var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
			if mesh and not mesh.mesh is BoxMesh: errors.append("Primitive authoring wall lost: "+String(body.name))
	return errors

func _bind(mesh: MeshInstance3D, role: String) -> void:
	bindings.append({"node":mesh,"mesh":mesh.mesh,"override":mesh.material_override,"role":role})
	mesh.set_meta("material_role",role)

func set_proposed(enabled: bool) -> void:
	for record in bindings:
		var node: MeshInstance3D = record.node
		if record.has("derived"):
			node.mesh = record.derived if enabled else record.mesh
			node.material_override = null if enabled else record.override
		else:
			node.material_override = material_for_role(record.role) if enabled else record.override
	proposed = enabled

func _split_faces(mesh: MeshInstance3D, mode: String) -> void:
	var builders := {}
	var changed := false
	var original := mesh.mesh
	var transform := relative_transform(prepared_root,mesh)
	var inverse := transform.affine_inverse()
	var normal_basis := transform.basis.inverse().transposed()
	for surface in original.get_surface_count():
		var original_role := "original:%d" % surface
		var arrays := original.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
		if indices.is_empty(): indices = PackedInt32Array(range(vertices.size()))
		for index in range(0,indices.size(),3):
			var polygon := []
			for j in 3:
				var k := indices[index+j]
				var fallback := -(vertices[indices[index+1]]-vertices[indices[index]]).cross(vertices[indices[index+2]]-vertices[indices[index]]).normalized()
				polygon.append({"p":transform*vertices[k],"n":normals[k] if not normals.is_empty() else fallback,"uv":uvs[k] if not uvs.is_empty() else Vector2.ZERO})
			var center: Vector3 = (polygon[0].p+polygon[1].p+polygon[2].p)/3
			var normal: Vector3 = (normal_basis*polygon[0].n).normalized()
			if mode=="walls":
				var axis := -1
				if (normal.z>.9 and absf(center.z-6.15)<.01) or (normal.z<-.9 and absf(center.z-23.85)<.01): axis = 0
				if (normal.x>.9 and absf(center.x-9.15)<.01) or (normal.x<-.9 and absf(center.x-26.85)<.01): axis = 2
				if axis>=0:
					var low := 9.0 if axis==0 else 6.0
					var high := 27.0 if axis==0 else 24.0
					for interval in [[-1000.0,low],[low,high],[high,1000.0]]:
						var part := _clip(_clip(polygon,axis,interval[0],true),axis,interval[1],false)
						var role := "courtyard_plaster" if interval[0]==low else original_role
						_emit(builders,part,role,inverse)
						changed = changed or (role!=original_role and part.size()>=3)
					continue
			elif normal.y>.9 and (absf(center.y)<.01 or absf(center.y-4.504)<.001):
				var w: float = config.border_width
				var xs := [-1000.0,9.0,9+w,12-w,12.0,24.0,24+w,27-w,27.0,1000.0]
				var zs := [-1000.0,6.0,6+w,9-w,9.0,21.0,21+w,24-w,24.0,1000.0]
				for xi in xs.size()-1:
					for zi in zs.size()-1:
						var part := _clip(_clip(_clip(_clip(polygon,0,xs[xi],true),0,xs[xi+1],false),2,zs[zi],true),2,zs[zi+1],false)
						if part.size()<3: continue
						var p := Vector2((xs[xi]+xs[xi+1])/2,(zs[zi]+zs[zi+1])/2)
						var role := original_role
						if p.x>9 and p.x<27 and p.y>6 and p.y<24 and not (p.x>12 and p.x<24 and p.y>9 and p.y<21):
							var outer := minf(minf(p.x-9,27-p.x),minf(p.y-6,24-p.y))
							var inner := maxf(maxf(12-p.x,p.x-24),maxf(9-p.y,p.y-21))
							role = "corridor_border" if outer<w+.001 or inner<w+.001 else "corridor_floor"
						_emit(builders,part,role,inverse)
						changed = changed or role!=original_role
				continue
			_emit(builders,polygon,original_role,inverse)
	if not changed: return
	var result := ArrayMesh.new()
	var roles := []
	for role in builders:
		var tool: SurfaceTool = builders[role]
		tool.generate_tangents()
		tool.commit(result)
		result.surface_set_material(result.get_surface_count()-1,mesh.get_active_material(int(role.trim_prefix("original:"))) if role.begins_with("original:") else material_for_role(role))
		roles.append("original" if role.begins_with("original:") else role)
	bindings.append({"node":mesh,"mesh":original,"derived":result,"override":mesh.material_override,"roles":roles})
	mesh.set_meta("preview_material_roles",roles)

func _clip(polygon: Array, axis: int, boundary: float, keep_above: bool) -> Array:
	var result := []
	if polygon.is_empty(): return result
	var previous: Dictionary = polygon[-1]
	var before: bool = previous.p[axis]>=boundary if keep_above else previous.p[axis]<=boundary
	for current: Dictionary in polygon:
		var inside: bool = current.p[axis]>=boundary if keep_above else current.p[axis]<=boundary
		if inside!=before:
			var t: float = (boundary-previous.p[axis])/(current.p[axis]-previous.p[axis])
			result.append({"p":previous.p.lerp(current.p,t),"n":previous.n.lerp(current.n,t).normalized(),"uv":previous.uv.lerp(current.uv,t)})
		if inside: result.append(current)
		previous = current
		before = inside
	return result

func _emit(builders: Dictionary, polygon: Array, role: String, inverse: Transform3D) -> void:
	if polygon.size()<3: return
	for i in range(1,polygon.size()-1):
		var a: Vector3 = polygon[i].p-polygon[0].p
		var b: Vector3 = polygon[i+1].p-polygon[0].p
		if a.cross(b).length()<.000001: continue
		if not builders.has(role):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			builders[role] = tool
		var tool: SurfaceTool = builders[role]
		for point in [polygon[0],polygon[i],polygon[i+1]]:
			tool.set_normal(point.n)
			tool.set_uv(point.uv)
			tool.add_vertex(inverse*point.p)
