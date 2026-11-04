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
	var courtyard_only := "--courtyard-cross-only" in OS.get_cmdline_user_args()
	var ring_only := "--courtyard-ring-only" in OS.get_cmdline_user_args()
	var paper_only := "--paper-reader-only" in OS.get_cmdline_user_args()
	var staff_only := "--staff-room-only" in OS.get_cmdline_user_args() or paper_only
	var storage_only := "--storage-only" in OS.get_cmdline_user_args()
	courtyard_only = courtyard_only or ring_only or staff_only or storage_only
	if courtyard_only:
		views = [["courtyard-cross",Vector3(18,17,15.05),Vector3(18,0,15)]]
		# Cutaway screenshot only: expose all four ground-floor openings.
		var geometry := level.get_node("NavigationRegion3D/Geometry")
		geometry.get_node("Floor2Rooms").hide()
		for slab in geometry.get_node("Floors").get_children():
			if str(slab.name).begins_with("Upper"):
				slab.hide()
		for railing in geometry.get_node("Courtyard").get_children():
			if str(railing.name).begins_with("UpperRail"):
				railing.hide()
		for cover in geometry.get_node("Cover").get_children():
			if cover.position.y > 4.5:
				cover.hide()
		for sign in geometry.get_node("Signs").get_children():
			if sign.position.y > 4.5:
				sign.hide()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 24
	if staff_only:
		views = [["staff-overview",Vector3(31.5,13,12.05),Vector3(31.5,0.6,12)],
			["staff-inside",Vector3(30,1.65,11.5),Vector3(34.1,1,12)],
			["staff-awake",Vector3(30,1.65,11.5),Vector3(34.1,1,12)]]
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		level.get_node("Guard_G3/Presentation")._process(0.016)
		for actor in get_nodes_in_group("guards"):
			if actor.name != &"Guard_G3":
				actor.hide()
		for item in level.get_node("Interactables").get_children():
			if item.name != &"Key":
				item.hide()
	if paper_only:
		views = [["paper-note",Vector3(30.6,1.6,11),Vector3(32.2,1.112,11)],
			["paper-calendar",Vector3(28.7,1.6,16),Vector3(27.3,1.5,16)]]
	if storage_only:
		views = [["storage-keypad",Vector3(25.5,1.6,21),Vector3(27,1.4,21)],
			["storage-overview",Vector3(31.5,12,21.05),Vector3(31.5,0,21)],
			["storage-inside",Vector3(28.2,1.7,21),Vector3(35.4,1.4,20.6)]]
		for actor in get_nodes_in_group("guards"):
			actor.hide()
		for item in level.get_node("Interactables").get_children():
			if item.name != &"Rope":
				item.hide()
	for shot in views:
		if storage_only:
			var flow := level.get_node("GameFlow")
			if flow.state == GameStateMachine.State.PAUSED:
				flow.resume()
			var door := level.get_node("NavigationRegion3D/Doors/Storage")
			level.get_node("Player").position = Vector3(25.5,0,21)
			if shot[0] == "storage-keypad":
				door.interact(level.get_node("Player"))
			else:
				door.keypad.close_panel()
				if not door.unlocked:
					door.submit_code("1403",level.get_node("Player"))
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL if shot[0] == "storage-overview" else Camera3D.PROJECTION_PERSPECTIVE
			camera.size = 13
		if paper_only:
			var flow := level.get_node("GameFlow")
			if flow.state == GameStateMachine.State.PAUSED:
				flow.resume()
			var reader := level.get_node("StaffReader")
			reader.show()
			var document := "CodeNote" if shot[0] == "paper-note" else "MaintenanceBoard"
			level.get_node("NavigationRegion3D/Geometry/StaffInterior/"+document).interact(level.get_node("Player"))
		if staff_only and shot[0] == "staff-awake":
			level.get_node("Guard_G3").hear_noise(Vector3(32,0,14),0.9)
			level.get_node("Guard_G3")._update_cone()
			level.get_node("Guard_G3/Presentation")._process(0.016)
		if frame_only and shot[0] == "t1-empty":
			if not level.get_node("Interactables/Painting_T1").interact(level.get_node("Player")):
				push_error("Could not collect T1 for screenshot")
				quit(1)
				return
		camera.position = shot[1]
		if staff_only:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL if shot[0] == "staff-overview" else Camera3D.PROJECTION_PERSPECTIVE
			camera.size = 16
		camera.look_at(shot[2])
		camera.fov = 40 if shot[0] == "overview" else 75
		for frame in 5:
			await process_frame
		if storage_only:
			level.get_node("NavigationRegion3D/Doors/Storage").keypad._fit()
			await process_frame
		await RenderingServer.frame_post_draw
		var output := "res://maps/museum/docs/step-06-%s.png" % shot[0]
		if entrance_only:
			output = "res://maps/museum/docs/concept-v2/exterior-start-godot.png"
		if frame_only:
			output = "res://maps/museum/docs/step-07-%s.png" % shot[0]
		if courtyard_only:
			output = "res://maps/museum/docs/step-10-courtyard-cross.png"
		if ring_only:
			output = "res://maps/museum/docs/step-11-courtyard-ring.png"
		if staff_only:
			output = "res://maps/museum/docs/step-14-ah-%s.png" % shot[0]
		if paper_only:
			output = "res://maps/museum/docs/step-15-%s.png" % shot[0]
		if storage_only:
			output = "res://maps/museum/docs/step-16-%s.png" % shot[0]
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
