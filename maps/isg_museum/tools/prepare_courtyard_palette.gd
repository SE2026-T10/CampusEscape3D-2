extends SceneTree

const CONFIG := "res://maps/isg_museum/resources/courtyard_palette.json"
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	if not config is Dictionary or config.get("schema_version")!=1 or not config.get("roles") is Dictionary or config.get("stage") not in ["A_preview_only","B_production"]:
		push_error("Invalid courtyard palette config")
		quit(1)
		return
	var check := "--check" in OS.get_cmdline_user_args()
	for role in config.roles:
		var entry = config.roles[role]
		if not entry is Dictionary or not entry.has_all(["source_color","source_normal","source_roughness","material","derived_color","tint","tile_m","normal_strength","roughness","metallic","seed","contrast","mottle"]):
			failures.append("Incomplete role "+role)
			continue
		if not entry.tint is Array or entry.tint.size()!=3 or not entry.tile_m is float or entry.tile_m<=0:
			failures.append("Invalid dimensions/colour "+role)
			continue
		for key in ["source_color","source_normal","source_roughness"]:
			if not FileAccess.file_exists(entry[key]): failures.append("Missing "+entry[key])
		if not check and failures.is_empty():
			generate(role,entry,config.texture_size)
		if check:
			if not FileAccess.file_exists(entry.material) or not FileAccess.file_exists(entry.derived_color):
				failures.append("Missing derived preset: "+role)
				continue
			var material := load(entry.material) as StandardMaterial3D
			if material==null or material.albedo_texture==null or material.normal_texture==null:
				failures.append("Invalid material "+role)
				continue
			if material.shading_mode!=BaseMaterial3D.SHADING_MODE_PER_PIXEL or material.get_meta("material_role","")!=role:
				failures.append("Invalid lit role "+role)
			if not is_equal_approx(material.uv1_scale.x,1.0/float(entry.tile_m)): failures.append("Texture scale mismatch "+role)
			var scale := 1.0/float(entry.tile_m)
			if not material.uv1_scale.is_equal_approx(Vector3.ONE*scale) or not material.uv1_triplanar or not material.uv1_world_triplanar:
				failures.append("Texture projection mismatch "+role)
			if not material.normal_enabled or not is_equal_approx(material.normal_scale,float(entry.normal_strength)) or not is_equal_approx(material.roughness,float(entry.roughness)) or not is_equal_approx(material.metallic,float(entry.metallic)):
				failures.append("Surface parameters mismatch "+role)
			if material.albedo_texture.resource_path!=entry.derived_color or material.normal_texture.resource_path!=entry.source_normal or material.roughness_texture==null or material.roughness_texture.resource_path!=entry.source_roughness:
				failures.append("Texture source mismatch "+role)
			# Recompute offline, without saving: catches stale tint/contrast/seed output too.
			var actual := Image.load_from_file(entry.derived_color)
			var expected := derive_albedo(entry,config.texture_size)
			if actual==null or expected==null or actual.get_format()!=expected.get_format() or actual.get_size()!=expected.get_size() or actual.get_data()!=expected.get_data():
				failures.append("Albedo does not match JSON "+role)
	for failure in failures: push_error(failure)
	print("Courtyard palette ","checked" if check else "prepared",": ",config.roles.size()," roles, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func derive_albedo(entry: Dictionary, size: int) -> Image:
	var source := Image.load_from_file(entry.source_color)
	if source==null: return null
	source.resize(size,size,Image.INTERPOLATE_LANCZOS)
	# Offline low-pass only where configured; retain large mineral variations.
	var lowpass := int(entry.get("albedo_lowpass_size",size))
	if lowpass<size:
		source.resize(lowpass,lowpass,Image.INTERPOLATE_LANCZOS)
		source.resize(size,size,Image.INTERPOLATE_BILINEAR)
	source.convert(Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = entry.seed
	noise.frequency = .009
	noise.fractal_octaves = 3
	var tint := Color(entry.tint[0],entry.tint[1],entry.tint[2])
	for y in size:
		for x in size:
			var sample := source.get_pixel(x,y)
			var lum := (sample.r+sample.g+sample.b)/3.0
			var variation := clampf(1+(lum-.53)*float(entry.contrast),.20,1.30)
			variation += noise.get_noise_2d(x,y)*float(entry.mottle)
			source.set_pixel(x,y,Color(tint.r*variation,tint.g*variation,tint.b*variation))
	return source

func generate(role: String, entry: Dictionary, size: int) -> void:
	DirAccess.make_dir_recursive_absolute(entry.material.get_base_dir())
	DirAccess.make_dir_recursive_absolute(entry.derived_color.get_base_dir())
	var source := derive_albedo(entry,size)
	if source==null:
		failures.append("Could not read source "+role)
		return
	if source.save_png(entry.derived_color)!=OK:
		failures.append("Could not save "+role)
		return
	# Plain .tres references let the editor import the newly written PNG next.
	var text := "[gd_resource type=\"StandardMaterial3D\" load_steps=4 format=3]\n\n"
	for pair in [["color",entry.derived_color],["normal",entry.source_normal],["roughness",entry.source_roughness]]:
		text += "[ext_resource type=\"Texture2D\" path=\"%s\" id=\"%s\"]\n"%[pair[1],pair[0]]
	text += "\n[resource]\nresource_name = \"Gardner preview: %s\"\n"%role
	text += "albedo_texture = ExtResource(\"color\")\nnormal_enabled = true\nnormal_texture = ExtResource(\"normal\")\n"
	text += "normal_scale = %s\nroughness = %s\nmetallic = %s\nmetallic_specular = 0.25\n"%[entry.normal_strength,entry.roughness,entry.metallic]
	text += "roughness_texture = ExtResource(\"roughness\")\nroughness_texture_channel = 0\n"
	var scale := 1.0/float(entry.tile_m)
	text += "uv1_scale = Vector3(%s, %s, %s)\nuv1_triplanar = true\nuv1_world_triplanar = true\nuv1_triplanar_sharpness = 8.0\ntexture_filter = 5\n"%[scale,scale,scale]
	text += "metadata/material_role = \"%s\"\n"%role
	var file := FileAccess.open(entry.material,FileAccess.WRITE)
	file.store_string(text)
	file.close()
