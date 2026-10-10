extends SceneTree

## Development tool: builds the Expanded Library graybox from the layout data
## in tools/expanded/expanded_layout.gd, bakes its navigation mesh and saves
##   res://scenes/level/expanded_library.tscn
##   res://scenes/level/expanded_library_navmesh.tres
## Run from the project folder:
##   godot --headless --path . --script res://tools/expanded/build_expanded_graybox.gd
## Exits with code 0 on success and 1 on failure.
##
## The scene follows the tutorial's conventions: every solid piece is a
## StaticBody3D on physics layer 1 ("world") with a "Mesh" and a "Shape"
## child, all level geometry sits under NavigationRegion3D (the navmesh is
## baked from static colliders on layer 1), and the player is an instance of
## scenes/player/player.tscn. The mission (objectives, access doors, the exit,
## checkpoints) is built under "Gameplay" from the layout's mission data, with
## the tutorial's systems and node layout; "Layout" keeps design markers and
## labels (objectives, gates, planned patrols, hiding spots).
##
## While the level is a graybox, this tool and the layout data are the source
## of truth: change the data and rebuild instead of editing the scene by hand.

const Layout := preload("res://tools/expanded/expanded_layout.gd")
const SCENE_PATH := "res://scenes/level/expanded_library.tscn"
const NAVMESH_PATH := "res://scenes/level/expanded_library_navmesh.tres"
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const GUARD_SCENE := "res://scenes/npc/guard.tscn"

const ZONE_NODE_NAMES := {
	"A": "A_EntranceLobby", "B": "B_MainStacks", "C": "C_ReadingStudy",
	"D": "D_ServiceCorridor", "E": "E_StaffUpperStacks", "F": "F_RestrictedArchive",
}
const HEADER_COLOURS := {
	"door": Color(0.42, 0.44, 0.48), "arch": Color(0.42, 0.44, 0.48), "entrance": Color(0.3, 0.55, 0.85),
	"gate": Color(0.85, 0.2, 0.18), "shortcut": Color(0.95, 0.7, 0.15), "exit": Color(0.25, 0.85, 0.4),
}
const COVER_COLOURS := {
	"shelf": Color(0.45, 0.32, 0.22), "rack": Color(0.4, 0.38, 0.34), "low": Color(0.72, 0.6, 0.42),
	"carrel_desk": Color(0.72, 0.6, 0.42), "carrel_panel": Color(0.35, 0.45, 0.4),
}
const PATROL_COLOURS := [Color(1.0, 0.45, 0.1), Color(0.95, 0.25, 0.7), Color(1.0, 0.85, 0.15),
	Color(0.4, 0.9, 0.9), Color(0.6, 1.0, 0.4), Color(0.7, 0.6, 1.0), Color(1.0, 0.5, 0.5),
	Color(0.95, 0.95, 0.95), Color(0.3, 0.6, 1.0)]

var _level: Node3D
var _materials := {}
var _meshes := {}
var _shapes := {}
var _counter := 0
var _bodies := 0


func _init() -> void:
	_build.call_deferred()


