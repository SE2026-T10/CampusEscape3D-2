extends SceneTree

## Default writes; --check compares semantic trees and never writes resources.
const Art := preload("res://maps/isg_museum/tools/environment_art_builder.gd")
# Godot stores mesh normals and tangents in a quantized form. A reimport can
# shift their decoded values slightly; positions, indices and UVs must still match.
const MESH_DIRECTION_TOLERANCE := 0.00025
const SCENES := {"museum_geometry":"apply_to_geometry", "exhibits_expansion":"apply_to_exhibits",
	"service_expansion":"apply_to_service", "painting_t1":"apply_painting",
	"painting_t2":"apply_painting", "painting_demo":"apply_painting",
	"museum_door":"apply_to_door", "entrance_door":"apply_to_door", "museum":"apply_to_main"}

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var builder := Art.new()
	var layout := builder.load_layout()
	var check_only := "--check" in OS.get_cmdline_user_args()
	var failures := 0
	for id in SCENES:
		var path: String = Art.BASE+"scenes/"+id+".tscn"
		var scene := (load(path) as PackedScene).instantiate()
		var before := rebuild_snapshot(scene) if check_only else {}
		if SCENES[id] == "apply_painting":
			builder.apply_painting(scene)
		else:
			builder.call(SCENES[id],scene,layout)
		if check_only:
			if not rebuild_matches(before,scene,"--diagnose" in OS.get_cmdline_user_args()):
				push_error("Saved environment differs: "+id)
				failures += 1
		else:
			var packed := PackedScene.new()
			var error := packed.pack(scene)
			if error == OK:
				error = ResourceSaver.save(packed,path)
			if error != OK:
				failures += 1
		print("Environment art ","checked: " if check_only else "saved: ",id)
		scene.free()
	if not check_only:
		builder.write_manifest()
	if "--diagnose" in OS.get_cmdline_user_args():
		Node.print_orphan_nodes()
	quit(0 if failures == 0 else 1)

static func resource_key(resource: Resource, directions: Variant = null) -> String:
	if resource == null:
		return "null"
	var result := resource.get_class()
	if resource is Mesh:
		result += str(resource.get_aabb())
		for i in resource.get_surface_count():
			var arrays: Array = resource.surface_get_arrays(i)
			if directions != null:
				directions.append([arrays[Mesh.ARRAY_NORMAL],arrays[Mesh.ARRAY_TANGENT]])
				arrays[Mesh.ARRAY_NORMAL] = null
				arrays[Mesh.ARRAY_TANGENT] = null
			result += str(arrays[Mesh.ARRAY_VERTEX].size())+":"+str(hash(arrays))
			result += resource_key(resource.surface_get_material(i))
	elif resource is BaseMaterial3D:
		result += str(resource.albedo_color)+str(resource.roughness)+str(resource.metallic)
		result += str(resource.transparency)+str(resource.shading_mode)
		if resource.albedo_texture:
			result += resource.albedo_texture.resource_path
		result += str(resource.normal_enabled)
		result += str(resource.normal_scale)+str(resource.uv1_scale)+str(resource.uv1_world_triplanar)
		if resource.roughness_texture:
			result += resource.roughness_texture.resource_path
		if resource.normal_enabled and resource.normal_texture:
			result += resource.normal_texture.resource_path
	elif resource is Environment:
		result += str(resource.background_mode)+str(resource.background_color)+str(resource.ambient_light_energy)+str(resource.ambient_light_color)
		result += resource_key(resource.sky)
	elif resource is Sky:
		result += resource_key(resource.sky_material)
	elif resource is ProceduralSkyMaterial:
		result += str(resource.sky_top_color)+str(resource.sky_horizon_color)+str(resource.ground_horizon_color)
	elif resource is BoxShape3D:
		result += str(resource.size)
	elif resource is CylinderShape3D:
		result += str(resource.radius)+str(resource.height)
	elif resource is ConcavePolygonShape3D:
		result += str(hash(resource.get_faces()))+str(resource.backface_collision)
	else:
		result += resource.resource_path
	return result

static func signature(root_node: Node, directions_by_path: Variant = null) -> String:
	var rows: Array[String] = []
	_signature(root_node,root_node,rows,directions_by_path)
	rows.sort()
	return "\n".join(rows)

static func rebuild_snapshot(root_node: Node) -> Dictionary:
	var directions := {}
	return {"structure":signature(root_node,directions),"directions":directions}

