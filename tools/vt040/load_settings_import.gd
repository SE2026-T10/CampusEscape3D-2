extends SceneTree

const Importer := preload("res://features/settings_import/settings_batch_import.gd")
const CLIENTS := 120
const WAVES := 5
const ROWS := 100


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var work := OS.get_temp_dir().path_join("vt040-load-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	if DirAccess.make_dir_absolute(work) != OK:
		printerr("Could not create experiment directory")
		quit(2)
		return
	var results: Array[float] = []
	var failures := 0
	for wave in range(WAVES):
		var rows := _batch(wave)
		var encoded := JSON.stringify(rows)
		var gate := Semaphore.new()
		var ready := Semaphore.new()
		var threads: Array[Thread] = []
		for index in range(CLIENTS):
			var name := "%d-%d" % [wave, index]
			var source := work.path_join(name + ".json")
			var target := work.path_join(name + ".cfg")
			var input := FileAccess.open(source, FileAccess.WRITE)
			var previous := FileAccess.open(target, FileAccess.WRITE)
			if input == null or previous == null:
				failures += 1
				break
			var input_ok := input.store_string(encoded)
			var previous_ok := previous.store_string("[settings]\nmaster_volume=0.4\n")
			input.close()
			previous.close()
			if not input_ok or not previous_ok:
				failures += 1
				break
			var thread := Thread.new()
			if thread.start(_job.bind(source, target, gate, ready)) != OK:
				failures += 1
				break
			threads.append(thread)
		for _thread in threads:
			ready.wait()
		var start := Time.get_ticks_usec()
		gate.post(threads.size())
		var sample: Array[float] = []
		for thread in threads:
			var result: Dictionary = thread.wait_to_finish()
			if result.ok:
				sample.append(float(result.finished - start) / 1000.0)
			else:
				failures += 1
		results.append_array(sample)
		print("wave=%d submitted=%d verified=%d rows=%d p95_ms=%.3f" %
			[wave + 1, threads.size(), sample.size(), ROWS, _p95(sample)])
	for file in DirAccess.get_files_at(work):
		DirAccess.remove_absolute(work.path_join(file))
	DirAccess.remove_absolute(work)
	var p95 := _p95(results)
	print("VT-040 load: waves=%d concurrency=%d n=%d failures=%d p95_ms=%.3f target_ms=3500" %
		[WAVES, CLIENTS, results.size(), failures, p95])
	quit(0 if failures == 0 and results.size() == CLIENTS * WAVES and p95 <= 3500.0 else 1)


func _batch(wave: int) -> Array:
	var rows := [
		{"key": "hud_scale", "value": 1.25},
		{"key": "captions", "value": false},
	]
	for index in range(ROWS - 2):
		rows.insert((index * 11 + wave * 3) % (rows.size() + 1), {"key": "master_volume", "value": 2})
	return rows


func _job(source: String, target: String, gate: Semaphore, ready: Semaphore) -> Dictionary:
	ready.post()
	gate.wait()
	var result := Importer.import_file(source, target)
	var finished := Time.get_ticks_usec()
	var actual := ConfigFile.new()
	var ok: bool = result.status == "partial_success" and result.saved == 2 \
		and result.rejected.size() == ROWS - 2 and actual.load(target) == OK \
		and actual.get_value("settings", "hud_scale", 0.0) == 1.25 \
		and actual.get_value("settings", "captions", true) == false \
		and is_equal_approx(actual.get_value("settings", "master_volume", 0.0), 0.4)
	return {"ok": ok, "finished": finished}


func _p95(sample: Array[float]) -> float:
	if sample.is_empty():
		return -1.0
	var ordered := sample.duplicate()
	ordered.sort()
	return ordered[ceili(0.95 * ordered.size()) - 1]
