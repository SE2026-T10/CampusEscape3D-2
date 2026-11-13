extends SceneTree

## T15: concurrent caller tasks at an in-process queue, with serial Godot node access.
## Run with -- --out=/absolute/path/latency.csv (parent directory must exist).
const MUSEUM := "res://maps/isg_museum/scenes/museum.tscn"
const TestUtils := preload("res://tests/test_utils.gd")
const UNIQUE_REQUESTS := 50
const TASKS := UNIQUE_REQUESTS * 2
const MEASURED_BURSTS := 10
const PER_FRAME := 10
const TIMEOUT_USEC := 10_000_000
const TARGET_USEC := 3_000_000
const WRONG_CODE := "0000"
const NEAR_STORAGE := Vector3(25.5, 0, 21)
const ISOLATED_GROUPS := [&"player", &"game_flow", &"staff_calendar", &"museum_contract", &"noise_system"]

class Task extends RefCounted:
	signal admitted_for_service
	var position: int
	var request_number: int
	var retry: bool
	var scope: int
	var submitted_usec: int
	var service_start_usec: int
	var finished_usec: int
	var receipt: Dictionary = {}
	var timed_out := false

var _failures: Array[String] = []
var _pending: Array[Task] = []
var _outstanding := 0
var _peak := 0
var _csv: FileAccess


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			path = argument.trim_prefix("--out=")
	if path.is_empty():
		printerr("Required: -- --out=/absolute/path/latency.csv")
		quit(2)
		return
	_csv = FileAccess.open(path, FileAccess.WRITE)
	if _csv == null:
		printerr("Cannot open latency CSV: ", error_string(FileAccess.get_open_error()))
		quit(2)
		return
	_csv.store_csv_line(PackedStringArray(["burst", "phase", "arrival", "request_id", "kind",
		"submitted_usec", "service_start_usec", "finished_usec", "queue_usec", "service_usec",
		"latency_usec", "status", "alarm_triggered", "wrong_attempts_after", "alarm_count_after", "error"]))
	# Set a reproducible engine frame cap. The harness budget is per frame, not per CPU thread.
	Engine.max_fps = 60
	print("T15 environment: Godot=%s OS=%s version=%s CPU=%s logical_processors=%d physical_memory_bytes=%s max_fps=%d" % [
		Engine.get_version_info().string, OS.get_name(), OS.get_version(), OS.get_processor_name(),
		OS.get_processor_count(), str(OS.get_memory_info().get("physical", "unknown")), Engine.max_fps])
	print("T15 config: outstanding=%d, 50 new + 50 retries, 10/frame, one warm-up + %d measured, timeout_usec=%d" % [
		TASKS, MEASURED_BURSTS, TIMEOUT_USEC])
	print("T15 order: new 1..25, retries 1..25, new 26..50, retries 26..50; no shuffle")
	print("T15 clock: Time.get_ticks_usec(); submit to receipt; p95 nearest-rank ceil(0.95*n)")
	var aggregate: Array[int] = []
	for burst in range(MEASURED_BURSTS + 1):
		var samples := await _run_burst(burst)
		if burst > 0:
			aggregate.append_array(samples)
	_csv.flush()
	_csv.close()
	var p95 := _p95(aggregate)
	if aggregate.size() != MEASURED_BURSTS * TASKS or p95 > TARGET_USEC:
		_failures.append("Aggregate sample count/p95 outside contract: %d / %d us" % [aggregate.size(), p95])
	print("T15 aggregate: samples=%d p95_usec=%d target_usec=%d errors=%d" % [
		aggregate.size(), p95, TARGET_USEC, _failures.size()])
	for failure in _failures:
		printerr("FAIL: ", failure)
	# Audio teardown is asynchronous. Use the repo's cleanup after measurement.
	await TestUtils.settle_async_audio(self)
	quit(0 if _failures.is_empty() else 1)


