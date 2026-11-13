extends SceneTree

const StorageSubmissionTests := preload("res://maps/isg_museum/tests/storage_submission_tests.gd")
const SHUFFLE_SEEDS := [17, 38, 73, 103, 903]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args != PackedStringArray(["--flaky"]):
		printerr("Usage: run_storage_submission_tests.gd [-- --flaky]")
		quit(2)
		return
	var host := Node.new()
	root.add_child(host)
	var suite := StorageSubmissionTests.new()
	var failures: Array[String] = []
	if args.is_empty():
		failures = await suite.run(host)
	else:
		var trial := 0
		for mode in ["original", "reversed", "shuffle"]:
			for order_seed in (SHUFFLE_SEEDS if mode == "shuffle" else [0, 0, 0, 0, 0]):
				trial += 1
				print("[FLAKY TRIAL %02d START]" % trial)
				var result := await suite.run(host, mode, order_seed)
				print("[FLAKY TRIAL %02d END] failures=%d" % [trial, result.size()])
				for failure in result:
					failures.append("trial %02d: %s" % [trial, failure])
	for failure in failures:
		printerr("FAIL: ", failure)
	print("VT-038 storage submission failures: ", failures.size())
	host.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