func _build() -> void:
	_level = Node3D.new()
	_level.name = "ExpandedLibrary"
	_level.set_meta("layout_version", Layout.VERSION)
	_add_environment()
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	region.navigation_mesh = _new_navmesh()
	_add(_level, region)
	var ground := _group(region, "Ground")
	var upper := _group(region, "Upper")
	var zones := {}
	for z in Layout.ZONES:
		var node := _group(ground if z.floor == "ground" else upper, ZONE_NODE_NAMES[z.id])
		node.set_meta("zone_id", z.id)
		node.set_meta("zone_name", z.name)
		node.set_meta("floor", z.floor)
		zones[z.id] = node
	for f in Layout.FLOORS:
		_add_floor(zones[f.zone], f)
	for i in Layout.WALLS.size():
		_add_wall(zones[Layout.WALLS[i].zone], Layout.WALLS[i], i)
	var stairs := _group(region, "Stairs")
	for s in Layout.STAIRS:
		_add_stair(stairs, s)
	for c in Layout.COVER:
		_add_cover(zones[c.zone], c)
	_add_debug_and_player(region)
	_add_layout_markers()

	# Bake the navigation mesh from the static colliders (needs the level in the tree).
	root.add_child(_level)
	region.bake_navigation_mesh(false)
	var nav_mesh := region.navigation_mesh
	if nav_mesh.get_polygon_count() == 0:
		push_error("Bake produced an empty navigation mesh.")
		quit(1)
		return
	if not _save(nav_mesh, NAVMESH_PATH):
		quit(1)
		return
	nav_mesh.take_over_path(NAVMESH_PATH)   # referenced from the scene as an external resource
	# The runtime systems are added outside the tree, so they don't start (music,
	# HUDs) while the tool runs; they only need to be in the saved scene.
	root.remove_child(_level)
	_add_guards()
	_add_gameplay()
	_add_runtime_systems()
	var packed := PackedScene.new()
	var error := packed.pack(_level)
	if error != OK:
		push_error("Could not pack the scene (error %d)." % error)
		quit(1)
		return
	if not _save(packed, SCENE_PATH):
		quit(1)
		return
	print("Built %s (layout %s): %d solid pieces; navmesh %d polygons, %d vertices -> %s" % [
		SCENE_PATH, Layout.VERSION, _bodies, nav_mesh.get_polygon_count(), nav_mesh.get_vertices().size(), NAVMESH_PATH])
	_level.free()
	quit(0)


## Saves `resource` at `path`, keeping the file's existing UID so a rebuild does not churn references.
func _save(resource: Resource, path: String) -> bool:
	var uid := ResourceLoader.get_resource_uid(path) if FileAccess.file_exists(path) else ResourceUID.INVALID_ID
	var error := ResourceSaver.save(resource, path, ResourceSaver.FLAG_CHANGE_PATH)
	if error != OK:
		push_error("Could not save %s (error %d)." % [path, error])
		return false
	if uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(path, uid)
	return true


func _new_navmesh() -> NavigationMesh:
	# Same settings as the tutorial's navmesh (scenes/level/library_navmesh.tres).
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.agent_height = 1.75
	nav_mesh.region_min_size = 8.0
	return nav_mesh


# --- Shared runtime systems ----------------------------------------------------------------

## The level-wide systems every map has, with the same node names and scripts
## as in the tutorial (scenes/level/library_graybox.tscn): game flow and its
## menus, the stealth director, the noise hub, the stealth HUD, the detection
## debug panel and the audio director. Each finds the others through its group
## when the level loads and is freed with the level, so a map never shares or
## duplicates them. The mission systems (ObjectiveManager, CheckpointManager,
## ObjectiveHud) are added by _add_gameplay().
const RUNTIME_SYSTEMS := [
	["StealthDirector", "Node", "res://scripts/systems/stealth_director.gd"],
	["StealthHud", "CanvasLayer", "res://scripts/ui/stealth_hud.gd"],
	["NoiseSystem", "Node3D", "res://scripts/systems/noise/noise_system.gd"],
	["DetectionDebugHud", "CanvasLayer", "res://scripts/systems/detection_debug_hud.gd"],
	["GameFlow", "Node", "res://scripts/game/game_flow.gd"],
	["GameMenus", "CanvasLayer", "res://scripts/ui/game_menus.gd"],
	["AudioDirector", "Node", "res://scripts/presentation/audio_director.gd"],
]


func _add_runtime_systems() -> void:
	for entry in RUNTIME_SYSTEMS:
		var node: Node = ClassDB.instantiate(entry[1])
		node.name = entry[0]
		node.set_script(load(entry[2]))
		_add(_level, node)
		if entry[0] == "GameMenus":
			node.set("win_message", Layout.WIN_MESSAGE)


# --- Mission ----------------------------------------------------------------------------------

