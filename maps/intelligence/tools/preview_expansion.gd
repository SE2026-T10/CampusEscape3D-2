extends SceneTree
## Staged viewpoints for art review, not evidence of completing the mission.
var output:="res://ci-logs/k17-v3-preview"
func _init() -> void: _run.call_deferred()
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output=arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17_test.tscn")
	await _frames(30)
	root.size=Vector2i(1280,720)
	var player:=current_scene.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	var camera:=Camera3D.new()
	camera.fov=75
	current_scene.add_child(camera)
	camera.make_current()
	for hud in ["ObjectiveHud","StealthHud"]: current_scene.get_node(hud).visible=false
	for id in [K17MissionController.ENTER,K17MissionController.PASS,K17MissionController.CODE,K17MissionController.ARCHIVE]: ObjectiveManager.find(current_scene).complete(id)
	current_scene.get_node("Gameplay/VaultDoor").open()
	var views:=[
		["01_compound",Vector3(-43,28,52),Vector3(0,0,0)],
		["02_motor_pool",Vector3(-36,1.6,43),Vector3(-36,1.6,28)],
		["03_guard_post",Vector3(-36,1.6,12),Vector3(-36,1.3,2)],
		["04_main_stairs",Vector3(4,1.6,-22),Vector3(4,-2.8,-40)],
		["05_vault",Vector3(8,-2.4,-48),Vector3(0,-2.7,-40)],
		["06_utilities",Vector3(36,1.6,21),Vector3(36,1.6,4)],
		["07_service_stairs",Vector3(30,-2.4,-36),Vector3(30,1,-24)],
	]
	for v in views:
		camera.position=v[1]
		camera.look_at(v[2])
		await _frames(20)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output.path_join(v[0]+".png")))
		print("K17 V3 VIEW ",v[0])
	current_scene.queue_free()
	await _frames(40)
	await preload("res://tests/test_utils.gd").settle_async_audio(self)
	quit()
func _frames(count: int) -> void:
	for i in count: await process_frame
