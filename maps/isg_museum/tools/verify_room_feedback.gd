extends "res://maps/isg_museum/tools/verify_contract.gd"

func _run() -> void:
	await fresh()
	var calendar := get_first_node_in_group("staff_calendar")
	var room := level.get_node("NavigationRegion3D/Geometry/StaffInterior")
	var storage := level.get_node("NavigationRegion3D/Geometry/StorageInterior")
	var door := level.get_node("NavigationRegion3D/Doors/Storage")
	var fake := {"year":2026,"month":11,"day":7,"hour":23,"minute":59,"second":59}
	calendar.time_provider = func(): return fake
	calendar.refresh_clock()
	check(calendar.face.days[6] == 7 and calendar.face.days.count(7) == 1,"Calendar puts 7 November 2026 in the Saturday column")
	check(calendar.get_code() == "0711" and door.current_code() == "0711","Calendar and lock share one zero-padded DDMM code")
	for year in [2024,2025,2000,2100]:
		fake.merge({"year":year,"month":2,"day":1},true)
		calendar.refresh_clock()
		var expected := 29 if year in [2024,2000] else 28
		check(calendar.face.days.max() == expected,"February day count follows leap-year rules for %d"%year)
	fake.merge({"year":2026,"month":12,"day":31},true)
	calendar.refresh_clock()
	await aim(calendar,Vector3(28.7,0,16))
	await press_e()
	var reader := level.get_node("StaffReader")
	check(reader.panel.visible and reader._calendar_mode,"E opens the graphical month calendar")
	check(root.get_visible_rect().encloses(reader.panel.get_global_rect()),"Portrait calendar fits inside viewport")
	fake.merge({"year":2027,"month":1,"day":1},true)
	await frames(65)
	check(calendar.face.date.day == 1 and calendar.face.date.year == 2027 and door.current_code() == "0101","Midnight updates wall calendar, reading sheet and lock together")
	await press_e()
	player.position = Vector3(25.5,0,21)
	check(not door.submit_code("3112",player) and not door.unlocked,"Yesterday's code no longer unlocks the closed door")
	check(door.submit_code("0101",player) and door.unlocked,"Today's code unlocks the door")
	fake.day = 2
	calendar.refresh_clock()
	check(door.current_code() == "0201" and door.unlocked,"Already-solved door retains access after date rollover")
	check(door.interact(player) and not door.is_open and door.interact(player) and not door.keypad.visible,"Unlocked door closes and reopens after midnight without entering code again")
	check(not room.has_node("ShiftLog") and room.get_node("KeyLabelText").text.contains("PHÒNG B"),"Book replaced by key rack label")
	check(not storage.has_node("UtilityCart") and not storage.has_node("Checklist") and not storage.has_node("InspectionTag"),"Requested cart, board and maintenance date are removed")
	check(is_equal_approx(storage.get_node("SteelCabinet").position.z+.325,23.85),"Cabinet back sits against interior face of south wall")
	check(not level.get_node("NavigationRegion3D/Teammate").has_node("Bench"),"Bench beside N0 removed")
	check(not level.get_node("NavigationRegion3D/Doors").has_node("RestorationShortcut"),"B-to-restoration door and navigation link removed")
	var ray := PhysicsRayQueryParameters3D.create(Vector3(32,5.8,16),Vector3(32,5.8,20),1)
	check(not level.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Full-height wall occupies former B shortcut")
	var guard := level.get_node("Guard_G3")
	guard.position.y = 0
	guard.go_to_sleep()
	var presentation := guard.get_node("Presentation")
	presentation._process(0)
	var knee: Node3D = presentation._shins[0]
	check((knee.global_position-guard.global_position).dot(-guard.global_basis.z) > .35,"Seated knees extend forward toward desk")
	check(knee.global_basis.y.dot(Vector3.UP) > .99,"Calves point vertically down from knees")
	var shoe: MeshInstance3D = knee.get_child(1)
	check(absf(shoe.global_position.y-.04) < .01,"Seated shoes rest on floor")
	check(guard.get_debug_text().contains("sleeping") and not guard.get_debug_text().contains("returning to chair"),"Debug description matches sleeping phase")
	guard.set_phase(&"searching")
	presentation._process(0)
	check(not knee.visible and is_equal_approx(guard.get_node("Model/Hips").position.y,.9),"Standing restores original proportions and hides seated leg pieces")
	var paintings := [
		["Interactables/Painting_T1",0,.15,1.0],
		["Interactables/Painting_T2",0,35.85,-1.0],
		["Interactables/Painting_T3",2,.15,1.0],
		["NavigationRegion3D/ExhibitsExpansion/A2",0,.15,1.0],
		["NavigationRegion3D/ExhibitsExpansion/B2",0,35.85,-1.0],
		["NavigationRegion3D/ExhibitsExpansion/C2",2,.15,1.0],
	]
	for entry in paintings:
		var item := level.get_node(entry[0])
		var gap := INF
		for mesh: MeshInstance3D in item.find_children("*","MeshInstance3D",true,false):
			var bounds := mesh.get_aabb()
			for corner in 8:
				var point := mesh.global_transform*bounds.get_endpoint(corner)
				gap = minf(gap,(point[int(entry[1])]-float(entry[2]))*float(entry[3]))
		check(gap >= -.002 and gap <= .02,"Artwork sits within two centimetres of wall: "+String(entry[0]))
	print("Room feedback verification: %d checks, %d failures"%[checks,failures])
	silence()
	current_scene = null
	level.free()
	await process_frame
	quit(0 if failures == 0 else 1)
