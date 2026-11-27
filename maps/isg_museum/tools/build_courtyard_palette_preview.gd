extends SceneTree

func _initialize() -> void:
	var preview := Node3D.new()
	preview.name = "CourtyardPalettePreview"
	var controller := load("res://maps/isg_museum/scripts/courtyard_palette_preview.gd") as GDScript
	if controller==null or not controller.can_instantiate():
		preview.free()
		quit(1)
		return
	preview.set_script(controller)
	var map: Node3D = load("res://maps/isg_museum/scenes/museum_editing.tscn").instantiate()
	map.name = "Map"
	preview.add_child(map)
	map.owner = preview
	var packed := PackedScene.new()
	var error := packed.pack(preview)
	if error==OK: error = ResourceSaver.save(packed,"res://maps/isg_museum/scenes/previews/courtyard_palette_preview.tscn")
	preview.free()
	print("Preview build: ",error)
	quit(0 if error==OK else 1)
