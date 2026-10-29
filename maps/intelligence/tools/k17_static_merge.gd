extends RefCounted
## Merge authored opaque box surfaces by small spatial cells and material.
## Colliders stay in their original bodies. UV2 is unwrapped for a fresh bake.
func merge(host: Node3D) -> Vector2i:
	var found: Array[MeshInstance3D]=[]
	_collect(host,found)
	var groups: Dictionary={}
	for mesh in found:
		var transform:=_relative(mesh,host)
		var cell:=Vector3i(floori(transform.origin.x/12),floori(transform.origin.y/5),floori(transform.origin.z/12))
		var material:=mesh.get_active_material(0)
		var key: String=str(cell)+":"+str(material.get_instance_id())+":"+str(mesh.layers)+":"+str(mesh.cast_shadow)
		if not groups.has(key): groups[key]=[]
		groups[key].append([mesh,transform])
	var merged:=0
	var batches:=0
	for key in groups:
		var entries: Array=groups[key]
		if entries.size()<3: continue
		var tool:=SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for item in entries: tool.append_from(item[0].mesh,0,item[1])
		var mesh: ArrayMesh=tool.commit()
		var result:=mesh.lightmap_unwrap(Transform3D.IDENTITY,.35)
		if result!=OK:
			push_error("K17 static merge UV2 failed: "+str(result))
			continue
		var batch:=MeshInstance3D.new()
		batch.name="StaticBatch%d"%batches
		batch.mesh=mesh
		batch.material_override=entries[0][0].get_active_material(0)
		batch.layers=entries[0][0].layers
		batch.cast_shadow=entries[0][0].cast_shadow
		batch.gi_mode=GeometryInstance3D.GI_MODE_STATIC
		host.add_child(batch,true)
		batch.owner=host
		for item in entries: item[0].free()
		merged+=entries.size()
		batches+=1
	host.set_meta("static_merge",Vector2i(merged,batches))
	print("K17 STATIC MERGE ",host.name," ",merged," boxes -> ",batches," batches")
	return Vector2i(merged,batches)

func _collect(node: Node,found: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child.scene_file_path!="": continue
		if child is MeshInstance3D and child.name!="Roof" and child.visible and child.gi_mode==GeometryInstance3D.GI_MODE_STATIC and child.mesh is BoxMesh:
			var material: Material=child.get_active_material(0)
			if material is StandardMaterial3D and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED:
				found.append(child)
		_collect(child,found)

func _relative(node: Node3D,host: Node3D) -> Transform3D:
	var result:=node.transform
	var parent:=node.get_parent()
	while parent!=host:
		if parent is Node3D: result=parent.transform*result
		parent=parent.get_parent()
	return result
