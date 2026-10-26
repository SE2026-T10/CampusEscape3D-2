extends SceneTree

## Development tool: builds the Expanded Library graybox from the layout data
## in maps/library/tools/expanded_layout.gd, bakes its navigation mesh and saves
##   res://maps/library/scenes/expanded_library.tscn
##   res://maps/library/resources/expanded_library_navmesh.tres
## Run from the project folder:
##   godot --headless --path . --script res://maps/library/tools/build_expanded_graybox.gd
## Exits with code 0 on success and 1 on failure.
##
## The scene follows the tutorial's conventions: every solid piece is a
## StaticBody3D on physics layer 1 ("world") with a "Mesh" and a "Shape"
## child, all level geometry sits under NavigationRegion3D (the navmesh is
## baked from static colliders on layer 1), and the player is an instance of
## shared/scenes/player/player.tscn. The mission (objectives, access doors, the exit,
## checkpoints) is built under "Gameplay" from the layout's mission data, with
## the tutorial's systems and node layout; "Layout" keeps design markers and
## labels (objectives, gates, planned patrols, hiding spots).
##
## While the level is a graybox, this tool and the layout data are the source
## of truth: change the data and rebuild instead of editing the scene by hand.

const Layout := preload("res://maps/library/tools/expanded_layout.gd")
const SCENE_PATH := "res://maps/library/scenes/expanded_library.tscn"
const NAVMESH_PATH := "res://maps/library/resources/expanded_library_navmesh.tres"
const PLAYER_SCENE := "res://shared/scenes/player/player.tscn"
const GUARD_SCENE := "res://shared/scenes/npc/guard.tscn"

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
	_add_dressing()
	_assign_floor_layers(_level, Transform3D.IDENTITY)
	_batch_static_meshes()
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
	print("Built %s (layout %s): %d solid pieces; navmesh %d polygons, %d vertices -> %s; dressing: %d meshes, %d lights; %d boxes batched into %d MultiMeshes" % [
		SCENE_PATH, Layout.VERSION, _bodies, nav_mesh.get_polygon_count(), nav_mesh.get_vertices().size(), NAVMESH_PATH,
		_dressing_meshes, _light_count, _batched_boxes, _batch_meshes])
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
	# Same settings as the tutorial's navmesh (maps/tutorial/resources/library_navmesh.tres).
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.agent_height = 1.75
	nav_mesh.region_min_size = 8.0
	return nav_mesh


# --- Shared runtime systems ----------------------------------------------------------------

