extends RefCounted
const Utils := preload("res://tests/test_utils.gd")
const L := preload("res://maps/intelligence/resources/layout/k17_layout.gd")
const V4 := preload("res://maps/intelligence/resources/layout/k17_v4.gd")
const M := preload("res://maps/intelligence/scripts/mission_controller.gd")
var failures: Array[String] = []
var checks := 0
var host: Node
var level: Node3D

func run(parent: Node) -> Array[String]:
	host = parent
	level = (load("res://maps/intelligence/scenes/intelligence_k17.tscn") as PackedScene).instantiate()
	_expect(await Utils.add_level_and_wait_for_navigation(host,level,L.SPAWN),"Navigation ready")
	var player := level.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	for guard in level.get_node("Guards").get_children():
		guard.set_physics_process(false)
		guard.vision.set_physics_process(false)
		_expect(guard.expanded_security and is_equal_approx(guard.chase_speed,V4.CHASE_SPEED),"Permanent guards use the K17 security configuration")
	var map := level.get_world_3d().navigation_map
	_expect(host.get_tree().get_nodes_in_group("hiding_spots").size()==7,"Seven cover locations")
	for spot in host.get_tree().get_nodes_in_group("hiding_spots"):
		var floor_pos: Vector3 = spot.global_position-Vector3(0,.7,0)
		var path := NavigationServer3D.map_get_path(map,L.SPAWN,floor_pos,true)
		_expect(not path.is_empty() and path[-1].distance_to(floor_pos)<.9,"Walkable cover: "+str(spot.name))
	for route in L.REINFORCEMENT_ROUTES:
		for point in route:
			var path:=NavigationServer3D.map_get_path(map,L.SPAWN,point,true)
			_expect(not path.is_empty() and path[-1].distance_to(point)<.9,"Dispatch waypoint is truly reachable: "+str(point))
	var spot := level.get_node("Gameplay/HidingSpots/RadioBay") as HidingSpot
	player.global_position=spot.global_position-Vector3(0,.7,0)
	player.is_crouching=true
	await _frames(5)
	_expect(spot.is_concealing(),"Unseen crouched entry conceals")
	var guard := level.get_node("Guards/Guard3") as Guard
	guard.global_position=player.global_position+Vector3(0,0,-4)
	_expect(spot.conceals_from(guard),"Physical radio partition blocks a guard behind it")
	guard.global_position=player.global_position+Vector3(-2.5,0,0)
	_expect(not spot.conceals_from(guard),"Entering a marked area never hides an open side from a guard")
	guard.global_position=player.global_position+Vector3(1,0,0)
	_expect(not spot.conceals_from(guard),"Guard checking nearby finds the player")
	spot.entered_unseen=false
	_expect(not spot.is_concealing(),"Seen entry does not grant concealment")
	spot.entered_unseen=true
	player.is_crouching=false
	_expect(not spot.is_concealing(),"Standing in cover is not concealed")
	var alarm := level.get_node("Gameplay/Security/Alarm") as SecurityAlarm
	var mission := level.get_node("Gameplay/Mission") as K17MissionController
	_expect(not alarm.is_active(),"No persistent alert before file")
	mission.has_file=true
	_expect(alarm.is_active() and guard.is_alarm_attentive(),"Exfiltration keeps guards attentive without recurring position reports")
	var noises := NoiseSystem.find(level).emitted_count
	alarm._process(30)
	_expect(alarm.is_active() and NoiseSystem.find(level).emitted_count==noises,"Persistent alert emits no omniscient noise")
	mission.has_file=false
	_expect(not alarm.is_active(),"Pre-file restore ends persistent alert")
	await _directional_cover(player)
	await _power_and_camera(player,mission)
	await _knowledge_and_inventory(player)
	await _hud_layout(player)
	level.queue_free()
	await _frames(40)
	print("K17 V4 CHECKS: %d checks; %d failures"%[checks,failures.size()])
	return failures

