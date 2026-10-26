extends SceneTree

## Build V1 from shared actors and map-local geometry; runtime needs no tools.
const BASE := "res://maps/intelligence/"
const SCENE := BASE + "scenes/intelligence_k17.tscn"
const NAV := BASE + "resources/k17_navmesh.tres"
const Mission := preload("res://maps/intelligence/scripts/mission_controller.gd")
const PLAYER := preload("res://shared/scenes/player/player.tscn")
const GUARD := preload("res://shared/scenes/npc/guard.tscn")
const Art := preload("res://maps/intelligence/tools/k17_art_builder.gd")
const ART_SCENE := BASE + "scenes/environment/k17_environment.tscn"
const WALL := Color(0.32, 0.37, 0.36)
const METAL := Color(0.16, 0.22, 0.22)
const CRATE := Color(0.34, 0.32, 0.19)
const GOLD := Color(0.95, 0.67, 0.19)
const CYAN := Color(0.28, 0.9, 0.8)
var level: Node3D
var materials := {}


func _init() -> void:
	_build.call_deferred()


func _build() -> void:
	level = Node3D.new()
	level.name = "IntelligenceK17"
	level.set_meta("map_version", "v2-art")
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	var nav := NavigationMesh.new()
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask = 17
	nav.agent_height = 2.0
	nav.agent_radius = 0.5
	nav.region_min_size = 2.0
	region.navigation_mesh = nav
	_add(level, region)
	_geometry(region)
	if not _build_environment(region):
		level.free()
		quit(1)
		return
	root.add_child(level)
	region.bake_navigation_mesh(false)
	if nav.get_polygon_count() == 0 or ResourceSaver.save(nav, NAV, ResourceSaver.FLAG_CHANGE_PATH) != OK:
		push_error("K17: navigation bake/save failed")
		quit(1)
		return
	root.remove_child(level)
	_actors()
	_gameplay()
	_systems()
	var packed := PackedScene.new()
	if packed.pack(level) != OK or ResourceSaver.save(packed, SCENE) != OK:
		push_error("K17: scene save failed")
		quit(1)
		return
	print("K17 BUILT: ", nav.get_polygon_count(), " navmesh polygons, 4 military appearances on shared guards, 2 approaches/exits")
	level.free()
	quit(0)


