extends RefCounted

## QA contract shared by map selection tests and the real scene-flow runner.
## Museum's optional systems do not relax the existing library/K17 contracts.
static func is_museum(scene: Node) -> bool:
	return scene!=null and scene.scene_file_path in [LevelCatalog.scene_of(LevelCatalog.MUSEUM),LevelCatalog.test_scene_of(LevelCatalog.MUSEUM)]

static func owned_system(scene: Node, group: StringName) -> Node:
	if scene==null or not scene.is_inside_tree(): return null
	for node in scene.get_tree().get_nodes_in_group(group):
		if node==scene or scene.is_ancestor_of(node): return node
	return null

static func objectives(scene: Node) -> ObjectiveManager:
	return owned_system(scene,&"objective_manager") as ObjectiveManager

static func expected_systems(scene: Node, group: String) -> int:
	var museum := is_museum(scene)
	var has_mission := museum or (scene!=null and scene.has_node("Gameplay/ObjectiveManager"))
	if group=="audio_director": return 0 if museum else 1
	if group=="checkpoint_manager": return 1 if has_mission and not museum else 0
	if group=="objective_manager": return 1 if has_mission else 0
	return 1

static func count_callback(event: Signal, target: Object, method: StringName) -> int:
	var count := 0
	for entry in event.get_connections():
		var callback: Callable = entry.callable
		if callback.get_object()==target and callback.get_method()==method: count += 1
	return count

static func required_callbacks(scene: Node) -> Dictionary:
	var director := owned_system(scene,&"stealth_director") as StealthDirector
	var flow := owned_system(scene,&"game_flow") as GameFlow
	if director==null or flow==null: return {"missing_flow_or_director":0}
	var result := {"GameFlow.player_caught":count_callback(director.player_caught,flow,&"_on_player_caught"),
		"GameFlow.level_reset":count_callback(director.level_reset,flow,&"_on_level_reset")}
	var manager := objectives(scene)
	if expected_systems(scene,"objective_manager")==1:
		result["GameFlow.level_completed"] = count_callback(manager.level_completed,flow,&"_on_level_completed") if manager else 0
	if is_museum(scene):
		var contract := owned_system(scene,&"museum_contract")
		result["MuseumContract.player_caught"] = count_callback(director.player_caught,contract,&"_caught") if contract else 0
		result["MuseumDemo.level_reset"] = count_callback(director.level_reset,scene,&"_restart_demo")
	else:
		var checkpoint := owned_system(scene,&"checkpoint_manager")
		if expected_systems(scene,"checkpoint_manager")==1:
			result["CheckpointManager.level_reset"] = count_callback(director.level_reset,checkpoint,&"restore_checkpoint") if checkpoint else 0
	return result
