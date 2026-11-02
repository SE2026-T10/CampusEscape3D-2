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
		["start", Vector3(18,1.7,35), Vector3(18,1.7,30)],
	]
	var entrance_only := "--entrance-only" in OS.get_cmdline_user_args()
	if entrance_only:
		views = [["start", Vector3(18,1.7,35), Vector3(18,1.7,30)]]
	var frame_only := "--frame-only" in OS.get_cmdline_user_args()
	if frame_only:
		views = [
			["t1-intact",Vector3(2.15,6.1,12),Vector3(0.23,6,12)],
			["t1-empty",Vector3(2.15,6.1,12),Vector3(0.23,6,12)],
		]
	for shot in views:
		if frame_only and shot[0] == "t1-empty":
			if not level.get_node("Interactables/Painting_T1").interact(level.get_node("Player")):
				push_error("Could not collect T1 for screenshot")
				quit(1)
				return
		camera.position = shot[1]
		camera.look_at(shot[2])
		camera.fov = 40 if shot[0] == "overview" else 75
		for frame in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		var output := "res://maps/museum/docs/step-06-%s.png" % shot[0]
		if entrance_only:
			output = "res://maps/museum/docs/concept-v2/exterior-start-godot.png"
		if frame_only:
			output = "res://maps/museum/docs/step-07-%s.png" % shot[0]
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