func _geometry(parent: Node) -> void:
	_box(parent, "Ground", Vector3(0, -0.2, 1), Vector3(48, 0.4, 60), Color(0.20, 0.24, 0.22))
	# A real sight blocker beside (not inside) the west rally point protects the spawn.
	_box(parent, "EntryCover", Vector3(-13.2, 1.1, 25.1), Vector3(1.6, 2.2, 2.0), CRATE)
	_box(parent,"VehicleBarrier",Vector3(0,.6,23.6),Vector3(6.6,1.2,.5),METAL)
	for z in [17.8,19.0]:
		_box(parent,"FuelDrum"+str(z),Vector3(-22,.55,z),Vector3(.83,1.1,.83),METAL)
	# Compound boundary and interior walls: all static colliders are baked.
	_box(parent, "BoundaryWest", Vector3(-24, 1.6, 1), Vector3(0.4, 3.2, 60), METAL)
	_box(parent, "BoundaryEast", Vector3(24, 1.6, 1), Vector3(0.4, 3.2, 60), METAL)
	_box(parent, "BoundaryNorth", Vector3(0, 1.6, -29), Vector3(48, 3.2, 0.4), METAL)
	_box(parent, "BoundarySouth", Vector3(0, 1.6, 31), Vector3(48, 3.2, 0.4), METAL)
	_wall_h(parent, "Fence", 22, -24, 24, [Vector2(-18, -14), Vector2(14, 18)], METAL, 2.1)
	_wall_h(parent, "Front", 14, -20, 20, [Vector2(-13.8, -10.2), Vector2(14.2, 17.8)])
	_wall_h(parent, "ArchiveFront", 0, -20, 20, [Vector2(2.2, 5.8)])
	_wall_h(parent, "North", -24, -20, 20, [])
	_wall_v(parent, "West", -20, -24, 14, [])
	_wall_v(parent, "East", 20, -24, 14, [])
	_wall_v(parent, "GuardRoomPartition", -4, 0, 14, [Vector2(5.2, 8.8)])
	_wall_v(parent, "ServicePartition", 12, 0, 14, [Vector2(5.2, 8.8)])
	# Separate communications bay, controlled corridor and archive service aisles.
	_wall_h(parent,"CommsSouth",9.5,-4,12,[Vector2(-1.8,1.8)])
	_wall_h(parent,"CommsNorth",4.7,-4,12,[Vector2(2.2,5.8)])
	_wall_v(parent,"ArchiveServiceWall",12,-24,0,[])
	_wall_v(parent,"ArchiveEastAisle",8,-24,-8,[Vector2(-22,-18)])
	_wall_v(parent,"ArchiveWestBay",-12,-24,0,[Vector2(-21,-17),Vector2(-7,-3)])
	# Guard room desk, communications consoles and archive racks.
	_box(parent, "PassDesk", Vector3(-12, 0.4, 4), Vector3(2.8, 0.8, 1.2), METAL)
	_box(parent, "ArchiveDesk", Vector3(4, 0.45, -20), Vector3(2.4, 0.9, 1.2), METAL)
	for x in [-16.0, -8.0]:
		_box(parent, "GuardRoomLocker" + str(x), Vector3(x, 1.1, 1), Vector3(2, 2.2, 1.1), CRATE)
	for z in [-17.0, -10.0]:
		_box(parent, "ArchiveRackLeft" + str(z), Vector3(-8, 1.2, z), Vector3(5.5, 2.4, 1.2), METAL)
		_box(parent, "ArchiveRackRight" + str(z), Vector3(3, 1.2, z), Vector3(5.5, 2.4, 1.2), METAL)
	_box(parent, "CheckpointCover", Vector3(8, 1.2, -2.7), Vector3(3.8, 2.4, 1.0), METAL)
	_box(parent, "Terminal", Vector3(5, 0.65, 11.5), Vector3(3, 1.3, 1.2), METAL)
	for pos in [Vector3(-8, 0.65, 17), Vector3(2, 0.65, 19), Vector3(11, 0.65, 16.5), Vector3(-17, 0.65, 11)]:
		_box(parent, "SupplyCrate" + str(pos), pos, Vector3(2.8, 1.3, 1.5), CRATE)
	for z in [3.0, 10.0]:
		_box(parent, "ServiceCover" + str(z), Vector3(13.2, 0.65, z), Vector3(1.4, 1.3, 1.8), CRATE)
	# Painted floors make the five spaces readable without final assets.
	_paint(parent, "GuardRoomFloor", Vector3(-12, 0.015, 7), Vector3(15.5, 0.02, 13.5), Color(0.26, 0.30, 0.27))
	_paint(parent, "CommunicationsFloor", Vector3(4, 0.015, 7), Vector3(15.5, 0.02, 13.5), Color(0.23, 0.29, 0.31))
	_paint(parent, "ArchiveFloor", Vector3(0, 0.015, -12), Vector3(39.5, 0.02, 23.5), Color(0.27, 0.28, 0.26))
	_paint(parent, "ServiceLane", Vector3(16, 0.025, 7), Vector3(1.4, 0.025, 13), Color(0.6, 0.46, 0.15))
	for x in [-16.0, 16.0]:
		_paint(parent, "ExtractionPad" + str(x), Vector3(x, 0.025, 27), Vector3(3.8, 0.02, 3.8), Color(0.12, 0.45, 0.31))
	_label(parent, "K17Sign", "K17 / CƠ SỞ TÌNH BÁO", Vector3(-12, 2.8, 14.25), GOLD)
	_label(parent, "GuardSign", "PHÒNG TRỰC\nGIẤY THÔNG HÀNH", Vector3(-12, 2.7, 2), GOLD)
	_label(parent, "CommsSign", "KHU THÔNG TIN\nHỒ SƠ ↑  /  BẢO TRÌ →", Vector3(4, 2.7, 1), CYAN)
	_label(parent, "ServiceSign", "LỐI BẢO TRÌ / ĐƯỜNG RÚT", Vector3(16, 2.6, 13.8), GOLD)
	_label(parent, "FileSign", "MẬT LỆNH 04\nNIÊM PHONG · 120 GIÂY", Vector3(4, 2.7, -22), GOLD)
	_label(parent, "PrepSign", "ĐIỂM CHUẨN BỊ\nCHECKPOINT", Vector3(8, 2.0, -6), CYAN)
	for x in [-16.0, 16.0]:
		_label(parent, "ExtractionSign" + str(x), "ĐIỂM TẬP KẾT\nMANG HỒ SƠ ĐẾN ĐÂY", Vector3(x, 2.5, 28.5), CYAN)
		_light(parent, "ExtractionBeacon" + str(x), Vector3(x, 3, 27), CYAN, 8, 2.0)
		_paint(parent, "ExtractionPost" + str(x), Vector3(x + 1.6, 1, 27), Vector3(0.15, 2, 0.15), CYAN)


