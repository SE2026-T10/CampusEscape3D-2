extends SceneTree
## Copy outside the project and run from an empty directory with --main-pack.
## Depends only on shipped runtime classes/resources, never tests or build tools.
const BASE:="res://maps/intelligence/"
var failures: Array[String]=[]
func _init() -> void: _run.call_deferred()
func _run() -> void:
	for test_mode in [false,true]:
		change_scene_to_file(BASE+"scenes/"+("intelligence_k17_test.tscn" if test_mode else "intelligence_k17.tscn"))
		await _frames(30)
		var player:=current_scene.get_node("Player") as FirstPersonPlayer
		player.set_physics_process(false)
		player.global_position=Vector3(8,.05,-20)
		player.camera.look_at(Vector3(8,1,-30))
		var mission:=current_scene.get_node("Gameplay/Mission") as K17MissionController
		mission.set_physics_process(false)
		var team:=current_scene.get_node("Gameplay/Reinforcements")
		_expect(current_scene.get_node("NavigationRegion3D/Sectors").get_child_count()==8,"Packed sector instances")
		_expect(current_scene.get_node("LightmapGI").light_data!=null,"Packed full-compound lightmap")
		_expect(current_scene.get_node("Guards").get_child_count()==(0 if test_mode else 6),"Packed initial actor count")
		_expect(current_scene.get_node("Gameplay/IntelligenceFile").position.y< -2,"Packed B1 document")
		for id in [K17MissionController.ENTER,K17MissionController.PASS,K17MissionController.CODE,K17MissionController.ARCHIVE,K17MissionController.FILE]: ObjectiveManager.find(current_scene).complete(id)
		mission.time_left=110
		team._physics_process(0)
		mission.time_left=75
		team._physics_process(0)
		_expect(team.spawned_count==(0 if test_mode else 4),"Packed dispatch honours mode")
		_expect(current_scene.get_node("Guards").get_child_count()==(0 if test_mode else 10),"Packed final actor count")
		for guard in current_scene.get_node("Guards").get_children():
			_expect(guard.has_node("Model/Hips/Torso/MilitaryChest"),"Packed military appearance, including late actors")
		StealthDirector.find(current_scene).reset_level()
		await _frames(10)
		_expect(team.spawned_count==0,"Packed restore clears reinforcements")
		print("[K17 pack] test_mode=",test_mode," sectors=8 dispatch/restore verified")
		current_scene.queue_free()
		await _frames(40)
	for path in ["tools/build_k17.gd","tests/k17_expansion_tests.gd","docs/expansion-v3/VALIDATION.md"]:
		_expect(not FileAccess.file_exists(BASE+path) and not FileAccess.file_exists(BASE+path+".remap"),"Development file excluded: "+path)
	for i in 4:
		OS.delay_msec(50)
		await process_frame
	for failure in failures: printerr(failure)
	print("K17 V3 PACK PASSED" if failures.is_empty() else "K17 V3 PACK FAILED")
	quit(0 if failures.is_empty() else 1)
func _expect(ok: bool,message: String) -> void:
	if not ok: failures.append(message)
func _frames(count: int) -> void:
	for i in count: await physics_frame
