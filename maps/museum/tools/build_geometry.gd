extends SceneTree

## Offline blockout builder. Replaces museum_geometry.tscn, never runs in gameplay.
## Edit this source before rebuilding; editor changes in the generated scene are overwritten.
const OUTPUT := "res://maps/museum/scenes/museum_geometry.tscn"
var geometry := Node3D.new()
var stone := material(Color(0.71, 0.67, 0.56))
var floor_mat := material(Color(0.38, 0.32, 0.25))
var upper_mat := material(Color(0.47, 0.37, 0.27))
var red := material(Color(0.39, 0.16, 0.16))
var blue := material(Color(0.24, 0.34, 0.37))
var green := material(Color(0.22, 0.32, 0.23))
var brass := material(Color(0.63, 0.47, 0.21))


func _initialize() -> void:
	_build.call_deferred()


func material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.85
	return mat


func attach(parent: Node, node: Node, node_name: String) -> void:
	node.name = node_name
	parent.add_child(node)
	node.owner = geometry


func group(node_name: String) -> Node3D:
	var node := Node3D.new()
	attach(geometry, node, node_name)
	return node


func box(parent: Node, node_name: String, size: Vector3, at: Vector3,
		mat: Material, angles := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	attach(parent, body, node_name)
	body.position = at
	body.rotation = angles
	body.collision_layer = 1
	body.collision_mask = 0
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	cube.material = mat
	mesh.mesh = cube
	attach(body, mesh, "Mesh")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	attach(body, collision, "Collision")
	return body


func slab(parent: Node, node_name: String, x0: float, x1: float, z0: float,
		z1: float, y: float, mat: Material) -> void:
	box(parent, node_name, Vector3(x1-x0, 0.3, z1-z0),
		Vector3((x0+x1)/2, y-0.15, (z0+z1)/2), mat)


## axis_x means a wall along X with fixed Z. openings = [centre, width].
func wall(parent: Node, node_name: String, axis_x: bool, fixed: float,
		start: float, end: float, base: float, openings: Array = [],
		height := 4.5, mat: Material = null) -> void:
	if mat == null:
		mat = stone
	var cursor := start
	var index := 0
	for opening in openings:
		var lo: float = opening[0] - opening[1]/2.0
		var hi: float = opening[0] + opening[1]/2.0
		wall_segment(parent, node_name + "_%d" % index, axis_x, fixed, cursor, lo, base, height, mat)
		wall_segment(parent, node_name + "_Lintel%d" % index, axis_x, fixed, lo, hi, base+2.8, height-2.8, mat)
		cursor = hi
		index += 1
	wall_segment(parent, node_name + "_%d" % index, axis_x, fixed, cursor, end, base, height, mat)


func wall_segment(parent: Node, node_name: String, axis_x: bool, fixed: float,
		start: float, end: float, base: float, height: float, mat: Material) -> void:
	if end-start < 0.01 or height < 0.01:
		return
	var size := Vector3(end-start, height, 0.3) if axis_x else Vector3(0.3, height, end-start)
	var at := Vector3((start+end)/2, base+height/2, fixed) if axis_x else Vector3(fixed, base+height/2, (start+end)/2)
	box(parent, node_name, size, at, mat)


func label(parent: Node, node_name: String, caption: String, at: Vector3, yaw := 0.0) -> void:
	var sign := Label3D.new()
	attach(parent, sign, node_name)
	sign.position = at
	sign.rotation.y = yaw
	sign.text = caption
	sign.font_size = 64
	sign.pixel_size = 0.006
	sign.outline_size = 12
	sign.modulate = Color(1, 0.89, 0.65)


func ramp(parent: Node, node_name: String, start: Vector3, end: Vector3) -> void:
	var delta := end-start
	var angle := atan2(delta.y, delta.x)
	# For decreasing X use the equivalent slope, keeping the top face upward.
	if absf(angle) > PI/2:
		angle -= signf(angle)*PI
	var normal := Vector3(-sin(angle), cos(angle), 0)
	box(parent, node_name, Vector3(delta.length(), 0.16, 2.2),
		(start+end)/2-normal*0.08, upper_mat, Vector3(0, 0, angle))


func stairs(node_name: String, mirror: bool) -> void:
	var stair := group(node_name)
	# A: lower east->west, midlanding, upper west->east. B mirrors in X.
	var low_start := Vector3(7, 0, 28.25)
	var low_end := Vector3(2, 2.25, 28.25)
	var high_start := Vector3(2, 2.25, 25.75)
	var high_end := Vector3(7, 4.5, 25.75)
	if mirror:
		low_start = Vector3(29, 0, 4.25)
		low_end = Vector3(34, 2.25, 4.25)
		high_start = Vector3(34, 2.25, 1.75)
		high_end = Vector3(29, 4.5, 1.75)
	ramp(stair, "LowerRamp", low_start, low_end)
	ramp(stair, "UpperRamp", high_start, high_end)
	if mirror:
		slab(stair, "MidLanding", 34, 35.6, 0.65, 5.35, 2.25, upper_mat)
	else:
		slab(stair, "MidLanding", 0.4, 2, 24.65, 29.35, 2.25, upper_mat)
	# Solid centre divider prevents cutting sideways between flights at different heights.
	box(stair, "CentreDivider", Vector3(5, 5.7, 0.3),
		Vector3(31.5, 2.85, 3) if mirror else Vector3(4.5, 2.85, 27), stone)
	# Upper vestibule cannot drop into lower flight; upper flight remains open.
	box(stair, "UpperLandingRail", Vector3(0.16, 1.2, 3),
		Vector3(29, 5.1, 4.5) if mirror else Vector3(7, 5.1, 28.5), brass)
	# Rails along the outer edges of both inclined flights.
	for i in 2:
		var a := low_start if i == 0 else high_start
		var b := low_end if i == 0 else high_end
		var slope := atan2((b-a).y, (b-a).x)
		if absf(slope) > PI/2:
			slope -= signf(slope)*PI
		var p := (a+b)/2 + Vector3(0, 0.7, 1.18 if i == 0 else -1.18)
		box(stair, "SlopeRail%d" % i, Vector3((b-a).length(), 1.2, 0.12), p, brass, Vector3(0,0,slope))


func _build() -> void:
	geometry.name = "Geometry"
	var floors := group("Floors")
	slab(floors, "Ground", 0, 36, 0, 30, 0, floor_mat)
	# Rectangular bands split at the courtyard and both full-height stair openings.
	slab(floors, "UpperNorthMain", 0, 27, 0, 9, 4.5, upper_mat)
	slab(floors, "UpperNorthEastRing", 27, 36, 6, 9, 4.5, upper_mat)
	slab(floors, "UpperStairBEntrance", 27, 29, 0, 6, 4.5, upper_mat)
	slab(floors, "UpperSouthMain", 9, 36, 21, 30, 4.5, upper_mat)
	slab(floors, "UpperSouthWestRing", 0, 9, 21, 24, 4.5, upper_mat)
	slab(floors, "UpperStairAEntrance", 7, 9, 24, 30, 4.5, upper_mat)
	slab(floors, "UpperWestMiddle", 0, 12, 9, 21, 4.5, upper_mat)
	slab(floors, "UpperEastMiddle", 24, 36, 9, 21, 4.5, upper_mat)
	var exterior := group("Exterior")
	wall(exterior, "North", true, 0, 0, 36, 0, [], 9)
	wall(exterior, "West", false, 0, 0, 30, 0, [], 9)
	wall(exterior, "SouthGround", true, 30, 0, 36, 0, [[18, 2]])
	wall(exterior, "SouthUpper", true, 30, 0, 36, 4.5)
	wall(exterior, "EastGround", false, 36, 0, 30, 0)
	wall(exterior, "EastUpper", false, 36, 0, 30, 4.5, [[27, 1.6]])
	box(exterior, "EntranceSecured", Vector3(2, 2.8, 0.2), Vector3(18,1.4,30), blue)
	# Window sill blocks walking off the building; E is the controlled rope exit.
	box(exterior, "EscapeSill", Vector3(0.3, 1.0, 1.6), Vector3(36,5,27), stone)
	slab(exterior, "OutsideLanding", 36, 41, 24, 30, 0, blue)
	for floor_index in 2:
		var y := 4.5 * floor_index
		var rooms := group("Floor%dRooms" % (floor_index+1))
		var mat := stone if floor_index == 0 else red
		wall(rooms, "NorthPartition", true, 6, 0, 36, y, [[15,2],[23,2]], 4.5, mat)
		wall(rooms, "StairBPartition", false, 27, 0, 6, y, [[3,2]])
		wall(rooms, "WestPartition", false, 9, 6, 24, y, [[9,1.6],[19,1.6]], 4.5, mat)
		wall(rooms, "SouthPartition", true, 24, 0, 27, y, [[18,2.4]])
		wall(rooms, "StairAPartition", false, 9, 24, 30, y, [[27,1.6]])
		wall(rooms, "EastSouthPartition", false, 27, 24, 30, y, [[27,1.6]])
		if floor_index == 0:
			wall(rooms, "StaffPartition", false, 27, 6, 18, y, [[10,1.6],[15,1.6]])
			wall(rooms, "StorePartition", false, 27, 18, 24, y, [[21,1.6]])
			wall(rooms, "StaffSouth", true, 18, 27, 36, y)
			wall(rooms, "ServiceNorth", true, 24, 27, 36, y)
		else:
			wall(rooms, "GalleryBPartition", false, 27, 6, 18, y, [[10,1.6]], 4.5, red)
			wall(rooms, "RestorationWest", false, 27, 18, 24, y)
			wall(rooms, "ShortcutPartition", true, 18, 27, 36, y, [[32,1.6]])
	var courtyard := group("Courtyard")
	# Low perimeter gives ground-floor cover; the south arch is the sole entrance.
	wall(courtyard, "GroundNorth", true, 9, 12, 24, 0, [], 1.2, green)
	wall(courtyard, "GroundWest", false, 12, 9, 21, 0, [], 1.2, green)
	wall(courtyard, "GroundEast", false, 24, 9, 21, 0, [], 1.2, green)
	wall(courtyard, "GroundSouth", true, 21, 12, 24, 0, [[18,2]], 1.2, green)
	wall(courtyard, "UpperRailNorth", true, 9, 12, 24, 4.5, [], 1.2, brass)
	wall(courtyard, "UpperRailSouth", true, 21, 12, 24, 4.5, [], 1.2, brass)
	wall(courtyard, "UpperRailWest", false, 12, 9, 21, 4.5, [], 1.2, brass)
	wall(courtyard, "UpperRailEast", false, 24, 9, 21, 4.5, [], 1.2, brass)
	box(courtyard, "FountainBase", Vector3(3,0.6,3), Vector3(18,0.3,15), blue)
	for p in [Vector3(14,0.6,11), Vector3(22,0.6,11), Vector3(14,0.6,19), Vector3(22,0.6,19)]:
		box(courtyard, "Planter%d" % courtyard.get_child_count(), Vector3(1.3,1.2,1.3), p, green)
	stairs("StairA", false)
	stairs("StairB", true)
	var covers := group("Cover")
	for floor_index in 2:
		var y := floor_index*4.5
		box(covers, "WestNorth%d" % floor_index, Vector3(2.2,1.2,3), Vector3(4.3,y+0.6,11.5), blue)
		box(covers, "WestSouth%d" % floor_index, Vector3(2.2,1.2,3), Vector3(4.3,y+0.6,18), blue)
		box(covers, "NorthWest%d" % floor_index, Vector3(3.4,1.2,1.4), Vector3(10.5,y+0.6,2.8), blue)
		box(covers, "NorthEast%d" % floor_index, Vector3(3.4,1.2,1.4), Vector3(22,y+0.6,2.8), blue)
	box(covers, "StaffDesk", Vector3(2.8,0.7,1.4), Vector3(31.5,0.35,11), blue)
	box(covers, "GalleryBPlinth", Vector3(2.4,1.2,3), Vector3(31.3,5.1,12), blue)
	box(covers, "RestorationWest", Vector3(1.8,1.2,3), Vector3(29.6,5.1,21.8), blue)
	box(covers, "RestorationEast", Vector3(1.8,1.2,3), Vector3(34.2,5.1,21.8), blue)
	var signs := group("Signs")
	label(signs, "Welcome", "BẢO TÀNG · SẢNH\nK: phía đông tầng 1  |  A/B: lối lên tầng 2", Vector3(18,3.2,24.2))
	label(signs, "A0", "THANG A · LÊN TẦNG 2", Vector3(9.2,3.1,27), PI/2)
	label(signs, "A1", "THANG A · XUỐNG TẦNG 1", Vector3(9.2,7.6,27), PI/2)
	label(signs, "B0", "THANG B · LÊN TẦNG 2", Vector3(26.8,3.1,3), -PI/2)
	label(signs, "B1", "THANG B · XUỐNG TẦNG 1", Vector3(26.8,7.6,3), -PI/2)
	label(signs, "Staff", "NHÂN VIÊN · CHÌA K", Vector3(26.8,3.1,10), -PI/2)
	label(signs, "GalleryA", "PHÒNG A · T1", Vector3(9.2,7.6,9), PI/2)
	label(signs, "GalleryB", "PHÒNG B · T2 · CẦN K", Vector3(26.8,7.6,10), -PI/2)
	label(signs, "GalleryC", "PHÒNG C · T3", Vector3(15,7.6,6.2))
	label(signs, "Restoration", "KHO PHỤC CHẾ · DÂY / LỐI THOÁT", Vector3(26.8,7.6,27), -PI/2)
	var packed := PackedScene.new()
	var error := packed.pack(geometry)
	if error == OK:
		error = ResourceSaver.save(packed, OUTPUT)
	geometry.free()
	if error != OK:
		push_error("Museum geometry save failed: %d" % error)
		quit(1)
		return
	print("Built full museum geometry: ", OUTPUT)
	quit(0)
