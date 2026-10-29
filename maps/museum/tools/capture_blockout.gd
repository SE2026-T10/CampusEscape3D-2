extends SceneTree

## Run with a real renderer (not --headless), --write-movie is unnecessary.
## Saves actual Godot views to docs; no runtime dependency on these images.
func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var level := (load("res://maps/museum/scenes/museum.tscn") as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	level.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for node in get_nodes_in_group("debug_visuals"):
		if node is Node3D:
			node.visible = false
	for node in level.get_children():
		if node is CanvasLayer:
			node.hide()
	var camera := Camera3D.new()
	level.add_child(camera)
	camera.current = true
	var views := [
		["overview", Vector3(49,49,53), Vector3(18,2,15)],
		["courtyard", Vector3(10.5,6.1,22.5), Vector3(21,3.4,12)],
		["stair-a", Vector3(8,6.1,25.75), Vector3(1.2,2.8,26)],
		["start", Vector3(18,1.7,28.5), Vector3(18,1.7,20)],
	]
	for shot in views:
		camera.position = shot[1]
		camera.look_at(shot[2])
		camera.fov = 40 if shot[0] == "overview" else 75
		for frame in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		var output := "res://maps/museum/docs/step-06-%s.png" % shot[0]
		var result := root.get_texture().get_image().save_png(output)
		if result != OK:
			push_error("Could not save screenshot: " + output)
			quit(1)
			return
		print("Saved ", output)
	current_scene = null
	level.free()
	await process_frame
	quit(0)
