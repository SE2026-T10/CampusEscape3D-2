extends RefCounted

## Offline material assignments shared by the scene builders and apply_materials.
const WOOD_FLOOR := preload("res://maps/isg_museum/assets/materials/presets/wood_floor.tres")
const PLASTER := preload("res://maps/isg_museum/assets/materials/presets/plaster_cream.tres")
const SAGE := preload("res://maps/isg_museum/assets/materials/presets/plaster_sage.tres")
const BURGUNDY := preload("res://maps/isg_museum/assets/materials/presets/plaster_burgundy.tres")
const MARBLE := preload("res://maps/isg_museum/assets/materials/presets/marble.tres")
const WOOD := preload("res://maps/isg_museum/assets/materials/presets/dark_wood.tres")
const PAVING := preload("res://maps/isg_museum/assets/materials/presets/paving_stones.tres")
const GRASS := preload("res://maps/isg_museum/assets/materials/presets/grass.tres")
const STEEL := preload("res://maps/isg_museum/assets/materials/presets/steel.tres")
const PAINTED_STEEL := preload("res://maps/isg_museum/assets/materials/presets/painted_steel.tres")
const CONCRETE := preload("res://maps/isg_museum/assets/materials/presets/concrete.tres")


static func apply_geometry(scene: Node3D) -> void:
	for path in ["Exterior", "Floor1Rooms", "Floor2Rooms", "StairA", "StairB"]:
		_apply_tree(scene.get_node(path), PLASTER)
	_apply_tree(scene.get_node("Floors"), WOOD_FLOOR)
	_set_material(scene, "Floors/Ground/Mesh", MARBLE)
	_set_material(scene, "Exterior/OutsideLanding/Mesh", CONCRETE)
	for stairs in ["StairA", "StairB"]:
		for part in ["LowerRamp", "UpperRamp", "MidLanding"]:
			_set_material(scene, stairs + "/" + part + "/Mesh", MARBLE)
		for part in ["UpperLandingRail", "SlopeRail0", "SlopeRail1"]:
			_set_material(scene, stairs + "/" + part + "/Mesh", STEEL)
	for body in scene.get_node("Cover").get_children():
		_apply_tree(body, WOOD if str(body.name).begins_with("Restoration") else MARBLE)
	for child in scene.get_node("Courtyard").get_children():
		var node_name := str(child.name)
		if node_name.begins_with("Path"):
			_apply_tree(child, PAVING)
		elif node_name.begins_with("Garden"):
			_apply_tree(child, GRASS)
		elif node_name.begins_with("UpperRail"):
			_apply_tree(child, STEEL)
		else:
			_apply_tree(child, MARBLE)
	for child in scene.get_node("FrontYard").get_children():
		var node_name := str(child.name)
		var mat: Material = PLASTER
		if node_name == "Ground":
			mat = GRASS
		elif node_name == "Walkway":
			mat = PAVING
		elif node_name == "ClosedStreetGate" or node_name.begins_with("LampPost"):
			mat = STEEL
		elif node_name.begins_with("Planter"):
			mat = MARBLE
		_apply_tree(child, mat)
	_staff_materials(scene)
	_storage_materials(scene)
	_floor_finishes(scene)
	_wall_finishes(scene)


static func apply_service(scene: Node3D) -> void:
	for path in ["ReceptionCounter/Visual", "CounterTop", "ChairBack",
			"ReceptionNotice/Base", "WallMap/Frame"]:
		_set_material(scene, path, WOOD)
	_set_material(scene, "ReceptionChair/Visual", PAINTED_STEEL)
	for gate in ["TicketGate_A", "TicketGate_B"]:
		_set_material(scene, gate + "/Panel/MeshInstance3D", PAINTED_STEEL)


static func apply_exhibits(scene: Node3D) -> void:
	for sculpture in ["S1", "S2"]:
		_set_material(scene, sculpture + "/BasePlate", WOOD)
		_set_material(scene, sculpture + "/Artifact/Stand", MARBLE)
	for path in ["S2/Artifact/BustBase", "S2/Artifact/Shoulders",
			"S2/Artifact/Neck", "S2/Artifact/Head"]:
		_set_material(scene, path, MARBLE)
	for drawer in ["H1", "H2"]:
		_set_material(scene, drawer + "/Tray", WOOD)
		_set_material(scene, drawer + "/Lid", WOOD)
	_set_material(scene, "GalleryAlarmSwitch/Panel", PAINTED_STEEL)


static func apply_door(scene: Node3D) -> void:
	_set_material(scene, "Panel/MeshInstance3D", WOOD)


static func _staff_materials(scene: Node3D) -> void:
	for path in ["Desk/Mesh", "DeskTop", "ModestyPanel_A", "ChairSeat", "ChairBack", "KeyRack_D"]:
		_set_material(scene, "StaffInterior/" + path, WOOD)
	_set_material(scene, "StaffInterior/Lockers/Mesh", PAINTED_STEEL)
	for child in scene.get_node("StaffInterior").get_children():
		var node_name := str(child.name)
		if node_name.begins_with("LockerHandle") or node_name.begins_with("ChairLeg") \
				or node_name == "RadioAntenna":
			_apply_tree(child, STEEL)


