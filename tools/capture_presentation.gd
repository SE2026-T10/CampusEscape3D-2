extends SceneTree

## Renders Phase 12 presentation evidence:
##   guard_poses.png   the guard model in each animation (idle, walk, run, search),
##                     two moments of each, side by side on a small stage
##   ui_*.png          the HUD in the real level: playing, detection meter rising,
##                     investigating, chase, caught, paused, victory
##
##   godot --path . --resolution 1280x720 --script res://tools/capture_presentation.gd -- --out=docs/presentation
##
## Needs a display (or a virtual one such as Xvfb); headless runs can't render.

const GUARD := "res://scenes/npc/guard.tscn"
const LEVEL := "res://scenes/level/library_graybox.tscn"

var _out := "res://docs/presentation"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = "res://" + a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _guard_poses()
	if not "--poses-only" in OS.get_cmdline_user_args():
		await _ui_states()
	quit(0)


func _guard_poses() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.15, 0.14)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 8)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.45, 0.33, 0.24)
	plane.material = floor_mat
	floor_mesh.mesh = plane
	stage.add_child(floor_mesh)
	var source: Node3D = (load(GUARD) as PackedScene).instantiate()
	var lib := GuardPresentation.build_library()
	var poses := [["idle", 1.0], ["walk", 0.0], ["walk", 0.5], ["run", 0.0], ["run", 0.3], ["search", 0.6], ["search", 1.8]]
	for i in poses.size():
		var holder := Node3D.new()
		holder.position = Vector3((i - (poses.size() - 1) / 2.0) * 1.15, 0, 0)
		holder.rotation_degrees.y = 125.0  # three-quarter view
		stage.add_child(holder)
		var model := source.get_node("Model").duplicate() as Node3D
		holder.add_child(model)
		var player := AnimationPlayer.new()
		holder.add_child(player)
		player.root_node = player.get_path_to(holder)
		player.add_animation_library(&"", lib)
		player.play(poses[i][0])
		player.seek(poses[i][1], true)
		player.pause()
		var label := Label3D.new()
		label.text = "%s %.1fs" % poses[i]
		label.position = Vector3(0, 2.15, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 40
		label.outline_size = 8
		holder.add_child(label)
	source.free()
	var camera := Camera3D.new()
	camera.fov = 30.0
	stage.add_child(camera)
	camera.position = Vector3(0, 1.6, 10.5)
	camera.look_at(Vector3(0, 0.95, 0), Vector3.UP)
	camera.current = true
	await _save("guard_poses.png")
	stage.queue_free()
	await process_frame


func _ui_states() -> void:
	var level: Node3D = (load(LEVEL) as PackedScene).instantiate()
	root.add_child(level)
	for i in 90:
		await physics_frame
	var player := level.get_node("Player") as FirstPersonPlayer
	var guard := level.get_node("Guards/GuardMain") as Guard
	var flow := GameFlow.find(level)
	var director := StealthDirector.find(level)
	# 1. Playing: looking at the access card's desk from close by shows the interaction prompt.
	var card := level.get_node("Gameplay/AccessCard") as Node3D
	player.global_position = card.global_position + Vector3(1.2, -0.9, 0)
	_look_at(player, card.global_position)
	await _frames(20)
	await _save("ui_01_prompt.png")
	# 2. Detection rising: stand in front of a guard, facing it, until its meter passes 30.
	player.global_position = guard.global_position - guard.global_basis.z * 6.0
	_look_at(player, guard.global_position + Vector3(0, 1.4, 0))
	var waited := 0
	while guard.vision.detection < 45.0 and waited < 600:
		player.global_position = guard.global_position - guard.global_basis.z * 6.0
		_look_at(player, guard.global_position + Vector3(0, 1.4, 0))
		await physics_frame
		waited += 1
	await _save("ui_02_detection.png")
	# 3. Chase: keep standing there until the guard gives chase.
	waited = 0
	while guard.machine.current != GuardStateMachine.CHASE and waited < 600:
		_look_at(player, guard.global_position + Vector3(0, 1.4, 0))
		await physics_frame
		waited += 1
	await _frames(15)
	await _save("ui_03_chase.png")
	# 4. Caught: let the guard reach the player.
	waited = 0
	while director.status != StealthDirector.Status.CAUGHT and waited < 900:
		_look_at(player, guard.global_position + Vector3(0, 1.4, 0))
		await physics_frame
		waited += 1
	await _frames(40)
	await _save("ui_04_caught.png")
	while director.status == StealthDirector.Status.CAUGHT:
		await physics_frame
	await _frames(30)
	# 5. Pause menu.
	flow.pause()
	await _wait_real(0.4)
	await _save("ui_05_paused.png")
	flow.resume()
	await _wait_real(0.2)
	# 6. Investigation: a noise near a guard sends it to look.
	var east := level.get_node("Guards/GuardEast") as Guard
	# The player stands behind the guard, beyond its sight range.
	player.global_position = east.global_position + east.global_basis.z * 19.0
	_look_at(player, east.global_position + Vector3(0, 1.2, 0))
	await _frames(20)
	NoiseSystem.find(level).emit_noise(east.global_position + east.global_basis.z * 3.0, NoiseEvent.Type.RUN, "capture")
	waited = 0
	while east.machine.current != GuardStateMachine.INVESTIGATE and waited < 120:
		await physics_frame
		waited += 1
	await _frames(45)
	_look_at(player, east.global_position + Vector3(0, 1.2, 0))
	await _frames(2)
	await _save("ui_06_investigating.png")
	# 7. Victory screen: complete the earlier objectives, then really use the exit door.
	var objectives := ObjectiveManager.find(level)
	for id in [ObjectiveManager.ENTER_LIBRARY, ObjectiveManager.REACH_RESTRICTED, ObjectiveManager.TAKE_CARD]:
		objectives.complete(id)
	var door := level.get_node("Gameplay/ExitDoor") as Node3D
	player.global_position = Vector3(26.4, 0.05, -23)
	_look_at(player, door.global_position + Vector3(0, 0.2, 0))
	await _frames(20)
	(player.get_node("Interactor") as PlayerInteractor).try_interact()
	await _wait_real(1.0)
	await _save("ui_07_victory.png")
	level.queue_free()
	await _frames(20)


func _look_at(player: FirstPersonPlayer, target: Vector3) -> void:
	var flat := target - player.global_position
	player.rotation.y = atan2(-flat.x, -flat.z)
	var eye := player.camera.global_position
	player.head.rotation.x = atan2(target.y - eye.y, Vector2(target.x - eye.x, target.z - eye.z).length())


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _wait_real(seconds: float) -> void:
	await create_timer(seconds, true).timeout


func _save(file: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out.path_join(file)))
	print("saved ", _out.path_join(file))
