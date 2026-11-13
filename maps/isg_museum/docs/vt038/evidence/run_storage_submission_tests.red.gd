extends SceneTree

const StorageSubmissionTests := preload("res://maps/isg_museum/tests/storage_submission_tests.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var failures := await StorageSubmissionTests.new().run(host)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("VT-038 storage submission failures: ", failures.size())
	host.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
