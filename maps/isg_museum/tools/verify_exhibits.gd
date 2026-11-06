extends SceneTree
var level: Node3D
var player: FirstPersonPlayer
var checks := 0
var failures := 0

func _initialize():
	run.call_deferred()
func check(ok: bool, title: String):
	checks += 1
	if ok: print("PASS: ",title)
	else:
		failures += 1
		push_error(title)
func frames(count: int):
	for i in count: await physics_frame
func e(down: bool):
	if down: Input.action_press("interact")
	else: Input.action_release("interact")
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = down
	Input.parse_input_event(event)
	await process_frame
	await frames(3)
func aim(target: Node3D, feet: Vector3):
	player.position = feet
	player.velocity = Vector3.ZERO
	player.camera.look_at(target.global_position)
	await frames(5)
func run():
	level = load("res://maps/isg_museum/scenes/museum.tscn").instantiate()
	if not level.has_node("NavigationRegion3D/ExhibitsExpansion"):
		level.get_node("NavigationRegion3D").add_child(load("res://maps/isg_museum/scenes/exhibits_expansion.tscn").instantiate())
	root.add_child(level)
	current_scene = level
	player = level.get_node("Player")
	player.set_physics_process(false)
	player.get_node("Noise").set_physics_process(false)
	level.get_node("StealthDirector").set_physics_process(false)
	for guard: Guard in get_nodes_in_group("guards"):
		guard.set_physics_process(false)
		guard.vision.set_physics_process(false)
		guard.vision.reset()
		guard.hearing.set_physics_process(false)
		guard.agent.avoidance_enabled = false
		guard.get_node("Presentation").process_mode = Node.PROCESS_MODE_DISABLED
	await frames(20)
	var exhibits = level.get_node("NavigationRegion3D/ExhibitsExpansion")
	var manager: ObjectiveManager = level.get_node("ObjectiveManager")
	var watcher: Guard = level.get_node("Guard_G1")
	watcher.position = Vector3(7,0,11.5)
	watcher.hearing.set_physics_process(true)
	for sample in [["S1",Vector3(6.3,0,11.5),&"take_s1"],["S2",Vector3(6.3,0,18),&"take_s2"]]:
		var item = exhibits.get_node(sample[0])
		await aim(item,sample[1])
		check(player.get_node("Interactor").find_target() == item,"Camera selects "+sample[0]+" glass case")
		var noises: int = level.get_node("NoiseSystem").emitted_count
		await e(true)
		await e(false)
		check(item.broken and not item.get_node("Glass").visible and item.get_node("Shards").visible,"First E breaks glass and leaves shards: "+sample[0])
		check(not manager.is_completed(sample[2]) and item.get_node("Artifact").visible,"Breaking alone never grants sculpture: "+sample[0])
		check(level.get_node("NoiseSystem").emitted_count > noises,"Glass breaking emits real world noise: "+sample[0])
		await e(true)
		await e(false)
		check(manager.is_completed(sample[2]) and not item.get_node("Artifact").visible and item.get_node("Shards").visible,"Separate E collects sculpture and keeps broken display: "+sample[0])
		check(not item.interact(player),"Cannot collect sculpture twice: "+sample[0])
	check(watcher.hearing.reported_count > 0,"Nearby actual guard hearing receives glass break noise")
	for sample in [["H1",Vector3(10.5,0,4.25),&"take_h1"],["H2",Vector3(22,0,4.25),&"take_h2"]]:
		var item = exhibits.get_node(sample[0])
		await aim(item,sample[1])
		check(player.get_node("Interactor").find_target() == item,"Camera selects historical drawer: "+sample[0])
		await e(true)
		await frames(45)
		await e(false)
		var saved: float = item.open_progress
		await frames(40)
		check(saved > .4 and saved < 2 and is_equal_approx(saved,item.open_progress) and not item.is_open,"Releasing pauses partial opening: "+sample[0])
		await e(true)
		await frames(200)
		check(item.is_open and not manager.is_completed(sample[2]),"Holding opens drawer without auto collecting: "+sample[0])
		await e(false)
		await e(true)
		await e(false)
		check(manager.is_completed(sample[2]) and item.collected and not item.get_node("Artifact").visible,"Second press collects historical item: "+sample[0])
	for sample in [["A2",Vector3(1.7,4.5,18),&"take_a2"],["B2",Vector3(34.1,4.5,15),&"take_b2"],["C2",Vector3(10,4.5,1.7),&"take_c2"]]:
		var item = exhibits.get_node(sample[0])
		await aim(item,sample[1])
		check(player.get_node("Interactor").find_target() == item,"Camera selects extra painting: "+sample[0])
		await e(true)
		await e(false)
		if sample[0] == "B2":
			check(manager.is_completed(sample[2]) and not item.visible,"Rolled B2 is an ordinary small pickup")
		else:
			check(manager.is_completed(sample[2]) and item.is_missing and not item.get_node("Canvas").visible and item.get_node("Frame").visible,"Extra painting leaves frame: "+sample[0])
	var alarm = exhibits.get_node("GalleryAlarmSwitch")
	check(alarm.alarm_count == 1,"Root forwards protected C2 pickup to enabled C alarm")
	alarm.artwork_taken(&"take_c2")
	check(alarm.alarm_count == 1,"Same artwork cannot generate duplicate alarm")
	alarm.disable_alarm()
	manager.complete(&"take_t3")
	check(not alarm.alarm_enabled and alarm.alarm_count == 1,"Disabling C alarm prevents later protected-artwork alarm")
	check(alarm._reported.has(&"take_t3"),"Root forwards existing T3 objective completion to C alarm exactly once")
	await aim(alarm,Vector3(25.7,4.5,4.2))
	check(player.get_node("Interactor").find_target() == alarm,"Actual camera can select C alarm switch")
	print("Exhibit focused verification: %d checks, %d failures"%[checks,failures])
	for sound in level.find_children("*","AudioStreamPlayer3D",true,false):
		sound.stop()
		sound.stream = null
	current_scene = null
	level.free()
	await process_frame
	quit(0 if failures == 0 else 1)
