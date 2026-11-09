extends SceneTree

## Offline blockout builder. Replaces museum_geometry.tscn, never runs in gameplay.
## Edit this source before rebuilding; editor changes in the generated scene are overwritten.
const OUTPUT := "res://maps/isg_museum/scenes/museum_geometry.tscn"
const Palette := preload("res://maps/isg_museum/tools/material_palette.gd")
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


func front_yard() -> void:
	var yard := group("FrontYard")
	slab(yard, "Ground", 0, 36, 30, 38, 0, green)
	# Flush visual path; walking collision stays on the continuous ground slab.
	var path_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3, 8)
	plane.material = stone
	path_mesh.mesh = plane
	attach(yard, path_mesh, "Walkway")
	path_mesh.position = Vector3(18, 0.003, 34)
	box(yard, "FenceWest", Vector3(0.3,1.3,8), Vector3(0.15,0.65,34), stone)
	box(yard, "FenceEast", Vector3(0.3,1.3,8), Vector3(35.85,0.65,34), stone)
	wall_segment(yard, "FenceSouthWest", true, 37.85, 0, 16.5, 0, 1.3, stone)
	wall_segment(yard, "FenceSouthEast", true, 37.85, 19.5, 36, 0, 1.3, stone)
	box(yard, "ClosedStreetGate", Vector3(3,1.3,0.2), Vector3(18,0.65,37.85), blue)
	for p in [Vector3(6,0.4,34),Vector3(11,0.4,34),Vector3(25,0.4,34),Vector3(30,0.4,34)]:
		box(yard, "Planter%d" % yard.get_child_count(), Vector3(1.4,0.8,1.4), p, green)
	label(yard, "EntranceSign", "BẢO TÀNG · CỬA CHÍNH", Vector3(18,3.2,30.2))
	label(yard, "GateSign", "CỔNG SÂN", Vector3(18,1.7,37.65), PI)
	for x in [16.4,19.6]:
		box(yard, "LampPost%d" % yard.get_child_count(), Vector3(0.12,1.4,0.12), Vector3(x,0.7,31), brass)
		var lamp := OmniLight3D.new()
		attach(yard,lamp,"EntranceLight%d" % yard.get_child_count())
		lamp.position = Vector3(x,1.6,31)
		lamp.light_color = Color(1,0.82,0.57)
		lamp.light_energy = 1.2
		lamp.omni_range = 5


func courtyard_ground(courtyard: Node3D) -> void:
	# Four 2 m openings share clear, level paths through the centre.
	wall(courtyard, "GroundNorth", true, 9, 12, 24, 0, [[18,2]], 1.2, green)
	wall(courtyard, "GroundSouth", true, 21, 12, 24, 0, [[18,2]], 1.2, green)
	wall(courtyard, "GroundWest", false, 12, 9, 21, 0, [[15,2]], 1.2, green)
	wall(courtyard, "GroundEast", false, 24, 9, 21, 0, [[15,2]], 1.2, green)
	box(courtyard, "FountainBase", Vector3(3,0.6,3), Vector3(18,0.3,15), blue)
	var planter_index := 0
	for p in [Vector3(14,0.6,11), Vector3(22,0.6,11), Vector3(14,0.6,19), Vector3(22,0.6,19)]:
		box(courtyard, "Planter%d" % planter_index, Vector3(1.3,1.2,1.3), p, green)
		planter_index += 1
	# Visual surfaces only: the existing ground slab provides seamless collision.
	for patch in [Vector3(14.6,0.003,11.6),Vector3(21.4,0.003,11.6),Vector3(14.6,0.003,18.4),Vector3(21.4,0.003,18.4)]:
		courtyard_surface(courtyard,"Garden%d" % courtyard.get_child_count(),Vector2(4.8,4.8),patch,green)
	courtyard_surface(courtyard,"PathNorth",Vector2(2,3),Vector3(18,0.004,10.5),stone)
	courtyard_surface(courtyard,"PathSouth",Vector2(2,3),Vector3(18,0.004,19.5),stone)
	courtyard_surface(courtyard,"PathWest",Vector2(3,2),Vector3(13.5,0.004,15),stone)
	courtyard_surface(courtyard,"PathEast",Vector2(3,2),Vector3(22.5,0.004,15),stone)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for segment in 96:
		var a := TAU * segment / 96.0
		var b := TAU * (segment+1) / 96.0
		var inner_a := Vector3(cos(a)*2.2,0.006,sin(a)*2.2)
		var outer_a := Vector3(cos(a)*4.0,0.006,sin(a)*4.0)
		var inner_b := Vector3(cos(b)*2.2,0.006,sin(b)*2.2)
		var outer_b := Vector3(cos(b)*4.0,0.006,sin(b)*4.0)
		for vertex in [inner_a,outer_a,outer_b,inner_a,outer_b,inner_b]:
			vertices.append(vertex)
			normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var ring_mesh := ArrayMesh.new()
	ring_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	ring_mesh.surface_set_material(0,stone)
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	attach(courtyard,ring,"PathRing")
	ring.position = Vector3(18,0,15)


