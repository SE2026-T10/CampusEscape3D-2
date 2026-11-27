extends RefCounted

const BASE := "res://maps/isg_museum/"
var checks := 0
var failures: Array[String] = []
var tree: SceneTree

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)

func frames(n: int) -> void:
	for i in n: await tree.physics_frame

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await tree.process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	Input.parse_input_event(event)
	await frames(3)

func run(host: Node) -> Array[String]:
	tree = host.get_tree()
	var level: Node3D = load(BASE+"scenes/museum.tscn").instantiate()
	host.add_child(level)
	await frames(20)
	for actor in level.get_children():
		if actor is Guard:
			actor.set_physics_process(false)
			actor.agent.avoidance_enabled = false
			actor.vision.set_physics_process(false)
			actor.hearing.set_physics_process(false)
	level.get_node("StealthDirector").set_physics_process(false)
	var player = level.get_node("Player")
	player.set_physics_process(false)
	player.get_node("Noise").set_physics_process(false)
	var n0 = level.get_node("NavigationRegion3D/Teammate")
	var reception = level.get_node("NavigationRegion3D/ServiceExpansion/Receptionist")
	var p0 = n0.get_node("Presentation")
	var p1 = reception.get_node("Presentation")
	var ui = tree.get_first_node_in_group("museum_contract_ui")
	var service = tree.get_first_node_in_group("museum_service_ui")
	var contract = tree.get_first_node_in_group("museum_contract")
	var flow = level.get_node("GameFlow")
	for npc in [n0,reception]:
		check(npc is Interactable and not npc.is_in_group("guards"),"NPC remains an Interactable outside guard groups")
		check(npc.find_children("*","Skeleton3D",true,false).size()==1,"One skeletal visual per NPC")
		check(npc.find_children("*","NavigationAgent3D",true,false).is_empty() and npc.find_children("*","AudioStreamPlayer3D",true,false).is_empty(),"No guard navigation/audio copied into NPC")
		check(not npc.has_node("Head") and not npc.has_node("Body") and not npc.has_node("Torso"),"Old box character removed")
		var p = npc.get_node("Presentation")
		check(p.skeleton.get_bone_count()==65 and p.skeleton.get_child(0).skin!=null,"NPC uses real existing 65-bone skin")
	check(p0.skeleton!=p1.skeleton and p0.animation!=p1.animation,"Independent poses and playback")
	check(p0.skeleton.get_child(0).mesh==p1.skeleton.get_child(0).mesh,"Immutable mesh shared")
	check(absf(p0.visual.global_position.y)<.01,"N0 floor anchor compensates interaction-root height")
	var approach: Vector3 = Vector3(18,0,35)-p0.visual.global_position
	check((-p0.visual.global_basis.z).dot(approach.normalized())>.5,"N0 faces the exterior approach")
	check(p1.visual.global_position.distance_to(Vector3(33.05,0,27))<.01,"Reception anchor lies at actual chair floor")
	check((-p1.visual.global_basis.z).dot(Vector3.LEFT)>.99,"Receptionist faces counter to the west")
	var guard_material: Material = level.get_node("Guard_G1/Model/VisualPivot/GuardRig/Skeleton3D/Object_6").mesh.surface_get_material(0)
	var guard_colour: Color = guard_material.albedo_color
	check(p0.skeleton.get_node("Object_6").get_active_material(0)!=guard_material and p1.skeleton.get_node("Object_6").get_active_material(0)!=guard_material,"Only private role material overrides are recoloured")
	check(p0.skeleton.get_node("Object_7").get_active_material(0)==p1.skeleton.get_node("Object_7").get_active_material(0),"Skin/face source material retained")
	var other_pose: Transform3D = p1.skeleton.get_bone_pose(8)
	p0.animation.play("standing_talk")
	p0.animation.seek(.2,true)
	var pose: Transform3D = p0.skeleton.get_bone_pose(8)
	p0.animation.seek(1.4,true)
	check(not pose.is_equal_approx(p0.skeleton.get_bone_pose(8)),"Talk clip really rotates arm joints")
	check(other_pose.is_equal_approx(p1.skeleton.get_bone_pose(8)),"Talking N0 does not change receptionist pose")
	p1.animation.play("seated_talk")
	p1.animation.seek(.5,true)
	pose = p1.skeleton.get_bone_pose(8)
	p1.animation.seek(3.5,true)
	check(not pose.is_equal_approx(p1.skeleton.get_bone_pose(8)),"Reception talk clip really animates arm joints")
	p1.reset_presentation()
	p0.reset_presentation()
	player.position = Vector3(20.5,0,33.3)
	player.camera.look_at(n0.global_position)
	await frames(4)
	check(player.get_node("Interactor").find_target()==n0,"N0 selectable by actual camera ray")
	player.modal_active = true
	check(not n0.interact(player) and not p0.talking,"Modal rejection never begins talking")
	player.modal_active = false
	flow.pause()
	check(not n0.interact(player) and not p0.talking,"Gameflow rejection never begins talking")
	flow.resume()
	check(n0.interact(player) and p0.talking,"Successful direct N0 interaction starts talk")
	var changes: int = p0.playback_changes
	p0.set_talking(true)
	p0.set_talking(true)
	check(p0.playback_changes==changes,"Repeated talk flag does not restart clip")
	var selected: Array = contract.selected_ids.duplicate()
	ui.accept_button.pressed.emit()
	check(contract.accepted and not p0.talking and not ui.visible,"Accepting contract ends direct conversation")
	for code in [KEY_E,KEY_ESCAPE,KEY_J]:
		check(n0.interact(player),"Reopen N0 conversation")
		await key(code)
		check(not ui.visible and not p0.talking,"Contract key closes talk: "+str(code))
	check(contract.selected_ids==selected,"Contract is not rerolled on repeated conversation")
	ui.open_contract(n0)
	player.position = Vector3(18,0,35)
	await frames(6)
	check(not ui.visible and not p0.talking,"Distance ends N0 conversation")
	await key(KEY_J)
	check(ui.visible and ui._source==null and not p0.talking,"J reads remotely without N0 talking")
	ui.close_sheet()
	player.position = Vector3(31.1,0,27)
	player.camera.look_at(reception.global_position)
	await frames(5)
	check(player.get_node("Interactor").find_target()==reception,"Receptionist remains selectable above counter")
	player.modal_active = true
	check(not reception.interact(player) and not p1.talking,"Reception modal rejection leaves seated idle")
	player.modal_active = false
	check(reception.interact(player) and p1.talking and p1.current_animation=="seated_talk","Direct quiz starts seated talk")
	await frames(15)
	var hips: Vector3 = p1.bone_position("Hips")
	var foot: Vector3 = p1.bone_position("LeftFoot")
	print("RECEPTION hips=",hips," foot=",foot)
	check(hips.y>.4 and hips.y<.7 and foot.y>-.08 and foot.y<.3,"Seated hips/feet align with chair and floor")
	for i in 3: service.answer((service.questions[0].correct+1)%4)
	player.position = Vector3(31.1,0,28.4)
	await frames(50)
	check(service.cooldown_left>0 and p1.watching and p1.current_animation=="seated_watch","Cooldown selects watching pose during existing session")
	check(reception.get_node("WatchNotice").visible and absf(p1.look.yaw)>.05 and absf(p1.look.yaw)<=.65,"Watch notice and bounded skeletal look actually operate")
	check(not p1.look.last_head_pose.is_equal_approx(p1.skeleton.get_bone_pose_rotation(p1.skeleton.find_bone("mixamorig_Head"))),"Post-animation modifier changes the rendered head pose")
	check(p1.visual.global_position.distance_to(Vector3(33.05,0,27))<.01,"Watching never moves pelvis/seat anchor")
	service.cooldown_left = .02
	await frames(8)
	check(not p1.watching and p1.current_animation=="seated_talk","Cooldown expiry resumes current conversation without losing source")
	service.answer(service.questions[0].correct)
	service.answer(service.questions[1].correct)
	check(not contract.has_ticket,"Two answers never grant ticket")
	changes = p1.playback_changes
	var old_mouse: int = service._old_mouse
	service.answer(service.questions[2].correct)
	check(contract.has_ticket and service.mode=="ticket" and service.source==reception,"Third answer grants ticket and keeps NPC source")
	check(p1.playback_changes==changes and p1.talking and player.modal_active and service._old_mouse==old_mouse,"Quiz to ticket keeps clip, modal ownership and mouse restore mode")
	service.close_button.pressed.emit()
	check(not p1.talking and p1.current_animation=="seated_idle","Button close returns seated idle")
	for code in [KEY_E,KEY_ESCAPE,KEY_V]:
		reception.interact(player)
		await key(code)
		check(not service.visible and not p1.talking,"Service key closes talk: "+str(code))
	service.open_map(level.get_node("NavigationRegion3D/ServiceExpansion/WallMap"),player)
	service.save_map()
	check(not p1.talking,"Physical map is not an NPC conversation")
	service.close_panel()
	player.position = Vector3(18,0,35)
	for code in [KEY_M,KEY_V]:
		await key(code)
		check(service.visible and service.source==null and not p1.talking,"Remote document never triggers talking: "+str(code))
		service.close_panel()
	player.position = Vector3(31.1,0,27)
	reception.interact(player)
	player.position = Vector3(18,0,35)
	await frames(5)
	check(not service.visible and not p1.talking,"Distance closes reception conversation")
	player.position = Vector3(31.1,0,27)
	reception.interact(player)
	await frames(3)
	flow.pause()
	var time: float = p1.animation.current_animation_position
	for i in 5: await tree.process_frame
	check(not p1.talking and is_equal_approx(time,p1.animation.current_animation_position),"Pause closes dialogue and freezes animation")
	flow.resume()
	for gate_name in ["TicketGate_A","TicketGate_B"]:
		var gate = level.get_node("NavigationRegion3D/ServiceExpansion/"+gate_name)
		player.position = gate.global_position+Vector3(-.6,0,0)
		check(gate.interact(player) and gate.is_open,"Earned ticket opens "+gate_name)
	check(guard_material.albedo_color==guard_colour,"NPC recolouring leaves guard materials unchanged")
	ui.open_contract(n0)
	ui.queue_free()
	await frames(2)
	check(not p0.talking,"UI destruction ends conversation before losing source")
	for sound in level.find_children("*","AudioStreamPlayer3D",true,false): sound.stop()
	level.free()
	var editing: Node3D = load(BASE+"scenes/museum_editing.tscn").instantiate()
	host.add_child(editing)
	await frames(10)
	var npc0 = editing.get_node("NavigationRegion3D/Teammate")
	var npc1 = editing.get_node("NavigationRegion3D/ServiceExpansion/Receptionist")
	check(npc0.has_node("Visual") and npc1.has_node("Visual") and editing.find_children("*","Skeleton3D",true,false).size()==2,"Editing reload retains exactly two NPC visuals and no guard skeleton")
	check(not npc0.get_node("Presentation").talking and not npc1.get_node("Presentation").talking,"Reload restores default presentation states")
	var edit_player = editing.get_node("Player")
	edit_player.set_physics_process(false)
	check(npc0.interact(edit_player),"Editing mode N0 remains interactive")
	tree.get_first_node_in_group("museum_contract_ui").close_sheet()
	check(npc1.interact(edit_player),"Editing mode receptionist remains interactive")
	editing.free()
	print("NPC visual verification: %d checks, %d failures"%[checks,failures.size()])
	return failures
