extends RefCounted
## Inspect unmerged collision geometry at actor height; roofs and bake cuts are excluded.
const Data := preload("res://maps/intelligence/resources/layout/minimap_layout.gd")
const OUTPUT := "res://maps/intelligence/resources/k17_minimap_layout.tres"

func save(region: Node3D) -> bool:
	var data := build(region)
	if data.ground.get("floors",[]).is_empty() or data.basement.get("floors",[]).is_empty() or data.stairs.size()!=2:
		push_error("K17 minimap: incomplete authoring geometry")
		return false
	var ok := ResourceSaver.save(data,OUTPUT)==OK
	if not ok: push_error("K17 minimap: resource save failed")
	# Authoring tags are consumed before packing; runtime needs only the resource.
	for node in region.find_children("*","Node3D",true,false):
		for tag in ["minimap_room","minimap_stair"]:
			if node.has_meta(tag): node.remove_meta(tag)
	return ok

func build(region: Node3D) -> Data:
	var data := Data.new()
	data.ground={"floors":[],"rooms":[],"walls":[],"obstacles":[]}
	data.basement={"floors":[],"rooms":[],"walls":[],"obstacles":[]}
	for node in region.find_children("*","Node3D",true,false):
		if node.has_meta("minimap_stair"):
			data.stairs.append(node.get_meta("minimap_stair"))
		if node.has_meta("minimap_room"):
			var mesh: MeshInstance3D = node if node is MeshInstance3D else node.get_node("Mesh")
			var bounds := _relative(mesh,region)*mesh.get_aabb()
			var entry: Dictionary = data.basement if bounds.get_center().y< -2 else data.ground
			entry.rooms.append(_footprint(bounds))
	for node in region.find_children("*","CollisionShape3D",true,false):
		var collider := node as CollisionShape3D
		var body := collider.get_parent()
		if not collider.shape is BoxShape3D or body.has_meta("bake_cut") or str(body.name).begins_with("NavigationGateCut"):
			continue
		var size_: Vector3 = (collider.shape as BoxShape3D).size
		var bounds := _relative(collider,region)*AABB(-size_/2,size_)
		var footprint := _footprint(bounds)
		for floor_id in 2:
			var height := -4.0 if floor_id==1 else 0.0
			var entry: Dictionary = data.basement if floor_id==1 else data.ground
			if bounds.size.y<=.5 and absf(bounds.end.y-height)<.08 and footprint.get_area()>2:
				entry.floors.append(footprint)
			elif bounds.position.y<height+.9 and bounds.end.y>height+.9 and footprint.get_area()>.3:
				var kind := "walls" if minf(footprint.size.x,footprint.size.y)<=.6 and maxf(footprint.size.x,footprint.size.y)>2 else "obstacles"
				entry[kind].append(footprint)
	data.ground_bounds=_union(data.ground.floors)
	var underground: Array = data.basement.floors.duplicate()
	underground.append_array(data.stairs)
	data.basement_bounds=_union(underground).grow(2)
	return data

func _relative(node: Node3D,region: Node3D) -> Transform3D:
	var pose := node.transform
	var parent := node.get_parent()
	while parent!=region:
		if parent is Node3D: pose=(parent as Node3D).transform*pose
		parent=parent.get_parent()
	return pose

func _footprint(bounds: AABB) -> Rect2:
	return Rect2(bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z)

func _union(rectangles: Array) -> Rect2:
	if rectangles.is_empty(): return Rect2()
	var result: Rect2 = rectangles[0]
	for rectangle in rectangles: result=result.merge(rectangle)
	return result