func _build_environment(region: NavigationRegion3D) -> bool:
	# Navigation/collision remain explicit. Art has its own editable scene and UVs.
	for node in region.find_children("*", "VisualInstance3D", true, false):
		node.visible = false
	for node in region.find_children("*", "Light3D", true, false):
		node.visible = false
	for node in region.get_children():
		if node is StaticBody3D and str(node.name).begins_with("Fence"):
			node.collision_layer = 16 # Movement barrier; shared sight_mask 3 sees through wire.
	# Preserve hand edits AND baked lightmaps on a normal gameplay/nav rebuild.
	# Art regeneration is an explicit authoring operation and requires another bake.
	if not FileAccess.file_exists(ART_SCENE) or "--rebuild-art" in OS.get_cmdline_user_args():
		var art := Art.new().build(region)
		var packed := PackedScene.new()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ART_SCENE.get_base_dir()))
		if packed.pack(art) != OK or ResourceSaver.save(packed, ART_SCENE) != OK:
			push_error("K17: environment scene could not be saved")
			art.free()
			return false
		art.free()
	var instance := (load(ART_SCENE) as PackedScene).instantiate()
	_add(level, instance)
	return true


func _actors() -> void:
	var player := PLAYER.instantiate() as FirstPersonPlayer
	player.name = "Player"
	player.position = Vector3(-16, 0.05, 27)
	player.collision_mask |= 16
	_add(level, player)
	var routes := _group(level, "PatrolRoutes")
	var guards := _group(level, "Guards")
	var points := [
		[Vector3(-8, 0.05, 18), Vector3(8, 0.05, 18), Vector3(8, 0.05, 20), Vector3(-8, 0.05, 20)],
		[Vector3(-16, 0.05, 4), Vector3(-8, 0.05, 4), Vector3(-8, 0.05, 10), Vector3(-16, 0.05, 10)],
		[Vector3(1, 0.05, 3), Vector3(9, 0.05, 3), Vector3(9, 0.05, 10), Vector3(1, 0.05, 10)],
		[Vector3(-15, 0.05, -19), Vector3(-15, 0.05, -5), Vector3(-1, 0.05, -5), Vector3(-1, 0.05, -19)],
	]
	for i in points.size():
		var route := PatrolRoute.new()
		route.name = "Route%d" % (i + 1)
		_add(routes, route)
		for j in points[i].size():
			var point := PatrolPoint.new()
			point.name = "Point%d" % j
			point.position = points[i][j]
			point.wait_time = 2.5
			_add(route, point)
		var guard := GUARD.instantiate() as Guard
		guard.name = "Guard%d" % (i + 1)
		guard.position = points[i][0]
		guard.rotation.y = -PI / 2.0
		guard.patrol_route = route
		guard.checkpoint_snapshot = true
		guard.collision_mask |= 16
		_add(guards, guard)
		guard.set_meta("appearance", "k17_military")


