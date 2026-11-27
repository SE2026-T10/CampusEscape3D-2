extends SceneTree

## Reapply the museum palette offline. Saved materials are visible in the editor.
const Palette := preload("res://maps/isg_museum/tools/material_palette.gd")
const SCENES := {
	"museum_geometry": "apply_geometry",
	"service_expansion": "apply_service",
	"exhibits_expansion": "apply_exhibits",
	"museum_door": "apply_door",
	"entrance_door": "apply_door",
}


func _initialize() -> void:
	_apply.call_deferred()


func _apply() -> void:
	var palette := Palette.new()
	for scene_name in SCENES:
		var path := "res://maps/isg_museum/scenes/%s.tscn" % scene_name
		var scene := (load(path) as PackedScene).instantiate()
		palette.call(SCENES[scene_name], scene)
		# Rebuild the owned art layer after the blockout palette so source materials
		# and cover finishes survive both standalone palette runs and builder runs.
		var art := preload("res://maps/isg_museum/tools/environment_art_builder.gd").new()
		var layout := art.load_layout()
		if scene_name == "museum_geometry":
			art.apply_to_geometry(scene, layout)
		elif scene_name == "exhibits_expansion":
			art.apply_to_exhibits(scene, layout)
		elif scene_name == "service_expansion":
			art.apply_to_service(scene, layout)
		var packed := PackedScene.new()
		var result := packed.pack(scene)
		if result == OK:
			result = ResourceSaver.save(packed, path)
		scene.free()
		if result != OK:
			push_error("Could not apply museum materials to %s: %d" % [path, result])
			quit(1)
			return
		print("Applied museum materials: ", path)
	quit()
