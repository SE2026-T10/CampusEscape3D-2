extends SceneTree
## Camera input/render regression: staged setup, real viewport input thereafter.
const C:=preload("res://maps/intelligence/resources/layout/k17_projection.gd")
const M:=preload("res://maps/intelligence/scripts/mission_controller.gd")
var failures: Array[String]=[]
var checks:=0
var flow: GameFlow

class FocusedControl extends Control:
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventKey: accept_event()

func _init() -> void:
	root.unfocusable=true
	_run.call_deferred()

func _run() -> void:
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,720)
	for no_guards in [false,true]:
		change_scene_to_file("res://maps/intelligence/scenes/intelligence_k17_test.tscn" if no_guards else "res://maps/intelligence/scenes/intelligence_k17.tscn")
		await frames(45)
		flow=GameFlow.find(current_scene)
		for guard in current_scene.get_node("Guards").get_children(): guard.process_mode=Node.PROCESS_MODE_DISABLED
		for id in [M.ENTER,M.PASS,M.CODE,M.ARCHIVE,M.VAULT]: ObjectiveManager.find(current_scene).complete(id)
		var player:=current_scene.get_node("Player") as FirstPersonPlayer
		player.set_physics_process(false)
		var rig:=current_scene.get_node("Gameplay/ProjectionRig") as K17ProjectionRig
		var system:=current_scene.get_node("Gameplay/B1Surveillance")
		var hud:=current_scene.get_node("ObjectiveHud")
		rig.position=Vector3(-6,-4,-47)
		rig._set_deployed(true)
		rig.powered=true
		player.position=rig.to_global(C.GRIP_OFFSET)
		player.camera.look_at(rig.to_global(Vector3(0,1.4,-4)))
		key(KEY_V)
		await frames(3)
		expect(not system.hacked and system.feed_mode==0,"V cannot grant CCTV rights before hack")
		expect(player.get_node("Interactor").get_prompt_text().contains("B1") or rig.begin_grip(player),"Equipment remains usable before camera connection")
		rig.release_grip()
		expect(system.hack(),"Hack grants the real camera feed")
		await frames(15)
		await expect_feed(system,1,"Camera front appears immediately after hack")
		key(KEY_V)
		await frames(15)
		await expect_feed(system,2,"Physical V selects C1")
		key(KEY_V)
		await frames(3)
		expect(system.feed_mode==0,"Second V intentionally hides the feed")
		if system._panel: expect(not system._panel.visible,"Hidden feed does not leave a live image panel")
		expect(rig.begin_grip(player),"Actual handle can be gripped while camera is hidden")
		await frames(15)
		await expect_feed(system,1,"Gripping opaque screen restores the front view")
		var held:=rig.holder
		key(KEY_V)
		await frames(15)
		await expect_feed(system,2,"V switches camera while gripping")
		expect(rig.holder==held,"Camera switch does not release the handle")
		var focus_trap:=FocusedControl.new()
		focus_trap.focus_mode=Control.FOCUS_ALL
		root.add_child(focus_trap)
		focus_trap.grab_focus()
		key(KEY_V)
		await frames(3)
		expect(system.feed_mode==0,"Gameplay camera shortcut works with GUI keyboard focus")
		focus_trap.queue_free()
		key(KEY_V,true)
		await frames(3)
		expect(system.feed_mode==0,"Held-key repeat cannot cycle multiple feeds")
		key(KEY_V)
		await frames(15)
		await expect_feed(system,1,"V can reopen a hidden feed")
		flow.pause()
		await frames(3,false)
		key(KEY_V)
		await frames(3,false)
		expect(system.feed_mode==1,"Pause ignores camera shortcut")
		if system._panel: expect(not system._panel.visible,"Camera panel hides during pause")
		flow.resume()
		await frames(15)
		await expect_feed(system,1,"Resume restores camera image")
		hud.open_journal(&"")
		await frames(3)
		key(KEY_V)
		await frames(3)
		expect(system.feed_mode==1,"Journal blocks camera shortcut")
		if system._panel: expect(not system._panel.visible,"Journal hides live camera panel")
		hud.close_journal()
		var saved: Dictionary=system.get_checkpoint_state()
		system.restore_checkpoint_state(saved)
		await frames(15)
		await expect_feed(system,1,"Restoring hacked checkpoint restores a usable front feed")
		if system._camera:
			expect(system._camera.global_position.distance_to(rig.to_global(Vector3(0,1.65,-.23)))<.01,"Front camera is ahead of opaque screen, not inside it")
			await RenderingServer.frame_post_draw
			expect(not system._viewport.get_texture().get_image().is_empty(),"Native renderer produced real camera pixels")
			if not no_guards:
				var guard:=current_scene.get_node("Guards/Guard6") as Node3D
				var with_guard: Image=system._viewport.get_texture().get_image()
				guard.hide()
				await frames(15)
				await RenderingServer.frame_post_draw
				var without_guard: Image=system._viewport.get_texture().get_image()
				expect(changed_pixels(with_guard,without_guard)>8,"Front feed renders the actual guard ahead instead of the empty camouflage image")
				guard.show()
				await frames(15)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://maps/intelligence/docs/camera-feed-fix"))
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://maps/intelligence/docs/camera-feed-fix/"+("no_guards" if no_guards else "normal")+".png"))
		ObjectiveManager.find(current_scene).complete(M.FILE)
		await frames(15)
		key(KEY_V)
		await frames(3)
		expect(system.revoked and system.feed_mode==0,"Seal alarm still revokes feeds; V cannot bypass it")
		if system._panel: expect(not system._panel.visible,"Revoked feed cannot show a stale live image")
		current_scene.queue_free()
		current_scene=null
		await frames(30)
		flow=null
	await preload("res://tests/test_utils.gd").settle_async_audio(self)
	for failure in failures: printerr(failure)
	print("K17 B1 CAMERA FEED: %d checks; %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func expect_feed(system: Node,mode: int,label: String) -> void:
	expect(system.feed_mode==mode,label)
	if system._panel:
		expect(system._panel.is_visible_in_tree(),label+" / visible on native renderer")
		expect(system._image.visible and system._image.texture!=null,label+" / actual viewport texture")

func key(code: Key,echo:=false) -> void:
	var press:=InputEventKey.new()
	press.physical_keycode=code
	press.keycode=code
	press.pressed=true
	press.echo=echo
	root.push_input(press)
	var release:=InputEventKey.new()
	release.physical_keycode=code
	release.keycode=code
	root.push_input(release)

func frames(count: int,resume:=true) -> void:
	for i in count:
		if resume and is_instance_valid(flow) and flow.state==GameStateMachine.State.PAUSED: flow.resume()
		await physics_frame

func expect(value: bool,label: String) -> void:
	checks+=1
	print("[B1 camera ","OK" if value else "FAIL","] ",label)
	if not value: failures.append(label)

func changed_pixels(a: Image,b: Image) -> int:
	var count:=0
	for y in a.get_height():
		for x in a.get_width():
			var first:=a.get_pixel(x,y)
			var second:=b.get_pixel(x,y)
			if absf(first.r-second.r)+absf(first.g-second.g)+absf(first.b-second.b)>.1: count+=1
	return count