const MISSION_SCRIPTS := {
	"objectives": "res://scripts/systems/objectives/objective_manager.gd",
	"checkpoints": "res://scripts/systems/checkpoints/checkpoint_manager.gd",
	"trigger": "res://scripts/systems/objectives/objective_trigger.gd",
	"item": "res://scripts/systems/objectives/access_card.gd",
	"door": "res://scripts/systems/objectives/access_door.gd",
	"exit": "res://scripts/systems/objectives/exit_door.gd",
	"checkpoint": "res://scripts/systems/checkpoints/checkpoint.gd",
	"noise": "res://scripts/systems/noise/noise_maker.gd",
	"hud": "res://scripts/ui/objective_hud.gd",
}
const ITEM_LOOKS := {
	"take_card": {"node": "StaffAccessCard", "label": "STAFF CARD", "prompt": "Take the staff access card",
		"waiting": "Staff access card (not yet)", "size": Vector3(0.32, 0.02, 0.2), "colour": Color(1.0, 0.85, 0.3)},
	"take_manuscript": {"node": "RareManuscript", "label": "RARE MANUSCRIPT", "prompt": "Take the rare manuscript",
		"waiting": "Rare manuscript (not yet)", "size": Vector3(0.3, 0.08, 0.4), "colour": Color(0.75, 0.25, 0.2)},
}


## The mission, with the tutorial's systems and node layout (Gameplay/…, then
## ObjectiveHud at the root): ObjectiveManager with this level's five
## objectives, CheckpointManager, the lobby trigger, the two pickups, the
## access doors, the exit door and the checkpoints. Added after the bake and
## outside the tree: none of it is navmesh geometry (door panels must not be
## baked, so guards keep their routes through the doorways).
func _add_gameplay() -> void:
	var gameplay := _group(_level, "Gameplay")
	var manager := _scripted(gameplay, "ObjectiveManager", Node.new(), "objectives")
	var list: Array[Dictionary] = []
	for o in Layout.OBJECTIVES:
		list.append({"id": StringName(o.id), "title": o.title, "hint": o.hint, "done": o.done})
	manager.set("objectives", list)
	_scripted(gameplay, "CheckpointManager", Node.new(), "checkpoints")
	for o in Layout.OBJECTIVES:
		if o.has("trigger"):
			var r: Array = o.trigger
			var trigger := _scripted(gameplay, "EnterLibraryTrigger", Area3D.new(), "trigger") as Area3D
			trigger.position = Vector3((r[0] + r[2]) / 2.0, o.trigger_y + 1.0, (r[1] + r[3]) / 2.0)
			trigger.set("objective_id", StringName(o.id))
			_shape(trigger, Vector3(r[2] - r[0], 2.0, r[3] - r[1]))
		if o.has("item"):
			_add_item(gameplay, o)
	for d in Layout.DOORS:
		_add_access_door(gameplay, d)
	_add_exit_door(gameplay)
	for c in Layout.CHECKPOINTS:
		_add_checkpoint(gameplay, c)
	var hud := CanvasLayer.new()
	_scripted(_level, "ObjectiveHud", hud, "hud")


func _add_item(parent: Node, o: Dictionary) -> void:
	var look: Dictionary = ITEM_LOOKS[o.id]
	var item := _scripted(parent, look.node, Area3D.new(), "item") as Area3D
	item.position = o.item
	item.set("objective_id", StringName(o.id))
	item.set("prompt", look.prompt)
	item.set("waiting_prompt", look.waiting)
	_shape(item, Vector3(0.7, 0.45, 0.9))
	var model := Node3D.new()
	model.name = "Model"
	model.position = Vector3(0, -0.13, 0)
	_add(item, model)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = _box_mesh(look.size)
	mesh.material_override = _glow_material(look.colour)
	_add(model, mesh)
	var label := _label(item, "Label", look.label, Vector3(0, 0.45, 0), look.colour, 0.005)
	label.font_size = 28   # as the tutorial's card label


