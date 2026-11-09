extends SceneTree

## Development tool: builds the Morning Grocery graybox, bakes its navigation mesh and saves
##   res://maps/grocery/scenes/grocery_morning.tscn
##   res://maps/grocery/resources/grocery_navmesh.tres
## Run from the project folder:
##   godot --headless --path . --script res://maps/grocery/tools/build_grocery.gd
## Exits with code 0 on success and 1 on failure.
##
## While the map is a graybox this tool is the source of truth for the layout: change the data
## below and rebuild instead of editing the scene by hand. Conventions follow the Museum and
## Library scenes: every solid piece is a StaticBody3D on layer 1 with a "Mesh" and a "Shape"
## child, all level geometry sits under NavigationRegion3D (the navmesh is baked from static
## colliders; meshes without a collider, such as the dressing, are ignored), and the player and
## NPCs are instances of the shared scenes.
##
## A big American supermarket, 80 x 44 m under a 6 m roof (metres; x east, z south):
##   street          z 14..20   spawn at (0, 17); the entrance is a 6 m gap in the front wall
##   front end       z 8..14    four checkout lanes (cashiers walk behind them), customer service
##   produce         x -38..-8, z 3..11 (tables); seasonal pallets on the east side
##   aisles          11 double-sided gondolas along z (x -30..30 every 6 m): 10 aisles, with a
##                   cross aisle at z -10; dairy cases at the north end of the west aisles
##   walls           deli counter (west), meat counter (north-east), freezers (east)
##   back of house   stock room x -40..-6, z -30..-24 (pallet racks, door into the store)
##   exits           stock-room door (north wall, x -20) and back door (east wall, z -12)

const SCENE_PATH := "res://maps/grocery/scenes/grocery_morning.tscn"
const NAVMESH_PATH := "res://maps/grocery/resources/grocery_navmesh.tres"
const PLAYER_SCENE := "res://shared/scenes/player/player.tscn"
const GUARD_SCENE := "res://shared/scenes/npc/guard.tscn"

const X_MIN := -40.0
const X_MAX := 40.0
const Z_MIN := -30.0
const FRONT_Z := 14.0
const Z_MAX := 20.0
const WALL_H := 6.0
const WALL_T := 0.4
const ROOF_T := 0.3

const C_ROOF := Color(0.45, 0.45, 0.48)
const C_ROOF_TRIM := Color(0.8, 0.78, 0.72)
const C_CANOPY := Color(0.2, 0.5, 0.35)
const C_GLASS := Color(0.6, 0.8, 0.95, 0.22)
const C_FLOOR := Color(0.74, 0.72, 0.66)
const C_STREET := Color(0.42, 0.43, 0.45)
const C_WALL := Color(0.9, 0.87, 0.8)
const C_STOCK_WALL := Color(0.72, 0.68, 0.6)
const C_SHELF := Color(0.55, 0.38, 0.24)
const C_WALL_SHELF := Color(0.42, 0.3, 0.2)
const C_COUNTER := Color(0.35, 0.5, 0.62)
const C_FRIDGE := Color(0.82, 0.9, 0.95)
const C_DELI := Color(0.85, 0.82, 0.78)
const C_MEAT := Color(0.8, 0.5, 0.5)
const C_CRATE := Color(0.6, 0.45, 0.27)
const C_RACK := Color(0.3, 0.4, 0.6)
const C_DOOR := Color(0.3, 0.32, 0.36)
const C_STOCK_DOOR := Color(0.4, 0.3, 0.22)
const C_TABLE := Color(0.6, 0.5, 0.35)
const PRODUCT_COLOURS := [Color(0.85, 0.25, 0.2), Color(0.95, 0.75, 0.2), Color(0.25, 0.6, 0.85),
	Color(0.3, 0.7, 0.35), Color(0.9, 0.9, 0.85), Color(0.7, 0.35, 0.6), Color(0.95, 0.5, 0.15)]

## Double-sided gondolas along z: centre x of each, and the z spans of its two segments
## (a cross aisle between them at z -12..-8; the north end leaves room for the dairy lane).
const GONDOLA_X := [-30.0, -24.0, -18.0, -12.0, -6.0, 0.0, 6.0, 12.0, 18.0, 24.0, 30.0]
const GONDOLA_SPANS := [[-21.0, -12.0], [-8.0, 1.0]]
const GONDOLA_W := 1.2
const GONDOLA_H := 2.0

const WALL_SHELF_H := 2.6
## Tall shelves against the walls (centre x / z and size x / z). Those along z face +x or -x,
## those along x face +z.
const WALL_SHELVES := [
	{"name": "WestFrontShelves", "x": -39.4, "z": 7.75, "sx": 0.8, "sz": 9.5},
	{"name": "WestDairyShelves", "x": -39.4, "z": -17.5, "sx": 0.8, "sz": 9.0},
	{"name": "NorthEastShelves", "x": 33.5, "z": -29.4, "sx": 11.0, "sz": 0.8},
	{"name": "EastFrontShelves", "x": 39.4, "z": 7.75, "sx": 0.8, "sz": 9.5},
]

## Where the target can lie (marker positions = the item's resting point).
const LOOT_SPOTS := [
	Vector3(-24.0, 2.0, -4.0), Vector3(-12.0, 2.0, -16.5), Vector3(0.0, 2.0, -4.0),
	Vector3(12.0, 2.0, -16.5), Vector3(24.0, 2.0, -4.0), Vector3(30.0, 2.0, -16.5),
	Vector3(-38.2, 1.15, -5.0), Vector3(14.0, 1.2, -28.8), Vector3(-22.0, 1.05, 9.0),
	Vector3(20.0, 1.55, 5.5), Vector3(12.0, 1.2, 11.8), Vector3(-28.0, 2.2, -23.4),
	Vector3(-39.4, 2.6, -17.5), Vector3(-36.0, 2.4, -28.6), Vector3(39.2, 2.2, -20.0),
]