## The level-wide systems every map has, with the same node names and scripts
## as in the tutorial (maps/tutorial/scenes/library_graybox.tscn): game flow and its
## menus, the stealth director, the noise hub, the stealth HUD, the detection
## debug panel and the audio director. Each finds the others through its group
## when the level loads and is freed with the level, so a map never shares or
## duplicates them. The mission systems (ObjectiveManager, CheckpointManager,
## ObjectiveHud) are added by _add_gameplay().
const RUNTIME_SYSTEMS := [
	["StealthDirector", "Node", "res://shared/scripts/stealth/stealth_director.gd"],
	["StealthHud", "CanvasLayer", "res://shared/scripts/ui/stealth_hud.gd"],
	["NoiseSystem", "Node3D", "res://shared/scripts/noise/noise_system.gd"],
	["DetectionDebugHud", "CanvasLayer", "res://shared/scripts/debug/detection_debug_hud.gd"],
	["GameFlow", "Node", "res://shared/scripts/game/game_flow.gd"],
	["GameMenus", "CanvasLayer", "res://shared/scripts/ui/game_menus.gd"],
	["AudioDirector", "Node", "res://shared/scripts/presentation/audio_director.gd"],
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
	"objectives": "res://features/objectives/objective_manager.gd",
	"checkpoints": "res://features/checkpoints/checkpoint_manager.gd",
	"trigger": "res://features/objectives/objective_trigger.gd",
	"item": "res://features/objectives/access_card.gd",
	"door": "res://features/objectives/access_door.gd",
	"exit": "res://features/objectives/exit_door.gd",
	"checkpoint": "res://features/checkpoints/checkpoint.gd",
	"noise": "res://shared/scripts/noise/noise_maker.gd",
	"hud": "res://shared/scripts/ui/objective_hud.gd",
	"hiding": "res://shared/scripts/stealth/hiding_spot.gd",
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
	var hiding := _group(gameplay, "HidingSpots")
	for h in Layout.HIDING:
		_add_hiding_spot(hiding, h)
	var signs := _group(_group(_level, "Dressing"), "Signs")
	for k in Layout.SIGNS.size():
		_add_sign(signs, Layout.SIGNS[k], k)
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
	if c.has("spawn"):
		spawn.position = c.spawn - cp.position + Vector3(0, 0.05, 0)
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


## A HidingSpot (the tutorial's script and size) with a dark floor mark.
func _add_hiding_spot(parent: Node, h: Dictionary) -> void:
	var spot := _scripted(parent, String(h.name).replace(" ", ""), Area3D.new(), "hiding") as Area3D
	spot.position = h.pos + Vector3(0, 0.6, 0)
	spot.set_meta("zone_id", h.zone)
	_shape(spot, Vector3(1.4, 1.2, 1.0))
	var mark := MeshInstance3D.new()
	mark.name = "FloorMark"
	mark.position = Vector3(0, -0.594, 0)
	mark.mesh = _box_mesh(Vector3(1.4, 0.01, 1.0))
	mark.material_override = _material(Color(0.08, 0.1, 0.2))
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(spot, mark)


## A sign as in the tutorial: a 0.34 m board with a Label3D, no collision.
func _add_sign(parent: Node, sign: Dictionary, index: int) -> void:
	var node := Node3D.new()
	node.name = "Sign%02d" % index
	node.position = sign.pos
	node.rotation_degrees = Vector3(0, sign.facing, 0)
	_add(parent, node)
	var width := maxf(1.6, String(sign.text).length() * 0.105 + 0.4)
	var board := MeshInstance3D.new()
	board.name = "Board"
	board.position = Vector3(0, 0, -0.03)
	board.mesh = _box_mesh(Vector3(width, 0.34, 0.04))
	board.material_override = _look("sign_red" if sign.get("red", false) else "sign_board")   # the tutorial's sign boards
	_add(node, board)
	var text := Label3D.new()
	text.name = "Text"
	text.position = Vector3(0, 0, 0.01)
	text.text = sign.text
	text.font_size = 36
	text.outline_size = 8
	text.modulate = Color(1, 0.75, 0.7) if sign.get("red", false) else Color(0.9, 0.95, 1.0)
	_add(node, text)


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
	# v4: the tutorial's ambient colour and key light; the ambient energy is a
	# little above its 0.42 because these rooms are larger and have fewer lights
	# per square metre, so the spots between lights are never darker than the
	# v3 graybox (0.55 ambient, no lamps) was everywhere.
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = env
	_add(_level, world)
	var light := DirectionalLight3D.new()
	light.name = "KeyLight"
	light.rotation_degrees = Vector3(-52, -28, 0)
	light.light_color = Color(1, 0.95, 0.88)
	light.light_energy = 0.4
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	# v4: indoors no view is longer than about 40 m; the default 100 m spread the
	# shadow map over the whole building (blurrier, and every caster drawn).
	light.directional_shadow_max_distance = 40.0
	_add(_level, light)


func _add_debug_and_player(region: NavigationRegion3D) -> void:
	var debug := Node3D.new()
	debug.name = "NavigationDebug"
	debug.set_script(load("res://shared/scripts/debug/navigation_debug.gd"))
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
	var body := _add_body(parent, "Floor" if not upper else "UpperSlab", centre, size)
	# Visuals: the room's floor finish, in tiles; an upper slab's underside is the
	# ceiling of the room below (layer 2, like the tutorial's ceilings).
	var k := 0
	for a in Layout.zone(f.zone).areas:
		var part := _clip(r, a.rect)
		if part.is_empty():
			continue
		for t in _tiles(part, FLOOR_TILE):
			var tc := Vector3((t[0] + t[2]) / 2.0, 0, (t[1] + t[3]) / 2.0) - centre
			var w: float = t[2] - t[0]
			var d: float = t[3] - t[1]
			var tile_name := "Mesh" if k == 0 else "Mesh_%d" % k
			if upper:
				var top_t := thickness - 0.1
				_visual(body, tile_name, Vector3(tc.x, thickness / 2.0 - top_t / 2.0, tc.z), Vector3(w, top_t, d), AREA_FLOORS[a.name], true)
				_visual(body, "Ceiling_%d" % k, Vector3(tc.x, -thickness / 2.0 + 0.05, tc.z), Vector3(w, 0.1, d), "ceiling", false, LAYER_GROUND)
			else:
				_visual(body, tile_name, Vector3(tc.x, 0, tc.z), Vector3(w, thickness, d), AREA_FLOORS[a.name])
			k += 1


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
	var base_name := "%s%02d" % ["Railing" if railing else "Wall", index]
	for k in intervals.size():
		var iv: Array = intervals[k]
		var length: float = iv[1] - iv[0]
		if length < 0.01:
			continue
		var mid: float = (iv[0] + iv[1]) / 2.0
		var centre := _wall_point(along_x, mid, fixed, y0 + height / 2.0)
		var body := _add_body(parent, "%s_%d" % [base_name, k], centre, _wall_size(along_x, length, height, t))
		# Visuals: plaster (wood for a balcony railing) in tiles, then the trims.
		var tiles := _tiles([iv[0], 0.0, iv[1], 1.0], WALL_TILE)
		for n in tiles.size():
			var tl: Array = tiles[n]
			var tile_mid: float = (tl[0] + tl[2]) / 2.0 - mid
			_visual(body, "Mesh" if n == 0 else "Mesh_%d" % n, _wall_point(along_x, tile_mid, 0.0, 0.0),
				_wall_size(along_x, tl[2] - tl[0], height, t), "wood" if railing else "wall", true)
		if railing:
			_visual(body, "Cap", _wall_point(along_x, 0.0, 0.0, height / 2.0 + 0.025),
				_wall_size(along_x, length, 0.05, t + 0.06), "trim", false)
		else:
			_add_wainscot(body, wall, along_x, fixed, iv, [lo - t / 2.0, hi + t / 2.0], mid, height)
	# Headers over doorways (the tutorial's cream; red on card gates, amber on the
	# one-way shortcut, green on the exit), wooden trims, a closed panel in the exit.
	for o in openings:
		if railing or o.type == "stair":
			continue
		var header_h := height - Layout.DOOR_HEIGHT
		var tag := String(o.name).validate_node_name().replace(" ", "").replace("–", "-")
		var header_look: String = {"gate": "restricted", "shortcut": "shortcut", "exit": "exit"}.get(o.type, "header")
		_add_box(parent, "Header_" + tag, _wall_point(along_x, o.at, fixed, y0 + Layout.DOOR_HEIGHT + header_h / 2.0),
			_wall_size(along_x, o.width, header_h, t), HEADER_COLOURS.get(o.type, Color.GRAY), Basis(), header_look)
		_add_door_trim(parent, "Trim_" + tag, o, along_x, fixed, y0)
		if o.type == "exit":
			_add_box(parent, "ExitDoorPanel", _wall_point(along_x, o.at, fixed, y0 + Layout.DOOR_HEIGHT / 2.0),
				_wall_size(along_x, o.width, Layout.DOOR_HEIGHT, t * 0.6), HEADER_COLOURS.exit)


## A wainscot (1 m panel and a rail) on each face of a wall piece that faces a
## room: wood in the public rooms, dark red with a red rail in the restricted
## zones (as the tutorial's restricted trims). Split where the room changes.
func _add_wainscot(body: Node, wall: Dictionary, along_x: bool, fixed: float, iv: Array, ends: Array, mid: float, height: float) -> void:
	var t := Layout.WALL_THICKNESS
	# Where the piece runs into a crossing wall (its extended end), the room's
	# face starts half a thickness inside.
	var a: float = iv[0] + (t if is_equal_approx(iv[0], ends[0]) else 0.0)
	var b: float = iv[1] - (t if is_equal_approx(iv[1], ends[1]) else 0.0)
	if b - a < 0.2:
		return
	var y_base: float = -height / 2.0
	for side in [-1.0, 1.0]:
		# Cut the face where the zone or room on that side changes.
		var cuts := [a, b]
		for zn in Layout.ZONES:
			if zn.floor != wall.floor:
				continue
			for ar in zn.areas:
				var r: Array = ar.rect
				for c in ([r[0], r[2]] if along_x else [r[1], r[3]]):
					if c > a + 0.05 and c < b - 0.05:
						cuts.append(c)
		cuts.sort()
		for n in range(cuts.size() - 1):
			var p0: float = cuts[n]
			var p1: float = cuts[n + 1]
			if p1 - p0 < 0.1:
				continue
			var probe := (p0 + p1) / 2.0
			var off: float = side * (t / 2.0 + 0.2)
			var found := _area_at(wall.floor, probe if along_x else fixed + off, fixed + off if along_x else probe)
			if found[0].is_empty():
				continue   # the outside of the building
			var restricted: bool = found[0].id in RESTRICTED_ZONES
			var along := (p0 + p1) / 2.0 - mid
			_visual(body, "Wainscot%s_%d" % ["N" if side < 0 else "P", n],
				_wall_point(along_x, along, side * (t / 2.0 + 0.015), y_base + 0.5),
				_wall_size(along_x, p1 - p0, 1.0, 0.03), "restricted_panel" if restricted else "trim")
			_visual(body, "Rail%s_%d" % ["N" if side < 0 else "P", n],
				_wall_point(along_x, along, side * (t / 2.0 + 0.03), y_base + 1.02),
				_wall_size(along_x, p1 - p0, 0.06, 0.06), "restricted" if restricted else "wood_dark", false)


## Wooden posts and a lintel around a doorway, as the tutorial's Dressing/Doorways
## (red on the card gates, amber on the shortcut). They sit on the wall's solid
## ends, outside the opening, so the doorway keeps its full width.
func _add_door_trim(parent: Node, node_name: String, o: Dictionary, along_x: bool, fixed: float, y0: float) -> void:
	var trim := _group(parent, node_name)
	var look: String = {"gate": "restricted", "shortcut": "shortcut"}.get(o.type, "trim")
	var depth := Layout.WALL_THICKNESS + 0.08
	for side in [-1.0, 1.0]:
		var at: float = o.at + side * (o.width / 2.0 + 0.07)
		_visual(trim, "Post%d" % (1 if side < 0 else 2), _wall_point(along_x, at, fixed, y0 + Layout.DOOR_HEIGHT / 2.0),
			_wall_size(along_x, 0.14, Layout.DOOR_HEIGHT, depth), look)
	_visual(trim, "Lintel", _wall_point(along_x, o.at, fixed, y0 + Layout.DOOR_HEIGHT + 0.06),
		_wall_size(along_x, o.width + 0.28, 0.12, depth), look)


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
	var ramp := _add_box(node, "Ramp", top_mid - normal * (t / 2.0), Vector3(width, t, length), ramp_colour, basis, "stair")
	# Light stripes across the ramp every 0.45 m, flush on its surface, so it
	# reads as a stair from both floors (one MultiMesh, no collision).
	var stripes := MultiMeshInstance3D.new()
	stripes.name = "Nosing"
	stripes.set_script(load(BATCH_SCRIPT))
	stripes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stripes.material_override = _look("nosing")
	var data := PackedFloat32Array()
	var count := int((length - 0.4) / 0.45)
	for i in count:
		BatchedBoxes.pack(data, Transform3D(Basis.from_scale(Vector3(width - 0.16, 0.01, 0.07)),
			Vector3(0, t / 2.0 + 0.004, -length / 2.0 + 0.3 + i * 0.45)), Color.WHITE)
	stripes.set("boxes", data)
	_add(ramp, stripes)
	_dressing_meshes += 1
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
		var rail := _add_box(node, "Handrail%d" % i, Vector3(rail_x, (bottom + top) / 2.0, z_mid), Vector3(0.1, top - bottom, run / panels),
			ramp_colour.darkened(0.3), Basis(), "wood")
		_visual(rail, "Cap", Vector3(0, (top - bottom) / 2.0 + 0.02, 0), Vector3(0.14, 0.04, run / panels), "brass", false)
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
		_add_box(node, "Step%02d" % i, Vector3(xc, h / 2.0, zc), Vector3(width, h, seg), ramp_colour.darkened(0.45), Basis(), "wood_dark")


func _add_cover(parent: Node3D, c: Dictionary) -> void:
	var y0 := Layout.floor_y(c.floor)
	var colour: Color = COVER_COLOURS.get(c.kind, Color.GRAY)
	var prefix: String = {"shelf": "Shelf", "rack": "Rack", "low": "Low", "carrel_desk": "CarrelDesk", "carrel_panel": "CarrelPanel"}[c.kind]
	var look: String = c.get("look", "")
	for r in c.rects:
		var size := Vector3(r[2] - r[0], c.h, r[3] - r[1])
		var centre := Vector3((r[0] + r[2]) / 2.0, y0 + c.h / 2.0, (r[1] + r[3]) / 2.0)
		var index := _next()
		var body := _add_box(parent, "%s%02d" % [prefix, index], centre, size, colour, Basis(), COVER_BODY_LOOKS.get(look, ""))
		body.set_meta("cover", "full" if c.h >= 1.8 else "low")
		if look != "":
			body.set_meta("look", look)
			_dress_cover(body, look, size, index)


## The material of a piece of furniture's own box, by look.
const COVER_BODY_LOOKS := {
	"bookcase": "wood", "archive_shelf": "wood_dark", "display_case": "wood", "low_bookcase": "wood",
	"reading_table": "desk", "office_desk": "desk", "study_desk": "desk", "circulation_desk": "cabinet",
	"planter": "planter", "carrel_desk": "carrel", "carrel_panel": "desk", "work_table": "steel",
	"storage_rack": "steel", "crate": "crate", "archive_crate": "crate_dark", "pedestal": "stone",
}


## Decoration on a piece of furniture (children of its body, no collision). The
## body's box is the collider and stays as it was: books line a bookcase's faces,
## a tabletop overhangs a desk by 4 cm, boxes on a rack stand 2 cm proud of it.
## Anything on top of low cover stays small, so low cover still looks low.
func _dress_cover(body: StaticBody3D, look: String, size: Vector3, index: int) -> void:
	var top := size.y / 2.0
	match look:
		"bookcase", "archive_shelf", "display_case", "low_bookcase":
			var books := Node3D.new()
			books.name = "Books"
			books.set_script(load(BOOKS_SCRIPT))
			books.set("size", size)
			books.set("rows", 2 if size.y < 1.5 else (5 if size.y > 2.3 else 4))
			books.set("book_seed", index)
			books.set("draw_distance", BOOKS_DRAW_DISTANCE)
			_add(body, books)
			_dressing_meshes += 1
			_visual(body, "Top", Vector3(0, top + 0.02, 0), size + Vector3(0.06, -size.y + 0.04, 0.06), "wood_dark")
		"reading_table", "office_desk", "study_desk":
			_visual(body, "Top", Vector3(0, top - 0.01, 0), Vector3(size.x + 0.08, 0.06, size.z + 0.08), "desk_top")
			if look == "office_desk":
				_visual(body, "Monitor", Vector3(-size.x * 0.3, top + 0.2, 0.05), Vector3(0.5, 0.32, 0.04), "screen", false)
				_visual(body, "Papers", Vector3(size.x * 0.25, top + 0.03, 0.1), Vector3(0.3, 0.02, 0.22), "paper", false)
			elif look == "study_desk":
				_add_lamp(body, Vector3(-size.x * 0.3, top, 0))
			else:
				_visual(body, "Books", Vector3(size.x * 0.28, top + 0.06, 0), Vector3(0.24, 0.1, 0.32), "poster_b", false)
		"circulation_desk":
			_visual(body, "Top", Vector3(0, top - 0.01, 0), Vector3(size.x + 0.1, 0.06, size.z + 0.1), "desk_top")
			_visual(body, "Front", Vector3(0, 0, size.z / 2.0 + 0.015), Vector3(size.x - 0.3, size.y - 0.3, 0.03), "trim")
			_visual(body, "Monitor", Vector3(-1.2, top + 0.2, -0.2), Vector3(0.5, 0.32, 0.04), "screen", false)
			_visual(body, "Books", Vector3(0.4, top + 0.06, 0.1), Vector3(0.4, 0.1, 0.3), "poster_a", false)
			# The tutorial's globe, on the desk's east end.
			_cylinder(body, "GlobeStand", Vector3(size.x / 2.0 - 0.4, top + 0.1, 0), 0.07, 0.2, "brass")
			var globe := MeshInstance3D.new()
			globe.name = "Globe"
			globe.position = Vector3(size.x / 2.0 - 0.4, top + 0.38, 0)
			var sphere := SphereMesh.new()
			sphere.resource_scene_unique_id = "SphereMesh_globe"
			sphere.radius = 0.2
			sphere.height = 0.4
			sphere.radial_segments = 12
			sphere.rings = 6
			globe.mesh = sphere
			globe.material_override = _look("globe")
			_add(body, globe)
			_dressing_meshes += 1
		"planter":
			_visual(body, "Soil", Vector3(0, top + 0.01, 0), Vector3(size.x - 0.1, 0.02, size.z - 0.1), "wood_dark", false)
			# Low shrubs: small clumps, at most 0.3 m above the planter (it stays low cover).
			for n in 5:
				var fx := (n - 2) * size.x / 5.5
				var fz := 0.18 * (1 if n % 2 == 0 else -1) * size.z / 1.0
				var fs := 0.24 + 0.05 * ((index + n) % 3)
				_visual(body, "Leaves%d" % n, Vector3(fx, top + fs / 2.0 - 0.04, fz),
					Vector3(fs, fs - 0.04, fs), "foliage" if n % 2 == 0 else "foliage_light")
		"carrel_desk":
			_visual(body, "Top", Vector3(0, top - 0.01, 0.02), Vector3(size.x, 0.05, size.z + 0.04), "desk_top")
			_add_lamp(body, Vector3(size.x * 0.3, top, -size.z * 0.25))
		"work_table":
			_visual(body, "Top", Vector3(0, top - 0.01, 0), Vector3(size.x + 0.06, 0.05, size.z + 0.06), "wood")
			for n in 3:
				var h := 0.1 + 0.06 * ((index + n) % 3)
				_visual(body, "Stack%d" % n, Vector3(-size.x * 0.3 + n * size.x * 0.25, top + h / 2.0, 0.1 * (n % 2)),
					Vector3(0.3, h, 0.22), ["poster_a", "poster_b", "poster_c"][n], false)
		"storage_rack":
			# Three shelves of cardboard boxes, 2 cm proud of the frame.
			for level in 3:
				var y := -top + 0.05 + level * size.y / 3.0
				_visual(body, "Shelf%d" % level, Vector3(0, y, 0), Vector3(size.x + 0.06, 0.04, size.z + 0.06), "steel", false)
				for half in 2:
					var bh := size.y / 3.0 - 0.18 - 0.08 * ((index + level + half) % 2)
					_visual(body, "Box%d%d" % [level, half], Vector3((half - 0.5) * size.x / 2.0, y + 0.02 + bh / 2.0, 0),
						Vector3(size.x / 2.0 - 0.08, bh, size.z + 0.04), "cardboard" if (level + half) % 2 == 0 else "crate")
		"crate":
			_visual(body, "Pallet", Vector3(0, -top + 0.06, 0), Vector3(size.x + 0.08, 0.12, size.z + 0.08), "wood_dark")
			for n in 2:
				_visual(body, "Band%d" % n, Vector3(0, -top + 0.4 + n * 0.5, 0), Vector3(size.x + 0.03, 0.08, size.z + 0.03), "crate_dark", false)
		"archive_crate":
			for n in 2:
				_visual(body, "Band%d" % n, Vector3(0, -top + 0.3 + n * 0.6, 0), Vector3(size.x + 0.03, 0.06, size.z + 0.03), "brass", false)
		"pedestal":
			_visual(body, "Top", Vector3(0, top - 0.03, 0), Vector3(size.x + 0.1, 0.06, size.z + 0.1), "brass")
			_visual(body, "Base", Vector3(0, -top + 0.06, 0), Vector3(size.x + 0.1, 0.12, size.z + 0.1), "stone")
		"carrel_panel":
			pass   # the desk wood is enough


## Hand-placed decoration on wall faces: [kind, position, facing (degrees, 0 = faces +z), look].
## Positions are 2 cm in front of a wall face (wall line ± 0.15).
const WALL_DECOR := [
	["clock", Vector3(0, 3.4, 27.83), 180.0, ""],        # lobby, over the main doors
	["clock", Vector3(0, 3.4, 9.83), 180.0, ""],         # reading hall, over its doors
	["clock", Vector3(3.0, Layout.UPPER_Y + 3.0, -7.83), 0.0, ""],   # balcony, over the staff wing door
	["poster", Vector3(11.83, 1.7, 14.0), -90.0, "poster_a"],
	["poster", Vector3(11.83, 1.7, 26.0), -90.0, "poster_c"],
	["poster", Vector3(11.83, 1.7, -6.0), -90.0, "poster_b"],
	["poster", Vector3(-11.83, 1.7, -8.0), 90.0, "poster_d"],
	["poster", Vector3(-11.83, 1.7, 6.0), 90.0, "poster_a"],
	["poster", Vector3(11.83, Layout.UPPER_Y + 1.7, 0.0), -90.0, "poster_c"],
	["poster", Vector3(11.83, Layout.UPPER_Y + 1.7, 6.0), -90.0, "poster_d"],
	["poster", Vector3(-12.17, 1.7, 14.0), -90.0, "poster_b"],
	["poster", Vector3(-12.17, 1.7, 2.0), -90.0, "poster_c"],
]
## Rugs on public floors: [rect x0, z0, x1, z1, floor y, look].
const RUGS := [
	[-3.0, 17.5, 3.0, 22.5, 0.0, "rug_teal"],                 # lobby
	[-8.5, -11.0, -3.5, 5.0, 0.0, "rug_teal"], [3.5, -11.0, 8.5, 5.0, 0.0, "rug_teal"],   # reading hall
	[-26.5, 13.5, -15.5, 17.5, 0.0, "rug_teal"], [-26.5, 21.0, -15.5, 25.0, 0.0, "rug_teal"],   # browsing hall
	[-2.5, -5.0, 2.5, -1.0, Layout.UPPER_Y, "rug_teal"], [4.5, 1.0, 9.5, 5.0, Layout.UPPER_Y, "rug_teal"],   # balcony
	[12.3, -11.6, 29.7, -10.4, Layout.UPPER_Y, "rug_red"],   # archive hall runner, G2 → back gate
]


## The dressing that is not part of one piece: lights, ceilings and the roof,
## chairs, rugs, stair landings, windows, clocks and posters, and the accents
## on the mission's objects. Added after the bake, under "Dressing".
func _add_dressing() -> void:
	var dressing: Node3D
	if _level.has_node("Dressing"):
		dressing = _level.get_node("Dressing")
	else:
		dressing = _group(_level, "Dressing")
	_add_lights(_group(dressing, "Lights"))
	_add_roof(_group(dressing, "Ceilings"))
	var props := _group(dressing, "Props")
	_add_chairs(props)
	_add_floor_marks(props)
	_add_windows(_group(dressing, "Windows"))
	_add_wall_decor(_group(dressing, "Landmarks"))
	_add_mission_accents(_group(dressing, "MissionAccents"))


## The tutorial's ceiling light (shared/scenes/props/ceiling_light.tscn) on a grid in
## every room, about LIGHT_SPACING apart (one in a small room). Under an upper slab and upstairs it
## sits on the ceiling; in the double-height halls (lobby, browsing hall,
## storage, dock) it hangs from the roof on a cord, as a pendant.
func _add_lights(parent: Node3D) -> void:
	for zn in Layout.ZONES:
		for a in zn.areas:
			var r: Array = a.rect
			var nx := maxi(1, roundi((r[2] - r[0]) / LIGHT_SPACING))
			var nz := maxi(1, roundi((r[3] - r[1]) / LIGHT_SPACING))
			for i in nx:
				for j in nz:
					var x: float = r[0] + (i + 0.5) * (r[2] - r[0]) / nx
					var z: float = r[1] + (j + 0.5) * (r[3] - r[1]) / nz
					var fixture_y: float   # the fixture's centre
					var pendant := false
					var spec: Array = LIGHT_GROUND
					if zn.floor == "upper":
						fixture_y = ROOF_Y - 0.04
						spec = LIGHT_UPPER
					elif zn.id == "A" and a.name == "Porch":
						fixture_y = Layout.GROUND_WALL_HEIGHT - 0.04
					elif _under_slab(x, z):
						fixture_y = Layout.UPPER_Y - Layout.SLAB_THICKNESS - 0.04
					else:
						fixture_y = PENDANT_Y
						pendant = true
						spec = LIGHT_PENDANT
					var light_name := "%s_%s_%d" % [zn.id, String(a.name).replace(" ", ""), i * nz + j]
					var light := _prop(parent, LIGHT_SCENE, light_name, Vector3(x, fixture_y - 3.4, z))
					_level.set_editable_instance(light, true)   # stores the overrides on its Light
					var omni := light.get_node("Light") as OmniLight3D
					omni.omni_range = spec[0]
					omni.light_energy = spec[1]
					omni.light_cull_mask = LIGHT_MASK_UPPER if zn.floor == "upper" else LIGHT_MASK_GROUND
					omni.distance_fade_enabled = true
					omni.distance_fade_begin = LIGHT_FADE_BEGIN
					omni.distance_fade_length = LIGHT_FADE_LENGTH
					if pendant:
						# A cord up to the roof (same layer as the fixture: hidden in top-down captures).
						var cord := _visual(light, "Cord", Vector3(0, 3.4 + (ROOF_Y - fixture_y) / 2.0, 0),
							Vector3(0.03, ROOF_Y - fixture_y, 0.03), "cord", false, 2)
					_light_count += 1


## The roof over the whole building at the top of the upper walls, the upper
## parts of the outer walls around the double-height halls, and the porch's
## ceiling: all above or outside every walkable place, so they never stand
## between a guard and the player. Without shadows, like the tutorial's
## ceilings; the roof on the overhead layer (hidden in top-down captures).
func _add_roof(parent: Node3D) -> void:
	var k := 0
	for t in _tiles([-36.15, -28.15, 36.15, 28.15], WALL_TILE):
		_visual(parent, "Roof_%d" % k, Vector3((t[0] + t[2]) / 2.0, ROOF_Y + 0.1, (t[1] + t[3]) / 2.0),
			Vector3(t[2] - t[0], 0.2, t[3] - t[1]), "roof", false, 2)
		k += 1
	_visual(parent, "Porch", Vector3(0, Layout.GROUND_WALL_HEIGHT + 0.1, 31.0), Vector3(10.3, 0.2, 6.3), "ceiling", false, LAYER_GROUND)
	# Outer walls above the ground floor where no upper wall stands: north (the
	# whole front), west of the browsing hall, east of storage and the dock.
	var g := Layout.GROUND_WALL_HEIGHT
	var h := ROOF_Y - g
	var t := Layout.WALL_THICKNESS
	var uppers := [[Vector3(0, g + h / 2.0, 28.0), Vector3(72.3, h, t)],
		[Vector3(-36.0, g + h / 2.0, 19.0), Vector3(t, h, 18.3)],
		[Vector3(36.0, g + h / 2.0, 11.0), Vector3(t, h, 34.3)]]
	for n in uppers.size():
		var pos: Vector3 = uppers[n][0]
		var size: Vector3 = uppers[n][1]
		var along_x := size.x > size.z
		var length := size.x if along_x else size.z
		var tiles := _tiles([-length / 2.0, 0.0, length / 2.0, 1.0], WALL_TILE)
		for m in tiles.size():
			var tl: Array = tiles[m]
			var c: float = (tl[0] + tl[2]) / 2.0
			_visual(parent, "UpperWall%d_%d" % [n, m], pos + (Vector3(c, 0, 0) if along_x else Vector3(0, 0, c)),
				_wall_size(along_x, tl[2] - tl[0], h, t), "wall", false, LAYER_GROUND)


## Chairs (shared/scenes/props/chair.tscn, no collision) pushed in at the tables and
## desks: each stands at most 0.15 m beyond its table's edge, inside the strip
## no agent walks in (the navmesh keeps 0.5 m from every collider).
func _add_chairs(parent: Node3D) -> void:
	var k := 0
	for c in Layout.COVER:
		var look: String = c.get("look", "")
		if not look in ["reading_table", "office_desk"]:
			continue
		var y0 := Layout.floor_y(c.floor)
		for r in c.rects:
			var cx: float = (r[0] + r[2]) / 2.0
			var w: float = r[2] - r[0]
			var d: float = r[3] - r[1]
			var cz: float = (r[1] + r[3]) / 2.0
			var seats := []
			if look == "office_desk":
				seats = [[cx - w * 0.3, 1.0]]   # behind the desk (the card is in front, in the middle)
			else:
				seats = [[cx - w / 4.0, -1.0], [cx + w / 4.0, 1.0]]
			for s in seats:
				var side: float = s[1]
				# The chair's back is on its local +z; it faces the table.
				var z: float = cz + side * (d / 2.0 - 0.06)
				_prop(parent, CHAIR_SCENE, "Chair%02d" % k, Vector3(s[0], y0, z), 0.0 if side > 0 else 180.0)
				k += 1


## Rugs on public floors, a red runner in the archive hall, a light landing
## strip at both ends of every stair (where the floor changes), and the
## yellow-black hazard stripes in front of the exit. All 5–10 mm thick on
## the floor, so nothing to walk into.
func _add_floor_marks(parent: Node3D) -> void:
	for n in RUGS.size():
		var r: Array = RUGS[n]
		var pieces := _tiles(r, FLOOR_TILE)   # tiled like the floors (lights per mesh)
		for m in pieces.size():
			var t: Array = pieces[m]
			_visual(parent, "Rug%02d" % n if m == 0 else "Rug%02d_%d" % [n, m], Vector3((t[0] + t[2]) / 2.0, r[4] + 0.005, (t[1] + t[3]) / 2.0),
				Vector3(t[2] - t[0], 0.01, t[3] - t[1]), r[5], false)
	for s in Layout.STAIRS:
		var dir := signf(s.z_high - s.z_low)
		var xc: float = (s.x0 + s.x1) / 2.0
		var width: float = s.x1 - s.x0
		_visual(parent, "%s_FootStrip" % s.id, Vector3(xc, 0.004, s.z_low - dir * 0.45), Vector3(width, 0.008, 0.9), "nosing", false)
		_visual(parent, "%s_TopStrip" % s.id, Vector3(xc, Layout.UPPER_Y + 0.004, s.z_high + dir * 0.45), Vector3(width, 0.008, 0.9), "nosing", false)
	var exit := Layout.find_opening(Layout.EXIT_DOOR.opening)
	var ec: Vector3 = exit.centre
	var w: float = exit.opening.width
	for n in 6:
		var z: float = ec.z - w / 2.0 + (n + 0.5) * w / 6.0
		_visual(parent, "Hazard%d" % n, Vector3(ec.x - 0.9, 0.004, z), Vector3(1.2, 0.008, w / 6.0),
			"hazard_yellow" if n % 2 == 0 else "hazard_black", false)


## Windows (frame and glowing blue glass, as the tutorial's) on the inside face
## of the outer walls, every 6 m, clear of doorways and of the walls that meet
## them. Outer walls only: nothing walkable is behind them.
func _add_windows(parent: Node3D) -> void:
	var k := 0
	for wall in Layout.WALLS:
		if wall.get("kind", "wall") == "railing":
			continue
		var along_x: bool = wall.a[1] == wall.b[1]
		var fixed: float = wall.a[1] if along_x else wall.a[0]
		if not (absf(fixed) > 27.9 if along_x else absf(fixed) > 35.9):
			continue   # an inside wall
		var lo: float = minf(wall.a[0], wall.b[0]) if along_x else minf(wall.a[1], wall.b[1])
		var hi: float = maxf(wall.a[0], wall.b[0]) if along_x else maxf(wall.a[1], wall.b[1])
		# Positions to keep clear: openings, and walls meeting this one.
		var blocked := []
		for o in wall.get("openings", []):
			blocked.append([o.at - o.width / 2.0 - 0.9, o.at + o.width / 2.0 + 0.9])
		for other in Layout.WALLS:
			if other == wall or other.floor != wall.floor:
				continue
			for p in [other.a, other.b]:
				var on_line: bool = is_equal_approx(p[1], fixed) if along_x else is_equal_approx(p[0], fixed)
				if on_line:
					var c: float = p[0] if along_x else p[1]
					blocked.append([c - 1.2, c + 1.2])
		var y0 := Layout.floor_y(wall.floor)
		var sill := 1.6 if wall.floor == "ground" else 1.3
		var pos := lo + 3.0
		while pos <= hi - 2.9:
			var clear := true
			for b in blocked:
				if pos + 0.85 > b[0] and pos - 0.85 < b[1]:
					clear = false
			# The side of the wall that is inside the building.
			var inside := 0.0
			for side in [-1.0, 1.0]:
				var off: float = fixed + side * 0.5
				var found := _area_at(wall.floor, pos if along_x else off, off if along_x else pos)
				if not found[0].is_empty():
					inside = side
			# Not over the ground floor's double-height halls' tall furniture, nor behind a stair.
			if clear and inside != 0.0 and not _behind_stair(wall.floor, along_x, fixed, pos):
				var face: float = fixed + inside * (Layout.WALL_THICKNESS / 2.0)
				var node := Node3D.new()
				node.name = "Window%02d" % k
				node.position = _wall_point(along_x, pos, face, y0 + sill + 0.7)
				node.rotation_degrees = Vector3(0, (0.0 if inside > 0 else 180.0) if along_x else (90.0 if inside > 0 else -90.0), 0)
				_add(parent, node)
				_visual(node, "Frame", Vector3(0, 0, 0.02), Vector3(1.7, 1.5, 0.04), "window_frame", false)
				_visual(node, "Glass", Vector3(0, 0, 0.03), Vector3(1.5, 1.3, 0.04), "window", false)
				_visual(node, "Sill", Vector3(0, -0.77, 0.06), Vector3(1.8, 0.06, 0.12), "wood", false)
				k += 1
			pos += 6.0


## True if a window at `pos` along an outer wall would be behind a stair (S3 runs along the west wall).
func _behind_stair(floor_name: String, along_x: bool, fixed: float, pos: float) -> bool:
	if floor_name != "ground" or along_x:
		return false
	for s in Layout.STAIRS:
		var near_wall: bool = absf(s.x0 - fixed) < 0.5 or absf(s.x1 - fixed) < 0.5
		if near_wall and pos > minf(s.z_low, s.z_high) - 1.0 and pos < maxf(s.z_low, s.z_high) + 1.0:
			return true
	return false


## Clocks (the tutorial's: rim, face, hands) and posters on wall faces.
func _add_wall_decor(parent: Node3D) -> void:
	for n in WALL_DECOR.size():
		var d: Array = WALL_DECOR[n]
		var node := Node3D.new()
		node.name = "%s%02d" % [String(d[0]).capitalize(), n]
		node.position = d[1]
		node.rotation_degrees = Vector3(0, d[2], 0)
		_add(parent, node)
		if d[0] == "clock":
			var rim := _cylinder(node, "Rim", Vector3.ZERO, 0.42, 0.05, "dark_metal", 16)
			rim.rotation_degrees = Vector3(90, 0, 0)
			var face := _cylinder(node, "Face", Vector3(0, 0, 0.01), 0.36, 0.05, "clock_face", 16)
			face.rotation_degrees = Vector3(90, 0, 0)
			_visual(node, "HourHand", Vector3(0.06, 0.06, 0.045), Vector3(0.04, 0.2, 0.01), "dark_metal", false).rotation_degrees = Vector3(0, 0, -45)
			_visual(node, "MinuteHand", Vector3(0, 0.13, 0.05), Vector3(0.03, 0.28, 0.01), "dark_metal", false)
		else:
			_visual(node, "Frame", Vector3(0, 0, 0.0), Vector3(0.86, 1.16, 0.03), "wood_dark", false)
			_visual(node, "Print", Vector3(0, 0.06, 0.01), Vector3(0.74, 0.86, 0.03), d[3], false)
			_visual(node, "Caption", Vector3(0, -0.45, 0.01), Vector3(0.6, 0.1, 0.03), "paper", false)


## Mission accents: a warm light over the staff card and over the manuscript
## (as the tutorial's spot on its card), a green glow at the exit and red ones
## at the card gates. They light small areas around objects, not the guards' paths.
func _add_mission_accents(parent: Node3D) -> void:
	for o in Layout.OBJECTIVES:
		if not o.has("item"):
			continue
		var glow := OmniLight3D.new()
		glow.name = "Glow_" + String(o.id)
		glow.position = o.item + Vector3(0, 0.9, 0)
		glow.light_color = Color(1.0, 0.85, 0.5)
		glow.light_energy = 1.2
		glow.omni_range = 2.5
		_fade(glow)
		_add(parent, glow)
		_light_count += 1
	var exit := Layout.find_opening(Layout.EXIT_DOOR.opening)
	var exit_glow := OmniLight3D.new()
	exit_glow.name = "ExitGlow"
	exit_glow.position = exit.centre + Vector3(-1.2, 2.9, 0)
	exit_glow.light_color = Color(0.3, 1.0, 0.5)
	exit_glow.light_energy = 1.0
	exit_glow.omni_range = 4.5
	_fade(exit_glow)
	_add(parent, exit_glow)
	_light_count += 1
	for d in Layout.DOORS:
		if not d.has("key"):
			continue
		var found := Layout.find_opening(d.opening)
		var gate := OmniLight3D.new()
		gate.name = "GateGlow_" + String(d.name).replace(" ", "")
		gate.position = found.centre + Vector3(0, 3.0, 0)
		gate.light_color = Color(1.0, 0.35, 0.3)
		gate.light_energy = 0.6
		gate.omni_range = 3.0
		_fade(gate)
		_add(parent, gate)
		_light_count += 1


## Puts every static surface of the level on its floor's render layer (see
## LAYER_GROUND), so each floor's lights reach only that floor's surfaces. Left on
## layer 1: the player, guards, gameplay objects, design markers and the props
## that are scene instances (chairs); ceilings and fixtures keep layer 2; the
## stairs, between the floors, get both floor layers.
func _assign_floor_layers(node: Node, parent_xf: Transform3D) -> void:
	if node.get_parent() == _level and String(node.name) in ["Player", "Guards", "Gameplay", "Layout", "NavigationDebug"]:
		return
	if node != _level and node.owner != _level:
		return   # inside a prop instance
	var xf := parent_xf * ((node as Node3D).transform if node is Node3D else Transform3D.IDENTITY)
	if node is GeometryInstance3D and (node as GeometryInstance3D).layers == 1:
		var gi := node as GeometryInstance3D
		var on_stair := false
		var n := node.get_parent()
		while n:
			if String(n.name) == "Stairs":
				on_stair = true
			n = n.get_parent()
		var centre_y := (xf * gi.get_aabb()).get_center().y
		gi.layers = LAYER_GROUND | LAYER_UPPER if on_stair else (LAYER_UPPER if centre_y > Layout.UPPER_Y - 0.15 else LAYER_GROUND)
	if node.get_script() and String((node.get_script() as Script).resource_path) == BOOKS_SCRIPT:
		node.set("layers", LAYER_UPPER if xf.origin.y > Layout.UPPER_Y - 0.15 else LAYER_GROUND)
	for child in node.get_children():
		_assign_floor_layers(child, xf)


## Batching: the level's static boxes (the tiles of floors, walls and ceilings,
## the furniture's own boxes and all the box-shaped decoration) are merged into
## MultiMeshes of coloured unit boxes, as ShelfBooks draws books, so the
## renderer draws a few hundred objects instead of a few thousand. One MultiMesh
## per group of the original nodes (each floor, the stairs, each dressing
## group), BATCH_CELL-metre cell, render layer, shadow setting and material
## kind: plain colours share one vertex-colour material (metal too: on these
## small boxes its sheen hardly showed), glowing materials keep their own. A
## batch reached by more than 8 lights (the renderer's limit per mesh) is split
## until no piece is. Colliders are not touched: a solid piece keeps its Shape, only its
## visible box moves into the batch. Left as they are: the mission's objects
## (their scripts recolour or hide them), labels, the books, prop instances
## (chairs, lights), and the few cylinders and spheres.
const BATCH_CELL := 12.0
var _batched_boxes := 0
var _batch_meshes := 0


func _batch_static_meshes() -> void:
	var groups := {}   # parent group node -> {key -> [instances]}
	var batchable: Array[MeshInstance3D] = []
	_collect_batchable(_level, batchable)
	for mi in batchable:
		var host := _batch_host(mi)
		var xf := _world_of(mi) * Transform3D(Basis.from_scale((mi.mesh as BoxMesh).size), Vector3.ZERO)
		var material := mi.material_override as StandardMaterial3D
		var kind := "plain" if not material.emission_enabled else String(material.resource_scene_unique_id).trim_prefix("Material_")
		var centre := xf.origin
		var cell := Vector2i(floori((centre.x + 36.0) / BATCH_CELL), floori((centre.z + 28.0) / BATCH_CELL))
		if mi.layers == LAYER_OVERHEAD:
			cell = Vector2i.ZERO   # no lamp lights this layer: one batch is enough
		var shadow := mi.cast_shadow
		var key := "%d_%d_%s_L%d_S%d" % [cell.x, cell.y, kind, mi.layers, int(shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)]
		if not groups.has(host):
			groups[host] = {}
		if not groups[host].has(key):
			groups[host][key] = {"items": [], "material": material, "plain": kind == "plain", "layers": mi.layers,
				"shadow": shadow, "cell": cell}
		groups[host][key].items.append([xf, material.albedo_color])
		mi.get_parent().remove_child(mi)
		mi.free()
		_batched_boxes += 1
	var plain := StandardMaterial3D.new()
	plain.resource_scene_unique_id = "Material_batched_plain"
	plain.vertex_color_use_as_albedo = true
	plain.roughness = 0.9
	var lights := _light_bounds()
	for host in groups:
		var keys: Array = groups[host].keys()
		keys.sort()
		for key in keys:
			var g: Dictionary = groups[host][key]
			var pieces := _split_for_lights(g.items, g.layers, lights)
			for k in pieces.size():
				var items: Array = pieces[k]
				# The node sits at the piece's centre, on its floor; instances are relative to it.
				var bounds := _items_aabb(items)
				var floor_y := 0.0
				for it in items:
					floor_y += (it[0] as Transform3D).origin.y
				floor_y = Layout.UPPER_Y if floor_y / items.size() > Layout.UPPER_Y - 0.15 else 0.0
				var centre := bounds.get_center()
				var origin := Vector3(snappedf(centre.x, 0.5), floor_y, snappedf(centre.z, 0.5))
				var host_xf := _world_of(host)
				var data := PackedFloat32Array()
				for it in items:
					BatchedBoxes.pack(data, Transform3D(Basis(), -origin) * it[0], it[1])
				var node := MultiMeshInstance3D.new()
				node.name = "Batch_" + key + ("" if pieces.size() == 1 else "_%d" % k)
				node.set_script(load(BATCH_SCRIPT))
				node.set("boxes", data)
				node.position = host_xf.affine_inverse() * origin
				node.material_override = plain if g.plain else g.material
				node.layers = g.layers
				node.cast_shadow = g.shadow
				_add(host, node)
				_batch_meshes += 1


## Every omni light as [bounding box of its range, cull mask]: Godot pairs a light
## with a mesh when these boxes meet and the mask includes one of the mesh's layers.
func _light_bounds() -> Array:
	var out := []
	for l in _level.find_children("*", "OmniLight3D", true, false):
		var omni := l as OmniLight3D
		var r := omni.omni_range
		out.append([AABB(_world_of(omni).origin - Vector3.ONE * r, Vector3.ONE * r * 2.0), omni.light_cull_mask])
	return out


## Splits a batch's boxes in two along the longer side of their bounds, again and
## again, until each piece is reached by at most MAX_LIGHTS_PER_MESH lights (the
## renderer's limit; maps/library/tools/light_report.gd counts the same way).
const MAX_LIGHTS_PER_MESH := 8


func _split_for_lights(items: Array, layers: int, lights: Array) -> Array:
	var bounds := _items_aabb(items)
	var reached := 0
	for l in lights:
		if (l[1] & layers) != 0 and (l[0] as AABB).intersects(bounds):
			reached += 1
	if reached <= MAX_LIGHTS_PER_MESH or items.size() == 1:
		return [items]
	var axis := 0 if bounds.size.x >= bounds.size.z else 2
	var sorted := items.duplicate()
	sorted.sort_custom(func(a, b): return (a[0] as Transform3D).origin[axis] < (b[0] as Transform3D).origin[axis])
	var half := sorted.size() / 2
	return _split_for_lights(sorted.slice(0, half), layers, lights) + _split_for_lights(sorted.slice(half), layers, lights)


func _items_aabb(items: Array) -> AABB:
	var bounds := (items[0][0] as Transform3D) * AABB(-Vector3.ONE / 2.0, Vector3.ONE)
	for it in items:
		bounds = bounds.merge((it[0] as Transform3D) * AABB(-Vector3.ONE / 2.0, Vector3.ONE))
	return bounds


func _collect_batchable(node: Node, out: Array[MeshInstance3D]) -> void:
	if node.get_parent() == _level and String(node.name) in ["Player", "Guards", "Gameplay", "Layout", "NavigationDebug"]:
		return
	if node != _level and node.owner != _level:
		return   # inside a prop instance
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is BoxMesh and node.material_override is StandardMaterial3D \
			and String(node.get_parent().name) != "ExitDoorPanel" and not String(node.get_parent().get_parent().name) == "Signs":
		out.append(node)
	for child in node.get_children():
		_collect_batchable(child, out)


## Where a batched box goes: under the floor it came from (so hiding a floor
## hides its visuals, as the capture tools do; the stairs count as the ground
## floor), Dressing/Ceilings (hidden in top-down captures) or Dressing.
func _batch_host(node: Node) -> Node3D:
	var n := node
	while n.get_parent() and n.get_parent() != _level:
		var p := n.get_parent()
		if p.name == "NavigationRegion3D":
			# The stairs' boxes join the ground floor's (Stairs keeps just the three stairs).
			return _batch_group((p.get_node("Ground") if n.name == "Stairs" else n) as Node3D)
		if p.name == "Dressing":
			return _batch_group(n as Node3D if n.name == "Ceilings" else p as Node3D)
		n = p
	return _batch_group(_level)


func _batch_group(parent: Node3D) -> Node3D:
	var existing := parent.get_node_or_null("Batched") as Node3D
	return existing if existing else _group(parent, "Batched")


## A node's transform relative to the level root (the level is not in the tree here).
func _world_of(node: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n and n != _level:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## Accent lights fade out sooner than the room lights (they light a few metres).
func _fade(light: OmniLight3D) -> void:
	light.light_cull_mask = LIGHT_MASK_UPPER if light.position.y > Layout.UPPER_Y else LIGHT_MASK_GROUND
	light.distance_fade_enabled = true
	light.distance_fade_begin = 16.0
	light.distance_fade_length = 4.0


## A small green-shaded desk lamp (the tutorial's lamp shade) standing on `top`.
func _add_lamp(parent: Node, pos: Vector3) -> void:
	_cylinder(parent, "LampStem", pos + Vector3(0, 0.15, 0), 0.02, 0.3, "brass", 6)
	_visual(parent, "LampShade", pos + Vector3(0, 0.32, 0), Vector3(0.24, 0.1, 0.16), "lamp_shade", false)


## Adds a StaticBody3D (layer 1) with a "Mesh" and a "Shape" child. `look`
## (a LOOKS name) replaces the flat graybox colour with the library material.
func _add_box(parent: Node, node_name: String, centre: Vector3, size: Vector3, colour: Color, basis := Basis(), look := "") -> StaticBody3D:
	var body := _add_body(parent, node_name, centre, size, basis)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = _box_mesh(size)
	mesh.material_override = _look(look) if look != "" else _material(colour)
	_add(body, mesh)
	body.move_child(mesh, 0)
	return body


## A StaticBody3D (layer 1) with only its "Shape": the collider. Its visuals
## are added by the caller (tiled floors and walls).
func _add_body(parent: Node, node_name: String, centre: Vector3, size: Vector3, basis := Basis()) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.transform = Transform3D(basis, centre)
	body.collision_layer = 1
	body.collision_mask = 0
	_add(parent, body)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = _box_shape(size)
	_add(body, shape)
	_bodies += 1
	return body


# --- Visual dressing (v4) -----------------------------------------------------------------------
#
# Everything below is decoration: MeshInstance3D / MultiMesh / lights with no
# collision. It sits inside the colliders it decorates, flush on their faces,
# or at most a few centimetres outside them (chairs: 0.15 m beside a table),
# never on its own in walkable space, and never adds apparent cover where
# there is no collider (nothing opaque on top of low cover beyond a few small
# objects). So the navmesh, the guards' sight (physics rays on layer 1) and
# the player's collision are exactly those of the v3 graybox.

## The library's materials: the tutorial's palette (maps/tutorial/scenes/library_graybox.tscn).
## [albedo, roughness, metallic, emission energy (0 = none)]
const LOOKS := {
	"wall": [Color(0.78, 0.72, 0.62), 1.0, 0.0, 0.0],
	"ceiling": [Color(0.86, 0.83, 0.76), 1.0, 0.0, 0.0],
	"roof": [Color(0.55, 0.5, 0.42), 1.0, 0.0, 0.0],   # the ceiling colour as the ambient light shows it (unshaded)
	"wood": [Color(0.33, 0.21, 0.12), 0.82, 0.0, 0.0],
	"wood_dark": [Color(0.28, 0.18, 0.1), 0.85, 0.0, 0.0],
	"desk": [Color(0.33, 0.22, 0.13), 0.8, 0.0, 0.0],
	"desk_top": [Color(0.55, 0.37, 0.21), 0.8, 0.0, 0.0],
	"carrel": [Color(0.42, 0.3, 0.2), 0.85, 0.0, 0.0],
	"cabinet": [Color(0.3, 0.2, 0.12), 0.8, 0.0, 0.0],
	"trim": [Color(0.36, 0.24, 0.14), 0.7, 0.0, 0.0],
	"header": [Color(0.78, 0.74, 0.66), 1.0, 0.0, 0.0],
	"restricted": [Color(0.6, 0.12, 0.1), 0.6, 0.0, 0.0],
	"restricted_panel": [Color(0.42, 0.13, 0.11), 0.85, 0.0, 0.0],
	"shortcut": [Color(0.85, 0.62, 0.18), 0.9, 0.0, 0.0],
	"exit": [Color(0.05, 0.45, 0.18), 0.6, 0.0, 0.8],
	"floor_stone": [Color(0.5, 0.48, 0.45), 0.9, 0.0, 0.0],
	"floor_wood": [Color(0.4, 0.3, 0.22), 0.9, 0.0, 0.0],
	"floor_carpet": [Color(0.26, 0.32, 0.33), 1.0, 0.0, 0.0],
	"floor_service": [Color(0.3, 0.33, 0.38), 0.9, 0.0, 0.0],
	"floor_concrete": [Color(0.4, 0.4, 0.38), 0.9, 0.0, 0.0],
	"floor_archive": [Color(0.34, 0.1, 0.11), 0.9, 0.0, 0.0],
	"floor_vault": [Color(0.24, 0.08, 0.09), 0.9, 0.0, 0.0],
	"rug_teal": [Color(0.13, 0.33, 0.33), 1.0, 0.0, 0.0],
	"rug_red": [Color(0.45, 0.11, 0.11), 1.0, 0.0, 0.0],
	"stair": [Color(0.45, 0.33, 0.22), 0.85, 0.0, 0.0],
	"nosing": [Color(0.86, 0.8, 0.62), 0.8, 0.0, 0.0],
	"brass": [Color(0.72, 0.56, 0.24), 0.35, 0.7, 0.0],
	"dark_metal": [Color(0.1, 0.1, 0.11), 0.4, 0.6, 0.0],
	"steel": [Color(0.42, 0.44, 0.47), 0.55, 0.4, 0.0],
	"stone": [Color(0.55, 0.53, 0.5), 0.9, 0.0, 0.0],
	"crate": [Color(0.55, 0.42, 0.25), 0.9, 0.0, 0.0],
	"crate_dark": [Color(0.4, 0.3, 0.18), 0.9, 0.0, 0.0],
	"cardboard": [Color(0.62, 0.48, 0.3), 1.0, 0.0, 0.0],
	"planter": [Color(0.4, 0.27, 0.16), 0.85, 0.0, 0.0],
	"foliage": [Color(0.12, 0.28, 0.14), 0.8, 0.0, 0.0],
	"foliage_light": [Color(0.2, 0.36, 0.18), 0.8, 0.0, 0.0],
	"paper": [Color(0.86, 0.83, 0.74), 1.0, 0.0, 0.0],
	"sign_board": [Color(0.12, 0.14, 0.18), 0.5, 0.0, 0.0],
	"sign_red": [Color(0.55, 0.06, 0.05), 0.5, 0.0, 0.5],
	"window": [Color(0.16, 0.24, 0.4), 0.3, 0.0, 0.6],
	"window_frame": [Color(0.3, 0.2, 0.12), 0.8, 0.0, 0.0],
	"clock_face": [Color(0.95, 0.93, 0.85), 1.0, 0.0, 0.3],
	"globe": [Color(0.2, 0.45, 0.65), 0.6, 0.0, 0.0],
	"lamp_shade": [Color(0.1, 0.45, 0.25), 0.6, 0.0, 0.8],
	"screen": [Color(0.15, 0.3, 0.42), 0.3, 0.0, 0.7],
	"hazard_yellow": [Color(0.9, 0.72, 0.1), 0.8, 0.0, 0.0],
	"hazard_black": [Color(0.08, 0.08, 0.08), 0.8, 0.0, 0.0],
	"poster_a": [Color(0.62, 0.2, 0.15), 0.9, 0.0, 0.0],
	"poster_b": [Color(0.2, 0.38, 0.55), 0.9, 0.0, 0.0],
	"poster_c": [Color(0.75, 0.6, 0.22), 0.9, 0.0, 0.0],
	"poster_d": [Color(0.25, 0.45, 0.28), 0.9, 0.0, 0.0],
	"cord": [Color(0.1, 0.1, 0.11), 0.8, 0.0, 0.0],
}

## Floor finish by room: warm stone and wood in the public rooms, carpet in the
## study rooms and staff wing, blue-grey and concrete in the service areas, and
## the tutorial's dark red in the restricted archive.
const AREA_FLOORS := {
	"Porch": "floor_stone", "Lobby": "floor_stone", "Main Stacks": "floor_wood", "Browsing Hall": "floor_wood",
	"Reading Hall": "floor_wood", "Study 1": "floor_carpet", "Study 2": "floor_carpet", "Study 3": "floor_carpet",
	"Study 4": "floor_carpet", "Service Corridor": "floor_service", "Book Processing": "floor_concrete",
	"Storage": "floor_concrete", "Loading Dock": "floor_concrete", "Upper Stacks": "floor_wood",
	"Staff Balcony": "floor_wood", "Staff Corridor": "floor_carpet", "Office 1": "floor_carpet",
	"Office 2": "floor_carpet", "Office 3": "floor_carpet", "Archive Hall": "floor_archive",
	"Archive Stacks": "floor_archive", "Vault": "floor_vault", "Alcove": "floor_archive",
	"Staff Stair Landing": "floor_concrete",
}
## Zones whose walls carry the red restricted wainscot (the card / staff-only areas).
const RESTRICTED_ZONES := ["D", "F"]
## Visual tiles are at most this long: the Compatibility renderer lights each
## mesh with at most 8 omni lights, so large slabs are split into pieces that
## each see only their nearby lights.
const FLOOR_TILE := 6.0
const WALL_TILE := 6.0
## The roof over the whole building (above every walkable place: decoration only).
const ROOF_Y := Layout.UPPER_Y + Layout.UPPER_WALL_HEIGHT
const LIGHT_SPACING := 9.5
const PENDANT_Y := 4.7
## The room lights are the tutorial's ceiling light (shared/scenes/props/ceiling_light.tscn)
## with a shorter reach than its own 10 m, set per mounting so that a guard's
## chest (1.2 m) under a light gets about the same light on both floors:
## [range, energy] for a light on a ground-floor ceiling (3.9 m up), an upper
## ceiling (3.2 m up) and a pendant in a double-height hall (4.4 m up).
const LIGHT_GROUND := [6.5, 1.2]
const LIGHT_UPPER := [6.0, 1.1]
const LIGHT_PENDANT := [7.0, 1.4]
## The Compatibility renderer draws at most 32 lights in view and 8 on one mesh,
## dropping the rest in no particular order. So: lights fade out by distance (a
## faded light takes no slot), and each floor's lights only reach that floor's
## surfaces (render layers, below); characters, props and the mission's objects
## (layer 1) are lit by both. The slab between the floors is lit from below as
## the ground floor's ceiling and from above as the upper floor, never both; the
## roof and the fixtures (overhead layer) by no lamp. Checked by
## maps/library/tools/light_report.gd.
const LIGHT_FADE_BEGIN := 16.0
const LIGHT_FADE_LENGTH := 5.0
## Render layers (bit values): 1 characters, props and gameplay (lit by every
## light), 2 overhead (the roof, light fixtures and cords: hidden in top-down
## captures, as the tutorial's ceilings), 4 the ground floor's surfaces (its
## ceilings too), 8 the upper floor's surfaces.
const LAYER_OVERHEAD := 2
const LAYER_GROUND := 4
const LAYER_UPPER := 8
const LIGHT_MASK_GROUND := 1 | LAYER_GROUND
const LIGHT_MASK_UPPER := 1 | LAYER_UPPER
const LIGHT_SCENE := "res://shared/scenes/props/ceiling_light.tscn"
const CHAIR_SCENE := "res://shared/scenes/props/chair.tscn"
const BOOKS_SCRIPT := "res://shared/scripts/level/shelf_books.gd"
const BATCH_SCRIPT := "res://shared/scripts/level/batched_boxes.gd"
## Books further than this from the camera are not drawn (the bookcase box still
## is): this level has about 30 bookcases, and a long view would otherwise draw
## all of their books (some 400,000 triangles), even behind walls.
const BOOKS_DRAW_DISTANCE := 20.0

var _dressing_meshes := 0
var _light_count := 0


func _look(look_name: String) -> StandardMaterial3D:
	var key := "look_" + look_name
	if not _materials.has(key):
		var spec: Array = LOOKS[look_name]
		var m := StandardMaterial3D.new()
		m.resource_scene_unique_id = "Material_%s" % look_name
		m.albedo_color = spec[0]
		m.roughness = spec[1]
		m.metallic = spec[2]
		if spec[3] > 0.0:
			m.emission_enabled = true
			m.emission = spec[0]
			m.emission_energy_multiplier = spec[3]
		if look_name in ["ceiling", "roof"]:
			m.disable_receive_shadows = true   # faces down: the sun never reaches it
		if look_name == "roof":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # no lamp lights it: its ambient look, baked in
		_materials[key] = m
	return _materials[key]


## A decorative box (no collision) at `pos` in `parent`'s space. It casts no sun
## shadow unless asked: only the walls, the upper slab and the furniture's own
## boxes need to (as in v3); shadows of finishes on them would be invisible and
## cost the renderer a shadow pass.
func _visual(parent: Node, node_name: String, pos: Vector3, size: Vector3, look: String, shadow := false, layers := 1) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.position = pos
	mesh.mesh = _box_mesh(size)
	mesh.material_override = _look(look)
	if not shadow:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.layers = layers
	_add(parent, mesh)
	_dressing_meshes += 1
	return mesh


func _cylinder(parent: Node, node_name: String, pos: Vector3, radius: float, height: float, look: String, segments := 10) -> MeshInstance3D:
	var key := "cyl_%.3f_%.3f_%d" % [radius, height, segments]
	if not _meshes.has(key):
		var c := CylinderMesh.new()
		c.resource_scene_unique_id = "CylinderMesh_" + key.replace(".", "p")
		c.top_radius = radius
		c.bottom_radius = radius
		c.height = height
		c.radial_segments = segments
		c.rings = 1
		_meshes[key] = c
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.position = pos
	mesh.mesh = _meshes[key]
	mesh.material_override = _look(look)
	_add(parent, mesh)
	_dressing_meshes += 1
	return mesh


## Splits the rect [x0, z0, x1, z1] into equal tiles no longer than `max_size`.
func _tiles(r: Array, max_size: float) -> Array:
	var out := []
	var nx := maxi(1, ceili((r[2] - r[0]) / max_size - 0.001))
	var nz := maxi(1, ceili((r[3] - r[1]) / max_size - 0.001))
	var w: float = (r[2] - r[0]) / nx
	var d: float = (r[3] - r[1]) / nz
	for i in nx:
		for j in nz:
			out.append([r[0] + i * w, r[1] + j * d, r[0] + (i + 1) * w, r[1] + (j + 1) * d])
	return out


## The intersection of two rects, or [] if they don't overlap.
func _clip(a: Array, b: Array) -> Array:
	var r := [maxf(a[0], b[0]), maxf(a[1], b[1]), minf(a[2], b[2]), minf(a[3], b[3])]
	return r if r[2] - r[0] > 0.01 and r[3] - r[1] > 0.01 else []


## The zone and area at (x, z) on a floor, as [zone, area] ({} if outside).
func _area_at(floor_name: String, x: float, z: float) -> Array:
	for zn in Layout.ZONES:
		if zn.floor != floor_name:
			continue
		for a in zn.areas:
			var r: Array = a.rect
			if x >= r[0] and x <= r[2] and z >= r[1] and z <= r[3]:
				return [zn, a]
	return [{}, {}]


## True if (x, z) on the ground floor is under an upper slab.
func _under_slab(x: float, z: float) -> bool:
	for f in Layout.FLOORS:
		var r: Array = f.rect
		if f.floor == "upper" and x > r[0] and x < r[2] and z > r[1] and z < r[3]:
			return true
	return false


## An instance of a prop scene (edit-state, so the scene stores it as an instance).
func _prop(parent: Node, path: String, node_name: String, pos: Vector3, yaw_degrees := 0.0) -> Node3D:
	var node := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	node.name = node_name
	node.position = pos
	node.rotation_degrees = Vector3(0, yaw_degrees, 0)
	parent.add_child(node)
	node.owner = _level
	return node


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
		# This level's detection tuning (stored as overrides on the instance's Vision child).
		for key in Layout.GUARD_TUNING:
			guard.set(key, Layout.GUARD_TUNING[key])
		var vision := guard.get_node("Vision")
		for key in Layout.GUARD_VISION:
			vision.set(key, Layout.GUARD_VISION[key])
		_level.set_editable_instance(guard, true)


func _add_route(parent: Node, index: int) -> Node3D:
	var p: Dictionary = Layout.PATROLS[index]
	var route := Node3D.new()
	route.name = "%s_%s" % [p.id, String(p.name).replace(" ", "")]
	route.set_script(load("res://shared/scripts/npc/patrol_route.gd"))
	route.set("debug_color", PATROL_COLOURS[index % PATROL_COLOURS.size()])
	route.set_meta("zone_id", p.zone)
	route.set_meta("patrol_id", p.id)
	_add(parent, route)
	for k in p.points.size():
		var point := Marker3D.new()
		point.name = "Point%d" % k
		point.set_script(load("res://shared/scripts/npc/patrol_point.gd"))
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
