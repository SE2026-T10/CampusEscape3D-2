extends SceneTree

const Art := preload("res://maps/isg_museum/tools/environment_art_builder.gd")

func _initialize() -> void:
	var art := Art.new()
	var folder := Art.BASE+"scenes/art/modules/"
	DirAccess.make_dir_recursive_absolute(folder)
	for entry in [
		["gothic_column","architecture/gothic_architectural_structures/gothic_architectural_structures.glb",Vector3(.55,3.05,.55),["Object_4"],Color(.82,.77,.63)]]:
		var module := art.prepare_visual(entry[1],entry[2],0,entry[3],Art.COURTYARD_STONE)
		module.name = entry[0].to_pascal_case()
		art.assign_owners(module,module)
		var packed := PackedScene.new()
		assert(packed.pack(module) == OK)
		assert(ResourceSaver.save(packed,folder+entry[0]+".tscn") == OK)
		module.free()
	quit()