## name, role ("staff" / "customer"), speed, [start, end] on the navmesh, wait at each end.
const WALKERS := [
	{"name": "CashierA", "role": "staff", "speed": 1.4, "points": [Vector3(8.5, 0, 13.05), Vector3(18.5, 0, 13.05)], "wait": 5.0},
	{"name": "CashierB", "role": "staff", "speed": 1.4, "points": [Vector3(22.5, 0, 13.05), Vector3(32.5, 0, 13.05)], "wait": 5.0},
	{"name": "FrontStaff", "role": "staff", "speed": 2.0, "points": [Vector3(-36, 0, 1.9), Vector3(36, 0, 1.9)], "wait": 1.5},
	{"name": "CrossAisleStaff", "role": "staff", "speed": 2.0, "points": [Vector3(-34, 0, -10), Vector3(32, 0, -10)], "wait": 2.0},
	{"name": "ProduceStaff", "role": "staff", "speed": 1.8, "points": [Vector3(-36, 0, 7.0), Vector3(-9, 0, 7.0)], "wait": 3.0},
	{"name": "StockStaffA", "role": "staff", "speed": 1.9, "points": [Vector3(-36, 0, -25.8), Vector3(-8, 0, -25.8)], "wait": 3.0},
	{"name": "StockStaffB", "role": "staff", "speed": 1.9, "points": [Vector3(10, 0, -26.8), Vector3(32, 0, -26.8)], "wait": 3.0},
	{"name": "ShopperAisle1", "role": "customer", "speed": 1.2, "points": [Vector3(-27, 0, -20), Vector3(-27, 0, 0)], "wait": 3.0},
	{"name": "ShopperAisle3", "role": "customer", "speed": 1.3, "points": [Vector3(-15, 0, 0), Vector3(-15, 0, -20)], "wait": 2.5},
	{"name": "ShopperAisle5", "role": "customer", "speed": 1.2, "points": [Vector3(-3, 0, -20), Vector3(-3, 0, 0)], "wait": 3.5},
	{"name": "ShopperAisle7", "role": "customer", "speed": 1.3, "points": [Vector3(9, 0, 0), Vector3(9, 0, -20)], "wait": 3.0},
	{"name": "ShopperAisle9", "role": "customer", "speed": 1.2, "points": [Vector3(21, 0, -20), Vector3(21, 0, 0)], "wait": 2.5},
	{"name": "ShopperAisle10", "role": "customer", "speed": 1.1, "points": [Vector3(27, 0, 0), Vector3(27, 0, -20)], "wait": 3.5},
	{"name": "ShopperProduceA", "role": "customer", "speed": 1.1, "points": [Vector3(-36, 0, 3.5), Vector3(-10, 0, 3.5)], "wait": 3.0},
	{"name": "ShopperProduceB", "role": "customer", "speed": 1.2, "points": [Vector3(-36, 0, 11.0), Vector3(-22, 0, 11.0)], "wait": 3.0},
	{"name": "ShopperDeli", "role": "customer", "speed": 1.1, "points": [Vector3(-34, 0, -11), Vector3(-34, 0, 1)], "wait": 4.0},
	{"name": "ShopperFreezer", "role": "customer", "speed": 1.1, "points": [Vector3(37.2, 0, -24), Vector3(37.2, 0, -2)], "wait": 4.0},
	{"name": "ShopperMeat", "role": "customer", "speed": 1.2, "points": [Vector3(4, 0, -23.3), Vector3(24, 0, -23.3)], "wait": 3.0},
	{"name": "ShopperQueue", "role": "customer", "speed": 1.0, "points": [Vector3(8, 0, 9.5), Vector3(32, 0, 9.5)], "wait": 4.0},
]

var _level: Node3D
var _materials := {}
var _bodies := 0


func _init() -> void:
	_build.call_deferred()


func _build() -> void:
	_level = Node3D.new()
	_level.name = "GroceryMorning"
	_add_environment()
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	region.navigation_mesh = _new_navmesh()
	_add(_level, region)
	_add_shell(region)
	_add_furniture(region)
	_add_street_view()
	_add_roof()

	# Bake from the static colliders (needs the level in the tree), then take it out again so
	# the runtime systems added below do not start while the tool runs.
	root.add_child(_level)
	region.bake_navigation_mesh(false)
	var nav_mesh := region.navigation_mesh
	if nav_mesh.get_polygon_count() == 0:
		push_error("Bake produced an empty navigation mesh.")
		quit(1)
		return
	_seat_navmesh_on_floor(nav_mesh)
	if not _save(nav_mesh, NAVMESH_PATH):
		quit(1)
		return
	nav_mesh.take_over_path(NAVMESH_PATH)
	root.remove_child(_level)

	_add_loot_spots()
	_add_walkers()
	_add_player()
	_add_systems()
	_add_gameplay()
	_add_doors_and_triggers()

	var packed := PackedScene.new()
	var error := packed.pack(_level)
	if error != OK:
		push_error("Could not pack the scene (error %d)." % error)
		quit(1)
		return
	if not _save(packed, SCENE_PATH):
		quit(1)
		return
	print("Built %s: %d solid pieces; navmesh %d polygons, %d vertices -> %s" % [
		SCENE_PATH, _bodies, nav_mesh.get_polygon_count(), nav_mesh.get_vertices().size(), NAVMESH_PATH])
	_level.free()
	quit(0)


