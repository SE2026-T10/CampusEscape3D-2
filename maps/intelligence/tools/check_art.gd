extends SceneTree
## Integration checks for shipped art, sight-transparent barriers and shared HUD opt-in.
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	_run.call_deferred()

func _expect(condition: bool,message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _run() -> void:
	var level: Node3D = (load("res://maps/intelligence/scenes/intelligence_k17.tscn") as PackedScene).instantiate()
	root.add_child(level)
	await _frames(30)
	var player := level.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	for guard in level.get_node("Guards").get_children():
		guard.process_mode = Node.PROCESS_MODE_DISABLED
		_expect(guard.get_node("Model/Hips/Torso/Chest").visible == false,"Original library uniform is hidden")
		for path in ["Model/Hips/Torso/MilitaryChest","Model/Hips/Torso/Head/MilitaryFace","Model/Hips/LegL/MilitaryShoe"]:
			_expect(guard.has_node(path),"Military appearance is attached to animated joint: "+path)
	var env := level.get_node("K17Environment")
	_expect(level.get_node("LightmapGI").light_data != null,"Baked lighting is shipped")
	var baked:=level.get_node("LightmapGI").light_data as LightmapGIData
	if baked:
		var moving_paths: Array[String]=[]
		for i in baked.get_user_count():
			var path:=str(baked.get_user_path(i))
			if "/Guards/" in path or "/DoorHinge/" in path or "/CourtyardGate/Leaf/" in path or "/MaintenanceGate/Leaf/" in path:
				moving_paths.append(path)
		_expect(baked.get_user_count()>100,"Lightmap contains the authored compound geometry")
		_expect(moving_paths.is_empty(),"Moving guards and door leaves are excluded from baked shadows: "+str(moving_paths))
	_expect(env.get_node("Roof").mesh != null,"Closed interior roof is present")
	for sign in env.find_children("*","Label3D",true,false):
		_expect(sign.billboard == BaseMaterial3D.BILLBOARD_DISABLED,"Environmental signs are fixed to architecture")
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var sight := PhysicsRayQueryParameters3D.create(Vector3(-8,1.6,44.5),Vector3(-8,1.6,48),3)
	_expect(space.intersect_ray(sight).is_empty(),"Sight ray sees through chainlink")
	var movement := PhysicsRayQueryParameters3D.create(sight.from,sight.to,17)
	var hit: Dictionary = space.intersect_ray(movement)
	_expect(not hit.is_empty() and hit.collider.collision_layer == 16,"Chainlink still blocks actors")
	_expect((player.collision_mask&16) != 0,"K17 player collides with physical fence layer")
	var provider := level.get_node("Gameplay/Mission") as MapHudProvider
	_expect(not provider.show_objective_checklist(),"K17 opts into compact shared objectives")
	var default_provider := MapHudProvider.new()
	_expect(default_provider.show_objective_checklist(),"Other maps keep the original checklist by default")
	default_provider.free()
	var hud := level.get_node("ObjectiveHud") as ObjectiveHud
	_expect(not hud.get("_list").visible,"Compact checklist is actually hidden")
	var door := level.get_node("Gameplay/ArchiveDoor") as AccessDoor
	var leaf := door.get_node("Panel/DoorHinge") as Node3D
	door.open()
	await _frames(50)
	_expect(absf(leaf.rotation_degrees.y-90) < 1.0,"Authored door swings clear when opened")
	door.restore_checkpoint_state({"open":false})
	_expect(absf(leaf.rotation.y) < .01,"Checkpoint shuts the authored door")
	provider.call("_set_alarm_lights",true)
	for light in get_nodes_in_group("k17_alarm_lights"):
		if light.has_meta("alarm_only"): _expect(light.visible,"Alarm lighting is enabled")
	provider.call("_set_alarm_lights",false)
	for light in get_nodes_in_group("k17_alarm_lights"):
		if light.has_meta("alarm_only"): _expect(not light.visible,"Normal lighting has no active red alarm")
	baked=null
	level.queue_free()
	await _frames(30)
	await preload("res://tests/test_utils.gd").settle_async_audio(self)
	for failure in failures: printerr(failure)
	print("K17 ART CHECKS: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func _frames(count: int) -> void:
	for i in count: await physics_frame
