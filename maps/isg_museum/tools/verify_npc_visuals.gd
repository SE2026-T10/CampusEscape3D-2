extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--snapshot" in args:
		var index := args.find("--snapshot")
		if index+1>=args.size():
			quit(1)
			return
		var data := []
		for path in ["contract_teammate","service_expansion"]:
			var scene: Node = load("res://maps/isg_museum/scenes/"+path+".tscn").instantiate()
			_snapshot(scene,scene,path,data)
			scene.free()
		data.sort_custom(func(a,b): return a.path<b.path)
		var file := FileAccess.open("res://maps/isg_museum/docs/npc-art-v1/authoring-"+args[index+1].validate_filename()+".json",FileAccess.WRITE)
		file.store_string(JSON.stringify(data,"\t")+"\n")
		file.close()
		quit()
		return
	var host := Node.new()
	root.add_child(host)
	var failures: Array[String] = await preload("res://maps/isg_museum/tests/npc_visual_tests.gd").new().run(host)
	host.free()
	quit(0 if failures.is_empty() else 1)

func _snapshot(node: Node, scene: Node, prefix: String, data: Array) -> void:
	var record := {"path":prefix+"/"+String(scene.get_path_to(node)),"type":node.get_class()}
	if node is Node3D: record.transform = str(node.transform)
	if node.get_script(): record.script = node.get_script().resource_path
	if node is CollisionObject3D: record.layers = [node.collision_layer,node.collision_mask]
	if node is CollisionShape3D:
		record.shape = node.shape.get_class()
		if node.shape is BoxShape3D: record.size = str(node.shape.size)
	if node is MeshInstance3D:
		record.visible = node.visible
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		for surface in node.mesh.get_surface_count(): digest.update(var_to_bytes(node.mesh.surface_get_arrays(surface)))
		record.mesh = digest.finish().hex_encode()
		record.skin = node.skin.get_bind_count() if node.skin else 0
	data.append(record)
	for child in node.get_children(): _snapshot(child,scene,prefix,data)