static func rebuild_matches(before: Dictionary, root_node: Node, diagnose: bool = false) -> bool:
	var after := rebuild_snapshot(root_node)
	if before.structure != after.structure:
		if diagnose:
			diagnose_signatures(before.structure,after.structure)
		return false
	for path in before.directions:
		var saved_surfaces: Array = before.directions[path]
		var rebuilt_surfaces: Array = after.directions.get(path,[])
		if saved_surfaces.size() != rebuilt_surfaces.size():
			return false
		for index in saved_surfaces.size():
			if not _directions_match(saved_surfaces[index],rebuilt_surfaces[index]):
				if diagnose:
					print("Rebuild normals or tangents differ at ",path," surface ",index)
				return false
	return true

static func _directions_match(before: Array, after: Array) -> bool:
	if before == after:
		return true
	var normals: PackedVector3Array = before[0] if before[0] != null else PackedVector3Array()
	var rebuilt_normals: PackedVector3Array = after[0] if after[0] != null else PackedVector3Array()
	var tangents: PackedFloat32Array = before[1] if before[1] != null else PackedFloat32Array()
	var rebuilt_tangents: PackedFloat32Array = after[1] if after[1] != null else PackedFloat32Array()
	if normals.size() != rebuilt_normals.size() or tangents.size() != rebuilt_tangents.size():
		return false
	for index in normals.size():
		if normals[index].distance_squared_to(rebuilt_normals[index]) > MESH_DIRECTION_TOLERANCE * MESH_DIRECTION_TOLERANCE:
			return false
	for index in range(0,tangents.size(),4):
		var saved := Vector3(tangents[index],tangents[index+1],tangents[index+2])
		var rebuilt := Vector3(rebuilt_tangents[index],rebuilt_tangents[index+1],rebuilt_tangents[index+2])
		if saved.distance_squared_to(rebuilt) > MESH_DIRECTION_TOLERANCE * MESH_DIRECTION_TOLERANCE:
			return false
		if tangents[index+3] != rebuilt_tangents[index+3]:
			return false
	return true

static func diagnose_signatures(before: String, after: String) -> void:
	var original := {}
	var rebuilt := {}
	for row in before.split("\n"):
		original[row.get_slice(":",0)] = row
	for row in after.split("\n"):
		rebuilt[row.get_slice(":",0)] = row
	var paths := original.keys()
	for path in rebuilt:
		if not original.has(path):
			paths.append(path)
	paths.sort()
	for path in paths:
		var old_row: String = original.get(path,"<missing>")
		var new_row: String = rebuilt.get(path,"<missing>")
		if old_row == new_row:
			continue
		print("Rebuild difference at ",path)
		print("  Before: ",old_row.left(1200))
		print("  After:  ",new_row.left(1200))

static func _signature(root_node: Node, node: Node, rows: Array[String], directions_by_path: Variant) -> void:
	var path := str(root_node.get_path_to(node))
	var row := path+":"+node.get_class()
	var directions: Variant = null if directions_by_path == null else []
	if node is Node3D:
		row += str(node.transform)+str(node.visible)
	if node is MeshInstance3D:
		row += resource_key(node.mesh,directions)+resource_key(node.material_override)
	if node is MultiMeshInstance3D:
		row += resource_key(node.multimesh.mesh,directions)+str(node.multimesh.instance_count)+resource_key(node.material_override)
		for i in node.multimesh.instance_count:
			row += str(node.multimesh.get_instance_transform(i))
	if node is CollisionShape3D:
		row += resource_key(node.shape)+str(node.disabled)
	if node is CollisionObject3D:
		row += str(node.collision_layer)+str(node.collision_mask)
	if node is GeometryInstance3D:
		row += str(node.visibility_range_begin)+str(node.visibility_range_end)
	if node is Light3D:
		row += str(node.light_color)+str(node.light_energy)+str(node.shadow_enabled)
	if node is OmniLight3D:
		row += str(node.omni_range)
	if node is WorldEnvironment:
		row += resource_key(node.environment)
	for key in ["environment_art","preserve_source_material","source","fit_scale","fit_anchor","fit_reference_bounds","tree_lod",
			"material_role","material_roles","arch_spandrel","arch_spandrel_collision","floor_shell","floor_partition_hidden","outer_profile","top_y"]:
		row += str(node.get_meta(key)) if node.has_meta(key) else "<none>"
	rows.append(row)
	if directions != null and not directions.is_empty():
		directions_by_path[path] = directions
	for child in node.get_children():
		_signature(root_node,child,rows,directions_by_path)
