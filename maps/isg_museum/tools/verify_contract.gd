extends SceneTree

## Contract state and real exit/restart integration. Exhibit mechanics have their
## own tests; completing objectives here isolates scoring from furniture layout.
const SCENE := "res://maps/isg_museum/scenes/museum.tscn"
var level: Node3D
var contract: Node
var player: FirstPersonPlayer
var objectives: ObjectiveManager
var failures := 0
var checks := 0
var fixture_contract_index := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, caption: String) -> void:
	checks += 1
	if ok:
		print("PASS: ",caption)
	else:
		failures += 1
		push_error(caption)


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func isolate() -> void:
	for guard: Guard in get_nodes_in_group("guards"):
		guard.set_physics_process(false)
		guard.agent.avoidance_enabled = false
		guard.velocity = Vector3.ZERO
		guard.vision.set_physics_process(false)
		guard.vision.reset()
		guard.hearing.set_physics_process(false)
		guard.get_node("Presentation").process_mode = Node.PROCESS_MODE_DISABLED
	player = level.get_node("Player")
	player.set_physics_process(false)
	player.get_node("Noise").set_physics_process(false)
	level.get_node("StealthDirector").set_physics_process(false)
	contract = get_first_node_in_group("museum_contract")
	objectives = level.get_node("ObjectiveManager")


func silence() -> void:
	if not is_instance_valid(level):
		return
	for sound in level.find_children("*","AudioStreamPlayer3D",true,false):
		sound.stop()
		sound.stream = null


func fresh() -> void:
	paused = false
	if is_instance_valid(level):
		silence()
		current_scene = null
		level.free()
		await frames(3)
	level = load(SCENE).instantiate()
	level.get_node("MuseumContract").contract_index_override = fixture_contract_index
	root.add_child(level)
	current_scene = level
	isolate()
	await frames(20)


func press_e() -> void:
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventAction.new()
	release.action = &"interact"
	Input.parse_input_event(release)
	await process_frame
	await frames(3)


func aim(target: Node3D, feet: Vector3) -> void:
	player.position = feet
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.camera.look_at(target.global_position)
	await frames(4)


func press_j() -> void:
	var press := InputEventKey.new()
	press.physical_keycode = KEY_J
	press.keycode = KEY_J
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventKey.new()
	release.physical_keycode = KEY_J
	release.keycode = KEY_J
	Input.parse_input_event(release)
	await process_frame
	await frames(4)


func escape() -> bool:
	var exit := level.get_node("Interactables/EscapeWindow") as Interactable
	await aim(exit,Vector3(34.1,4.5,27))
	if player.get_node("Interactor").find_target() != exit:
		check(false,"Exit remains selectable by camera ray")
		return false
	await press_e()
	return level.get_node("GameFlow").state == GameStateMachine.State.WIN


func restart_real() -> bool:
	var old_id := level.get_instance_id()
	var ui := get_first_node_in_group("museum_contract_ui")
	if ui and ui.visible and ui._is_result:
		ui.restart_button.pressed.emit()
	elif not level.get_node("GameFlow").restart():
		return false
	for i in 80:
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != old_id:
			level = current_scene as Node3D
			isolate()
			await frames(20)
			return true
	return false