func _gameplay() -> void:
	var gameplay := _group(level, "Gameplay")
	var objectives := ObjectiveManager.new()
	objectives.name = "ObjectiveManager"
	var list: Array[Dictionary] = []
	for objective in Mission.OBJECTIVES:
		list.append(objective.duplicate())
	objectives.objectives = list
	_add(gameplay, objectives)
	_script(gameplay, "CheckpointManager", Node.new(), "res://features/checkpoints/checkpoint_manager.gd")
	_script(gameplay, "Mission", Node.new(), BASE + "scripts/mission_controller.gd")
	for x in [-12.0, 16.0]:
		var trigger := ObjectiveTrigger.new()
		trigger.name = "EnterTrigger" + str(x)
		trigger.position = Vector3(x, 1, 11)
		trigger.objective_id = Mission.ENTER
		_add(gameplay, trigger)
		_shape(trigger, Vector3(5, 2, 3))
	_pickup(gameplay, "AccessPass", Mission.PASS, Vector3(-12, 0.84, 4), "Lấy giấy thông hành", "Vào cơ sở trước", Color("c1b893"), Vector3(0.4, 0.035, 0.26))
	_pickup(gameplay, "IntelligenceFile", Mission.FILE, Vector3(4, 1.15, -20), "Lấy Mật lệnh 04 — bắt đầu 120 giây", "Đến ô checkpoint trước khi thu hồi hồ sơ", Color(0.8, 0.25, 0.12), Vector3(0.5, 0.08, 0.35))
	var door := AccessDoor.new()
	door.name = "ArchiveDoor"
	door.position = Vector3(4, 1.2, 0)
	door.door_name = "cửa khu hồ sơ"
	door.prompt = "Mở cửa khu hồ sơ"
	door.key_objective_id = Mission.PASS
	door.key_name = "giấy thông hành"
	_add(gameplay, door)
	_shape(door, Vector3(3.6, 2.4, 1.0))
	var panel := _box(door, "Panel", Vector3.ZERO, Vector3(3.5, 2.4, 0.2), METAL)
	panel.get_node("Mesh").free()
	var hinge := Node3D.new()
	hinge.name = "DoorHinge"
	hinge.position.x = -1.72
	_add(panel,hinge)
	var door_art := (load(BASE+"assets/models/blast_door.glb") as PackedScene).instantiate()
	door_art.position.x = 1.72
	door_art.rotation.y = PI
	_add(hinge, door_art)
	door.leaf_paths = [NodePath("Panel/DoorHinge")]
	door.leaf_open_angles = PackedFloat32Array([90.0])
	var cp := _script(gameplay, "ArchiveCheckpoint", Area3D.new(), BASE + "scripts/mission_checkpoint.gd") as Checkpoint
	cp.position = Vector3(8, 1, -6)
	cp.checkpoint_name = "Điểm chuẩn bị K17"
	_shape(cp, Vector3(3.2, 2, 3.2))
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = Vector3(0, -0.95, 0)
	spawn.rotation.y = PI / 2
	_add(cp, spawn)
	# Ground markings, sign and radio position live in the environment scene.
	for i in 2:
		var zone := _script(gameplay, "Extraction%d" % i, Area3D.new(), BASE + "scripts/extraction_zone.gd") as Area3D
		zone.position = Vector3(-16 if i == 0 else 16, 1, 27)
		zone.set("route_id", &"courtyard" if i == 0 else &"maintenance")
		zone.set("route_name", "Sân tiếp vận" if i == 0 else "Hành lang bảo trì")
		_shape(zone, Vector3(3.8, 2, 3.8))


