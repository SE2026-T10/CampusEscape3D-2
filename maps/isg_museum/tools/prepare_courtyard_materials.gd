extends SceneTree

## Offline low-contrast albedo derived from the existing marble. No source edits.
const BASE := "res://maps/isg_museum/assets/materials/"

func _initialize() -> void:
	var source := Image.load_from_file(BASE+"textures/marble_012/Marble012_2K-JPG_Color.jpg")
	source.resize(1024,1024,Image.INTERPOLATE_LANCZOS)
	source.convert(Image.FORMAT_RGB8)
	for y in source.get_height():
		for x in source.get_width():
			var sample := source.get_pixel(x,y)
			var grain := (sample.r+sample.g+sample.b)/3.0
			# Keep gentle mineral variation, instead of multiplying strong marble veins.
			source.set_pixel(x,y,Color(.79,.765,.69).lerp(Color(grain,grain,grain),.12))
	DirAccess.make_dir_recursive_absolute(BASE+"textures/derived")
	assert(source.save_png(BASE+"textures/derived/courtyard_stone_albedo.png") == OK)
	print("Prepared courtyard mineral albedo: 1024x1024, 12% source contrast; CC0 marble source unchanged")
	quit()
