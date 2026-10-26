@tool
extends EditorScript
## Run from the script editor (Ctrl+Shift+X), in Godot 4.7 with Mobile/Forward+.
## Writes the environment's lightmap, saves that scene, leaves the editor open.

func _run() -> void:
	if RenderingServer.get_rendering_device() == null:
		push_error("K17 bake needs an editor started with --rendering-method mobile (the project stays Compatibility).")
		return
	await _frames(100)
	EditorInterface.open_scene_from_path("res://maps/intelligence/scenes/environment/k17_environment.tscn")
	await _frames(70)
	var scene := EditorInterface.get_edited_scene_root()
	if scene == null:
		push_error("K17 BAKE: no scene")
		return
	var lightmap := scene.get_node("LightmapGI") as LightmapGI
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(lightmap)
	EditorInterface.edit_node(lightmap)
	await _frames(40)
	print("K17 BAKE: editor scene ready")
	var button: Button
	for node in _all_nodes(EditorInterface.get_base_control().get_tree().root):
		if node is Button and "Bake Lightmaps" in node.text:
			button = node
		if "Lightmap" in node.get_class():
			print("K17 EDITOR NODE ",node.get_class()," ",node.has_method("_bake"))
	if button == null:
		push_error("K17 BAKE: toolbar not found")
		return
	print("K17 BAKE: pressing toolbar")
	button.pressed.emit()
	await _frames(10)
	for node in _all_nodes(EditorInterface.get_base_control().get_tree().root):
		if node is EditorFileDialog and node.visible:
			print("K17 BAKE: selecting lightmap resource")
			node.file_selected.emit("res://maps/intelligence/resources/k17_lightmap.lmbake")
			node.hide()
	await _frames(40)
	print("K17 BAKE DATA ",lightmap.light_data)
	if lightmap.light_data:
		EditorInterface.save_scene()
		print("K17 BAKE SAVED")
		return
	else:
		push_error("K17 BAKE: empty result")
		return

func _all_nodes(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child in node.get_children(): result.append_array(_all_nodes(child))
	return result

func _frames(count: int) -> void:
	for i in count: await EditorInterface.get_base_control().get_tree().process_frame