func _systems() -> void:
	for entry in [
		["StealthDirector", Node.new(), "res://shared/scripts/stealth/stealth_director.gd"],
		["NoiseSystem", Node3D.new(), "res://shared/scripts/noise/noise_system.gd"],
		["StealthHud", CanvasLayer.new(), "res://shared/scripts/ui/stealth_hud.gd"],
		["ObjectiveHud", CanvasLayer.new(), "res://shared/scripts/ui/objective_hud.gd"],
		["GameFlow", Node.new(), "res://shared/scripts/game/game_flow.gd"],
		["GameMenus", CanvasLayer.new(), "res://shared/scripts/ui/game_menus.gd"],
		["AudioDirector", Node.new(), "res://shared/scripts/presentation/audio_director.gd"],
		["MilitaryAppearance", Node.new(), BASE+"scripts/military_appearance.gd"],
	]:
		var node := _script(level, entry[0], entry[1], entry[2])
		if node is GameMenus:
			node.win_message = "An đã đưa Mật lệnh 04 ra khỏi cơ sở K17."

	var debug := _script(level, "NavigationDebug", Node3D.new(), "res://shared/scripts/debug/navigation_debug.gd")
	debug.set("region", level.get_node("NavigationRegion3D"))
	debug.set("visible_on_start", false)


func _pickup(parent: Node, node_name: String, id: StringName, pos: Vector3, prompt: String, waiting: String, colour: Color, size: Vector3) -> void:
	var item := AccessCard.new()
	item.name = node_name
	item.position = pos
	item.objective_id = id
	item.prompt = prompt
	item.waiting_prompt = waiting
	item.spin_speed = 0.0
	_add(parent, item)
	_shape(item, Vector3(0.8, 0.5, 0.8))
	var model := _group(item, "Model")
	_paint(model, "Mesh", Vector3.ZERO, size, colour)
	var stencil := Label3D.new()
	stencil.name = "DocumentStamp"
	stencil.text = "K17 / PASS" if id == Mission.PASS else "MẬT LỆNH 04"
	stencil.position.y = size.y/2+.002
	stencil.rotation.x = -PI/2
	stencil.font_size = 24
	stencil.pixel_size = .0010
	stencil.outline_size = 0
	stencil.modulate = Color("1e2829")
	_add(model, stencil)


func _wall_h(parent: Node, prefix: String, z: float, left: float, right: float, gaps: Array, colour := WALL, height := 3.2) -> void:
	var start := left
	for i in gaps.size() + 1:
		var end: float = gaps[i].x if i < gaps.size() else right
		if end > start:
			_box(parent, prefix + str(i), Vector3((start + end) / 2, height / 2, z), Vector3(end - start, height, 0.35), colour)
		start = gaps[i].y if i < gaps.size() else right


func _wall_v(parent: Node, prefix: String, x: float, low: float, high: float, gaps: Array) -> void:
	var start := low
	for i in gaps.size() + 1:
		var end: float = gaps[i].x if i < gaps.size() else high
		if end > start:
			_box(parent, prefix + str(i), Vector3(x, 1.6, (start + end) / 2), Vector3(0.35, 3.2, end - start), WALL)
		start = gaps[i].y if i < gaps.size() else high


func _box(parent: Node, node_name: String, pos: Vector3, size: Vector3, colour: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	_add(parent, body)
	_paint(body, "Mesh", Vector3.ZERO, size, colour)
	_shape(body, size)
	return body


func _paint(parent: Node, node_name: String, pos: Vector3, size: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.position = pos
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var key := colour.to_html()
	if not materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = 0.85
		materials[key] = material
	mesh.material_override = materials[key]
	_add(parent, mesh)
	return mesh


func _shape(parent: Node, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	_add(parent, shape)


func _label(parent: Node, node_name: String, text: String, pos: Vector3, colour: Color) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = pos
	label.font_size = 32
	label.pixel_size = 0.006
	label.modulate = colour
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_add(parent, label)


func _light(parent: Node, node_name: String, pos: Vector3, colour: Color, distance: float, energy: float, alarm := false) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = pos
	light.light_color = colour
	light.omni_range = distance
	light.light_energy = energy
	if alarm:
		light.add_to_group("k17_alarm_lights", true)
	_add(parent, light)


func _script(parent: Node, node_name: String, node: Node, path: String) -> Node:
	node.name = node_name
	node.set_script(load(path))
	_add(parent, node)
	return node


func _group(parent: Node, node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	_add(parent, node)
	return node


func _add(parent: Node, node: Node) -> void:
	parent.add_child(node)
	node.owner = level