func _directional_cover(player: FirstPersonPlayer) -> void:
	for camera in host.get_tree().get_nodes_in_group("security_cameras"): camera.set_physics_process(false)
	var guard:=level.get_node("Guards/Guard3") as Guard
	var saved:=guard.transform
	var exposed:=0
	for spot in host.get_tree().get_nodes_in_group("hiding_spots"):
		player.global_position=spot.global_position-Vector3(0,.65,0)
		player.set_crouching(true)
		await _frames(4)
		spot.entered_unseen=true
		_expect(spot.contains_player() and spot.is_concealing(),"Cover centre is inside a physical recess: "+str(spot.name))
		for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK,Vector3(1,0,1).normalized(),Vector3(-1,0,1).normalized()]:
			guard.global_position=player.global_position+direction*4
			guard.rotation.y=atan2(direction.x,direction.z)
			await _frames(2)
			guard.vision.reset()
			guard.vision._physics_process(.2)
			if guard.vision._check_sight():
				exposed+=1
				_expect(guard.vision.can_see_target and not spot.conceals_from(guard),"Open view still detects player inside cover: "+str(spot.name)+" / "+str(direction))
	_expect(exposed>0,"At least one real open-side sight line exercised")
	var radio:=level.get_node("Gameplay/HidingSpots/RadioBay") as HidingSpot
	player.global_position=V4.HIDING.RadioBay+Vector3(0,.05,0)
	await _frames(4)
	radio.entered_unseen=true
	var camera:=level.get_node("Gameplay/Cameras/Command") as SecurityCamera
	var camera_pose:=camera.transform
	camera.global_position=player.global_position+Vector3(-2.5,2.0,0)
	camera._head.look_at(player.global_position+Vector3(0,.5,0))
	_expect(radio.is_concealing() and camera.can_see(player),"Camera looking through an open side is never blinded by a hiding area")
	var flags:=StealthDirector.find(level).gather_flags(player,[])
	_expect(flags.seen and not flags.hidden,"HUD never says HIDDEN while a powered camera has a clear view")
	camera.transform=camera_pose
	camera._head.rotation_degrees=Vector3(-camera.pitch_degrees,0,0)
	guard.transform=saved
	var radio_position:=radio.global_position
	radio.global_position=Vector3(0,.7,40)
	player.global_position=Vector3(0,.05,40)
	await _frames(4)
	radio.entered_unseen=true
	_expect(not radio.contains_player() and not radio.is_concealing(),"A misplaced hiding area on an open road grants no cover")
	radio.global_position=radio_position
	player.set_crouching(false)

func _power_and_camera(player: FirstPersonPlayer,mission: K17MissionController) -> void:
	var power: PowerNetwork=level.get_node("Gameplay/PowerNetwork")
	power.set_physics_process(false)
	level.get_node("Gameplay/Reinforcements").set_physics_process(false)
	var control: CircuitSwitch=level.get_node("Gameplay/CameraSwitch")
	var cameras:=host.get_tree().get_nodes_in_group("security_cameras")
	_expect(cameras.size()==3 and cameras.all(func(c): return c.is_powered()),"Three cameras start powered")
	for c in cameras: c.set_physics_process(false)
	var camera: SecurityCamera=level.get_node("Gameplay/Cameras/Command")
	player.global_position=Vector3(6.5,0,10)
	await _frames(5)
	camera._physics_process(0)
	_expect(camera.can_see(player),"Camera can see a real exposed target in its cone")
	player.is_crouching=true
	camera._physics_process(.2)
	var crouched_meter:=camera.meter
	camera.meter=0
	player.is_crouching=false
	camera._physics_process(.2)
	_expect(camera.meter>crouched_meter,"Crouching slows camera detection")
	camera.meter=99
	camera._physics_process(.2)
	_expect(camera.alarms==1 and SecurityAlarm.find(level).is_active(),"Camera raises a local alarm, not an instant capture")
	_expect(GameFlow.find(level).state==GameStateMachine.State.PLAYING,"Camera alarm keeps the mission playable")
	player.global_position=Vector3(6.5,0,3)
	await _frames(4)
	_expect(not camera.can_see(player),"Wall between communications rooms blocks the camera")
	_expect(control.interact(player) and not power.is_powered(&"surveillance"),"Actual circuit switch turns cameras off")
	for c in cameras:
		c._physics_process(1)
		_expect(not c.is_powered() and not c.sees_player and c.meter==0,"Unpowered camera resets perception")
	var snapshot:=power.get_checkpoint_state()
	mission.has_file=true
	mission.time_left=105.1
	power._physics_process(0)
	_expect(not power.get("backup_active"),"No backup before T+15")
	var flow:=GameFlow.find(level)
	flow.pause()
	mission.time_left=105
	power._physics_process(1)
	_expect(not power.get("backup_active"),"Pause blocks backup start")
	flow.resume()
	power._physics_process(0)
	_expect(power.get("backup_active") and power.is_powered(&"surveillance"),"T+15 restores power through backup")
	var noises:=NoiseSystem.find(level).emitted_count
	power._physics_process(100)
	_expect(power.get("backup_starts")==1 and NoiseSystem.find(level).emitted_count==noises,"Backup starts exactly once")
	_expect(not control.interact(player) and power.is_powered(&"surveillance"),"Main switch cannot cut backup")
	power.restore_checkpoint_state(snapshot)
	mission.has_file=false
	_expect(not power.get("backup_active") and not power.is_powered(&"surveillance"),"Snapshot restores main OFF and clears backup")
	SecurityAlarm.find(level).clear()
	for c in cameras: c.set_physics_process(false)

