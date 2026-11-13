extends RefCounted

## VT-038 test-first. The legacy adapter forwards each delivery to production;
## only the fixture knows the request ID until the keyed API is implemented.
const MUSEUM := "res://maps/isg_museum/scenes/museum.tscn"
const NEAR_STORAGE := Vector3(25.5, 0, 21)
const WRONG_CODE := "0000"


func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	await _run_case(host, failures, "T02", ["req-a", "req-b", "req-c"], [0, 1, 1, 3, 3])
	await _run_case(host, failures, "T03", ["req-a", "req-a", "req-a"], [1, 0, 0, 1, 1])
	return failures


func _run_case(host: Node, failures: Array[String], test_id: String, ids: Array[String], expected: Array) -> void:
	var tree := host.get_tree()
	for group in [&"game_flow", &"staff_calendar", &"museum_contract", &"noise_system"]:
		if not tree.get_nodes_in_group(group).is_empty():
			failures.append("[%s FIXTURE] Existing node in group %s" % [test_id, group])
			return
	var scene := load(MUSEUM) as PackedScene
	if scene == null:
		failures.append("[%s FIXTURE] Cannot load museum scene" % test_id)
		return
	var level := scene.instantiate() as Node3D
	level.set("disable_guards_for_editing", true)
	var contract := level.get_node("MuseumContract")
	contract.set("contract_index_override", 0)
	host.add_child(level)
	var player := level.get_node("Player") as Node3D
	player.set_physics_process(false)
	player.get_node("Noise").set_physics_process(false)
	level.get_node("StealthDirector").set_physics_process(false)
	player.global_position = NEAR_STORAGE
	var door := level.get_node("NavigationRegion3D/Doors/Storage") as Interactable
	var calendar := tree.get_first_node_in_group("staff_calendar")
	var flow := GameFlow.find(door)
	var noise := NoiseSystem.find(door)
	# Child _ready is synchronous; allow queued scene setup to finish before observing effects.
	await tree.process_frame
	if calendar == null or flow == null or noise == null:
		failures.append("[%s FIXTURE] Missing calendar, flow or noise node" % test_id)
		await _cleanup(level, tree)
		return
	calendar.set("time_provider", func() -> Dictionary:
		return {"year": 2026, "month": 11, "day": 7, "hour": 12, "minute": 0, "second": 0})
	var counts := {"rejected": 0, "noise": 0}
	door.connect(&"rejected", func(_reason: String) -> void: counts.rejected += 1)
	var source := door.global_position + Vector3.UP
	noise.noise_emitted.connect(func(event: NoiseEvent) -> void:
		if event.type == NoiseEvent.Type.INTERACTION and event.source_group == "environment" and event.position.is_equal_approx(source):
			counts.noise += 1)
	var initial: Array = _snapshot(door, contract, counts)
	if flow.state != GameStateMachine.State.PLAYING or not door.can_interact(player) \
			or player.global_position.distance_to(door.global_position) > 3.0 \
			or door.get("unlocked") or door.get("is_open") \
			or door.call("current_code") != "0711" or initial != [0, 0, 0, 0, 0]:
		failures.append("[%s FIXTURE] Expected playable, nearby, locked door and fresh fixed-date state; counters=%s" % [test_id, initial])
		await _cleanup(level, tree)
		return
	print("[%s] fixture ready: PLAYING, within 3 m, locked, fixed calendar, counters=%s" % [test_id, initial])
	var request := {"id": ids[0], "code": WRONG_CODE}
	var accepted := _deliver(door, player, request)
	var first := _snapshot(door, contract, counts)
	print("[%s] first delivery id=%s accepted=%s counters=%s" % [test_id, ids[0], accepted, first])
	if accepted or first != [1, 0, 0, 1, 1]:
		failures.append("[%s CONTROL] First wrong guess: expected false and [1, 0, 0, 1, 1], actual %s and %s" % [test_id, accepted, first])
		await _cleanup(level, tree)
		return
	for i in range(1, ids.size()):
		if ids[i] != ids[0]:
			request = {"id": ids[i], "code": WRONG_CODE}
		accepted = _deliver(door, player, request)
		print("[%s] delivery %d id=%s accepted=%s counters=%s" % [test_id, i + 1, ids[i], accepted, _snapshot(door, contract, counts)])
		if accepted:
			failures.append("[%s] Wrong guess must not unlock" % test_id)
	var actual := _snapshot(door, contract, counts)
	var fields := "[wrong_attempts, door_alarms, contract_alarms, rejected, keypad_noise]"
	if actual != expected:
		failures.append("[%s] %s expected=%s actual=%s" % [test_id, fields, expected, actual])
	else:
		print("[%s PASS] %s = %s" % [test_id, fields, actual])
	if door.get("unlocked") or door.get("is_open"):
		failures.append("[%s] Door should stay locked and closed" % test_id)
	await _cleanup(level, tree)


func _deliver(door: Interactable, actor: Node3D, request: Dictionary) -> bool:
	# Pass-through baseline: submit_code has no ID parameter. This adapter does
	# not mutate fixture state or synthesize a structured production receipt.
	return bool(door.call("submit_code", request.code, actor))


func _snapshot(door: Interactable, contract: Node, counts: Dictionary) -> Array:
	return [door.get("wrong_attempts"), door.get("alarm_count"), contract.get("alarms"), counts.rejected, counts.noise]


func _cleanup(level: Node3D, tree: SceneTree) -> void:
	for sound in level.find_children("*", "AudioStreamPlayer3D", true, false):
		sound.stop()
		sound.stream = null
	level.queue_free()
	await tree.process_frame
