extends SceneTree

const BASELINE := "res://maps/isg_museum/docs/reports/visual-feedback-2026-11-15/snapshots/before-source/"
const ReportPaths := preload("res://maps/isg_museum/tools/report_paths.gd")
const OUT := "res://maps/isg_museum/docs/reports/visual-feedback-2026-11-15/"
const VIEWS := [
	["yard",Vector3(18,1.65,36),Vector3(18,1.5,30)],
	["yard-west",Vector3(12,1.65,36.5),Vector3(7,0,34)],
	["yard-east",Vector3(24,1.65,36.5),Vector3(29,0,34)],
	["north",Vector3(18,1.65,12),Vector3(18,3.4,9)],
	["south",Vector3(18,1.65,18),Vector3(18,3.4,21)],
	["west",Vector3(15,1.65,15),Vector3(12,3.4,15)],
	["east",Vector3(21,1.65,15),Vector3(24,3.4,15)],
	["upper-north",Vector3(18,6.15,12),Vector3(18,7.8,9)],
	["upper-south",Vector3(18,6.15,18),Vector3(18,7.8,21)],
	["upper-west",Vector3(15,6.15,15),Vector3(12,7.8,15)],
	["upper-east",Vector3(21,6.15,15),Vector3(24,7.8,15)],
	["joint",Vector3(16,2.5,10.6),Vector3(14.5,3.1,9)],
	["corner",Vector3(14.8,1.65,12.5),Vector3(12,3.1,9)],
	["hedge",Vector3(16,1.65,10.5),Vector3(16.7,1.1,9)],
	["stair-a-lower",Vector3(7.4,1.65,28.25),Vector3(2,2.8,28.25)],
	["stair-a-upper",Vector3(1.2,3.9,25.75),Vector3(7,4.7,25.75)],
	["stair-b-lower",Vector3(28.6,1.65,4.25),Vector3(34,2.8,4.25)],
	["stair-b-upper",Vector3(34.8,3.9,1.75),Vector3(29,4.7,1.75)],
	["room-a",Vector3(2,6.15,16),Vector3(.2,5.1,12)],
	["room-b",Vector3(34,6.15,16),Vector3(35.8,5.1,12)],
	["room-c",Vector3(18,6.15,2),Vector3(14,5.1,.2)]]

var output_dir := OUT

func out_path(filename: String) -> String:
	return ReportPaths.artifact(output_dir,filename)

func _initialize() -> void:
	output_dir = ReportPaths.output_root(OUT)
	run.call_deferred()

func run() -> void:
	var before := "--before" in OS.get_cmdline_user_args()
	var scene := BASELINE+"museum_editing.tscn" if before else "res://maps/isg_museum/scenes/museum_editing.tscn"
	var level := load(scene).instantiate() as Node3D
	root.size = Vector2i(1280,720)
	root.add_child(level)
	current_scene = level
	await process_frame
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for node in get_nodes_in_group("debug_visuals"):
		if node is Node3D:
			node.hide()
	for child in level.get_children():
		if child is CanvasLayer:
			child.hide()
	var player := level.get_node("Player") as FirstPersonPlayer
	player.camera.current = true
	var movie := "--movie" in OS.get_cmdline_user_args()
	if movie:
		level.process_mode = Node.PROCESS_MODE_INHERIT
		var flow := level.get_node("GameFlow") as GameFlow
		if flow.state == GameStateMachine.State.PAUSED:
			flow.resume()
		for room in [[Vector3(2,4.5,14),Vector3(2,4.5,18),Vector3(.17,5.1,16)],
			[Vector3(34,4.5,14),Vector3(34,4.5,17),Vector3(35.83,5.1,15)],
			[Vector3(14,4.5,2),Vector3(18,4.5,2),Vector3(16,5.1,.17)],
			[Vector3(12.8,0,7.9),Vector3(16,0,7.9),Vector3(14.5,1.1,9)]]:
			player.position = room[0]
			player.velocity = Vector3.ZERO
			await walk_camera(player,room[1],room[2])
		for mirror in [false,true]:
			var points := [Vector3(7.4,0,28.25),Vector3(1.2,2.25,28.25),Vector3(1.2,2.25,25.75),Vector3(7.4,4.5,25.75)]
			if mirror:
				for i in points.size():
					points[i] = Vector3(36-points[i].x,points[i].y,points[i].z-24)
			player.position = points[0]
			player.velocity = Vector3.ZERO
			for destination in points.slice(1):
				await walk_camera(player,destination,destination+Vector3.UP*1.4)
			points.reverse()
			for destination in points.slice(1):
				await walk_camera(player,destination,destination+Vector3.UP*1.4)
		level.free()
		quit()
		return
	for view in VIEWS:
		player.position = view[1]-Vector3.UP*player.stand_eye_height
		player.head.position.y = player.stand_eye_height
		player.camera.look_at(view[2])
		for frame in (45 if movie else 8):
			if movie:
				player.position.x += .004
				player.camera.rotate_y(.001)
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_path(("before-" if before else "after-")+view[0]+".png"))
		print("Player camera captured: ",view[0])
	level.free()
	quit()

func walk_camera(player: FirstPersonPlayer, target: Vector3, look: Vector3) -> void:
	for tick in 300:
		var direction := target-player.position
		direction.y = 0
		if direction.length() < .16:
			break
		player.rotation.y = atan2(-direction.x,-direction.z)
		player.camera.look_at(look)
		Input.action_press("move_forward")
		await physics_frame
	Input.action_release("move_forward")
	for i in 25:
		player.camera.rotate_y(.004)
		await physics_frame
	print("Actual input camera walk: ",player.position," target ",target)
	if Vector2(player.position.x-target.x,player.position.z-target.z).length() > .25:
		push_error("Capture walk blocked before target")
		quit(1)