func _run() -> void:
	await fresh()
	if contract == null:
		check(false,"Museum scene contains the contract manager")
		quit(1)
		return
	check(not contract.accepted and not contract.has_ticket and not contract.ticket_scanned,
		"New attempt begins without assigned contract or access ticket")
	check(contract.catalog.size() >= 10,"Catalog contains unique IDs for all room collectibles")
	check(objectives.get_mandatory_ids() == [&"escape"] and not objectives.is_finished(),
		"Only escape is mandatory; optional items cannot automatically win the level")
	check(objectives.get_state(&"escape") == ObjectiveManager.State.ACTIVE,
		"Escape objective is available independently of item checklist")
	var exit := level.get_node("Interactables/EscapeWindow") as Interactable
	check(not exit.interact(player),"Escape refuses a player without rope")
	check(contract.report().rating == "unassigned","A run without talking to teammate is identified separately")
	check(not contract.scan_ticket() and not contract.ticket_scanned,"Ticket reader cannot grant access without a ticket")
	contract.grant_ticket()
	check(contract.has_ticket and contract.scan_ticket() and contract.ticket_scanned,
		"Receiving and scanning one ticket unlocks shared upstairs access")
	objectives.complete(&"take_h1")
	check(not objectives.is_finished(),"Collecting an optional item before assignment keeps gameplay running")
	var teammate := level.get_node("NavigationRegion3D/Teammate") as Node3D
	await aim(teammate,Vector3(20.5,0,33))
	check(player.get_node("Interactor").find_target() == teammate,"Teammate outside museum is selectable by camera ray")
	await press_e()
	var ui := get_first_node_in_group("museum_contract_ui")
	check(ui.visible and not ui._is_result and player.modal_active and not paused,
		"Camera E opens teammate contract paper while world continues")
	check(ui.panel.get_global_rect().get_center().distance_to(root.get_visible_rect().get_center()) < 2
		and root.get_visible_rect().encloses(ui.panel.get_global_rect()),"Contract paper stays within centre of viewport")
	check(ui.content.get_children().any(func(node): return node is Label and node.text.contains("21:30")),
		"Contract paper includes appointment evidence needed for service quiz")
	ui.accept_button.pressed.emit()
	await frames(3)
	check(contract.accepted and not ui.visible and not player.modal_active,"Accept button assigns contract and restores player controls")
	await press_j()
	check(ui.visible and not ui._is_result,"J reopens accepted contract without visiting teammate again")
	await press_e()
	check(not ui.visible and not player.modal_active,"E puts contract paper away without changing game state")
	var report: Dictionary = contract.report()
	check(contract.accepted and report.required.size() >= 2 and report.required.size() <= 3,
		"Teammate assigns one fixed contract with two to three targets")
	check(report.required.has("s1") and report.required.has("h1") and report.required.has("t1"),
		"First contract asks for bronze bird, silver medal and T1")
	check(report.collected.has("h1") and not report.missing.has("h1") and report.rating == "partial",
		"Correct item collected before assignment counts after accepting contract")
	var before_extras_score: int = report.score
	objectives.complete(&"take_b2")
	objectives.complete(&"take_a2")
	report = contract.report()
	check(report.extras.has("b2") and report.extras.has("a2") and report.missing.has("s1") and report.missing.has("t1")
		and report.rating == "partial","Extra artwork never substitutes for missing contract targets")
	check(report.score >= before_extras_score,"Additional artwork does not deduct beginner score")
	objectives.complete(&"take_s1")
	objectives.complete(&"take_t1")
	report = contract.report()
	check(report.rating == "complete" and report.missing.is_empty(),"All requested IDs complete contract assessment")
	check(not objectives.is_finished() and level.get_node("GameFlow").state == GameStateMachine.State.PLAYING,
		"Completing every contract target still requires explicit escape")
	contract.record_alarm("contract verification")
	contract.record_alarm("contract verification second")
	check(contract.report().alarms == 2,"Report counts distinct alarm events")
	check(contract.report(false).rating == "caught","Caught assessment overrides completed collection")
	# Actual exit with no contract items, after explicitly accepting the job.
	await fresh()
	contract.accept_contract()
	objectives.complete(&"take_rope")
	check(not objectives.is_finished(),"Rope alone does not automatically end the attempt")
	check(await escape() and contract.report().rating == "empty","Rope permits an actual empty-handed retreat")
	ui = get_first_node_in_group("museum_contract_ui")
	check(ui.visible and ui._is_result and contract.last_report.rating == "empty",
		"Retreat opens result sheet with frozen empty-handed assessment")
	check(await restart_real() and not contract.accepted and not contract.has_ticket
		and not contract.ticket_scanned and contract.report().collected.is_empty()
		and not objectives.is_completed(&"take_rope"),"Real scene restart clears contract, ticket, loot and rope together")
	# Actual partial exit.
	contract.accept_contract()
	objectives.complete(&"take_rope")
	objectives.complete(StringName(contract.catalog[contract.selected_ids[0]].objective))
	check(await escape() and contract.report().rating == "partial" and contract.report().missing.size() == 2,
		"Actual exit with one requested item yields partial contract")
	await fresh()
	contract.accept_contract()
	for id in [&"take_rope",&"take_s1",&"take_h1",&"take_t1"]:
		objectives.complete(id)
	check(await escape() and contract.report().rating == "complete",
		"Actual exit with exactly the requested items completes contract without all artwork")
	# Live guard facts must block exit even before director aggregation updates.
	await fresh()
	objectives.complete(&"take_rope")
	var guard: Guard = level.get_node("Guard_G1")
	guard.vision.can_see_target = true
	check(not exit_for_level().interact(player),"Live guard sight prevents rope exit")
	guard.vision.can_see_target = false
	guard.machine.request_transition(GuardStateMachine.CHASE,"contract verification",player.position)
	check(not exit_for_level().interact(player),"Live chase prevents rope exit")
	await frames(8)
	check(contract.report().detections == 1,"Detection statistic counts a chase encounter once rather than every frame")
	guard.reset_to_start()
	guard.set_physics_process(false)
	level.get_node("GameFlow").pause()
	check(not exit_for_level().interact(player),"Paused game cannot execute an escape interaction")
	level.get_node("GameFlow").resume()
	# T2 stays uncredited while held or on the floor, then credits once at depot.
	await fresh()
	contract.accept_contract()
	objectives.complete(&"take_key")
	var painting = level.get_node("Interactables/Painting_T2")
	await aim(painting,Vector3(33.5,4.5,10))
	await press_e()
	check(player.is_carrying() and not contract.report().collected.has("t2") and not objectives.is_completed(&"take_t2"),
		"T2 carried in hands is not credited in report")
	player.position = Vector3(32,4.5,16)
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	await frames(4)
	check(painting.try_drop() and not contract.report().collected.has("t2"),"Dropping T2 on floor still does not credit delivery")
	await aim(painting,Vector3(32,4.5,16))
	await press_e()
	var depot := level.get_node("Interactables/T2Depot") as Node3D
	await aim(depot,Vector3(32,4.5,27.5))
	await press_e()
	check(objectives.is_completed(&"take_t2") and contract.report().collected.has("t2")
		and contract.report().extras.has("t2"),"Only E delivery at depot credits T2 as collected extra")
	# Real catch signal must snapshot and preserve the caught assessment.
	var director := level.get_node("StealthDirector") as StealthDirector
	director._catch(level.get_node("Guard_G1"))
	await frames(5)
	var caught_id := level.get_instance_id()
	check(contract.report(false).rating == "caught" and level.get_node("GameFlow").state == GameStateMachine.State.CAUGHT,
		"Guard catch enters caught state with a report for that attempt")
	ui = get_first_node_in_group("museum_contract_ui")
	check(ui.visible and ui._is_result and contract.last_report.rating == "caught",
		"Caught attempt opens result sheet instead of generic victory")
	await frames(180)
	check(is_instance_valid(level) and current_scene != null and current_scene.get_instance_id() == caught_id,
		"Caught result persists beyond the former automatic reset delay")
	check(await restart_real() and not contract.accepted and contract.report().collected.is_empty(),
		"Restart after caught report restores fresh contract and collection")
	print("Museum contract verification: %d checks, %d failures"%[checks,failures])
	silence()
	current_scene = null
	level.free()
	await process_frame
	quit(0 if failures == 0 else 1)


func exit_for_level() -> Interactable:
	return level.get_node("Interactables/EscapeWindow") as Interactable