func _run_burst(burst: int) -> Array[int]:
	var samples: Array[int] = []
	for group in ISOLATED_GROUPS:
		if not get_nodes_in_group(group).is_empty():
			_failures.append("Burst %d: previous fixture still owns group %s" % [burst, group])
			return samples
	var scene := load(MUSEUM) as PackedScene
	if scene == null:
		_failures.append("Burst %d: cannot load museum scene" % burst)
		return samples
	var level := scene.instantiate() as Node3D
	level.set("disable_guards_for_editing", true)
	var contract := level.get_node("MuseumContract")
	contract.set("contract_index_override", 0)
	root.add_child(level)
	var actor := level.get_node("Player") as Node3D
	actor.set_physics_process(false)
	actor.get_node("Noise").set_physics_process(false)
	level.get_node("StealthDirector").set_physics_process(false)
	actor.global_position = NEAR_STORAGE
	var door := level.get_node("NavigationRegion3D/Doors/Storage") as Interactable
	var flow := GameFlow.find(door)
	var calendar := get_first_node_in_group("staff_calendar")
	var noise := NoiseSystem.find(door)
	await process_frame
	if calendar == null or flow == null or noise == null:
		_failures.append("Burst %d: missing calendar, game flow or noise" % burst)
		await _cleanup(level)
		return samples
	calendar.set("time_provider", func() -> Dictionary:
		return {"year": 2026, "month": 11, "day": 7, "hour": 12, "minute": 0, "second": 0})
	var counts := {"rejected": 0, "noise": 0}
	door.connect(&"rejected", func(_reason: String) -> void: counts.rejected += 1)
	var source := door.global_position + Vector3.UP
	noise.noise_emitted.connect(func(event: NoiseEvent) -> void:
		if event.type == NoiseEvent.Type.INTERACTION and event.source_group == "environment" and event.position.is_equal_approx(source):
			counts.noise += 1)
	var playable := flow.state == GameStateMachine.State.PLAYING and door.can_interact(actor)
	var nearby := actor.global_position.distance_to(door.global_position) <= 3.0
	var locked: bool = not door.get("unlocked") and not door.get("is_open")
	if not playable or not nearby or not locked or door.call("current_code") != "0711" or _snapshot(door, contract, counts) != [0, 0, 0, 0, 0]:
		_failures.append("Burst %d: expected fresh, playing, locked door with fixed date and nearby player" % burst)
		await _cleanup(level)
		return samples

	_pending.clear()
	_outstanding = 0
	_peak = 0
	# Start 100 independently suspended caller tasks. None may touch the door
	# until its own signal is released by the harness drain.
	for half in 2:
		for retry in [false, true]:
			for index in range(half * 25 + 1, half * 25 + 26):
				var task := Task.new()
				task.position = _pending.size() + 1
				task.request_number = index
				task.retry = retry
				task.scope = door.get_instance_id()
				_submit(task, door, actor)
	if _pending.size() != TASKS or _outstanding != TASKS or _peak != TASKS or _snapshot(door, contract, counts) != [0, 0, 0, 0, 0]:
		_failures.append("Burst %d: gate did not hold exactly 100 caller tasks before side effects" % burst)
	var gate_usec := Time.get_ticks_usec()
	print("T15 gate: burst=%d phase=%s queued=%d outstanding=%d peak=%d pre_release_effects=%s gate_usec=%d" % [
		burst, "warmup" if burst == 0 else "measured", _pending.size(), _outstanding, _peak,
		_snapshot(door, contract, counts), gate_usec])
	var done := 0
	while done < _pending.size():
		await process_frame
		var limit := mini(done + PER_FRAME, _pending.size())
		while done < limit:
			_pending[done].admitted_for_service.emit()
			done += 1

	var phase := "warmup" if burst == 0 else "measured"
	var burst_errors := 0
	for task in _pending:
		var elapsed := task.finished_usec - task.submitted_usec
		var error := ""
		if task.finished_usec == 0:
			error = "missing_completion"
		elif task.timed_out:
			error = "timeout"
		elif task.receipt != _expected(task.request_number):
			error = "receipt_mismatch"
		if not error.is_empty():
			burst_errors += 1
			_failures.append("Burst %d arrival %d: %s actual=%s" % [burst, task.position, error, str(task.receipt)])
		else:
			samples.append(elapsed)
		_csv.store_csv_line(PackedStringArray([str(burst), phase, str(task.position), _request_id(task.request_number),
			"retry" if task.retry else "new", str(task.submitted_usec), str(task.service_start_usec),
			str(task.finished_usec), str(task.service_start_usec - task.submitted_usec),
			str(task.finished_usec - task.service_start_usec), str(elapsed),
			str(task.receipt.get("status", "")), str(task.receipt.get("alarm_triggered", "")),
			str(task.receipt.get("wrong_attempts_after", "")), str(task.receipt.get("alarm_count_after", "")), error]))
	var actual := _snapshot(door, contract, counts)
	if _outstanding != 0 or actual != [2, 16, 16, 50, 50] or door.get("unlocked") or door.get("is_open"):
		_failures.append("Burst %d final effects: expected [2, 16, 16, 50, 50], locked/closed; got %s, outstanding=%d" % [
			burst, actual, _outstanding])
	var p95 := _p95(samples)
	if burst > 0 and (samples.size() != TASKS or p95 > TARGET_USEC):
		_failures.append("Burst %d measured count/p95 outside contract: %d / %d us" % [burst, samples.size(), p95])
	print("T15 burst: burst=%d phase=%s samples=%d p95_usec=%d errors=%d final=%s outstanding=%d" % [
		burst, phase, samples.size(), p95, burst_errors, actual, _outstanding])
	_csv.flush()
	_pending.clear()
	await _cleanup(level)
	return samples


func _submit(task: Task, door: Interactable, actor: Node3D) -> void:
	task.submitted_usec = Time.get_ticks_usec()
	_pending.append(task)
	_outstanding += 1
	_peak = maxi(_peak, _outstanding)
	await task.admitted_for_service
	task.service_start_usec = Time.get_ticks_usec()
	if task.service_start_usec - task.submitted_usec < TIMEOUT_USEC:
		task.receipt = door.call("submit_code_request", task.scope,
			_request_id(task.request_number), WRONG_CODE, actor)
	task.finished_usec = Time.get_ticks_usec()
	task.timed_out = task.finished_usec - task.submitted_usec >= TIMEOUT_USEC
	_outstanding -= 1


static func _request_id(number: int) -> String:
	return "load-%02d" % number


static func _expected(number: int) -> Dictionary:
	# The published gameplay rule, not values read back from the implementation:
	# every third distinct wrong code alarms and resets the wrong-attempt counter.
	@warning_ignore("integer_division")
	var alarms: int = number / 3
	return {"status": &"WRONG_CODE", "request_id": _request_id(number), "alarm_triggered": number % 3 == 0,
		"wrong_attempts_after": number % 3, "alarm_count_after": alarms}


static func _snapshot(door: Interactable, contract: Node, counts: Dictionary) -> Array:
	return [door.get("wrong_attempts"), door.get("alarm_count"), contract.get("alarms"), counts.rejected, counts.noise]


static func _p95(samples: Array[int]) -> int:
	if samples.is_empty():
		return -1
	var sorted := samples.duplicate()
	sorted.sort()
	return sorted[ceili(0.95 * sorted.size()) - 1]


func _cleanup(level: Node3D) -> void:
	for sound in level.find_children("*", "AudioStreamPlayer3D", true, false):
		sound.stop()
		sound.stream = null
	level.queue_free()
	await process_frame