func courtyard_surface(parent: Node, node_name: String, size: Vector2, at: Vector3, mat: Material) -> void:
	var surface := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	plane.material = mat
	surface.mesh = plane
	attach(parent,surface,node_name)
	surface.position = at


func staff_interior() -> void:
	var room := group("StaffInterior")
	var wood := material(Color(0.3,0.17,0.085))
	var paper := material(Color(0.87,0.81,0.65))
	var metal := material(Color(0.28,0.32,0.3))
	# A: one long, solid-front desk. Standing heads remain visible; crouching is covered.
	box(room,"Desk",Vector3(1.4,1.1,4.6),Vector3(32.2,0.55,12),wood)
	staff_visual(room,"DeskTop",Vector3(1.48,0.08,4.68),Vector3(32.2,1.06,12),wood)
	staff_visual(room,"ModestyPanel_A",Vector3(0.06,1.0,4.4),Vector3(31.49,0.5,12),wood)
	# D: the key is on the locker frontage, never on the desk.
	box(room,"Lockers",Vector3(0.6,2.0,4.8),Vector3(35.4,1.0,12),metal)
	for z in [10.4,12,13.6]:
		staff_visual(room,"LockerHandle%d"%room.get_child_count(),Vector3(0.06,0.12,0.06),Vector3(35.06,1.1,z),brass)
	staff_visual(room,"KeyRack_D",Vector3(0.08,0.15,0.55),Vector3(35.06,1.2,10.2),wood)
	staff_visual(room,"KeyLabel",Vector3(.04,.3,.78),Vector3(35.04,1.65,10.2),paper)
	label(room,"KeyLabelText","CHÌA KHÓA PHÒNG B\nTẦNG 2",Vector3(35.012,1.65,10.2),-PI/2)
	room.get_node("KeyLabelText").font_size = 36
	room.get_node("KeyLabelText").pixel_size = .0012
	room.get_node("KeyLabelText").modulate = Color(.18,.15,.1)
	room.get_node("KeyLabelText").outline_size = 0
	# B: chair behind the desk; visual-only, with clear standing/circulation space.
	staff_visual(room,"ChairSeat",Vector3(0.65,0.12,0.65),Vector3(34.1,0.47,12),wood)
	staff_visual(room,"ChairBack",Vector3(0.15,0.8,0.65),Vector3(34.5,0.88,12),wood)
	for x in [33.85,34.35]:
		for z in [11.75,12.25]:
			staff_visual(room,"ChairLeg%d"%room.get_child_count(),Vector3(0.07,0.4,0.07),Vector3(x,0.2,z),metal)
	staff_visual(room,"Radio",Vector3(0.18,0.28,0.14),Vector3(32.3,1.27,13.4),metal)
	staff_visual(room,"RadioAntenna",Vector3(0.02,0.28,0.02),Vector3(32.35,1.52,13.4),metal)
	staff_visual(room,"LampBase",Vector3(0.25,0.06,0.25),Vector3(32.2,1.14,10.4),brass)
	staff_visual(room,"LampStem",Vector3(0.04,0.4,0.04),Vector3(32.2,1.36,10.4),brass)
	staff_visual(room,"LampShade",Vector3(0.35,0.12,0.25),Vector3(32.2,1.59,10.4),brass)
	var light := OmniLight3D.new()
	attach(room,light,"DeskLight")
	light.position = Vector3(32.2,1.55,10.6)
	light.light_color = Color(1,0.8,0.5)
	light.light_energy = 0.8
	light.omni_range = 4
	# C stays on the west wall; G is a small loose paper on desk A.
	staff_readable(room,"MaintenanceBoard","Lịch treo tường","","LỊCH THÁNG",Vector3(27.3,1.5,16),PI/2,paper,
		"res://maps/isg_museum/scripts/staff_calendar.gd")
	staff_readable(room,"CodeNote","G · Mảnh ghi chú",
		"Mã kho là ngày hôm nay.\n\nViết ngày trước, tháng sau: DDMM.",
		"G · GHI CHÚ\nDDMM",Vector3(32.2,1.112,11),0,paper)
	var note := room.get_node("CodeNote") as Node3D
	note.scale = Vector3.ONE*0.25
	note.rotation.x = -PI/2
	var note_mesh := note.get_node("Board").mesh as BoxMesh
	note_mesh.size.z = 0.012
	for pos in [Vector3(34.7,0,14.9),Vector3(34.8,0,15.4)]:
		var prop := Area3D.new()
		attach(room,prop,"NoisyBottle%d"%room.get_child_count())
		prop.position = pos
		prop.set_script(load("res://maps/isg_museum/scripts/staff_noise_prop.gd"))
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(0.65,0.65,0.65)
		shape.shape = box_shape
		shape.position.y = 0.3
		attach(prop,shape,"Trigger")
		var bottle := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.065
		cylinder.bottom_radius = 0.075
		cylinder.height = 0.32
		cylinder.material = green
		bottle.mesh = cylinder
		attach(prop,bottle,"Bottle")
		bottle.position.y = 0.09
		bottle.rotation.z = PI/2
		staff_visual(prop,"Label",Vector3(0.13,0.15,0.17),Vector3(0,0.09,0),brass)


