extends RefCounted

## VT-038. T02/T03 keep the original RED side-effect oracle and use the keyed API.
const MUSEUM := "res://maps/isg_museum/scenes/museum.tscn"
const CALENDAR := ^"NavigationRegion3D/Geometry/StaffInterior/MaintenanceBoard"
const NEAR_STORAGE := Vector3(25.5, 0, 21)
const WRONG_CODE := "0000"
const GROUPS := [&"game_flow", &"staff_calendar", &"museum_contract", &"noise_system", &"player"]
const SCENARIOS: Array[String] = ["T02/T03/T11", "T04", "T05-T12/day", "T05-T12/year"]


static func scenario_order(mode := "original", order_seed := 0) -> Array[String]:
	var order: Array[String] = SCENARIOS.duplicate()
	if mode == "reversed":
		order.reverse()
	elif mode == "shuffle":
		var rng := RandomNumberGenerator.new()
		rng.seed = order_seed
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var value: String = order[i]
			order[i] = order[j]
			order[j] = value
	return order


func run(host: Node, mode := "original", order_seed := 0) -> Array[String]:
	var failures: Array[String] = []
	var order := scenario_order(mode, order_seed)
	print("[VT-038 ORDER] mode=%s seed=%d order=%s" % [mode, order_seed, order])
	for scenario in order:
		var scopes: Array[int] = []
		match scenario:
			"T02/T03/T11":
				# One lifecycle scenario: T03 checks T02's old scope on a fresh door.
				await _run_case(host, failures, scopes, "T02", ["req-a", "req-b", "req-c"], [0, 1, 1, 3, 3])
				await _run_case(host, failures, scopes, "T03", ["req-a", "req-a", "req-a"], [1, 0, 0, 1, 1])
			"T04":
				await _run_case(host, failures, scopes, "T04", ["req-a", "req-b", "req-c", "req-d", "req-c"], [1, 1, 1, 4, 4])
			"T05-T12/day":
				await _run_case(host, failures, scopes, scenario, [], [])
			"T05-T12/year":
				await _run_case(host, failures, scopes, scenario, [], [], true)
	_check_empty_groups(host.get_tree(), failures, "teardown")
	return failures


func _check_empty_groups(tree: SceneTree, failures: Array[String], label: String) -> bool:
	for group in GROUPS:
		if not tree.get_nodes_in_group(group).is_empty():
			failures.append("[%s FIXTURE] Existing node in group %s" % [label, group])
			return false
	return true