func _add_access_door(parent: Node, d: Dictionary) -> void:
	var found := Layout.find_opening(d.opening)
	var width: float = found.opening.width
	var along_x: bool = found.along_x
	var door := _scripted(parent, String(d.opening).validate_node_name().replace(" ", ""), Area3D.new(), "door") as Area3D
	door.position = found.centre + Vector3(0, 1.2, 0)
	door.set("door_name", d.name)
	if d.has("key"):
		door.set("mode", 0)   # AccessDoor.Mode.KEY
		door.set("key_objective_id", StringName(d.key))
		door.set("key_name", d.key_name)
	else:
		door.set("mode", 1)   # AccessDoor.Mode.ONE_WAY
		door.set("open_from", Vector3(d.open_from[0], 0, d.open_from[1]))
	if d.has("completes"):
		door.set("complete_objective_id", StringName(d.completes))
	# The interaction box reaches 0.5 m out on both sides, in front of the panel,
	# so the player's interaction ray meets it before the solid panel.
	_shape(door, _wall_size(along_x, width, 2.4, 1.0))
	var colour: Color = HEADER_COLOURS[found.opening.type]
	_add_box(door, "Panel", Vector3(0, Layout.DOOR_HEIGHT / 2.0 - 1.2, 0),
		_wall_size(along_x, width, Layout.DOOR_HEIGHT, Layout.WALL_THICKNESS * 0.6), colour)
	_noise(door)


func _add_exit_door(parent: Node) -> void:
	var found := Layout.find_opening(Layout.EXIT_DOOR.opening)
	var exit := _scripted(parent, "ExitDoor", Area3D.new(), "exit") as Area3D
	# Inside the dock (the wall is the level's east edge), in front of the closed panel.
	exit.position = found.centre + Vector3(-0.4, 1.2, 0)
	exit.set("key_objective_id", StringName(Layout.EXIT_DOOR.key))
	exit.set("locked_sign", Layout.EXIT_DOOR.sign)
	exit.set("locked_prompt", Layout.EXIT_DOOR.prompt)
	exit.set("locked_reason", Layout.EXIT_DOOR.reason)
	var panel := _level.find_child("ExitDoorPanel", true, false)
	if panel:
		exit.set("door_mesh", panel.get_node("Mesh"))
	_shape(exit, Vector3(0.5, 2.4, found.opening.width))
	_noise(exit)
	var sign := _label(exit, "Sign", Layout.EXIT_DOOR.sign, Vector3(-0.3, 1.55, 0), Color.WHITE, 0.005)
	sign.font_size = 40


func _add_checkpoint(parent: Node, c: Dictionary) -> void:
	var cp := _scripted(parent, c.node, Area3D.new(), "checkpoint") as Area3D
	cp.position = c.pos + Vector3(0, 1.0, 0)
	cp.set("checkpoint_name", c.name)
	cp.set_meta("zone_id", c.zone)
	_shape(cp, Vector3(2.6, 2.0, 2.2))
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = Vector3(0, -0.95, 0)
	spawn.rotation_degrees = Vector3(0, c.facing, 0)
	_add(cp, spawn)
	var pad := MeshInstance3D.new()
	pad.name = "Pad"
	pad.position = Vector3(0, -0.99, 0)
	if not _meshes.has("checkpoint_pad"):
		var m := CylinderMesh.new()
		m.resource_scene_unique_id = "CylinderMesh_checkpoint_pad"
		m.top_radius = 0.75
		m.bottom_radius = 0.75
		m.height = 0.02
		_meshes["checkpoint_pad"] = m
	pad.mesh = _meshes["checkpoint_pad"]
	_add(cp, pad)
	var label := _label(cp, "Label", "CHECKPOINT", Vector3(0, 1.2, 0), Color.WHITE, 0.005)
	label.font_size = 28


func _scripted(parent: Node, node_name: String, node: Node, script_key: String) -> Node:
	node.name = node_name
	node.set_script(load(MISSION_SCRIPTS[script_key]))
	_add(parent, node)
	return node


func _shape(parent: Node, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = _box_shape(size)
	_add(parent, shape)


func _noise(parent: Node) -> void:
	var noise := Node3D.new()
	noise.name = "Noise"
	noise.set_script(load(MISSION_SCRIPTS.noise))
	noise.set("radius", 6.0)
	_add(parent, noise)


func _glow_material(colour: Color) -> StandardMaterial3D:
	var key := "glow_" + colour.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.resource_scene_unique_id = "Material_%s" % key
		m.albedo_color = colour
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = 0.6
		_materials[key] = m
	return _materials[key]


# --- Environment, player, debug ------------------------------------------------------------

func _add_environment() -> void:
	var env := Environment.new()
	env.resource_scene_unique_id = "Environment_graybox"
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.07, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.66, 0.58)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = env
	_add(_level, world)
	var light := DirectionalLight3D.new()
	light.name = "KeyLight"
	light.rotation_degrees = Vector3(-52, -28, 0)
	light.light_color = Color(1, 0.95, 0.88)
	light.light_energy = 0.55
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_add(_level, light)