func staff_visual(parent: Node,node_name: String,size: Vector3,at: Vector3,mat: Material) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	visual.mesh = mesh
	attach(parent,visual,node_name)
	visual.position = at


func staff_readable(parent: Node,node_name: String,title: String,content: String,caption: String,at: Vector3,yaw: float,mat: Material,
		script_path := "res://maps/isg_museum/scripts/staff_document.gd") -> void:
	var document := Area3D.new()
	attach(parent,document,node_name)
	document.position = at
	document.rotation.y = yaw
	document.set_script(load(script_path))
	document.set("title",title)
	document.set("content",content)
	document.set("prompt","Đọc " + title.to_lower())
	staff_visual(document,"Board",Vector3(1.3,0.95,0.08),Vector3.ZERO,mat)
	var shape := CollisionShape3D.new()
	var form := BoxShape3D.new()
	form.size = Vector3(1.4,1.05,0.22)
	shape.shape = form
	attach(document,shape,"CollisionShape3D")
	var text := Label3D.new()
	attach(document,text,"Text")
	text.position.z = 0.055
	text.text = caption
	text.font_size = 40
	text.pixel_size = 0.0017
	text.modulate = Color(0.15,0.12,0.08)
	text.outline_size = 0


func storage_interior() -> void:
	# Existing room X=27..36, Z=18..24; concept rotated to face west entrance.
	var room := group("StorageInterior")
	var metal := material(Color(0.22,0.29,0.25))
	var paper := material(Color(0.86,0.8,0.64))
	var wood := material(Color(0.34,0.23,0.12))
	box(room,"ToolShelves",Vector3(4.1,2.15,0.7),Vector3(31,1.075,18.65),metal)
	for y in [0.35,0.95,1.55,2.12]:
		staff_visual(room,"Shelf%d"%room.get_child_count(),Vector3(4.2,0.07,0.82),Vector3(31,y,18.95),wood)
		for x in [29.5,30.4,31.5,32.5]:
			staff_visual(room,"ToolBox%d"%room.get_child_count(),Vector3(0.5,0.3,0.35),Vector3(x,y+0.18,19.04),brass if x < 31 else green)
	box(room,"SteelCabinet",Vector3(3.4,2.2,0.65),Vector3(31.5,1.1,23.525),metal)
	staff_visual(room,"CabinetDoor",Vector3(1.15,2.1,0.06),Vector3(32.65,1.1,23.165),green)
	staff_visual(room,"CabinetHandle",Vector3(0.06,0.22,0.08),Vector3(32.2,1.1,23.095),brass)
	staff_visual(room,"RopeRack",Vector3(0.12,0.2,1.7),Vector3(35.65,1.95,20.6),wood)
	for z in [20.2,20.6,21.0]:
		staff_visual(room,"Hook%d"%room.get_child_count(),Vector3(0.25,0.12,0.06),Vector3(35.47,1.96,z),brass)
	label(room,"RopeSign","DÂY THOÁT HIỂM",Vector3(35.62,2.65,20.6),-PI/2)
	room.get_node("RopeSign").pixel_size = 0.0025
	staff_visual(room,"EquipmentBag",Vector3(0.42,0.6,0.5),Vector3(35.5,1.3,22),wood)
	var light := OmniLight3D.new()
	attach(room,light,"UtilityLight")
	light.position = Vector3(31.5,3.4,21)
	light.light_color = Color(1,0.83,0.6)
	light.light_energy = 1.3
	light.omni_range = 7
	staff_visual(room,"Lamp",Vector3(0.5,0.12,0.5),Vector3(31.5,3.6,21),brass)
	label(room,"StorageSign","KHO PHỤ · KHÓA MÃ",Vector3(26.79,3.1,21),-PI/2)
	room.get_node("StorageSign").pixel_size = 0.0025
	staff_visual(room,"KeypadBacking",Vector3(0.09,0.42,0.29),Vector3(26.78,1.45,19.9),metal)
	staff_visual(room,"KeypadScreen",Vector3(0.03,0.075,0.21),Vector3(26.72,1.58,19.9),green)
	for y in 4:
		for z in 3:
			staff_visual(room,"Key%d%d"%[y,z],Vector3(0.035,0.042,0.045),Vector3(26.715,1.46-y*0.06,19.83+z*0.07),paper)


