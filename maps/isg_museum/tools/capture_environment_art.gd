extends SceneTree

## Design/QA photos only. Timing lives in benchmark_environment_art.gd.
const Art := preload("res://maps/isg_museum/tools/environment_art_builder.gd")
const OUT := "res://maps/isg_museum/docs/environment-art-v1_1/"
var level: Node3D
var camera: Camera3D
var prefix := "after-"
var evidence: Array = []
var art := Art.new()

func _initialize() -> void:
	run.call_deferred()

func shot(id: String, at: Vector3, target: Vector3, use_player := false) -> Image:
	if not use_player:
		camera.current = true
		camera.position = at
		camera.look_at(target)
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	pixels.save_png(OUT+prefix+id+".png")
	var active := root.get_camera_3d()
	evidence.append({"image":prefix+id+".png","camera_path":str(active.get_path()),
		"camera_position":str(active.global_position),"fov":active.fov,"player_camera":use_player})
	print("Captured ",prefix,id)
	return pixels

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var before := "--before" in OS.get_cmdline_user_args()
	prefix = "before-" if before else "after-"
	level = load(OUT+"before-source/museum.tscn" if before else Art.BASE+"scenes/museum.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	level.process_mode = Node.PROCESS_MODE_DISABLED
	for child in level.get_children():
		if child is CanvasLayer:
			child.hide()
	for node in get_nodes_in_group("debug_visuals"):
		if node is Node3D:
			node.hide()
	camera = Camera3D.new()
	root.add_child(camera)
	camera.fov = 78
	await shot("01-courtyard",Vector3(18,1.65,22.5),Vector3(18,4.8,12))
	await shot("02-fountain-trees",Vector3(18,1.65,20),Vector3(18,2.2,12))
	await shot("03-upper-canopy",Vector3(23.7,6.15,17.2),Vector3(22.9,3.3,19.9))
	await shot("04-hedge",Vector3(18,1.55,10.5),Vector3(14.9,1,9))
	var player := level.get_node("Player") as FirstPersonPlayer
	var guard := level.get_node("Guard_G4")
	player.position = Vector3(14,0,17.4)
	player.rotation.y = PI
	guard.position = Vector3(14.95,0,20.6)
	guard.face_yaw(0)
	player.set_crouching(false)
	player.head.position.y = player.stand_eye_height
	player.camera.current = true
	player.camera.look_at(guard.position+Vector3(0,1.5,0))
	await shot("05-player-standing",Vector3.ZERO,Vector3.ZERO,true)
	player.set_crouching(true)
	player.head.position.y = player.crouch_eye_height
	player.camera.look_at(guard.position+Vector3(0,1.2,0))
	await shot("06-player-crouching",Vector3.ZERO,Vector3.ZERO,true)
	# No third-person avatar exists: label a proxy of the real crouched capsule.
	var proxy := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = player.get_node("CollisionShape3D").shape.radius
	capsule.height = player.get_node("CollisionShape3D").shape.height
	proxy.mesh = capsule
	var proxy_material := art.colour(Color(.08,.5,.95,.65))
	proxy_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	proxy.material_override = proxy_material
	level.add_child(proxy)
	proxy.position = player.position+Vector3(0,capsule.height/2,0)
	var label := Label3D.new()
	level.add_child(label)
	label.position = player.position+Vector3(0,1.45,0)
	label.text = "QA: Player crouch capsule"
	label.pixel_size = .0018
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	await shot("07-cover-qa",Vector3(18.6,2.8,17.2),Vector3(14,1.15,19))
	proxy.free()
	label.free()
	var markers := Node3D.new()
	level.add_child(markers)
	for i in 3:
		var mat := art.colour([Color.WHITE,Color.RED,Color.BLUE][i])
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		art.box(markers,"Reference%d" % i,Vector3(.5,1.1,.3),Vector3(16.6+i*.65,11.9,15),mat)
	await shot("08-roof-glass-on",Vector3(18,3.8,18),Vector3(17.3,11.9,15))
	var roof := level.get_node("NavigationRegion3D/Geometry/EnvironmentArt/Roof")
	for child in roof.get_children():
		if str(child.name).begins_with("Glass"):
			child.hide()
	await shot("09-roof-glass-off",Vector3(18,3.8,18),Vector3(17.3,11.9,15))
	markers.free()
	if not before:
		await column_comparison()
	var file := FileAccess.open(OUT+prefix+"capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"images":evidence},"\t"))
	camera.free()
	level.free()
	quit()

func column_comparison() -> void:
	level.hide()
	var old_environment: Environment = level.get_node("WorldEnvironment").environment
	level.get_node("WorldEnvironment").environment = null
	var fixture := Node3D.new()
	root.add_child(fixture)
	var environment := WorldEnvironment.new()
	art.add(fixture,environment,"Environment")
	environment.environment = old_environment
	var sun := level.get_node("DirectionalLight3D").duplicate() as DirectionalLight3D
	art.add(fixture,sun,"Sun")
	var columns := art.group(fixture,"Columns")
	for i in 2:
		var module := load(Art.BASE+"scenes/art/modules/gothic_column.tscn").instantiate() as Node3D
		art.add(columns,module,"Column%d" % i)
		module.position.x = -1+i*2
	var reference := await shot("10-column-unbatched",Vector3(3,2.4,6),Vector3(0,1.5,0))
	art.batch_visuals(columns)
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	var path := OUT+"qa-column-batch.tscn"
	assert(ResourceSaver.save(packed,path) == OK)
	fixture.free()
	fixture = load(path).instantiate()
	root.add_child(fixture)
	var batched := await shot("11-column-batched-reloaded",Vector3(3,2.4,6),Vector3(0,1.5,0))
	var a := reference.get_data()
	var b := batched.get_data()
	var error_sum := 0.0
	var changed := 0
	for i in mini(a.size(),b.size()):
		error_sum += absi(int(a[i])-int(b[i]))
		changed += int(absi(int(a[i])-int(b[i])) > 8)
	var output := FileAccess.open(OUT+"column-batch-comparison.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"mean_absolute_byte_error":error_sum/a.size(),
		"fraction_bytes_delta_gt_8":float(changed)/a.size(),"same_camera_material_light":true,
		"normal_tangent_changes_made":false},"\t"))
	fixture.free()
	level.get_node("WorldEnvironment").environment = old_environment