func _run_case(host: Node, failures: Array[String], scopes: Array[int], test_id: String, ids: Array[String], expected: Array, year_boundary := false) -> void:
	var tree := host.get_tree()
	if not _check_empty_groups(tree, failures, test_id):
		return
	var scene := load(MUSEUM) as PackedScene
	if scene == null:
		failures.append("[%s FIXTURE] Cannot load museum scene" % test_id)
		return
	var level := scene.instantiate() as Node3D
	level.set("disable_guards_for_editing", true)
	var contract := level.get_node("MuseumContract")
	contract.set("contract_index_override", 0)
	var calendar := level.get_node_or_null(CALENDAR)
	if calendar == null:
		failures.append("[%s FIXTURE] Missing calendar node" % test_id)
		level.free()
		return
	var date := {"year": 2026, "month": 12 if year_boundary else 11,
		"day": 31 if year_boundary else 7, "hour": 23, "minute": 59, "second": 59}
	# Set the provider before _ready, which refreshes the calendar.
	calendar.set("time_provider", func() -> Dictionary: return date)
	host.add_child(level)
	var player := level.get_node("Player") as Node3D
	player.set_physics_process(false)
	player.get_node("Noise").set_physics_process(false)
	level.get_node("StealthDirector").set_physics_process(false)
	player.global_position = NEAR_STORAGE
	var door := level.get_node("NavigationRegion3D/Doors/Storage") as Interactable
	var flow := GameFlow.find(door)
	var noise := NoiseSystem.find(door)
	# Child _ready is synchronous; allow queued scene setup to finish before observing effects.
	await tree.process_frame
	if tree.get_first_node_in_group("staff_calendar") != calendar or flow == null or noise == null:
		failures.append("[%s FIXTURE] Missing calendar, flow or noise node" % test_id)
		await _cleanup(level, tree)
		return
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
			or door.call("current_code") != ("3112" if year_boundary else "0711") or initial != [0, 0, 0, 0, 0]:
		failures.append("[%s FIXTURE] Expected playable, nearby, locked door and fresh fixed-date state; counters=%s" % [test_id, initial])
		await _cleanup(level, tree)
		return
	print("[%s] fixture ready: PLAYING, within 3 m, locked, fixed calendar, counters=%s" % [test_id, initial])
	if test_id == "T03" and not scopes.is_empty():
		var stale := {"id": "req-a", "code": WRONG_CODE, "scope": scopes[0]}
		_expect(failures, "T11", _deliver(door, player, stale), _expected_receipt(&"STALE_SCOPE", "req-a"), "reject previous door instance scope")
		_expect(failures, "T11", _snapshot(door, contract, counts), initial, "previous scope had no effect on new door")
	scopes.append(door.get_instance_id())
	if ids.is_empty():
		_check_request_contract(failures, door, player, date, contract, counts, year_boundary)
		await _cleanup(level, tree)
		return
	var request := {"id": ids[0], "code": WRONG_CODE}
	var receipt := _deliver(door, player, request)
	var first := _snapshot(door, contract, counts)
	print("[%s] first delivery receipt=%s counters=%s" % [test_id, receipt, first])
	if not _expect(failures, test_id, first, [1, 0, 0, 1, 1], "first wrong-guess effect"):
		await _cleanup(level, tree)
		return
	_expect(failures, test_id, receipt, _expected_receipt(&"WRONG_CODE", ids[0], false, 1, 0), "first receipt")
	if test_id == "T03":
		var keypad := door.get("keypad") as CanvasLayer
		door.interact(player)
		keypad.call("close_panel")
		_expect(failures, "T11", door.interact(player) and keypad.visible, true, "keypad reopened in the same door instance")
		keypad.call("close_panel")
	var expected_receipts := {
		"req-a": [false, 1, 0], "req-b": [false, 2, 0],
		"req-c": [true, 0, 1], "req-d": [false, 1, 1]}
	for i in range(1, ids.size()):
		request = {"id": ids[i], "code": WRONG_CODE}
		receipt = _deliver(door, player, request)
		var snapshot: Array = expected_receipts[ids[i]]
		_expect(failures, test_id, receipt, _expected_receipt(&"WRONG_CODE", ids[i], snapshot[0], snapshot[1], snapshot[2]), "receipt delivery %d" % (i + 1))
		print("[%s] delivery %d receipt=%s counters=%s" % [test_id, i + 1, receipt, _snapshot(door, contract, counts)])
	var actual := _snapshot(door, contract, counts)
	var fields := "[wrong_attempts, door_alarms, contract_alarms, rejected, keypad_noise]"
	if actual != expected:
		failures.append("[%s] %s expected=%s actual=%s" % [test_id, fields, expected, actual])
	else:
		print("[%s PASS] %s = %s" % [test_id, fields, actual])
	if door.get("unlocked") or door.get("is_open"):
		failures.append("[%s] Door should stay locked and closed" % test_id)
	await _cleanup(level, tree)


func _deliver(door: Interactable, actor: Node3D, request: Dictionary) -> Dictionary:
	return door.call("submit_code_request", request.get("scope", door.get_instance_id()), request.id, request.code, actor)


func _expected_receipt(status: StringName, id: String, alarm := false, attempts: Variant = null, alarms: Variant = null) -> Dictionary:
	return {"status": status, "request_id": id, "alarm_triggered": alarm,
		"wrong_attempts_after": attempts, "alarm_count_after": alarms}


func _expect(failures: Array[String], test_id: String, actual: Variant, expected: Variant, label: String) -> bool:
	if actual == expected:
		print("[%s PASS] %s" % [test_id, label])
		return true
	failures.append("[%s] %s expected=%s actual=%s" % [test_id, label, str(expected), str(actual)])
	return false