## The bake leaves the walkable surface about 2 cell heights above the floor (0.5 m here). The
## guards' path corners would then sit a full path_desired_distance above them and never count
## as reached, so the guards' stuck detection would fire on every long walk. Lower the whole
## mesh onto the floor (y = 0), as the hand-made Museum navmesh is.
func _seat_navmesh_on_floor(nav_mesh: NavigationMesh) -> void:
	var vertices := nav_mesh.get_vertices()
	var lowest := INF
	for v in vertices:
		lowest = minf(lowest, v.y)
	for i in vertices.size():
		vertices[i].y -= lowest
	nav_mesh.set_vertices(vertices)


func _save(resource: Resource, path: String) -> bool:
	var uid := ResourceLoader.get_resource_uid(path) if FileAccess.file_exists(path) else ResourceUID.INVALID_ID
	var error := ResourceSaver.save(resource, path, ResourceSaver.FLAG_CHANGE_PATH)
	if error != OK:
		push_error("Could not save %s (error %d)." % [path, error])
		return false
	if uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(path, uid)
	return true


# --- Helpers --------------------------------------------------------------------------------

func _add(parent: Node, node: Node) -> Node:
	node.owner = null
	parent.add_child(node)
	node.owner = _level
	return node


func _material(colour: Color) -> StandardMaterial3D:
	if not _materials.has(colour):
		var m := StandardMaterial3D.new()
		m.albedo_color = colour
		m.roughness = 0.85
		if colour.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.1
		_materials[colour] = m
	return _materials[colour]


