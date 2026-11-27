extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var host := Node.new()
	root.add_child(host)
	var failures: Array[String] = await preload("res://maps/isg_museum/tests/courtyard_palette_tests.gd").new().run(host)
	host.free()
	await preload("res://tests/test_utils.gd").settle_async_audio(self)
	quit(0 if failures.is_empty() else 1)
