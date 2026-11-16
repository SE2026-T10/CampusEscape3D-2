extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var host := Node.new()
	root.add_child(host)
	var suite := preload("res://maps/isg_museum/tests/guard_visual_tests.gd").new()
	var failures: Array[String] = await suite.run(host)
	host.free()
	quit(0 if failures.is_empty() else 1)