func _add_debug_and_player(region: NavigationRegion3D) -> void:
	var debug := Node3D.new()
	debug.name = "NavigationDebug"
	debug.set_script(load("res://scripts/systems/navigation_debug.gd"))
	debug.set("region", region)
	debug.set("visible_on_start", false)
	_add(_level, debug)
	# Edit-state instance, so the scene stores it like the editor does (an instance plus overrides).
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	player.name = "Player"
	player.position = Layout.SPAWN
	_level.add_child(player)
	player.owner = _level   # an instance: only its root is owned by the level
	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 80.0
	camera.position = Vector3(0, 60, 2)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	camera.far = 200.0
	camera.current = false
	_add(_level, camera)


# --- Geometry ---------------------------------------------------------------------------------

func _add_floor(parent: Node3D, f: Dictionary) -> void:
	var r: Array = f.rect
	var upper: bool = f.floor == "upper"
	var thickness: float = Layout.SLAB_THICKNESS if upper else Layout.GROUND_FLOOR_THICKNESS
	var top: float = Layout.UPPER_Y if upper else 0.0
	var size := Vector3(r[2] - r[0], thickness, r[3] - r[1])
	var centre := Vector3((r[0] + r[2]) / 2.0, top - thickness / 2.0, (r[1] + r[3]) / 2.0)
	var colour: Color = Layout.zone(f.zone).colour.darkened(0.45 if not upper else 0.3)
	_add_box(parent, "Floor" if not upper else "UpperSlab", centre, size, colour)


func _add_wall(parent: Node3D, wall: Dictionary, index: int) -> void:
	var y0 := Layout.floor_y(wall.floor)
	var railing: bool = wall.get("kind", "wall") == "railing"
	var height: float = Layout.RAILING_HEIGHT if railing else (Layout.UPPER_WALL_HEIGHT if wall.floor == "upper" else Layout.GROUND_WALL_HEIGHT)
	var along_x: bool = wall.a[1] == wall.b[1]
	var fixed: float = wall.a[1] if along_x else wall.a[0]
	var lo: float = minf(wall.a[0], wall.b[0]) if along_x else minf(wall.a[1], wall.b[1])
	var hi: float = maxf(wall.a[0], wall.b[0]) if along_x else maxf(wall.a[1], wall.b[1])
	var t := Layout.WALL_THICKNESS
	# Solid intervals: the segment (extended by half a thickness to close corners) minus the openings.
	var intervals := [[lo - t / 2.0, hi + t / 2.0]]
	var openings: Array = wall.get("openings", [])
	for o in openings:
		var cut := [o.at - o.width / 2.0, o.at + o.width / 2.0]
		var next := []
		for iv in intervals:
			if cut[1] <= iv[0] or cut[0] >= iv[1]:
				next.append(iv)
				continue
			if cut[0] > iv[0]:
				next.append([iv[0], cut[0]])
			if cut[1] < iv[1]:
				next.append([cut[1], iv[1]])
		intervals = next
	var colour: Color = Layout.zone(wall.zone).colour.darkened(0.15 if railing else 0.05)
	var base_name := "%s%02d" % ["Railing" if railing else "Wall", index]
	for k in intervals.size():
		var iv: Array = intervals[k]
		var length: float = iv[1] - iv[0]
		if length < 0.01:
			continue
		var mid: float = (iv[0] + iv[1]) / 2.0
		_add_box(parent, "%s_%d" % [base_name, k], _wall_point(along_x, mid, fixed, y0 + height / 2.0),
			_wall_size(along_x, length, height, t), colour)
	# Headers over doorways, a closed panel in the exit.
	for o in openings:
		if railing or o.type == "stair":
			continue
		var header_h := height - Layout.DOOR_HEIGHT
		var tag := String(o.name).validate_node_name().replace(" ", "").replace("–", "-")
		_add_box(parent, "Header_" + tag, _wall_point(along_x, o.at, fixed, y0 + Layout.DOOR_HEIGHT + header_h / 2.0),
			_wall_size(along_x, o.width, header_h, t), HEADER_COLOURS.get(o.type, Color.GRAY))
		if o.type == "exit":
			_add_box(parent, "ExitDoorPanel", _wall_point(along_x, o.at, fixed, y0 + Layout.DOOR_HEIGHT / 2.0),
				_wall_size(along_x, o.width, Layout.DOOR_HEIGHT, t * 0.6), HEADER_COLOURS.exit)


