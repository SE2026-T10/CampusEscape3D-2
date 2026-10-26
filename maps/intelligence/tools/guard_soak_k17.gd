extends SceneTree

## Exercise the shipping NPC configuration; player stays at the safe entrance.
const SCENE := "res://maps/intelligence/scenes/intelligence_k17.tscn"
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file(SCENE)
	for i in 45:
		await physics_frame
	var guards := current_scene.get_node("Guards").get_children()
	var counters: Array[Dictionary] = []
	for guard in guards:
		var counter := {"name": guard.name, "reached": 0, "stuck": 0}
		guard.patrol_point_reached.connect(func(_index): counter.reached += 1)
		guard.got_stuck.connect(func(_index): counter.stuck += 1)
		counters.append(counter)
	for i in 5400:
		await physics_frame
	var ok := GameFlow.find(current_scene).state == GameStateMachine.State.PLAYING
	for counter in counters:
		print("  [K17 patrol] ", counter)
		ok = ok and counter.reached >= 4 and counter.stuck == 0
	print("K17 PATROL PASSED (90 seconds, 4 live NPCs)" if ok else "K17 PATROL FAILED")
	current_scene.queue_free()
	for i in 40:
		await process_frame
	quit(0 if ok else 1)
