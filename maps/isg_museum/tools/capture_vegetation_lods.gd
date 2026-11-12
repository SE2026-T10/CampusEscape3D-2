extends SceneTree

## Isolated vegetation QA under one fixed lighting rig. Optional movie uses
## Godot's native --write-movie; it is never used as a timing benchmark.
const Art := preload("res://maps/isg_museum/tools/environment_art_builder.gd")
const OUT := Art.BASE+"docs/environment-art-v1_1/"
var camera: Camera3D
var trees: Array[Node3D] = []
var labels: Array[String] = []
var before := false
var caption: Label
var evidence: Array = []

func _initialize() -> void:
	run.call_deferred()

func snap(id: String) -> void:
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var name := ("before-" if before else "after-")+id+".png"
	root.get_texture().get_image().save_png(OUT+name)
	evidence.append({"image":name,"camera":str(camera.position),"root_distance":camera.position.length(),"lighting":"v1.1 fixed rig"})
	print("LOD QA captured ",name)

func set_camera(distance: float, angle := .55) -> void:
	var radius := sqrt(distance*distance-2.55*2.55)
	camera.position = Vector3(sin(angle)*radius,2.55,cos(angle)*radius)
	camera.look_at(Vector3(0,2.55,0))
	caption.text = "SOURCE TREE LOD QA | camera to root %.1f m | same anchor / lighting" % camera.position.length()

func run() -> void:
	before = "--before" in OS.get_cmdline_user_args()
	root.size = Vector2i(960,540)
	root.content_scale_size = Vector2i(960,540)
	var art := Art.new()
	var layout := art.load_layout()
	var world := Node3D.new()
	root.add_child(world)
	var source := load(Art.BASE+"scenes/museum.tscn").instantiate() as Node3D
	var environment := WorldEnvironment.new()
	world.add_child(environment)
	environment.environment = source.get_node("WorldEnvironment").environment
	var sun := source.get_node("DirectionalLight3D").duplicate() as DirectionalLight3D
	world.add_child(sun)
	source.free()
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90,90)
	ground.mesh = plane
	ground.material_override = art.colour(Color(.26,.32,.2))
	world.add_child(ground)
	ground.position.y = -.025
	if before:
		var original: Node3D = load(OUT+"before-source/museum_geometry.tscn").instantiate()
		for node in original.get_node("EnvironmentArt").get_children():
			if not str(node.name).begins_with("Tree"):
				continue
			var id := "far" if str(node.name).begins_with("TreeFar") else "near"
			if id in labels:
				continue
			var copy := node.duplicate() as Node3D
			world.add_child(copy)
			copy.position = Vector3.ZERO
			trees.append(copy)
			labels.append(id)
		original.free()
	else:
		for level in layout.quality.tree_lods:
			var tree := art.place(world,"Tree_"+level.id,"derived/tree_small_02_%s.scn" % level.id,
				Vector3(4.4,5.2,4.8),Vector3.ZERO,0,[],null,layout.courtyard.tree)
			trees.append(tree)
			labels.append(level.id)
			for mesh in tree.get_node("VisualPivot").get_children():
				mesh.visibility_range_begin = level.begin
				mesh.visibility_range_end = level.end
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 40
	var layer := CanvasLayer.new()
	root.add_child(layer)
	caption = Label.new()
	layer.add_child(caption)
	caption.position = Vector2(20,18)
	caption.add_theme_font_size_override("font_size",18)
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	if "--transition" in OS.get_cmdline_user_args():
		for i in 600:
			var progress := float(i)/599
			var distance := 12+18*sin(progress*PI)
			set_camera(distance,.25+progress*.8)
			await process_frame
		print("LOD transition movie: 600 frames; root distance 12 -> 30 -> 12 m")
	else:
		# Force each saved LOD at exactly the same camera/light for shape review.
		for i in trees.size():
			for j in trees.size():
				trees[j].visible = i == j
			for mesh in trees[i].get_node("VisualPivot").get_children():
				mesh.visibility_range_begin = 0
				mesh.visibility_range_end = 0
			set_camera(12)
			caption.text += " | FORCED "+labels[i]
			await snap("lod-"+labels[i]+"-same-camera")
		for i in trees.size():
			trees[i].show()
			var begins := 0.0
			var ends := 19.0 if labels[i] == "near" else 0.0
			if before:
				begins = 19.0 if labels[i] == "far" else 0.0
			else:
				begins = layout.quality.tree_lods[i].begin
				ends = layout.quality.tree_lods[i].end
			for mesh in trees[i].get_node("VisualPivot").get_children():
				mesh.visibility_range_begin = begins
				mesh.visibility_range_end = ends
		for distance in [12.0,18.0,22.0,30.0]:
			set_camera(distance)
			await snap("lod-auto-%dm" % int(distance))
		var file := FileAccess.open(OUT+("before-" if before else "after-")+"lod-capture.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"snapshots":evidence,"normalization":"identical source reference bounds for all v1.1 levels"},"\t"))
	world.free()
	layer.free()
	quit()