func _wall_point(along_x: bool, along: float, fixed: float, y: float) -> Vector3:
	return Vector3(along, y, fixed) if along_x else Vector3(fixed, y, along)


func _wall_size(along_x: bool, length: float, height: float, thickness: float) -> Vector3:
	return Vector3(length, height, thickness) if along_x else Vector3(thickness, height, length)


func _add_stair(parent: Node3D, s: Dictionary) -> void:
	var node := _group(parent, "%s_%s" % [s.id, String(s.name).replace(" ", "")])
	node.set_meta("stair_id", s.id)
	node.set_meta("zone_id", s.zone)
	var width: float = s.x1 - s.x0
	var xc: float = (s.x0 + s.x1) / 2.0
	var run: float = absf(s.z_high - s.z_low)
	var rise := Layout.UPPER_Y
	var dir := signf(s.z_high - s.z_low)
	var length := sqrt(run * run + rise * rise)
	var t := Layout.RAMP_THICKNESS
	var normal := Vector3(0, run, -dir * rise) / length
	var x_axis := Vector3.RIGHT
	var basis := Basis(x_axis, normal, x_axis.cross(normal))
	var top_mid := Vector3(xc, rise / 2.0, (s.z_low + s.z_high) / 2.0)
	var ramp_colour := Color(0.3, 0.5, 0.75)
	_add_box(node, "Ramp", top_mid - normal * (t / 2.0), Vector3(width, t, length), ramp_colour, basis)
	# Balustrade on the open side (collides, so nobody falls off the side): short
	# axis-aligned panels stepping up with the ramp, standing on the ramp's edge.
	# Vertical faces on purpose: a single panel turned with the slope leans
	# downhill, and its lower end caught guards' shoulders at the foot of S2
	# (Phase 3).
	var rail_x: float = s.x1 if s.open_side == "east" else s.x0
	var panels := Layout.HANDRAIL_PANELS
	for i in panels:
		var s_a := run * i / panels
		var s_b := run * (i + 1) / panels
		var bottom := maxf(rise * s_a / run - 0.35, 0.0)
		var top := rise * s_b / run + Layout.HANDRAIL_HEIGHT
		var z_mid: float = s.z_low + dir * (s_a + s_b) / 2.0
		_add_box(node, "Handrail%d" % i, Vector3(rail_x, (bottom + top) / 2.0, z_mid), Vector3(0.1, top - bottom, run / panels),
			ramp_colour.darkened(0.3))
	# Stepped blocks under the ramp: they seal the space beneath it (no hidden
	# crawl space, no unreachable navmesh island) and read as steps from the side.
	var steps := Layout.RAMP_FILLER_STEPS
	var vertical_thickness := t * length / run
	for i in range(1, steps):
		var s0 := run * i / steps
		var h := rise * s0 / run - vertical_thickness - 0.02
		if h < 0.05:
			continue
		var seg := run / steps
		var zc: float = s.z_low + dir * (s0 + seg / 2.0)
		_add_box(node, "Step%02d" % i, Vector3(xc, h / 2.0, zc), Vector3(width, h, seg), ramp_colour.darkened(0.45))


