extends SceneTree
## Staged viewpoints for art review, not evidence of completing the mission.
var output:="res://ci-logs/k17-v4-preview"
var selected_views: PackedStringArray=[]
func _init() -> void: _run.call_deferred()
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output=arg.trim_prefix("--out=")
		if arg.begins_with("--views="): selected_views=arg.trim_prefix("--views=").split(",")
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
	PlayerInventory.find(current_scene).add(ItemCatalog.STAFF_CARD)
	for id in [K17MissionController.ENTER,K17MissionController.PASS,K17MissionController.CODE,K17MissionController.ARCHIVE]: ObjectiveManager.find(current_scene).complete(id)
	current_scene.get_node("Gameplay/VaultKeypad").set_entry(preload("res://maps/intelligence/resources/layout/k17_v4.gd").VAULT_CODE)
	current_scene.get_node("Gameplay/VaultKeypad").submit()
	var views:=[
		["01_compound",Vector3(-43,28,52),Vector3(0,0,0)],
		["02_motor_pool",Vector3(-36,1.6,43),Vector3(-36,1.6,28)],
		["03_guard_post",Vector3(-36,1.6,12),Vector3(-36,1.3,2)],
		["04_main_stairs",Vector3(4,1.6,-22),Vector3(4,-2.8,-40)],
		["05_vault",Vector3(8,-2.4,-48),Vector3(0,-2.7,-40)],
		["06_utilities",Vector3(36,1.6,21),Vector3(36,1.6,4)],
		["07_service_stairs",Vector3(30,-2.4,-36),Vector3(30,1,-24)],
		["08_power_console",Vector3(40.7,1.65,2.4),Vector3(43,1.6,3.2)],
		["09_keypad",Vector3(5.35,1.65,-21.7),Vector3(5.35,1.55,-23.45)],
		["10_command_south",Vector3(9,1.6,1.5),Vector3(0,1.4,3)],
		["11_radio",Vector3(.3,1.6,13.2),Vector3(6,1.6,10.5)],
		["12_old_guard_room",Vector3(-5.5,1.6,12),Vector3(-13,1.3,2)],
		["13_records_west",Vector3(-15,1.6,-20),Vector3(-4,1.4,-9)],
		["14_records_east",Vector3(10.7,1.6,-2),Vector3(3,1.5,-17)],
		["15_utility_control",Vector3(36,1.6,1.5),Vector3(42,1.4,5)],
		["16_utility_generator",Vector3(36,1.6,8),Vector3(42,1.4,11)],
		["17_utility_workshop",Vector3(35,1.6,16),Vector3(40,1.4,13)],
		["18_service_north",Vector3(35,1.6,-18),Vector3(42,1.6,-10)],
		["19_service_south",Vector3(36,1.6,42),Vector3(26,1.6,28)],
		["20_camera_command",Vector3(6,1.6,12.8),Vector3(3,2.8,10)],
		["21_camera_records",Vector3(10.7,1.6,-18),Vector3(10.8,2.8,-12)],
		["22_camera_service",Vector3(32,1.6,32),Vector3(27,3,28)],
		["23_response_post",Vector3(-18,1.6,36),Vector3(-18,1.3,41)],
		["24_records_annex",Vector3(16.5,1.6,-5),Vector3(17,1.3,-16)],
		["25_planning_table",Vector3(-14,1.6,12.7),Vector3(-17.2,.9,10.5)],
		["26_cover_motor_pool",Vector3(-38,1.3,24.8),Vector3(-41,.7,24.9)],
		["27_cover_guard_post",Vector3(-43,1.2,-3.5),Vector3(-43,.7,-6.3)],
		["28_cover_radio",Vector3(-2.5,1.2,13),Vector3(0,.7,13)],
		["29_cover_utilities",Vector3(42,1.3,3),Vector3(41.2,.7,5)],
		["30_cover_records",Vector3(10.5,1.2,-20),Vector3(8,.7,-20)],
		["31_cover_vault",Vector3(-5,-2.8,-48.6),Vector3(-7.5,-3.2,-47.2)],
		["32_cover_service",Vector3(26,1.4,40),Vector3(25.8,.8,37.3)],
		["33_pipe_main",Vector3(-17.8,1.6,12),Vector3(-19.55,2.7,-4)],
		["34_valve_west",Vector3(-17.6,1.6,9),Vector3(-19.55,1.7,10)],
		["35_valve_east",Vector3(17.2,1.6,9),Vector3(19.55,1.7,10)],
		["36_return_conduit",Vector3(12,-2.4,-37),Vector3(27,-1.15,-41.78)],
		["37_guard_sign_mount",Vector3(-36,1.6,18),Vector3(-36,2.6,14.1)],
		["38_extraction_sign",Vector3(-36,1.6,50),Vector3(-36,2.5,53.2)],
		["39_service_panel_bank",Vector3(40.7,1.6,2.1),Vector3(43,1.6,3.3)],
		["40_vault_sign_mount",Vector3(8,-2.4,-45),Vector3(8,-1.7,-41)],
		["41_wiring_board",Vector3(33,1.6,1),Vector3(30.5,1.8,.235)],
		["42_rack_notice_rail",Vector3(-16,1.6,-11),Vector3(-18.8,1.92,-12)],
	]
	for v in views:
		if not selected_views.is_empty() and v[0] not in selected_views: continue
		camera.position=v[1]
		camera.look_at(v[2])
		await _frames(20)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output.path_join(v[0]+".png")))
		print("K17 V4 VIEW ",v[0])
	current_scene.queue_free()
	await _frames(40)
	await preload("res://tests/test_utils.gd").settle_async_audio(self)
	quit()
func _frames(count: int) -> void:
	for i in count:
		if is_instance_valid(current_scene):
			var flow:=GameFlow.find(current_scene)
			if flow and flow.state==GameStateMachine.State.PAUSED: flow.resume()
		await process_frame
