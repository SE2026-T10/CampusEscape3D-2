extends SceneTree
## Staged visual review only. Does not claim a full walking playthrough.
const M := preload("res://maps/intelligence/scripts/mission_controller.gd")
const C := preload("res://maps/intelligence/resources/layout/k17_sabotage.gd")
var output := "res://maps/intelligence/docs/sabotage-v5"
func _init() -> void: _run.call_deferred()
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output=arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size=Vector2i(1280,720)
	for route in [&"maintenance",&"courtyard"]:
		change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17_test.tscn")
		await _frames(40)
		var player := current_scene.get_node("Player") as FirstPersonPlayer
		player.set_physics_process(false)
		player.global_position=C.STAND
		player.camera.look_at(C.TARGET+Vector3(0,1.2,0))
		if route==&"maintenance":
			var overview := Camera3D.new()
			current_scene.add_child(overview)
			overview.position=Vector3(35.4,1.7,14.5)
			overview.look_at(C.TARGET+Vector3(0,1.18,0))
			overview.make_current()
			await _frames(4)
			await _shot("target-overview")
			overview.queue_free()
			player.camera.make_current()
			await _frames(2)
			await _shot("target-locked")
		for id in [M.ENTER,M.PASS,M.CODE,M.ARCHIVE,M.VAULT,M.FILE]: ObjectiveManager.find(current_scene).complete(id)
		current_scene.get_node("Gameplay/Sabotage").plant()
		await _frames(10)
		if route==&"maintenance": await _shot("target-armed")
		var mission := current_scene.get_node("Gameplay/Mission") as K17MissionController
		mission.try_extract(route,"Góc thử mỹ thuật")
		await _frames(88)
		await _shot("finale-"+str(route))
		await _frames(180)
		await _shot("result-"+str(route))
		if route==&"maintenance":
			for path in ["GameMenus","ObjectiveHud","StealthHud"]: current_scene.get_node(path).hide()
			await _frames(3)
			await _shot("target-damaged")
		current_scene.queue_free()
		await _frames(40)
	await preload("res://tests/test_utils.gd").settle_async_audio(self)
	print("K17 V5 VISUAL PREVIEW: staged target/finale/results captured")
	quit()
func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output.path_join(name+".png")))
func _frames(count: int) -> void:
	for i in count:
		if is_instance_valid(current_scene):
			var flow := GameFlow.find(current_scene)
			if flow and flow.state==GameStateMachine.State.PAUSED: flow.resume()
		await physics_frame