func _add_cover(parent: Node3D, c: Dictionary) -> void:
	var y0 := Layout.floor_y(c.floor)
	var colour: Color = COVER_COLOURS.get(c.kind, Color.GRAY)
	var prefix: String = {"shelf": "Shelf", "rack": "Rack", "low": "Low", "carrel_desk": "CarrelDesk", "carrel_panel": "CarrelPanel"}[c.kind]
	for r in c.rects:
		var size := Vector3(r[2] - r[0], c.h, r[3] - r[1])
		var centre := Vector3((r[0] + r[2]) / 2.0, y0 + c.h / 2.0, (r[1] + r[3]) / 2.0)
		var body := _add_box(parent, "%s%02d" % [prefix, _next()], centre, size, colour)
		body.set_meta("cover", "full" if c.h >= 1.8 else "low")


## Adds a StaticBody3D (layer 1) with a "Mesh" and a "Shape" child.
func _add_box(parent: Node, node_name: String, centre: Vector3, size: Vector3, colour: Color, basis := Basis()) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.transform = Transform3D(basis, centre)
	body.collision_layer = 1
	body.collision_mask = 0
	_add(parent, body)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = _box_mesh(size)
	mesh.material_override = _material(colour)
	_add(body, mesh)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = _box_shape(size)
	_add(body, shape)
	_bodies += 1
	return body


# --- Planned gameplay markers -----------------------------------------------------------------

func _add_layout_markers() -> void:
	var layout := _group(_level, "Layout")
	# Design markers, not gameplay: hidden in play (the mission has its own
	# pickups, doors and HUD) and shown with the debug overlay (F3).
	layout.visible = false
	layout.add_to_group("debug_visuals", true)
	var labels := _group(layout, "ZoneLabels")
	for z in Layout.ZONES:
		var y := Layout.floor_y(z.floor) + 3.0
		for a in z.areas:
			var r: Array = a.rect
			var label := _label(labels, "%s_%s" % [z.id, String(a.name).replace(" ", "")],
				"%s · %s" % [z.id, a.name], Vector3((r[0] + r[2]) / 2.0, y, (r[1] + r[3]) / 2.0), z.colour.lightened(0.4), 0.02)
			label.set_meta("zone_id", z.id)
	var objectives := _group(layout, "Objectives")
	for i in Layout.OBJECTIVES.size():
		var o: Dictionary = Layout.OBJECTIVES[i]
		var marker := _marker(objectives, "O%d" % (i + 1), o.pos)
		for key in ["id", "title", "zone", "note"]:
			marker.set_meta(key, o[key])
		_label(marker, "Label", "O%d · %s" % [i + 1, o.title], Vector3(0, 2.3, 0), Color(1.0, 0.95, 0.4), 0.012)
		_beacon(marker, Color(1.0, 0.85, 0.2))
	var exit := _marker(layout, "Exit", Layout.OBJECTIVES[4].pos)
	exit.set_meta("opening", "Loading Dock Exit")
	var gates := _group(layout, "Gates")
	for g in Layout.GATES:
		var found := Layout.find_opening(g.opening)
		var marker := _marker(gates, String(g.opening).validate_node_name().replace(" ", "").replace("–", "-"), found.centre)
		marker.set_meta("opening", g.opening)
		marker.set_meta("needs", g.needs)
		marker.set_meta("guards", g.guards)
		marker.set_meta("type", found.opening.type)
		var colour: Color = HEADER_COLOURS[found.opening.type]
		_label(marker, "Label", "%s\n(%s)" % [g.opening, g.needs], Vector3(0, 3.0, 0), colour.lightened(0.3), 0.009)
	var patrols := _group(layout, "PlannedPatrols")
	for i in Layout.PATROLS.size():
		if not Layout.PATROLS[i].has("guard"):
			_add_route(patrols, i)
	var hiding := _group(layout, "HidingSpots")
	for h in Layout.HIDING:
		var marker := _marker(hiding, String(h.name).replace(" ", ""), h.pos)
		marker.set_meta("zone_id", h.zone)
		_label(marker, "Label", "hide", Vector3(0, 1.4, 0), Color(0.5, 0.75, 1.0), 0.008)