func _knowledge_and_inventory(player: FirstPersonPlayer) -> void:
	var objectives:=ObjectiveManager.find(level)
	var inventory:=PlayerInventory.find(level)
	objectives.restore({})
	_expect(objectives.is_graph() and objectives.get_mandatory_ids().size()==7 and objectives.get_optional_ids().size()==3,"Seven mandatory objectives, two preparations and optional sabotage")
	objectives.complete(M.ENTER)
	var note: DocumentPickup=level.get_node("Gameplay/VaultCode")
	_expect(note.interact(player),"Instructions can be read before taking the pass")
	await _frames(4)
	_expect(objectives.is_completed(M.CODE) and objectives.get_state(M.PASS)==ObjectiveManager.State.ACTIVE,"Intel-first order is supported")
	var doc_count:=inventory.documents.size()
	note.interact(player)
	_expect(inventory.documents.size()==doc_count,"Reading a document twice never duplicates knowledge")
	_expect(level.get_node("Gameplay/AccessPass").interact(player) and inventory.has(ItemCatalog.STAFF_CARD),"Pass also becomes a carried item")
	_expect(level.get_node("Gameplay/ArchiveDoor").interact(player),"Carried pass opens archive door")
	var keypad: CodeLock=level.get_node("Gameplay/VaultKeypad")
	keypad.set_entry(V4.VAULT_CODE)
	keypad.submit()
	_expect(not keypad.is_solved,"Known code cannot bypass checkpoint prerequisite")
	player.global_position=L.PREP
	await _frames(5)
	_expect(objectives.is_completed(M.ARCHIVE),"Reaching the real checkpoint unlocks the code step")
	_expect(not level.get_node("Gameplay/VaultDoor").interact(player),"Manual door interaction cannot bypass keypad")
	keypad.set_entry("0000")
	for i in 3: keypad.submit()
	_expect(keypad.wrong_attempts==3 and keypad.lockout_left==20 and SecurityAlarm.find(level).is_active(),"Three wrong codes give a temporary lock and local alarm")
	var flow:=GameFlow.find(level)
	flow.pause()
	await _frames(20)
	_expect(keypad.lockout_left==20,"Pause freezes keypad lockout")
	flow.resume()
	keypad._process(20)
	_expect(keypad.attempts_left==3 and keypad.lockout_left==0,"Lockout ends with fresh attempts")
	keypad.set_entry(V4.VAULT_CODE)
	keypad.submit()
	await _frames(4)
	_expect(keypad.is_solved and objectives.is_completed(M.VAULT) and level.get_node("Gameplay/VaultDoor").is_open,"Correct code opens the physical door and advances mission")
	var cp:=CheckpointManager.find(level)
	_expect(cp.saved_progress.get(M.VAULT)==ObjectiveManager.State.COMPLETED,"Standing at checkpoint records the solved vault")
	var bottle0: ItemPickup=level.get_node("Gameplay/Bottle0")
	var bottle1: ItemPickup=level.get_node("Gameplay/Bottle1")
	_expect(bottle0.interact(player) and bottle1.interact(player) and inventory.is_full(),"Three slots fit the pass and both bottles")
	var carried:=inventory.get_checkpoint_state()
	player.global_position=Vector3(-25,.05,33)
	player.rotation=Vector3.ZERO
	player.get_node("Head").rotation=Vector3.ZERO
	player.camera.look_at(Vector3(-25,.05,24))
	await _frames(4)
	inventory.select(1)
	var noises:=NoiseSystem.find(level).emitted_count
	_expect(inventory.throw_selected(),"Aiming at a valid floor throws one real distraction")
	await _frames(40)
	_expect(inventory.count()==2 and inventory.has(ItemCatalog.STAFF_CARD) and NoiseSystem.find(level).emitted_count>noises,"Successful throw consumes exactly one bottle and makes landing noise")
	inventory.select(2)
	player.camera.look_at(player.camera.global_position+Vector3(.1,10,0))
	_expect(not inventory.throw_selected() and inventory.count()==2,"Invalid throw consumes nothing")
	inventory.restore_checkpoint_state(carried)
	_expect(inventory.is_full(),"Inventory snapshot restores exactly three carried items")
	var docs_before:=inventory.documents.size()
	cp.restore_checkpoint()
	await _frames(5)
	for g in level.get_node("Guards").get_children(): g.process_mode=Node.PROCESS_MODE_DISABLED
	_expect(inventory.documents.size()==docs_before,"Checkpoint keeps knowledge")
	_expect(not bottle0.taken and not bottle1.taken and inventory.count()==1,"Pickup and inventory restore together without duplicating bottles")
	objectives.restore({})
	objectives.complete(M.ENTER)
	await _frames(5)
	_expect(objectives.is_completed(M.CODE),"Remembered instructions cannot become a restore softlock")
	level.get_node("ObjectiveHud").close_journal()

