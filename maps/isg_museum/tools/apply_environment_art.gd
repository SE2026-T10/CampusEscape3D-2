extends SceneTree

## Default writes; --check compares semantic trees and never writes resources.
const Art := preload("res://maps/isg_museum/tools/environment_art_builder.gd")
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
		var before := signature(scene)
		if SCENES[id] == "apply_painting":
			builder.apply_painting(scene)
		else:
			builder.call(SCENES[id],scene,layout)
		if check_only:
			if before != signature(scene):
				push_error("Saved environment differs: "+id)
				if "--diagnose" in OS.get_cmdline_user_args():
					var after := signature(scene).split("\n")
					for row in before.split("\n"):
						if not row in after:
							print("Changed: ",row.left(600))
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

static func resource_key(resource: Resource) -> String:
	if resource == null:
		return "null"
	var result := resource.get_class()
	if resource is Mesh:
		result += str(resource.get_aabb())
		for i in resource.get_surface_count():
			var arrays: Array = resource.surface_get_arrays(i)
			result += str(arrays[Mesh.ARRAY_VERTEX].size())+":"+str(hash(arrays))
			result += resource_key(resource.surface_get_material(i))
	elif resource is BaseMaterial3D:
		result += str(resource.albedo_color)+str(resource.roughness)+str(resource.metallic)
		result += str(resource.transparency)+str(resource.shading_mode)
		if resource.albedo_texture:
			result += resource.albedo_texture.resource_path
		result += str(resource.normal_enabled)
		if resource.normal_enabled and resource.normal_texture:
			result += resource.normal_texture.resource_path
	elif resource is Environment:
		result += str(resource.background_mode)+str(resource.background_color)+str(resource.ambient_light_energy)
		result += resource_key(resource.sky)
	elif resource is Sky:
		result += resource_key(resource.sky_material)
	elif resource is ProceduralSkyMaterial:
		result += str(resource.sky_top_color)+str(resource.sky_horizon_color)+str(resource.ground_horizon_color)
	elif resource is BoxShape3D:
		result += str(resource.size)
	elif resource is CylinderShape3D:
		result += str(resource.radius)+str(resource.height)
	else:
		result += resource.resource_path
	return result

static func signature(root_node: Node) -> String:
	var rows: Array[String] = []
	_signature(root_node,root_node,rows)
	rows.sort()
	return "\n".join(rows)

static func _signature(root_node: Node, node: Node, rows: Array[String]) -> void:
	var row := str(root_node.get_path_to(node))+":"+node.get_class()
	if node is Node3D:
		row += str(node.transform)+str(node.visible)
	if node is MeshInstance3D:
		row += resource_key(node.mesh)+resource_key(node.material_override)
	if node is MultiMeshInstance3D:
		row += resource_key(node.multimesh.mesh)+str(node.multimesh.instance_count)+resource_key(node.material_override)
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
	if node is WorldEnvironment:
		row += resource_key(node.environment)
	for key in ["environment_art","preserve_source_material","source"]:
		row += str(node.get_meta(key)) if node.has_meta(key) else "<none>"
	rows.append(row)
	for child in node.get_children():
		_signature(root_node,child,rows)