## The guards: for each patrol loop with a "guard", its PatrolRoute and a guard
## instance under "Guards" (the tutorial's layout: Guards/<Route> + Guards/<Guard>).
## Added after the bake and outside the tree, so the guards don't start while
## the tool runs (CharacterBody3D is not baked into the navmesh anyway).
func _add_guards() -> void:
	var guards := _group(_level, "Guards")
	for i in Layout.PATROLS.size():
		var p: Dictionary = Layout.PATROLS[i]
		if not p.has("guard"):
			continue
		var route := _add_route(guards, i)
		var first := Layout.patrol_point(p, 0)
		var second := Layout.patrol_point(p, 1)
		var guard := (load(GUARD_SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
		guard.name = p.guard
		guard.position = first + Vector3(0, 0.05, 0)
		guard.rotation.y = atan2(-(second.x - first.x), -(second.z - first.z))
		guard.set("patrol_route", route)
		guard.set_meta("patrol_id", p.id)
		guards.add_child(guard)
		guard.owner = _level   # an instance: only its root is owned by the level


func _add_route(parent: Node, index: int) -> Node3D:
	var p: Dictionary = Layout.PATROLS[index]
	var route := Node3D.new()
	route.name = "%s_%s" % [p.id, String(p.name).replace(" ", "")]
	route.set_script(load("res://scripts/npc/patrol_route.gd"))
	route.set("debug_color", PATROL_COLOURS[index % PATROL_COLOURS.size()])
	route.set_meta("zone_id", p.zone)
	route.set_meta("patrol_id", p.id)
	_add(parent, route)
	for k in p.points.size():
		var point := Marker3D.new()
		point.name = "Point%d" % k
		point.set_script(load("res://scripts/npc/patrol_point.gd"))
		point.position = Layout.patrol_point(p, k)
		if p.has("wait"):
			point.set("wait_time", p.wait)
		_add(route, point)
	return route


func _marker(parent: Node, node_name: String, pos: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = node_name
	m.position = pos
	_add(parent, m)
	return m


func _label(parent: Node, node_name: String, text: String, pos: Vector3, colour: Color, pixel: float) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = pixel
	label.font_size = 48
	label.outline_size = 10
	label.modulate = colour
	label.no_depth_test = false
	_add(parent, label)
	return label


## A thin glowing post (visual only, no collision) so planned locations stand out in the graybox.
func _beacon(parent: Node, colour: Color) -> void:
	var post := MeshInstance3D.new()
	post.name = "Beacon"
	var mesh := CylinderMesh.new()
	mesh.resource_scene_unique_id = "CylinderMesh_beacon"
	mesh.top_radius = 0.06
	mesh.bottom_radius = 0.06
	mesh.height = 2.0
	if not _meshes.has("beacon"):
		_meshes["beacon"] = mesh
	post.mesh = _meshes["beacon"]
	post.position = Vector3(0, 1.0, 0)
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var key := "beacon_material"
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.resource_scene_unique_id = "Material_beacon"
		m.albedo_color = colour
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = 1.5
		_materials[key] = m
	post.material_override = _materials[key]
	_add(parent, post)


# --- Helpers -----------------------------------------------------------------------------------

func _group(parent: Node, node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	_add(parent, n)
	return n


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = _level


func _next() -> int:
	_counter += 1
	return _counter


func _material(colour: Color) -> StandardMaterial3D:
	var key := colour.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.resource_scene_unique_id = "Material_%s" % key
		m.albedo_color = colour
		m.roughness = 1.0
		_materials[key] = m
	return _materials[key]


func _box_mesh(size: Vector3) -> BoxMesh:
	var key := _size_key(size)
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.resource_scene_unique_id = "BoxMesh_%s" % key
		m.size = size
		_meshes[key] = m
	return _meshes[key]


func _box_shape(size: Vector3) -> BoxShape3D:
	var key := _size_key(size)
	if not _shapes.has(key):
		var s := BoxShape3D.new()
		s.resource_scene_unique_id = "BoxShape_%s" % key
		s.size = size
		_shapes[key] = s
	return _shapes[key]


func _size_key(size: Vector3) -> String:
	return ("%.3f_%.3f_%.3f" % [size.x, size.y, size.z]).replace(".", "p").replace("-", "m")