## A solid box: StaticBody3D (layer 1) with "Mesh" and "Shape". `centre` is the box centre.
func _box(parent: Node, node_name: String, centre: Vector3, size: Vector3, colour: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = centre
	_add(parent, body)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _material(colour)
	_add(body, mi)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	_add(body, cs)
	_bodies += 1
	return body


## A visual-only box (no collision, so it takes no part in the navmesh).
func _deco(parent: Node, node_name: String, centre: Vector3, size: Vector3, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.position = centre
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _material(colour)
	_add(parent, mi)
	return mi


## Text on a sign. `yaw` turns it: 0 faces +z (south), 180 faces -z, 90 faces +x, -90 faces -x.
func _label(parent: Node, node_name: String, text: String, at: Vector3, size: int, pixel: float, yaw := 0.0) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.font_size = size
	label.pixel_size = pixel
	label.outline_size = 0
	label.position = at
	label.rotation_degrees = Vector3(0, yaw, 0)
	_add(parent, label)


## A wall along x at depth z from x0 to x1, or along z at x from z0 to z1.
func _wall_x(parent: Node, node_name: String, z: float, x0: float, x1: float, colour := C_WALL) -> void:
	_box(parent, node_name, Vector3((x0 + x1) / 2.0, WALL_H / 2.0, z), Vector3(x1 - x0, WALL_H, WALL_T), colour)


func _wall_z(parent: Node, node_name: String, x: float, z0: float, z1: float, colour := C_WALL) -> void:
	_box(parent, node_name, Vector3(x, WALL_H / 2.0, (z0 + z1) / 2.0), Vector3(WALL_T, WALL_H, z1 - z0), colour)


func _new_navmesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.agent_height = 2.0
	nm.agent_radius = 0.5
	nm.agent_max_climb = 0.25
	nm.agent_max_slope = 45.0
	nm.region_min_size = 1.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	return nm


func _add_environment() -> void:
	# Morning: bright sky, warm sun from the east. The roof shuts the sun out, so the shop is
	# lit by strong ambient light (the project uses the Compatibility renderer, which has a
	# small per-mesh light limit, so there are no ceiling omni lights).
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.38, 0.6, 0.9)
	sky_material.sky_horizon_color = Color(0.82, 0.88, 0.95)
	sky_material.ground_horizon_color = Color(0.75, 0.75, 0.72)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	_add(_level, we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -70, 0)
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	_add(_level, sun)


# --- Geometry -------------------------------------------------------------------------------

func _add_shell(region: Node3D) -> void:
	var shell := Node3D.new()
	shell.name = "Shell"
	_add(region, shell)
	var width := X_MAX - X_MIN
	var depth := Z_MAX - Z_MIN
	_box(shell, "Floor", Vector3(0, -0.125, (Z_MIN + Z_MAX) / 2.0), Vector3(width, 0.25, depth), C_FLOOR)
	_box(shell, "StreetPaving", Vector3(0, -0.12, (FRONT_Z + Z_MAX) / 2.0), Vector3(width, 0.26, Z_MAX - FRONT_Z), C_STREET)
	# Outer walls: the east wall has the back-door gap (z -13.2..-10.8), the north wall the
	# stock-room door gap (x -21.2..-18.8).
	_wall_z(shell, "WestWall", X_MIN, Z_MIN, Z_MAX)
	_wall_z(shell, "EastWallA", X_MAX, Z_MIN, -13.2)
	_wall_z(shell, "EastWallB", X_MAX, -10.8, Z_MAX)
	_wall_x(shell, "NorthWallA", Z_MIN, X_MIN, -21.2)
	_wall_x(shell, "NorthWallB", Z_MIN, -18.8, X_MAX)
	# The street side is a kerb-high barrier so the street stays in view (the player cannot cross it).
	_box(shell, "StreetBarrier", Vector3(0, 0.6, Z_MAX), Vector3(width, 1.2, WALL_T), C_WALL)
	# Front wall with the open entrance (x -3..3): solid piers, and shop windows between them.
	for pier in [[X_MIN, -38.0], [-23.0, -21.0], [-6.0, -3.0], [3.0, 6.0], [21.0, 23.0], [38.0, X_MAX]]:
		_wall_x(shell, "FrontPier_%d" % int(pier[0]), FRONT_Z, pier[0], pier[1])
	for span in [[-38.0, -23.0], [-21.0, -6.0], [6.0, 21.0], [23.0, 38.0]]:
		var cx: float = (span[0] + span[1]) / 2.0
		var w: float = span[1] - span[0]
		_box(shell, "WindowSill_%d" % int(cx), Vector3(cx, 0.45, FRONT_Z), Vector3(w, 0.9, WALL_T), C_WALL)
		_box(shell, "WindowGlass_%d" % int(cx), Vector3(cx, 1.95, FRONT_Z), Vector3(w, 2.1, 0.1), C_GLASS)
		_box(shell, "WindowHead_%d" % int(cx), Vector3(cx, (3.0 + WALL_H) / 2.0, FRONT_Z), Vector3(w, WALL_H - 3.0, WALL_T), C_WALL)
	# Stock room (x -40..-6, z -30..-24): south wall with a door gap (x -17..-13), east wall.
	_wall_x(shell, "StockSouthWallA", -24.0, X_MIN, -17.0, C_STOCK_WALL)
	_wall_x(shell, "StockSouthWallB", -24.0, -13.0, -6.0, C_STOCK_WALL)
	_wall_z(shell, "StockEastWall", -6.0, Z_MIN, -24.0, C_STOCK_WALL)


func _add_furniture(region: Node3D) -> void:
	var f := Node3D.new()
	f.name = "Furniture"
	_add(region, f)
	_add_gondolas(f)
	_add_produce(f)
	_add_walls_and_counters(f)
	_add_stock_room(f)
	_add_checkout(f, 11.8)
	_add_front_end(f)


## Double-sided shelving along z, with colourful product bands on both faces and an aisle sign.
func _add_gondolas(f: Node3D) -> void:
	for i in GONDOLA_X.size():
		var x: float = GONDOLA_X[i]
		for s in GONDOLA_SPANS.size():
			var z0: float = GONDOLA_SPANS[s][0]
			var z1: float = GONDOLA_SPANS[s][1]
			var length := z1 - z0
			var body := _box(f, "Gondola_%d_%d" % [i, s], Vector3(x, GONDOLA_H / 2.0, (z0 + z1) / 2.0), Vector3(GONDOLA_W, GONDOLA_H, length), C_SHELF)
			for tier in 3:
				for face in [-1.0, 1.0]:
					var colour: Color = PRODUCT_COLOURS[(i * 2 + s + tier) % PRODUCT_COLOURS.size()]
					_deco(body, "Goods_%d_%d" % [tier, int(face)], Vector3(face * (GONDOLA_W / 2.0 + 0.03), -0.55 + tier * 0.55, 0), Vector3(0.06, 0.32, length - 0.3), colour)
		# Aisle sign hanging over the front end of each aisle between two gondolas.
		if i < GONDOLA_X.size() - 1:
			var ax: float = x + 3.0
			var number := i + 1
			for hx in [-0.9, 0.9]:
				_deco(f, "SignHanger_%d_%d" % [number, int(hx * 10)], Vector3(ax + hx, WALL_H - 0.8, 1.6), Vector3(0.04, 1.6, 0.04), Color(0.6, 0.62, 0.65))
			_deco(f, "AisleSign_%d" % number, Vector3(ax, WALL_H - 1.7, 1.6), Vector3(2.4, 0.6, 0.08), Color(0.15, 0.4, 0.55))
			_label(f, "AisleText_%d" % number, "AISLE %d" % number, Vector3(ax, WALL_H - 1.7, 1.66), 64, 0.0045)


func _add_produce(f: Node3D) -> void:
	var produce := [Color(0.85, 0.2, 0.15), Color(0.95, 0.75, 0.15), Color(0.35, 0.65, 0.25), Color(0.9, 0.45, 0.1), Color(0.55, 0.2, 0.45)]
	var n := 0
	for ix in [-34.0, -28.0, -22.0, -16.0, -10.0]:
		for iz in [5.0, 9.0]:
			var table := _box(f, "ProduceTable_%d" % n, Vector3(ix, 0.45, iz), Vector3(4.2, 0.9, 1.8), C_TABLE)
			for k in 4:
				_deco(table, "Fruit_%d" % k, Vector3(-1.5 + k * 1.0, 0.5, 0), Vector3(0.8, 0.14, 1.4), produce[(n + k) % produce.size()])
			n += 1
	_label(f, "ProduceSign", "FRESH PRODUCE", Vector3(-22.0, WALL_H - 1.5, 11.0), 96, 0.01)
	# Seasonal pallet displays on the east side of the front end.
	var pallet_colours := [Color(0.9, 0.7, 0.2), Color(0.8, 0.3, 0.25), Color(0.3, 0.55, 0.8), Color(0.4, 0.7, 0.4)]
	var p := 0
	for px in [12.0, 20.0, 28.0, 36.0]:
		var pallet := _box(f, "PalletDisplay_%d" % p, Vector3(px, 0.75, 5.5), Vector3(3.0, 1.5, 1.2), C_TABLE)
		_deco(pallet, "Stack", Vector3(0, 0.55, 0), Vector3(2.6, 0.5, 1.0), pallet_colours[p])
		p += 1


func _add_walls_and_counters(f: Node3D) -> void:
	for ws in WALL_SHELVES:
		var body := _box(f, ws.name, Vector3(ws.x, WALL_SHELF_H / 2.0, ws.z), Vector3(ws.sx, WALL_SHELF_H, ws.sz), C_WALL_SHELF)
		var along_z: bool = ws.sz > ws.sx
		var face := (1.0 if ws.x < 0.0 else -1.0) if along_z else 1.0
		for tier in 3:
			var colour: Color = PRODUCT_COLOURS[(tier * 3 + int(absf(ws.z))) % PRODUCT_COLOURS.size()]
			var y := -0.7 + tier * 0.75
			if along_z:
				_deco(body, "Goods_%d" % tier, Vector3(face * 0.43, y, 0), Vector3(0.06, 0.4, ws.sz - 0.3), colour)
			else:
				_deco(body, "Goods_%d" % tier, Vector3(0, y, face * 0.43), Vector3(ws.sx - 0.3, 0.4, 0.06), colour)
	# Dairy cases along the stock-room wall (a gap at x -17..-13 for the door), freezers on the
	# east wall (a gap at z -13.2..-10.8 for the back door) and a freezer island.
	_box(f, "DairyCaseA", Vector3(-27.75, 1.1, -23.4), Vector3(19.5, 2.2, 1.0), C_FRIDGE)
	_box(f, "DairyCaseB", Vector3(-10.0, 1.1, -23.4), Vector3(4.0, 2.2, 1.0), C_FRIDGE)
	_box(f, "FreezerA", Vector3(39.2, 1.1, -20.0), Vector3(1.2, 2.2, 11.6), C_FRIDGE)
	_box(f, "FreezerB", Vector3(39.2, 1.1, -5.0), Vector3(1.2, 2.2, 8.0), C_FRIDGE)
	_box(f, "FreezerIsland", Vector3(35.0, 0.6, -12.0), Vector3(1.6, 1.2, 16.0), C_FRIDGE)
	# Deli counter on the west wall and the meat counter on the north wall, with glass fronts.
	var deli := _box(f, "DeliCounter", Vector3(-38.2, 0.55, -5.0), Vector3(1.2, 1.1, 14.0), C_DELI)
	_deco(deli, "Glass", Vector3(0.7, 0.35, 0), Vector3(0.06, 0.5, 13.6), C_GLASS)
	_deco(deli, "Top", Vector3(0, 0.58, 0), Vector3(1.4, 0.08, 14.2), Color(0.3, 0.3, 0.32))
	var meat := _box(f, "MeatCounter", Vector3(14.0, 0.55, -28.8), Vector3(24.0, 1.1, 1.2), C_MEAT)
	_deco(meat, "Glass", Vector3(0, 0.35, 0.65), Vector3(23.6, 0.5, 0.06), C_GLASS)
	_deco(meat, "Top", Vector3(0, 0.58, 0), Vector3(24.2, 0.08, 1.4), Color(0.3, 0.3, 0.32))
	# Department signs.
	_label(f, "DeliSign", "DELI & BAKERY", Vector3(-39.7, WALL_H - 1.6, -5.0), 96, 0.01, 90.0)
	_label(f, "DairySign", "DAIRY", Vector3(-27.0, WALL_H - 2.6, -22.8), 96, 0.01)
	_label(f, "MeatSign", "MEAT & SEAFOOD", Vector3(14.0, WALL_H - 1.6, -29.7), 96, 0.01)
	_label(f, "FrozenSign", "FROZEN", Vector3(39.7, WALL_H - 2.6, -20.0), 96, 0.01, -90.0)


func _add_stock_room(f: Node3D) -> void:
	for rx in [-36.0, -29.0, -22.0]:
		var rack := _box(f, "PalletRack_%d" % int(rx), Vector3(rx, 1.2, -28.6), Vector3(5.0, 2.4, 1.4), C_RACK)
		for tier in 3:
			_deco(rack, "Boxes_%d" % tier, Vector3(0, -0.8 + tier * 0.8, 0.72), Vector3(4.6, 0.5, 0.06), PRODUCT_COLOURS[(tier + int(absf(rx))) % PRODUCT_COLOURS.size()].lightened(0.1))
	_box(f, "StockCrateA", Vector3(-12.0, 0.5, -27.0), Vector3(1.0, 1.0, 1.0), C_CRATE)
	_box(f, "StockCrateB", Vector3(-12.5, 0.5, -28.5), Vector3(1.0, 1.0, 1.0), C_CRATE)
	_box(f, "StockCrateC", Vector3(-9.0, 0.75, -28.8), Vector3(1.6, 1.5, 1.0), C_CRATE)
	_box(f, "StockCrateD", Vector3(-39.0, 0.5, -25.5), Vector3(1.0, 1.0, 1.0), C_CRATE)
	_box(f, "StockCrateE", Vector3(-39.0, 0.75, -27.0), Vector3(1.6, 1.5, 1.0), C_CRATE)


## Four checkout lanes at depth `z`: base, belt, register, sign. Cashiers walk behind them
## (z + 0.5 .. z + 2.0). Only the counter bases are solid; everything on top is visual.
func _add_checkout(f: Node3D, z: float) -> void:
	var lanes := [{"x": 10.0, "n": 1}, {"x": 17.0, "n": 2}, {"x": 24.0, "n": 3}, {"x": 31.0, "n": 4}]
	for lane in lanes:
		var x: float = lane.x
		var base := _box(f, "CheckoutCounter%d" % lane.n, Vector3(x, 0.55, z), Vector3(5.0, 1.1, 1.0), C_COUNTER)
		_deco(base, "Top", Vector3(0, 0.58, 0), Vector3(5.2, 0.08, 1.2), Color(0.85, 0.8, 0.7))
		_deco(base, "Belt", Vector3(-0.6, 0.65, -0.1), Vector3(3.1, 0.05, 0.62), Color(0.1, 0.1, 0.12))
		_deco(base, "RailFront", Vector3(-0.6, 0.7, -0.44), Vector3(3.1, 0.06, 0.04), Color(0.7, 0.72, 0.75))
		_deco(base, "RailBack", Vector3(-0.6, 0.7, 0.24), Vector3(3.1, 0.06, 0.04), Color(0.7, 0.72, 0.75))
		_deco(base, "DividerBar", Vector3(1.05, 0.72, -0.15), Vector3(0.05, 0.1, 0.5), Color(0.9, 0.5, 0.1))
		_deco(base, "Register", Vector3(1.8, 0.78, 0.2), Vector3(0.55, 0.34, 0.45), Color(0.25, 0.27, 0.3))
		var screen := _deco(base, "Screen", Vector3(1.8, 1.08, 0.3), Vector3(0.42, 0.26, 0.04), Color(0.15, 0.4, 0.55))
		screen.rotation_degrees = Vector3(20, 0, 0)
		_deco(base, "CardReader", Vector3(1.8, 0.66, -0.2), Vector3(0.14, 0.04, 0.2), Color(0.12, 0.12, 0.14))
		_deco(base, "GumDisplay", Vector3(2.15, 0.72, -0.35), Vector3(0.32, 0.18, 0.14), Color(0.2, 0.7, 0.45))
		_deco(base, "BagHolder", Vector3(2.35, 0.8, 0.1), Vector3(0.05, 0.4, 0.2), Color(0.8, 0.8, 0.8))
		for side in [-2.2, 2.2]:
			_deco(base, "SignPole_%d" % int(side * 10), Vector3(side, 2.8, 0.0), Vector3(0.07, 4.5, 0.07), Color(0.6, 0.62, 0.65))
		_deco(base, "SignBoard", Vector3(0, 4.9, 0.0), Vector3(1.6, 0.55, 0.1), Color(0.15, 0.45, 0.3))
		_label(base, "SignText", "CHECKOUT %d" % lane.n, Vector3(0, 4.9, -0.07), 64, 0.0035, 180.0)
	_deco(f, "QueueMark", Vector3(20.5, 0.005, z - 2.4), Vector3(28.0, 0.01, 0.12), Color(0.95, 0.75, 0.15))


## Entrance mat, baskets, a customer service desk and a row of shopping carts.
func _add_front_end(f: Node3D) -> void:
	_deco(f, "EntranceMat", Vector3(0, 0.01, 12.4), Vector3(5.6, 0.02, 2.4), Color(0.25, 0.25, 0.28))
	for i in 4:
		_deco(f, "BasketStack%d" % i, Vector3(-4.6, 0.2 + i * 0.11, 13.0), Vector3(0.42, 0.14, 0.3), Color(0.85, 0.2, 0.15))
	var desk := _box(f, "ServiceDesk", Vector3(-17.0, 0.55, 12.4), Vector3(5.0, 1.1, 1.2), C_COUNTER)
	_deco(desk, "Top", Vector3(0, 0.58, 0), Vector3(5.2, 0.08, 1.4), Color(0.85, 0.8, 0.7))
	_deco(f, "ServiceSignBoard", Vector3(-17.0, 3.6, 12.4), Vector3(3.2, 0.7, 0.1), Color(0.15, 0.4, 0.55))
	_label(f, "ServiceSignText", "CUSTOMER SERVICE", Vector3(-17.0, 3.6, 12.33), 64, 0.0035, 180.0)
	for i in 6:
		_deco(f, "Cart%d" % i, Vector3(-9.5 + i * 0.5, 0.5, 13.0), Vector3(0.6, 0.9, 1.0), Color(0.72, 0.74, 0.78))


# --- Runtime content (added outside the tree, after the bake) --------------------------------

func _add_loot_spots() -> void:
	var spots := Node3D.new()
	spots.name = "LootSpots"
	_add(_level, spots)
	for i in LOOT_SPOTS.size():
		var m := Marker3D.new()
		m.name = "Spot%d" % i
		m.position = LOOT_SPOTS[i]
		_add(spots, m)
		m.add_to_group("loot_spots", true)


func _add_walkers() -> void:
	var holder := Node3D.new()
	holder.name = "Walkers"
	_add(_level, holder)
	for w in WALKERS:
		var route := Node3D.new()
		route.name = "%sRoute" % w.name
		route.set_script(load("res://shared/scripts/npc/patrol_route.gd"))
		route.set("loop", true)
		route.set("debug_color", Color(0.3, 0.9, 0.4) if w.role == "staff" else Color(0.95, 0.75, 0.2))
		_add(holder, route)
		for k in w.points.size():
			var point := Marker3D.new()
			point.name = "Point%d" % k
			point.set_script(load("res://shared/scripts/npc/patrol_point.gd"))
			point.position = w.points[k]
			point.set("wait_time", w.wait)
			_add(route, point)
		var walker := (load(GUARD_SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
		var is_staff: bool = w.role == "staff"
		walker.set_script(load("res://maps/grocery/scripts/grocery_staff.gd" if is_staff else "res://maps/grocery/scripts/shopper.gd"))
		walker.name = w.name
		walker.position = w.points[0] + Vector3(0, 0.05, 0)
		var to: Vector3 = w.points[1] - w.points[0]
		walker.rotation.y = atan2(-to.x, -to.z)
		walker.set("patrol_route", route)
		walker.set("patrol_speed", w.speed)
		holder.add_child(walker)
		walker.owner = _level
		if not is_staff:
			walker.set("investigate_speed", w.speed)
			var vision := walker.get_node("Vision")
			vision.set("detection_distance", 12.0)
			vision.set("fov_degrees", 100.0)


func _add_player() -> void:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	player.name = "Player"
	player.position = Vector3(0, 0, 17.0)
	# This map's movement tuning (overrides on the shared player; other maps keep 3.5 / 5.5 / 1.8):
	# a store this big is a long way on foot, and sprinting is limited by the stamina bar instead.
	player.set("walk_speed", 4.2)
	player.set("sprint_speed", 6.5)
	player.set("crouch_speed", 2.2)
	player.set("use_stamina", true)
	_level.add_child(player)
	player.owner = _level


func _add_systems() -> void:
	_add_scripted("StealthDirector", Node.new(), "res://shared/scripts/stealth/stealth_director.gd")
	_add_scripted("StealthHud", CanvasLayer.new(), "res://shared/scripts/ui/stealth_hud.gd")
	_add_scripted("NoiseSystem", Node3D.new(), "res://shared/scripts/noise/noise_system.gd")
	_add_scripted("ObjectiveHud", CanvasLayer.new(), "res://shared/scripts/ui/objective_hud.gd")
	_add_scripted("GameFlow", Node.new(), "res://shared/scripts/game/game_flow.gd")
	_add_scripted("GameMenus", CanvasLayer.new(), "res://shared/scripts/ui/game_menus.gd")
	_add_scripted("AudioDirector", Node.new(), "res://shared/scripts/presentation/audio_director.gd")


func _add_scripted(node_name: String, node: Node, script_path: String, parent: Node = null) -> Node:
	node.name = node_name
	node.set_script(load(script_path))
	return _add(parent if parent else _level, node)


func _add_gameplay() -> void:
	var gameplay := Node3D.new()
	gameplay.name = "Gameplay"
	_add(_level, gameplay)
	var manager := _add_scripted("ObjectiveManager", Node.new(), "res://features/objectives/objective_manager.gd", gameplay)
	# Placeholder titles; GroceryHeist.setup()s the real flow (with the drawn item) at run time.
	manager.set("objectives", GroceryHeist.build_objectives("the target item"))
	_add_scripted("CheckpointManager", Node.new(), "res://features/checkpoints/checkpoint_manager.gd", gameplay)
	var loot := Loot.new()
	loot.name = "Loot"
	loot.position = LOOT_SPOTS[0]
	_add(gameplay, loot)
	# After the ObjectiveManager (it is ready first), so setup() runs before anything listens.
	_add_scripted("GroceryHeist", Node.new(), "res://maps/grocery/scripts/grocery_heist.gd", gameplay)


func _add_doors_and_triggers() -> void:
	var gameplay := _level.get_node("Gameplay")
	var heist := gameplay.get_node("GroceryHeist")
	heist.set("loot", gameplay.get_node("Loot"))
	_trigger("EnterStoreTrigger", Vector3(0, 1.5, 11.0), Vector3(7, 3, 4), GroceryHeist.ENTER)
	_trigger("BackDoorTrigger", Vector3(37.5, 1.5, -12.0), Vector3(4, 3, 5), GroceryHeist.REACH_EXIT)
	_trigger("StockDoorTrigger", Vector3(-20, 1.5, -27.5), Vector3(5, 3, 4), GroceryHeist.REACH_EXIT)
	_exit_door("BackDoor", Vector3(X_MAX, 1.4, -12.0), 90.0, "Back door", C_DOOR)
	_exit_door("StockRoomDoor", Vector3(-20, 1.4, Z_MIN), 0.0, "Stock-room door", C_STOCK_DOOR)


func _trigger(node_name: String, at: Vector3, size: Vector3, objective: StringName) -> void:
	var area := Area3D.new()
	area.name = node_name
	area.position = at
	area.set_script(load("res://features/objectives/objective_trigger.gd"))
	area.set("objective_id", objective)
	_add(_level, area)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	_add(area, cs)


## An exit door filling a wall gap. `yaw` 90 turns it for a door in an east/west wall.
func _exit_door(node_name: String, at: Vector3, yaw: float, title: String, colour: Color) -> void:
	var door := Area3D.new()
	door.name = node_name
	door.position = at
	door.rotation_degrees = Vector3(0, yaw, 0)
	door.set_script(load("res://features/objectives/exit_door.gd"))
	door.set("objective_id", ObjectiveManager.ESCAPE)
	door.set("key_objective_id", GroceryHeist.STEAL)
	door.set("locked_sign", "LOCKED · NOTHING TAKEN")
	door.set("locked_reason", "You haven't taken anything yet.")
	door.set("locked_prompt", "Exit (take something first)")
	door.set("door_name", title)
	_add(_level, door)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 2.8, 1.6)
	cs.shape = box
	_add(door, cs)
	var panel := StaticBody3D.new()
	panel.name = "Panel"
	panel.position = Vector3(0, WALL_H / 2.0 - 1.4, 0)
	_add(door, panel)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.4, WALL_H, 0.3)
	mi.mesh = mesh
	mi.material_override = _material(colour)
	_add(panel, mi)
	var pcs := CollisionShape3D.new()
	pcs.name = "Shape"
	var pbox := BoxShape3D.new()
	pbox.size = Vector3(2.4, WALL_H, 0.3)
	pcs.shape = pbox
	_add(panel, pcs)
	door.set("door_mesh", mi)
	_add_scripted("Noise", Node3D.new(), "res://shared/scripts/noise/noise_maker.gd", door)


# --- Street scenery (visual only: no collision, outside the NavigationRegion3D) ---------------

## What the shop windows look out on: a road, parked cars, trees and buildings across the street.
func _add_street_view() -> void:
	var view := Node3D.new()
	view.name = "StreetView"
	_add(_level, view)
	_deco(view, "Road", Vector3(0, -0.14, 27.0), Vector3(260, 0.2, 14.0), Color(0.2, 0.21, 0.23))
	for i in 24:
		_deco(view, "LaneMark%d" % i, Vector3(-100 + i * 9.0, -0.03, 27.0), Vector3(3.5, 0.02, 0.25), Color(0.9, 0.85, 0.4))
	_deco(view, "FarPavement", Vector3(0, -0.12, 36.0), Vector3(260, 0.24, 4.0), C_STREET)
	_deco(view, "NearPavementWest", Vector3(-71, -0.12, 17.0), Vector3(62, 0.24, 6.0), C_STREET)
	_deco(view, "NearPavementEast", Vector3(71, -0.12, 17.0), Vector3(62, 0.24, 6.0), C_STREET)
	# Parked cars along the near kerb: body, cabin and four dark wheels.
	var car_colours := [Color(0.75, 0.15, 0.15), Color(0.2, 0.35, 0.7), Color(0.85, 0.85, 0.8), Color(0.9, 0.7, 0.15), Color(0.2, 0.2, 0.22)]
	var car_x := [-32.0, -14.0, 9.0, 26.0, 36.0]
	for i in car_x.size():
		var c := Node3D.new()
		c.name = "Car%d" % i
		c.position = Vector3(car_x[i], 0, 23.0)
		_add(view, c)
		_deco(c, "Body", Vector3(0, 0.55, 0), Vector3(4.2, 0.8, 1.8), car_colours[i])
		_deco(c, "Cabin", Vector3(-0.2, 1.15, 0), Vector3(2.2, 0.6, 1.6), Color(0.7, 0.82, 0.9, 0.6))
		for wx in [-1.3, 1.3]:
			for wz in [-0.9, 0.9]:
				_deco(c, "Wheel", Vector3(wx, 0.3, wz), Vector3(0.6, 0.6, 0.25), Color(0.05, 0.05, 0.06))
	# Trees on the pavement outside the windows.
	for tx in [-36.0, -28.0, -14.0, -4.5, 4.5, 14.0, 28.0, 36.0]:
		var t := Node3D.new()
		t.name = "Tree_%d" % int(tx)
		t.position = Vector3(tx, 0, 17.0)
		_add(view, t)
		_deco(t, "Trunk", Vector3(0, 1.2, 0), Vector3(0.35, 2.4, 0.35), Color(0.4, 0.28, 0.18))
		_deco(t, "Crown", Vector3(0, 3.2, 0), Vector3(2.2, 2.0, 2.2), Color(0.28, 0.55, 0.25))
	# Buildings across the road.
	var heights := [9.0, 14.0, 7.0, 12.0, 10.0, 16.0, 8.0, 13.0, 11.0]
	var tints := [Color(0.82, 0.7, 0.58), Color(0.7, 0.74, 0.8), Color(0.85, 0.8, 0.7), Color(0.65, 0.5, 0.45), Color(0.78, 0.78, 0.74), Color(0.6, 0.66, 0.7)]
	for i in heights.size():
		var bx := -64.0 + i * 16.0
		_deco(view, "Building%d" % i, Vector3(bx, heights[i] / 2.0, 44.0), Vector3(14.0, heights[i], 10.0), tints[i % tints.size()])
		for row in int(heights[i] / 3.5):
			for col in 3:
				_deco(view, "Win%d_%d_%d" % [i, row, col], Vector3(bx - 4.0 + col * 4.0, 2.0 + row * 3.5, 38.95),
					Vector3(1.8, 1.6, 0.1), Color(0.35, 0.5, 0.65))


# --- Roof and ceiling light panels --------------------------------------------------------------

## A flat roof over the shop (z -30..14) with a canopy over the street side, a low parapet, the
## shop sign and rows of glowing ceiling panels. Outside the NavigationRegion3D.
func _add_roof() -> void:
	var roof := Node3D.new()
	roof.name = "Roof"
	_add(_level, roof)
	var width := X_MAX - X_MIN + 2 * WALL_T
	var span := FRONT_Z - Z_MIN
	var mid := (Z_MIN + FRONT_Z) / 2.0
	_box(roof, "RoofSlab", Vector3(0, WALL_H + ROOF_T / 2.0, mid), Vector3(width, ROOF_T, span + 2 * WALL_T), C_ROOF)
	_box(roof, "Canopy", Vector3(0, WALL_H - 0.45, FRONT_Z + 0.9), Vector3(width, 0.18, 1.8), C_CANOPY)
	var top := WALL_H + ROOF_T + 0.25
	_box(roof, "ParapetNorth", Vector3(0, top, Z_MIN - WALL_T / 2.0), Vector3(width, 0.5, 0.25), C_ROOF_TRIM)
	_box(roof, "ParapetSouth", Vector3(0, top, FRONT_Z + WALL_T / 2.0), Vector3(width, 0.5, 0.25), C_ROOF_TRIM)
	_box(roof, "ParapetWest", Vector3(X_MIN - WALL_T / 2.0, top, mid), Vector3(0.25, 0.5, span + 2 * WALL_T), C_ROOF_TRIM)
	_box(roof, "ParapetEast", Vector3(X_MAX + WALL_T / 2.0, top, mid), Vector3(0.25, 0.5, span + 2 * WALL_T), C_ROOF_TRIM)
	_deco(roof, "SignBoard", Vector3(0, WALL_H - 1.4, FRONT_Z + 1.95), Vector3(14.0, 1.4, 0.12), Color(0.15, 0.45, 0.3))
	_label(roof, "SignText", "MORNING GROCERY", Vector3(0, WALL_H - 1.4, FRONT_Z + 2.03), 128, 0.008)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.98, 0.92)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.97, 0.88)
	glow.emission_energy_multiplier = 1.6
	for x in [-32.0, -24.0, -16.0, -8.0, 0.0, 8.0, 16.0, 24.0, 32.0]:
		for z in [-24.0, -16.0, -8.0, 0.0, 8.0]:
			var panel := MeshInstance3D.new()
			panel.name = "LightPanel_%d_%d" % [int(x), int(z)]
			var mesh := BoxMesh.new()
			mesh.size = Vector3(3.0, 0.06, 0.6)
			panel.mesh = mesh
			panel.material_override = glow
			panel.position = Vector3(x, WALL_H - 0.04, z)
			panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_add(roof, panel)
