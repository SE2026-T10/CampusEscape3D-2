@tool
extends EditorScript
## Invoke from the Godot editor with Mobile/Forward+; Compatibility uses the bake.
func _run() -> void:
	if RenderingServer.get_rendering_device()==null:
		push_error("V6 BAKE: start the editor with --rendering-method mobile")
		return
	await _frames(60)
	EditorInterface.open_scene_from_path("res://maps/intelligence/scenes/intelligence_k17.tscn")
	await _frames(50)
	var scene := EditorInterface.get_edited_scene_root()
	var lightmap := scene.get_node("LightmapGI") as LightmapGI
	lightmap.light_data=null
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(lightmap)
	EditorInterface.edit_node(lightmap)
	await _frames(40)
	var button: Button
	for node in _all(EditorInterface.get_base_control().get_tree().root):
		if node is Button and "Bake Lightmaps" in node.text: button=node
	if button==null:
		push_error("V6 BAKE: editor bake action unavailable")
		return
	print("K17 V6 BAKE START")
	button.pressed.emit()
	await _frames(10)
	for node in _all(EditorInterface.get_base_control().get_tree().root):
		if node is EditorFileDialog and node.visible:
			node.file_selected.emit("res://maps/intelligence/resources/k17_v6_lightmap.lmbake")
			node.hide()
	await _frames(60)
	if lightmap.light_data==null:
		push_error("V6 BAKE: no baked data")
		return
	EditorInterface.save_scene()
	print("K17 V6 BAKE SAVED ",lightmap.light_data.resource_path)

func _frames(count: int) -> void:
	for i in count: await EditorInterface.get_base_control().get_tree().process_frame

func _all(node: Node) -> Array[Node]:
	var result: Array[Node]=[node]
	for child in node.get_children(): result.append_array(_all(child))
	return result
