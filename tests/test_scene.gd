extends Node

## Lightweight Phase 1 smoke test. Run this scene directly in Godot. a
func _ready() -> void:
	var library_scene := load("res://scenes/level/library_graybox.tscn") as PackedScene
	assert(library_scene != null, "The library graybox scene must load.")
	var library := library_scene.instantiate()
	assert(library.name == "LibraryGraybox", "The graybox root must be named LibraryGraybox.")
	assert(library.get_node_or_null("Floor") != null, "The graybox must include a floor.")
	library.queue_free()
	print("Phase 1 smoke test passed.")
	get_tree().quit()
