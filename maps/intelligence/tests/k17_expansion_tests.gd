extends RefCounted
const L := preload("res://maps/intelligence/resources/layout/k17_layout.gd")
const Utils := preload("res://tests/test_utils.gd")
const M := preload("res://maps/intelligence/scripts/mission_controller.gd")
var failures: Array[String]=[]
var checks:=0
var host: Node
var level: Node3D

func run(parent: Node) -> Array[String]:
	host=parent
	await _load(false)
	var player:=level.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	for guard in level.get_node("Guards").get_children(): guard.process_mode=Node.PROCESS_MODE_DISABLED
	var mission:=level.get_node("Gameplay/Mission") as K17MissionController
	var team:=level.get_node("Gameplay/Reinforcements")
	team.set_physics_process(false)
	_expect(level.get_node("NavigationRegion3D/Sectors").get_child_count()==8,"Eight authored sectors are present.")
	_expect(L.SIZE==Vector2(96,108),"The compound uses the expanded 96 by 108 metre bounds.")
	_expect(level.get_node("Gameplay/IntelligenceFile").global_position.y< -2,"The real mission document is in B1.")
	var map:=level.get_world_3d().navigation_map
	for point in [Vector3(-36,0,5),Vector3(36,0,7),Vector3(4,-4,-35),Vector3(0,-4,-48.5),Vector3(30,-4,-38),Vector3(30,0,-23),Vector3(17,0,-5),Vector3(17,0,-16)]:
		var path:=NavigationServer3D.map_get_path(map,L.SPAWN,point,true)
		_expect(not path.is_empty() and path[-1].distance_to(point)<1,"Navigation reaches expanded sector/stair "+str(point))
	mission.record_sensor_trip(L.SENSORS[0])
	team._physics_process(0)
	_expect(team.spawned_count==0 and not mission.has_file,"A local sensor alarm cannot dispatch reinforcements before pickup.")
	var objectives:=ObjectiveManager.find(level)
	for id in [M.ENTER,M.PASS,M.CODE]: objectives.complete(id)
	player.global_position=L.PREP
	player.camera.look_at(Vector3(8,1.6,-30))
	await _frames(5)
	_expect(CheckpointManager.find(level).active==level.get_node("Gameplay/ArchiveCheckpoint"),"The final safe checkpoint is active before dispatch.")
	objectives.complete(M.VAULT)
	objectives.complete(M.FILE)
	mission.time_left=111
	team._physics_process(0)
	_expect(team.spawned_count==0,"No reinforcements arrive before T+10.")
	mission.time_left=110
	team._physics_process(0)
	_expect(team.spawned_count==2 and level.get_node("Guards").get_child_count()==8,"First dispatch adds two physical guards at T+10.")
	team._physics_process(0)
	_expect(team.spawned_count==2,"Repeated processing cannot duplicate a wave.")
	var flow:=GameFlow.find(level)
	flow.pause()
	mission.time_left=75
	team._physics_process(30)
	_expect(team.spawned_count==2,"Pause prevents the second dispatch.")
	flow.resume()
	team._physics_process(0)
	_expect(team.spawned_count==4 and level.get_node("Guards").get_child_count()==10,"Second dispatch adds two more guards at T+45.")
	for guard in level.get_node("Guards").get_children():
		if not str(guard.name).begins_with("Reinforcement"): continue
		_expect(guard.has_meta("military_applied") and guard.has_node("Model/Hips/Torso/MilitaryChest"),"Late-spawned guards receive the military appearance.")
		_expect(not guard.checkpoint_snapshot,"Transient guards do not enter permanent guard snapshots.")
		_expect(guard.global_position.distance_to(player.global_position)>12,"Dispatch originates away from the player.")
		guard.process_mode=Node.PROCESS_MODE_DISABLED
	for i in 5: team._physics_process(100)
	_expect(team.spawned_count==4,"Dispatch has a hard four-guard cap.")
	mission.time_left=.01
	mission._physics_process(.02)
	_expect(flow.state==GameStateMachine.State.FAILED,"The normal mission deadline still ends a reinforced run.")
	_expect(flow.retry_checkpoint(),"The reinforced run retries the real checkpoint.")
	await _frames(6)
	_expect(team.spawned_count==0 and level.get_node("Guards").get_child_count()==6,"Retry removes all four transient guards.")
	_expect(not mission.has_file and team.waves==[false,false],"Retry re-arms dispatch only for a new file pickup.")
	_expect(team.get_child_count()==0,"Retry releases temporary patrol routes as well as actors.")
	# A blocked visible/near entry is deferred, never moved onto the player.
	player.global_position=L.REINFORCEMENT_ROUTES[0][0]
	_expect(not team._safe_position(player.global_position),"A dispatch point occupied by the player is refused.")
	await _unload()
	await _load(true)
	mission=level.get_node("Gameplay/Mission")
	team=level.get_node("Gameplay/Reinforcements")
	for id in [M.ENTER,M.PASS,M.CODE,M.ARCHIVE,M.VAULT,M.FILE]: ObjectiveManager.find(level).complete(id)
	mission.time_left=60
	team._physics_process(100)
	await _frames(5)
	_expect(team.spawned_count==0 and host.get_tree().get_nodes_in_group("guards").is_empty(),"The no-guard mode suppresses both waves after pickup.")
	await _unload()
	print("K17 EXPANSION CHECKS: %d checks; %d failures"%[checks,failures.size()])
	return failures

func _load(test: bool) -> void:
	level=(load("res://maps/intelligence/scenes/intelligence_k17_test.tscn" if test else "res://maps/intelligence/scenes/intelligence_k17.tscn") as PackedScene).instantiate()
	_expect(await Utils.add_level_and_wait_for_navigation(host,level,L.SPAWN),"Expanded navigation becomes ready.")
	await _frames(4)

func _unload() -> void:
	host.get_tree().paused=false
	level.queue_free()
	await _frames(40)
	_expect(host.get_tree().get_nodes_in_group("guards").is_empty(),"Leaving frees permanent and transient guards.")

func _frames(count: int) -> void:
	for i in count: await host.get_tree().physics_frame

func _expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append("[K17 expansion] "+message)
