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
	var equipment := level.get_node("Gameplay/Sabotage")
	var equipment_meshes := equipment.find_children("*","MeshInstance3D",true,false)
	_expect(equipment_meshes.all(func(mesh): return mesh.gi_mode==GeometryInstance3D.GI_MODE_DYNAMIC),"Replaceable sabotage meshes never bake intact shadows into the room")
	_expect(equipment_meshes.size()<25,"Equipment is batched independently per visual state")
	_expect(equipment.get_node("Intact").visible and not equipment.get_node("Damaged").visible,"Fresh map shows intact equipment only")
	_expect(level.get_node("LightmapGI").light_data != null,"Baked lighting is shipped")
	var baked:=level.get_node("LightmapGI").light_data as LightmapGIData
	if baked:
		var moving_paths: Array[String]=[]
		for i in baked.get_user_count():
			var path:=str(baked.get_user_path(i))
			if "/Guards/" in path or "/DoorHinge/" in path or "/Cameras/" in path or "/VaultKeypad/" in path or "/CourtyardGate/Leaf/" in path or "/MaintenanceGate/Leaf/" in path or "/Sabotage/" in path:
				moving_paths.append(path)
		_expect(baked.get_user_count()>100,"Lightmap contains the authored compound geometry")
		_expect(moving_paths.is_empty(),"Moving guards and door leaves are excluded from baked shadows: "+str(moving_paths))
		var missing: Array[String]=[]
		for i in baked.get_user_count():
			var path:=baked.get_user_path(i)
			if level.get_node("LightmapGI").get_node_or_null(path)==null: missing.append(str(path))
		_expect(missing.is_empty(),"Every baked mesh still exists in the shipped scene: "+str(missing))
	for camera in get_nodes_in_group("security_cameras"):
		_expect(not camera._cone.visible,"K17 camera keeps perception without a floating translucent cone")
		_expect(camera.get_children().filter(func(child): return child is Label3D and child.visible).is_empty(),"Camera labels are physical equipment signs, not floating billboards")
	var sectors:=level.get_node("NavigationRegion3D/Sectors")
	_expect(sectors.get_node("command").has_node("CameraCeilingPlate") and sectors.get_node("records").has_node("CameraCeilingPlate"),"Both indoor cameras have ceiling support")
	_expect(sectors.get_node("service_route").has_node("CameraMast") and sectors.get_node("service_route").has_node("CameraMastBase"),"Outdoor camera has a grounded mast and base")
	_expect(not sectors.get_node("guard_post/PassDesk/Mesh").visible and not sectors.get_node("secure_vault/FileDesk/Mesh").visible,"Detailed desks are not hidden under solid placeholder cubes")
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