static func _storage_materials(scene: Node3D) -> void:
	for path in ["ToolShelves/Mesh", "SteelCabinet/Mesh", "CabinetDoor", "KeypadBacking"]:
		_set_material(scene, "StorageInterior/" + path, PAINTED_STEEL)
	_set_material(scene, "StorageInterior/RopeRack", WOOD)
	for child in scene.get_node("StorageInterior").get_children():
		var node_name := str(child.name)
		if node_name.begins_with("Shelf"):
			_apply_tree(child, WOOD)
		elif node_name.begins_with("Hook") or node_name == "CabinetHandle":
			_apply_tree(child, STEEL)


static func _floor_finishes(scene: Node3D) -> void:
	var finishes := _replace_group(scene, "FloorFinishes")
	# Thin visual finishes share the existing continuous physics floor.
	_floor(finishes, "SculptureWood", Rect2(0, 6, 9, 18), 0.002, WOOD_FLOOR)
	_floor(finishes, "HistoryWood", Rect2(0, 0, 27, 6), 0.002, WOOD_FLOOR)
	_floor(finishes, "StaffWood", Rect2(27, 6, 9, 12), 0.002, WOOD_FLOOR)
	_floor(finishes, "ServiceWood", Rect2(27, 24, 9, 6), 0.002, WOOD_FLOOR)
	_floor(finishes, "StorageConcrete", Rect2(27, 18, 9, 6), 0.002, CONCRETE)
	_floor(finishes, "RestorationConcrete", Rect2(27, 18, 9, 12), 4.502, CONCRETE)


static func _floor(parent: Node3D, node_name: String, bounds: Rect2, y: float, mat: Material) -> void:
	var plane := PlaneMesh.new()
	plane.size = bounds.size
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = plane
	visual.material_override = mat
	visual.position = Vector3(bounds.get_center().x, y, bounds.get_center().y)
	parent.add_child(visual)
	visual.owner = parent.owner


static func _wall_finishes(scene: Node3D) -> void:
	var finishes := _replace_group(scene, "WallFinishes")
	# Only the room-facing upper-storey surfaces receive the gallery colours.
	# Shared walls and the ground floor retain their cream finish.
	for group in ["Exterior", "Floor2Rooms"]:
		for body in scene.get_node(group).get_children():
			var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
			if mesh == null or not mesh.mesh is BoxMesh:
				continue
			var bounds := AABB(body.position - mesh.mesh.size / 2.0, mesh.mesh.size)
			_room_wall_faces(finishes, str(body.name), bounds, Rect2(0.15, 6.15, 8.7, 17.7), SAGE)
			_room_wall_faces(finishes, str(body.name), bounds, Rect2(0.15, 0.15, 26.7, 5.7), BURGUNDY)


static func _room_wall_faces(parent: Node3D, prefix: String, wall: AABB,
		room: Rect2, mat: Material) -> void:
	var bottom := maxf(4.5, wall.position.y)
	var top := minf(9.0, wall.end.y)
	if top <= bottom:
		return
	var x0 := maxf(room.position.x, wall.position.x)
	var x1 := minf(room.end.x, wall.end.x)
	var z0 := maxf(room.position.y, wall.position.z)
	var z1 := minf(room.end.y, wall.end.z)
	var mid_y := (bottom + top) / 2.0
	if z1 > z0:
		if is_equal_approx(wall.end.x, room.position.x):
			_wall_face(parent, prefix, Vector2(z1-z0, top-bottom),
				Vector3(wall.end.x+0.002, mid_y, (z0+z1)/2), PI/2, mat)
		if is_equal_approx(wall.position.x, room.end.x):
			_wall_face(parent, prefix, Vector2(z1-z0, top-bottom),
				Vector3(wall.position.x-0.002, mid_y, (z0+z1)/2), -PI/2, mat)
	if x1 > x0:
		if is_equal_approx(wall.end.z, room.position.y):
			_wall_face(parent, prefix, Vector2(x1-x0, top-bottom),
				Vector3((x0+x1)/2, mid_y, wall.end.z+0.002), 0, mat)
		if is_equal_approx(wall.position.z, room.end.y):
			_wall_face(parent, prefix, Vector2(x1-x0, top-bottom),
				Vector3((x0+x1)/2, mid_y, wall.position.z-0.002), PI, mat)


static func _wall_face(parent: Node3D, prefix: String, size: Vector2,
		at: Vector3, yaw: float, mat: Material) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	var visual := MeshInstance3D.new()
	visual.name = prefix + "Finish%d" % parent.get_child_count()
	visual.mesh = quad
	visual.material_override = mat
	visual.position = at
	visual.rotation.y = yaw
	parent.add_child(visual)
	visual.owner = parent.owner


static func _replace_group(scene: Node3D, node_name: String) -> Node3D:
	var previous := scene.get_node_or_null(node_name)
	if previous:
		previous.free()
	var group := Node3D.new()
	group.name = node_name
	scene.add_child(group)
	group.owner = scene
	return group


static func _set_material(scene: Node, path: String, mat: Material) -> void:
	var mesh := scene.get_node_or_null(path) as MeshInstance3D
	if mesh and not mesh.get_meta("preserve_source_material", false):
		mesh.material_override = mat


static func _apply_tree(node: Node, mat: Material) -> void:
	if node.get_meta("preserve_source_material", false):
		return
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_tree(child, mat)
