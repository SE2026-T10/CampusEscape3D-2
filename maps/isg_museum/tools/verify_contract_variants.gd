extends "res://maps/isg_museum/tools/verify_contract.gd"

func _run() -> void:
	var data := preload("res://maps/isg_museum/scripts/museum_contract.gd")
	var counts := [0,0,0,0]
	var repeats := 0
	var last := -1
	for i in 10000:
		var index := data.sample_contract_index()
		counts[index] += 1
		if last == index:
			repeats += 1
		last = index
	check(counts.all(func(n): return n > 2200 and n < 2800),"Independent draws sample all four contracts at approximately 25 percent")
	check(repeats > 1500,"Sampling permits consecutive duplicate contracts instead of excluding previous pick")
	var answer_positions := {}
	for variant in 4:
		fixture_contract_index = variant
		await fresh()
		var expected: Dictionary = data.CONTRACTS[variant]
		check(contract.contract_info == expected and contract.selected_ids == expected.targets,"Variant %d supplies its own targets, event, time and host"%(variant+1))
		var expansion := level.get_node("NavigationRegion3D/ServiceExpansion")
		var poster := expansion.get_node("EventPoster")
		var plate := expansion.get_node("ReceptionNotice")
		check(poster.get_content().contains(expected.event.to_upper()) and poster.get_node("Caption").text.contains(expected.event.to_upper()),"Poster matches event for variant %d"%(variant+1))
		check(plate.get_content().contains(expected.host) and not plate.get_content().contains("Vé") and plate.position.y > 1.1 and plate.position.y < 1.5,"Small desk nameplate shows correct host and no ticket details")
		await aim(plate,Vector3(30,0,26.35))
		check(player.get_node("Interactor").find_target() == plate,"Desk nameplate can be read with actual camera E ray")
		var teammate := level.get_node("NavigationRegion3D/Teammate")
		check(teammate.position.x > 19.5 and teammate.position.z > 30 and teammate.position.z < 33,"N0 stands to right of entrance clear of main doorway")
		await aim(teammate,Vector3(20.5,0,33))
		await press_e()
		var paper := get_first_node_in_group("museum_contract_ui")
		check(paper.visible and paper.content.get_child(0).text.contains(expected.event.to_upper()),"Paper title matches selected contract")
		await frames(8)
		var main_fits: bool = root.get_visible_rect().encloses(paper.panel.get_global_rect())
		check(main_fits and paper.accept_button.is_visible_in_tree() and paper.panel.get_global_rect().encloses(paper.accept_button.get_global_rect()),"Compact paper and accept action fit 1280x720")
		var text := ""
		for node in paper.content.find_children("*","Label",true,false):
			text += node.text
		check(not text.contains("N0:") and not text.contains("S1 ·") and text.contains(expected.appointment),"Paper omits long dialogue and item IDs while keeping appointment")
		paper.accept_button.pressed.emit()
		var selected_before: Array = contract.selected_ids.duplicate()
		await press_j()
		check(contract.selected_ids == selected_before and contract.contract_info == expected,"Reopening contract in same attempt never rerolls")
		await press_e()
		var ui := expansion.get_node("ServiceUi")
		var npc := expansion.get_node("Receptionist")
		await aim(npc,Vector3(31.1,0,27))
		await press_e()
		check(ui.visible and ui.mode == "quiz" and not contract.has_ticket,"Quiz starts without showing or granting ticket")
		var fields := ["event","host","appointment"]
		for q in 3:
			var question: Dictionary = ui.questions[q]
			check(question.answers.size() == 4 and question.answers[question.correct] == expected[fields[q]],"Question %d correct answer follows active contract"%(q+1))
			answer_positions[question.correct] = true
			ui.answers.get_child(question.correct).pressed.emit()
		check(contract.has_ticket and ui.mode == "ticket" and ui.question.text.contains(expected.event)
			and ui.question.text.contains(expected.host) and ui.question.text.contains(expected.appointment),"Third correct answer hands over readable ticket with matching details")
		await frames(6)
		check(root.get_visible_rect().encloses(ui.panel.get_global_rect()),"Ticket stays centred and inside screen")
		await press_e()
		var v := InputEventKey.new()
		v.physical_keycode = KEY_V
		v.pressed = true
		Input.parse_input_event(v)
		await frames(4)
		check(ui.visible and ui.mode == "ticket" and ui.source == null,"V reopens saved ticket without returning to NPC")
		ui.close_panel()
		# End a real attempt; restart must use production random selection, not fixture.
		level.get_node("StealthDirector")._catch(level.get_node("Guard_G1"))
		await frames(4)
		check(await restart_real() and not contract.accepted and not contract.has_ticket
			and data.CONTRACTS.has(contract.contract_info),"Caught restart clears progress and draws a valid fresh contract")
	check(answer_positions.size() >= 2,"Answer positions vary rather than hard-coding a fixed button")
	print("Contract variants verification: %d checks, %d failures; draws %s"%[checks,failures,counts])
	silence()
	current_scene = null
	level.free()
	await process_frame
	quit(0 if failures == 0 else 1)