func _hud_layout(player: FirstPersonPlayer) -> void:
	var hud:=level.get_node("ObjectiveHud") as ObjectiveHud
	for note in host.get_tree().get_nodes_in_group("documents"): note.interact(player)
	hud.close_journal()
	var window:=host.get_window()
	var original_size:=window.size
	var original_scale:=GameSettings.hud_scale
	for size in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(1920,1080)]:
		window.size=size
		for scale_ in [1.0,1.25]:
			GameSettings.hud_scale=scale_
			GameSettings.apply(host.get_tree())
			for i in 4: await host.get_tree().process_frame
			var view:=hud.get_viewport().get_visible_rect().grow(1)
			var controls:=hud.get_layout_controls()
			_expect(view.encloses(controls.objectives.get_global_rect()) and view.encloses(controls.status.get_global_rect()) and view.encloses(controls.slots.get_global_rect()),"K17 panels stay on screen: %s / %s"%[size,scale_])
			_expect(not controls.objectives.get_global_rect().intersects(controls.status.get_global_rect()),"Mission/status panels do not overlap")
			hud.open_journal(&"")
			for i in 4: await host.get_tree().process_frame
			_expect(not controls.status.visible and view.encloses(controls.journal.get_global_rect()),"Journal replaces status and fits")
			var pages:=""
			for i in 8:
				if not hud.is_journal_open(): break
				pages+=hud.get_journal_text()
				hud.next_journal_page()
				await host.get_tree().process_frame
			_expect(PlayerInventory.find(level).documents.all(func(d): return d.title in pages),"Every K17 document is reachable with J")
			hud.close_journal()
	window.size=original_size
	GameSettings.hud_scale=original_scale
	GameSettings.apply(host.get_tree())

func _frames(count: int) -> void:
	for i in count: await host.get_tree().physics_frame

func _expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append("[K17 V4] "+message)