func _build() -> void:
	if "--update-feedback" in OS.get_cmdline_user_args():
		geometry.free()
		geometry = (load(OUTPUT) as PackedScene).instantiate()
		geometry.get_node("StaffInterior").free()
		geometry.get_node("StorageInterior").free()
		staff_interior()
		storage_interior()
		var rooms := geometry.get_node("Floor2Rooms")
		for child in rooms.get_children():
			if str(child.name).begins_with("ShortcutPartition"):
				child.free()
		wall(rooms,"ShortcutPartition",true,18,27,36,4.5,[],4.5,red)
		save_geometry()
		return
	if "--update-storage" in OS.get_cmdline_user_args():
		geometry.free()
		geometry = (load(OUTPUT) as PackedScene).instantiate()
		var previous := geometry.get_node_or_null("StorageInterior")
		if previous:
			previous.free()
		storage_interior()
		geometry.get_node("Signs/Restoration").text = "KHO PHỤC CHẾ · TẬP KẾT T2 / LỐI THOÁT"
		save_geometry()
		return
	if "--update-staff-interior" in OS.get_cmdline_user_args():
		geometry.free()
		geometry = (load(OUTPUT) as PackedScene).instantiate()
		var previous := geometry.get_node_or_null("StaffInterior")
		if previous:
			previous.free()
		var desk := geometry.get_node_or_null("Cover/StaffDesk")
		if desk:
			desk.free()
		staff_interior()
		save_geometry()
		return
	if "--update-staff" in OS.get_cmdline_user_args():
		geometry.free()
		geometry = (load(OUTPUT) as PackedScene).instantiate()
		var rooms := geometry.get_node("Floor1Rooms") as Node3D
		for child in rooms.get_children():
			if str(child.name).begins_with("StaffPartition"):
				child.free()
		wall(rooms,"StaffPartition",false,27,6,18,0,[[10,1.6]])
		save_geometry()
		return
	# Patch only the courtyard; preserve authored rooms, stairs, yard and upper rails.
	if "--update-courtyard" in OS.get_cmdline_user_args():
		geometry.free()
		geometry = (load(OUTPUT) as PackedScene).instantiate()
		var existing := geometry.get_node("Courtyard") as Node3D
		for child in existing.get_children():
			if str(child.name).begins_with("Ground") or str(child.name).begins_with("Planter") \
					or str(child.name).begins_with("Garden") or str(child.name).begins_with("Path") \
					or child.name == &"FountainBase":
				child.free()
		courtyard_ground(existing)
		save_geometry()
		return
	# Patch the existing authored interior for this migration. A normal builder
	# run also includes the yard, so future regeneration keeps the new start.
	if "--update-entrance" in OS.get_cmdline_user_args():
		geometry.free()
		geometry = (load(OUTPUT) as PackedScene).instantiate()
		var secured := geometry.get_node_or_null("Exterior/EntranceSecured")
		if secured:
			secured.free()
		var previous_yard := geometry.get_node_or_null("FrontYard")
		if previous_yard:
			previous_yard.free()
		front_yard()
		save_geometry()
		return
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
			wall(rooms, "StaffPartition", false, 27, 6, 18, y, [[10,1.6]])
			wall(rooms, "StorePartition", false, 27, 18, 24, y, [[21,1.6]])
			wall(rooms, "StaffSouth", true, 18, 27, 36, y)
			wall(rooms, "ServiceNorth", true, 24, 27, 36, y)
		else:
			wall(rooms, "GalleryBPartition", false, 27, 6, 18, y, [[10,1.6]], 4.5, red)
			wall(rooms, "RestorationWest", false, 27, 18, 24, y)
			wall(rooms, "ShortcutPartition", true, 18, 27, 36, y, [], 4.5, red)
	var courtyard := group("Courtyard")
	courtyard_ground(courtyard)
	wall(courtyard, "UpperRailNorth", true, 9, 12, 24, 4.5, [], 1.2, brass)
	wall(courtyard, "UpperRailSouth", true, 21, 12, 24, 4.5, [], 1.2, brass)
	wall(courtyard, "UpperRailWest", false, 12, 9, 21, 4.5, [], 1.2, brass)
	wall(courtyard, "UpperRailEast", false, 24, 9, 21, 4.5, [], 1.2, brass)
	stairs("StairA", false)
	stairs("StairB", true)
	var covers := group("Cover")
	for floor_index in 2:
		var y := floor_index*4.5
		box(covers, "WestNorth%d" % floor_index, Vector3(2.2,1.2,3), Vector3(4.3,y+0.6,11.5), blue)
		box(covers, "WestSouth%d" % floor_index, Vector3(2.2,1.2,3), Vector3(4.3,y+0.6,18), blue)
		box(covers, "NorthWest%d" % floor_index, Vector3(3.4,1.2,1.4), Vector3(10.5,y+0.6,2.8), blue)
		box(covers, "NorthEast%d" % floor_index, Vector3(3.4,1.2,1.4), Vector3(22,y+0.6,2.8), blue)
	staff_interior()
	storage_interior()
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
	label(signs, "Restoration", "KHO PHỤC CHẾ · TẬP KẾT T2 / LỐI THOÁT", Vector3(26.8,7.6,27), -PI/2)
	front_yard()
	save_geometry()


func save_geometry() -> void:
	Palette.apply_geometry(geometry)
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