func _check_request_contract(failures: Array[String], door: Interactable, player: Node3D, date: Dictionary, contract: Node, counts: Dictionary, year_boundary: bool) -> void:
	var old_position := player.global_position
	var next_code := "0101" if year_boundary else "0811"
	var a := {"id": "req-a", "code": next_code}
	for invalid in [{"id": "", "code": WRONG_CODE}, {"id": 7, "code": WRONG_CODE},
			{"id": "bad key", "code": WRONG_CODE}, {"id": "x".repeat(65), "code": WRONG_CODE},
			{"id": "a", "code": "711"}, {"id": "a", "code": "07A1"}, {"id": "a", "code": 711}]:
		_expect(failures, "T07", _deliver(door, player, invalid).status, &"INVALID_REQUEST", "invalid input")
	_expect(failures, "T11", _deliver(door, player, {"id": "req-a", "code": next_code, "scope": 0}).status, &"STALE_SCOPE", "reject wrong scope")
	_expect(failures, "T11", _deliver(door, door, a).status, &"STALE_SCOPE", "reject actor outside player scope")
	player.global_position = old_position + Vector3(0, 0, 10)
	_expect(failures, "T08", _deliver(door, player, a), _expected_receipt(&"RETRYABLE", "req-a"), "temporary refusal")
	_expect(failures, "T07/T08/T11", _snapshot(door, contract, counts), [0, 0, 0, 0, 0], "refusals did not execute")
	player.global_position = old_position
	_expect(failures, "T08", _deliver(door, player, {"id": "req-a", "code": WRONG_CODE}), _expected_receipt(&"CONFLICT", "req-a"), "payload bound after temporary refusal")
	var nested: Array = []
	door.connect(&"rejected", func(_reason: String) -> void:
		nested.append(_deliver(door, player, a).status)
		nested.append(_deliver(door, player, {"id": "req-a", "code": WRONG_CODE}).status)
		nested.append(_deliver(door, player, {"id": "req-b", "code": WRONG_CODE}).status)
		nested.append(door.call("submit_code", WRONG_CODE, player)), CONNECT_ONE_SHOT)
	var first := _deliver(door, player, a)
	_expect(failures, "T08", first, _expected_receipt(&"WRONG_CODE", "req-a", false, 1, 0), "same payload executes once after refusal")
	_expect(failures, "T09", nested, [&"IN_PROGRESS", &"CONFLICT", &"BUSY", false], "synchronous signal reentry")
	_expect(failures, "T06", _deliver(door, player, {"id": "req-a", "code": WRONG_CODE}).status, &"CONFLICT", "completed ID cannot change payload")
	first.alarm_triggered = true
	date.day = 1 if year_boundary else 8
	date.month = 1 if year_boundary else 11
	date.year = 2027 if year_boundary else 2026
	date.hour = 0
	date.minute = 0
	date.second = 0
	print("[T10 CLOCK] fake rollover=%s" % ("2026-12-31 -> 2027-01-01" if year_boundary else "2026-11-07 -> 2026-11-08"))
	_expect(failures, "T10/T12", _deliver(door, player, a), _expected_receipt(&"WRONG_CODE", "req-a", false, 1, 0), "replay survives date rollover and caller mutation")
	_expect(failures, "T09/T10", _snapshot(door, contract, counts), [1, 0, 0, 1, 1], "only first guess executed")
	var opened := [0]
	door.connect(&"opened", func() -> void: opened[0] += 1)
	var b := {"id": "req-b", "code": next_code}
	_expect(failures, "T05/T10", _deliver(door, player, b), _expected_receipt(&"UNLOCKED", "req-b", false, 0, 0), "fresh ID uses today's code; BUSY did not bind it")
	player.global_position = old_position + Vector3(0, 0, 10)
	_expect(failures, "T05", _deliver(door, player, b), _expected_receipt(&"UNLOCKED", "req-b", false, 0, 0), "replay after unlock and moving away")
	_expect(failures, "T05", _deliver(door, player, {"id": "req-c", "code": next_code}).status, &"ALREADY_UNLOCKED", "fresh request does not toggle unlocked door")
	_expect(failures, "T05", [door.get("unlocked"), door.get("is_open"), opened[0]], [true, true, 1], "door opened exactly once")


func _snapshot(door: Interactable, contract: Node, counts: Dictionary) -> Array:
	return [door.get("wrong_attempts"), door.get("alarm_count"), contract.get("alarms"), counts.rejected, counts.noise]


func _cleanup(level: Node3D, tree: SceneTree) -> void:
	for sound in level.find_children("*", "AudioStreamPlayer3D", true, false):
		sound.stop()
		sound.stream = null
	level.queue_free()
	await tree.process_frame
