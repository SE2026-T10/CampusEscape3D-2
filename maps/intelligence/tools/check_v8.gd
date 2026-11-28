extends SceneTree
## Stages two saves to exercise 04-B's real hold input, restoration and results.
const M := preload("res://maps/intelligence/scripts/mission_controller.gd")
const Cleanup := preload("res://tests/test_utils.gd")
const MAP := "res://maps/intelligence/scenes/intelligence_k17%s.tscn"
const ARCHIVE_STAND := Vector3(-19,-4,-42.7)
var _checks := 0
var _failures: Array[String] = []
var _out := ""
var _flow: GameFlow
var _player: FirstPersonPlayer


func _init() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _run() -> void:
	AudioServer.set_bus_mute(0,true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): _out=arg.trim_prefix("--out=")
	if not _out.is_empty(): DirAccess.make_dir_recursive_absolute(_out)
	for test_mode in [false,true]:
		await _check_scene(test_mode)
	await Cleanup.settle_async_audio(self)
	for failure in _failures: printerr(failure)
	print("K17 V8: %d checks; %d failures" % [_checks,_failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _check_scene(test_mode: bool) -> void:
	change_scene_to_file(MAP % ("_test" if test_mode else ""))
	await _frames(40)
	var level := current_scene
	_flow = GameFlow.find(level)
	if _flow.state==GameStateMachine.State.PAUSED: _flow.resume()
	_player = level.get_node("Player")
	_player.set_physics_process(false)
	for guard in level.get_node("Guards").get_children():
		guard.process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("Gameplay/Reinforcements").set_physics_process(false)
	var mission := level.get_node("Gameplay/Mission") as K17MissionController
	var docs := level.get_node("Gameplay/V8Documents")
	var objectives := ObjectiveManager.find(level)
	var checkpoints := CheckpointManager.find(level)
	var annex := docs.get_node("ArchiveDesk/Annex") as AccessCard
	var seal := docs.get_node("ArchiveDesk/Tray/Seal") as Node3D
	var primary := level.get_node("Gameplay/IntelligenceFile") as AccessCard
	var hud := level.get_node("ObjectiveHud") as ObjectiveHud
	var inventory := PlayerInventory.find(level)
	var suffix := "test" if test_mode else "normal"
	_expect(objectives.is_optional(M.ANNEX) and objectives.get_mandatory_ids().size()==7,"04-B leaves seven mandatory objectives / "+suffix)
	_expect(seal.visible and not annex.visible and not annex.enabled and annex.collision_layer==0,"Sealed Annex does not intercept focus / "+suffix)
	_expect(not annex.interact(_player),"04-B cannot be taken early / "+suffix)

	var noise := NoiseSystem.find(level)
	var previous_noise := noise.emitted_count
	_player.position = Vector3(-36,0,5.6)
	var logbook := docs.get_node("GuardDesk/HandoverLog") as Interactable
	await _aim(logbook)
	var phone := docs.get_node("GuardDesk/DeskPhone")
	_expect(phone.rang and phone.get_node("Ring").stream != null,"Approaching the desk triggers its positional ring / "+suffix)
	_expect(noise.emitted_count==previous_noise,"The room cue does not change guard perception / "+suffix)
	for desk in [docs.get_node("GuardDesk"),docs.get_node("ArchiveDesk")]:
		var ray := PhysicsRayQueryParameters3D.create(desk.global_position+Vector3.UP*.08,desk.global_position-Vector3.UP*.16,1)
		var hit := _player.get_world_3d().direct_space_state.intersect_ray(ray)
		# The archive tabletop mesh is 10 cm above its simplified collision box.
		_expect(not hit.is_empty() and absf(hit.position.y-desk.global_position.y)<.13,"New props align with the existing desk / "+str(desk.name))
	if not test_mode:
		await _shot("guard_desk")
		await _hold(1)
		_expect(inventory.has_document(&"k17_handover_04b") and hud.is_journal_open(),"Reading the log stores the clue in J")
		await _shot("handover_log")
		hud.close_journal()

	for id in [M.ENTER,M.PASS,M.CODE,M.ARCHIVE,M.VAULT]:
		objectives.complete(id)
	_expect(checkpoints.activate(level.get_node("Gameplay/ProjectionCheckpoint")),"Pre-file checkpoint is captured / "+suffix)
	_player.position = ARCHIVE_STAND
	await _aim(primary)
	await _shot("sealed_"+suffix)
	await _hold(216)
	_expect(mission.has_file and mission.time_left>119 and annex.visible and not seal.visible,"Taking the primary file starts the clock and exposes 04-B / "+suffix)
	_expect(not test_mode or not inventory.has_document(&"k17_handover_04b"),"Reading the clue is optional / "+suffix)

	await _aim(annex)
	await _shot("annex_"+suffix)
	await _hold(48)
	_expect(not annex.is_taken() and annex.visible,"Releasing E early leaves 04-B in the tray / "+suffix)
	var interactor := _player.get_node("Interactor") as PlayerInteractor
	_key(true)
	await _frames(20)
	_expect(interactor.hold_target==annex,"The full hold starts through real player input / "+suffix)
	_flow.pause()
	var paused_time := mission.time_left
	await _frames(12,false)
	_expect(mission.time_left==paused_time and not annex.is_taken(),"Pausing stops the deadline and pending pickup / "+suffix)
	_key(false)
	_flow.resume()
	await _frames(4)
	var before_take := mission.time_left
	await _hold(184)
	_expect(annex.is_taken() and not annex.visible and not annex.enabled,"Holding E completes 04-B once / "+suffix)
	_expect(before_take-mission.time_left>=3.0 and mission.time_left<117.0,"04-B spends time on the original deadline / "+suffix)
	_expect(not annex.interact(_player),"The annex cannot be taken twice / "+suffix)

	if test_mode:
		mission.time_left = .1
		await _frames(12,false)
		_expect(_flow.retry_checkpoint(),"Timeout can retry the pre-file checkpoint")
	else:
		var director := StealthDirector.find(level)
		director.reset_delay = .05
		director._catch(level.get_node("Guards/Guard1"))
	await _frames(18)
	_expect(_flow.state==GameStateMachine.State.PLAYING and not mission.has_file and primary.visible,"Retry returns the primary file / "+suffix)
	_expect(seal.visible and not annex.is_taken() and not annex.visible and annex.collision_layer==0,"Retry reseals the annex and clears optional progress / "+suffix)
	_expect(inventory.has_document(&"k17_handover_04b") != test_mode,"Retry preserves journal knowledge only when read / "+suffix)

	_player.position = ARCHIVE_STAND
	await _aim(primary)
	await _hold(216)
	if test_mode:
		await _aim(annex)
		await _hold(184)
	var route := &"maintenance" if test_mode else &"courtyard"
	var zone := level.get_node("Gameplay/Extraction%d" % int(test_mode)) as Area3D
	_player.position = zone.global_position-Vector3.UP
	await _frames(40,false)
	_expect(mission.escaped and objectives.escape_route==route,"Both outcomes trigger extraction / "+suffix)
	var menus := level.get_node("GameMenus") as GameMenus
	var ending := "Đoàn sơ tán đã đổi tuyến" if test_mode else "Đang xác minh giờ phong tỏa"
	_expect(_flow.state==GameStateMachine.State.WIN and menus.get_win_text().contains(ending),"Results confirm the correct handoff / "+suffix)
	if DisplayServer.get_name()!="headless":
		var view := root.get_visible_rect()
		_expect(view.encloses(menus.play_again_button.get_global_rect()) and view.encloses(menus._win_stats.get_global_rect()),"Results and buttons remain on-screen / "+suffix)
	_expect(not annex.interact(_player),"The annex cannot be collected after extraction / "+suffix)
	await _shot("win_"+suffix)
	_flow = null
	current_scene = null
	level.queue_free()
	paused = false
	await _frames(20)


func _aim(target: Interactable) -> void:
	_player.camera.look_at(target.global_position)
	await _frames(5)
	_expect(_player.get_node("Interactor").focused==target,"Can aim at "+target.name)


func _key(down: bool) -> void:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = down
	root.push_input(event)


func _hold(frames: int) -> void:
	_key(true)
	await _frames(frames)
	_key(false)
	await _frames(4)


func _frames(count: int,resume := true) -> void:
	for i in count:
		if resume and is_instance_valid(_flow) and _flow.state==GameStateMachine.State.PAUSED:
			_flow.resume()
		await physics_frame


func _shot(name_: String) -> void:
	if _out.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join(name_+".png"))


func _expect(condition: bool,message: String) -> void:
	_checks += 1
	print("[V8 %s] %s" % ["OK" if condition else "FAIL",message])
	if not condition: _failures.append(message)
