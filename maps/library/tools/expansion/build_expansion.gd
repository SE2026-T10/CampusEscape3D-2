extends SceneTree

## Development tool: builds the Expanded Library expansion sub-scene,
##   res://maps/library/scenes/expanded_library_expansion.tscn,
## from maps/library/tools/expansion/expansion_layout.gd. It writes only that file:
## the existing level (expanded_library.tscn) and its frozen builder are not
## touched. Afterwards rebake the level's navmesh, which includes the
## expansion's geometry:
##   godot --headless --path . --script res://maps/library/tools/expansion/build_expansion.gd
##   godot --headless --path . --script res://maps/library/tools/expansion/bake_navmesh.gd
##
## The sub-scene, instanced once in the level as "Expansion" (after Gameplay):
##   Expansion
##   ├─ Geometry (group expanded_navigation_source: baked into the level's navmesh)
##   │  ├─ G_ServiceNetwork, D_ElectricalAnnex: StaticBody3D pieces on layer 1,
##   │  │  each with a Shape and its Mesh tiles (the existing level's conventions)
##   ├─ Gameplay: the electrical room's staff-card AccessDoor, HidingSpots,
##   │  Items (ItemPickup), Storage (ItemStorage shelves), Documents
##   │  (DocumentPickup), Mission (Phase 4: PowerNetwork, SecurityAlarm, the
##   │  panel cover, BreakerPanel, VaultKeypad, SecurityLocker, PumpCrank,
##   │  PumpControl, StormDrainExit; the VaultDoor sits with the doors); not baked: guards keep their routes through doors, as
##   │  in the level, and shelves and items change no route. Item, shelf and
##   │  clipboard models are made by their scripts at run time (ItemCatalog).
##   ├─ Dressing: ceilings and roofs (no collision), lamps, door headers, signs
##     and (Phase 9) decor: pipes, trays, stripes, flood marks (no collision)
##   └─ Layout (debug_visuals, F3): zone labels and reserved-space markers
## Colours: the existing level's palette (LOOKS of the frozen builder).

const Layout := preload("res://maps/library/tools/expansion/expansion_layout.gd")
const Palette := preload("res://maps/library/tools/build_expanded_graybox.gd")
const MainLayout := preload("res://maps/library/tools/expanded_layout.gd")
const SCENE_PATH := "res://maps/library/scenes/expanded_library_expansion.tscn"
const LIGHT_SCENE := "res://shared/scenes/props/ceiling_light.tscn"
const SCRIPTS := {
	"door": "res://features/objectives/access_door.gd",
	"noise": "res://shared/scripts/noise/noise_maker.gd",
	"hiding": "res://shared/scripts/stealth/hiding_spot.gd",
	"item": "res://features/inventory/item_pickup.gd",
	"storage": "res://features/inventory/item_storage.gd",
	"document": "res://features/inventory/document_pickup.gd",
	"tool": "res://features/inventory/tool_mechanism.gd",
	"power": "res://features/puzzles/power_network.gd",
	"alarm": "res://features/puzzles/security_alarm.gd",
	"code_lock": "res://features/puzzles/code_lock.gd",
	"breakers": "res://features/puzzles/breaker_panel.gd",
	"pump": "res://features/puzzles/pump_control.gd",
	"exit": "res://features/objectives/exit_door.gd",
	"switch": "res://features/security/circuit_switch.gd",
	"camera": "res://features/security/security_camera.gd",
	"badge_reader": "res://maps/library/scripts/escape/badge_reader.gd",
	"dock_shutter": "res://maps/library/scripts/escape/dock_shutter.gd",
	"escape_routes": "res://maps/library/scripts/escape/escape_routes.gd",
	"mechanism_audio": "res://maps/library/scripts/presentation/mechanism_audio.gd",
	"checkpoint": "res://features/checkpoints/checkpoint.gd",
}
## Mesh tiles are at most this long, so no mesh is reached by more than the
## renderer's 8 lights per mesh (lamps are 8-12 m apart, range 10 m).
const TILE := 6.0

var _root: Node3D
var _materials := {}
var _meshes := {}
var _shapes := {}
var _bodies := 0
var _pump: Node3D
var _tiles := 0


func _init() -> void:
	_build.call_deferred()


func _build() -> void:
	_root = Node3D.new()
	_root.name = "Expansion"
	_root.editor_description = "Expanded Library expansion content (2026 expansion). Built by maps/library/tools/expansion/build_expansion.gd from expansion_layout.gd (%s): the basement / service network (zone G), the electrical room (zone D), the west and east service stairs. New puzzles, mechanics and areas go here, not into expanded_library.tscn, whose builder is frozen. Instanced once into expanded_library.tscn as \"Expansion\", right after \"Gameplay\"; content uses the level's existing systems through their groups." % Layout.VERSION
	_root.set_meta("expansion_layout_version", Layout.VERSION)

	var geometry := _group(_root, "Geometry")
	geometry.add_to_group(Layout.NAV_GROUP, true)
	var zones := {}
	for z in Layout.ZONES:
		var node := _group(geometry, "%s_%s" % [z.id, "ServiceNetwork" if z.id == "G" else "ElectricalAnnex"])
		node.set_meta("zone_id", z.id)
		node.set_meta("zone_name", z.name)
		node.set_meta("areas", z.areas.map(func(a): return a.name))
		zones[z.id] = node
	# Phase 9 follow-up: cover added to the existing staff balcony (zone E).
	var balcony := _group(geometry, "E_StaffBalcony")
	balcony.set_meta("zone_id", "E")
	zones["E"] = balcony
	for f in Layout.FLOORS:
		var r: Array = f.rect
		_add_box_body(zones[f.zone], "Floor_" + f.name, Vector3((r[0] + r[2]) / 2.0, f.y - Layout.FLOOR_T / 2.0, (r[1] + r[3]) / 2.0),
			Vector3(r[2] - r[0], Layout.FLOOR_T, r[3] - r[1]), "floor_sealed" if f.zone == "G" and (f.y < -1.0 or f.name == "WestLanding") and f.look == "floor_concrete" else f.look)
	for w in Layout.WALLS:
		var along_x: bool = w.a[1] == w.b[1]
		var lo: float = minf(w.a[0], w.b[0]) if along_x else minf(w.a[1], w.b[1])
		var hi: float = maxf(w.a[0], w.b[0]) if along_x else maxf(w.a[1], w.b[1])
		var mid := (lo + hi) / 2.0
		var centre := Vector3(mid, (w.y0 + w.y1) / 2.0, w.a[1]) if along_x else Vector3(w.a[0], (w.y0 + w.y1) / 2.0, mid)
		var t := Layout.WALL_T
		var size := Vector3(hi - lo, w.y1 - w.y0, t) if along_x else Vector3(t, w.y1 - w.y0, hi - lo)
		# Polish (basement): the service network's walls (the basement and the two service
		# stair shafts) in concrete.
		_add_box_body(zones[w.zone], "Wall_" + w.name, centre, size, "concrete_wall" if w.zone == "G" else "wall")
	for ramp in Layout.RAMPS:
		_add_ramp(zones[ramp.zone], ramp)
	for c in Layout.COVER:
		var r: Array = c.rect
		var cover := _add_box_body(zones[c.zone], "Cover_" + c.name, Vector3((r[0] + r[2]) / 2.0, c.y + c.h / 2.0, (r[1] + r[3]) / 2.0),
			Vector3(r[2] - r[0], c.h, r[3] - r[1]), c.look)
		if c.has("layers"):
			for m in cover.get_children():
				if m is MeshInstance3D:
					m.set_meta("render_layers", c.layers)
		if c.get("hidden", false):
			_strip_meshes(cover)   # polish: collision only, a model is built in its place
	var seals := _group(geometry, "Seals")
	for seal in Layout.SEALS:
		var body := StaticBody3D.new()
		body.name = seal.name
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = seal.centre
		body.set_meta("why", "keeps the navmesh's margin at the S2 stair top (see expansion_layout.gd SEALS); no mesh")
		_add(seals, body)
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		cs.shape = _box_shape(seal.size)
		_add(body, cs)
		_bodies += 1
	var g: Dictionary = Layout.GRATE
	var grate := _add_box_body(zones["G"], g.name, g.centre + Vector3(0, g.height / 2.0, 0), Vector3(g.width, g.height, 0.12), "dark_metal")
	_strip_meshes(grate)   # polish: collision only; the barred grille (Mission/StormDrainGrille) is its look

	var gameplay := _group(_root, "Gameplay")
	for d in Layout.DOORS:
		_add_access_door(gameplay, d)
	var hiding := _group(gameplay, "HidingSpots")
	for h in Layout.HIDING:
		_add_hiding_spot(hiding, h)
	var items := _group(gameplay, "Items")
	for it in Layout.ITEMS:
		_add_item(items, it)
	var storage := _group(gameplay, "Storage")
	for st in Layout.STORAGE:
		_add_storage(storage, st)
	var documents := _group(gameplay, "Documents")
	for doc in Layout.DOCUMENTS:
		_add_document(documents, doc)
	var checkpoints := _group(gameplay, "Checkpoints")
	for cp in Layout.CHECKPOINTS:
		_add_checkpoint(checkpoints, cp)
	_add_mission(_group(gameplay, "Mission"))
	_add_security(_group(gameplay, "Security"))
	_add_escapes(_group(gameplay, "Escape"))
	# Phase 9: 3D sounds for the mechanisms (it only listens to their signals).
	var audio := Node3D.new()
	audio.name = "MechanismAudio"
	audio.set_script(load(SCRIPTS.mechanism_audio))
	_add(gameplay, audio)

	var dressing := _group(_root, "Dressing")
	var ceilings := _group(dressing, "Ceilings")
	for c in Layout.CEILINGS:
		var r: Array = c.rect
		_add_visual_box(ceilings, "Ceiling", Vector3((r[0] + r[2]) / 2.0, c.y + 0.05, (r[1] + r[3]) / 2.0), Vector3(r[2] - r[0], 0.1, r[3] - r[1]), "concrete_ceiling" if c.y < 0.0 else "ceiling")
	for c in Layout.ROOFS:
		var r: Array = c.rect
		_add_visual_box(ceilings, "Roof", Vector3((r[0] + r[2]) / 2.0, c.y + 0.1, (r[1] + r[3]) / 2.0), Vector3(r[2] - r[0], 0.2, r[3] - r[1]), "ceiling")
	var patches := _group(dressing, "FloorPatches")
	for fp in Layout.FLOOR_PATCHES:
		var r: Array = fp.rect
		var cx: float = (r[0] + r[2]) / 2.0
		var cz: float = (r[1] + r[3]) / 2.0
		var sx: float = r[2] - r[0]
		var sz: float = r[3] - r[1]
		var top_t: float = fp.slab - 0.1
		_add_visual_box(patches, fp.name, Vector3(cx, fp.top - top_t / 2.0, cz), Vector3(sx, top_t, sz), fp.look, Layout.LAYER_UPPER)
		_add_visual_box(patches, fp.name + "Ceiling", Vector3(cx, fp.top - fp.slab + 0.05, cz), Vector3(sx, 0.1, sz), "ceiling", Layout.LAYER_GROUND)
	var headers := _group(dressing, "DoorHeaders")
	for hd in Layout.DOOR_HEADERS:
		for side in [-1.0, 1.0]:
			_add_visual_box(headers, "%s_%s" % [hd.name, "W" if side < 0 else "E"],
				Vector3(hd.x + side * (Layout.WALL_T / 2.0 + 0.01), (Layout.DOOR_HEIGHT + Layout.GROUND_WALL_TOP) / 2.0, hd.z),
				Vector3(0.02, Layout.GROUND_WALL_TOP - Layout.DOOR_HEIGHT, hd.width + 0.2), hd.look)
	var lights := _group(dressing, "Lights")
	var light_scene: PackedScene = load(LIGHT_SCENE)
	var k := 0
	for l in Layout.LIGHTS:
		var lamp: Node3D = light_scene.instantiate()
		lamp.name = "%s_%d" % ["Basement" if l.basement else "Ground", k]
		k += 1
		lamp.position = l.pos - (Vector3(0, Layout.BASEMENT_LAMP_DROP, 0) if l.basement else Vector3.ZERO)
		lights.add_child(lamp)
		lamp.owner = _root
		_root.set_editable_instance(lamp, true)
		var omni := lamp.get_node("Light") as OmniLight3D
		omni.light_cull_mask = Layout.LIGHT_MASK_BASEMENT if l.basement else Layout.LIGHT_MASK_GROUND
		omni.distance_fade_enabled = true
		omni.distance_fade_begin = 28.0
		omni.distance_fade_length = 6.0
		(lamp.get_node("Fixture") as GeometryInstance3D).layers = Layout.LAYER_BASEMENT if l.basement else Layout.LAYER_GROUND
		if l.basement or l.pos.x < -36.0:
			(lamp.get_node("Fixture") as Node3D).visible = false   # polish: a caged bulkhead in its place (_bulkheads, _west_landing_services)
	_add_decor(_group(dressing, "Decor"))
	# Polish (loading dock): its solid props (in Geometry, baked) and loose decor.
	_build_dock_props(_group(_root.get_node("Geometry"), "D_LoadingDock"), _group(dressing, "DockDecor"))
	# Polish (lobby and reading hall): the desk, S1, G4, details; the hall's lamps, wall bookcases, display.
	_build_lobby(_group(dressing, "LobbyDecor"))
	_build_reading_hall(_group(_root.get_node("Geometry"), "C_ReadingHall"), _group(dressing, "HallDecor"))
	# Polish (Book Processing): workstations, the noticeboard, solid props, wall details.
	_build_processing(_group(_root.get_node("Geometry"), "D_Processing"), _group(dressing, "ProcessingDecor"))
	# Polish (storage room): the racks' shelving, the S2 stair's dressing, wall shelving, details.
	_build_storage(_group(_root.get_node("Geometry"), "D_Storage"), _group(dressing, "StorageDecor"))
	# Polish (browsing hall, main and upper stacks): tables, S3 in oak, carpet, lounge, display;
	# the rows' dressing, floors, strip lights, the upper ceiling and beams, stools and trolleys.
	_build_browsing_hall(_group(_root.get_node("Geometry"), "B_BrowsingHall"), _group(dressing, "BrowsingDecor"))
	_build_stacks(_group(_root.get_node("Geometry"), "B_Stacks"), _group(dressing, "StacksDecor"), ceilings)
	# Polish (staff wing): offices, staff corridor and balcony in the stacks' steel-and-oak mix.
	_build_staff_wing(_group(_root.get_node("Geometry"), "E_StaffWing"), _group(dressing, "StaffDecor"), ceilings)
	# Polish (basement and the tool box room): concrete utility.
	var basement_solid := _group(_root.get_node("Geometry"), "G_BasementProps")
	var basement_decor := _group(dressing, "BasementDecor")
	_build_basement(basement_solid, basement_decor)
	_build_tool_room(basement_solid, basement_decor)
	_set_layer_meta(basement_decor, Layout.LAYER_BASEMENT)
	# Polish (restricted archive): an old rare-books archive; the vault door and G3's leaves.
	_build_archive(_group(_root.get_node("Geometry"), "F_ArchiveProps"), _group(dressing, "ArchiveDecor"), ceilings)
	# Polish (study rooms): a modern quiet study.
	_build_study_rooms(_group(_root.get_node("Geometry"), "C_StudyProps"), _group(dressing, "StudyDecor"), ceilings)
	# Polish (service corridor): back-of-house utility.
	_build_service_corridor(_group(_root.get_node("Geometry"), "D_CorridorProps"), _group(dressing, "CorridorDecor"), ceilings)
	# Polish (main entrance and porch): the library's grand front hall.
	_build_porch(_group(_root.get_node("Geometry"), "A_PorchProps"), _group(dressing, "PorchDecor"), ceilings)
	# Polish (service stair landings, ground): the basement's concrete utility.
	_build_stair_landings(_group(_root.get_node("Geometry"), "G_LandingProps"), _group(dressing, "LandingDecor"), ceilings)
	var signs := _group(dressing, "Signs")
	for s in Layout.SIGNS:
		_add_sign(signs, s)
	var sealed_sign := signs.get_node_or_null("Sign_STORMDRAINSEALED")
	if _pump and sealed_sign:
		var hide: Array[NodePath] = [_pump.get_path_to(sealed_sign)]
		_pump.set("hide_on_solve", hide)

	var layout := _group(_root, "Layout")
	layout.add_to_group(&"debug_visuals", true)
	layout.visible = false
	for z in Layout.ZONES:
		for a in z.areas:
			var r: Array = a.rect
			_add_label(layout, "Zone_" + String(a.name).replace(" ", ""), Vector3((r[0] + r[2]) / 2.0, a.y + 2.2, (r[1] + r[3]) / 2.0),
				"%s · %s" % [z.id, a.name], Color(0.5, 1.0, 0.95))
	for res in Layout.RESERVED:
		var marker := _add_label(layout, res.name, res.pos + Vector3(0, 1.6, 0), res.text, Color(0.6, 1.0, 0.65))
		marker.set_meta("reserved", true)

	_assign_layers(_root)
	_batch_static_meshes()
	# The decor's holders are empty once their boxes are batched.
	for holder in _root.get_node("Dressing/Decor").get_children():
		if holder.name != "Batched" and holder.get_child_count() == 0:
			holder.get_parent().remove_child(holder)
			holder.free()
	var packed := PackedScene.new()
	var err := packed.pack(_root)
	if err != OK:
		push_error("Packing failed: %s" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, SCENE_PATH)
	if err != OK:
		push_error("Saving failed: %s" % err)
		quit(1)
		return
	print("Built %s (expansion layout %s): %d solid pieces, %d mesh tiles, %d lamps, %d hiding spots, %d access door(s), %d items, %d shelves, %d documents" % [
		SCENE_PATH, Layout.VERSION, _bodies, _tiles, Layout.LIGHTS.size(), Layout.HIDING.size(), Layout.DOORS.size(),
		Layout.ITEMS.size(), Layout.STORAGE.size(), Layout.DOCUMENTS.size()])
	print("  mission (x3): %d puzzle nodes under Gameplay/Mission" % Layout.MISSION.size())
	print("  escapes (x5): main entrance exit + badge reader, dock shutter release + control + trigger, storm drain trigger")
	_root.free()
	quit(0)


# --- Geometry ------------------------------------------------------------------------------

func _group(parent: Node, node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	_add(parent, n)
	return n


func _add(parent: Node, node: Node) -> void:
	parent.add_child(node)
	node.owner = _root


## A solid box: StaticBody3D on the world layer with a Shape and its Mesh tiles.
func _add_box_body(parent: Node, node_name: String, centre: Vector3, size: Vector3, look: String, basis := Basis()) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.transform = Transform3D(basis, centre)
	_add(parent, body)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = _box_shape(size)
	_add(body, shape)
	_add_tiles(body, size, look)
	_bodies += 1
	return body


## Mesh tiles covering a box (local to its parent), split along its longer horizontal side.
func _add_tiles(parent: Node3D, size: Vector3, look: String, name_prefix := "Mesh") -> void:
	var along_x := size.x >= size.z
	var length := size.x if along_x else size.z
	var n := maxi(1, ceili(length / TILE - 0.001))
	for i in n:
		var piece := length / n
		var offset := -length / 2.0 + piece * (i + 0.5)
		var mesh := MeshInstance3D.new()
		mesh.name = name_prefix if i == 0 else "%s_%d" % [name_prefix, i]
		mesh.mesh = _box_mesh(Vector3(piece, size.y, size.z) if along_x else Vector3(size.x, size.y, piece))
		mesh.material_override = _look(look)
		mesh.position = Vector3(offset, 0, 0) if along_x else Vector3(0, 0, offset)
		_add(parent, mesh)
		_tiles += 1


## `layers` > 0 fixes the render layers (else _assign_layers picks them by height).
func _add_visual_box(parent: Node, node_name: String, centre: Vector3, size: Vector3, look: String, layers := 0) -> void:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = centre
	_add(parent, holder)
	_add_tiles(holder, size, look)
	for m in holder.get_children():
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if layers > 0:
			m.set_meta("render_layers", layers)


## A ramp from its top (ground, y 0) to its bottom (basement, y BF), with
## stepped fillers underneath so nothing is walkable (or baked) under it.
func _add_ramp(parent: Node, r: Dictionary) -> void:
	var top := Vector3((r.x0 + r.x1) / 2.0, 0.0, r.z_top)
	var bottom := Vector3((r.x0 + r.x1) / 2.0, Layout.BF, r.z_bottom)
	var z_axis := (bottom - top).normalized()
	var x_axis := Vector3.RIGHT
	var y_axis := z_axis.cross(x_axis)
	if y_axis.y < 0.0:
		x_axis = -x_axis
		y_axis = -y_axis
	var basis := Basis(x_axis, y_axis, z_axis)
	var width: float = r.x1 - r.x0
	var length := top.distance_to(bottom)
	var centre := (top + bottom) / 2.0 - y_axis * Layout.RAMP_T / 2.0
	var body := _add_box_body(parent, "Ramp_" + r.name, centre, Vector3(width, Layout.RAMP_T, length), "stair", basis)
	body.set_meta("stair", r.name)
	# Fillers: from the basement floor to just under the ramp, in steps.
	var steps: int = Layout.RAMP_FILLER_STEPS
	var dz: float = (r.z_bottom - r.z_top) / steps
	for i in steps:
		var z0: float = r.z_top + dz * i
		var z1: float = r.z_top + dz * (i + 1)
		var lowest_surface := lerpf(0.0, Layout.BF, float(i + 1) / steps)   # the ramp at this step's lower end
		var filler_top := lowest_surface - Layout.RAMP_T / cos(atan2(-Layout.BF, absf(r.z_bottom - r.z_top))) - 0.05
		var h := filler_top - Layout.BF
		if h < 0.15:
			continue
		_add_box_body(parent, "RampFill_%s_%d" % [r.name, i], Vector3((r.x0 + r.x1) / 2.0, Layout.BF + h / 2.0, (z0 + z1) / 2.0),
			Vector3(width, h, absf(z1 - z0)), "concrete_wall")


# --- Gameplay -------------------------------------------------------------------------------

## A staff-card door as the level's (AccessDoor, KEY mode): an interaction box
## 1 m deep across the doorway, a solid panel (not baked: guards pass it), a noise.
func _add_access_door(parent: Node, d: Dictionary) -> void:
	var door := Area3D.new()
	door.name = d.name
	door.set_script(load(SCRIPTS.door))
	door.position = d.centre + Vector3(0, 1.2, 0)
	door.set("door_name", d.door_name)
	door.set("mode", 0)   # AccessDoor.Mode.KEY
	door.set("key_objective_id", StringName(d.key))
	if d.has("key_item"):
		door.set("key_item", StringName(d.key_item))
	door.set("key_name", d.key_name)
	if d.has("hidden_until"):
		door.set("hidden_until_document", StringName(d.hidden_until))
	if d.has("prompt"):
		door.set("prompt", d.prompt)
	_add(parent, door)
	var w: float = d.width
	var h: float = d.get("height", Layout.DOOR_HEIGHT)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = _box_shape(Vector3(w, 2.4, 1.0) if d.along_x else Vector3(1.0, 2.4, w))
	_add(door, shape)
	var panel := StaticBody3D.new()
	panel.name = "Panel"
	panel.collision_layer = 1
	panel.collision_mask = 0
	panel.position = Vector3(0, h / 2.0 - 1.2, 0)
	_add(door, panel)
	var size := Vector3(w, h, 0.18) if d.along_x else Vector3(0.18, h, w)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = _box_mesh(size)
	mesh.material_override = _colour(Color(0.85, 0.2, 0.18))   # the level's card-gate red
	_add(panel, mesh)
	var pshape := CollisionShape3D.new()
	pshape.name = "Shape"
	pshape.shape = _box_shape(size)
	_add(panel, pshape)
	if d.has("hatch"):
		door.set("found_colour", HATCH_COLOUR)
		_dress_hatch(panel, size)
	if d.get("security", false):
		_dress_security_door(door, d)
	var noise := Node3D.new()
	noise.name = "Noise"
	noise.set_script(load(SCRIPTS.noise))
	noise.set("radius", 6.0)
	_add(door, noise)


## A hiding spot as the level's: an Area3D with HidingSpot and a dark floor mark.
func _add_hiding_spot(parent: Node, h: Dictionary) -> void:
	var spot := Area3D.new()
	spot.name = String(h.name).replace(" ", "")
	spot.set_script(load(SCRIPTS.hiding))
	spot.position = h.pos + Vector3(0, 0.6, 0)
	spot.set_meta("zone_id", h.zone)
	_add(parent, spot)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = _box_shape(Vector3(1.4, 1.2, 1.0))
	_add(spot, shape)
	var mark := MeshInstance3D.new()
	mark.name = "FloorMark"
	mark.position = Vector3(0, -0.594, 0)
	mark.mesh = _box_mesh(Vector3(1.4, 0.01, 1.0))
	mark.material_override = _colour(Color(0.08, 0.1, 0.2))
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if h.pos.y > 4.0:
		mark.set_meta("render_layers", Layout.LAYER_UPPER)   # lit by the upper floor's lamps only
	_add(spot, mark)


## Phase 9 follow-up: a checkpoint built as the existing level's (pad, spawn, label).
func _add_checkpoint(parent: Node, c: Dictionary) -> void:
	var cp := Area3D.new()
	cp.name = c.node
	cp.set_script(load(SCRIPTS.checkpoint))
	cp.position = c.pos + Vector3(0, 1.0, 0)
	cp.set("checkpoint_name", c.name)
	cp.set_meta("zone_id", c.zone)
	_add(parent, cp)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = _box_shape(Vector3(2.6, 2.0, 2.2))
	_add(cp, shape)
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = c.spawn - cp.position + Vector3(0, 0.05, 0)
	spawn.rotation_degrees = Vector3(0, c.facing, 0)
	_add(cp, spawn)
	var pad := MeshInstance3D.new()
	pad.name = "Pad"
	pad.position = Vector3(0, -0.99, 0)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.75
	disc.bottom_radius = 0.75
	disc.height = 0.02
	pad.mesh = disc
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(cp, pad)
	var label := Label3D.new()
	label.name = "Label"
	label.position = Vector3(0, 1.2, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.text = "CHECKPOINT"
	label.font_size = 28
	label.outline_size = 10
	_add(cp, label)


## A carried item (ItemPickup) with its interaction box; the model comes from ItemCatalog at run time.
func _add_item(parent: Node, it: Dictionary) -> void:
	var item := Area3D.new()
	item.name = it.name
	item.set_script(load(SCRIPTS.item))
	item.position = it.pos
	item.rotation_degrees = Vector3(0, it.yaw, 0)
	item.set("item_id", StringName(it.item))
	if it.has("objective"):
		item.set("objective_id", StringName(it.objective))
	if it.has("available"):
		item.set("available", it.available)
	item.set_meta("zone_id", it.zone)
	_add(parent, item)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = _box_shape(Vector3(0.5, 0.35, 0.5))
	shape.position = Vector3(0, 0.175, 0)
	_add(item, shape)


## A storage shelf (ItemStorage); its model and interaction box come from the script.
func _add_storage(parent: Node, st: Dictionary) -> void:
	var shelf := Area3D.new()
	shelf.name = st.name
	shelf.set_script(load(SCRIPTS.storage))
	shelf.position = st.pos
	shelf.rotation_degrees = Vector3(0, st.facing, 0)
	shelf.set("storage_name", st.title)
	shelf.set_meta("zone_id", st.zone)
	_add(parent, shelf)


## A clue document on a wall (DocumentPickup); the clipboard model comes from the script.
func _add_document(parent: Node, doc: Dictionary) -> void:
	var node := Area3D.new()
	node.name = doc.name
	node.set_script(load(SCRIPTS.document))
	node.position = doc.pos
	node.rotation_degrees = Vector3(0, doc.facing, 0)
	node.set("document_id", StringName(doc.id))
	node.set("title", doc.title)
	node.set("text", doc.text)
	for key in [["kind", "kind"], ["model", "model"], ["display", "display_text"], ["available", "available"]]:
		if doc.has(key[0]):
			node.set(key[1], doc[key[0]])
	if doc.has("discovers"):
		node.set("discovers_objective", StringName(doc.discovers))
	node.set_meta("zone_id", doc.zone)
	_add(parent, node)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = _box_shape(Vector3(0.5, 0.6, 0.3))
	_add(node, shape)
	# Polish (wall clues): every clue shows a floating "!" until it is read.
	node.set("show_marker", true)
	node.set("marker_offset", Vector3(0, 1.2, 0.6) if doc.get("stone", false) else (Vector3(0, 0.8, 0.25) if doc.get("board", false) else Vector3(0, 0.3, 0.15)))
	if doc.get("stone", false):
		node.set("marker_pixel_size", 0.008)   # larger over the big panel, in front of its cap
	if doc.get("stone", false):
		_cornerstone_model(node)
	if doc.get("board", false):
		_clue_board_model(node)


## A wall clue's model (polish): an oak-framed cork board (0.9 × 0.7 m, its top rail red)
## with the clue's sheet pinned on (ruled lines, nothing readable; the text is in the
## journal), a red pin and a yellow tape corner, and a brass picture lamp over it with a
## short soft light. The node stands at the board (its back 2 cm off the wall); local +z
## faces the room. A "Model" child: DocumentPickup then skips its clipboard.
func _clue_board_model(node: Node3D) -> void:
	var m := Node3D.new()
	m.name = "Model"
	_add(node, m)
	var w := 0.9
	var h := 0.7
	var f := 0.05   # the frame's width
	_add_visual_box(m, "Cork", Vector3(0, 0, -0.002), Vector3(w - 2.0 * f, h - 2.0 * f, 0.02), "cork")
	_add_visual_box(m, "FrameTop", Vector3(0, h / 2.0 - f / 2.0, 0), Vector3(w, f, 0.032), "pipe_red")
	_add_visual_box(m, "FrameBottom", Vector3(0, -h / 2.0 + f / 2.0, 0), Vector3(w, f, 0.03), "oak")
	for e in [-1.0, 1.0]:
		_add_visual_box(m, "FrameSide%d" % int(e), Vector3(e * (w / 2.0 - f / 2.0), 0, 0), Vector3(f, h - 2.0 * f, 0.03), "oak")
	# The sheet, its lines, a red pin and a yellow tape corner.
	var sz := 0.0105
	_add_visual_box(m, "Sheet", Vector3(-0.06, -0.01, sz), Vector3(0.34, 0.46, 0.004), "paper")
	_add_visual_box(m, "Heading", Vector3(-0.06, 0.17, sz + 0.003), Vector3(0.22, 0.03, 0.004), "keypad_bezel")
	for k in 6:
		_add_visual_box(m, "Line%d" % k, Vector3(-0.06 - (0.02 if k % 3 == 2 else 0.0), 0.1 - k * 0.05, sz + 0.003), Vector3(0.26 - (0.06 if k % 3 == 2 else 0.0), 0.008, 0.004), "keypad_bezel")
	_add_visual_box(m, "Pin", Vector3(-0.06, 0.2, sz + 0.012), Vector3(0.025, 0.025, 0.02), "pipe_red")
	_add_box_r(m, "Tape", Vector3(0.1, -0.23, sz + 0.003), Vector3(0.08, 0.03, 0.004), "sticker_yellow", Vector3(0, 0, PI / 4.0))
	_add_visual_box(m, "Card", Vector3(0.24, 0.08, sz), Vector3(0.14, 0.1, 0.004), "sticker_yellow")
	_add_visual_box(m, "CardPin", Vector3(0.24, 0.12, sz + 0.012), Vector3(0.02, 0.02, 0.02), "motor_blue")
	# The picture lamp: a wall plate, an arm out over the board, a shade with a glow.
	var top := h / 2.0
	_add_visual_box(m, "LampPlate", Vector3(0, top + 0.1, -0.01), Vector3(0.1, 0.07, 0.016), "brass")
	_add_box_r(m, "LampArm", Vector3(0, top + 0.13, 0.07), Vector3(0.02, 0.02, 0.17), "brass", Vector3(-0.35, 0, 0))
	_add_visual_box(m, "LampShade", Vector3(0, top + 0.16, 0.15), Vector3(0.42, 0.05, 0.08), "brass")
	_add_visual_box(m, "LampGlow", Vector3(0, top + 0.133, 0.15), Vector3(0.38, 0.006, 0.05), "lamp_cream")
	var light := OmniLight3D.new()
	light.name = "BoardLight"
	light.position = Vector3(0, top + 0.12, 0.3)   # above the wainscot's batches (≤ 8 lights per mesh)
	light.light_color = Color(1.0, 0.88, 0.68)
	light.light_energy = 0.8
	light.omni_range = 0.7
	light.omni_attenuation = 1.3
	light.shadow_enabled = false
	var y := node.position.y
	light.light_cull_mask = Layout.LIGHT_MASK_BASEMENT if y < -0.3 else (9 if y > 4.0 else Layout.LIGHT_MASK_GROUND)
	_add(m, light)
	(node.get_node("Shape") as CollisionShape3D).shape = _box_shape(Vector3(w, h, 0.3))


## The lobby's cornerstone (the foundation clue, LobbyPlaque) as its model: a great light
## stone panel over about three quarters of the north wall east of the reading hall arch
## (7.3 × 2.35 m above the wainscot, 0.12 m proud of the wall, its centre 2.575 m up), with
## an inset border, a dark stone cap and sill on three corbels, bronze rosettes and a
## bronze inscription plate (the clue's engraving, sized to fit). The node stands at the
## plate (0.15 m off the wall); local +z faces the lobby. A "Model" child: DocumentPickup
## then skips its brass plate.
const CORNERSTONE_SIZE := Vector2(7.3, 2.35)


func _cornerstone_model(node: Node3D) -> void:
	var m := Node3D.new()
	m.name = "Model"
	_add(node, m)
	var wall := -0.15   # the wall face (local z)
	var w := CORNERSTONE_SIZE.x
	var h := CORNERSTONE_SIZE.y
	var face := wall + 0.12
	_add_visual_box(m, "Block", Vector3(0, 0, wall + 0.06), Vector3(w, h, 0.12), "stone_light")
	_add_visual_box(m, "Cap", Vector3(0, h / 2.0 + 0.05, wall + 0.08), Vector3(w + 0.16, 0.1, 0.16), "stone_dark")
	_add_visual_box(m, "Sill", Vector3(0, -h / 2.0 - 0.05, wall + 0.08), Vector3(w + 0.16, 0.1, 0.16), "stone_dark")
	for sx in [-w * 0.38, 0.0, w * 0.38]:
		_add_visual_box(m, "Corbel%d" % int(sx * 10), Vector3(sx, -h / 2.0 - 0.21, wall + 0.07), Vector3(0.24, 0.22, 0.14), "stone_dark")
	# An inset border 0.14 m inside the edges.
	var bi := 0.14
	var bt := 0.05
	for e in [-1.0, 1.0]:
		_add_visual_box(m, "BorderH%d" % int(e), Vector3(0, e * (h / 2.0 - bi), face + 0.004), Vector3(w - 2.0 * bi + bt, bt, 0.008), "stone_dark")
		_add_visual_box(m, "BorderV%d" % int(e), Vector3(e * (w / 2.0 - bi), 0, face + 0.004), Vector3(bt, h - 2.0 * bi - bt, 0.008), "stone_dark")
	# Bronze rosettes either side of the plate.
	for e in [-1.0, 1.0]:
		_add_box_r(m, "Rosette%d" % int(e), Vector3(e * (w / 2.0 - 0.75), 0, face + 0.01), Vector3(0.34, 0.34, 0.02), "bronze", Vector3(0, 0, PI / 4.0))
		_add_visual_box(m, "RosetteBoss%d" % int(e), Vector3(e * (w / 2.0 - 0.75), 0, face + 0.025), Vector3(0.12, 0.12, 0.02), "brass")
	_add_visual_box(m, "Frame", Vector3(0, 0, face + 0.006), Vector3(5.2, 1.6, 0.012), "bronze")
	_add_visual_box(m, "Plate", Vector3(0, 0, face + 0.015), Vector3(5.0, 1.42, 0.006), "brass")
	_add_text(m, "Title", Vector3(0, 0.2, face + 0.0195), "CAMPUS LIBRARY\nFOUNDED A.D. 1962", 64, 0.0052, Color(0.15, 0.1, 0.04))
	_add_text(m, "Motto", Vector3(0, -0.47, face + 0.0195), "Knowledge kept, knowledge shared", 40, 0.0034, Color(0.2, 0.14, 0.06))
	# The clue is read from anywhere on the plate.
	(node.get_node("Shape") as CollisionShape3D).shape = _box_shape(Vector3(5.2, 1.6, 0.3))


## Phase 4: the puzzles and their supports (MISSION in the layout).
func _add_mission(mission: Node3D) -> void:
	var m: Dictionary = Layout.MISSION
	var power := Node.new()
	power.name = "PowerNetwork"
	power.set_script(load(SCRIPTS.power))
	_add(mission, power)
	var alarm := Node3D.new()
	alarm.name = "SecurityAlarm"
	alarm.set_script(load(SCRIPTS.alarm))
	_add(mission, alarm)
	var cover := _add_tool_mechanism(mission, m.panel_cover, "panel_grey")
	cover.set("hide_model_when_operated", true)
	_dress_cover(cover.get_node("Model"), m.panel_cover.size)
	var breakers := _placed(mission, m.breakers, SCRIPTS.breakers)
	breakers.set("puzzle_name", "Breaker panel")
	breakers.set("circuit", StringName(m.breakers.circuit))
	breakers.set("objective_id", StringName(m.breakers.objective))
	var solution: Array[bool] = []
	solution.assign(m.breakers.solution)
	breakers.set("solution", solution)
	breakers.set("cover_path", breakers.get_path_to(cover))
	breakers.set("panel_style", "rail")
	# Its status text on a small screen above the panel, where the cover doesn't hide it.
	var display := Label3D.new()
	display.name = "Display"
	display.font_size = 24
	display.pixel_size = 0.0018
	display.outline_size = 4
	display.position = Vector3(0, PANEL_SCREEN_Y, -0.058)
	_add(breakers, display)
	_dress_electrical(_group(mission, "ElectricalDressing"), m.breakers.pos)
	for key in ["vault_keypad", "locker"]:
		var k: Dictionary = m[key]
		var lock := _placed(mission, k, SCRIPTS.code_lock)
		lock.set("puzzle_name", k.title)
		lock.set("code", k.code)
		lock.set("power_circuit", StringName(k.power))
		lock.set("alarm_on_wrong", k.alarm)
		lock.set("max_attempts", k.attempts)
		lock.set("lockout_time", k.lockout)
		lock.set("objective_id", StringName(k.objective))
		if k.has("door"):
			lock.set("door_path", lock.get_path_to(_root.get_node("Gameplay/" + k.door)))
		var reveals: Array[NodePath] = []
		for r in k.get("reveal", []):
			reveals.append(lock.get_path_to(_root.get_node("Gameplay/" + r)))
		lock.set("reveal_paths", reveals)
		# Polish: the vault's electronic keypad and the locker's combination lock.
		if key == "vault_keypad":
			lock.set("lock_style", "keypad")
			_add_display(lock, Vector3(0, 0.335, 0.012), 18, 0.0015)
			_dress_keypad(mission, k)
		else:
			lock.set("lock_style", "wheels")
			lock.set("dial_spacing", 0.12)
			var door := _dress_locker(mission, k)
			lock.set("door_visual_path", lock.get_path_to(door))
			_add_display(lock, Vector3(0, 0.27, -0.03), 18, 0.0014)
	var crank := _add_tool_mechanism(mission, m.pump_crank, "")
	_dress_crank(crank)
	var pump := _placed(mission, m.pump, SCRIPTS.pump)
	pump.set("puzzle_name", "Pump")
	pump.set("objective_id", StringName(m.pump.objective))
	var valves: Array[bool] = []
	valves.assign(m.pump.solution)
	pump.set("solution", valves)
	pump.set("crank_path", pump.get_path_to(mission.get_node(String(m.pump_crank.name))))
	pump.set("grate_path", pump.get_path_to(_root.get_node("Geometry/G_ServiceNetwork/" + Layout.GRATE.name)))
	_pump = pump   # its hide_on_solve (the sealed sign) is set once the signs exist
	# Polish: the pump unit, the valve manifold, the starter, the grille and the culvert water.
	pump.set("plant_style", true)
	_add_display(pump, Vector3(-3.2, 0.3, -0.04), 18, 0.0015)
	var plant := _dress_pump_room(mission, m)
	for key in ["gauge", "motor", "grille", "water"]:
		pump.set(key + "_path", pump.get_path_to(plant[key]))
	var e: Dictionary = m.drain_exit
	var exit := Area3D.new()
	exit.name = e.name
	exit.set_script(load(SCRIPTS.exit))
	exit.position = e.pos
	exit.set("objective_id", &"escape")
	exit.set("key_objective_id", &"take_manuscript")
	exit.set("extra_key_objective_id", &"drain_culvert")
	exit.set("locked_sign", "STORM DRAIN · GRATE JAMMED")
	exit.set("locked_prompt", "Storm drain (blocked)")
	exit.set("locked_reason", "You can't leave without the rare manuscript.")
	exit.set("extra_locked_reason", "The grate is jammed shut while the culvert is flooded.")
	# Phase 6 (escape C): walked through; the trigger is past the grate.
	exit.set("walk_through", true)
	exit.set("trigger_path", NodePath("Trigger"))
	exit.set("route_id", &"maintenance_passage")
	exit.set("route_name", "Hidden maintenance passage")
	exit.set("open_sign", "")   # polish: the tag goes once the grate is open
	exit.set_meta("zone_id", e.zone)
	_add(mission, exit)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = _box_shape(e.size)
	_add(exit, shape)
	var dt: Dictionary = Layout.ESCAPES.drain_trigger
	_add_trigger(exit, dt.name, dt.offset, dt.size)
	# Polish: on the tag hung on the grille (the grille's own "JammedTag" plate), not floating.
	var tag_at: Vector3 = Layout.GRATE.centre + Vector3(0, GRILLE_TAG_Y, 0.068) - e.pos
	var sign_label := _add_label(exit, "Sign", tag_at, "STORM DRAIN · GRATE JAMMED", Color(1, 0.4, 0.3))
	sign_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign_label.no_depth_test = false   # Phase 6: not seen through the hidden maintenance panel
	sign_label.font_size = 26
	sign_label.pixel_size = 0.002
	sign_label.outline_size = 0
	var noise := Node3D.new()
	noise.name = "Noise"
	noise.set_script(load(SCRIPTS.noise))
	noise.set("radius", 6.0)
	_add(exit, noise)


## Polish (code locks): a puzzle's status text (its "Display", found by Puzzle) at `at`.
func _add_display(puzzle: Node3D, at: Vector3, font: int, pixel: float) -> void:
	var display := Label3D.new()
	display.name = "Display"
	display.font_size = font
	display.pixel_size = pixel
	display.outline_size = 0
	display.position = at
	_add(puzzle, display)


## A group placed and turned like the device `d` (pos, facing), for its dressing in local coordinates.
func _device_frame(parent: Node, node_name: String, d: Dictionary) -> Node3D:
	var g := Node3D.new()
	g.name = node_name
	g.position = d.pos
	g.rotation_degrees = Vector3(0, d.get("facing", 0.0), 0)
	_add(parent, g)
	return g


## The vault keypad's steel housing, screen and bezel (no collision). Local: +z toward the room;
## the wall is 2 cm behind the keypad's centre.
func _dress_keypad(parent: Node, k: Dictionary) -> void:
	var g := _device_frame(parent, k.name + "Housing", k)
	var up := Layout.LAYER_UPPER if k.pos.y > Layout.UY - 0.5 else 0
	_add_visual_box(g, "Housing", Vector3(0, 0.15, -0.007), Vector3(0.74, 0.66, 0.02), "keypad_steel", up)
	_add_visual_box(g, "Bezel", Vector3(0, 0.38, 0.004), Vector3(0.68, 0.2, 0.004), "keypad_bezel", up)
	_add_visual_box(g, "Screen", Vector3(0, 0.38, 0.007), Vector3(0.64, 0.16, 0.004), "screen_dark", up)
	_add_visual_box(g, "KeyWell", Vector3(0, 0.02, 0.004), Vector3(0.68, 0.32, 0.004), "keypad_bezel", up)


## The security locker: a grey steel carcass with three shelves, and its door on a hinge (a
## Node3D at the hinge, returned) with a handle, hinges, vents, a SECURITY plate and the
## combination lock's frame. The door has no collision (the navmesh is unchanged).
func _dress_locker(parent: Node, k: Dictionary) -> Node3D:
	var c: Dictionary = k.cabinet
	var up := Layout.LAYER_UPPER if c.centre.y > Layout.UY - 0.5 else 0
	var half: Vector3 = c.size / 2.0
	var lo: Vector3 = c.centre - half
	var hi: Vector3 = c.centre + half
	var carcass := _group(parent, "LockerCabinet")
	var t := 0.02
	_add_visual_box(carcass, "Back", Vector3(lo.x + t / 2.0, c.centre.y, c.centre.z), Vector3(t, c.size.y, c.size.z), "locker_inside", up)
	_add_visual_box(carcass, "SideNorth", Vector3(c.centre.x, c.centre.y, lo.z + t / 2.0), Vector3(c.size.x, c.size.y, t), "locker_grey", up)
	_add_visual_box(carcass, "SideSouth", Vector3(c.centre.x, c.centre.y, hi.z - t / 2.0), Vector3(c.size.x, c.size.y, t), "locker_grey", up)
	_add_visual_box(carcass, "Top", Vector3(c.centre.x, hi.y - t / 2.0, c.centre.z), Vector3(c.size.x, t, c.size.z), "locker_grey", up)
	_add_visual_box(carcass, "Bottom", Vector3(c.centre.x, lo.y + 0.04, c.centre.z), Vector3(c.size.x, 0.08, c.size.z), "locker_grey", up)
	var n := 0
	for y in c.shelves:
		_add_visual_box(carcass, "Shelf%d" % n, Vector3(c.centre.x - 0.01, y, c.centre.z), Vector3(c.size.x - 0.06, 0.02, c.size.z - 0.04), "locker_inside", up)
		n += 1
	# The door: hinge on the south edge of the front, the door extending north from it.
	var door := Node3D.new()
	door.name = "LockerDoor"
	door.position = Vector3(hi.x + 0.015, lo.y, c.hinge_z)
	_add(parent, door)
	var w: float = c.hinge_z - lo.z - 0.01   # door width (along -z from the hinge)
	var parts := [
		["Panel", Vector3(0, c.size.y / 2.0, -w / 2.0), Vector3(0.03, c.size.y - 0.01, w), "locker_grey"],
		["Handle", Vector3(0.035, 1.05, -w + 0.07), Vector3(0.03, 0.26, 0.03), "keypad_bezel"],
		["HingeLow", Vector3(0.0, 0.3, 0.012), Vector3(0.035, 0.1, 0.02), "keypad_bezel"],
		["HingeHigh", Vector3(0.0, c.size.y - 0.3, 0.012), Vector3(0.035, 0.1, 0.02), "keypad_bezel"],
		["Plate", Vector3(0.017, c.size.y - 0.18, -w / 2.0), Vector3(0.004, 0.06, 0.24), "keypad_bezel"],
	]
	for i in 5:   # vents near the bottom, and two slats above the plate
		parts.append(["VentLow", Vector3(0.016, 0.18 + i * 0.04, -w / 2.0), Vector3(0.004, 0.015, 0.36), "keypad_bezel"])
	for y in [c.size.y - 0.1, c.size.y - 0.07]:
		parts.append(["VentTop", Vector3(0.016, y, -w / 2.0), Vector3(0.004, 0.012, 0.36), "keypad_bezel"])
	# The lock's frame and status tag (the wheels and lever are the lock's own controls).
	var lock_local: Vector3 = k.pos - door.position
	parts.append(["LockFrame", lock_local + Vector3(-0.03, 0.12, 0), Vector3(0.012, 0.12, 0.42), "keypad_bezel"])
	parts.append(["LockTag", lock_local + Vector3(-0.036, 0.27, 0), Vector3(0.004, 0.07, 0.36), "screen_dark"])
	var j := 0
	for part in parts:
		_add_visual_box(door, "%s_%d" % [part[0], j], part[1], part[2], part[3], up)
		j += 1
	var label := Label3D.new()
	label.name = "SecurityLabel"
	label.text = "SECURITY"
	label.font_size = 20
	label.pixel_size = 0.0016
	label.outline_size = 0
	label.modulate = Color(0.9, 0.9, 0.88)
	label.position = Vector3(0.02, c.size.y - 0.18, -w / 2.0)
	label.rotation_degrees = Vector3(0, 90, 0)
	_add(door, label)
	return door


## Polish (electrical room): the breaker panel's height of its status screen above its centre.
const PANEL_SCREEN_Y := 0.555
## The breakers' x positions on the rail (BreakerPanel "rail": four at 0.22 m, MAIN 0.26 m wide).
const PANEL_BREAKERS := [-0.46, -0.24, -0.02, 0.2]
const PANEL_MAIN_X := 0.44


## The panel cover's screws and warning sticker (children of its model, so they go with it).
func _dress_cover(model: Node3D, size: Vector3) -> void:
	var front := size.z / 2.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var screw := MeshInstance3D.new()
			screw.name = "Screw%s%s" % ["L" if sx < 0 else "R", "B" if sy < 0 else "T"]
			var head := CylinderMesh.new()
			head.top_radius = 0.014
			head.bottom_radius = 0.016
			head.height = 0.008
			head.radial_segments = 10
			screw.mesh = head
			screw.material_override = _look("conduit")
			screw.rotation = Vector3(PI / 2.0, 0, 0)
			screw.position = Vector3(sx * (size.x / 2.0 - 0.05), sy * (size.y / 2.0 - 0.05), front + 0.004)
			_add(model, screw)
	var sticker := MeshInstance3D.new()
	sticker.name = "WarningSticker"
	var tri := PrismMesh.new()   # a triangle facing the room, a corner up
	tri.size = Vector3(0.16, 0.14, 0.003)
	sticker.mesh = tri
	sticker.material_override = _look("sticker_yellow")
	sticker.position = Vector3(0, 0.02, front + 0.002)
	_add(model, sticker)
	var mark := Label3D.new()
	mark.name = "Mark"
	mark.text = "!"
	mark.font_size = 48
	mark.pixel_size = 0.0022
	mark.outline_size = 0
	mark.modulate = Color(0.05, 0.05, 0.05)
	mark.position = Vector3(0, 0.0, front + 0.005)
	_add(model, mark)


## The electrical room's cabinets and the breaker panel's enclosure, rail, cable
## duct, wiring and screen, the switches' conduits and the panel's cable bundle
## up to the tray (no collision; nothing in front of a control). `p`: the panel's centre.
func _dress_electrical(parent: Node3D, p: Vector3) -> void:
	# Panel enclosure (relative to the panel's centre; the cabinet front is 0.08 m behind it).
	var parts := [
		["Backplate", Vector3(0, 0.13, -0.055), Vector3(1.3, 0.5, 0.02), "steel"],
		["FrameTop", Vector3(0, 0.395, -0.05), Vector3(1.36, 0.03, 0.05), "panel_grey"],
		["FrameBottom", Vector3(0, -0.135, -0.05), Vector3(1.36, 0.03, 0.05), "panel_grey"],
		["FrameLeft", Vector3(-0.665, 0.13, -0.05), Vector3(0.03, 0.56, 0.05), "panel_grey"],
		["FrameRight", Vector3(0.665, 0.13, -0.05), Vector3(0.03, 0.56, 0.05), "panel_grey"],
		["Rail", Vector3(0, 0.05, -0.04), Vector3(1.22, 0.035, 0.01), "conduit"],
		["CableDuct", Vector3(0, 0.27, -0.025), Vector3(1.22, 0.12, 0.04), "duct_grey"],
		["Busbar", Vector3(0.03, -0.0475, 0.0), Vector3(1.08, 0.015, 0.012), "copper"],
		["Screen", Vector3(0, PANEL_SCREEN_Y, -0.07), Vector3(0.74, 0.11, 0.016), "screen_dark"],
		# The cable bundle: from the duct's right end along the cabinet, up, over the
		# cabinet's top to the wall, and up the wall into the tray (right of the DANGER sign).
		["BundleOut", Vector3(1.03, 0.27, -0.055), Vector3(0.84, 0.04, 0.04), "wire_black"],
		["BundleUp", Vector3(1.45, 0.46, -0.055), Vector3(0.04, 0.42, 0.04), "wire_black"],
		["BundleOver", Vector3(1.45, 0.67, -0.4175), Vector3(0.04, 0.04, 0.685), "wire_black"],
	]
	for x in PANEL_BREAKERS:
		parts.append(["Wire", Vector3(x, 0.175, 0.0), Vector3(0.012, 0.07, 0.012), "wire_black"])
	for dx in [-0.06, 0.06]:
		parts.append(["MainWire", Vector3(PANEL_MAIN_X + dx, 0.175, 0.0), Vector3(0.018, 0.07, 0.018), "wire_black"])
	for y in [0.38, 0.56]:
		parts.append(["BundleClip", Vector3(1.45, y, -0.055), Vector3(0.06, 0.015, 0.05), "panel_grey"])
	var k := 0
	for part in parts:
		_add_visual_box(parent, "%s_%d" % [part[0], k], p + part[1], part[2], part[3])
		k += 1
	var wall_x := p.x + 1.45
	_add_visual_box(parent, "BundleWall", Vector3(wall_x, 2.98, -27.78), Vector3(0.04, 1.96, 0.04), "wire_black")
	for y in [2.5, 3.0, 3.5]:
		_add_visual_box(parent, "BundleWallClip_%d" % k, Vector3(wall_x, y, -27.775), Vector3(0.06, 0.015, 0.05), "panel_grey")
		k += 1
	# The switches' conduits: up the cabinet from above the name plate, over the top into the wall conduit.
	for sw in Layout.SECURITY.switches:
		var at: Vector3 = sw.pos
		_add_visual_box(parent, "SwitchConduitUp_" + sw.name, Vector3(at.x, 1.7725, -27.075), Vector3(0.05, 0.505, 0.05), "conduit")
		_add_visual_box(parent, "SwitchConduitOver_" + sw.name, Vector3(at.x, 2.025, -27.415), Vector3(0.05, 0.05, 0.63), "conduit")
	# The cabinets: three doors (seams), handles, vents, a plinth, a top trim and status lamps.
	var r: Array = []
	for c in Layout.COVER:
		if c.name == "ElectricalCabinets":
			r = c.rect
	var face: float = r[3]
	var mid: float = (r[0] + r[2]) / 2.0
	var cab := [
		["Seam", Vector3(r[0] + 2.0, 1.0, face + 0.005), Vector3(0.012, 1.84, 0.01), "seam_dark"],
		["Seam", Vector3(r[0] + 4.0, 1.0, face + 0.005), Vector3(0.012, 1.84, 0.01), "seam_dark"],
		["Plinth", Vector3(mid, 0.05, face + 0.01), Vector3(r[2] - r[0] + 0.02, 0.1, 0.02), "seam_dark"],
		["TopTrim", Vector3(mid, 1.985, face + 0.006), Vector3(r[2] - r[0], 0.03, 0.012), "panel_grey"],
		["Handle", Vector3(r[0] + 1.8, 1.05, face + 0.02), Vector3(0.03, 0.24, 0.03), "panel_grey"],
		["Handle", Vector3(r[0] + 4.2, 1.05, face + 0.02), Vector3(0.03, 0.24, 0.03), "panel_grey"],
		["Handle", Vector3(r[0] + 3.85, 0.8, face + 0.02), Vector3(0.03, 0.24, 0.03), "panel_grey"],
		["Lamp", Vector3(r[0] + 0.3, 1.85, face + 0.006), Vector3(0.03, 0.03, 0.012), "led_green"],
		["Lamp", Vector3(r[0] + 0.43, 1.85, face + 0.006), Vector3(0.03, 0.03, 0.012), "led_amber"],
		["Lamp", Vector3(r[2] - 0.43, 1.85, face + 0.006), Vector3(0.03, 0.03, 0.012), "led_green"],
		["Lamp", Vector3(r[2] - 0.3, 1.85, face + 0.006), Vector3(0.03, 0.03, 0.012), "led_green"],
	]
	for i in 4:
		var y := 0.3 + i * 0.08
		cab.append(["Vent", Vector3(r[0] + 0.95, y, face + 0.007), Vector3(0.8, 0.025, 0.014), "seam_dark"])
		cab.append(["Vent", Vector3(r[2] - 0.95, y, face + 0.007), Vector3(0.8, 0.025, 0.014), "seam_dark"])
	for part in cab:
		_add_visual_box(parent, "Cabinet%s_%d" % [part[0], k], part[1], part[2], part[3])
		k += 1


## Phase 5: circuit switches and cameras (SECURITY in the layout).
func _add_security(security: Node3D) -> void:
	for sw in Layout.SECURITY.switches:
		var node := Area3D.new()
		node.name = sw.name
		node.set_script(load(SCRIPTS.switch))
		node.position = sw.pos
		node.set("circuit", StringName(sw.circuit))
		node.set("circuit_title", sw.title)
		node.set("on_text", sw.on)
		node.set("off_text", sw.off)
		if sw.has("reboots"):
			node.set("reboots_circuit", StringName(sw.reboots))
			node.set("reboot_lock_time", sw.lock)
			node.set("reboot_text", sw.reboot)
		node.set("style", "rotary")   # polish: a rotary isolator with its name plate and lamp
		node.set_meta("zone_id", "D")
		_add(security, node)
	var cameras := _group(security, "Cameras")
	for c in Layout.SECURITY.cameras:
		var cam := Node3D.new()
		cam.name = c.name
		cam.set_script(load(SCRIPTS.camera))
		cam.position = c.pos
		var to: Vector3 = c.look - c.pos
		cam.rotation = Vector3(0, atan2(-to.x, -to.z), 0)
		cam.set("camera_name", c.title)
		cam.set("pitch_degrees", rad_to_deg(atan2(-to.y, Vector2(to.x, to.z).length())))
		for key in [["fov", "fov_degrees"], ["sweep", "sweep_angle"], ["range", "view_range"]]:
			if c.has(key[0]):
				cam.set(key[1], c[key[0]])
		cam.set_meta("zone_id", c.zone)
		_add(cameras, cam)


## Phase 6: the main entrance exit, its badge reader, the dock shutter's
## release and control, the dock's trigger (ESCAPES in the layout). The dock
## ExitDoor itself is the level's (escape_x5.py points it at these).
func _add_escapes(escape: Node3D) -> void:
	var e: Dictionary = Layout.ESCAPES
	var m: Dictionary = e.main_entrance
	var exit := Area3D.new()
	exit.name = m.name
	exit.set_script(load(SCRIPTS.exit))
	exit.position = m.pos
	exit.set("objective_id", &"escape")
	exit.set("key_objective_id", &"take_manuscript")
	exit.set("walk_through", true)
	exit.set("needs_unlock", true)
	exit.set("unlock_reason", m.unlock_reason)
	exit.set("armed_after_objective", StringName(m.armed_after))
	exit.set("lockdown_text", m.lockdown)
	exit.set("route_id", StringName(m.route))
	exit.set("route_name", m.route_name)
	exit.set("locked_sign", m.locked_sign)
	exit.set("open_sign", m.open_sign)
	exit.set("locked_prompt", m.locked_prompt)
	exit.set("locked_reason", "You can't leave without the rare manuscript.")
	exit.set("trigger_path", NodePath("Trigger"))
	exit.set("panel_path", NodePath("Panel"))
	exit.set_meta("zone_id", m.zone)
	_add(escape, exit)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = _box_shape(m.size)
	_add(exit, shape)
	var panel := StaticBody3D.new()
	panel.name = "Panel"
	panel.collision_layer = 1
	panel.collision_mask = 0
	panel.position = m.panel.centre - m.pos
	_add(exit, panel)
	var pshape := CollisionShape3D.new()
	pshape.name = "Shape"
	pshape.shape = _box_shape(m.panel.size)
	_add(panel, pshape)   # polish: no mesh; the grille (EntranceGrille) shows the lockdown
	_add_trigger(exit, "Trigger", m.trigger.centre - m.pos, m.trigger.size)
	var grille := _dress_main_entrance(escape)
	exit.set("curtain_path", exit.get_path_to(grille))
	# Polish: on the LOCKDOWN light box over the doors (lobby side), not floating.
	var sign_label := _add_label(exit, "Sign", Vector3(0, ENTRANCE_BOX_Y, ENTRANCE_FACE - 0.09) - Vector3(0, m.pos.y, m.pos.z), m.locked_sign, Color(1, 0.4, 0.3))
	sign_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign_label.rotation_degrees = Vector3(0, 180, 0)
	sign_label.no_depth_test = false
	sign_label.font_size = 28
	sign_label.pixel_size = 0.0036
	sign_label.outline_size = 0
	var noise := Node3D.new()
	noise.name = "Noise"
	noise.set_script(load(SCRIPTS.noise))
	noise.set("radius", 6.0)
	_add(exit, noise)
	var r: Dictionary = e.badge_reader
	var reader := Area3D.new()
	reader.name = r.name
	reader.set_script(load(SCRIPTS.badge_reader))
	reader.position = r.pos
	reader.rotation_degrees = Vector3(0, r.facing, 0)
	reader.set("hold_time", r.hold)
	reader.set_meta("zone_id", r.zone)
	_add(escape, reader)
	reader.set("exit_path", reader.get_path_to(exit))
	# Polish: the reader's steel housing and a dark panel behind its screen text.
	var housing := _device_frame(escape, "BadgeReaderHousing", r)
	_add_visual_box(housing, "Plate", Vector3(0, 0.12, -0.04), Vector3(0.32, 0.62, 0.02), "keypad_steel")
	_add_visual_box(housing, "ScreenPanel", Vector3(0, 0.3, -0.028), Vector3(0.64, 0.24, 0.006), "screen_dark")
	var release := _add_tool_mechanism(escape, e.dock_release, "")
	_dress_release(release)
	var shutter := _placed(escape, e.dock_shutter, SCRIPTS.dock_shutter)
	shutter.set("puzzle_name", "Dock shutter")
	shutter.set("release_path", shutter.get_path_to(release))
	# The dock ExitDoor is in the level (Gameplay/ExitDoor): ../../../../Gameplay/ExitDoor from here.
	shutter.set("exit_path", NodePath("../../../../Gameplay/ExitDoor"))
	# Polish (loading dock): the station, the roller shutter, the props, the yard outside.
	_dress_dock_station(escape, e.dock_shutter)
	_add_display(shutter, Vector3(0, 0.21, 0.049), 14, 0.0013)
	var curtain := _dress_dock_shutter(escape)
	shutter.set("curtain_path", shutter.get_path_to(curtain))
	_dress_dock_yard(escape)
	var dt: Dictionary = e.dock_trigger
	_add_trigger(escape, dt.name, dt.centre, dt.size)
	# Phase 7: what the player knows about the ways out (HUD, exit messages).
	var routes := Node.new()
	routes.name = "EscapeRoutes"
	routes.set_script(load(SCRIPTS.escape_routes))
	_add(escape, routes)
	routes.set("main_exit_path", NodePath("../MainEntranceExit"))
	routes.set("dock_exit_path", NodePath("../../../../Gameplay/ExitDoor"))
	routes.set("drain_exit_path", NodePath("../../Mission/StormDrainExit"))
	routes.set("shutter_path", NodePath("../DockShutterControl"))
	routes.set("release_path", NodePath("../DockShutterRelease"))
	routes.set("panel_path", NodePath("../../MaintenancePanel"))
	routes.set("locker_path", NodePath("../../Mission/SecurityLocker"))


## An exit trigger (Area3D; ExitDoor sets its layers at run time).
func _add_trigger(parent: Node, node_name: String, offset: Vector3, size: Vector3) -> void:
	var trig := Area3D.new()
	trig.name = node_name
	trig.position = offset
	trig.collision_layer = 0
	trig.collision_mask = 2
	_add(parent, trig)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = _box_shape(size)
	_add(trig, shape)


## A Node3D with `script` at d.pos facing d.facing (degrees about Y).
func _placed(parent: Node, d: Dictionary, script_path: String) -> Node3D:
	var node := Node3D.new()
	node.name = d.name
	node.set_script(load(script_path))
	node.position = d.pos
	node.rotation_degrees = Vector3(0, d.get("facing", 0.0), 0)
	node.set_meta("zone_id", d.zone)
	_add(parent, node)
	return node


## A ToolMechanism with a box model and its interaction box.
func _add_tool_mechanism(parent: Node, d: Dictionary, look: String) -> Area3D:
	var tool := Area3D.new()
	tool.name = d.name
	tool.set_script(load(SCRIPTS.tool))
	tool.position = d.pos
	tool.rotation_degrees = Vector3(0, d.facing, 0)
	tool.set("mechanism_name", d.mechanism_name)
	tool.set("action_text", d.action_text)
	if d.has("objective"):
		tool.set("objective_id", StringName(d.objective))
	tool.set_meta("zone_id", d.zone)
	_add(parent, tool)
	if look != "":   # "": the caller builds its Model
		var mesh := MeshInstance3D.new()
		mesh.name = "Model"
		mesh.mesh = _box_mesh(d.size)
		mesh.material_override = _look(look)
		_add(tool, mesh)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = _box_shape(d.size + Vector3(0.0, 0.0, 0.1))
	_add(tool, shape)
	return tool


## Polish (pump room): collision only (a model is built in its place).
func _strip_meshes(body: Node) -> void:
	for child in body.get_children():
		if child is MeshInstance3D:
			body.remove_child(child)
			child.free()
			_tiles -= 1


func _cyl_mesh(radius: float, height: float, segments := 16) -> CylinderMesh:
	var key := "cyl_%s_%d" % [_key(Vector3(radius, height, 0)), segments]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.resource_scene_unique_id = "CylinderMesh_%s" % key
		m.top_radius = radius
		m.bottom_radius = radius
		m.height = height
		m.radial_segments = segments
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


func _torus_mesh(inner: float, outer: float) -> TorusMesh:
	var key := "torus_%s" % _key(Vector3(inner, outer, 0))
	if not _meshes.has(key):
		var m := TorusMesh.new()
		m.resource_scene_unique_id = "TorusMesh_%s" % key
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 24
		m.ring_segments = 8
		_meshes[key] = m
	return _meshes[key]


## A cylinder along `axis` ("x", "y" or "z"), no collision, no shadow.
func _add_visual_cyl(parent: Node, node_name: String, centre: Vector3, radius: float, length: float, axis: String, look: String, segments := 16) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = _cyl_mesh(radius, length, segments)
	mesh.material_override = _look(look)
	mesh.position = centre
	if axis == "x":
		mesh.rotation = Vector3(0, 0, PI / 2.0)
	elif axis == "z":
		mesh.rotation = Vector3(PI / 2.0, 0, 0)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(parent, mesh)
	return mesh


## A ring (a wheel's rim) facing +z.
func _add_ring(parent: Node, node_name: String, centre: Vector3, inner: float, outer: float, look: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = _torus_mesh(inner, outer)
	mesh.material_override = _look(look)
	mesh.position = centre
	mesh.rotation = Vector3(PI / 2.0, 0, 0)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(parent, mesh)


func _add_text(parent: Node, node_name: String, at: Vector3, text: String, font: int, pixel: float, colour: Color, yaw := 0.0) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.font_size = font
	label.pixel_size = pixel
	label.outline_size = 0
	label.modulate = colour
	label.position = at
	label.rotation_degrees = Vector3(0, yaw, 0)
	_add(parent, label)
	return label


## Polish (pump room): the grille's GRATE JAMMED tag height above the floor, the hatch's colour once found.
const GRILLE_TAG_Y := 1.35
const HATCH_COLOUR := Color(0.45, 0.47, 0.5)


## The pump room and the storm drain (no collision; the pump unit stands inside the
## PumpMachine cover's collision box, x -2…2, z -20.2…-17.8, and is lower than it).
## Returns the moving parts: {"gauge": needle pivot, "motor", "grille", "water"}.
func _dress_pump_room(parent: Node, m: Dictionary) -> Dictionary:
	var b := Layout.BF
	var ceiling := b + Layout._BC
	var unit := _group(parent, "PumpUnit")
	var z := -19.0
	var axis_y := b + 0.98   # the shaft's height
	_add_visual_box(unit, "Plinth", Vector3(0, b + 0.15, z), Vector3(3.9, 0.3, 2.3), "floor_concrete")
	_add_visual_box(unit, "BaseFrame", Vector3(0, b + 0.34, z), Vector3(3.7, 0.08, 1.1), "keypad_bezel")
	_add_text(unit, "PlinthText", Vector3(0, b + 0.15, z + 1.155), "SUMP PUMP  P-1", 40, 0.003, Color(0.85, 0.82, 0.7))
	# The motor (it hums while the pump runs).
	var motor := Node3D.new()
	motor.name = "Motor"
	motor.position = Vector3(-0.95, axis_y, z)
	_add(unit, motor)
	_add_visual_cyl(motor, "Body", Vector3.ZERO, 0.4, 1.4, "x", "motor_blue", 20)
	for i in 7:
		_add_visual_cyl(motor, "Fin%d" % i, Vector3(-0.54 + i * 0.18, 0, 0), 0.43, 0.035, "x", "motor_blue", 20)
	_add_visual_cyl(motor, "FanCowl", Vector3(-0.78, 0, 0), 0.38, 0.17, "x", "motor_dark", 20)
	_add_visual_cyl(motor, "EndShield", Vector3(0.72, 0, 0), 0.3, 0.05, "x", "motor_dark", 20)
	for sx in [-0.45, 0.45]:
		_add_visual_box(motor, "Foot%s" % ("W" if sx < 0 else "E"), Vector3(sx, -0.5, 0), Vector3(0.2, 0.2, 0.9), "motor_dark")
	_add_visual_box(motor, "TerminalBox", Vector3(0.15, 0.47, 0), Vector3(0.3, 0.18, 0.3), "motor_blue")
	_add_visual_box(motor, "RatingPlate", Vector3(0.09, 0.05, 0.437), Vector3(0.14, 0.1, 0.006), "panel_grey")   # on the fins' edge, between two fins
	_add_text(motor, "RatingText", Vector3(0.09, 0.05, 0.442), "7.5 kW\n400 V", 16, 0.0018, Color(0.1, 0.1, 0.1))
	_add_visual_box(unit, "MotorConduit", Vector3(-0.8, (b + 1.55 + ceiling) / 2.0, z), Vector3(0.05, ceiling - b - 1.55, 0.05), "conduit")
	# Coupling guard, the pump casing (volute) on its pedestal.
	_add_visual_box(unit, "CouplingGuard", Vector3(0.0, axis_y, z), Vector3(0.45, 0.4, 0.45), "hazard_yellow")
	_add_visual_box(unit, "Pedestal", Vector3(0.55, b + 0.45, z), Vector3(0.4, 0.14, 0.6), "pump_casing")
	_add_visual_cyl(unit, "Volute", Vector3(0.55, axis_y, z), 0.52, 0.5, "x", "pump_casing", 24)
	_add_visual_cyl(unit, "VoluteRim", Vector3(0.55, axis_y, z), 0.55, 0.06, "x", "pump_casing", 24)
	_add_visual_cyl(unit, "BearingHousing", Vector3(0.25, axis_y, z), 0.17, 0.12, "x", "pump_casing")
	# Suction: out of the casing's end, into a riser up to the east header.
	var pipe_r := 0.15
	_add_visual_cyl(unit, "SuctionPipe", Vector3(1.255, axis_y, z), pipe_r, 0.91, "x", "pipe")
	_add_visual_cyl(unit, "SuctionRiser", Vector3(1.55, (axis_y - 0.16 + ceiling) / 2.0, z), pipe_r, ceiling - axis_y + 0.16, "y", "pipe")
	_add_visual_box(unit, "SuctionHeaderLink", Vector3(1.78, b + 3.4, z), Vector3(0.46, 0.16, 0.16), "pipe")
	_add_flange(unit, "SuctionFlange", Vector3(0.86, axis_y, z), "x", pipe_r)
	_add_flange(unit, "SuctionRiserFlange", Vector3(1.55, b + 2.3, z), "y", pipe_r)
	# Discharge: up from the casing's top, along the ceiling to the west header.
	var top := axis_y + 0.52
	_add_visual_cyl(unit, "DischargePipe", Vector3(0.55, (top + b + 3.48) / 2.0, z), pipe_r - 0.02, b + 3.48 - top, "y", "pipe")
	_add_flange(unit, "DischargeFlange", Vector3(0.55, top + 0.03, z), "y", pipe_r - 0.02)
	_add_visual_box(unit, "DischargeValve", Vector3(0.55, b + 2.55, z), Vector3(0.3, 0.32, 0.3), "pipe_red")
	_add_visual_cyl(unit, "DischargeRun", Vector3(-0.75, b + 3.4, z), pipe_r - 0.02, 2.6, "x", "pipe")
	_add_visual_box(unit, "DischargeElbow", Vector3(0.55, b + 3.4, z), Vector3(0.3, 0.3, 0.3), "pipe")
	# The pressure gauge on the discharge pipe, facing the controls (+z).
	var g := Vector3(0.55, b + 1.8, z + 0.17)
	_add_visual_cyl(unit, "GaugeStem", Vector3(0.55, b + 1.8, z + 0.13), 0.022, 0.06, "z", "conduit")
	_add_visual_cyl(unit, "GaugeBody", g, 0.13, 0.06, "z", "keypad_bezel", 24)
	_add_visual_cyl(unit, "GaugeFace", g + Vector3(0, 0, 0.031), 0.115, 0.004, "z", "gauge_face", 24)
	for k in 6:   # scale marks from 0 (lower left) to 10 bar (lower right), red over 8
		var a := lerpf(2.3, -2.3, k / 5.0)
		var tick := MeshInstance3D.new()
		tick.name = "Tick%d" % k
		tick.mesh = _box_mesh(Vector3(0.006, 0.022, 0.003))
		tick.material_override = _look("glow_red" if k == 5 else "keypad_bezel")
		tick.position = g + Vector3(-sin(a) * 0.092, cos(a) * 0.092, 0.035)
		tick.rotation = Vector3(0, 0, a)
		_add(unit, tick)
	_add_text(unit, "GaugeText", g + Vector3(0, -0.05, 0.035), "BAR", 14, 0.0018, Color(0.1, 0.1, 0.1))
	var needle := Node3D.new()
	needle.name = "GaugeNeedle"
	needle.position = g + Vector3(0, 0, 0.037)
	needle.rotation = Vector3(0, 0, 2.3)
	_add(unit, needle)
	_add_visual_box(needle, "Pointer", Vector3(0, 0.042, 0), Vector3(0.008, 0.09, 0.003), "glow_red")
	_add_visual_box(needle, "Cap", Vector3.ZERO, Vector3(0.018, 0.018, 0.004), "keypad_bezel")

	# South wall, in the controls' frame (+z into the room, the wall face at z -0.15).
	var p: Dictionary = m.pump
	var wall := _device_frame(parent, "PumpPanelDressing", p)
	var top_y: float = ceiling - p.pos.y
	_add_visual_cyl(wall, "Manifold", Vector3(0, 0, -0.09), 0.055, 4.6, "x", "pipe")
	for x in [-1.6, 0.0, 1.6]:
		_add_visual_box(wall, "ValveBody%d" % int(x * 10), Vector3(x, 0, -0.09), Vector3(0.17, 0.17, 0.11), "keypad_bezel")
		for dx in [-0.11, 0.11]:
			_add_visual_cyl(wall, "ValveFlange%d_%d" % [int(x * 10), int(dx * 100)], Vector3(x + dx, 0, -0.09), 0.085, 0.03, "x", "pipe")
	for x in [-2.3, 2.3]:
		_add_visual_box(wall, "Elbow%d" % int(x * 10), Vector3(x, 0, -0.09), Vector3(0.13, 0.13, 0.11), "pipe")
		_add_visual_cyl(wall, "Riser%d" % int(x * 10), Vector3(x, top_y / 2.0, -0.09), 0.055, top_y, "y", "pipe")
	for x in [-2.0, -0.8, 0.8, 2.0]:
		_add_visual_box(wall, "Clamp%d" % int(x * 10), Vector3(x, 0, -0.1), Vector3(0.03, 0.13, 0.1), "conduit")
	# The starter (its lever is the START control at x -3.2; the lamps and screen are the pump's).
	var sx := -3.2
	_add_visual_box(wall, "StarterHousing", Vector3(sx, 0.02, -0.1), Vector3(0.46, 0.84, 0.1), "panel_grey")
	_add_visual_box(wall, "StarterBezel", Vector3(sx, 0.3, -0.049), Vector3(0.42, 0.16, 0.004), "keypad_bezel")
	_add_visual_box(wall, "StarterScreen", Vector3(sx, 0.3, -0.046), Vector3(0.38, 0.12, 0.004), "screen_dark")
	_add_text(wall, "StarterTitle", Vector3(sx, 0.41, -0.048), "PUMP P-1 STARTER", 16, 0.0018, Color(0.12, 0.12, 0.12))
	_add_visual_box(wall, "StarterConduit", Vector3(sx, (0.44 + top_y) / 2.0, -0.12), Vector3(0.05, top_y - 0.44, 0.05), "conduit")

	# The storm drain: the grille (slides up), its guide channels, the ceiling slot, streaks, the water.
	var gr: Dictionary = Layout.GRATE
	var grille := Node3D.new()
	grille.name = "StormDrainGrille"
	grille.position = gr.centre
	_add(parent, grille)
	var h: float = gr.height
	var w: float = gr.width
	_add_visual_box(grille, "RailTop", Vector3(0, h - 0.05, 0), Vector3(w, 0.1, 0.1), "grille_steel")
	_add_visual_box(grille, "RailBottom", Vector3(0, 0.05, 0), Vector3(w, 0.1, 0.1), "rust")
	for sx2 in [-1.0, 1.0]:
		_add_visual_box(grille, "Stile%s" % ("W" if sx2 < 0 else "E"), Vector3(sx2 * (w / 2.0 - 0.05), h / 2.0, 0), Vector3(0.1, h, 0.1), "grille_steel")
	var bars := 19
	for i in bars:
		var bx := -1.62 + i * 0.18
		_add_visual_box(grille, "Bar%d" % i, Vector3(bx, h / 2.0, 0), Vector3(0.035, h - 0.2, 0.035), "grille_steel")
	for y in [1.0, 2.0, 3.0]:
		_add_visual_box(grille, "Flat%d" % int(y), Vector3(0, y, 0.03), Vector3(w - 0.2, 0.06, 0.02), "grille_steel")
	_add_visual_box(grille, "JammedTag", Vector3(0, GRILLE_TAG_Y, 0.06), Vector3(1.0, 0.12, 0.01), "sign_board")
	for sx2 in [-0.42, 0.42]:
		_add_visual_box(grille, "TagWire%d" % int(sx2 * 100), Vector3(sx2, GRILLE_TAG_Y + 0.1, 0.05), Vector3(0.008, 0.1, 0.008), "conduit")
	var drain := _group(parent, "DrainDressing")
	for sx2 in [-1.0, 1.0]:
		_add_visual_box(drain, "Guide%s" % ("W" if sx2 < 0 else "E"), Vector3(sx2 * 1.82, b + Layout._BC / 2.0, gr.centre.z), Vector3(0.06, Layout._BC, 0.24), "keypad_bezel")
	_add_visual_box(drain, "Lintel", Vector3(0, ceiling - 0.06, gr.centre.z), Vector3(3.7, 0.12, 0.4), "keypad_bezel")
	_add_visual_box(drain, "Slot", Vector3(0, ceiling - 0.122, gr.centre.z), Vector3(3.64, 0.004, 0.12), "screen_dark")
	_add_visual_box(drain, "Sill", Vector3(0, b + 0.01, gr.centre.z), Vector3(3.7, 0.02, 0.4), "stone")
	var streaks := [[-1.2, 0.22, 1.4], [-0.35, 0.3, 2.0], [0.5, 0.18, 1.2], [1.25, 0.26, 1.7]]
	for i in streaks.size():
		var st: Array = streaks[i]
		_add_visual_box(drain, "Streak%d" % i, Vector3(st[0], b + 0.003, gr.centre.z + 0.2 + st[2] / 2.0), Vector3(st[1], 0.006, st[2]), "damp")
	var water := MeshInstance3D.new()
	water.name = "CulvertWater"
	water.mesh = _box_mesh(Vector3(3.7, 0.1, 12.85))
	water.material_override = _look("water")
	water.position = Vector3(0, b + 0.05, -33.575)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(parent, water)
	return {"gauge": needle, "motor": motor, "grille": grille, "water": water}


func _add_flange(parent: Node, node_name: String, at: Vector3, axis: String, pipe_r: float) -> void:
	_add_visual_cyl(parent, node_name, at, pipe_r + 0.07, 0.05, axis, "pipe")
	for k in 6:   # bolts round it
		var a := TAU * k / 6.0
		var offset := Vector3(0, cos(a), sin(a)) if axis == "x" else Vector3(cos(a), 0, sin(a))
		_add_visual_cyl(parent, "%sBolt%d" % [node_name, k], at + offset * (pipe_r + 0.045), 0.012, 0.075, axis, "keypad_bezel", 6)


## The pump crank: a rusted handwheel on a gearbox, chained and tagged SEIZED (no
## collision; the interaction box is the crank's own). Local: +z into the room, the
## wall face 0.12 m behind. "Model/Wheel" turns once and "Chain" / "Tag" go when freed.
func _dress_crank(tool: Node3D) -> void:
	var model := Node3D.new()
	model.name = "Model"
	_add(tool, model)
	_add_visual_box(model, "Backplate", Vector3(0, 0, -0.11), Vector3(0.46, 0.46, 0.02), "steel")
	_add_visual_box(model, "Gearbox", Vector3(0, 0, -0.07), Vector3(0.2, 0.2, 0.06), "rust")
	_add_visual_cyl(model, "Shaft", Vector3(0, 0, -0.03), 0.025, 0.06, "z", "keypad_bezel")
	var wheel := Node3D.new()
	wheel.name = "Wheel"
	_add(model, wheel)
	_add_ring(wheel, "Rim", Vector3.ZERO, 0.15, 0.18, "rust")
	for k in 4:
		var spoke := MeshInstance3D.new()
		spoke.name = "Spoke%d" % k
		spoke.mesh = _box_mesh(Vector3(0.32, 0.022, 0.016))
		spoke.material_override = _look("rust")
		spoke.rotation = Vector3(0, 0, PI * k / 4.0)
		spoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add(wheel, spoke)
	_add_visual_cyl(wheel, "Hub", Vector3.ZERO, 0.035, 0.04, "z", "keypad_bezel")
	_add_visual_cyl(wheel, "Handle", Vector3(0, 0.165, 0.05), 0.018, 0.1, "z", "keypad_bezel", 8)
	# The chain: two strands crossing the wheel to a padlock.
	var chain := Node3D.new()
	chain.name = "Chain"
	_add(model, chain)
	var n := 0
	for strand in [[Vector3(-0.21, 0.2, 0.03), Vector3(0.02, -0.06, 0.035)], [Vector3(0.21, 0.2, 0.03), Vector3(0.02, -0.06, 0.035)]]:
		var a: Vector3 = strand[0]
		var c: Vector3 = strand[1]
		var steps := 7
		var angle := atan2(c.y - a.y, c.x - a.x)
		for i in steps:
			var link := MeshInstance3D.new()
			link.name = "Link%d" % n
			link.mesh = _box_mesh(Vector3(0.05, 0.018, 0.012) if i % 2 == 0 else Vector3(0.05, 0.012, 0.018))
			link.material_override = _look("tool_steel")
			link.position = a.lerp(c, (i + 0.5) / steps)
			link.rotation = Vector3(0, 0, angle)
			link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_add(chain, link)
			n += 1
	_add_visual_box(chain, "Padlock", Vector3(0.02, -0.1, 0.045), Vector3(0.06, 0.07, 0.03), "brass")
	_add_visual_box(chain, "Shackle", Vector3(0.02, -0.055, 0.045), Vector3(0.04, 0.03, 0.01), "tool_steel")
	var tag := Node3D.new()
	tag.name = "Tag"
	tag.position = Vector3(0.09, -0.16, 0.05)
	tag.rotation = Vector3(0, 0, 0.18)
	_add(model, tag)
	_add_visual_box(tag, "Plate", Vector3.ZERO, Vector3(0.15, 0.07, 0.004), "sticker_yellow")
	_add_text(tag, "Text", Vector3(0, 0, 0.003), "SEIZED", 24, 0.0018, Color(0.08, 0.08, 0.08))


## The hidden maintenance panel once found: a steel access hatch on its tunnel side
## (+z): frame, stiffeners with rivets, hinges, the latch on the right-hand edge, a
## stencil and a hazard kick plate. "Panel/Hatch", shown by AccessDoor once found.
func _dress_hatch(panel: Node3D, size: Vector3) -> void:
	var hatch := Node3D.new()
	hatch.name = "Hatch"
	hatch.visible = false
	_add(panel, hatch)
	var f := size.z / 2.0
	var w := size.x
	var h := size.y
	_add_visual_box(hatch, "FrameTop", Vector3(0, h / 2.0 - 0.06, f + 0.015), Vector3(w, 0.12, 0.03), "keypad_bezel")
	_add_visual_box(hatch, "FrameBottom", Vector3(0, -h / 2.0 + 0.06, f + 0.015), Vector3(w, 0.12, 0.03), "keypad_bezel")
	for sx in [-1.0, 1.0]:
		_add_visual_box(hatch, "Frame%s" % ("W" if sx < 0 else "E"), Vector3(sx * (w / 2.0 - 0.06), 0, f + 0.015), Vector3(0.12, h, 0.03), "keypad_bezel")
	for y in [-1.05, 0.3]:
		_add_visual_box(hatch, "Rib%d" % int(y * 10), Vector3(0, y, f + 0.012), Vector3(w - 0.24, 0.08, 0.024), "panel_grey")
		for i in 8:
			_add_visual_box(hatch, "Rivet%d_%d" % [int(y * 10), i], Vector3(-1.65 + i * 0.47, y, f + 0.028), Vector3(0.025, 0.025, 0.01), "keypad_bezel")
	for y in [-1.3, 0.0, 1.3]:
		_add_visual_box(hatch, "Hinge%d" % int(y * 10), Vector3(-w / 2.0 + 0.1, y, f + 0.04), Vector3(0.08, 0.22, 0.05), "conduit")
	_add_visual_box(hatch, "LatchPlate", Vector3(w / 2.0 - 0.3, -0.7, f + 0.008), Vector3(0.14, 0.34, 0.016), "conduit")
	_add_visual_box(hatch, "LatchHandle", Vector3(w / 2.0 - 0.3, -0.7, f + 0.06), Vector3(0.045, 0.24, 0.045), "keypad_bezel")
	for dy in [-0.1, 0.1]:
		_add_visual_box(hatch, "LatchPost%d" % int(dy * 10), Vector3(w / 2.0 - 0.3, -0.7 + dy, f + 0.03), Vector3(0.03, 0.03, 0.05), "keypad_bezel")
	for i in 10:
		_add_visual_box(hatch, "Kick%d" % i, Vector3(-w / 2.0 + 0.12 + (i + 0.5) * (w - 0.24) / 10.0, -h / 2.0 + 0.27, f + 0.004),
			Vector3((w - 0.24) / 10.0, 0.18, 0.008), "hazard_yellow" if i % 2 == 0 else "hazard_black")
	_add_text(hatch, "Stencil", Vector3(0, 0.95, f + 0.002), "MAINTENANCE", 64, 0.004, Color(0.93, 0.86, 0.55))
	_add_text(hatch, "StencilSub", Vector3(0, 0.66, f + 0.002), "CULVERT ACCESS · KEEP CLEAR", 32, 0.0035, Color(0.93, 0.86, 0.55))


# --- Loading dock (polish) -------------------------------------------------------------------

## The dock exit's opening (in the level's east wall x 36, 0.3 m thick): z 22.5…25.5, 0…2.6 m.
const DOCK_X := 36.0
const DOCK_Z := 24.0
const DOCK_W := 3.0
const DOCK_H := 2.6
## Outside the building: its own render layer, lit only by the yard's streetlight (and seen through the door).
const LAYER_YARD := 32


## The shutter release: a yellow MANUAL RELEASE box with a red pull handle ("Model/Handle",
## dropped when freed), wedged by a rusty bolt ("Model/Bolt") and tagged JAMMED ("Model/Tag").
## Local: +z into the room, the wall face 2 cm behind. No collision (the release's own box is used).
func _dress_release(tool: Node3D) -> void:
	var model := Node3D.new()
	model.name = "Model"
	_add(tool, model)
	_add_visual_box(model, "Housing", Vector3(0, 0.03, 0.01), Vector3(0.36, 0.5, 0.06), "release_yellow")
	_add_visual_box(model, "Slot", Vector3(0, -0.01, 0.041), Vector3(0.05, 0.32, 0.004), "screen_dark")
	_add_text(model, "Title", Vector3(0, 0.235, 0.042), "MANUAL RELEASE", 18, 0.0016, Color(0.06, 0.06, 0.06))
	_add_text(model, "Hint", Vector3(0, -0.2, 0.042), "PULL DOWN TO FREE SHUTTER", 12, 0.0014, Color(0.06, 0.06, 0.06))
	var handle := Node3D.new()
	handle.name = "Handle"
	handle.position = Vector3(0, 0.12, 0.042)
	_add(model, handle)
	_add_visual_box(handle, "Stem", Vector3(0, 0, 0.03), Vector3(0.025, 0.025, 0.06), "keypad_bezel")
	_add_visual_box(handle, "Grip", Vector3(0, 0, 0.065), Vector3(0.16, 0.035, 0.035), "pipe_red")
	var bolt := Node3D.new()
	bolt.name = "Bolt"
	bolt.position = Vector3(0, 0.07, 0.058)
	_add(model, bolt)
	_add_visual_cyl(bolt, "Shank", Vector3.ZERO, 0.012, 0.15, "x", "rust", 8)
	for sx in [-0.075, 0.075]:
		_add_visual_box(bolt, "Nut%d" % int(sx * 1000), Vector3(sx, 0, 0), Vector3(0.022, 0.032, 0.032), "rust")
	var tag := Node3D.new()
	tag.name = "Tag"
	tag.position = Vector3(0.105, -0.02, 0.07)
	tag.rotation = Vector3(0, 0, -0.2)
	_add(model, tag)
	_add_visual_box(tag, "Plate", Vector3.ZERO, Vector3(0.11, 0.055, 0.004), "sign_red")
	_add_text(tag, "Text", Vector3(0, 0, 0.003), "JAMMED", 20, 0.0016, Color(1, 0.95, 0.9))
	_add_visual_box(tag, "Wire", Vector3(-0.05, 0.05, -0.002), Vector3(0.004, 0.06, 0.004), "conduit")


## The shutter control's station (its OPEN button is the control's own; the lamp is the
## puzzle's): a yellow housing, the screen, CLOSE and STOP (for show), a conduit up the wall.
func _dress_dock_station(parent: Node, d: Dictionary) -> void:
	var g := _device_frame(parent, "DockShutterStation", d)
	_add_visual_box(g, "Housing", Vector3(0, 0.02, 0.01), Vector3(0.36, 0.6, 0.06), "release_yellow")
	_add_visual_box(g, "Bezel", Vector3(0, 0.21, 0.042), Vector3(0.32, 0.1, 0.004), "keypad_bezel")
	_add_visual_box(g, "Screen", Vector3(0, 0.21, 0.045), Vector3(0.3, 0.08, 0.004), "screen_dark")
	_add_text(g, "Title", Vector3(0, 0.29, 0.042), "DOCK SHUTTER", 16, 0.0015, Color(0.06, 0.06, 0.06))
	_add_text(g, "OpenText", Vector3(0.09, 0, 0.042), "OPEN", 16, 0.0015, Color(0.06, 0.06, 0.06))
	_add_visual_cyl(g, "CloseButton", Vector3(0, -0.11, 0.052), 0.03, 0.024, "z", "wire_black", 12)
	_add_text(g, "CloseMark", Vector3(0, -0.11, 0.065), "▼", 24, 0.0016, Color(0.9, 0.9, 0.9))
	_add_text(g, "CloseText", Vector3(0.09, -0.11, 0.042), "CLOSE", 16, 0.0015, Color(0.06, 0.06, 0.06))
	_add_visual_cyl(g, "StopCollar", Vector3(0, -0.21, 0.044), 0.048, 0.01, "z", "release_yellow", 16)
	_add_visual_cyl(g, "StopButton", Vector3(0, -0.21, 0.06), 0.04, 0.03, "z", "pipe_red", 16)
	_add_text(g, "StopText", Vector3(0.09, -0.21, 0.042), "STOP", 16, 0.0015, Color(0.06, 0.06, 0.06))
	_add_visual_box(g, "Conduit", Vector3(0.13, 0.32 + 0.7, 0.0), Vector3(0.04, 1.4, 0.04), "conduit")


## The roller shutter: galvanised slats and a bottom bar (the curtain, returned: it rolls
## up, DockShutter hides the slats above the opening), guide rails, the coil box and motor,
## the wall over the door (the level's green header is hidden), an EXIT sign and two bollards.
func _dress_dock_shutter(parent: Node) -> Node3D:
	var curtain := Node3D.new()
	curtain.name = "ShutterCurtain"
	curtain.position = Vector3(DOCK_X - 0.03, 0, DOCK_Z)
	_add(parent, curtain)
	var bottom := Node3D.new()
	bottom.name = "SlatBottom"
	bottom.position = Vector3(0, 0.05, 0)
	_add(curtain, bottom)
	_add_visual_box(bottom, "Bar", Vector3.ZERO, Vector3(0.06, 0.09, DOCK_W), "keypad_bezel")
	_add_visual_box(bottom, "Seal", Vector3(0, -0.038, 0), Vector3(0.05, 0.02, DOCK_W), "wire_black")
	for z in [-0.9, 0.9]:
		_add_visual_box(bottom, "Pull%d" % int(z * 10), Vector3(-0.05, 0.0, z), Vector3(0.04, 0.04, 0.14), "conduit")
	var n := 25
	for i in n:
		var slat := Node3D.new()
		slat.name = "Slat%02d" % i
		slat.position = Vector3(0, 0.15 + i * 0.1, 0)
		_add(curtain, slat)
		_add_visual_box(slat, "Face", Vector3.ZERO, Vector3(0.03, 0.094, DOCK_W), "shutter_steel")
		_add_visual_box(slat, "Groove", Vector3(0, 0.047, 0), Vector3(0.036, 0.012, DOCK_W), "shutter_groove")
	var frame := _group(parent, "DockShutterFrame")
	for side in [-1.0, 1.0]:
		var z: float = DOCK_Z + side * (DOCK_W / 2.0 - 0.035)
		_add_visual_box(frame, "Rail%s" % ("N" if side < 0 else "S"), Vector3(DOCK_X, DOCK_H / 2.0, z), Vector3(0.16, DOCK_H, 0.07), "shutter_box")
	var room_face := DOCK_X - 0.15
	_add_visual_box(frame, "Header", Vector3(DOCK_X, DOCK_H + 0.8, DOCK_Z), Vector3(0.3, 1.6, DOCK_W), "wall")
	_add_visual_box(frame, "CoilBox", Vector3(room_face - 0.21, DOCK_H + 0.28, DOCK_Z), Vector3(0.42, 0.56, DOCK_W + 0.5), "shutter_box")
	for side in [-1.0, 1.0]:
		_add_visual_box(frame, "CoilCap%s" % ("N" if side < 0 else "S"), Vector3(room_face - 0.21, DOCK_H + 0.28, DOCK_Z + side * (DOCK_W / 2.0 + 0.27)),
			Vector3(0.44, 0.58, 0.04), "keypad_bezel")
	_add_visual_box(frame, "Motor", Vector3(room_face - 0.2, DOCK_H + 0.28, DOCK_Z + DOCK_W / 2.0 + 0.45), Vector3(0.3, 0.26, 0.32), "motor_dark")
	_add_text(frame, "CoilText", Vector3(room_face - 0.425, DOCK_H + 0.28, DOCK_Z), "LOADING BAY 1", 40, 0.003, Color(0.12, 0.12, 0.12), -90.0)
	return curtain


## Solid props (StaticBody3D, one box each, the model inside it; navmesh rebaked) and loose
## decor (no collision, against the walls or on the crates). Clear of the guard's way across
## the dock, the camera's view, the release, the shutter and its control.
func _build_dock_props(solid: Node3D, decor: Node3D) -> void:
	# Bollards either side of the shutter, on the wall piers.
	for z in [22.2, 25.8]:
		var m := _solid_prop(solid, "Bollard%d" % int(z * 10), [35.44, z - 0.11, 35.66, z + 0.11], 1.0)
		_add_visual_cyl(m, "Post", Vector3(0, 0.5, 0), 0.1, 1.0, "y", "hazard_yellow", 12)
		for y in [0.55, 0.85]:
			_add_visual_cyl(m, "Band%d" % int(y * 100), Vector3(0, y, 0), 0.102, 0.12, "y", "hazard_black", 12)
	# Pallet rack along the north wall, east of the storage door (under the camera).
	var rack := _solid_prop(solid, "PalletRack", [29.5, 12.15, 35.0, 13.35], 2.4)
	for x in [-2.7, -0.9, 0.9, 2.7]:
		for z in [-0.55, 0.55]:
			_add_visual_box(rack, "Upright%d_%d" % [int(x * 10), int(z * 100)], Vector3(x, 1.2, z), Vector3(0.08, 2.4, 0.08), "rack_blue")
	for y in [1.15, 2.33]:
		for z in [-0.55, 0.55]:
			_add_visual_box(rack, "Beam%d_%d" % [int(y * 100), int(z * 100)], Vector3(0, y, z), Vector3(5.48, 0.1, 0.06), "rack_orange")
	var loads := [["cardboard", 0.8], ["wrap", 0.85], ["", 0.0], ["wrap", 0.7], ["cardboard", 0.7], ["cardboard_dark", 0.5]]
	for i in 6:
		var bx: float = [-1.8, 0.0, 1.8][i % 3]
		var by: float = 0.0 if i < 3 else 1.2
		_pallet(rack, "Pallet%d" % i, Vector3(bx, by, 0), Vector3(1.2, 0.14, 1.0))
		if loads[i][0] != "":
			_add_visual_box(rack, "Load%d" % i, Vector3(bx, by + 0.14 + loads[i][1] / 2.0, 0), Vector3(1.1, loads[i][1], 0.9), loads[i][0])
		else:
			_add_visual_box(rack, "Load%d" % i, Vector3(bx - 0.25, by + 0.34, -0.1), Vector3(0.5, 0.4, 0.5), "cardboard")
	# Book boxes on pallets along the south wall.
	for k in 2:
		var r: Array = [[24.2, 26.5, 25.6, 27.8], [30.0, 26.5, 31.4, 27.8]][k]
		var m := _solid_prop(solid, "BookBoxes%d" % k, r, 1.3)
		_pallet(m, "Pallet", Vector3.ZERO, Vector3(1.4, 0.14, 1.3))
		var n := 0
		for layer in 2:
			for ix in 2:
				for iz in 2:
					var look := "cardboard" if (ix + iz + layer + k) % 2 == 0 else "cardboard_dark"
					_add_visual_box(m, "Box%d" % n, Vector3(-0.34 + ix * 0.68, 0.14 + 0.29 + layer * 0.58, -0.31 + iz * 0.62), Vector3(0.66, 0.57, 0.6), look)
					n += 1
		_add_visual_box(m, "Strap", Vector3(0, 0.72, 0), Vector3(1.37, 1.16, 0.03), "wire_black")
		_add_text(m, "Label", Vector3(0, 0.5, -0.611), "BOOKS · FRAGILE", 22, 0.002, Color(0.15, 0.1, 0.05), 180.0)
	# Shrink-wrapped pallets: east of the crates, and by the south wall near the control.
	for k in 2:
		var r: Array = [[31.0, 15.4, 32.2, 16.6], [31.6, 26.4, 32.8, 27.6]][k]
		var m := _solid_prop(solid, "Wrapped%d" % k, r, 1.4)
		_pallet(m, "Pallet", Vector3.ZERO, Vector3(1.2, 0.14, 1.2))
		_add_visual_box(m, "Wrap", Vector3(0, 0.14 + 0.6, 0), Vector3(1.16, 1.2, 1.16), "wrap")
		_add_visual_box(m, "Cap", Vector3(0, 1.36, 0), Vector3(1.18, 0.04, 1.18), "cardboard")
		for sx in [-0.3, 0.3]:
			_add_visual_box(m, "Strap%d" % int(sx * 10), Vector3(sx, 0.77, 0), Vector3(0.04, 1.26, 1.19), "wire_black")
	# Roll cages of returned books, north-west corner.
	var book_looks := ["pipe_red", "motor_blue", "cabinet_green", "cardboard", "rack_orange", "keypad_bezel"]
	for k in 2:
		var x0 := 17.4 + k * 1.0
		var m := _solid_prop(solid, "RollCage%d" % k, [x0, 12.4, x0 + 0.8, 13.1], 1.7)
		_add_visual_box(m, "Base", Vector3(0, 0.12, 0), Vector3(0.8, 0.06, 0.7), "keypad_bezel")
		for sx in [-0.37, 0.37]:
			for sz in [-0.32, 0.32]:
				_add_visual_box(m, "Post%d_%d" % [int(sx * 100), int(sz * 100)], Vector3(sx, 0.9, sz), Vector3(0.03, 1.6, 0.03), "conduit")
				_add_visual_cyl(m, "Castor%d_%d" % [int(sx * 100), int(sz * 100)], Vector3(sx, 0.045, sz), 0.045, 0.03, "x", "wire_black", 8)
		for y in [0.45, 0.8, 1.15, 1.5]:
			_add_visual_box(m, "BarBack%d" % int(y * 100), Vector3(0, y, -0.32), Vector3(0.74, 0.02, 0.02), "conduit")
			for sx in [-0.37, 0.37]:
				_add_visual_box(m, "BarSide%d_%d" % [int(sx * 100), int(y * 100)], Vector3(sx, y, 0), Vector3(0.02, 0.02, 0.64), "conduit")
		_add_visual_box(m, "Shelf", Vector3(0, 0.85, 0), Vector3(0.74, 0.03, 0.64), "keypad_bezel")
		var b := 0
		for shelf_y in [0.15, 0.865]:
			for i in 5:
				var h := 0.22 + 0.04 * ((i + k) % 3)
				_add_visual_box(m, "Books%d" % b, Vector3(-0.28 + i * 0.14, shelf_y + h / 2.0, -0.05), Vector3(0.12, h, 0.5), book_looks[(i + b + k) % book_looks.size()])
				b += 1
	# The forklift, parked against the south wall in the south-west corner, forks down.
	var f := _solid_prop(solid, "Forklift", [17.4, 26.4, 19.6, 27.7], 2.2)
	_add_visual_box(f, "Chassis", Vector3(-0.05, 0.45, 0), Vector3(1.9, 0.5, 1.1), "forklift_yellow")
	_add_visual_box(f, "Counterweight", Vector3(-0.85, 0.62, 0), Vector3(0.45, 0.78, 1.16), "keypad_bezel")
	_add_visual_box(f, "Seat", Vector3(-0.35, 0.96, 0), Vector3(0.4, 0.12, 0.45), "wire_black")
	_add_visual_box(f, "Backrest", Vector3(-0.55, 1.17, 0), Vector3(0.08, 0.4, 0.45), "wire_black")
	for x in [-0.6, 0.45]:
		for z in [-0.5, 0.5]:
			_add_visual_box(f, "Guard%d_%d" % [int(x * 10), int(z * 10)], Vector3(x, 1.33, z), Vector3(0.05, 1.26, 0.05), "wire_black")
	_add_visual_box(f, "Roof", Vector3(-0.075, 1.98, 0), Vector3(1.15, 0.05, 1.05), "wire_black")
	_add_visual_cyl(f, "Beacon", Vector3(-0.4, 2.05, 0.3), 0.05, 0.08, "y", "glow_amber", 10)
	_add_visual_cyl(f, "Steering", Vector3(0.2, 1.15, 0), 0.15, 0.03, "y", "wire_black", 16)
	for z in [-0.35, 0.35]:
		_add_visual_box(f, "Mast%d" % int(z * 10), Vector3(0.95, 1.1, z), Vector3(0.08, 2.2, 0.08), "keypad_bezel")
	_add_visual_box(f, "MastTop", Vector3(0.95, 2.16, 0), Vector3(0.08, 0.08, 0.78), "keypad_bezel")
	_add_visual_box(f, "Carriage", Vector3(1.02, 0.3, 0), Vector3(0.06, 0.45, 0.85), "keypad_bezel")
	for x in [0.6, -0.75]:
		var r := 0.28 if x > 0 else 0.22
		for z in [-0.58, 0.58]:
			_add_visual_cyl(f, "Wheel%d_%d" % [int(x * 10), int(z * 10)], Vector3(x, r, z), r, 0.2, "z", "wire_black", 14)
	_add_text(f, "Number", Vector3(-1.076, 0.7, 0), "FL-2", 40, 0.003, Color(0.95, 0.8, 0.1), -90.0)
	# Its forks (on the floor, no collision) and the loose decor.
	for z in [-0.25, 0.25]:
		_add_visual_box(decor, "ForkliftFork%d" % int(z * 10), Vector3(20.1, 0.025, 27.05 + z), Vector3(1.0, 0.05, 0.12), "keypad_bezel")
	_add_visual_box(decor, "CrateBoxA", Vector3(21.9, 1.4, 15.9), Vector3(0.55, 0.4, 0.45), "cardboard")
	_add_visual_box(decor, "CrateBoxB", Vector3(22.3, 1.35, 16.35), Vector3(0.4, 0.3, 0.35), "cardboard_dark")
	_add_visual_box(decor, "CrateBoxC", Vector3(28.1, 1.375, 25.1), Vector3(0.6, 0.35, 0.5), "cardboard")
	for k in 2:   # pallets stood on edge against the west wall, south of the dock door
		var p := Node3D.new()
		p.name = "LeaningPallet%d" % k
		p.position = Vector3(17.22 + k * 0.15, 0, 23.6 + k * 0.1)
		p.rotation = Vector3(0, 0, -0.05)
		_add(decor, p)
		for i in 5:
			_add_visual_box(p, "Board%d" % i, Vector3(0, 0.08 + i * 0.26, 0), Vector3(0.025, 0.14, 1.2), "pallet_wood")
		for z in [-0.55, 0.0, 0.55]:
			_add_visual_box(p, "Block%d" % int(z * 100), Vector3(0.06, 0.6, z), Vector3(0.1, 1.18, 0.1), "pallet_wood")
	# Hand truck against the south wall, east of the book boxes.
	for x in [26.05, 26.45]:
		_add_visual_box(decor, "HandTruckRail%d" % int(x * 100), Vector3(x, 0.62, 27.72), Vector3(0.03, 1.2, 0.03), "keypad_bezel")
		_add_visual_cyl(decor, "HandTruckWheel%d" % int(x * 100), Vector3(x, 0.12, 27.66), 0.12, 0.05, "x", "wire_black", 12)
	_add_visual_box(decor, "HandTruckNose", Vector3(26.25, 0.01, 27.6), Vector3(0.45, 0.02, 0.2), "keypad_bezel")
	_add_visual_box(decor, "HandTruckBar", Vector3(26.25, 1.2, 27.72), Vector3(0.43, 0.03, 0.03), "keypad_bezel")
	# Pallet jack against the south wall, beside the forklift.
	for z in [27.35, 27.68]:
		_add_visual_box(decor, "JackFork%d" % int(z * 100), Vector3(21.6, 0.04, z), Vector3(1.15, 0.08, 0.16), "pipe_red")
	_add_visual_box(decor, "JackPump", Vector3(20.88, 0.2, 27.52), Vector3(0.25, 0.3, 0.45), "pipe_red")
	_add_visual_box(decor, "JackHandle", Vector3(20.82, 0.85, 27.7), Vector3(0.04, 1.0, 0.04), "keypad_bezel")   # stood up against the wall
	_add_visual_box(decor, "JackGrip", Vector3(20.82, 1.35, 27.72), Vector3(0.3, 0.04, 0.04), "wire_black")
	# Floor: the bay box in front of the shutter and its stencil.
	_add_visual_box(decor, "BayLineWest", Vector3(32.25, 0.005, DOCK_Z), Vector3(0.1, 0.01, 3.6), "hazard_yellow")
	for z in [22.25, 25.75]:
		_add_visual_box(decor, "BayLine%d" % int(z * 100), Vector3(34.05, 0.005, z), Vector3(3.6, 0.01, 0.1), "hazard_yellow")
	var stencil := _add_text(decor, "BayStencil", Vector3(33.3, 0.012, DOCK_Z), "LOADING BAY 1", 64, 0.0042, Color(0.9, 0.75, 0.15))
	stencil.basis = Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))   # flat, read from the room (facing east)


# --- Electrical room door and Book Processing (polish) ---------------------------------------

## The electrical room door: two grey steel leaves on hinges (swinging into the electrical
## room when it opens), a steel frame, a card reader and a light strip that show the
## door's state, a DANGER sign. Local to the door (+x: the electrical room; the floor
## is 1.2 m below its origin). The panel keeps its collision; AccessDoor stops drawing it.
func _dress_security_door(door: Node3D, d: Dictionary) -> void:
	door.set("found_colour", Color(0.55, 0.57, 0.58))
	var parts := _door_leaves(door, d.width, "steel")
	door.set("leaf_paths", parts.leaves)
	door.set("leaf_open_angles", parts.angles)
	door.set("status_light_paths", parts.lights)


## Two door leaves on hinges at the jambs, a frame, a light strip over the door and a
## card reader with its LED, built in `holder` (placed and turned like the door: +x is
## the side the leaves swing to, the floor 1.2 m below). "steel": grey with wired glass
## and a DANGER plate; "wood": wooden with a glazed panel, brass and a STAFF ONLY plate.
## Returns {leaves, angles, lights} as paths relative to `holder`.
func _door_leaves(holder: Node3D, w: float, style: String) -> Dictionary:
	var h: float = Layout.DOOR_HEIGHT
	var floor_y := -1.2
	var wood := style == "wood"
	var leaves: Array[NodePath] = []
	var angles := PackedFloat32Array()
	for side in [-1.0, 1.0]:   # hinges at both jambs, each leaf reaching to the middle
		var hinge := Node3D.new()
		hinge.name = "Leaf%s" % ("North" if side < 0 else "South")
		hinge.position = Vector3(0, floor_y, side * w / 2.0)
		_add(holder, hinge)
		var dz: float = -side   # from the hinge toward the middle
		var half := w / 2.0 - 0.02
		_add_visual_box(hinge, "Leaf", Vector3(0, h / 2.0 - 0.01, dz * half / 2.0), Vector3(0.05, h - 0.04, half), "wood" if wood else "door_steel")
		if wood:
			_add_visual_box(hinge, "Glass", Vector3(0, 1.75, dz * half / 2.0), Vector3(0.056, 0.6, half - 0.3), "window")
			for y in [0.45, 1.05]:
				_add_visual_box(hinge, "Panel%d" % int(y * 100), Vector3(0, y, dz * half / 2.0), Vector3(0.058, 0.45, half - 0.3), "wood_dark")
			_add_visual_box(hinge, "Kick", Vector3(0, 0.1, dz * half / 2.0), Vector3(0.06, 0.15, half - 0.06), "brass")
			_add_visual_box(hinge, "Handle", Vector3(-0.06, 1.05, dz * (half - 0.12)), Vector3(0.04, 0.16, 0.035), "brass")
		else:
			_add_visual_box(hinge, "Glass", Vector3(0, 1.65, dz * half * 0.55), Vector3(0.06, 0.55, 0.28), "wired_glass")
			for y in [1.5, 1.65, 1.8]:
				_add_visual_box(hinge, "Wire%d" % int(y * 100), Vector3(0, y, dz * half * 0.55), Vector3(0.062, 0.006, 0.28), "keypad_bezel")
			_add_visual_box(hinge, "Kick", Vector3(0, 0.15, dz * half / 2.0), Vector3(0.06, 0.25, half - 0.06), "conduit")
			_add_visual_box(hinge, "Handle", Vector3(-0.06, 1.05, dz * (half - 0.15)), Vector3(0.04, 0.035, 0.3), "keypad_bezel")
		for y in [0.3, 1.3, 2.3]:
			_add_visual_box(hinge, "Knuckle%d" % int(y * 10), Vector3(0, y, 0.02 * dz), Vector3(0.07, 0.12, 0.04), "brass" if wood else "keypad_bezel")
		if wood:
			if side < 0:
				_add_visual_box(hinge, "StaffPlate", Vector3(-0.03, 1.32, dz * half / 2.0), Vector3(0.005, 0.1, 0.4), "brass")
				_add_text(hinge, "StaffText", Vector3(-0.034, 1.32, dz * half / 2.0), "STAFF ONLY", 26, 0.0018, Color(0.12, 0.08, 0.03), -90.0)
		elif side < 0:   # the DANGER plate on the near side of the north leaf
			_add_visual_box(hinge, "DangerPlate", Vector3(-0.03, 2.15, dz * half / 2.0), Vector3(0.005, 0.3, 0.62), "sticker_yellow")
			_add_text(hinge, "DangerText", Vector3(-0.034, 2.15, dz * half / 2.0), "DANGER · HIGH VOLTAGE\nAUTHORISED STAFF ONLY", 22, 0.0018, Color(0.06, 0.06, 0.06), -90.0)
		else:
			var sticker := MeshInstance3D.new()
			sticker.name = "Warning"
			var tri := PrismMesh.new()
			tri.size = Vector3(0.24, 0.21, 0.004)
			sticker.mesh = tri
			sticker.material_override = _look("sticker_yellow")
			sticker.position = Vector3(-0.03, 2.15, dz * half / 2.0)
			sticker.rotation_degrees = Vector3(0, -90, 0)
			_add(hinge, sticker)
			_add_text(hinge, "WarningMark", Vector3(-0.034, 2.13, dz * half / 2.0), "!", 64, 0.0026, Color(0.05, 0.05, 0.05), -90.0)
		leaves.append(holder.get_path_to(hinge))
		angles.append(90.0 if side < 0 else -90.0)
	var frame := _group(holder, "Frame")
	var frame_look := "wood_dark" if wood else "keypad_bezel"
	for side in [-1.0, 1.0]:
		_add_visual_box(frame, "Jamb%s" % ("N" if side < 0 else "S"), Vector3(0, floor_y + (h + 0.06) / 2.0, side * (w / 2.0 + 0.03)), Vector3(0.36, h + 0.06, 0.06), frame_look)
	_add_visual_box(frame, "Head", Vector3(0, floor_y + h + 0.04, 0), Vector3(0.36, 0.08, w + 0.12), frame_look)
	# The light strip over the door and the card reader's LED (AccessDoor colours both).
	var strip := MeshInstance3D.new()
	strip.name = "StatusStrip"
	strip.mesh = _box_mesh(Vector3(0.03, 0.04, w - 0.4))
	strip.position = Vector3(-0.19, floor_y + h + 0.15, 0)
	_add(holder, strip)
	var reader := _group(holder, "CardReader")
	reader.position = Vector3(-0.17, floor_y + 1.25, -(w / 2.0 + 0.45))
	_add_visual_box(reader, "Box", Vector3.ZERO, Vector3(0.04, 0.17, 0.1), "keypad_bezel")
	_add_visual_box(reader, "Pad", Vector3(-0.021, -0.02, 0), Vector3(0.004, 0.07, 0.07), "screen_dark")
	var led := MeshInstance3D.new()
	led.name = "Led"
	led.mesh = _box_mesh(Vector3(0.008, 0.022, 0.022))
	led.position = Vector3(-0.022, 0.06, 0)
	_add(reader, led)
	_add_text(reader, "Label", Vector3(-0.024, -0.075, 0), "STAFF CARD", 12, 0.0012, Color(0.9, 0.9, 0.88), -90.0)
	var lights: Array[NodePath] = [holder.get_path_to(strip), holder.get_path_to(led)]
	return {"leaves": leaves, "angles": angles, "lights": lights}


# --- Lobby and reading hall (polish) ----------------------------------------------------------

## The main entrance (opening x −2…2 in the wall z 28, 2.6 m high; the lobby face z 27.85).
const ENTRANCE_FACE := 27.85
const ENTRANCE_BOX_Y := 2.95


## The main entrance: open bronze glass doors (swung back onto the porch), a frame, the
## LOCKDOWN light box, and the security grille (returned; ExitDoor rolls it up while the
## exit is open and drops it for the lockdown). Visual only: the exit's panel is the collision.
func _dress_main_entrance(parent: Node3D) -> Node3D:
	var g := _group(parent, "MainEntranceDressing")
	var out := 28.15   # the porch face
	for side in [-1.0, 1.0]:
		var leaf := Node3D.new()
		leaf.name = "Door%s" % ("West" if side < 0 else "East")
		leaf.position = Vector3(side * 1.97, 0, out + 0.5)
		_add(g, leaf)
		_add_visual_box(leaf, "Frame", Vector3(0, 1.25, 0), Vector3(0.06, 2.5, 0.98), "bronze")
		_add_visual_box(leaf, "Glass", Vector3(0, 1.4, 0), Vector3(0.065, 1.9, 0.78), "glass_door")
		_add_visual_box(leaf, "Bar", Vector3(-side * 0.05, 1.05, -0.05), Vector3(0.03, 0.03, 0.7), "brass")
		for e in [-1.0, 1.0]:
			_add_visual_box(leaf, "Kick%d" % int(e), Vector3(e * 0.0325, 0.15, 0), Vector3(0.004, 0.24, 0.9), "brass")
	for side in [-1.0, 1.0]:
		_add_visual_box(g, "Jamb%s" % ("W" if side < 0 else "E"), Vector3(side * 2.04, 1.33, ENTRANCE_FACE - 0.02), Vector3(0.08, 2.66, 0.06), "bronze")
	_add_visual_box(g, "Head", Vector3(0, 2.64, ENTRANCE_FACE - 0.02), Vector3(4.16, 0.08, 0.06), "bronze")
	_add_visual_box(g, "LightBox", Vector3(0, ENTRANCE_BOX_Y, ENTRANCE_FACE - 0.04), Vector3(2.4, 0.3, 0.08), "sign_board")
	var grille := Node3D.new()
	grille.name = "EntranceGrille"
	grille.position = Vector3(0, 0, 28.0)
	_add(g, grille)
	var rows := 13
	for i in rows:
		var row := Node3D.new()
		row.name = "Row%02d" % i
		row.position = Vector3(0, 0.05 + i * 0.2, 0)
		_add(grille, row)
		_add_visual_box(row, "Rod", Vector3.ZERO, Vector3(4.0, 0.03 if i > 0 else 0.08, 0.03), "grille_steel")
		for k in 5:
			var x := -1.6 + k * 0.8 + (0.4 if i % 2 == 1 else 0.0)
			if absf(x) < 1.95:
				_add_visual_box(row, "Link%d" % k, Vector3(x, 0.1, 0), Vector3(0.025, 0.2, 0.02), "grille_steel")
	for side in [-1.0, 1.0]:
		_add_visual_box(g, "GrilleGuide%s" % ("W" if side < 0 else "E"), Vector3(side * 1.98, 1.3, 28.0), Vector3(0.05, 2.6, 0.1), "keypad_bezel")
	return grille


## The lobby (no new collision): the circulation desk's front panels, ledge, second PC,
## returns slot, stamp and hanging sign; the S1 stair's brass nosing and the panelling and
## cupboard under its open side; the G4 staff door's wooden leaves, frame and reader (the
## level's door points at them, fixes_x10.gd); a library map, noticeboard, plants, mat, banner.
func _build_lobby(decor: Node3D) -> void:
	# Circulation desk (x 1…7, z 15.4…16.6, top 1.12; the public face is north, z 15.4).
	var d := Node3D.new()
	d.name = "CirculationDesk"
	d.position = Vector3(4.0, 0, 16.0)
	_add(decor, d)
	for i in 5:
		_add_visual_box(d, "FrontPanel%d" % i, Vector3(-2.4 + i * 1.2, 0.55, -0.61), Vector3(1.0, 0.72, 0.02), "oak")
		_add_visual_box(d, "PanelInset%d" % i, Vector3(-2.4 + i * 1.2, 0.55, -0.622), Vector3(0.8, 0.52, 0.004), "oak_dark")
	# Oak legs between the panels and at the ends, as the library tables'.
	for i in 6:
		_add_visual_box(d, "Leg%d" % i, Vector3(-3.0 + i * 1.2, 0.55, -0.615), Vector3(0.09, 1.1, 0.04), "oak_dark")
	_add_visual_box(d, "KickStrip", Vector3(0, 0.06, -0.61), Vector3(6.0, 0.1, 0.022), "oak_dark")
	_add_visual_box(d, "TopApron", Vector3(0, 1.0, -0.612), Vector3(6.0, 0.08, 0.026), "oak_dark")
	_add_visual_box(d, "Ledge", Vector3(0, 1.21, -0.48), Vector3(6.1, 0.18, 0.28), "oak")
	_add_visual_box(d, "ReturnsSlot", Vector3(2.4, 1.21, -0.625), Vector3(0.45, 0.05, 0.012), "screen_dark")
	_add_text(d, "ReturnsText", Vector3(2.4, 1.27, -0.627), "RETURNS", 18, 0.0018, Color(0.95, 0.92, 0.8), 180.0)
	_add_visual_box(d, "Monitor2Foot", Vector3(1.6, 1.13, -0.15), Vector3(0.2, 0.02, 0.16), "keypad_bezel")
	_add_visual_box(d, "Monitor2", Vector3(1.6, 1.3, -0.2), Vector3(0.5, 0.32, 0.04), "keypad_bezel")
	_add_visual_box(d, "Monitor2Screen", Vector3(1.6, 1.3, -0.178), Vector3(0.46, 0.28, 0.004), "screen_lit")
	_add_visual_box(d, "Keyboard2", Vector3(1.6, 1.13, 0.25), Vector3(0.44, 0.02, 0.15), "wire_black")
	_add_visual_box(d, "Stamp", Vector3(-0.7, 1.16, 0.2), Vector3(0.06, 0.08, 0.06), "pipe_red")
	_add_visual_box(d, "InkPad", Vector3(-0.55, 1.13, 0.2), Vector3(0.1, 0.02, 0.07), "wire_black")
	# S1 stair: brass nosing (the level's strips, hidden by fixes_x10.gd) and the open (east)
	# side's panelling and cupboard under it.
	# S1 in oak like S3, with a red runner (its ramp and handrail bodies unchanged; the old
	# balustrade boxes are removed by fixes_x14.gd).
	_dress_oak_stair(decor, "S1Stair", -11.85, -8.85, true)
	var face := -8.8 + 0.012
	_add_visual_box(decor, "S1CupboardDoor", Vector3(face, 1.0, 13.6), Vector3(0.016, 1.9, 0.95), "wood_dark")
	_add_visual_box(decor, "S1CupboardFrame", Vector3(face - 0.004, 1.0, 13.6), Vector3(0.008, 2.0, 1.07), "trim")
	_add_visual_box(decor, "S1CupboardKnob", Vector3(face + 0.02, 1.0, 13.95), Vector3(0.03, 0.04, 0.04), "brass")
	_add_visual_box(decor, "S1CupboardPlate", Vector3(face + 0.01, 1.6, 13.6), Vector3(0.006, 0.07, 0.24), "brass")
	_add_text(decor, "S1CupboardText", Vector3(face + 0.014, 1.6, 13.6), "STORE", 20, 0.0016, Color(0.12, 0.08, 0.03), 90.0)
	# G4 staff door (east wall x 12, z 20…22): wooden leaves swinging into the service corridor.
	var g4 := Node3D.new()
	g4.name = "LobbyStaffDoorDressing"
	g4.position = Vector3(12.0, 1.2, 21.0)
	_add(_root.get_node("Gameplay"), g4)
	_door_leaves(g4, 2.0, "wood")
	# Plants in the two planters and the entrance mat (the wall decor was removed by request).
	for pl in [[Vector3(-6.0, 1.0, 13.5)], [Vector3(6.0, 1.0, 25.5)]]:
		var base: Vector3 = pl[0]
		_add_visual_cyl(decor, "PlantTrunk%d" % int(base.x), base + Vector3(0, 0.45, 0), 0.04, 0.9, "y", "wood_dark", 8)
		for k in 4:
			var off := Vector3([-0.25, 0.25, 0.0, 0.1][k], 0.85 + k * 0.22, [0.1, -0.1, 0.0, 0.15][k])
			_add_visual_box(decor, "Foliage%d_%d" % [int(base.x), k], base + off, Vector3(0.55 - k * 0.08, 0.3, 0.45 - k * 0.06), "foliage" if k % 2 == 0 else "foliage_light")
	_add_visual_box(decor, "EntranceMat", Vector3(0, 0.006, 26.95), Vector3(3.6, 0.012, 1.4), "wire_black")
	_add_visual_box(decor, "EntranceMatBorder", Vector3(0, 0.005, 26.95), Vector3(3.8, 0.01, 1.6), "rug_red")


## A stair's nosing redrawn in `look`: the level's strips (hidden by a fixes_x*.gd) as a
## BatchedBoxes called "Nosing" with the same boxes and world transform.
func _add_stair_nosing(parent: Node3D, path: String, look: String) -> void:
	var level: Node = (load("res://maps/library/scenes/expanded_library.tscn") as PackedScene).instantiate()
	var src := level.get_node(path) as Node3D
	var xf := Transform3D.IDENTITY
	var n: Node = src
	while n and n != level:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	var nosing := MultiMeshInstance3D.new()
	nosing.name = "Nosing"
	nosing.set_script(src.get_script())   # BatchedBoxes
	nosing.transform = xf
	nosing.material_override = _look(look)
	nosing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nosing.set_meta("render_layers", (src as GeometryInstance3D).layers)
	_add(parent, nosing)
	nosing.set("boxes", src.get("boxes"))
	level.free()


## The reading hall (x −12…12, z −14…10): banker's lamps and books on the six tables, the
## NEW BOOKS display on the centre bookcase, solid wall bookcases between the doorways
## (0.45 m deep, clear of the openings), a newspaper rack and a globe (solid), QUIET signs
## and pictures above the bookcases.
const HALL_TABLES := [Vector3(-6, 0.82, -9), Vector3(-6, 0.82, -3), Vector3(-6, 0.82, 3), Vector3(6, 0.82, -9), Vector3(6, 0.82, -3), Vector3(6, 0.82, 3)]
const HALL_BOOKCASES := [
	["West0", [-11.85, -13.4, -11.4, -4.7]], ["West1", [-11.85, 0.7, -11.4, 9.4]],
	["East0", [11.4, -13.4, 11.85, 1.8]], ["East1", [11.4, 6.2, 11.85, 9.4]],
	["North0", [-7.6, -13.85, -4.4, -13.4]], ["North1", [-1.6, -13.85, 1.6, -13.4]], ["North2", [4.4, -13.85, 7.6, -13.4]],
	["South0", [-11.4, 9.4, -3.2, 9.85]], ["South1", [4.4, 9.4, 11.4, 9.85]],
]


func _build_reading_hall(solid: Node3D, decor: Node3D) -> void:
	var book_looks := ["pipe_red", "motor_blue", "cabinet_green", "rack_orange", "keypad_bezel", "cardboard", "wood_dark", "rug_teal"]
	var k := 0
	for t in HALL_TABLES:
		var g := Node3D.new()
		g.name = "HallTable%d" % k
		g.position = t
		_add(decor, g)
		_add_visual_cyl(g, "LampBase", Vector3(-0.9, 0.012, -0.3), 0.08, 0.024, "y", "brass", 12)
		_add_visual_box(g, "LampStem", Vector3(-0.9, 0.17, -0.3), Vector3(0.02, 0.3, 0.02), "brass")
		_add_visual_box(g, "LampShade", Vector3(-0.9, 0.34, -0.26), Vector3(0.34, 0.08, 0.15), "lamp_green")
		_add_visual_box(g, "LampGlow", Vector3(-0.9, 0.298, -0.26), Vector3(0.3, 0.004, 0.11), "glow_sodium")
		_add_visual_box(g, "BookLeft", Vector3(0.0, 0.012, 0.3), Vector3(0.16, 0.015, 0.22), "paper")
		_add_visual_box(g, "BookRight", Vector3(0.17, 0.012, 0.3), Vector3(0.16, 0.015, 0.22), "paper")
		_add_visual_box(g, "BookCover", Vector3(0.085, 0.004, 0.3), Vector3(0.36, 0.008, 0.24), book_looks[k % book_looks.size()])
		_add_visual_box(g, "Notebook", Vector3(-0.35, 0.008, 0.35), Vector3(0.18, 0.012, 0.24), "motor_blue" if k % 2 == 0 else "pipe_red")
		_add_visual_box(g, "Pencil", Vector3(-0.2, 0.006, 0.38), Vector3(0.015, 0.012, 0.16), "sticker_yellow")
		k += 1
	# The centre bookcase (x −2.5…2.5, z ±0.3, top 1.3): NEW BOOKS sign and two display stands.
	_add_visual_box(decor, "NewBooksSign", Vector3(0, 1.45, 0), Vector3(1.2, 0.26, 0.04), "sign_board")
	_add_text(decor, "NewBooksTextS", Vector3(0, 1.45, 0.025), "NEW BOOKS", 36, 0.0034, Color(0.95, 0.93, 0.85))
	_add_text(decor, "NewBooksTextN", Vector3(0, 1.45, -0.025), "NEW BOOKS", 36, 0.0034, Color(0.95, 0.93, 0.85), 180.0)
	for x in [-1.7, 1.7]:
		for sd in [-1.0, 1.0]:
			_add_visual_box(decor, "Stand%d_%d" % [int(x * 10), int(sd)], Vector3(x, 1.315, sd * 0.12), Vector3(0.24, 0.03, 0.06), "brass")
			var book := MeshInstance3D.new()
			book.name = "FaceOut%d_%d" % [int(x * 10), int(sd)]
			book.mesh = _box_mesh(Vector3(0.2, 0.28, 0.03))
			book.material_override = _look(book_looks[(int(x) + int(sd) + 4) % book_looks.size()])
			book.position = Vector3(x, 1.45, sd * 0.13)
			book.rotation = Vector3(-sd * 0.25, 0, 0)
			_add(decor, book)
	# Wall bookcases (solid).
	var q := 0
	for bc in HALL_BOOKCASES:
		var r: Array = bc[1]
		var m := _solid_prop(solid, "WallBookcase" + bc[0], r, 2.6)
		var along_x: bool = (r[2] - r[0]) > (r[3] - r[1])
		var length: float = (r[2] - r[0]) if along_x else (r[3] - r[1])
		var depth: float = (r[3] - r[1]) if along_x else (r[2] - r[0])
		var bays := maxi(1, roundi(length / 1.0))
		var bay := length / bays
		for i in bays + 1:
			var tt := -length / 2.0 + i * bay
			_add_visual_box(m, "Side%d" % i, Vector3(tt, 1.3, 0) if along_x else Vector3(0, 1.3, tt), Vector3(0.04, 2.6, depth) if along_x else Vector3(depth, 2.6, 0.04), "wood")
		for y in [0.06, 0.5, 0.94, 1.38, 1.82, 2.26, 2.58]:
			_add_visual_box(m, "Shelf%d" % int(y * 100), Vector3(0, y, 0), Vector3(length, 0.03 if y < 2.5 else 0.05, depth) if along_x else Vector3(depth, 0.03 if y < 2.5 else 0.05, length), "wood_dark" if y > 2.5 else "wood")
		for level in 6:
			var y0: float = 0.075 + level * 0.44
			var books := int(length / 0.085)
			var i := 0
			while i < books:
				if (i * 3 + level + q) % 13 == 12:
					i += 2
					continue
				var hh := 0.26 + 0.035 * ((i * 7 + level) % 4)
				var tt := -length / 2.0 + 0.05 + i * 0.085
				var at := Vector3(tt, y0 + hh / 2.0, 0.02) if along_x else Vector3(0.02, y0 + hh / 2.0, tt)
				_add_visual_box(m, "B%d_%d" % [level, i], at, Vector3(0.075, hh, depth - 0.12) if along_x else Vector3(depth - 0.12, hh, 0.075), book_looks[(i * 5 + level * 3 + q) % book_looks.size()])
				i += 1
		q += 1
	var rack := _solid_prop(solid, "NewspaperRack", [3.2, 9.4, 4.2, 9.85], 1.2)
	_add_visual_box(rack, "Back", Vector3(0, 0.6, 0.18), Vector3(1.0, 1.2, 0.04), "wood")
	for y in [0.3, 0.65, 1.0]:
		_add_visual_box(rack, "Rail%d" % int(y * 100), Vector3(0, y, -0.05), Vector3(0.96, 0.03, 0.3), "wood_dark")
		for p in 3:
			_add_visual_box(rack, "Paper%d_%d" % [int(y * 100), p], Vector3(-0.3 + p * 0.3, y + 0.12, 0.0), Vector3(0.26, 0.22, 0.02), "paper")
	_add_text(rack, "Title", Vector3(0, 1.12, -0.03), "NEWSPAPERS", 20, 0.0018, Color(0.95, 0.92, 0.8), 180.0)
	var globe := _solid_prop(solid, "Globe", [-11.3, 8.8, -10.7, 9.4], 1.1)
	_add_visual_cyl(globe, "Foot", Vector3(0, 0.03, 0), 0.24, 0.06, "y", "wood_dark", 12)
	_add_visual_box(globe, "Leg", Vector3(0, 0.38, 0), Vector3(0.05, 0.7, 0.05), "wood_dark")
	_add_visual_cyl(globe, "Ball", Vector3(0, 0.85, 0), 0.24, 0.42, "y", "rug_teal", 16)
	_add_visual_cyl(globe, "Band", Vector3(0, 0.85, 0), 0.25, 0.04, "y", "cardboard", 16)
	_add_visual_box(globe, "Meridian", Vector3(0, 0.85, 0), Vector3(0.02, 0.56, 0.56), "brass")


## Book Processing (x 17–36, z −28…−6; no guard): workstations on the four tables, the
## noticeboard round the wiring chart, solid sorting shelves, a returns island, trolleys
## and a pallet, and wall details. The tables' collision is unchanged.
const PROCESSING_TABLES := [Vector3(22, 0.9, -22), Vector3(22, 0.9, -12), Vector3(29, 0.9, -22), Vector3(29, 0.9, -12)]


func _build_processing(solid: Node3D, decor: Node3D) -> void:
	var box_looks := ["archive_box", "cardboard", "archive_box", "cardboard_dark", "archive_box"]
	var book_looks := ["pipe_red", "motor_blue", "cabinet_green", "rack_orange", "keypad_bezel", "cardboard"]
	# Workstations: a PC, keyboard, scanner, label printer, tape and books (the tables'
	# own coloured blocks stay in the middle).
	var k := 0
	for t in PROCESSING_TABLES:
		var g := Node3D.new()
		g.name = "Workstation%d" % k
		g.position = t
		_add(decor, g)
		_add_visual_box(g, "MonitorFoot", Vector3(1.15, 0.01, -0.3), Vector3(0.2, 0.02, 0.16), "keypad_bezel")
		_add_visual_box(g, "MonitorNeck", Vector3(1.15, 0.12, -0.32), Vector3(0.04, 0.2, 0.03), "keypad_bezel")
		_add_visual_box(g, "Monitor", Vector3(1.15, 0.36, -0.3), Vector3(0.5, 0.32, 0.04), "keypad_bezel")
		_add_visual_box(g, "Screen", Vector3(1.15, 0.36, -0.278), Vector3(0.46, 0.28, 0.004), "screen_lit")
		_add_visual_box(g, "Keyboard", Vector3(1.1, 0.015, 0.2), Vector3(0.44, 0.02, 0.15), "wire_black")
		_add_visual_box(g, "Mouse", Vector3(1.42, 0.015, 0.22), Vector3(0.06, 0.02, 0.1), "wire_black")
		_add_visual_box(g, "ScannerBase", Vector3(-1.3, 0.02, 0.35), Vector3(0.12, 0.04, 0.12), "keypad_bezel")
		_add_visual_box(g, "Scanner", Vector3(-1.3, 0.12, 0.35), Vector3(0.07, 0.16, 0.09), "release_yellow")
		_add_visual_box(g, "Printer", Vector3(-1.25, 0.08, -0.35), Vector3(0.28, 0.16, 0.24), "panel_grey")
		_add_visual_box(g, "PrinterLabels", Vector3(-1.25, 0.08, -0.22), Vector3(0.12, 0.004, 0.04), "paper")
		_add_visual_box(g, "Tape", Vector3(0.35, 0.04, 0.42), Vector3(0.16, 0.08, 0.08), "pipe_red")
		for s in 2:   # stacks of books being processed
			var x: float = [-0.55, 0.15][s]
			var z: float = [0.4, -0.42][s]
			for b in 4 + s:
				_add_visual_box(g, "Stack%d_%d" % [s, b], Vector3(x + 0.01 * (b % 2), 0.025 + b * 0.05, z), Vector3(0.24, 0.045, 0.17), book_looks[(b + k + s) % book_looks.size()])
		k += 1
	# The noticeboard round the wiring chart (the chart keeps its place: (26, 1.4, −27.83)).
	var nb := Node3D.new()
	nb.name = "Noticeboard"
	nb.position = Vector3(25.55, 1.3, -27.85)   # between the wainscot rail and the window sill, left of the window
	_add(decor, nb)
	_add_visual_box(nb, "Cork", Vector3(0, 0, 0.004), Vector3(1.3, 0.48, 0.008), "cork")
	for y in [0.255, -0.255]:
		_add_visual_box(nb, "FrameH%d" % int(y * 100), Vector3(0, y, 0.008), Vector3(1.36, 0.03, 0.016), "wood_dark")
	for x in [-0.665, 0.665]:
		_add_visual_box(nb, "FrameV%d" % int(x * 100), Vector3(x, 0, 0.008), Vector3(0.03, 0.54, 0.016), "wood_dark")
	_add_text(nb, "Header", Vector3(-0.4, 0.19, 0.011), "STAFF NOTICES", 20, 0.0018, Color(0.12, 0.08, 0.04))
	var notes := [[-0.5, -0.03, 0.17, 0.24, "paper"], [-0.26, -0.06, 0.15, 0.2, "sticker_yellow"], [-0.04, -0.03, 0.17, 0.24, "paper"],
		[0.2, -0.12, 0.12, 0.14, "led_green"], [0.2, 0.08, 0.1, 0.1, "pipe_red"], [0.6, -0.15, 0.08, 0.1, "paper"]]
	for i in notes.size():
		var n: Array = notes[i]
		_add_visual_box(nb, "Note%d" % i, Vector3(n[0], n[1], 0.0095), Vector3(n[2], n[3], 0.002), n[4])
		_add_visual_box(nb, "Pin%d" % i, Vector3(n[0], n[1] + n[3] / 2.0 - 0.02, 0.012), Vector3(0.012, 0.012, 0.006), "pipe_red")
	# Solid props: sorting shelves on two walls, a returns island, two trolleys, a pallet.
	var walls := [["SortingShelfWest", [17.15, -27.5, 17.75, -19.5], "z"], ["SortingShelfSouth", [17.6, -6.75, 23.6, -6.15], "x"]]
	var q := 0
	for wdef in walls:
		var r: Array = wdef[1]
		var m := _solid_prop(solid, wdef[0], r, 2.0)
		var along_x: bool = wdef[2] == "x"
		var length: float = (r[2] - r[0]) if along_x else (r[3] - r[1])
		var depth: float = (r[3] - r[1]) if along_x else (r[2] - r[0])
		var bays := maxi(1, roundi(length / 1.0))
		var bay := length / bays
		for i in bays + 1:
			var tt := -length / 2.0 + i * bay
			var at := Vector3(tt, 1.0, 0) if along_x else Vector3(0, 1.0, tt)
			_add_visual_box(m, "Side%d" % i, at, Vector3(0.03, 2.0, depth) if along_x else Vector3(depth, 2.0, 0.03), "wood")
		for y in [0.05, 0.5, 0.95, 1.4, 1.98]:
			_add_visual_box(m, "Shelf%d" % int(y * 100), Vector3(0, y, 0), Vector3(length, 0.03, depth) if along_x else Vector3(depth, 0.03, length), "wood")
		for level in 4:
			var y0: float = [0.065, 0.515, 0.965, 1.415][level]
			var books := int(length / 0.07)
			var i := 0
			while i < books:
				if (i + level + q) % 9 == 8:   # a gap, a box now and then
					i += 2
					continue
				var hh := 0.24 + 0.04 * ((i + level) % 4)
				var tt := -length / 2.0 + 0.04 + i * 0.07
				var at := Vector3(tt, y0 + hh / 2.0, 0.02) if along_x else Vector3(0.02, y0 + hh / 2.0, tt)
				_add_visual_box(m, "Book%d_%d" % [level, i], at, Vector3(0.06, hh, depth - 0.12) if along_x else Vector3(depth - 0.12, hh, 0.06), book_looks[(i * 7 + level + q) % book_looks.size()])
				i += 1
		q += 1
	# The returns island: double-sided pigeonholes with letter labels.
	var isl := _solid_prop(solid, "ReturnsIsland", [25.4, -18.6, 26.1, -15.4], 1.3)
	_add_visual_box(isl, "Divider", Vector3(0, 0.65, 0), Vector3(0.04, 1.28, 3.2), "wood_dark")
	for z in [-1.6, -0.8, 0.0, 0.8, 1.6]:
		_add_visual_box(isl, "Upright%d" % int(z * 10), Vector3(0, 0.65, clampf(z, -1.585, 1.585)), Vector3(0.7, 1.28, 0.03), "wood")
	for y in [0.04, 0.45, 0.86]:
		_add_visual_box(isl, "Board%d" % int(y * 100), Vector3(0, y, 0), Vector3(0.7, 0.03, 3.2), "wood")
	var letters := "ABCDEFGHIJKLMNOPQRSTUVWX"
	var li := 0
	for side in [-1.0, 1.0]:
		for row in 3:
			for col in 4:
				var z := -1.2 + col * 0.8
				var y: float = [0.055, 0.465, 0.875][row]
				for b in 9:
					var hh := 0.22 + 0.03 * ((b + row + col) % 3)
					_add_visual_box(isl, "R%d_%d_%d_%d" % [int(side), row, col, b], Vector3(side * 0.19, y + hh / 2.0, z - 0.33 + b * 0.075), Vector3(0.24, hh, 0.065), book_looks[(b * 5 + row + col) % book_looks.size()])
				_add_text(isl, "L%d_%d_%d" % [int(side), row, col], Vector3(side * 0.352, y + 0.0, z), letters[li % letters.length()], 24, 0.002, Color(0.95, 0.92, 0.8), 90.0 * side)
				li += 1
	_add_visual_box(isl, "Top", Vector3(0, 1.29, 0), Vector3(0.72, 0.03, 3.22), "desk_top")
	_add_text(isl, "SignW", Vector3(-0.356, 1.2, 0), "RETURNS · SORT A–X", 24, 0.002, Color(0.95, 0.92, 0.8), -90.0)
	_add_text(isl, "SignE", Vector3(0.356, 1.2, 0), "RETURNS · SORT A–X", 24, 0.002, Color(0.95, 0.92, 0.8), 90.0)
	for tdef in [["BookTrolleyWest", [18.6, -13.0, 19.1, -12.0]], ["BookTrolleyEast", [32.0, -22.5, 32.5, -21.5]]]:
		var r: Array = tdef[1]
		var m := _solid_prop(solid, tdef[0], r, 1.0)
		for y in [0.2, 0.6, 0.98]:
			_add_visual_box(m, "Deck%d" % int(y * 100), Vector3(0, y, 0), Vector3(0.46, 0.03, 0.96), "keypad_bezel")
		for z in [-0.47, 0.47]:
			_add_visual_box(m, "End%d" % int(z * 100), Vector3(0, 0.55, z), Vector3(0.46, 0.9, 0.03), "rack_blue")
			_add_visual_cyl(m, "Wheel%d" % int(z * 100), Vector3(0, 0.06, z), 0.06, 0.03, "x", "wire_black", 8)
		for lvl in 2:
			for i in 13:
				var hh := 0.22 + 0.03 * ((i + lvl) % 3)
				_add_visual_box(m, "Book%d_%d" % [lvl, i], Vector3(0, [0.215, 0.615][lvl] + hh / 2.0, -0.42 + i * 0.065), Vector3(0.34, hh, 0.06), book_looks[(i + lvl + 2) % book_looks.size()])
	var pal := _solid_prop(solid, "NewArrivalsPallet", [29.0, -8.0, 30.2, -6.8], 1.2)
	_pallet(pal, "Pallet", Vector3.ZERO, Vector3(1.2, 0.14, 1.2))
	var n := 0
	for layer in 2:
		for ix in 2:
			for iz in 2:
				_add_visual_box(pal, "Box%d" % n, Vector3(-0.3 + ix * 0.6, 0.14 + 0.26 + layer * 0.52, -0.3 + iz * 0.6), Vector3(0.58, 0.51, 0.58), box_looks[(n + 1) % box_looks.size()])
				n += 1
	_add_text(pal, "Label", Vector3(0, 0.66, 0.601), "NEW ARRIVALS", 22, 0.002, Color(0.15, 0.1, 0.05))
	# The fire extinguisher by the electrical door (the clock, posters and signs were removed by request).
	_add_visual_box(decor, "ExtinguisherBracket", Vector3(35.83, 0.75, -25.2), Vector3(0.03, 0.08, 0.12), "keypad_bezel")
	_add_visual_cyl(decor, "Extinguisher", Vector3(35.74, 0.6, -25.2), 0.08, 0.5, "y", "pipe_red", 14)
	_add_visual_box(decor, "ExtinguisherHead", Vector3(35.74, 0.9, -25.2), Vector3(0.06, 0.1, 0.06), "wire_black")


# --- Storage room (polish) --------------------------------------------------------------------

## The four racks (the level's Rack57–60 colliders, 2 × 2 × 2 m) and their aisle tags.
const STORAGE_RACKS := [[21.0, -1.0, "A1"], [27.0, -1.0, "A2"], [21.0, 7.0, "A3"], [27.0, 7.0, "A4"]]
## The S2 staff stair: its open (west) side x, foot z (floor) and top z (upper floor), rise.
const S2_X := 32.85
const S2_FOOT := 4.0
const S2_TOP := -6.0
const S2_RISE := 4.5


## The storage room: double-sided steel shelving on the racks (inside their colliders),
## the S2 stair's yellow nosing, handrail, cage and sign, solid wall shelving, aisle
## signs, walkway lines, a book trolley, a step ladder. fixes_x9.gd removed the racks'
## old look and recoloured the stair in the level's scene.
func _build_storage(solid: Node3D, decor: Node3D) -> void:
	var box_looks := ["archive_box", "cardboard", "archive_box", "cardboard_dark", "archive_box"]
	var book_looks := ["pipe_red", "motor_blue", "cabinet_green", "rack_orange", "keypad_bezel", "cardboard"]
	for r in STORAGE_RACKS:
		var g := Node3D.new()
		g.name = "Shelving" + r[2]
		g.position = Vector3(r[0], 0, r[1])
		_add(decor, g)
		for x in [-0.95, 0.95]:
			for z in [-0.95, 0.0, 0.95]:
				_add_visual_box(g, "Upright%d_%d" % [int(x * 100), int(z * 100)], Vector3(x, 1.0, z), Vector3(0.07, 1.99, 0.07), "rack_blue")
		for y in [0.1, 0.72, 1.34, 1.96]:
			for x in [-0.95, 0.95]:
				_add_visual_box(g, "Beam%d_%d" % [int(y * 100), int(x * 100)], Vector3(x, y, 0), Vector3(0.06, 0.07, 1.96), "rack_orange")
		_add_visual_box(g, "BackPanel", Vector3(0, 1.0, 0), Vector3(0.02, 1.96, 1.9), "mesh_grey")
		var k := 0
		for side in [-1.0, 1.0]:
			for level in 3:
				var y0: float = [0.14, 0.76, 1.38][level]
				_add_visual_box(g, "Deck%d_%d" % [int(side), level], Vector3(side * 0.5, y0 - 0.015, 0), Vector3(0.9, 0.03, 1.86), "shutter_groove")
				var z := -0.88
				var n := 0
				while z < 0.8:
					var w := 0.36 + 0.08 * ((k + n) % 3)
					if (k + n + level) % 4 == 3:   # a row of books
						var bw := minf(w, 0.86 - z) if z + w > 0.86 else w
						for b in int(bw / 0.06):
							var h := 0.24 + 0.03 * ((b + level) % 3)
							_add_visual_box(g, "Book%d_%d" % [k, b], Vector3(side * 0.55, y0 + h / 2.0, z + 0.03 + b * 0.06), Vector3(0.7, h, 0.055), book_looks[(b + k) % book_looks.size()])
					else:
						var h := 0.32 + 0.08 * ((k + n + level) % 3)
						var bw := minf(w, 0.86 - z)
						_add_visual_box(g, "Box%d" % k, Vector3(side * 0.52, y0 + h / 2.0, z + bw / 2.0), Vector3(0.78, h, bw - 0.03), box_looks[(k + level) % box_looks.size()])
					z += w + 0.04
					n += 1
					k += 1
		for end in [-1.0, 1.0]:
			_add_visual_box(g, "TagPlate%d" % int(end), Vector3(0, 1.72, end * 0.98), Vector3(0.5, 0.22, 0.02), "release_yellow")
			_add_text(g, "Tag%d" % int(end), Vector3(0, 1.72, end * 0.992), r[2], 64, 0.0028, Color(0.06, 0.06, 0.06), 0.0 if end > 0 else 180.0)
	# The S2 stair: yellow nosing where the level's cream one was (a BatchedBoxes named
	# "Nosing": flush on the ramp, like the level's), the handrail along the open side,
	# the storage cage under it and the sign at the foot.
	_add_s2_nosing(decor)
	var cage := Node3D.new()
	cage.name = "S2Cage"
	_add(decor, cage)
	var face := S2_X - 0.06
	for i in 7:   # 1 m bays from z 1 down to the top, each as high as its step
		var z1 := 1.0 - i
		var top := 1.0 + 0.45 * i
		var zc := z1 - 0.5
		_add_visual_box(cage, "Post%d" % i, Vector3(face, top / 2.0, z1 - 0.02), Vector3(0.03, top, 0.04), "keypad_bezel")
		for y in range(1, int(top / 0.25)):
			_add_visual_box(cage, "Bar%d_%d" % [i, y], Vector3(face, y * 0.25, zc), Vector3(0.012, 0.012, 0.96), "conduit")
		for v in 4:
			_add_visual_box(cage, "Rod%d_%d" % [i, v], Vector3(face, top / 2.0, z1 - 0.2 - v * 0.2), Vector3(0.012, top, 0.012), "conduit")
		# Boxes stored behind the mesh (flat on the dark backing).
		for j in mini(int(top / 0.45), 4):
			_add_visual_box(cage, "Stored%d_%d" % [i, j], Vector3(face + 0.025, 0.22 + j * 0.42, zc + (0.12 if j % 2 == 0 else -0.1)), Vector3(0.008, 0.36, 0.5), box_looks[(i + j) % box_looks.size()])
	_add_visual_box(cage, "CageDoorFrame", Vector3(face - 0.005, 0.95, -1.5), Vector3(0.02, 1.9, 0.9), "rack_blue")
	_add_visual_box(cage, "CagePadlock", Vector3(face - 0.03, 1.0, -1.08), Vector3(0.03, 0.07, 0.05), "brass")
	# Solid wall shelving (archive boxes), against the walls only.
	var walls := [
		["WallShelfNorth", [17.4, -5.85, 24.4, -5.25], "x"],
		["WallShelfWest", [17.15, 4.5, 17.75, 11.4], "z"],
		["WallShelfSouth", [24.5, 11.25, 29.5, 11.85], "x"],
	]
	var q := 0
	for w in walls:
		var r: Array = w[1]
		var m := _solid_prop(solid, w[0], r, 2.2)
		var along_x: bool = w[2] == "x"
		var length: float = (r[2] - r[0]) if along_x else (r[3] - r[1])
		var depth: float = (r[3] - r[1]) if along_x else (r[2] - r[0])
		var bays := maxi(1, roundi(length / 1.2))
		var bay := length / bays
		for i in bays + 1:
			var t := -length / 2.0 + i * bay
			for d in [-depth / 2.0 + 0.04, depth / 2.0 - 0.04]:
				var at := Vector3(t, 1.1, d) if along_x else Vector3(d, 1.1, t)
				_add_visual_box(m, "Upright%d_%d" % [i, int(d * 100)], at, Vector3(0.05, 2.2, 0.05), "rack_blue")
		for y in [0.08, 0.62, 1.16, 1.7, 2.17]:
			var sz := Vector3(length, 0.03, depth - 0.04) if along_x else Vector3(depth - 0.04, 0.03, length)
			_add_visual_box(m, "Shelf%d" % int(y * 100), Vector3(0, y, 0), sz, "shutter_groove")
		for level in 4:
			var y0: float = [0.095, 0.635, 1.175, 1.715][level]
			for i in bays * 3:
				var t := -length / 2.0 + (i + 0.5) * bay / 3.0
				var h := 0.3 + 0.06 * ((i + level + q) % 3)
				var at := Vector3(t, y0 + h / 2.0, 0.02) if along_x else Vector3(0.02, y0 + h / 2.0, t)
				var sz := Vector3(bay / 3.0 - 0.05, h, depth - 0.12) if along_x else Vector3(depth - 0.12, h, bay / 3.0 - 0.05)
				_add_visual_box(m, "Box%d_%d" % [level, i], at, sz, box_looks[(i + level + q) % box_looks.size()])
		q += 1
	# The walkway lines, a trolley and a ladder.
	for z in [0.3, 5.7]:   # the cross aisle (west door ↔ stair foot)
		_add_visual_box(decor, "WalkLine%d" % int(z * 10), Vector3(24.85, 0.005, z), Vector3(15.1, 0.01, 0.08), "hazard_yellow")
	for x in [22.3, 25.7]:   # from the dock door to the cross aisle
		_add_visual_box(decor, "WalkLineS%d" % int(x * 10), Vector3(x, 0.005, 8.75), Vector3(0.08, 0.01, 6.1), "hazard_yellow")
	# Book trolley against the east wall (south of the stair foot): solid, small.
	var t := _solid_prop(solid, "BookTrolley", [35.4, 9.5, 35.85, 10.5], 1.0)
	_add_visual_box(t, "Base", Vector3(0, 0.2, 0), Vector3(0.4, 0.03, 0.9), "keypad_bezel")
	_add_visual_box(t, "Shelf", Vector3(0, 0.6, 0), Vector3(0.4, 0.03, 0.9), "keypad_bezel")
	_add_visual_box(t, "Top", Vector3(0, 0.98, 0), Vector3(0.4, 0.03, 0.9), "keypad_bezel")
	for z in [-0.43, 0.43]:
		_add_visual_box(t, "End%d" % int(z * 100), Vector3(0, 0.55, z), Vector3(0.4, 0.9, 0.03), "rack_blue")
		_add_visual_cyl(t, "Wheel%d" % int(z * 100), Vector3(0, 0.06, z), 0.06, 0.03, "x", "wire_black", 8)
	for lvl in 2:
		for i in 12:
			var h := 0.22 + 0.03 * ((i + lvl) % 3)
			_add_visual_box(t, "Book%d_%d" % [lvl, i], Vector3(0, [0.215, 0.615][lvl] + h / 2.0, -0.38 + i * 0.065), Vector3(0.3, h, 0.06), book_looks[(i + lvl) % book_looks.size()])
	# A folded step ladder leaning on the north wall, east of the processing door.
	var lad := Node3D.new()
	lad.name = "StepLadder"
	lad.position = Vector3(30.2, 0, -5.72)
	lad.rotation = Vector3(-0.06, 0, 0)
	_add(decor, lad)
	for x in [-0.22, 0.22]:
		_add_visual_box(lad, "Stile%d" % int(x * 100), Vector3(x, 0.9, 0), Vector3(0.05, 1.8, 0.06), "conduit")
	for i in 5:
		_add_visual_box(lad, "Step%d" % i, Vector3(0, 0.3 + i * 0.33, 0.01), Vector3(0.44, 0.03, 0.1), "keypad_bezel")


## The S2 stair's nosing, yellow: the level's own strips (Ramp/Nosing, hidden by fixes_x9.gd)
## re-drawn as a BatchedBoxes called "Nosing" with the same boxes and world transform.
func _add_s2_nosing(parent: Node3D) -> void:
	var level: Node = (load("res://maps/library/scenes/expanded_library.tscn") as PackedScene).instantiate()
	var src := level.get_node("NavigationRegion3D/Stairs/S2_S2StaffStair/Ramp/Nosing") as Node3D
	var xf := Transform3D.IDENTITY
	var n: Node = src
	while n and n != level:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	var nosing := MultiMeshInstance3D.new()
	nosing.name = "Nosing"
	nosing.set_script(src.get_script())   # BatchedBoxes
	nosing.transform = xf
	nosing.material_override = _look("hazard_yellow")
	nosing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nosing.set_meta("render_layers", (src as GeometryInstance3D).layers)
	_add(parent, nosing)
	nosing.set("boxes", src.get("boxes"))
	level.free()


## A solid prop: a StaticBody3D with one box shape over `rect` [x0, z0, x1, z1], `h` high
## (on the ground floor); returns its "Model" (origin on the floor at the rect's centre).
## The browsing hall (x −36…−12, z 10…28): oak library tables (their collision unchanged)
## with chairs, banker's lamps and books, the S3 stair in oak (treads, a closed stringer,
## balusters and a handrail; its ramp and handrail bodies unchanged), a patterned carpet,
## a lounge corner, a new-books display, a magazine rack, a book trolley and a plant
## (solid). The old look is removed by fixes_x12.gd.
const BROWSING_TABLES := [Vector3(-24, 0, 15.5), Vector3(-24, 0, 23), Vector3(-18, 0, 15.5), Vector3(-18, 0, 23)]
const BOOK_LOOKS := ["pipe_red", "motor_blue", "cabinet_green", "rack_orange", "keypad_bezel", "cardboard", "wood_dark", "rug_teal"]
## The S3 stair (expanded_layout.gd STAIRS): x −35.85…−32.85, foot at z 20 (y 0), top at z 10 (y 4.5).
const S3_X0 := -35.85
const S3_X1 := -32.85
const S3_FOOT := 20.0
const S3_TOP := 10.0
const S3_RISE := 4.5
const S3_STEPS := 22


func _build_browsing_hall(solid: Node3D, decor: Node3D) -> void:
	var k := 0
	for t in BROWSING_TABLES:
		var g := Node3D.new()
		g.name = "BrowsingTable%d" % k
		g.position = t
		_add(decor, g)
		_library_table(g, k)
		# Four chairs, two each side, facing the table (the old ones were at x ∓0.75, z ∓0.64).
		var c := 0
		for side in [-1.0, 1.0]:
			for x in [-0.75, 0.75]:
				var ch := Node3D.new()
				ch.name = "Chair%d" % c
				ch.position = Vector3(x, 0, side * 0.64)
				ch.rotation_degrees = Vector3(0, 0.0 if side < 0 else 180.0, 0)
				_add(g, ch)
				_library_chair(ch)
				c += 1
		k += 1
	_dress_s3(decor)
	_browsing_carpet(decor)
	# Lounge corner (south-west, clear of the S3 foot): a rug, two leather armchairs,
	# a coffee table and a floor lamp.
	var rug := Node3D.new()
	rug.name = "LoungeRug"
	rug.position = Vector3(-34.1, 0, 25.65)
	_add(decor, rug)
	_add_visual_box(rug, "Border", Vector3(0, 0.006, 0), Vector3(2.9, 0.004, 3.7), "carpet_gold")
	_add_visual_box(rug, "Field", Vector3(0, 0.0085, 0), Vector3(2.7, 0.004, 3.5), "rug_red")
	var chair_w := _solid_prop(solid, "ArmchairWest", [-35.75, 24.9, -34.95, 25.9], 0.85)
	_armchair(chair_w, 0.0)
	var chair_s := _solid_prop(solid, "ArmchairSouth", [-34.55, 26.55, -33.55, 27.35], 0.85)
	_armchair(chair_s, 90.0)
	var coffee := _solid_prop(solid, "CoffeeTable", [-34.55, 25.05, -33.55, 25.75], 0.7)   # taller than the table: no navmesh on its top
	_add_visual_box(coffee, "Top", Vector3(0, 0.43, 0), Vector3(1.0, 0.04, 0.7), "oak")
	for lx in [-0.44, 0.44]:
		for lz in [-0.29, 0.29]:
			_add_visual_box(coffee, "Leg%d_%d" % [int(lx * 100), int(lz * 100)], Vector3(lx, 0.205, lz), Vector3(0.05, 0.41, 0.05), "oak_dark")
	_add_visual_box(coffee, "Shelf", Vector3(0, 0.1, 0), Vector3(0.9, 0.02, 0.6), "oak_dark")
	_add_visual_box(coffee, "Magazine0", Vector3(-0.2, 0.118, 0.05), Vector3(0.22, 0.016, 0.3), "poster_b")
	_add_visual_box(coffee, "Magazine1", Vector3(0.15, 0.118, -0.05), Vector3(0.22, 0.016, 0.3), "poster_a")
	_add_visual_box(coffee, "Book", Vector3(0.25, 0.465, 0.12), Vector3(0.24, 0.03, 0.17), "cabinet_green")
	_add_visual_box(coffee, "Cup", Vector3(-0.28, 0.49, -0.1), Vector3(0.07, 0.08, 0.07), "card_white")
	var lamp := _solid_prop(solid, "FloorLamp", [-35.7, 26.8, -35.3, 27.2], 1.6)
	_add_visual_box(lamp, "Base", Vector3(0, 0.015, 0), Vector3(0.34, 0.03, 0.34), "brass")
	_add_visual_box(lamp, "Pole", Vector3(0, 0.72, 0), Vector3(0.03, 1.4, 0.03), "brass")
	_add_visual_box(lamp, "Shade", Vector3(0, 1.44, 0), Vector3(0.38, 0.3, 0.38), "lamp_cream")
	_add_visual_box(lamp, "ShadeTop", Vector3(0, 1.595, 0), Vector3(0.3, 0.01, 0.3), "oak_dark")
	# New-books display (inside the lobby door, north of it).
	var display := _solid_prop(solid, "NewBooksDisplay", [-15.6, 19.2, -14.0, 20.0], 0.75)
	_add_visual_box(display, "Top", Vector3(0, 0.73, 0), Vector3(1.6, 0.04, 0.8), "oak")
	for lx in [-0.74, 0.74]:
		for lz in [-0.34, 0.34]:
			_add_visual_box(display, "Leg%d_%d" % [int(lx * 100), int(lz * 100)], Vector3(lx, 0.355, lz), Vector3(0.06, 0.71, 0.06), "oak_dark")
	_add_visual_box(display, "PanelN", Vector3(0, 0.38, -0.3), Vector3(1.4, 0.56, 0.02), "oak_dark")
	_add_visual_box(display, "PanelS", Vector3(0, 0.38, 0.3), Vector3(1.4, 0.56, 0.02), "oak_dark")
	for i in 6:
		var x := -0.6 + i * 0.24
		var sd := -1.0 if i % 2 == 0 else 1.0
		_add_box_r(display, "FaceOut%d" % i, Vector3(x, 0.89, sd * 0.12), Vector3(0.17, 0.25, 0.025), BOOK_LOOKS[(i * 3) % BOOK_LOOKS.size()], Vector3(-sd * 0.3, 0, 0))
		_add_visual_box(display, "Flat%d" % i, Vector3(x, 0.765, -sd * 0.22), Vector3(0.16, 0.03, 0.22), BOOK_LOOKS[(i * 5 + 1) % BOOK_LOOKS.size()])
	_add_box_r(display, "TentCard", Vector3(0, 0.83, 0), Vector3(0.34, 0.16, 0.01), "card_white", Vector3(0, 0, 0))
	_add_text(display, "TentTextS", Vector3(0, 0.83, 0.007), "NEW BOOKS", 22, 0.0016, Color(0.12, 0.08, 0.03))
	_add_text(display, "TentTextN", Vector3(0, 0.83, -0.007), "NEW BOOKS", 22, 0.0016, Color(0.12, 0.08, 0.03), 180.0)
	# Magazine rack against the east wall, south of the lobby door (faces west).
	var rack := _solid_prop(solid, "MagazineRack", [-12.6, 26.3, -12.15, 27.5], 1.2)
	_add_visual_box(rack, "Back", Vector3(0.18, 0.6, 0), Vector3(0.04, 1.2, 1.2), "oak_dark")
	for side in [-0.59, 0.59]:
		_add_visual_box(rack, "Side%d" % int(side * 100), Vector3(0, 0.6, side), Vector3(0.44, 1.2, 0.02), "oak")
	var mags := ["poster_a", "poster_b", "poster_c", "poster_d", "paper"]
	for y in [0.28, 0.62, 0.96]:
		_add_box_r(rack, "Ledge%d" % int(y * 100), Vector3(-0.02, y, 0), Vector3(0.3, 0.02, 1.16), "oak", Vector3(0, 0, -0.3))
		for p in 3:
			_add_box_r(rack, "Mag%d_%d" % [int(y * 100), p], Vector3(0.0, y + 0.14, -0.38 + p * 0.38), Vector3(0.015, 0.28, 0.21), mags[(p + int(y * 10)) % mags.size()], Vector3(0, 0, -0.3))
	# Book trolley (west of the browsing shelf) and a plant (north-east corner).
	var trolley := _solid_prop(solid, "BookTrolley", [-30.95, 12.3, -30.45, 13.2], 1.0)
	_book_trolley(trolley, Vector3(0.5, 1.0, 0.9), 3)
	var plant := _solid_prop(solid, "Plant", [-12.95, 10.55, -12.35, 11.15], 1.4)
	_add_visual_box(plant, "Pot", Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), "planter")
	_add_visual_box(plant, "Soil", Vector3(0, 0.495, 0), Vector3(0.44, 0.02, 0.44), "wood_dark")
	_add_visual_box(plant, "Trunk", Vector3(0, 0.75, 0), Vector3(0.05, 0.5, 0.05), "wood_dark")
	for i in 4:
		var off := Vector3([-0.12, 0.12, 0.0, 0.06][i], 0.95 + i * 0.13, [0.06, -0.06, 0.0, 0.1][i])
		_add_visual_box(plant, "Foliage%d" % i, off, Vector3(0.46 - i * 0.07, 0.24, 0.42 - i * 0.06), "foliage" if i % 2 == 0 else "foliage_light")


## A library table on a 3.0 × 1.4 m footprint (top at 0.8): oak top with an overhang,
## legs, an apron and recessed panels below (the cover stays solid to the eye too),
## two banker's lamps and books.
func _library_table(g: Node3D, k: int) -> void:
	_add_visual_box(g, "Top", Vector3(0, 0.775, 0), Vector3(3.1, 0.05, 1.5), "oak")
	_add_visual_box(g, "Lip", Vector3(0, 0.74, 0), Vector3(3.04, 0.02, 1.44), "oak_dark")
	for lx in [-1.42, 1.42]:
		for lz in [-0.62, 0.62]:
			_add_visual_box(g, "Leg%d_%d" % [int(lx * 100), int(lz * 100)], Vector3(lx, 0.365, lz), Vector3(0.09, 0.73, 0.09), "oak_dark")
	for sz in [-0.6, 0.6]:
		_add_visual_box(g, "Apron%d" % int(sz * 10), Vector3(0, 0.68, sz), Vector3(2.76, 0.1, 0.03), "oak_dark")
		_add_visual_box(g, "Panel%d" % int(sz * 10), Vector3(0, 0.34, sz * 0.58), Vector3(2.7, 0.62, 0.02), "oak")
	for sx in [-1.38, 1.38]:
		_add_visual_box(g, "End%d" % int(sx * 10), Vector3(sx, 0.34, 0), Vector3(0.02, 0.62, 1.1), "oak")
	for lx in [-0.75, 0.75]:
		var l := Node3D.new()
		l.name = "Lamp%d" % int(lx * 100)
		l.position = Vector3(lx, 0.8, 0)
		_add(g, l)
		_add_visual_box(l, "Base", Vector3(0, 0.012, 0), Vector3(0.14, 0.024, 0.14), "brass")
		_add_visual_box(l, "Stem", Vector3(0, 0.17, 0), Vector3(0.02, 0.3, 0.02), "brass")
		_add_visual_box(l, "Shade", Vector3(0, 0.34, 0), Vector3(0.34, 0.08, 0.15), "lamp_green")
		_add_visual_box(l, "Glow", Vector3(0, 0.298, 0), Vector3(0.3, 0.004, 0.11), "glow_sodium")
	var y := 0.8
	_add_visual_box(g, "OpenBookL", Vector3(-0.85, y + 0.012, 0.45), Vector3(0.16, 0.015, 0.22), "paper")
	_add_visual_box(g, "OpenBookR", Vector3(-0.68, y + 0.012, 0.45), Vector3(0.16, 0.015, 0.22), "paper")
	_add_visual_box(g, "OpenBookCover", Vector3(-0.765, y + 0.004, 0.45), Vector3(0.36, 0.008, 0.24), BOOK_LOOKS[k % BOOK_LOOKS.size()])
	_add_visual_box(g, "Notebook", Vector3(0.7, y + 0.006, -0.42), Vector3(0.18, 0.012, 0.24), "motor_blue" if k % 2 == 0 else "pipe_red")
	_add_visual_box(g, "Pencil", Vector3(0.86, y + 0.006, -0.4), Vector3(0.015, 0.012, 0.16), "sticker_yellow")
	_add_visual_box(g, "Stack0", Vector3(0.1, y + 0.02, 0.4), Vector3(0.24, 0.04, 0.17), BOOK_LOOKS[(k + 3) % BOOK_LOOKS.size()])
	_add_visual_box(g, "Stack1", Vector3(0.11, y + 0.055, 0.39), Vector3(0.22, 0.03, 0.16), BOOK_LOOKS[(k + 5) % BOOK_LOOKS.size()])


## A padded library chair at its parent's origin, facing +z (its back towards −z).
func _library_chair(ch: Node3D) -> void:
	for lx in [-0.19, 0.19]:
		for lz in [-0.17, 0.17]:
			_add_visual_box(ch, "Leg%d_%d" % [int(lx * 100), int(lz * 100)], Vector3(lx, 0.215, lz), Vector3(0.035, 0.43, 0.035), "oak_dark")
	_add_visual_box(ch, "Seat", Vector3(0, 0.45, 0), Vector3(0.44, 0.04, 0.43), "oak")
	_add_visual_box(ch, "Cushion", Vector3(0, 0.495, 0.01), Vector3(0.4, 0.05, 0.38), "fabric_green")
	for lx in [-0.19, 0.19]:
		_add_visual_box(ch, "Post%d" % int(lx * 100), Vector3(lx, 0.71, -0.19), Vector3(0.035, 0.5, 0.035), "oak_dark")
	_add_visual_box(ch, "TopRail", Vector3(0, 0.93, -0.19), Vector3(0.44, 0.07, 0.025), "oak")
	_add_visual_box(ch, "BackPad", Vector3(0, 0.73, -0.185), Vector3(0.34, 0.26, 0.03), "fabric_green")


## A leather armchair in a solid prop's model, facing +x (yaw 0) or turned by `yaw` degrees.
func _armchair(model: Node3D, yaw: float) -> void:
	var a := Node3D.new()
	a.name = "Armchair"
	a.rotation_degrees = Vector3(0, yaw, 0)
	_add(model, a)
	_add_visual_box(a, "Base", Vector3(0, 0.2, 0), Vector3(0.78, 0.3, 0.96), "leather")
	_add_visual_box(a, "Cushion", Vector3(0.06, 0.41, 0), Vector3(0.6, 0.12, 0.7), "leather")
	_add_visual_box(a, "Back", Vector3(-0.3, 0.6, 0), Vector3(0.18, 0.5, 0.96), "leather")
	for side in [-0.41, 0.41]:
		_add_visual_box(a, "Arm%d" % int(side * 100), Vector3(0.0, 0.48, side), Vector3(0.78, 0.26, 0.14), "leather")
	for fx in [-0.33, 0.33]:
		for fz in [-0.42, 0.42]:
			_add_visual_box(a, "Foot%d_%d" % [int(fx * 100), int(fz * 100)], Vector3(fx, 0.025, fz), Vector3(0.06, 0.05, 0.06), "oak_dark")


## A book trolley in a solid prop's model: a steel frame, `shelves` sloped shelves of books
## and casters; `size` is its box (x across, z along).
func _book_trolley(model: Node3D, size: Vector3, shelves: int) -> void:
	var along_x := size.x > size.z
	var length := size.x if along_x else size.z
	var depth := size.z if along_x else size.x
	for e in [-1.0, 1.0]:
		var at: float = e * (length / 2.0 - 0.03)
		_add_visual_box(model, "End%d" % int(e), Vector3(at, 0.55, 0) if along_x else Vector3(0, 0.55, at),
			Vector3(0.03, 0.9, depth) if along_x else Vector3(depth, 0.9, 0.03), "tool_steel")
		for d in [-1.0, 1.0]:
			var c := Vector3(at, 0.05, d * (depth / 2.0 - 0.05)) if along_x else Vector3(d * (depth / 2.0 - 0.05), 0.05, at)
			_add_visual_box(model, "Caster%d_%d" % [int(e), int(d)], c, Vector3(0.06, 0.08, 0.06), "tool_dark")
	for s in shelves:
		var y := 0.2 + s * 0.3
		_add_visual_box(model, "Shelf%d" % s, Vector3(0, y, 0), Vector3(length - 0.06, 0.02, depth) if along_x else Vector3(depth, 0.02, length - 0.06), "tool_steel")
		var n := int((length - 0.12) / 0.07)
		for i in n:
			var t := -length / 2.0 + 0.08 + i * 0.07
			var h := 0.2 + 0.03 * ((i * 7 + s) % 3)
			var look: String = BOOK_LOOKS[(i * 5 + s * 3) % BOOK_LOOKS.size()]
			for d in [-1.0, 1.0]:
				var c := Vector3(t, y + 0.01 + h / 2.0, d * depth * 0.25) if along_x else Vector3(d * depth * 0.25, y + 0.01 + h / 2.0, t)
				_add_visual_box(model, "B%d_%d_%d" % [s, i, int(d)], c, Vector3(0.06, h, depth * 0.42) if along_x else Vector3(depth * 0.42, h, 0.06), look)
	_add_visual_box(model, "Handle", Vector3(-length / 2.0 - 0.04, 0.95, 0) if along_x else Vector3(0, 0.95, -length / 2.0 - 0.04),
		Vector3(0.03, 0.03, depth * 0.8) if along_x else Vector3(depth * 0.8, 0.03, 0.03), "tool_dark")


## A box turned by `rot` (radians, XYZ euler), no collision, no shadow.
func _add_box_r(parent: Node, node_name: String, centre: Vector3, size: Vector3, look: String, rot: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = centre
	holder.rotation = rot
	_add(parent, holder)
	_add_tiles(holder, size, look)
	for m in holder.get_children():
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The S3 stair in oak: 22 treads and risers on the ramp (the walked surface is still
## the ramp: the treads' tops meet it at each step's back edge), the open side's
## closed stringer, skirt panels, balusters and handrail, newels.
func _dress_s3(decor: Node3D) -> void:
	_dress_oak_stair(decor, "S3Stair", S3_X0, S3_X1, false)


## An oak stair over a 10 m ramp from z 20 (y 0) to z 10 (y 4.5) between x0 and x1, open
## on the east (x1) side, as S3 and S1 (expanded_layout.gd STAIRS). `runner`: a red carpet
## runner with brass stair rods down the middle (S1).
func _dress_oak_stair(decor: Node3D, node_name: String, x0: float, x1: float, runner: bool) -> void:
	var s := Node3D.new()
	s.name = node_name
	_add(decor, s)
	var width := x1 - x0
	var xc := (x0 + x1) / 2.0
	var run := S3_FOOT - S3_TOP
	var rise := S3_RISE / S3_STEPS
	var going := run / S3_STEPS
	for i in S3_STEPS:
		var z_front := S3_FOOT - i * going
		var top := (i + 1) * rise
		_add_visual_box(s, "Tread%02d" % i, Vector3(xc + 0.02, top - 0.02, z_front - going / 2.0 + 0.015), Vector3(width - 0.1, 0.04, going + 0.03), "oak")
		_add_visual_box(s, "Riser%02d" % i, Vector3(xc + 0.02, i * rise + rise / 2.0 - 0.02, z_front - 0.01), Vector3(width - 0.12, rise - 0.04, 0.02), "oak_dark")
		if runner:
			_add_visual_box(s, "RunnerTread%02d" % i, Vector3(xc + 0.02, top + 0.003, z_front - going / 2.0 + 0.015), Vector3(1.7, 0.006, going + 0.03), "rug_red")
			_add_visual_box(s, "RunnerRiser%02d" % i, Vector3(xc + 0.02, i * rise + rise / 2.0 - 0.01, z_front + 0.003), Vector3(1.7, rise - 0.02, 0.006), "rug_red")
			for e in [-1.0, 1.0]:   # gold edges beside the runner, not under it (no shared faces)
				_add_visual_box(s, "RunnerEdge%02d_%d" % [i, int(e)], Vector3(xc + 0.02 + e * 0.875, top + 0.003, z_front - going / 2.0 + 0.015), Vector3(0.05, 0.006, going + 0.03), "carpet_gold")
			_add_visual_box(s, "Rod%02d" % i, Vector3(xc + 0.02, top + 0.012, z_front - going + 0.03), Vector3(1.86, 0.016, 0.016), "brass")
	var length := sqrt(run * run + S3_RISE * S3_RISE)
	var angle := atan2(S3_RISE, run)
	var zm := (S3_FOOT + S3_TOP) / 2.0
	var ym := S3_RISE / 2.0
	# Sloped boards (rotated about x: local +z runs down the slope towards the foot).
	var up := Vector3(0, cos(angle), sin(angle))   # the slope's normal (local +y), world
	for b in [["Stringer", x1 + 0.035, -0.15, 0.5, 0.07, "oak_dark"], ["Handrail", x1 + 0.035, 0.93 * cos(angle), 0.06, 0.08, "oak"]]:
		var off: float = b[2]
		_add_box_r(s, b[0], Vector3(b[1], ym + off / cos(angle), zm), Vector3(b[4], b[3], length - 0.1), b[5], Vector3(angle, 0, 0))
	# Skirt panels under the stringer (stepped, one per tread), the open side's face.
	for i in S3_STEPS:
		var z0 := S3_FOOT - (i + 1) * going
		var h := i * rise - 0.2
		if h < 0.05:
			continue
		_add_visual_box(s, "Skirt%02d" % i, Vector3(x1 + 0.02, h / 2.0, z0 + going / 2.0), Vector3(0.02, h, going), "oak")   # 1 cm off the fillers' face
	# Balusters (square with a collar) and newel posts.
	var n := 38
	for i in n:
		var z := S3_FOOT - 0.3 - i * (run - 0.5) / (n - 1)
		var slope_y := S3_RISE * (S3_FOOT - z) / run
		var bottom := slope_y + 0.1
		var top := slope_y + 0.9
		_add_visual_box(s, "Baluster%02d" % i, Vector3(x1 + 0.035, (bottom + top) / 2.0, z), Vector3(0.032, top - bottom, 0.032), "oak")
		_add_visual_box(s, "Collar%02d" % i, Vector3(x1 + 0.035, bottom + 0.22, z), Vector3(0.05, 0.06, 0.05), "oak_dark")
	_add_visual_box(s, "NewelFoot", Vector3(x1 + 0.035, 0.57, S3_FOOT - 0.08), Vector3(0.12, 1.14, 0.12), "oak_dark")
	_add_visual_box(s, "NewelFootCap", Vector3(x1 + 0.035, 1.17, S3_FOOT - 0.08), Vector3(0.16, 0.06, 0.16), "oak")
	_add_visual_box(s, "NewelTop", Vector3(x1 + 0.035, S3_RISE + 0.5, S3_TOP + 0.08), Vector3(0.12, 1.0, 0.12), "oak_dark")
	_add_visual_box(s, "NewelTopCap", Vector3(x1 + 0.035, S3_RISE + 1.03, S3_TOP + 0.08), Vector3(0.16, 0.06, 0.16), "oak")


## The browsing hall's patterned carpet over the carpet-coloured floor (fixes_x12.gd):
## a border with a gold line and a gold lattice with red diamonds. Thin, below the hiding spot's mark.
func _browsing_carpet(decor: Node3D) -> void:
	var c := Node3D.new()
	c.name = "Carpet"
	_add(decor, c)
	var x0 := -32.4
	var x1 := -12.55
	var z0 := 10.4
	var z1 := 27.45
	var y := 0.0025
	var bw := 0.35
	for e in [["N", Vector3((x0 + x1) / 2.0, y, z0 + bw / 2.0), Vector3(x1 - x0, 0.004, bw)], ["S", Vector3((x0 + x1) / 2.0, y, z1 - bw / 2.0), Vector3(x1 - x0, 0.004, bw)],
			["W", Vector3(x0 + bw / 2.0, y, (z0 + z1) / 2.0), Vector3(bw, 0.004, z1 - z0 - 2 * bw)], ["E", Vector3(x1 - bw / 2.0, y, (z0 + z1) / 2.0), Vector3(bw, 0.004, z1 - z0 - 2 * bw)]]:
		_add_visual_box(c, "Border" + e[0], e[1], e[2], "carpet_border")
	var i0 := x0 + bw + 0.15
	var i1 := x1 - bw - 0.15
	var j0 := z0 + bw + 0.15
	var j1 := z1 - bw - 0.15
	for e in [["N", Vector3((i0 + i1) / 2.0, y, j0), Vector3(i1 - i0, 0.004, 0.05)], ["S", Vector3((i0 + i1) / 2.0, y, j1), Vector3(i1 - i0, 0.004, 0.05)],
			["W", Vector3(i0, y, (j0 + j1) / 2.0), Vector3(0.05, 0.004, j1 - j0)], ["E", Vector3(i1, y, (j0 + j1) / 2.0), Vector3(0.05, 0.004, j1 - j0)]]:
		_add_visual_box(c, "Line" + e[0], e[1], e[2], "carpet_gold")
	# A lattice of thin gold lines every 1.5 m, small red diamonds at the crossings.
	var xs: Array[float] = []
	var x := -30.95
	while x < i1 - 0.3:
		xs.append(x)
		x += 1.5
	var zs: Array[float] = []
	var z := 11.6
	while z < j1 - 0.3:
		zs.append(z)
		z += 1.5
	for lx in xs:
		_add_visual_box(c, "LatticeX%d" % int(-lx * 10), Vector3(lx, y, (j0 + j1) / 2.0), Vector3(0.03, 0.004, j1 - j0), "carpet_gold")
	for lz in zs:
		_add_visual_box(c, "LatticeZ%d" % int(lz * 10), Vector3((i0 + i1) / 2.0, y + 0.0004, lz), Vector3(i1 - i0, 0.004, 0.03), "carpet_gold")
	var k := 0
	for lx in xs:
		for lz in zs:
			if absf(lx + 28.8) < 0.7 and absf(lz - 15.0) < 0.7:
				continue   # the browsing shelf's hiding spot mark
			_add_box_r(c, "Diamond%03d" % k, Vector3(lx, y + 0.0008, lz), Vector3(0.16, 0.004, 0.16), "carpet_border", Vector3(0, PI / 4.0, 0))
			k += 1


## The main and upper stacks. Ground (oak): cornices, kick plates, end panels with call
## number cards, carpet tiles and aisle runners, strip lights along the aisles, step stools
## and a trolley (solid), books on the floor by the shelves. Upper (steel mezzanine):
## steel end panels and kick plates, archive boxes on top, a lighter ceiling with steel
## beams and hanging strip lights, deck seams. The shelves' collision is unchanged.
func _build_stacks(solid: Node3D, decor: Node3D, ceilings: Node3D) -> void:
	var ground_rows: Array = []
	var upper_rows: Array = []
	for c in MainLayout.COVER:
		if c.kind != "shelf" or c.get("look", "") != "bookcase":
			continue
		for r in c.rects:
			if c.zone == "B":
				ground_rows.append(r)
			elif c.zone == "E" and r[2] < -6.0:
				upper_rows.append(r)
	var k := 0
	for r in ground_rows:
		_row_dressing(decor, "Row%02d" % k, r, 0.0, "oak_dark", "oak", true)
		k += 1
	var upper := _group(decor, "Upper")
	k = 0
	for r in upper_rows:
		_row_dressing(upper, "UpperRow%02d" % k, r, MainLayout.UPPER_Y, "steel_beam", "steel_shelf", false)
		k += 1
	# Upper: archive boxes on some shelf tops (2.24 m up).
	for i in upper_rows.size():
		var r: Array = upper_rows[i]
		if i % 2 == 1:
			continue
		var xc: float = (r[0] + r[2]) / 2.0
		var z: float = r[1] + 1.2 + (i % 3) * 0.8
		var j := 0
		while z < r[3] - 0.6:
			_add_visual_box(upper, "TopBox%02d_%02d" % [i, j], Vector3(xc, MainLayout.UPPER_Y + 2.24 + 0.14, z), Vector3(0.42, 0.28, 0.32), "archive_box" if j % 3 else "cardboard")
			z += 2.6 + (j % 2) * 1.7
			j += 1
	_stacks_floor(decor, upper)
	_stacks_lights(ceilings)
	_set_layer_meta(upper, Layout.LAYER_UPPER)
	_set_layer_meta(ceilings.get_node("UpperCeiling"), Layout.LAYER_UPPER)
	# Step stools (solid) against shelf faces, and books on the floor (decor, < 0.3 m deep).
	for st in [[-27.7, -15.0, 1.0], [-21.7, -21.0, 1.0], [-19.3, 2.0, -1.0]]:
		var face: float = st[0]
		var dir: float = st[2]
		var rect := [face, st[1] - 0.21, face + dir * 0.42, st[1] + 0.21]
		if dir < 0:
			rect = [face - 0.42, st[1] - 0.21, face, st[1] + 0.21]
		var model := _solid_prop(solid, "StepStool%d" % int(absf(st[1])), rect, 0.45)
		_step_stool(model, dir)
	var trolley := _solid_prop(solid, "StacksTrolley", [-24.2, -27.8, -22.8, -27.3], 1.0)
	_book_trolley(trolley, Vector3(1.4, 1.0, 0.5), 3)
	var piles := [[-30.7, -19.5, 1.0, 3], [-24.7, -14.0, 1.0, 2], [-22.3, -3.0, -1.0, 4], [-16.3, -22.5, -1.0, 3], [-28.3, 3.5, -1.0, 2], [-18.7, -5.5, 1.0, 3]]
	k = 0
	for p in piles:
		for b in p[3]:
			var yaw: int = (b * 37 + k * 11) % 20 - 10
			_add_box_r(decor, "FloorBook%d_%d" % [k, b], Vector3(p[0] + p[2] * 0.14, 0.02 + b * 0.04, p[1]), Vector3(0.18, 0.04, 0.25 - b * 0.015), BOOK_LOOKS[(k * 3 + b) % BOOK_LOOKS.size()], Vector3(0, deg_to_rad(yaw), 0))
		k += 1


## A shelf row's dressing at floor height `y0`: a kick plate, end panels with a call-number
## card at both ends and (oak rows) a cornice.
func _row_dressing(parent: Node3D, node_name: String, r: Array, y0: float, plate: String, panel: String, cornice: bool) -> void:
	var g := Node3D.new()
	g.name = node_name
	g.position = Vector3((r[0] + r[2]) / 2.0, y0, (r[1] + r[3]) / 2.0)
	_add(parent, g)
	var w: float = r[2] - r[0]
	var l: float = r[3] - r[1]
	_add_visual_box(g, "Kick", Vector3(0, 0.035, 0), Vector3(w + 0.06, 0.07, l), plate)
	if cornice:
		_add_visual_box(g, "Cornice", Vector3(0, 2.275, 0), Vector3(w + 0.12, 0.07, l + 0.08), plate)
	for e in [-1.0, 1.0]:
		var z: float = e * (l / 2.0 + 0.015)
		_add_visual_box(g, "End%d" % int(e), Vector3(0, 1.1, z), Vector3(w + 0.04, 2.2, 0.03), panel)
		_add_visual_box(g, "EndInset%d" % int(e), Vector3(0, 1.05, z + e * 0.017), Vector3(w - 0.12, 1.7, 0.004), plate)
		_add_visual_box(g, "Holder%d" % int(e), Vector3(0, 1.5, z + e * 0.022), Vector3(0.18, 0.12, 0.012), "brass")
		_add_visual_box(g, "Card%d" % int(e), Vector3(0, 1.5, z + e * 0.029), Vector3(0.155, 0.095, 0.004), "card_white")
		for t in 2:
			_add_visual_box(g, "Text%d_%d" % [int(e), t], Vector3(-0.01 * t, 1.52 - t * 0.035, z + e * 0.0315), Vector3(0.11 - t * 0.03, 0.012, 0.002), "wire_black")


## The main stacks' carpet tiles (seams on a 1 m grid) and runners along the aisles; the
## upper stacks' deck seams.
func _stacks_floor(decor: Node3D, upper: Node3D) -> void:
	var f := Node3D.new()
	f.name = "StacksFloor"
	_add(decor, f)
	for x in [-29.5, -26.5, -23.5, -20.5, -17.5]:
		_add_visual_box(f, "Runner%d" % int(-x * 10), Vector3(x, 0.0015, -9.5), Vector3(1.0, 0.003, 31.0), "carpet_runner")
	_add_visual_box(f, "RunnerCross", Vector3(-24.0, 0.0026, -9.0), Vector3(23.7, 0.003, 1.2), "carpet_runner")
	var x := -35.0
	while x < -12.2:
		_add_visual_box(f, "SeamX%d" % int(-x), Vector3(x, 0.0048, -8.925), Vector3(0.015, 0.002, 37.85), "carpet_seam")
		x += 1.0
	var z := -27.0
	while z < 10.0:
		_add_visual_box(f, "SeamZ%d" % int(z + 30), Vector3(-24.0, 0.0048, z), Vector3(23.7, 0.002, 0.015), "carpet_seam")
		z += 1.0
	var y := MainLayout.UPPER_Y + 0.002
	z = -26.65
	while z < 9.9:
		_add_visual_box(upper, "Deck%d" % int(z + 30), Vector3(-24.0, y, z), Vector3(23.7, 0.003, 0.02), "deck_seam")
		z += 1.2


## Strip lights: surface-mounted along the main stacks' aisles (ceiling 4.2 m), hanging from
## the upper stacks' new ceiling (8.0 m) between steel beams. Emissive only: the lamps
## (Dressing/Lights) are unchanged, their round fixtures hidden by fixes_x12.gd.
func _stacks_lights(ceilings: Node3D) -> void:
	var g := Node3D.new()
	g.name = "StacksStrips"
	_add(ceilings, g)
	var k := 0
	for x in [-33.6, -29.5, -26.5, -23.5, -20.5, -17.5, -13.9]:
		var z := -26.4
		while z < 9.5:
			_add_visual_box(g, "Housing%03d" % k, Vector3(x, 4.175, z), Vector3(0.22, 0.05, 1.25), "fluoro_housing")
			_add_visual_box(g, "Diffuser%03d" % k, Vector3(x, 4.146, z), Vector3(0.16, 0.012, 1.18), "fluoro")
			z += 2.4
			k += 1
	var top := MainLayout.UPPER_Y + 3.5   # 8.0
	var u := Node3D.new()
	u.name = "UpperCeiling"
	_add(ceilings, u)
	# In 5 × 7 panels (about 6 × 5.4 m), so no piece is reached by more than 8 lamps.
	for i in 5:
		for j in 7:
			_add_visual_box(u, "Panel%d_%d" % [i, j], Vector3(-35.85 + 29.7 * (i + 0.5) / 5.0, top - 0.03, -27.85 + 37.85 * (j + 0.5) / 7.0),
				Vector3(29.7 / 5.0, 0.04, 37.85 / 7.0), "ceiling")
	for bz in [-18.5, -9.0, 0.5]:
		_add_visual_box(u, "BeamWeb%d" % int(bz * 10), Vector3(-21.0, top - 0.19, bz), Vector3(29.7, 0.28, 0.03), "steel_beam")
		_add_visual_box(u, "BeamTop%d" % int(bz * 10), Vector3(-21.0, top - 0.06, bz), Vector3(29.7, 0.02, 0.16), "steel_beam")
		_add_visual_box(u, "BeamBottom%d" % int(bz * 10), Vector3(-21.0, top - 0.32, bz), Vector3(29.7, 0.02, 0.16), "steel_beam")
	k = 0
	for x in [-33.6, -29.0, -25.0, -21.0, -17.0, -13.0, -9.0]:
		var z := -26.4
		while z < 9.5:
			_add_visual_box(u, "Housing%03d" % k, Vector3(x, top - 0.4, z), Vector3(0.22, 0.05, 1.25), "fluoro_housing")
			_add_visual_box(u, "Diffuser%03d" % k, Vector3(x, top - 0.429, z), Vector3(0.16, 0.012, 1.18), "fluoro")
			for e in [-0.5, 0.5]:
				_add_visual_box(u, "Rod%03d_%d" % [k, int(e * 2)], Vector3(x, top - 0.2, z + e), Vector3(0.01, 0.36, 0.01), "tool_dark")
			z += 2.4
			k += 1


## Render layers for every mesh under `node` (read by _assign_layers).
func _set_layer_meta(node: Node, layers: int) -> void:
	if node is GeometryInstance3D:
		node.set_meta("render_layers", layers)
	for child in node.get_children():
		_set_layer_meta(child, layers)


## A two-step oak stool in a solid prop's model, its back against a shelf face on −dir·x.
func _step_stool(model: Node3D, dir: float) -> void:
	_add_visual_box(model, "TopStep", Vector3(-dir * 0.1, 0.43, 0), Vector3(0.2, 0.04, 0.42), "oak")
	_add_visual_box(model, "LowStep", Vector3(dir * 0.1, 0.22, 0), Vector3(0.2, 0.04, 0.42), "oak")
	for side in [-0.195, 0.195]:
		_add_visual_box(model, "SideBack%d" % int(side * 1000), Vector3(-dir * 0.1, 0.205, side), Vector3(0.2, 0.41, 0.03), "oak_dark")
		_add_visual_box(model, "SideFront%d" % int(side * 1000), Vector3(dir * 0.1, 0.1, side), Vector3(0.2, 0.2, 0.03), "oak_dark")


## The staff wing (upper floor, x −6…12): Offices 1–3 (z −28…−14), the staff corridor
## (z −14…−8) and the staff balcony (z −8…10). The stacks' mix: the upper stacks' light
## ceiling, beams and strip lights, deck floor and painted wainscot (fixes_x13.gd), oak
## furniture. The desks' and tables' collision is unchanged; the new props are solid. The
## old look is removed by fixes_x13.gd. The card, the checkpoint, the security locker and
## the documents are untouched.
const STAFF_Y := 4.5
const OFFICE_Z0 := -27.85
const OFFICE_Z1 := -14.15
const OFFICE_DESK_Z := -23.5
const BALCONY_TABLES := [Vector3(0, 0, -3), Vector3(7, 0, 3)]


func _build_staff_wing(solid: Node3D, decor: Node3D, ceilings: Node3D) -> void:
	var d := Node3D.new()
	d.name = "StaffWing"
	d.position = Vector3(0, STAFF_Y, 0)
	_add(decor, d)
	for i in 3:
		_office(solid, d, i)
	_staff_corridor(solid, d)
	_staff_balcony(solid, d)
	_staff_ceiling(ceilings)
	_set_layer_meta(d, Layout.LAYER_UPPER)
	_set_layer_meta(solid, Layout.LAYER_UPPER)


## A solid prop standing on the upper floor (see _solid_prop).
func _upper_prop(solid: Node3D, node_name: String, rect: Array, h: float) -> Node3D:
	var model := _solid_prop(solid, node_name, rect, h)
	(model.get_parent() as Node3D).position.y += STAFF_Y
	model.get_parent().set_meta("why", "staff wing prop (polish): solid; the model is its look")
	return model


## Office `i` (0…2, x −6 + 6i … +6): an oak desk set up per office (tidy, busy, half
## packed), an office chair, filing cabinets, steel shelving, carpet tiles, open door
## leaves and small extras.
func _office(solid: Node3D, d: Node3D, i: int) -> void:
	var x0 := -6.0 + 6.0 * i
	var c := x0 + 3.0
	var o := Node3D.new()
	o.name = "Office%d" % (i + 1)
	_add(d, o)
	var desk := Node3D.new()
	desk.name = "Desk"
	desk.position = Vector3(c, 0, OFFICE_DESK_Z)
	desk.rotation_degrees = Vector3(0, 180.0, 0)   # its user sits on the back-wall side, facing the door
	_add(o, desk)
	_office_desk(desk, i)
	var ch := Node3D.new()
	ch.name = "Chair"
	ch.position = Vector3(c + 0.85, 0, -23.94)
	ch.rotation_degrees = Vector3(0, 0.0 if i != 2 else 15.0, 0)
	_add(o, ch)
	_office_chair(ch)
	# Filing cabinets in the back corner (solid), steel shelving on a side wall clear of the
	# documents and the locker (solid).
	var cab := _upper_prop(solid, "Office%dCabinets" % (i + 1), [x0 + 0.2, OFFICE_Z0, x0 + 1.2, OFFICE_Z0 + 0.65], 1.32)
	for k in 2:
		var cx := -0.25 + k * 0.5
		_add_visual_box(cab, "Body%d" % k, Vector3(cx, 0.66, 0), Vector3(0.48, 1.32, 0.64), "locker_grey")
		for dr in 4:
			var y := 0.17 + dr * 0.32
			_add_visual_box(cab, "Drawer%d_%d" % [k, dr], Vector3(cx, y, 0.325), Vector3(0.42, 0.28, 0.012), "panel_grey")
			_add_visual_box(cab, "Handle%d_%d" % [k, dr], Vector3(cx, y + 0.08, 0.335), Vector3(0.14, 0.02, 0.02), "tool_dark")
			_add_visual_box(cab, "Label%d_%d" % [k, dr], Vector3(cx, y + 0.03, 0.333), Vector3(0.08, 0.04, 0.004), "card_white")
	if i == 1:
		_add_visual_box(cab, "PaperPile", Vector3(-0.2, 1.36, 0.0), Vector3(0.3, 0.08, 0.24), "paper")
	var shelf_rects := [[-0.6, -20.5, -0.15, -18.5], [0.15, -20.5, 0.6, -18.5], [6.15, -20.5, 6.6, -18.5]]
	var sh := _upper_prop(solid, "Office%dShelving" % (i + 1), shelf_rects[i], 2.0)
	_steel_shelving(sh, Vector3(0.45, 2.0, 2.0), i)
	_office_floor(o, x0)
	_office_door_leaves(o, x0, c, i)
	_add_visual_box(o, "NumberPlate", Vector3(c, 2.65, -13.786), Vector3(0.5, 0.1, 0.008), "brass")
	_add_text(o, "NumberText", Vector3(c, 2.65, -13.78), "OFFICE %d" % (i + 1), 22, 0.0016, Color(0.12, 0.08, 0.03))
	var bin := _upper_prop(solid, "Office%dBin" % (i + 1), [c + 1.65, -23.85, c + 1.95, -23.55], 0.35)
	_add_visual_box(bin, "Bin", Vector3(0, 0.17, 0), Vector3(0.28, 0.34, 0.28), "tool_dark")
	_add_visual_box(bin, "Rim", Vector3(0, 0.345, 0), Vector3(0.3, 0.02, 0.3), "tool_steel")
	if i < 2:
		var coat := _upper_prop(solid, "Office%dCoatStand" % (i + 1), [x0 + 0.3, -15.05, x0 + 0.7, -14.65], 1.8)
		_add_visual_box(coat, "Foot", Vector3(0, 0.02, 0), Vector3(0.38, 0.04, 0.38), "oak_dark")
		_add_visual_box(coat, "Pole", Vector3(0, 0.9, 0), Vector3(0.04, 1.76, 0.04), "oak_dark")
		for k in 4:
			var a := k * PI / 2.0
			_add_box_r(coat, "Hook%d" % k, Vector3(cos(a) * 0.09, 1.66, sin(a) * 0.09), Vector3(0.16, 0.025, 0.025), "brass", Vector3(0, -a, 0.5))
		_add_visual_box(coat, "Coat", Vector3(0.0, 1.2, 0.12), Vector3(0.36, 0.7, 0.1), "motor_dark" if i == 0 else "cabinet_green")
		var plant := _upper_prop(solid, "Office%dPlant" % (i + 1), [x0 + 5.2, -15.05, x0 + 5.75, -14.5], 1.3)
		_add_visual_box(plant, "Pot", Vector3(0, 0.22, 0), Vector3(0.44, 0.44, 0.44), "planter")
		for k in 3:
			_add_visual_box(plant, "Foliage%d" % k, Vector3([-0.08, 0.08, 0.0][k], 0.62 + k * 0.2, [0.05, -0.05, 0.0][k]), Vector3(0.5 - k * 0.1, 0.26, 0.46 - k * 0.1), "foliage" if k % 2 == 0 else "foliage_light")
	else:
		# Half packed: boxes in the back corner and by the door.
		var boxes := _upper_prop(solid, "Office3Boxes", [x0 + 4.55, OFFICE_Z0, x0 + 5.85, OFFICE_Z0 + 0.95], 0.62)
		for k in 4:
			var bx := -0.33 + (k % 2) * 0.66
			var by := 0.15 + (k / 2) * 0.31
			_add_box_r(boxes, "Box%d" % k, Vector3(bx, by, 0.0 if k < 2 else 0.05), Vector3(0.6, 0.3, 0.9 if k < 2 else 0.4), "archive_box" if k % 2 == 0 else "cardboard", Vector3(0, 0.0 if k < 2 else 0.12, 0))
		var door_boxes := _upper_prop(solid, "Office3DoorBoxes", [x0 + 0.25, -15.4, x0 + 0.95, -14.6], 0.62)
		_add_visual_box(door_boxes, "Box", Vector3(0, 0.15, 0), Vector3(0.66, 0.3, 0.76), "cardboard")
		_add_visual_box(door_boxes, "Tape", Vector3(0, 0.302, 0), Vector3(0.66, 0.004, 0.06), "sticker_yellow")
		_add_box_r(door_boxes, "TopBox", Vector3(0.02, 0.46, 0.02), Vector3(0.56, 0.3, 0.62), "archive_box", Vector3(0, 0.1, 0))


## An oak desk on a 3.0 × 1.0 m footprint (top at 0.82), its user on local +z: top, modesty panel at the front,
## a side panel and a drawer pedestal; the set-up per office (`style` 0 tidy, 1 busy with
## the staff card in the middle kept clear, 2 half packed).
func _office_desk(g: Node3D, style: int) -> void:
	_add_visual_box(g, "Top", Vector3(0, 0.795, 0), Vector3(3.1, 0.05, 1.1), "oak")
	_add_visual_box(g, "Modesty", Vector3(0, 0.42, -0.42), Vector3(2.9, 0.7, 0.03), "oak_dark")
	_add_visual_box(g, "SideW", Vector3(-1.47, 0.385, 0), Vector3(0.05, 0.77, 1.0), "oak_dark")
	_add_visual_box(g, "Pedestal", Vector3(1.22, 0.385, 0), Vector3(0.52, 0.77, 0.98), "oak_dark")
	for dr in 3:
		var y := 0.17 + dr * 0.24
		_add_visual_box(g, "Drawer%d" % dr, Vector3(1.22, y, 0.495), Vector3(0.46, 0.2, 0.012), "oak")
		_add_visual_box(g, "Pull%d" % dr, Vector3(1.22, y + 0.06, 0.505), Vector3(0.12, 0.02, 0.012), "brass")
	var t := 0.82
	# Monitor, keyboard, mouse (every desk).
	_add_visual_box(g, "MonitorFoot", Vector3(-0.85, t + 0.01, -0.2), Vector3(0.22, 0.02, 0.16), "keypad_bezel")
	_add_visual_box(g, "MonitorNeck", Vector3(-0.85, t + 0.14, -0.24), Vector3(0.04, 0.24, 0.03), "keypad_bezel")
	_add_visual_box(g, "Monitor", Vector3(-0.85, t + 0.35, -0.22), Vector3(0.56, 0.34, 0.035), "keypad_bezel")
	_add_visual_box(g, "Screen", Vector3(-0.85, t + 0.35, -0.2), Vector3(0.52, 0.3, 0.004), "screen_dark" if style == 2 else "screen_lit")
	_add_visual_box(g, "Keyboard", Vector3(-0.85, t + 0.012, 0.18), Vector3(0.44, 0.02, 0.15), "wire_black")
	_add_visual_box(g, "Mouse", Vector3(-0.5, t + 0.012, 0.2), Vector3(0.06, 0.02, 0.1), "wire_black")
	# Desk lamp (angled arm) at the east end.
	_add_visual_box(g, "LampBase", Vector3(1.3, t + 0.012, -0.3), Vector3(0.14, 0.024, 0.14), "tool_dark")
	_add_box_r(g, "LampArm", Vector3(1.3, t + 0.2, -0.24), Vector3(0.025, 0.36, 0.025), "tool_dark", Vector3(0.35, 0, 0))
	_add_box_r(g, "LampHead", Vector3(1.3, t + 0.38, -0.12), Vector3(0.14, 0.08, 0.2), "tool_dark", Vector3(0.5, 0, 0))
	_add_visual_box(g, "LampGlow", Vector3(1.3, t + 0.335, -0.06), Vector3(0.1, 0.004, 0.12), "glow_sodium")
	if style == 0:   # tidy
		_add_visual_box(g, "Tray0", Vector3(0.75, t + 0.03, -0.25), Vector3(0.36, 0.05, 0.28), "tool_steel")
		_add_visual_box(g, "Tray1", Vector3(0.75, t + 0.09, -0.25), Vector3(0.36, 0.05, 0.28), "tool_steel")
		_add_visual_box(g, "TrayPaper", Vector3(0.75, t + 0.06, -0.25), Vector3(0.3, 0.012, 0.22), "paper")
		_add_visual_box(g, "Mug", Vector3(0.2, t + 0.05, 0.2), Vector3(0.08, 0.1, 0.08), "pipe_red")
		_add_visual_box(g, "Notepad", Vector3(0.45, t + 0.006, 0.15), Vector3(0.15, 0.012, 0.21), "sticker_yellow")
		_add_visual_box(g, "Pen", Vector3(0.6, t + 0.006, 0.15), Vector3(0.012, 0.012, 0.14), "motor_blue")
	elif style == 1:   # busy (the staff card lies at the desk's centre: kept clear)
		for k in 3:
			_add_visual_box(g, "Tray%d" % k, Vector3(0.8, t + 0.03 + k * 0.06, -0.28), Vector3(0.36, 0.05, 0.28), "tool_steel")
			_add_box_r(g, "TrayPaper%d" % k, Vector3(0.8, t + 0.06 + k * 0.06, -0.28), Vector3(0.32, 0.012, 0.24), "paper", Vector3(0, 0.1 * (k - 1), 0))
		for k in 4:
			_add_box_r(g, "Pile%d" % k, Vector3(-0.35 - (k % 2) * 0.05, t + 0.01 + k * 0.022, 0.32), Vector3(0.22, 0.02, 0.3), "paper", Vector3(0, 0.15 * (k - 1.5), 0))
		for k in 3:
			_add_visual_box(g, "Binder%d" % k, Vector3(0.45 + k * 0.07, t + 0.16, -0.38), Vector3(0.06, 0.3, 0.26), ["motor_blue", "pipe_red", "cabinet_green"][k])
		_add_visual_box(g, "Mug", Vector3(-1.3, t + 0.05, 0.25), Vector3(0.08, 0.1, 0.08), "card_white")
		for k in 3:
			_add_visual_box(g, "Sticky%d" % k, Vector3(-1.18 + k * 0.1, t + 0.003, 0.4), Vector3(0.07, 0.004, 0.07), "sticker_yellow")
	else:   # half packed
		_add_visual_box(g, "DeskBox0", Vector3(0.55, t + 0.15, -0.1), Vector3(0.42, 0.3, 0.32), "archive_box")
		_add_box_r(g, "DeskBox1", Vector3(0.95, t + 0.12, 0.2), Vector3(0.4, 0.24, 0.3), "cardboard", Vector3(0, 0.2, 0))
		_add_visual_box(g, "TapeRoll", Vector3(0.0, t + 0.025, 0.3), Vector3(0.1, 0.05, 0.1), "sticker_yellow")
		_add_visual_box(g, "Mug", Vector3(0.25, t + 0.05, 0.25), Vector3(0.08, 0.1, 0.08), "motor_blue")


## A swivel office chair at its parent's origin, facing +z (its back towards −z).
func _office_chair(ch: Node3D) -> void:
	for k in 3:
		_add_box_r(ch, "Star%d" % k, Vector3(0, 0.05, 0), Vector3(0.56, 0.04, 0.05), "tool_dark", Vector3(0, k * PI / 3.0, 0))
	_add_visual_box(ch, "Column", Vector3(0, 0.25, 0), Vector3(0.05, 0.36, 0.05), "tool_steel")
	_add_visual_box(ch, "Seat", Vector3(0, 0.47, 0), Vector3(0.48, 0.08, 0.46), "keypad_bezel")
	_add_visual_box(ch, "Back", Vector3(0, 0.8, -0.21), Vector3(0.44, 0.5, 0.06), "keypad_bezel")
	_add_visual_box(ch, "BackPost", Vector3(0, 0.56, -0.2), Vector3(0.05, 0.16, 0.04), "tool_dark")
	for sx in [-0.24, 0.24]:
		_add_visual_box(ch, "Arm%d" % int(sx * 100), Vector3(sx, 0.66, -0.02), Vector3(0.05, 0.03, 0.3), "tool_dark")
		_add_visual_box(ch, "ArmPost%d" % int(sx * 100), Vector3(sx, 0.57, -0.08), Vector3(0.03, 0.16, 0.03), "tool_dark")


## Steel shelving in a solid prop's model (`size`: x across, z along): uprights, five
## shelves, archive boxes and binders.
func _steel_shelving(m: Node3D, size: Vector3, seed: int) -> void:
	var depth := size.x
	var length := size.z
	for ex in [-1.0, 1.0]:
		for ez in [-1.0, 1.0]:
			_add_visual_box(m, "Post%d_%d" % [int(ex), int(ez)], Vector3(ex * (depth / 2.0 - 0.02), size.y / 2.0, ez * (length / 2.0 - 0.02)), Vector3(0.035, size.y, 0.035), "steel_beam")
	for s in 5:
		var y := 0.08 + s * 0.45
		_add_visual_box(m, "Shelf%d" % s, Vector3(0, y, 0), Vector3(depth, 0.025, length), "steel_shelf")
		if s == 4:
			continue
		var z := -length / 2.0 + 0.1
		var k := 0
		while z < length / 2.0 - 0.3:
			var kind := (k + s + seed) % 4
			if kind == 3:
				z += 0.25   # a gap
			elif kind == 2:
				for b in 4:
					_add_visual_box(m, "Binder%d_%d_%d" % [s, k, b], Vector3(0, y + 0.17, z + b * 0.065), Vector3(depth - 0.12, 0.31, 0.055), ["motor_blue", "pipe_red", "cabinet_green", "keypad_bezel"][(b + s) % 4])
				z += 0.3
			else:
				_add_visual_box(m, "Box%d_%d" % [s, k], Vector3(0, y + 0.15, z + 0.17), Vector3(depth - 0.08, 0.27, 0.32), "archive_box" if kind == 0 else "cardboard")
				_add_visual_box(m, "BoxLabel%d_%d" % [s, k], Vector3(-depth / 2.0 + 0.035, y + 0.17, z + 0.17), Vector3(0.004, 0.06, 0.12), "card_white")
				z += 0.38
			k += 1


## Carpet tiles (1 m seams) over the office's recoloured floor, below the floor marks.
func _office_floor(o: Node3D, x0: float) -> void:
	var y := 0.0035
	var x := x0 + 1.0
	while x < x0 + 5.9:
		_add_visual_box(o, "SeamX%d" % int((x - x0) * 10), Vector3(x, y, (OFFICE_Z0 + OFFICE_Z1) / 2.0), Vector3(0.015, 0.002, OFFICE_Z1 - OFFICE_Z0), "carpet_seam")
		x += 1.0
	var z := OFFICE_Z0 + 0.85
	while z < OFFICE_Z1:
		_add_visual_box(o, "SeamZ%d" % int(-z * 10), Vector3(x0 + 3.0, y, z), Vector3(5.7, 0.002, 0.015), "carpet_seam")
		z += 1.0


## The office door (x c ± 1 in the wall z −14): two oak leaves folded back flat on the
## office side of the wall, with kick plates, vision panels and push plates.
func _office_door_leaves(o: Node3D, x0: float, c: float, i: int) -> void:
	var z := -14.168
	for side in [-1.0, 1.0]:
		var lx: float = c + side * 1.5
		var leaf := Node3D.new()
		leaf.name = "Leaf%s" % ("W" if side < 0 else "E")
		leaf.position = Vector3(lx, 0, z)
		_add(o, leaf)
		_add_visual_box(leaf, "Leaf", Vector3(0, 1.3, 0), Vector3(0.98, 2.56, 0.03), "oak")
		_add_visual_box(leaf, "Kick", Vector3(0, 0.12, -0.017), Vector3(0.9, 0.2, 0.004), "tool_steel")
		_add_visual_box(leaf, "VisionFrame", Vector3(side * -0.2, 1.65, -0.017), Vector3(0.26, 0.66, 0.004), "oak_dark")
		_add_visual_box(leaf, "Vision", Vector3(side * -0.2, 1.65, -0.0195), Vector3(0.2, 0.6, 0.002), "wired_glass")
		_add_visual_box(leaf, "PushPlate", Vector3(side * 0.38, 1.1, -0.017), Vector3(0.08, 0.3, 0.004), "brass")


## The staff corridor: a carpet runner, a bench, recycling bins and a water cooler (solid,
## along the balcony-side wall, clear of G1a and the corridor guard's route).
func _staff_corridor(solid: Node3D, d: Node3D) -> void:
	var c := Node3D.new()
	c.name = "Corridor"
	_add(d, c)
	_add_visual_box(c, "RunnerEdge", Vector3(3.0, 0.0015, -11.0), Vector3(17.6, 0.002, 1.5), "carpet_border")
	_add_visual_box(c, "Runner", Vector3(3.0, 0.0028, -11.0), Vector3(17.5, 0.002, 1.34), "carpet_runner")
	# A bench with a back (0.9 m, so the navmesh is not baked on its seat).
	var bench := _upper_prop(solid, "CorridorBench", [-5.2, -8.6, -3.6, -8.15], 0.9)
	for k in 3:
		_add_visual_box(bench, "Slat%d" % k, Vector3(0, 0.44, -0.17 + k * 0.11), Vector3(1.6, 0.03, 0.09), "oak")
	for k in 3:
		_add_visual_box(bench, "BackSlat%d" % k, Vector3(0, 0.58 + k * 0.12, 0.19), Vector3(1.6, 0.08, 0.03), "oak")
	for sx in [-0.7, 0.7]:
		_add_visual_box(bench, "Leg%d" % int(sx * 10), Vector3(sx, 0.21, 0), Vector3(0.05, 0.42, 0.4), "steel_beam")
		_add_visual_box(bench, "BackPost%d" % int(sx * 10), Vector3(sx, 0.66, 0.2), Vector3(0.05, 0.5, 0.03), "steel_beam")
	var bins := _upper_prop(solid, "RecyclingBins", [5.0, -8.6, 6.0, -8.15], 0.85)
	for k in 2:
		var bx := -0.25 + k * 0.5
		_add_visual_box(bins, "Bin%d" % k, Vector3(bx, 0.4, 0), Vector3(0.46, 0.8, 0.42), "motor_blue" if k == 0 else "cabinet_green")
		_add_visual_box(bins, "Lid%d" % k, Vector3(bx, 0.82, 0), Vector3(0.48, 0.04, 0.44), "tool_dark")
		_add_visual_box(bins, "Slot%d" % k, Vector3(bx, 0.842, 0.05), Vector3(0.24, 0.004, 0.06), "wire_black")
		_add_visual_box(bins, "Sticker%d" % k, Vector3(bx, 0.6, -0.212), Vector3(0.16, 0.16, 0.004), "card_white")
	var cooler := _upper_prop(solid, "WaterCooler", [10.6, -8.55, 11.0, -8.15], 1.3)
	_add_visual_box(cooler, "Cabinet", Vector3(0, 0.47, 0), Vector3(0.36, 0.94, 0.36), "card_white")
	_add_visual_box(cooler, "Tray", Vector3(0, 0.72, -0.19), Vector3(0.2, 0.02, 0.06), "tool_dark")
	_add_visual_box(cooler, "TapBlue", Vector3(-0.05, 0.84, -0.19), Vector3(0.03, 0.05, 0.03), "motor_blue")
	_add_visual_box(cooler, "TapRed", Vector3(0.05, 0.84, -0.19), Vector3(0.03, 0.05, 0.03), "pipe_red")
	_add_visual_box(cooler, "Bottle", Vector3(0, 1.1, 0), Vector3(0.26, 0.36, 0.26), "wired_glass")
	_add_visual_box(cooler, "Cap", Vector3(0, 0.935, 0), Vector3(0.12, 0.03, 0.12), "motor_blue")


## The staff balcony: oak tables with chairs, lamps and books (their bodies unchanged),
## rugs, the steel railing over the lobby (its Railing body unchanged), a break area
## (counter with a coffee machine, a sofa, a coffee table), planters and a book trolley.
func _staff_balcony(solid: Node3D, d: Node3D) -> void:
	var b := Node3D.new()
	b.name = "Balcony"
	_add(d, b)
	var k := 0
	for t in BALCONY_TABLES:
		var rug := Node3D.new()
		rug.name = "Rug%d" % k
		rug.position = t
		_add(b, rug)
		_add_visual_box(rug, "Border", Vector3(0, 0.0015, 0), Vector3(4.4, 0.002, 3.2), "carpet_gold")
		_add_visual_box(rug, "Field", Vector3(0, 0.003, 0), Vector3(4.2, 0.002, 3.0), "carpet_runner")
		var g := Node3D.new()
		g.name = "Table%d" % k
		g.position = t
		_add(b, g)
		_library_table(g, k + 2)
		var c := 0
		for side in [-1.0, 1.0]:
			for x in [-0.75, 0.75]:
				var ch := Node3D.new()
				ch.name = "Chair%d" % c
				ch.position = Vector3(x, 0, side * 0.64)
				ch.rotation_degrees = Vector3(0, 0.0 if side < 0 else 180.0, 0)
				_add(g, ch)
				_library_chair(ch)
				c += 1
		k += 1
	# The steel railing (x −8.85…12, z 10, 1.1 m): posts, rails and mesh panels.
	var r := Node3D.new()
	r.name = "Railing"
	r.position = Vector3(0, 0, 10.0)
	_add(b, r)
	var x0 := -8.85
	var x1 := 11.85
	var n := ceili((x1 - x0) / 1.5)
	var step := (x1 - x0) / n
	for i in n + 1:
		_add_visual_box(r, "Post%02d" % i, Vector3(x0 + i * step, 0.55, 0), Vector3(0.07, 1.1, 0.07), "steel_beam")
	_add_visual_box(r, "TopRail", Vector3((x0 + x1) / 2.0, 1.085, 0), Vector3(x1 - x0, 0.05, 0.1), "steel_shelf")
	_add_visual_box(r, "MidRail", Vector3((x0 + x1) / 2.0, 0.55, 0), Vector3(x1 - x0, 0.03, 0.05), "steel_beam")
	_add_visual_box(r, "BottomRail", Vector3((x0 + x1) / 2.0, 0.1, 0), Vector3(x1 - x0, 0.06, 0.08), "steel_beam")
	for i in n:
		_add_visual_box(r, "Mesh%02d" % i, Vector3(x0 + (i + 0.5) * step, 0.59, 0), Vector3(step - 0.08, 0.92, 0.012), "mesh_panel")
	# Break area against the east wall (x 12): kitchen counter, sofa and coffee table.
	var counter := _upper_prop(solid, "BreakCounter", [11.2, -7.75, 11.85, -5.75], 0.92)
	_add_visual_box(counter, "Base", Vector3(0, 0.43, 0), Vector3(0.6, 0.86, 2.0), "oak_dark")
	for k2 in 3:
		_add_visual_box(counter, "Door%d" % k2, Vector3(-0.306, 0.45, -0.66 + k2 * 0.66), Vector3(0.012, 0.72, 0.62), "oak")
		_add_visual_box(counter, "Knob%d" % k2, Vector3(-0.316, 0.7, -0.4 + k2 * 0.66), Vector3(0.02, 0.04, 0.04), "brass")
	_add_visual_box(counter, "Worktop", Vector3(-0.01, 0.89, 0), Vector3(0.64, 0.04, 2.0), "keypad_bezel")
	_add_visual_box(counter, "Sink", Vector3(0.0, 0.912, 0.55), Vector3(0.4, 0.006, 0.45), "tool_steel")
	_add_visual_box(counter, "Faucet", Vector3(0.18, 1.0, 0.55), Vector3(0.03, 0.18, 0.03), "tool_steel")
	_add_visual_box(counter, "Machine", Vector3(0.05, 1.1, -0.55), Vector3(0.34, 0.38, 0.3), "tool_dark")
	_add_visual_box(counter, "MachineDisplay", Vector3(-0.124, 1.2, -0.55), Vector3(0.004, 0.06, 0.12), "screen_lit")
	_add_visual_box(counter, "MachineLed", Vector3(-0.124, 1.12, -0.48), Vector3(0.004, 0.02, 0.02), "led_green")
	_add_visual_box(counter, "MachineSpout", Vector3(-0.1, 0.99, -0.55), Vector3(0.06, 0.05, 0.08), "tool_steel")
	_add_visual_box(counter, "Kettle", Vector3(0.05, 1.0, 0.0), Vector3(0.16, 0.2, 0.16), "card_white")
	for m in 3:
		_add_visual_box(counter, "Mug%d" % m, Vector3(-0.15, 0.96, -0.15 + m * 0.11), Vector3(0.08, 0.1, 0.08), ["pipe_red", "motor_blue", "card_white"][m])
	var sofa := _upper_prop(solid, "BreakSofa", [11.0, -2.7, 11.85, -0.5], 0.85)
	_add_visual_box(sofa, "Base", Vector3(0, 0.2, 0), Vector3(0.84, 0.3, 2.2), "fabric_green")
	for s in 2:
		_add_visual_box(sofa, "Cushion%d" % s, Vector3(-0.06, 0.41, -0.5 + s * 1.0), Vector3(0.62, 0.12, 0.96), "fabric_green")
	_add_visual_box(sofa, "Back", Vector3(0.32, 0.6, 0), Vector3(0.2, 0.5, 2.2), "fabric_green")
	for e in [-1.0, 1.0]:
		_add_visual_box(sofa, "Arm%d" % int(e), Vector3(0, 0.48, e * 1.03), Vector3(0.84, 0.26, 0.14), "fabric_green")
	_add_visual_box(sofa, "Pillow", Vector3(0.15, 0.62, -0.75), Vector3(0.14, 0.32, 0.32), "carpet_gold")
	var coffee := _upper_prop(solid, "BreakTable", [9.7, -2.1, 10.5, -1.1], 0.7)   # taller than the table: no navmesh on its top
	_add_visual_box(coffee, "Top", Vector3(0, 0.43, 0), Vector3(0.8, 0.04, 1.0), "oak")
	for lx in [-0.34, 0.34]:
		for lz in [-0.44, 0.44]:
			_add_visual_box(coffee, "Leg%d_%d" % [int(lx * 100), int(lz * 100)], Vector3(lx, 0.205, lz), Vector3(0.05, 0.41, 0.05), "oak_dark")
	_add_visual_box(coffee, "Magazine", Vector3(0.1, 0.458, 0.15), Vector3(0.22, 0.016, 0.3), "poster_c")
	_add_visual_box(coffee, "Cup", Vector3(-0.15, 0.49, -0.25), Vector3(0.07, 0.08, 0.07), "card_white")
	# Planters along the railing and a book trolley by the east wall.
	for px in [-4.0, 1.5, 9.5]:
		var p := _upper_prop(solid, "Planter%d" % int(px * 10), [px - 0.35, 9.35, px + 0.35, 9.85], 0.9)
		_add_visual_box(p, "Box", Vector3(0, 0.25, 0), Vector3(0.7, 0.5, 0.5), "oak_dark")
		_add_visual_box(p, "Rim", Vector3(0, 0.51, 0), Vector3(0.74, 0.03, 0.54), "oak")
		for f in 3:
			_add_visual_box(p, "Foliage%d" % f, Vector3(-0.18 + f * 0.18, 0.66 + (f % 2) * 0.08, 0), Vector3(0.3, 0.3, [0.4, 0.34, 0.37][f]), "foliage" if f % 2 == 0 else "foliage_light")   # depths differ: no shared faces
	var trolley := _upper_prop(solid, "BalconyTrolley", [11.35, 5.4, 11.85, 6.8], 1.0)
	_book_trolley(trolley, Vector3(0.5, 1.0, 1.4), 3)


## The staff wing's ceiling (8.0 m, as the upper stacks'): light panels per room, steel
## beams continuing the stacks' (z −18.5, −9, 0.5), strip lights (surface-mounted in the
## offices and the corridor, hanging on the balcony). The round fixtures are hidden by
## fixes_x13.gd; the lamps are unchanged.
func _staff_ceiling(ceilings: Node3D) -> void:
	var u := Node3D.new()
	u.name = "StaffCeiling"
	_add(ceilings, u)
	var top := STAFF_Y + 3.5
	var rooms := [[-5.85, -27.85, -0.15, -14.15, 1, 3], [0.15, -27.85, 5.85, -14.15, 1, 3], [6.15, -27.85, 11.85, -14.15, 1, 3],
		[-5.85, -13.85, 11.85, -8.15, 3, 1], [-6.15, -7.85, 11.85, 10.0, 3, 3]]
	var k := 0
	for r in rooms:
		var nx: int = r[4]
		var nz: int = r[5]
		var w: float = (r[2] - r[0]) / nx
		var l: float = (r[3] - r[1]) / nz
		for i in nx:
			for j in nz:
				_add_visual_box(u, "Panel%02d" % k, Vector3(r[0] + w * (i + 0.5), top - 0.03, r[1] + l * (j + 0.5)), Vector3(w, 0.04, l), "ceiling")
				k += 1
	for bz in [-18.5, -9.0, 0.5]:
		var bx0: float = -6.15 if bz > 0.0 else -5.85
		var bx1 := 11.85
		var cx := (bx0 + bx1) / 2.0
		var len := bx1 - bx0
		_add_visual_box(u, "BeamWeb%d" % int(bz * 10), Vector3(cx, top - 0.19, bz), Vector3(len, 0.28, 0.03), "steel_beam")
		_add_visual_box(u, "BeamTop%d" % int(bz * 10), Vector3(cx, top - 0.06, bz), Vector3(len, 0.02, 0.16), "steel_beam")
		_add_visual_box(u, "BeamBottom%d" % int(bz * 10), Vector3(cx, top - 0.32, bz), Vector3(len, 0.02, 0.16), "steel_beam")
	k = 0
	for i in 3:
		var c: float = -3.0 + 6.0 * i
		for sx in [-1.3, 1.3]:
			for z in [-25.6, -21.0, -16.4]:
				_add_visual_box(u, "OfficeHousing%02d" % k, Vector3(c + sx, top - 0.075, z), Vector3(0.22, 0.05, 1.25), "fluoro_housing")
				_add_visual_box(u, "OfficeDiffuser%02d" % k, Vector3(c + sx, top - 0.104, z), Vector3(0.16, 0.012, 1.18), "fluoro")
				k += 1
	var x := -4.8
	k = 0
	while x < 11.5:
		_add_visual_box(u, "CorridorHousing%02d" % k, Vector3(x, top - 0.075, -11.0), Vector3(1.25, 0.05, 0.22), "fluoro_housing")
		_add_visual_box(u, "CorridorDiffuser%02d" % k, Vector3(x, top - 0.104, -11.0), Vector3(1.18, 0.012, 0.16), "fluoro")
		x += 2.4
		k += 1
	k = 0
	for bx in [-4.5, -1.0, 2.5, 6.0, 9.5]:
		var z := -6.6
		while z < 9.4:
			_add_visual_box(u, "BalconyHousing%02d" % k, Vector3(bx, top - 0.4, z), Vector3(0.22, 0.05, 1.25), "fluoro_housing")
			_add_visual_box(u, "BalconyDiffuser%02d" % k, Vector3(bx, top - 0.429, z), Vector3(0.16, 0.012, 1.18), "fluoro")
			for e in [-0.5, 0.5]:
				_add_visual_box(u, "BalconyRod%02d_%d" % [k, int(e * 2)], Vector3(bx, top - 0.2, z + e), Vector3(0.01, 0.36, 0.01), "tool_dark")
			z += 2.4
			k += 1
	_set_layer_meta(u, Layout.LAYER_UPPER)


## The basement (zone G), concrete utility: grey concrete walls (their look, set in
## _build) with a painted lower band and a yellow line, sealed concrete floors, caged
## bulkhead lights (the lamps unchanged, their round fixtures hidden), ceiling services
## in the tunnel (a duct, cable bundles, pipe flanges and valves, hangers), floor markings
## (walkway lines, door stripes, drains), solid floor props clear of the basement
## guard's route, and steel treads, nosing and handrails on the two service stairs
## (their ramps unchanged). The storm drain keeps its own walls.
const BAND_H := 0.9
const BAND_SKIP := ["DrainWest", "DrainEast", "DrainEnd"]


func _build_basement(solid: Node3D, decor: Node3D) -> void:
	var b := Node3D.new()
	b.name = "Basement"
	_add(decor, b)
	_basement_bands(b)
	_basement_ceiling_services(b)
	_basement_floor_marks(b)
	for r in Layout.RAMPS:
		_dress_service_stair(b, r)
	_basement_props(solid)
	_bulkheads(b)
	_set_layer_meta(b, Layout.LAYER_BASEMENT)


## Caged bulkhead lights where the basement lamps' round fixtures were (hidden in _build),
## with a conduit up to the slab where there is a ceiling over them.
func _bulkheads(b: Node3D) -> void:
	var g := Node3D.new()
	g.name = "Bulkheads"
	_add(b, g)
	var k := 0
	for l in Layout.LIGHTS:
		if not l.basement:
			continue
		var at: Vector3 = l.pos + Vector3(0, 3.4 - Layout.BASEMENT_LAMP_DROP, 0)
		var h := Node3D.new()
		h.name = "Bulkhead%02d" % k
		h.position = at
		_add(g, h)
		_add_visual_box(h, "Back", Vector3(0, 0.05, 0), Vector3(0.34, 0.06, 0.24), "tool_dark")
		_add_visual_box(h, "Dome", Vector3(0, -0.02, 0), Vector3(0.28, 0.1, 0.18), "lamp_cream")
		for c in 3:
			_add_visual_box(h, "CageX%d" % c, Vector3(0, -0.075, -0.07 + c * 0.07), Vector3(0.32, 0.014, 0.014), "tool_dark")
		for c in 2:
			_add_visual_box(h, "CageZ%d" % c, Vector3(-0.1 + c * 0.2, -0.075, 0), Vector3(0.014, 0.014, 0.22), "tool_dark")
		for c in Layout.CEILINGS:
			var r: Array = c.rect
			if at.x > r[0] and at.x < r[2] and at.z > r[1] and at.z < r[3]:
				var top: float = c.y
				var len := top - (at.y + 0.08)
				if len > 0.05:
					_add_visual_box(h, "Conduit", Vector3(0, 0.08 + len / 2.0, 0), Vector3(0.03, len, 0.03), "conduit")
				break
		k += 1


func _basement_bands(b: Node3D) -> void:
	var g := Node3D.new()
	g.name = "WallBands"
	_add(b, g)
	for w in Layout.WALLS:
		if w.zone != "G" or w.y0 > Layout.BF + 0.5 or w.name in BAND_SKIP:
			continue
		var along_x: bool = w.a[1] == w.b[1]
		var lo: float = minf(w.a[0], w.b[0]) if along_x else minf(w.a[1], w.b[1])
		var hi: float = maxf(w.a[0], w.b[0]) if along_x else maxf(w.a[1], w.b[1])
		var mid := (lo + hi) / 2.0
		var t := Layout.WALL_T + 0.016
		var l := hi - lo + 0.016
		var top := minf(BAND_H, w.y1 - Layout.BF)
		var at := func(y: float) -> Vector3: return Vector3(mid, y, w.a[1]) if along_x else Vector3(w.a[0], y, mid)
		var size := func(h: float) -> Vector3: return Vector3(l, h, t) if along_x else Vector3(t, h, l)
		_add_visual_box(g, "Band_" + w.name, at.call(Layout.BF + top / 2.0), size.call(top), "band_paint")
		if w.y1 - Layout.BF > BAND_H + 0.05:
			_add_visual_box(g, "Line_" + w.name, at.call(Layout.BF + BAND_H + 0.025), size.call(0.05), "hazard_yellow")


## Above head height (2.6 m) only: a duct along the tunnel (a gap at the tunnel camera,
## as the cable tray's), cable bundles in the trays, square flanges on the pipes, three
## valves, hangers.
func _basement_ceiling_services(b: Node3D) -> void:
	var g := Node3D.new()
	g.name = "CeilingServices"
	_add(b, g)
	var y := Layout.BF + 3.57
	for seg in [[-35.6, 9.5], [14.5, 35.6]]:
		var x0: float = seg[0]
		var x1: float = seg[1]
		_add_visual_box(g, "Duct%d" % int(x0), Vector3((x0 + x1) / 2.0, y, -23.9), Vector3(x1 - x0, 0.3, 0.56), "duct_grey")
		var x := x0 + 0.75
		while x < x1 - 0.5:
			_add_visual_box(g, "DuctSeam%d" % int(x * 10), Vector3(x, y, -23.9), Vector3(0.05, 0.34, 0.6), "seam_dark")
			if int(round(x - x0 - 0.75)) % 3 == 0:
				_add_visual_box(g, "DuctHanger%d" % int(x * 10), Vector3(x, y + 0.165, -23.9), Vector3(0.03, 0.04, 0.66), "tool_dark")
			x += 1.5
	# Cable bundles in the existing trays (y BF + 3.2, z −23.4).
	for seg in [[-35.6, 9.5], [14.5, 36.1]]:
		var x0: float = seg[0]
		var x1: float = seg[1]
		_add_visual_box(g, "Cables%d" % int(x0), Vector3((x0 + x1) / 2.0, Layout.BF + 3.25, -23.42), Vector3(x1 - x0, 0.05, 0.26), "wire_black")
		_add_visual_box(g, "CablesRed%d" % int(x0), Vector3((x0 + x1) / 2.0, Layout.BF + 3.25, -23.25), Vector3(x1 - x0, 0.04, 0.05), "pipe_red")
	# Square flanges on the two north pipes every 4 m, valves on the red main.
	var fx := -42.0
	while fx < 45.0:
		if absf(fx) > 2.5:
			_add_visual_box(g, "Flange%d" % int(fx * 10), Vector3(fx, Layout.BF + 3.45, -26.72), Vector3(0.06, 0.32, 0.32), "pipe")
			_add_visual_box(g, "FlangeMain%d" % int(fx * 10), Vector3(fx + 2.0, Layout.BF + 3.15, -26.76), Vector3(0.05, 0.24, 0.24), "pipe_red")
		fx += 4.0
	for vx in [-20.0, 10.0, 30.0]:
		_add_visual_box(g, "ValveBody%d" % int(vx), Vector3(vx, Layout.BF + 3.15, -26.76), Vector3(0.22, 0.2, 0.2), "pipe_red")
		_add_visual_box(g, "ValveStem%d" % int(vx), Vector3(vx, Layout.BF + 2.98, -26.76), Vector3(0.03, 0.16, 0.03), "tool_steel")
		_add_visual_box(g, "ValveWheelX%d" % int(vx), Vector3(vx, Layout.BF + 2.9, -26.76), Vector3(0.3, 0.025, 0.025), "pipe_red")
		_add_visual_box(g, "ValveWheelZ%d" % int(vx), Vector3(vx, Layout.BF + 2.9, -26.76), Vector3(0.025, 0.025, 0.3), "pipe_red")
		_add_visual_box(g, "ValveTag%d" % int(vx), Vector3(vx + 0.12, Layout.BF + 2.82, -26.76), Vector3(0.004, 0.08, 0.06), "sticker_yellow")


## Flat on the floors (below the hiding spots' marks): walkway lines down the tunnel,
## hazard stripes across the doorways off it, floor drains.
func _basement_floor_marks(b: Node3D) -> void:
	var g := Node3D.new()
	g.name = "FloorMarks"
	_add(b, g)
	var y := Layout.BF + 0.003
	for z in [-23.75, -26.25]:
		_add_visual_box(g, "Walkway%d" % int(-z * 100), Vector3(1.0, y, z), Vector3(89.7, 0.002, 0.07), "hazard_yellow")
	for d in [["BayDoor", -24.0, -23.0, 2.0], ["PumpDoor", 0.0, -23.0, 2.0], ["Culvert", 0.0, -27.0, 4.0], ["Niche", -11.0, -27.0, 2.0]]:
		var w: float = d[3] / 6.0
		for i in 6:
			_add_visual_box(g, "%sStripe%d" % [d[0], i], Vector3(d[1] - d[3] / 2.0 + w * (i + 0.5), y + 0.001, d[2]), Vector3(w, 0.002, 0.28), "hazard_yellow" if i % 2 == 0 else "hazard_black")
	for p in [Vector3(-33.0, 0, -25.0), Vector3(-6.0, 0, -25.0), Vector3(22.0, 0, -25.0), Vector3(40.0, 0, -15.5), Vector3(-39.0, 0, -19.0)]:
		_add_visual_box(g, "Drain%d" % int(p.x), Vector3(p.x, y + 0.001, p.z), Vector3(0.36, 0.002, 0.36), "grille_steel")
		for k in 4:
			_add_visual_box(g, "DrainSlot%d_%d" % [int(p.x), k], Vector3(p.x - 0.12 + k * 0.08, y + 0.002, p.z), Vector3(0.03, 0.002, 0.3), "wire_black")


## A service stair (Layout.RAMPS entry): 20 steel treads with yellow nosing and risers on
## the ramp (the treads' tops meet the ramp at each step's back edge; the walked surface
## is still the ramp), and a handrail along both side walls.
func _dress_service_stair(b: Node3D, r: Dictionary) -> void:
	var s := Node3D.new()
	s.name = "Stair_" + r.name
	_add(b, s)
	var steps := 20
	var dir: float = signf(r.z_top - r.z_bottom)   # the way up along z
	var run: float = absf(r.z_top - r.z_bottom)
	var rise := -Layout.BF / steps
	var going := run / steps
	var xc: float = (r.x0 + r.x1) / 2.0
	var width: float = r.x1 - r.x0
	for i in steps:
		var z_front: float = r.z_bottom + dir * i * going
		var top := Layout.BF + (i + 1) * rise
		var zc: float = z_front + dir * (going / 2.0 - 0.015)
		_add_visual_box(s, "Tread%02d" % i, Vector3(xc, top - 0.02, zc), Vector3(width - 0.08, 0.04, going + 0.03), "tread_steel")
		_add_visual_box(s, "Nosing%02d" % i, Vector3(xc, top + 0.002, z_front - dir * 0.0), Vector3(width - 0.1, 0.006, 0.06), "hazard_yellow")
		_add_visual_box(s, "Riser%02d" % i, Vector3(xc, Layout.BF + i * rise + rise / 2.0 - 0.02, z_front - dir * 0.01), Vector3(width - 0.1, rise - 0.04, 0.02), "shutter_groove")
	var length := sqrt(run * run + Layout.BF * Layout.BF)
	var angle := atan2(-Layout.BF, run)
	var zm: float = (r.z_top + r.z_bottom) / 2.0
	var ym := Layout.BF / 2.0
	# Rotated about x so local +z runs along the slope: down towards +z when the stair goes
	# up towards −z (dir −1), and the reverse.
	var rot := Vector3(angle * -dir, 0, 0)
	for side in [[r.x0 + 0.05, "W"], [r.x1 - 0.05, "E"]]:
		var x: float = side[0]
		_add_box_r(s, "Handrail" + side[1], Vector3(x, ym + 0.9, zm), Vector3(0.05, 0.05, length - 0.4), "steel_shelf", rot)
		var n := 6
		for k in n:
			var f := (k + 0.5) / n
			var z: float = r.z_bottom + dir * f * run
			var slope_y: float = Layout.BF + f * -Layout.BF
			_add_visual_box(s, "Bracket%s%d" % [side[1], k], Vector3(x, slope_y + 0.83, z), Vector3(0.04, 0.12, 0.04), "tool_dark")


## Solid floor props, clear of the basement guard's route (P9: along z −25 from x −30 to
## 14, then the east basement at x 39), the main routes and the hiding spots; each is
## either taller than 0.8 m or under 0.7 m across (no navmesh island on its top).
func _basement_props(solid: Node3D) -> void:
	# West basement, along its east wall (clear of the way from the west stair to the
	# tunnel): a pallet stack, drums and a mop bucket.
	var pallet := _basement_prop(solid, "WestPalletStack", [-37.4, -19.9, -36.2, -18.9], 1.0)
	_pallet(pallet, "Pallet", Vector3(0, 0, 0), Vector3(1.2, 0.14, 1.0))
	for k in 4:
		_add_visual_box(pallet, "Box%d" % k, Vector3(-0.3 + (k % 2) * 0.6, 0.14 + 0.2 + (k / 2) * 0.42, 0.0), Vector3(0.56, 0.4, 0.92), "cardboard" if k % 2 == 0 else "cardboard_dark")
	_drums(_basement_prop(solid, "WestDrums", [-36.85, -21.4, -36.2, -20.15], 0.9), 2, true)
	# Tunnel, west of the guard's loop: a gas-cylinder cage (north wall).
	var cage := _basement_prop(solid, "GasCage", [-35.5, -26.85, -34.3, -26.25], 1.6)
	for ex in [-0.58, 0.58]:
		for ez in [-0.28, 0.28]:
			_add_visual_box(cage, "Post%d_%d" % [int(ex * 100), int(ez * 100)], Vector3(ex, 0.8, ez), Vector3(0.04, 1.6, 0.04), "release_yellow")
	_add_visual_box(cage, "Top", Vector3(0, 1.58, 0), Vector3(1.2, 0.03, 0.6), "release_yellow")
	_add_visual_box(cage, "MeshFront", Vector3(0, 0.85, 0.29), Vector3(1.12, 1.4, 0.01), "mesh_grey")
	for k in 4:
		var cx := -0.42 + k * 0.28
		_add_visual_cyl(cage, "Cylinder%d" % k, Vector3(cx, 0.7, -0.05), 0.11, 1.3, "y", "pipe_red" if k % 2 == 0 else "motor_dark", 8)
		_add_visual_box(cage, "CylinderCap%d" % k, Vector3(cx, 1.4, -0.05), Vector3(0.08, 0.1, 0.08), "tool_steel")
	var bucket := _basement_prop(solid, "MopBucket", [-36.6, -22.6, -36.2, -22.2], 0.4)
	_add_visual_box(bucket, "Bucket", Vector3(0, 0.15, 0), Vector3(0.36, 0.3, 0.36), "release_yellow")
	_add_visual_box(bucket, "Water", Vector3(0, 0.29, 0), Vector3(0.3, 0.01, 0.3), "water")
	_add_box_r(bucket, "MopHandle", Vector3(0.05, 0.75, -0.02), Vector3(0.03, 1.3, 0.03), "wood", Vector3(0, 0, 0.2))
	# Tunnel: a ladder leaning on the north wall (off the guard's line at z −25), drums.
	var ladder := _basement_prop(solid, "Ladder", [-19.9, -26.85, -19.3, -26.45], 2.2)
	for sx in [-0.25, 0.25]:
		_add_box_r(ladder, "Rail%d" % int(sx * 100), Vector3(sx, 1.08, 0.02), Vector3(0.05, 2.2, 0.06), "release_yellow", Vector3(0.12, 0, 0))
	for k in 7:
		_add_box_r(ladder, "Rung%d" % k, Vector3(0, 0.25 + k * 0.3, 0.12 - k * 0.036), Vector3(0.5, 0.03, 0.03), "tool_steel", Vector3(0.12, 0, 0))
	_drums(_basement_prop(solid, "TunnelDrums", [25.0, -26.85, 26.3, -26.2], 0.9), 2, false)
	# East basement and the cable bay: drums by the west wall, a pallet stack.
	_drums(_basement_prop(solid, "EastDrums", [36.5, -16.5, 37.15, -15.25], 0.9), 2, true)
	var pallet_e := _basement_prop(solid, "CableBayPallet", [45.0, -22.85, 45.85, -21.6], 1.0)
	_pallet(pallet_e, "Pallet", Vector3(0, 0, 0), Vector3(0.85, 0.14, 1.25))
	_add_visual_cyl(pallet_e, "Reel", Vector3(0, 0.5, 0), 0.36, 0.5, "x", "wood", 12)
	_add_visual_cyl(pallet_e, "ReelCable", Vector3(0, 0.5, 0), 0.26, 0.4, "x", "wire_black", 12)


## A solid prop on the basement floor (see _solid_prop).
func _basement_prop(solid: Node3D, node_name: String, rect: Array, h: float) -> Node3D:
	var model := _solid_prop(solid, node_name, rect, h)
	(model.get_parent() as Node3D).position.y += Layout.BF
	model.get_parent().set_meta("why", "basement prop (polish): solid; the model is its look")
	_set_layer_meta(model, Layout.LAYER_BASEMENT)
	return model


## `n` drums in a row along z (`along_z`) or x, 0.6 m across, 0.9 m tall.
func _drums(m: Node3D, n: int, along_z: bool) -> void:
	for k in n:
		var off := (k - (n - 1) / 2.0) * 0.63
		var at := Vector3(0, 0.45, off) if along_z else Vector3(off, 0.45, 0)
		_add_visual_cyl(m, "Drum%d" % k, at, 0.29, 0.88, "y", "motor_blue" if k % 2 == 0 else "rack_blue", 12)
		_add_visual_box(m, "Lid%d" % k, at + Vector3(0, 0.445, 0), Vector3(0.42, 0.01, 0.42), "tool_dark")
		_add_visual_box(m, "Label%d" % k, at + Vector3(0.0, 0.05, 0.0) + (Vector3(0.3, 0, 0) if along_z else Vector3(0, 0, 0.3)), Vector3(0.01, 0.22, 0.16) if along_z else Vector3(0.16, 0.22, 0.01), "card_white")


## The tool box room (maintenance bay, x −28…−20, z −23…−17): the crate under the tool
## kit drawn as two red rolling tool chests back to back (its collider unchanged, the kit
## on top where it was), a steel workbench with a vice, tools and a work lamp, parts
## shelving, a compressor, an oil drum, a step ladder and a cable reel (solid). Clear of
## the checkpoint pad, the respawn, the hiding spot, the shelf and the document.
func _build_tool_room(solid: Node3D, decor: Node3D) -> void:
	var by := Layout.BF
	var t := Node3D.new()
	t.name = "ToolRoom"
	_add(decor, t)
	var chest := Node3D.new()
	chest.name = "ToolChests"
	chest.position = Vector3(-26.8, by, -20.2)   # the BayCrate's centre (its collider: 1.6 × 1.2 × 1.6)
	_add(t, chest)
	for side in [-1.0, 1.0]:
		var zc: float = side * 0.4
		_add_visual_box(chest, "Body%d" % int(side), Vector3(0, 0.62, zc), Vector3(1.58, 1.0, 0.78), "restricted")
		_add_visual_box(chest, "Lid%d" % int(side), Vector3(0, 1.17, zc), Vector3(1.6, 0.06, 0.8), "tool_dark")
		_add_visual_box(chest, "Base%d" % int(side), Vector3(0, 0.08, zc), Vector3(1.5, 0.08, 0.72), "tool_dark")
		for k in 5:
			var y := 0.27 + k * 0.18
			_add_visual_box(chest, "Drawer%d_%d" % [int(side), k], Vector3(0, y, zc + side * 0.392), Vector3(1.48, 0.15, 0.012), "pipe_red")
			_add_visual_box(chest, "Handle%d_%d" % [int(side), k], Vector3(0, y + 0.04, zc + side * 0.402), Vector3(1.3, 0.025, 0.02), "tool_steel")
		for cx in [-0.68, 0.68]:
			_add_visual_box(chest, "Caster%d_%d" % [int(side), int(cx * 10)], Vector3(cx, 0.03, zc + side * 0.28), Vector3(0.08, 0.06, 0.08), "tool_dark")
	_add_visual_box(chest, "PushBar", Vector3(-0.86, 0.95, 0), Vector3(0.03, 0.03, 1.2), "tool_steel")
	# Workbench against the south wall, east of the document (x −22.3…−20.3).
	var bench := _basement_prop(solid, "Workbench", [-22.3, -17.85, -20.3, -17.15], 0.9)
	_add_visual_box(bench, "Top", Vector3(0, 0.88, 0), Vector3(2.0, 0.04, 0.7), "wood")
	_add_visual_box(bench, "Edge", Vector3(0, 0.84, -0.34), Vector3(2.0, 0.06, 0.03), "tool_steel")
	for lx in [-0.95, 0.95]:
		for lz in [-0.3, 0.3]:
			_add_visual_box(bench, "Leg%d_%d" % [int(lx * 100), int(lz * 100)], Vector3(lx, 0.43, lz), Vector3(0.05, 0.86, 0.05), "steel_beam")
	_add_visual_box(bench, "Shelf", Vector3(0, 0.15, 0), Vector3(1.9, 0.03, 0.62), "steel_shelf")
	_add_visual_box(bench, "Drawer", Vector3(0.55, 0.73, -0.33), Vector3(0.6, 0.16, 0.04), "tool_steel")
	_add_visual_box(bench, "ViceBase", Vector3(-0.75, 0.93, -0.25), Vector3(0.16, 0.06, 0.2), "motor_blue")
	_add_visual_box(bench, "ViceJaw0", Vector3(-0.75, 1.0, -0.31), Vector3(0.18, 0.1, 0.04), "motor_blue")
	_add_visual_box(bench, "ViceJaw1", Vector3(-0.75, 1.0, -0.2), Vector3(0.18, 0.1, 0.04), "motor_blue")
	_add_visual_box(bench, "ViceScrew", Vector3(-0.75, 1.0, -0.4), Vector3(0.02, 0.02, 0.16), "tool_steel")
	_add_visual_box(bench, "ViceBar", Vector3(-0.75, 1.0, -0.48), Vector3(0.2, 0.015, 0.015), "tool_steel")
	_add_box_r(bench, "Hammer", Vector3(-0.2, 0.91, -0.1), Vector3(0.3, 0.025, 0.03), "wood", Vector3(0, 0.4, 0))
	_add_box_r(bench, "HammerHead", Vector3(-0.07, 0.915, -0.15), Vector3(0.04, 0.035, 0.1), "tool_dark", Vector3(0, 0.4, 0))
	_add_box_r(bench, "Spanner", Vector3(0.1, 0.905, 0.05), Vector3(0.24, 0.01, 0.03), "tool_steel", Vector3(0, -0.3, 0))
	_add_box_r(bench, "Screwdriver", Vector3(0.25, 0.91, -0.15), Vector3(0.2, 0.02, 0.02), "release_yellow", Vector3(0, 0.6, 0))
	_add_visual_box(bench, "PartsTray", Vector3(0.6, 0.92, 0.1), Vector3(0.3, 0.04, 0.2), "tool_dark")
	for k in 3:
		_add_visual_box(bench, "Part%d" % k, Vector3(0.52 + k * 0.08, 0.95, 0.1), Vector3(0.04, 0.03, 0.04), "copper")
	_add_visual_box(bench, "LampBase", Vector3(0.85, 0.915, 0.2), Vector3(0.14, 0.03, 0.14), "tool_dark")
	_add_box_r(bench, "LampArm", Vector3(0.85, 1.1, 0.13), Vector3(0.025, 0.4, 0.025), "tool_dark", Vector3(-0.35, 0, 0))
	_add_box_r(bench, "LampHead", Vector3(0.85, 1.3, 0.02), Vector3(0.16, 0.08, 0.2), "release_yellow", Vector3(-0.5, 0, 0))
	_add_visual_box(bench, "LampGlow", Vector3(0.85, 1.255, -0.04), Vector3(0.1, 0.004, 0.12), "glow_sodium")
	# Parts shelving on the west wall, north of the chests (x −27.85…−27.4, z −22.8…−21.4).
	var sh := _basement_prop(solid, "PartsShelving", [-27.85, -22.8, -27.4, -21.4], 2.0)
	_steel_shelving(sh, Vector3(0.45, 2.0, 1.4), 3)
	for s in 4:
		var y := 0.08 + s * 0.45 + 0.1
		for k in 3:
			_add_visual_box(sh, "Bin%d_%d" % [s, k], Vector3(0.05, y, -0.45 + k * 0.45), Vector3(0.3, 0.16, 0.36), ["motor_blue", "rack_orange", "cabinet_green"][(s + k) % 3])
	# Floor equipment.
	var comp := _basement_prop(solid, "Compressor", [-21.4, -22.8, -20.4, -22.1], 0.9)
	_add_visual_cyl(comp, "Tank", Vector3(0, 0.3, 0), 0.26, 0.95, "x", "pipe_red", 12)
	_add_visual_box(comp, "Motor", Vector3(0.1, 0.68, 0), Vector3(0.4, 0.26, 0.3), "motor_dark")
	_add_visual_box(comp, "Gauge", Vector3(-0.25, 0.7, 0.0), Vector3(0.08, 0.08, 0.08), "gauge_face")
	_add_box_r(comp, "Handle", Vector3(-0.45, 0.6, 0), Vector3(0.03, 0.5, 0.3), "tool_dark", Vector3(0, 0, 0.3))
	for wz in [-0.25, 0.25]:
		_add_visual_box(comp, "Wheel%d" % int(wz * 100), Vector3(0.38, 0.08, wz), Vector3(0.16, 0.16, 0.05), "tool_dark")
	var drum := _basement_prop(solid, "OilDrum", [-20.95, -21.5, -20.35, -20.9], 0.9)
	_add_visual_cyl(drum, "Drum", Vector3(0, 0.45, 0), 0.29, 0.88, "y", "cabinet_green", 12)
	_add_visual_box(drum, "Lid", Vector3(0, 0.895, 0), Vector3(0.42, 0.01, 0.42), "tool_dark")
	_add_visual_box(drum, "Spill", Vector3(-0.35, 0.002, 0.1), Vector3(0.3, 0.004, 0.4), "wire_black")
	var steps := _basement_prop(solid, "StepLadder", [-25.9, -17.55, -25.3, -17.15], 1.8)
	for sx in [-0.26, 0.26]:
		_add_box_r(steps, "Rail%d" % int(sx * 100), Vector3(sx, 0.9, 0.0), Vector3(0.05, 1.8, 0.05), "tool_steel", Vector3(0.08, 0, 0))
	for k in 5:
		_add_visual_box(steps, "Step%d" % k, Vector3(0, 0.3 + k * 0.32, 0.05 - k * 0.025), Vector3(0.5, 0.03, 0.12), "tool_steel")
	var reel := _basement_prop(solid, "CableReel", [-21.9, -19.4, -21.3, -18.8], 0.5)
	_add_visual_cyl(reel, "Drum", Vector3(0, 0.25, 0), 0.25, 0.4, "z", "release_yellow", 12)
	_add_visual_cyl(reel, "Cable", Vector3(0, 0.25, 0), 0.19, 0.34, "z", "rack_orange", 12)
	_add_visual_box(reel, "Plug", Vector3(0.3, 0.02, 0.1), Vector3(0.08, 0.04, 0.05), "tool_dark")


## The restricted archive (upper floor, zone F: hall x 12…28 z −18…−6, stacks z −28…−18,
## vault x 28…36 z −28…−18, alcove z −18…−12, back gate G3 at x 30): an old rare-books
## archive. A bordered burgundy carpet, walnut shelving dressing (end panels, call cards,
## cornice, kick plate), walnut ceiling beams and brass pendants, the hall's oak reading
## desk with a book cradle, map cabinets and a display case (solid), the vault door as a
## round-boss steel vault door swinging open with the door, the manuscript's lit display
## case, vault shelving, a climate unit and a floor safe (solid), the alcove's conservation
## chest, a trolley and boxes, the back gate's steel leaves and status lamps, hazard
## stripes at the gate. The old look is removed by fixes_x15.gd; colliders unchanged.
const ARC_Y := 4.5


func _build_archive(solid: Node3D, decor: Node3D, ceilings: Node3D) -> void:
	var a := Node3D.new()
	a.name = "Archive"
	a.position = Vector3(0, ARC_Y, 0)
	_add(decor, a)
	_archive_carpet(a)
	var k := 0
	for c in MainLayout.COVER:
		if c.get("look", "") == "archive_shelf":
			for r in c.rects:
				_archive_row(a, "ArchiveRow%d" % k, r)
				k += 1
	_archive_desk(a)
	_archive_vault_case(a)
	_archive_chest(a)
	# Hazard stripes either side of the back gate (x 30, z −10…−8).
	for side in [-1.0, 1.0]:
		for i in 6:
			_add_visual_box(a, "GateStripe%d_%d" % [int(side), i], Vector3(30.0 + side * 0.42, 0.0025, -10.0 + (i + 0.5) / 3.0),
				Vector3(0.28, 0.004, 1.0 / 3.0), "hazard_yellow" if i % 2 == 0 else "hazard_black")
	# And at the front gate G2 (x 12, z −12…−10): inside the archive's carpet border, and on
	# the staff corridor's runner (lifted over it).
	for side in [-1.0, 1.0]:
		for i in 6:
			_add_visual_box(a, "FrontStripe%d_%d" % [int(side), i], Vector3(12.0 + side * 0.3, 0.0025 if side > 0 else 0.006, -12.0 + (i + 0.5) / 3.0),
				Vector3(0.28, 0.004, 1.0 / 3.0), "hazard_yellow" if i % 2 == 0 else "hazard_black")
	_archive_props(solid)
	_archive_ceiling(ceilings)
	_dress_vault_door()
	_dress_back_gate()
	_set_layer_meta(a, Layout.LAYER_UPPER)
	_set_layer_meta(solid, Layout.LAYER_UPPER)


## A border band, a gold line and gold fleurons on a 2 m grid over the archive's burgundy
## floor (hall and stacks, x 12…28, z −28…−6), below the floor marks.
func _archive_carpet(a: Node3D) -> void:
	var c := Node3D.new()
	c.name = "Carpet"
	_add(a, c)
	var x0 := 12.5
	var x1 := 27.5
	var z0 := -27.5
	var z1 := -6.5
	var y := 0.0025
	var bw := 0.3
	for e in [["N", Vector3((x0 + x1) / 2.0, y, z0 + bw / 2.0), Vector3(x1 - x0, 0.004, bw)], ["S", Vector3((x0 + x1) / 2.0, y, z1 - bw / 2.0), Vector3(x1 - x0, 0.004, bw)],
			["W", Vector3(x0 + bw / 2.0, y, (z0 + z1) / 2.0), Vector3(bw, 0.004, z1 - z0 - 2 * bw)], ["E", Vector3(x1 - bw / 2.0, y, (z0 + z1) / 2.0), Vector3(bw, 0.004, z1 - z0 - 2 * bw)]]:
		_add_visual_box(c, "Border" + e[0], e[1], e[2], "archive_border")
	var i0 := x0 + bw + 0.12
	var i1 := x1 - bw - 0.12
	var j0 := z0 + bw + 0.12
	var j1 := z1 - bw - 0.12
	for e in [["N", Vector3((i0 + i1) / 2.0, y, j0), Vector3(i1 - i0, 0.004, 0.04)], ["S", Vector3((i0 + i1) / 2.0, y, j1), Vector3(i1 - i0, 0.004, 0.04)],
			["W", Vector3(i0, y, (j0 + j1) / 2.0), Vector3(0.04, 0.004, j1 - j0)], ["E", Vector3(i1, y, (j0 + j1) / 2.0), Vector3(0.04, 0.004, j1 - j0)]]:
		_add_visual_box(c, "Line" + e[0], e[1], e[2], "carpet_gold")
	var k := 0
	var x := 14.0
	while x < 27.0:
		var z := -26.0
		while z < -7.0:
			var clear := absf(x - 19.5) > 0.8 or absf(z + 22.0) > 0.8   # the stacks aisle hiding spot
			for c2 in MainLayout.COVER:
				if c2.get("zone", "") == "F":
					for r in c2.rects:
						if x > r[0] - 0.3 and x < r[2] + 0.3 and z > r[1] - 0.3 and z < r[3] + 0.3:
							clear = false
			if clear:
				_add_box_r(c, "Fleuron%02d" % k, Vector3(x, y + 0.0006, z), Vector3(0.16, 0.004, 0.16), "carpet_gold", Vector3(0, PI / 4.0, 0))
				k += 1
			z += 2.0
		x += 2.0


## An archive shelf row (east-west, 0.6 m deep, 2.4 m tall): a walnut cornice and kick plate,
## walnut end panels with a brass call-card holder at both ends.
func _archive_row(parent: Node3D, node_name: String, r: Array) -> void:
	var g := Node3D.new()
	g.name = node_name
	g.position = Vector3((r[0] + r[2]) / 2.0, 0, (r[1] + r[3]) / 2.0)
	_add(parent, g)
	var l: float = r[2] - r[0]
	var d: float = r[3] - r[1]
	_add_visual_box(g, "Kick", Vector3(0, 0.035, 0), Vector3(l - 0.02, 0.07, d + 0.06), "walnut_dark")
	_add_visual_box(g, "Cornice", Vector3(0, 2.475, 0), Vector3(l + 0.08, 0.07, d + 0.12), "walnut_dark")
	for e in [-1.0, 1.0]:
		var x: float = e * (l / 2.0 + 0.015)
		_add_visual_box(g, "End%d" % int(e), Vector3(x, 1.2, 0), Vector3(0.03, 2.4, d + 0.07), "walnut")
		var o: float = e * (l / 2.0 + 0.03)   # the end panel's outer face
		_add_visual_box(g, "EndInset%d" % int(e), Vector3(o + e * 0.002, 1.15, 0), Vector3(0.004, 1.9, d - 0.12), "walnut_dark")
		_add_visual_box(g, "Holder%d" % int(e), Vector3(o + e * 0.01, 1.55, 0), Vector3(0.012, 0.12, 0.18), "brass")
		_add_visual_box(g, "Card%d" % int(e), Vector3(o + e * 0.019, 1.55, 0), Vector3(0.006, 0.095, 0.155), "card_white")
		for t in 2:
			_add_visual_box(g, "Text%d_%d" % [int(e), t], Vector3(o + e * 0.024, 1.57 - t * 0.035, -0.01 * t), Vector3(0.004, 0.012, 0.11 - t * 0.03), "wire_black")


## The hall's reading desk (the table's footprint x 18…22, z −10…−8.8, 0.8 m): walnut, with
## a book cradle and an open folio, white gloves, a magnifier, a pencil, a banker's lamp,
## and two chairs tucked in on its north side.
func _archive_desk(a: Node3D) -> void:
	var g := Node3D.new()
	g.name = "ReadingDesk"
	g.position = Vector3(20.0, 0, -9.4)
	_add(a, g)
	_add_visual_box(g, "Top", Vector3(0, 0.775, 0), Vector3(4.1, 0.05, 1.3), "walnut")
	_add_visual_box(g, "Leather", Vector3(0, 0.803, 0), Vector3(3.2, 0.004, 0.9), "fabric_green")
	for lx in [-1.92, 1.92]:
		for lz in [-0.52, 0.52]:
			_add_visual_box(g, "Leg%d_%d" % [int(lx * 100), int(lz * 100)], Vector3(lx, 0.365, lz), Vector3(0.1, 0.73, 0.1), "walnut_dark")
	for sz in [-0.5, 0.5]:
		_add_visual_box(g, "Apron%d" % int(sz * 10), Vector3(0, 0.68, sz), Vector3(3.74, 0.1, 0.03), "walnut_dark")
	_add_visual_box(g, "Modesty", Vector3(0, 0.34, 0.3), Vector3(3.6, 0.6, 0.02), "walnut")
	for sx in [-1.86, 1.86]:
		_add_visual_box(g, "End%d" % int(sx * 10), Vector3(sx, 0.34, 0), Vector3(0.02, 0.6, 0.9), "walnut")
	var t := 0.805
	# Book cradle: two grey foam wedges, an open folio on them.
	for s in [-1.0, 1.0]:
		_add_box_r(g, "Wedge%d" % int(s), Vector3(s * 0.2, t + 0.04, 0.05), Vector3(0.36, 0.06, 0.32), "panel_grey", Vector3(0, 0, -s * 0.3))
		_add_box_r(g, "Page%d" % int(s), Vector3(s * 0.2, t + 0.08, 0.05), Vector3(0.34, 0.012, 0.3), "paper", Vector3(0, 0, -s * 0.3))
	_add_visual_box(g, "Spine", Vector3(0, t + 0.03, 0.05), Vector3(0.05, 0.05, 0.31), "leather")
	_add_visual_box(g, "GloveL", Vector3(-0.75, t + 0.01, 0.25), Vector3(0.1, 0.02, 0.2), "card_white")
	_add_visual_box(g, "GloveR", Vector3(-0.62, t + 0.01, 0.28), Vector3(0.1, 0.02, 0.2), "card_white")
	_add_visual_cyl(g, "Lens", Vector3(0.7, t + 0.01, 0.2), 0.07, 0.012, "y", "wired_glass", 12)
	_add_box_r(g, "LensHandle", Vector3(0.82, t + 0.01, 0.28), Vector3(0.16, 0.02, 0.025), "brass", Vector3(0, -0.6, 0))
	_add_visual_box(g, "Pencil", Vector3(0.45, t + 0.006, 0.3), Vector3(0.15, 0.01, 0.01), "sticker_yellow")
	_add_visual_box(g, "Notepad", Vector3(0.45, t + 0.004, 0.18), Vector3(0.15, 0.008, 0.21), "paper")
	_add_visual_box(g, "BoxA", Vector3(1.5, t + 0.13, -0.3), Vector3(0.36, 0.26, 0.42), "archive_box")
	_add_visual_box(g, "BoxB", Vector3(1.5, t + 0.39, -0.3), Vector3(0.34, 0.26, 0.4), "archive_box")
	var l := Node3D.new()
	l.name = "Lamp"
	l.position = Vector3(-1.4, t, -0.35)
	_add(g, l)
	_add_visual_box(l, "Base", Vector3(0, 0.012, 0), Vector3(0.14, 0.024, 0.14), "brass")
	_add_visual_box(l, "Stem", Vector3(0, 0.17, 0), Vector3(0.02, 0.3, 0.02), "brass")
	_add_visual_box(l, "Shade", Vector3(0, 0.34, 0.03), Vector3(0.34, 0.08, 0.15), "lamp_green")
	_add_visual_box(l, "Glow", Vector3(0, 0.298, 0.03), Vector3(0.3, 0.004, 0.11), "glow_sodium")
	for x in [-0.8, 0.8]:
		var ch := Node3D.new()
		ch.name = "Chair%d" % int(x * 10)
		ch.position = Vector3(x, 0, -0.38)   # tucked in on the north side, inside the desk's collider
		_add(g, ch)
		_library_chair(ch)


## The vault's display case on the pedestal (its collider x 31…33, z −25.5…−24.5, 1.0 m): a
## walnut plinth with brass trim, a velvet cushion under the manuscript (its pickup
## unchanged), brass posts and rim (no panes: the manuscript stays in reach and in view)
## and a lit strip.
func _archive_vault_case(a: Node3D) -> void:
	var g := Node3D.new()
	g.name = "DisplayCase"
	g.position = Vector3(32.0, 0, -25.0)
	_add(a, g)
	_add_visual_box(g, "Plinth", Vector3(0, 0.47, 0), Vector3(1.96, 0.94, 0.96), "walnut")
	_add_visual_box(g, "PlinthBase", Vector3(0, 0.05, 0), Vector3(2.04, 0.1, 1.04), "walnut_dark")
	_add_visual_box(g, "Top", Vector3(0, 0.97, 0), Vector3(2.04, 0.06, 1.04), "walnut_dark")
	_add_visual_box(g, "Trim", Vector3(0, 0.9, 0), Vector3(2.0, 0.03, 1.0), "brass")
	_add_visual_box(g, "Cushion", Vector3(0, 1.01, 0), Vector3(0.7, 0.02, 0.5), "rug_red")
	_add_visual_box(g, "Plaque", Vector3(0, 0.75, 0.487), Vector3(0.4, 0.1, 0.006), "brass")
	_add_text(g, "PlaqueText", Vector3(0, 0.75, 0.491), "RARE MANUSCRIPT", 18, 0.0014, Color(0.12, 0.08, 0.03))
	for sx in [-0.9, 0.9]:
		for sz in [-0.42, 0.42]:
			_add_visual_box(g, "Post%d_%d" % [int(sx * 10), int(sz * 100)], Vector3(sx, 1.28, sz), Vector3(0.03, 0.56, 0.03), "brass")
	for sz in [-0.42, 0.42]:
		_add_visual_box(g, "RimX%d" % int(sz * 100), Vector3(0, 1.565, sz), Vector3(1.83, 0.025, 0.025), "brass")
	for sx in [-0.9, 0.9]:
		_add_visual_box(g, "RimZ%d" % int(sx * 10), Vector3(sx, 1.565, 0), Vector3(0.025, 0.025, 0.87), "brass")
	_add_visual_box(g, "Glow", Vector3(0, 1.005, -0.42), Vector3(1.6, 0.01, 0.02), "lamp_cream")


## The alcove crate (its collider x 31.5…33.5, z −16.5…−14.5, 1.2 m) as a conservation chest.
func _archive_chest(a: Node3D) -> void:
	var g := Node3D.new()
	g.name = "ConservationChest"
	g.position = Vector3(32.5, 0, -15.5)
	_add(a, g)
	_add_visual_box(g, "Body", Vector3(0, 0.55, 0), Vector3(1.96, 1.0, 1.96), "walnut")
	_add_visual_box(g, "Lid", Vector3(0, 1.13, 0), Vector3(2.0, 0.14, 2.0), "walnut_dark")
	_add_visual_box(g, "Base", Vector3(0, 0.03, 0), Vector3(1.9, 0.06, 1.9), "walnut_dark")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_visual_box(g, "Corner%d_%d" % [int(sx), int(sz)], Vector3(sx * 0.97, 0.6, sz * 0.97), Vector3(0.08, 1.16, 0.08), "brass")
	for s in [-1.0, 1.0]:
		_add_visual_box(g, "Band%d" % int(s), Vector3(0, 0.55, s * 0.985), Vector3(1.8, 0.06, 0.012), "brass")
		_add_visual_box(g, "Handle%d" % int(s), Vector3(s * 0.99, 0.8, 0), Vector3(0.02, 0.05, 0.3), "brass")
	_add_visual_box(g, "Label", Vector3(0, 0.75, 0.987), Vector3(0.36, 0.14, 0.004), "card_white")
	_add_visual_box(g, "LabelText", Vector3(0, 0.77, 0.991), Vector3(0.26, 0.015, 0.004), "wire_black")
	_add_visual_box(g, "Lock", Vector3(0, 1.02, 1.004), Vector3(0.1, 0.12, 0.012), "brass")


## Solid props, clear of the archive guard's loop (P7: (14,−9) → (23.2,−9) → (26.5,−15) →
## (26.5,−26) → (14,−26)), G2, the keypad and the way to the manuscript.
func _archive_props(solid: Node3D) -> void:
	# Hall, along its north wall (z −6): two map cabinets and a display case.
	for mc in [["MapCabinetWest", 13.2], ["MapCabinetEast", 23.6]]:
		var m := _upper_prop(solid, mc[0], [mc[1], -7.05, mc[1] + 1.4, -6.2], 0.95)
		_add_visual_box(m, "Body", Vector3(0, 0.47, 0), Vector3(1.4, 0.94, 0.85), "walnut")
		_add_visual_box(m, "Top", Vector3(0, 0.935, 0), Vector3(1.44, 0.03, 0.88), "walnut_dark")
		for dr in 6:
			var y := 0.1 + dr * 0.135
			_add_visual_box(m, "Drawer%d" % dr, Vector3(0, y + 0.06, -0.428), Vector3(1.3, 0.11, 0.012), "walnut_dark")
			_add_visual_box(m, "Pull%d" % dr, Vector3(0, y + 0.07, -0.437), Vector3(0.3, 0.02, 0.012), "brass")
			_add_visual_box(m, "Card%d" % dr, Vector3(-0.4, y + 0.07, -0.436), Vector3(0.1, 0.05, 0.004), "card_white")
		_add_visual_cyl(m, "Roll", Vector3(0.1, 0.99, 0.0), 0.04, 0.9, "x", "paper", 8)
	var case := _upper_prop(solid, "BookDisplayCase", [16.0, -7.05, 18.0, -6.2], 1.2)
	_add_visual_box(case, "Base", Vector3(0, 0.36, 0), Vector3(2.0, 0.72, 0.85), "walnut")
	_add_visual_box(case, "Deck", Vector3(0, 0.735, 0), Vector3(2.0, 0.03, 0.85), "rug_red")
	for sx in [-0.97, 0.97]:
		for sz in [-0.4, 0.4]:
			_add_visual_box(case, "Post%d_%d" % [int(sx * 100), int(sz * 100)], Vector3(sx, 0.96, sz), Vector3(0.03, 0.46, 0.03), "brass")
	for sz in [-0.4, 0.4]:
		_add_visual_box(case, "RimX%d" % int(sz * 100), Vector3(0, 1.19, sz), Vector3(1.97, 0.025, 0.025), "brass")
	for sx in [-0.97, 0.97]:
		_add_visual_box(case, "RimZ%d" % int(sx * 100), Vector3(sx, 1.19, 0), Vector3(0.025, 0.025, 0.83), "brass")
	for i in 4:
		_add_box_r(case, "Book%d" % i, Vector3(-0.66 + i * 0.44, 0.86, 0.05), Vector3(0.26, 0.2, 0.04), ["leather", "cabinet_green", "motor_dark", "leather"][i], Vector3(-0.35, 0, 0))
		_add_visual_box(case, "Stand%d" % i, Vector3(-0.66 + i * 0.44, 0.76, 0.1), Vector3(0.2, 0.02, 0.08), "brass")
	# Vault: steel shelving on the east wall, a climate unit, a floor safe.
	var k := 0
	for r in [[35.35, -27.6, 35.8, -25.6], [35.35, -22.6, 35.8, -20.6]]:
		var sh := _upper_prop(solid, "VaultShelving%d" % k, r, 2.0)
		_steel_shelving(sh, Vector3(0.45, 2.0, 2.0), k + 1)
		k += 1
	var cu := _upper_prop(solid, "ClimateUnit", [28.25, -27.8, 29.25, -27.3], 1.7)
	_add_visual_box(cu, "Body", Vector3(0, 0.85, 0), Vector3(1.0, 1.7, 0.5), "panel_grey")
	_add_visual_box(cu, "Grille", Vector3(0, 1.25, 0.252), Vector3(0.8, 0.5, 0.006), "grille_steel")
	_add_visual_box(cu, "Display", Vector3(0.25, 0.75, 0.252), Vector3(0.2, 0.1, 0.006), "screen_lit")
	_add_visual_box(cu, "Led", Vector3(0.25, 0.62, 0.252), Vector3(0.03, 0.03, 0.006), "led_green")
	_add_visual_box(cu, "Tag", Vector3(-0.25, 0.7, 0.253), Vector3(0.24, 0.16, 0.004), "card_white")
	var safe := _upper_prop(solid, "FloorSafe", [33.8, -18.95, 34.8, -18.2], 0.9)
	_add_visual_box(safe, "Body", Vector3(0, 0.45, 0), Vector3(1.0, 0.9, 0.75), "tool_dark")
	_add_visual_box(safe, "Door", Vector3(0, 0.45, -0.38), Vector3(0.8, 0.7, 0.012), "keypad_bezel")
	_add_visual_cyl(safe, "Dial", Vector3(-0.15, 0.5, -0.39), 0.07, 0.03, "z", "tool_steel", 12)
	_add_visual_box(safe, "Handle", Vector3(0.2, 0.45, -0.395), Vector3(0.04, 0.2, 0.03), "tool_steel")
	# Alcove: a trolley by its east wall and a stack of boxes by the hall.
	var trolley := _upper_prop(solid, "AlcoveTrolley", [35.25, -17.8, 35.8, -16.4], 1.0)
	_book_trolley(trolley, Vector3(0.55, 1.0, 1.4), 3)
	var boxes := _upper_prop(solid, "AlcoveBoxes", [28.3, -17.8, 29.3, -16.9], 0.62)
	for i in 3:
		_add_box_r(boxes, "Box%d" % i, Vector3(-0.22 + (i % 2) * 0.44, 0.15 + (0.0 if i < 2 else 0.31), 0.0), Vector3(0.42, 0.3, 0.86 if i < 2 else 0.6), "archive_box", Vector3(0, 0.0 if i < 2 else 0.15, 0))


## Walnut beams across the hall and the stacks and brass pendants where the round fixtures
## were (the lamps unchanged; their fixtures hidden by fixes_x15.gd).
func _archive_ceiling(ceilings: Node3D) -> void:
	var u := Node3D.new()
	u.name = "ArchiveCeiling"
	_add(ceilings, u)
	var top := ARC_Y + 3.5
	for bz in [-9.0, -15.0, -21.0, -27.0]:
		_add_visual_box(u, "Beam%d" % int(-bz), Vector3(20.0, top - 0.16, bz), Vector3(15.7, 0.3, 0.22), "walnut_dark")
	var k := 0
	for p in [Vector3(16, 0, -12), Vector3(24, 0, -12), Vector3(16, 0, -23), Vector3(24, 0, -23), Vector3(32, 0, -23), Vector3(32, 0, -15), Vector3(33, 0, -9)]:
		var g := Node3D.new()
		g.name = "Pendant%d" % k
		g.position = Vector3(p.x, top, p.z)
		_add(u, g)
		_add_visual_box(g, "Canopy", Vector3(0, -0.03, 0), Vector3(0.18, 0.05, 0.18), "brass")
		_add_visual_box(g, "Rod", Vector3(0, -0.17, 0), Vector3(0.02, 0.24, 0.02), "brass")
		_add_visual_box(g, "Cap", Vector3(0, -0.31, 0), Vector3(0.12, 0.04, 0.12), "brass")
		_add_visual_box(g, "Shade", Vector3(0, -0.43, 0), Vector3(0.38, 0.2, 0.38), "lamp_cream")
		_add_visual_box(g, "Rim", Vector3(0, -0.535, 0), Vector3(0.4, 0.02, 0.4), "brass")
		k += 1
	_set_layer_meta(u, Layout.LAYER_UPPER)


## The vault door (Expansion/Gameplay/VaultDoor, x 28, z −22…−20): one thick steel leaf
## hinged at its south jamb (z −20) with a round boss, a handwheel and locking bolts,
## swinging into the vault along its north wall's side when the keypad opens the door
## (AccessDoor leaf_paths; clear of the way to the manuscript), and status lamps over it on
## both sides. The panel keeps its collision.
func _dress_vault_door() -> void:
	var door := _root.get_node("Gameplay/VaultDoor") as Node3D
	var h: float = Layout.DOOR_HEIGHT
	var w := 2.0
	var floor_y := -1.2
	var hinge := Node3D.new()
	hinge.name = "Leaf"
	hinge.position = Vector3(-0.07, floor_y, w / 2.0)
	_add(door, hinge)
	var zc := -w / 2.0   # the leaf's middle, from the hinge
	var f := 0.01        # the leaf's hall face (x), from the hinge
	_add_visual_box(hinge, "Slab", Vector3(f + 0.15, h / 2.0 - 0.01, zc), Vector3(0.3, h - 0.04, w - 0.04), "door_steel")
	_add_visual_box(hinge, "Edge", Vector3(f - 0.002, h / 2.0 - 0.01, zc), Vector3(0.004, h - 0.14, w - 0.14), "tool_steel")
	_add_visual_cyl(hinge, "Boss", Vector3(f - 0.024, 1.3, zc), 0.78, 0.04, "x", "shutter_steel", 24)
	_add_visual_cyl(hinge, "BossRing", Vector3(f - 0.05, 1.3, zc), 0.62, 0.02, "x", "tool_steel", 24)
	_add_visual_cyl(hinge, "Hub", Vector3(f - 0.11, 1.3, zc), 0.1, 0.12, "x", "brass", 12)
	for s in 4:
		_add_box_r(hinge, "Spoke%d" % s, Vector3(f - 0.13, 1.3, zc), Vector3(0.03, 0.7, 0.04), "brass", Vector3(s * PI / 4.0, 0, 0))
	_add_ring(hinge, "Wheel", Vector3(f - 0.13, 1.3, zc), 0.31, 0.36, "brass")
	(hinge.get_node("Wheel") as Node3D).rotation = Vector3(0, 0, PI / 2.0)   # facing −x
	for b in 8:
		var ang := TAU * b / 8.0
		_add_visual_box(hinge, "Bolt%d" % b, Vector3(f - 0.015, 1.3 + sin(ang) * 0.86, zc + cos(ang) * 0.86), Vector3(0.03, 0.09, 0.09), "tool_steel")
	for y in [0.45, 2.1]:
		_add_visual_box(hinge, "HingeBlock%d" % int(y * 10), Vector3(f + 0.05, y, -0.08), Vector3(0.2, 0.32, 0.12), "keypad_bezel")
	var leaves: Array[NodePath] = [door.get_path_to(hinge)]
	door.set("leaf_paths", leaves)
	door.set("leaf_open_angles", PackedFloat32Array([-90.0]))
	var lamps: Array[NodePath] = []
	for side in [-1.0, 1.0]:
		var lamp := MeshInstance3D.new()
		lamp.name = "Lamp%s" % ("West" if side < 0 else "East")
		lamp.mesh = _box_mesh(Vector3(0.03, 0.05, 0.4))
		lamp.position = Vector3(side * 0.2, floor_y + h + 0.17, 0)
		_add(door, lamp)
		lamps.append(door.get_path_to(lamp))
	door.set("status_light_paths", lamps)
	_set_layer_meta(door, Layout.LAYER_UPPER)


## The archive's two gates in one style: the back gate G3 (the level's
## Gameplay/ArchiveBackGateG3, x 30, z −10…−8) and the front gate G2 (Gameplay/
## ArchiveFrontGateG2, x 12, z −12…−10, the staff card): two steel leaves (wired-glass
## vision panels, a chevron band, kick plates, a push bar) hinged at the jambs and swinging
## away from the approach (+x), status lamps over them on both sides, and at G2 a card
## reader with its LED on the staff corridor side. Built here in Expansion/Gameplay;
## fixes_x15.gd (G3) and fixes_x18.gd (G2) point the gates at them.
func _dress_back_gate() -> void:
	_dress_archive_gate("ArchiveBackGateDressing", Vector3(30.0, ARC_Y + 1.2, -9.0), false)
	_dress_archive_gate("ArchiveFrontGateDressing", Vector3(12.0, ARC_Y + 1.2, -11.0), true)


func _dress_archive_gate(node_name: String, at: Vector3, reader: bool) -> void:
	var g := Node3D.new()
	g.name = node_name
	g.position = at
	_add(_root.get_node("Gameplay"), g)
	var h: float = Layout.DOOR_HEIGHT
	var w := 2.0
	var floor_y := -1.2
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "Leaf%s" % ("North" if side < 0 else "South")
		hinge.position = Vector3(0, floor_y, side * w / 2.0)
		_add(g, hinge)
		var dz: float = -side
		var half := w / 2.0 - 0.02
		_add_visual_box(hinge, "Leaf", Vector3(0, h / 2.0 - 0.01, dz * half / 2.0), Vector3(0.06, h - 0.04, half), "door_steel")
		_add_visual_box(hinge, "Glass", Vector3(0, 1.7, dz * half * 0.5), Vector3(0.066, 0.5, 0.3), "wired_glass")
		for y in [1.55, 1.7, 1.85]:
			_add_visual_box(hinge, "Wire%d" % int(y * 100), Vector3(0, y, dz * half * 0.5), Vector3(0.068, 0.006, 0.3), "keypad_bezel")
		for i in 5:
			_add_visual_box(hinge, "Chevron%d" % i, Vector3(0, 0.55, dz * (0.115 + i * 0.19)), Vector3(0.066, 0.14, 0.19), "hazard_yellow" if i % 2 == 0 else "hazard_black")
		_add_visual_box(hinge, "Kick", Vector3(0, 0.12, dz * half / 2.0), Vector3(0.066, 0.2, half - 0.06), "tool_steel")
		_add_visual_box(hinge, "PushBar", Vector3(-0.07, 1.05, dz * half / 2.0), Vector3(0.04, 0.05, half - 0.2), "tool_steel")
		for y in [0.3, 1.3, 2.3]:
			_add_visual_box(hinge, "Knuckle%d" % int(y * 10), Vector3(0, y, 0.02 * dz), Vector3(0.08, 0.12, 0.04), "keypad_bezel")
	for side in [-1.0, 1.0]:
		var lamp := MeshInstance3D.new()
		lamp.name = "Lamp%s" % ("West" if side < 0 else "East")
		lamp.mesh = _box_mesh(Vector3(0.03, 0.05, 0.4))
		lamp.position = Vector3(side * 0.22, floor_y + h + 0.17, 0)
		_add(g, lamp)
	if reader:
		var box := _group(g, "CardReader")
		box.position = Vector3(-0.17, floor_y + 1.25, -(w / 2.0 + 0.45))
		_add_visual_box(box, "Box", Vector3.ZERO, Vector3(0.04, 0.17, 0.1), "keypad_bezel")
		_add_visual_box(box, "Pad", Vector3(-0.021, -0.02, 0), Vector3(0.004, 0.07, 0.07), "screen_dark")
		var led := MeshInstance3D.new()
		led.name = "Led"
		led.mesh = _box_mesh(Vector3(0.008, 0.022, 0.022))
		led.position = Vector3(-0.022, 0.06, 0)
		_add(box, led)
		_add_text(box, "Label", Vector3(-0.024, -0.075, 0), "STAFF CARD", 12, 0.0012, Color(0.9, 0.9, 0.88), -90.0)
	_set_layer_meta(g, Layout.LAYER_UPPER)



## The study rooms (ground floor, zone C: Study 1…4, x −12…12 in 6 m rooms, z −28…−14):
## a modern quiet study in light oak, green fabric and pale steel. Carpet tiles with a
## dark border, the back wall's eight carrels rebuilt over their colliders (oak tops,
## fabric dividers, a shelf with books and a light strip, a lamp, a tucked chair), group
## tables, bookcases and lockers (solid, clear of the rooms' probes, the checkpoint, the
## hiding spots and the doors), a whiteboard or noticeboard per room, the O1 desk as a
## tutor's desk, a ceiling grid with flat panel lights (the lamps unchanged, their round
## fixtures hidden by fixes_x16.gd) and glass door leaves folded back at the five study
## doors (visual only). The old look is removed by fixes_x16.gd; colliders unchanged.
const STUDY_Z0 := -27.85
const STUDY_Z1 := -14.15
const STUDY_CARRELS := [-10.5, -7.5, -4.5, -1.5, 1.5, 4.5, 7.5, 10.5]


func _build_study_rooms(solid: Node3D, decor: Node3D, ceilings: Node3D) -> void:
	for i in 4:
		var c := -9.0 + 6.0 * i
		var room := Node3D.new()
		room.name = "Study%d" % (i + 1)
		_add(decor, room)
		_study_carpet(room, c)
		_study_door_leaves(room, "DoorW", Vector3(c - 1.5, 0, -14.235), 0.0)
		_study_door_leaves(room, "DoorE", Vector3(c + 1.5, 0, -14.235), 0.0)
	for k in STUDY_CARRELS.size():
		_study_carrel(decor, "Carrel%d" % k, STUDY_CARRELS[k], k)
	# The Study 2–3 door (x 0, z −25…−23): its leaves folded back on the Study 2 side.
	_study_door_leaves(decor, "Door23S", Vector3(-0.235, 0, -25.5), 90.0)
	_study_door_leaves(decor, "Door23N", Vector3(-0.235, 0, -22.5), 90.0)
	# Study 1: a group table, a low bookcase and a whiteboard on the east wall.
	_study_table(_solid_prop(solid, "Study1Table", [-10.2, -24.9, -7.8, -22.9], 0.76), 4, 1)
	_study_bookcase(_wall_unit(_solid_prop(solid, "Study1Bookcase", [-6.6, -22.5, -6.2, -17.5], 1.2), -1.0), 5.0, 1.2, 3, 11)
	_whiteboard(decor, "Study1Board", Vector3(-6.162, 1.85, -20.0), -1.0, 1)
	# Study 2 (the checkpoint room): a six-seat table, lockers, a whiteboard.
	_study_table(_solid_prop(solid, "Study2Table", [-5.0, -24.9, -2.0, -22.9], 0.76), 6, 2)
	_study_lockers(_wall_unit(_solid_prop(solid, "Study2Lockers", [-5.8, -21.6, -5.35, -17.6], 1.8), 1.0), 4.0)
	_whiteboard(decor, "Study2Board", Vector3(-0.162, 1.75, -20.0), -1.0, 2)
	# Study 3: the O1 desk as a tutor's desk, a low bookcase and a noticeboard.
	_tutor_desk(decor)
	_study_bookcase(_wall_unit(_solid_prop(solid, "Study3Bookcase", [5.4, -22.5, 5.8, -17.5], 1.2), -1.0), 5.0, 1.2, 3, 23)
	_noticeboard(decor, "Study3Notices", Vector3(5.838, 1.85, -20.0), -1.0)
	# Study 4: a group table, a wall of tall bookcases, a whiteboard.
	_study_table(_solid_prop(solid, "Study4Table", [7.8, -24.9, 10.2, -22.9], 0.76), 4, 3)
	_study_bookcase(_wall_unit(_solid_prop(solid, "Study4BookcaseS", [11.4, -25.0, 11.8, -21.2], 2.0), -1.0), 3.8, 2.0, 5, 31)
	_study_bookcase(_wall_unit(_solid_prop(solid, "Study4BookcaseN", [11.4, -20.8, 11.8, -17.0], 2.0), -1.0), 3.8, 2.0, 5, 37)
	_whiteboard(decor, "Study4Board", Vector3(6.162, 1.75, -20.0), 1.0, 3)
	_study_ceiling(ceilings)


## A unit turned to face into the room from an east (face −1, its front towards −x) or
## west (face +1) wall: local +z is its front, local x runs along the wall.
func _wall_unit(model: Node3D, face: float) -> Node3D:
	var u := Node3D.new()
	u.name = "Unit"
	u.rotation_degrees = Vector3(0, 90.0 * face, 0)
	_add(model, u)
	return u


## Carpet tiles: a dark border along the walls and 1 m seams inside it, below the floor marks.
func _study_carpet(room: Node3D, c: float) -> void:
	var x0 := c - 2.85
	var x1 := c + 2.85
	var y := 0.0025
	var bw := 0.3
	var zm := (STUDY_Z0 + STUDY_Z1) / 2.0
	_add_visual_box(room, "BorderN", Vector3(c, y, STUDY_Z0 + bw / 2.0), Vector3(x1 - x0, 0.004, bw), "study_border")
	_add_visual_box(room, "BorderS", Vector3(c, y, STUDY_Z1 - bw / 2.0), Vector3(x1 - x0, 0.004, bw), "study_border")
	_add_visual_box(room, "BorderW", Vector3(x0 + bw / 2.0, y, zm), Vector3(bw, 0.004, STUDY_Z1 - STUDY_Z0 - 2.0 * bw), "study_border")
	_add_visual_box(room, "BorderE", Vector3(x1 - bw / 2.0, y, zm), Vector3(bw, 0.004, STUDY_Z1 - STUDY_Z0 - 2.0 * bw), "study_border")
	var inner := STUDY_Z1 - STUDY_Z0 - 2.0 * bw
	for k in 4:
		_add_visual_box(room, "SeamX%d" % k, Vector3(x0 + bw + 1.05 + k * 1.05, y + 0.001, zm), Vector3(0.015, 0.002, inner), "carpet_seam")
	var z := STUDY_Z0 + bw + 1.0
	var k := 0
	while z < STUDY_Z1 - bw - 0.3:
		_add_visual_box(room, "SeamZ%02d" % k, Vector3(c, y + 0.001, z), Vector3(x1 - x0 - 2.0 * bw, 0.002, 0.015), "carpet_seam")
		z += 1.0
		k += 1


## A carrel at x on the back wall (its desk collider x ± 0.6, z −27.85…−27.15, 0.75 m; its
## dividers' colliders at x ± 0.65, 1.5 m): an oak top on pale steel legs, green fabric
## dividers with oak caps, an oak shelf with books and a light strip, a lamp, a few
## things on the desk and a chair tucked in.
func _study_carrel(decor: Node3D, node_name: String, x: float, k: int) -> void:
	var g := Node3D.new()
	g.name = node_name
	g.position = Vector3(x, 0, -27.5)
	_add(decor, g)
	_add_visual_box(g, "Top", Vector3(0, 0.73, 0.015), Vector3(1.2, 0.04, 0.67), "oak")
	for sx in [-0.55, 0.55]:
		_add_visual_box(g, "Leg%d" % int(sx * 100), Vector3(sx, 0.355, 0.015), Vector3(0.04, 0.71, 0.6), "steel_beam")
	_add_visual_box(g, "Modesty", Vector3(0, 0.45, -0.25), Vector3(1.06, 0.4, 0.02), "oak")
	for e in [-1.0, 1.0]:
		var dx: float = e * 0.65
		_add_visual_box(g, "Divider%d" % int(e), Vector3(dx, 0.74, 0.255), Vector3(0.06, 1.48, 1.17), "fabric_green")
		_add_visual_box(g, "Cap%d" % int(e), Vector3(dx, 1.49, 0.255), Vector3(0.08, 0.02, 1.19), "oak")
		_add_visual_box(g, "Edge%d" % int(e), Vector3(dx, 0.74, 0.85), Vector3(0.08, 1.48, 0.02), "oak")
	# The shelf over the desk, its books and the light strip under it.
	_add_visual_box(g, "Shelf", Vector3(0, 1.26, -0.18), Vector3(1.24, 0.03, 0.28), "oak")
	_book_run(g, "Book", Vector3(-0.58, 1.275, -0.2), 0.95 if k % 2 == 0 else 0.7, 0.22, 0.22, k * 7 + 3)
	_add_visual_box(g, "Strip", Vector3(0, 1.238, -0.07), Vector3(1.1, 0.012, 0.03), "fluoro")
	# A lamp, a closed laptop or a notebook, a pen cup.
	var lx := 0.42 if k % 2 == 0 else -0.42
	_add_visual_box(g, "LampBase", Vector3(lx, 0.76, -0.2), Vector3(0.12, 0.02, 0.12), "steel_beam")
	_add_box_r(g, "LampArm", Vector3(lx, 0.94, -0.13), Vector3(0.02, 0.38, 0.02), "steel_beam", Vector3(0.35, 0, 0))
	_add_visual_box(g, "LampHead", Vector3(lx, 1.1, -0.02), Vector3(0.16, 0.035, 0.07), "steel_beam")
	_add_visual_box(g, "LampGlow", Vector3(lx, 1.081, -0.02), Vector3(0.13, 0.004, 0.05), "fluoro")
	if k % 3 == 0:
		_add_visual_box(g, "Laptop", Vector3(-lx * 0.4, 0.761, 0.08), Vector3(0.34, 0.022, 0.24), "keypad_bezel")
	else:
		_add_visual_box(g, "Notebook", Vector3(-lx * 0.4, 0.756, 0.1), Vector3(0.2, 0.012, 0.28), ["motor_blue", "pipe_red", "cabinet_green"][k % 3])
		_add_box_r(g, "Pen", Vector3(-lx * 0.4 + 0.13, 0.756, 0.1), Vector3(0.012, 0.01, 0.14), "tool_dark", Vector3(0, 0.3, 0))
	_add_visual_cyl(g, "PenCup", Vector3(-lx, 0.8, -0.2), 0.035, 0.1, "y", "steel_beam", 8)
	var ch := Node3D.new()
	ch.name = "Chair"
	ch.position = Vector3(0, 0, 0.3)
	ch.rotation_degrees = Vector3(0, 180, 0)
	_add(g, ch)
	_library_chair(ch)


## A row of books standing on a shelf from `at` along +x over `length` (`h` the tallest,
## `d` deep, centred on at.z), some runs leaning or with a gap.
func _book_run(parent: Node3D, prefix: String, at: Vector3, length: float, h: float, d: float, seed: int) -> void:
	var t := 0.0
	var i := 0
	while t < length - 0.04:
		var n := (seed * 31 + i * 17) % 23
		var w := 0.03 + 0.005 * (n % 5)
		var bh := h * (0.72 + 0.04 * (n % 7))
		if n == 5:
			t += 0.08   # a gap
			i += 1
			continue
		_add_visual_box(parent, "%s%02d" % [prefix, i], Vector3(at.x + t + w / 2.0, at.y + bh / 2.0, at.z), Vector3(w, bh, d * (0.8 + 0.03 * (n % 6))), BOOK_LOOKS[(n + seed) % BOOK_LOOKS.size()])
		t += w + 0.003
		i += 1


## A group table in a solid prop's model (its collider includes the chairs): an oak top on
## pale steel legs, `seats` chairs tucked in along its long sides, a few things on it.
func _study_table(m: Node3D, seats: int, k: int) -> void:
	var l := 2.6 if seats == 6 else 1.8
	_add_visual_box(m, "Top", Vector3(0, 0.74, 0), Vector3(l, 0.04, 0.9), "oak")
	_add_visual_box(m, "Edge", Vector3(0, 0.715, 0), Vector3(l - 0.04, 0.01, 0.86), "oak_dark")
	for sx in [-1.0, 1.0]:
		var lx: float = sx * (l / 2.0 - 0.12)
		for sz in [-0.36, 0.36]:
			_add_visual_box(m, "Leg%d_%d" % [int(sx), int(sz * 100)], Vector3(lx, 0.36, sz), Vector3(0.05, 0.72, 0.05), "steel_beam")
		_add_visual_box(m, "Foot%d" % int(sx), Vector3(lx, 0.68, 0), Vector3(0.05, 0.05, 0.72), "steel_beam")
	_add_visual_box(m, "Rail", Vector3(0, 0.68, 0), Vector3(l - 0.29, 0.05, 0.05), "steel_beam")
	var xs := [-0.85, 0.0, 0.85] if seats == 6 else [-0.45, 0.45]
	var n := 0
	for side in [-1.0, 1.0]:
		for x in xs:
			var ch := Node3D.new()
			ch.name = "Chair%d" % n
			ch.position = Vector3(x, 0, side * 0.62)
			ch.rotation_degrees = Vector3(0, 0.0 if side < 0 else 180.0, 0)
			_add(m, ch)
			_library_chair(ch)
			n += 1
	# A laptop, notebooks, a stack of books, a water bottle.
	_add_visual_box(m, "Laptop", Vector3(-l / 2.0 + 0.45, 0.771, -0.2), Vector3(0.34, 0.022, 0.24), "keypad_bezel")
	_add_box_r(m, "Screen", Vector3(-l / 2.0 + 0.45, 0.87, -0.33), Vector3(0.34, 0.22, 0.012), "keypad_bezel", Vector3(-0.25, 0, 0))
	_add_box_r(m, "ScreenLit", Vector3(-l / 2.0 + 0.45, 0.87, -0.325), Vector3(0.3, 0.18, 0.004), "screen_lit", Vector3(-0.25, 0, 0))
	_add_visual_box(m, "NotebookA", Vector3(0.2, 0.766, 0.22), Vector3(0.21, 0.012, 0.29), ["motor_blue", "pipe_red", "cabinet_green"][k % 3])
	_add_box_r(m, "NotebookB", Vector3(-0.15, 0.766, 0.18), Vector3(0.21, 0.012, 0.29), "card_white", Vector3(0, 0.4, 0))
	for b in 3:
		_add_box_r(m, "Stack%d" % b, Vector3(l / 2.0 - 0.4, 0.775 + b * 0.04, -0.15), Vector3(0.24, 0.035, 0.17), BOOK_LOOKS[(b * 3 + k) % BOOK_LOOKS.size()], Vector3(0, 0.15 * b, 0))
	_add_visual_cyl(m, "Bottle", Vector3(l / 2.0 - 0.75, 0.86, 0.25), 0.035, 0.2, "y", "motor_blue", 8)


## An oak bookcase in a wall unit (local x along the wall, front +z, 0.4 m deep):
## sides, top, plinth, a back and `shelves` shelves of books.
func _study_bookcase(u: Node3D, length: float, h: float, shelves: int, seed: int) -> void:
	var d := 0.4
	for e in [-1.0, 1.0]:
		_add_visual_box(u, "Side%d" % int(e), Vector3(e * (length / 2.0 - 0.015), h / 2.0, 0), Vector3(0.03, h, d), "oak")
	_add_visual_box(u, "Top", Vector3(0, h - 0.015, 0), Vector3(length, 0.03, d), "oak")
	_add_visual_box(u, "Plinth", Vector3(0, 0.04, 0.0), Vector3(length - 0.06, 0.08, d - 0.04), "oak_dark")
	_add_visual_box(u, "Back", Vector3(0, h / 2.0, -d / 2.0 + 0.015), Vector3(length - 0.06, h - 0.03, 0.02), "oak_dark")
	var bays := maxi(1, roundi(length / 1.0))
	var bw := (length - 0.06) / bays
	for b in range(1, bays):
		_add_visual_box(u, "Upright%d" % b, Vector3(-length / 2.0 + 0.03 + b * bw, h / 2.0, 0.01), Vector3(0.025, h - 0.06, d - 0.02), "oak")
	var row := (h - 0.11) / shelves
	for s in shelves:
		var y := 0.08 + s * row
		if s > 0:
			_add_visual_box(u, "Shelf%d" % s, Vector3(0, y + 0.012, 0.01), Vector3(length - 0.06, 0.025, d - 0.02), "oak")
		for b in bays:
			var x0 := -length / 2.0 + 0.03 + b * bw + 0.02
			var fill := bw - 0.06 if (b + s + seed) % 4 != 0 else bw * 0.55
			_book_run(u, "B%d_%d_" % [s, b], Vector3(x0, y + (0.025 if s > 0 else 0.0), 0.02), fill, row * 0.8, 0.26, seed + s * 5 + b)


## A bank of student lockers in a wall unit (front +z, 0.45 m deep, 1.8 m): pale steel,
## two tiers of 0.4 m doors with vents, number plates and handles, sage doors here and there.
func _study_lockers(u: Node3D, length: float) -> void:
	var d := 0.45
	_add_visual_box(u, "Body", Vector3(0, 0.95, -0.01), Vector3(length, 1.7, d - 0.02), "locker_grey")
	_add_visual_box(u, "Plinth", Vector3(0, 0.05, -0.02), Vector3(length, 0.1, d - 0.06), "tool_dark")
	_add_visual_box(u, "Top", Vector3(0, 1.79, 0), Vector3(length + 0.02, 0.02, d), "locker_grey")
	var cols := int(length / 0.4)
	var w := length / cols
	for i in cols:
		var x := -length / 2.0 + (i + 0.5) * w
		for t in 2:
			var y := 0.53 + t * 0.85
			var look := "locker_sage" if (i * 2 + t) % 5 == 1 else "locker_grey"
			_add_visual_box(u, "Door%d_%d" % [i, t], Vector3(x, y, d / 2.0 - 0.01), Vector3(w - 0.02, 0.8, 0.01), look)
			for v in 3:
				_add_visual_box(u, "Vent%d_%d_%d" % [i, t, v], Vector3(x, y + 0.28 - v * 0.035, d / 2.0 - 0.0025), Vector3(w * 0.5, 0.012, 0.005), "tool_dark")
			_add_visual_box(u, "Plate%d_%d" % [i, t], Vector3(x, y + 0.1, d / 2.0 - 0.0025), Vector3(0.07, 0.035, 0.005), "card_white")
			_add_visual_box(u, "Handle%d_%d" % [i, t], Vector3(x + w * 0.32, y - 0.05, d / 2.0 + 0.005), Vector3(0.025, 0.12, 0.02), "tool_dark")


## A whiteboard on a wall (`face`: −1 on an east wall, facing −x; +1 on a west wall): a
## white board in an aluminium frame with a marker tray, a few marker lines and magnets
## (nothing readable).
func _whiteboard(decor: Node3D, node_name: String, at: Vector3, face: float, k: int) -> void:
	var g := Node3D.new()
	g.name = node_name
	g.position = at
	g.rotation_degrees = Vector3(0, 90.0 * face, 0)
	_add(decor, g)
	_add_visual_box(g, "Board", Vector3(0, 0, 0), Vector3(2.4, 1.1, 0.02), "whiteboard")
	for e in [-1.0, 1.0]:
		_add_visual_box(g, "FrameH%d" % int(e), Vector3(0, e * 0.565, 0.004), Vector3(2.46, 0.03, 0.028), "alu")
		_add_visual_box(g, "FrameV%d" % int(e), Vector3(e * 1.215, 0, 0.004), Vector3(0.03, 1.1, 0.028), "alu")
	_add_visual_box(g, "Tray", Vector3(0, -0.6, 0.04), Vector3(1.2, 0.025, 0.07), "alu")
	_add_visual_box(g, "MarkerA", Vector3(-0.3, -0.578, 0.045), Vector3(0.13, 0.02, 0.02), "marker_blue")
	_add_visual_box(g, "MarkerB", Vector3(-0.1, -0.578, 0.045), Vector3(0.13, 0.02, 0.02), "marker_red")
	_add_visual_box(g, "Eraser", Vector3(0.25, -0.57, 0.045), Vector3(0.15, 0.04, 0.05), "tool_dark")
	var looks := ["marker_blue", "marker_red", "marker_green"]
	for j in 6:
		var w := 0.5 + 0.15 * ((j * 7 + k) % 5)
		_add_visual_box(g, "Line%d" % j, Vector3(-0.95 + w / 2.0 + (0.1 if j % 3 == 2 else 0.0), 0.38 - j * 0.11, 0.012), Vector3(w, 0.012, 0.004), looks[(j + k) % 3] if j % 3 != 0 else "marker_blue")
	_add_box_r(g, "Arrow", Vector3(0.55, 0.1, 0.012), Vector3(0.4, 0.012, 0.004), looks[k % 3], Vector3(0, 0, 0.5))
	for e in [-1.0, 1.0]:
		_add_visual_box(g, "BoxH%d" % int(e), Vector3(0.75, -0.15 + e * 0.15, 0.012), Vector3(0.5, 0.01, 0.004), looks[(k + 1) % 3])
		_add_visual_box(g, "BoxV%d" % int(e), Vector3(0.75 + e * 0.25, -0.15, 0.012), Vector3(0.01, 0.3, 0.004), looks[(k + 1) % 3])
	for j in 3:
		_add_visual_box(g, "Magnet%d" % j, Vector3(0.95 - j * 0.12, 0.45, 0.015), Vector3(0.03, 0.03, 0.01), ["pipe_red", "motor_blue", "sticker_yellow"][j])


## A cork noticeboard in an oak frame with pinned cards (nothing readable).
func _noticeboard(decor: Node3D, node_name: String, at: Vector3, face: float) -> void:
	var g := Node3D.new()
	g.name = node_name
	g.position = at
	g.rotation_degrees = Vector3(0, 90.0 * face, 0)
	_add(decor, g)
	_add_visual_box(g, "Cork", Vector3(0, 0, 0), Vector3(1.8, 1.0, 0.02), "cork")
	for e in [-1.0, 1.0]:
		_add_visual_box(g, "FrameH%d" % int(e), Vector3(0, e * 0.52, 0.004), Vector3(1.88, 0.04, 0.028), "oak")
		_add_visual_box(g, "FrameV%d" % int(e), Vector3(e * 0.92, 0, 0.004), Vector3(0.04, 1.0, 0.028), "oak")
	var cards := [[-0.6, 0.22, 0.3, 0.4, "card_white"], [-0.2, 0.26, 0.24, 0.3, "sticker_yellow"], [0.25, 0.18, 0.36, 0.26, "card_white"],
		[0.62, 0.22, 0.22, 0.3, "locker_sage"], [-0.5, -0.22, 0.4, 0.28, "paper"], [0.0, -0.2, 0.24, 0.24, "sticker_yellow"], [0.45, -0.22, 0.34, 0.36, "card_white"]]
	var j := 0
	for c in cards:
		_add_visual_box(g, "Card%d" % j, Vector3(c[0], c[1], 0.012), Vector3(c[2], c[3], 0.004), c[4])
		_add_visual_box(g, "Pin%d" % j, Vector3(c[0], c[1] + c[3] / 2.0 - 0.03, 0.018), Vector3(0.018, 0.018, 0.008), ["pipe_red", "motor_blue", "cabinet_green"][j % 3])
		for t in 2:
			_add_visual_box(g, "Text%d_%d" % [j, t], Vector3(c[0], c[1] + 0.05 - t * 0.06, 0.0155), Vector3(c[2] * (0.7 - 0.2 * t), 0.012, 0.003), "keypad_bezel")
		j += 1


## The O1 desk in Study 3 (its collider x 2.2…3.8, z −20.4…−19.6, 0.75 m) as a tutor's desk
## facing the door: an oak top and panels, a monitor, a keyboard, papers, a lamp, a mug and
## an office chair tucked in on its north side.
func _tutor_desk(decor: Node3D) -> void:
	var g := Node3D.new()
	g.name = "TutorDesk"
	g.position = Vector3(3.0, 0, -20.0)
	_add(decor, g)
	_add_visual_box(g, "Top", Vector3(0, 0.73, 0), Vector3(1.6, 0.04, 0.8), "oak")
	for sx in [-0.78, 0.78]:
		_add_visual_box(g, "Side%d" % int(sx * 100), Vector3(sx, 0.355, 0), Vector3(0.04, 0.71, 0.76), "oak")
	_add_visual_box(g, "Modesty", Vector3(0, 0.42, 0.36), Vector3(1.52, 0.5, 0.02), "oak")
	_add_visual_box(g, "Drawers", Vector3(0.5, 0.36, -0.02), Vector3(0.5, 0.66, 0.68), "oak_dark")
	for dr in 3:
		_add_visual_box(g, "Pull%d" % dr, Vector3(0.5, 0.58 - dr * 0.21, -0.365), Vector3(0.16, 0.02, 0.012), "steel_beam")
	var t := 0.75
	_add_visual_box(g, "MonitorFoot", Vector3(-0.1, t + 0.008, 0.18), Vector3(0.22, 0.016, 0.16), "keypad_bezel")
	_add_visual_box(g, "MonitorNeck", Vector3(-0.1, t + 0.13, 0.2), Vector3(0.04, 0.24, 0.03), "keypad_bezel")
	_add_visual_box(g, "Monitor", Vector3(-0.1, t + 0.32, 0.18), Vector3(0.56, 0.34, 0.03), "keypad_bezel")
	_add_visual_box(g, "MonitorScreen", Vector3(-0.1, t + 0.32, 0.1635), Vector3(0.52, 0.3, 0.003), "screen_lit")
	_add_visual_box(g, "Keyboard", Vector3(-0.1, t + 0.008, -0.12), Vector3(0.42, 0.016, 0.14), "keypad_bezel")
	_add_visual_box(g, "Mouse", Vector3(0.2, t + 0.01, -0.12), Vector3(0.06, 0.02, 0.1), "keypad_bezel")
	_add_box_r(g, "PapersA", Vector3(0.45, t + 0.004, -0.05), Vector3(0.21, 0.008, 0.3), "paper", Vector3(0, 0.2, 0))
	_add_box_r(g, "PapersB", Vector3(0.48, t + 0.01, -0.02), Vector3(0.21, 0.004, 0.3), "card_white", Vector3(0, -0.1, 0))
	_add_visual_box(g, "Tray", Vector3(-0.6, t + 0.03, 0.15), Vector3(0.26, 0.06, 0.34), "steel_beam")
	_add_visual_box(g, "TrayPapers", Vector3(-0.6, t + 0.05, 0.15), Vector3(0.22, 0.03, 0.3), "paper")
	_add_visual_cyl(g, "Mug", Vector3(0.62, t + 0.05, 0.2), 0.04, 0.1, "y", "card_white", 10)
	_add_visual_box(g, "LampBase", Vector3(0.6, t + 0.01, 0.28), Vector3(0.12, 0.02, 0.12), "steel_beam")
	_add_box_r(g, "LampArm", Vector3(0.6, t + 0.2, 0.22), Vector3(0.02, 0.38, 0.02), "steel_beam", Vector3(-0.3, 0, 0))
	_add_visual_box(g, "LampHead", Vector3(0.6, t + 0.37, 0.14), Vector3(0.16, 0.035, 0.07), "steel_beam")
	_add_visual_box(g, "LampGlow", Vector3(0.6, t + 0.351, 0.14), Vector3(0.13, 0.004, 0.05), "fluoro")
	var ch := Node3D.new()
	ch.name = "Chair"
	ch.position = Vector3(-0.1, 0, -0.3)
	_add(g, ch)
	_office_chair(ch)


## Glass door leaves folded back flat against a wall (visual only): two oak-framed glass
## leaves side by side, hinged at the jambs. `at` is the pair's middle, `yaw` 0 for the
## wall z −14 (the room side), 90 for the wall x 0 (the Study 2 side).
func _study_door_leaves(parent: Node3D, node_name: String, at: Vector3, yaw: float) -> void:
	var g := Node3D.new()
	g.name = node_name
	g.position = at
	g.rotation_degrees = Vector3(0, yaw, 0)
	_add(parent, g)
	var w := 0.98
	for e in [-1.0, 1.0]:
		_add_visual_box(g, "Stile%d" % int(e), Vector3(e * (w / 2.0 - 0.035), 1.28, 0), Vector3(0.07, 2.56, 0.04), "oak")
	_add_visual_box(g, "RailTop", Vector3(0, 2.51, 0), Vector3(w - 0.14, 0.1, 0.04), "oak")
	_add_visual_box(g, "RailBottom", Vector3(0, 0.1, 0), Vector3(w - 0.14, 0.2, 0.04), "oak")
	_add_visual_box(g, "Glass", Vector3(0, 1.33, 0), Vector3(w - 0.14, 2.26, 0.012), "glass_door")
	_add_visual_box(g, "Bar", Vector3(0, 1.05, -0.04), Vector3(w - 0.3, 0.03, 0.03), "alu")
	for e in [-1.0, 1.0]:
		_add_visual_box(g, "BarPost%d" % int(e), Vector3(e * (w / 2.0 - 0.15), 1.05, -0.03), Vector3(0.02, 0.02, 0.03), "alu")


## A ceiling grid (1.2 m tees) with square LED panels over the four rooms.
func _study_ceiling(ceilings: Node3D) -> void:
	var u := Node3D.new()
	u.name = "StudyCeiling"
	_add(ceilings, u)
	var top := 4.2
	var k := 0
	for i in 4:
		var c := -9.0 + 6.0 * i
		for t in 5:
			_add_visual_box(u, "TeeZ%d_%d" % [i, t], Vector3(c - 2.4 + t * 1.2, top - 0.006, (STUDY_Z0 + STUDY_Z1) / 2.0), Vector3(0.024, 0.012, STUDY_Z1 - STUDY_Z0), "ceiling_grid")
		for t in 11:
			_add_visual_box(u, "TeeX%d_%02d" % [i, t], Vector3(c, top - 0.006, -27.25 + t * 1.2), Vector3(5.7, 0.012, 0.024), "ceiling_grid")
		for z in [-25.45, -21.85, -17.05]:
			for sx in [-0.6, 0.6]:
				_add_visual_box(u, "Panel%02d" % k, Vector3(c + sx, top - 0.01, z), Vector3(1.17, 0.02, 1.17), "fluoro_housing")
				_add_visual_box(u, "Diffuser%02d" % k, Vector3(c + sx, top - 0.023, z), Vector3(1.1, 0.006, 1.1), "fluoro")
				k += 1



## The service corridor (ground floor, zone D: x 12…17, z −28…28): back-of-house utility.
## Sheet vinyl with seams, yellow walkway lines and hatched strips at the east doorways,
## a ventilation duct, a cable tray with cables and strip lights overhead on struts and
## hanger rods (under the archive's 4.2 m ceiling in the north part, from the 8 m roof in
## the south part; the lamps unchanged, their round fixtures hidden by fixes_x17.gd),
## bumper rails along both walls, corner guards on the east doors' jambs, two fire
## extinguishers, and solid props against the walls (shelving, a supply cabinet, bins,
## book carts) clear of the guard's route, the five doors and the probes. The old look
## is recoloured by fixes_x17.gd; colliders unchanged.
const CORR_X0 := 12.18      # the west wall's band face
const CORR_X1 := 16.82      # the east wall's band face
const CORR_Z0 := -27.82
const CORR_Z1 := 27.82
const CORR_WEST_DOORS := [[3.0, 5.0], [20.0, 22.0]]                    # SC1, G4
const CORR_EAST_DOORS := [[-18.0, -16.0], [1.0, 3.0], [18.5, 21.5]]    # processing, storage, dock
## Where the bumper rails stop: the doors and the props in front of each wall (sorted).
const CORR_WEST_GAPS := [[-27.0, -23.0], [-14.0, -12.6], [3.0, 5.0], [9.0, 10.4], [20.0, 22.0]]
const CORR_EAST_GAPS := [[-27.78, -26.38], [-25.8, -24.4], [-18.0, -16.0], [-9.0, -7.6], [1.0, 3.0], [7.0, 10.0], [14.5, 15.7], [18.5, 21.5]]


func _build_service_corridor(solid: Node3D, decor: Node3D, ceilings: Node3D) -> void:
	var d := Node3D.new()
	d.name = "ServiceCorridor"
	_add(decor, d)
	_corridor_floor(d)
	_corridor_walls(d)
	_corridor_props(solid)
	_corridor_services(ceilings)


## The open stretches of a wall between its doors (each door widened by `pad`).
func _corridor_runs(doors: Array, pad: float) -> Array:
	var runs := []
	var z := CORR_Z0
	for dr in doors:
		if dr[0] - pad - z > 0.1:
			runs.append([z, dr[0] - pad])
		z = dr[1] + pad
	if CORR_Z1 - z > 0.1:
		runs.append([z, CORR_Z1])
	return runs


## Two seams along the sheet vinyl, a yellow walkway line along each side (broken at that
## side's doors), and yellow and black hatching across the east doorways' approach.
func _corridor_floor(d: Node3D) -> void:
	var y := 0.0025
	for sx in [13.9, 15.1]:
		_add_visual_box(d, "Seam%d" % int(sx * 10), Vector3(sx, y + 0.001, 0), Vector3(0.012, 0.002, CORR_Z1 - CORR_Z0), "deck_seam")
	for side in [[12.95, CORR_WEST_DOORS, "W"], [16.05, CORR_EAST_DOORS, "E"]]:
		var k := 0
		for r in _corridor_runs(side[1], 0.4):
			_add_visual_box(d, "Line%s%d" % [side[2], k], Vector3(side[0], y, (r[0] + r[1]) / 2.0), Vector3(0.08, 0.004, r[1] - r[0]), "hazard_yellow")
			k += 1
	var k := 0
	for dr in CORR_EAST_DOORS:
		var z: float = dr[0]
		var i := 0
		while z < dr[1] - 0.01:
			_add_visual_box(d, "Hatch%d_%02d" % [k, i], Vector3(16.5, y, z + 0.1), Vector3(0.6, 0.004, 0.2), "hazard_yellow" if i % 2 == 0 else "hazard_black")
			z += 0.2
			i += 1
		k += 1


## Grey bumper rails at trolley height along both walls (broken at the doors), steel corner
## guards on the east doors' jambs, two fire extinguishers on brackets.
func _corridor_walls(d: Node3D) -> void:
	for side in [[CORR_X0 + 0.02, CORR_WEST_GAPS, "W"], [CORR_X1 - 0.02, CORR_EAST_GAPS, "E"]]:
		var k := 0
		for r in _corridor_runs(side[1], 0.25):
			var c := Vector3(side[0], 0.85, (r[0] + r[1]) / 2.0)
			_add_visual_box(d, "Bumper%s%d" % [side[2], k], c, Vector3(0.04, 0.14, r[1] - r[0]), "steel_beam")
			_add_visual_box(d, "BumperStripe%s%d" % [side[2], k], c + Vector3(0.022 if side[2] == "W" else -0.022, 0, 0), Vector3(0.004, 0.03, r[1] - r[0]), "tool_dark")
			k += 1
	var k := 0
	for dr in CORR_EAST_DOORS:
		for z in [dr[0] - 0.06, dr[1] + 0.06]:
			_add_visual_box(d, "CornerGuard%d" % k, Vector3(16.7875, 0.85, z), Vector3(0.045, 1.5, 0.17), "steel_beam")
			k += 1
	for e in [[Vector3(CORR_X0, 0, -6.6), 1.0], [Vector3(CORR_X1, 0, 12.6), -1.0]]:
		var at: Vector3 = e[0]
		var f: float = e[1]
		var g := Node3D.new()
		g.name = "Extinguisher%d" % int(at.z)
		g.position = at
		_add(d, g)
		_add_visual_box(g, "Bracket", Vector3(f * 0.02, 1.37, 0), Vector3(0.04, 0.12, 0.1), "tool_dark")
		_add_visual_cyl(g, "Body", Vector3(f * 0.12, 1.15, 0), 0.08, 0.46, "y", "extinguisher_red", 12)
		_add_visual_box(g, "Head", Vector3(f * 0.12, 1.42, 0), Vector3(0.05, 0.08, 0.05), "tool_dark")
		_add_visual_box(g, "Handle", Vector3(f * 0.12, 1.47, 0.04), Vector3(0.03, 0.02, 0.12), "tool_dark")
		_add_box_r(g, "Hose", Vector3(f * 0.215, 1.22, 0), Vector3(0.025, 0.42, 0.025), "tool_dark", Vector3(0, 0, f * 0.15))
		_add_visual_box(g, "Label", Vector3(f * 0.203, 1.15, 0.03), Vector3(0.004, 0.16, 0.06), "card_white")


## Solid props against the walls (a 3 cm gap to the band, at most 0.6 m deep).
func _corridor_props(solid: Node3D) -> void:
	# The north dead end, past the guard's turn at z −18: shelving, a supply cabinet, bins.
	var sh := _solid_prop(solid, "CorridorShelvingNorth", [12.2, -27.0, 12.75, -23.0], 2.0)
	var turn := Node3D.new()
	turn.name = "Unit"
	turn.rotation_degrees = Vector3(0, 180, 0)   # the box labels towards the corridor (+x)
	_add(sh, turn)
	_steel_shelving(turn, Vector3(0.55, 2.0, 4.0), 5)
	var cab := _solid_prop(solid, "CorridorSupplyCabinet", [16.3, -27.78, 16.8, -26.38], 2.0)
	_add_visual_box(cab, "Body", Vector3(0.01, 1.04, 0), Vector3(0.48, 1.92, 1.4), "locker_grey")
	for s in [-1.0, 1.0]:
		_add_visual_box(cab, "Door%d" % int(s), Vector3(-0.236, 1.03, s * 0.35), Vector3(0.012, 1.88, 0.68), "locker_grey")
		_add_visual_box(cab, "Handle%d" % int(s), Vector3(-0.248, 1.05, s * 0.05), Vector3(0.02, 0.22, 0.025), "tool_dark")
		for v in 3:
			_add_visual_box(cab, "Vent%d_%d" % [int(s), v], Vector3(-0.244, 1.72 - v * 0.04, s * 0.35), Vector3(0.004, 0.015, 0.4), "tool_dark")
	_add_visual_box(cab, "Gap", Vector3(-0.235, 1.03, 0), Vector3(0.008, 1.88, 0.01), "tool_dark")
	_add_visual_box(cab, "Plinth", Vector3(0.01, 0.04, 0), Vector3(0.44, 0.08, 1.36), "tool_dark")
	_add_visual_box(cab, "Tag", Vector3(-0.244, 1.45, -0.35), Vector3(0.004, 0.08, 0.16), "card_white")
	var bins := _solid_prop(solid, "CorridorBins", [16.25, -25.8, 16.8, -24.4], 1.05)
	for b in 2:
		var z := -0.36 + b * 0.72
		var look := "motor_blue" if b == 0 else "steel_beam"
		_add_visual_box(bins, "Bin%d" % b, Vector3(0, 0.5, z), Vector3(0.52, 0.92, 0.62), look)
		_add_visual_box(bins, "Lid%d" % b, Vector3(-0.02, 0.98, z), Vector3(0.56, 0.05, 0.66), look)
		_add_visual_box(bins, "LidHandle%d" % b, Vector3(-0.29, 0.96, z), Vector3(0.03, 0.04, 0.4), "tool_dark")
		for wz in [-0.24, 0.24]:
			_add_visual_cyl(bins, "Wheel%d_%d" % [b, int(wz * 100)], Vector3(0.2, 0.05, z + wz), 0.05, 0.04, "z", "tool_dark", 8)
		_add_visual_box(bins, "Label%d" % b, Vector3(-0.262, 0.62, z), Vector3(0.004, 0.18, 0.26), "card_white")
	# Book carts parked along the walls.
	var k := 0
	for c in [[12.2, -14.0], [12.2, 9.0], [16.25, -9.0]]:
		var cart := _solid_prop(solid, "CorridorCart%d" % k, [c[0], c[1], c[0] + 0.55, c[1] + 1.4], 1.0)
		_book_trolley(cart, Vector3(0.55, 1.0, 1.4), 3)
		k += 1
	# Mid corridor: shelving between the storage and the dock doors (box labels −x).
	var mid := _solid_prop(solid, "CorridorShelvingMid", [16.3, 7.0, 16.8, 10.0], 2.0)
	_steel_shelving(mid, Vector3(0.5, 2.0, 3.0), 2)
	# A book returns bin by the dock door.
	var ret := _solid_prop(solid, "CorridorReturnsBin", [16.2, 14.5, 16.8, 15.7], 1.0)
	_add_visual_box(ret, "Body", Vector3(0, 0.5, 0), Vector3(0.6, 0.9, 1.2), "motor_blue")
	_add_visual_box(ret, "Top", Vector3(0, 0.96, 0), Vector3(0.62, 0.06, 1.22), "steel_beam")
	_add_visual_box(ret, "Slot", Vector3(-0.302, 0.8, 0), Vector3(0.004, 0.06, 0.6), "tool_dark")
	_add_visual_box(ret, "Label", Vector3(-0.302, 0.55, 0), Vector3(0.004, 0.2, 0.5), "card_white")
	_add_visual_box(ret, "Plinth", Vector3(0, 0.03, 0), Vector3(0.56, 0.06, 1.16), "tool_dark")


## Overhead along the corridor: a ventilation duct (x 13.3) and a cable tray with cables
## (x 15.9) on struts every 3 m, hung from the ceiling (4.2 m, z < −6) or the roof (8 m),
## and a strip light under each lamp.
func _corridor_services(ceilings: Node3D) -> void:
	var u := Node3D.new()
	u.name = "CorridorServices"
	_add(ceilings, u)
	var length := CORR_Z1 - CORR_Z0
	_add_visual_box(u, "Duct", Vector3(13.3, 3.975, 0), Vector3(0.5, 0.35, length), "duct_steel")
	var z := CORR_Z0 + 1.5
	var k := 0
	while z < CORR_Z1 - 0.5:
		_add_visual_box(u, "DuctJoint%02d" % k, Vector3(13.3, 3.975, z), Vector3(0.54, 0.39, 0.04), "duct_steel")
		z += 1.5
		k += 1
	_add_visual_box(u, "TrayBase", Vector3(15.9, 3.805, 0), Vector3(0.4, 0.01, length), "steel_beam")
	for s in [-1.0, 1.0]:
		_add_visual_box(u, "TrayRail%d" % int(s), Vector3(15.9 + s * 0.195, 3.84, 0), Vector3(0.01, 0.08, length), "steel_beam")
	var cables := [[15.78, 0.03, "tool_dark"], [15.84, 0.025, "motor_blue"], [15.9, 0.03, "tool_dark"], [15.97, 0.02, "sticker_yellow"], [16.02, 0.03, "pipe_red"]]
	for c in cables:
		_add_visual_box(u, "Cable%d" % int(c[0] * 100), Vector3(c[0], 3.81 + c[1] / 2.0, 0), Vector3(c[1], c[1], length - 0.02), c[2])
	z = CORR_Z0 + 1.0
	k = 0
	while z < CORR_Z1:
		if absf(z + 6.0) > 0.4:
			var top := 4.2 if z < -6.0 else 8.0
			_add_visual_box(u, "Strut%02d" % k, Vector3(14.6, 3.78, z), Vector3(3.3, 0.04, 0.04), "steel_beam")
			for hx in [12.98, 16.22]:
				_add_visual_box(u, "Rod%02d_%d" % [k, int(hx)], Vector3(hx, (3.8 + top) / 2.0, z), Vector3(0.012, top - 3.8, 0.012), "steel_beam")
		z += 3.0
		k += 1
	k = 0
	for lz in [-23.333, -14.0, -4.667, 4.667, 14.0, 23.333]:
		var top := 4.2 if lz < -6.0 else 8.0
		_add_visual_box(u, "StripHousing%d" % k, Vector3(14.5, 3.6, lz), Vector3(0.24, 0.06, 2.4), "fluoro_housing")
		_add_visual_box(u, "StripDiffuser%d" % k, Vector3(14.5, 3.566, lz), Vector3(0.18, 0.012, 2.34), "fluoro")
		for e in [-1.0, 1.0]:
			_add_visual_box(u, "StripRod%d_%d" % [k, int(e)], Vector3(14.5, (3.63 + top) / 2.0, lz + e * 0.9), Vector3(0.01, top - 3.63, 0.01), "tool_dark")
		k += 1



## The porch (ground floor, zone A: x −5…5, z 28…34, where the player starts): the
## library's grand front hall. Stone tiles with a dark border and a brass medallion under
## the spawn, stone pilasters and a cornice, a coffered ceiling with three brass lanterns
## (the lamp unchanged, its round fixture hidden by fixes_x19.gd), stone benches and
## planters, a book return box, a library hours stand, bins, an umbrella stand and brass
## rope lines along the walk (solid, clear of the walk from the spawn to the doors) and an
## entrance mat. The old look is recoloured by fixes_x19.gd; colliders unchanged.
const PORCH_X := 4.85        # the side walls' faces (±x)
const PORCH_Z0 := 28.15      # the entrance wall's face
const PORCH_Z1 := 33.85      # the back wall's face
const PORCH_TOP := 4.2


func _build_porch(solid: Node3D, decor: Node3D, ceilings: Node3D) -> void:
	var d := Node3D.new()
	d.name = "Porch"
	_add(decor, d)
	_porch_floor(d)
	_porch_walls(d)
	_porch_props(solid, d)
	_porch_ceiling(ceilings)


## Stone tiles (0.6 m seams) inside a dark stone border, an entrance mat and a brass and
## stone medallion under the spawn (0, 32).
func _porch_floor(d: Node3D) -> void:
	var y := 0.0025
	var bw := 0.3
	var zm := (PORCH_Z0 + PORCH_Z1) / 2.0
	_add_visual_box(d, "BorderN", Vector3(0, y, PORCH_Z0 + bw / 2.0), Vector3(2.0 * PORCH_X, 0.004, bw), "stone_dark")
	_add_visual_box(d, "BorderS", Vector3(0, y, PORCH_Z1 - bw / 2.0), Vector3(2.0 * PORCH_X, 0.004, bw), "stone_dark")
	for s in [-1.0, 1.0]:
		_add_visual_box(d, "Border%s" % ("W" if s < 0 else "E"), Vector3(s * (PORCH_X - bw / 2.0), y, zm), Vector3(bw, 0.004, PORCH_Z1 - PORCH_Z0 - 2.0 * bw), "stone_dark")
	var x0 := -PORCH_X + bw
	var z0 := PORCH_Z0 + bw
	var x := x0 + 0.6
	var k := 0
	while x < PORCH_X - bw - 0.1:
		_add_visual_box(d, "SeamX%02d" % k, Vector3(x, y + 0.0005, zm), Vector3(0.01, 0.002, PORCH_Z1 - PORCH_Z0 - 2.0 * bw), "stone_seam")
		x += 0.6
		k += 1
	var z := z0 + 0.6
	k = 0
	while z < PORCH_Z1 - bw - 0.1:
		_add_visual_box(d, "SeamZ%02d" % k, Vector3(0, y + 0.0005, z), Vector3(2.0 * (PORCH_X - bw), 0.002, 0.01), "stone_seam")
		z += 0.6
		k += 1
	# The entrance mat beyond the doors' swing (z 28.15…29.15).
	_add_visual_box(d, "Mat", Vector3(0, 0.006, 30.0), Vector3(3.8, 0.012, 1.5), "mat_dark")
	_add_visual_box(d, "MatEdge", Vector3(0, 0.004, 30.0), Vector3(3.9, 0.008, 1.6), "bronze")
	# The medallion: a brass disc, a dark stone disc, a brass star.
	_add_visual_cyl(d, "MedallionRim", Vector3(0, 0.0045, 32.0), 0.95, 0.005, "y", "brass", 32)
	_add_visual_cyl(d, "MedallionStone", Vector3(0, 0.007, 32.0), 0.86, 0.006, "y", "stone_dark", 32)
	for r in 2:
		_add_box_r(d, "Star%d" % r, Vector3(0, 0.0095, 32.0), Vector3(0.9, 0.007, 0.9), "brass", Vector3(0, PI / 4.0 * r, 0))
	_add_visual_cyl(d, "MedallionCentre", Vector3(0, 0.012, 32.0), 0.18, 0.006, "y", "stone", 16)


## Stone pilasters on the side and back walls, a stone cornice under the ceiling.
func _porch_walls(d: Node3D) -> void:
	var piers := []
	for s in [-1.0, 1.0]:
		for z in [29.4, 31.0, 32.6]:
			piers.append([Vector3(s * PORCH_X, 0, z), -s * 90.0])
	for x in [-3.2, 3.2]:
		piers.append([Vector3(x, 0, PORCH_Z1), 180.0])
	var k := 0
	for p in piers:
		var g := Node3D.new()
		g.name = "Pilaster%d" % k
		g.position = p[0]
		g.rotation_degrees = Vector3(0, p[1], 0)
		_add(d, g)
		# Local +z faces into the porch, the wall face at z 0.
		_add_visual_box(g, "Base", Vector3(0, 0.16, 0.1), Vector3(0.54, 0.32, 0.2), "stone_light")
		_add_visual_box(g, "BaseMould", Vector3(0, 0.345, 0.085), Vector3(0.48, 0.05, 0.17), "stone_dark")
		_add_visual_box(g, "Shaft", Vector3(0, 2.05, 0.07), Vector3(0.4, 3.4, 0.14), "stone_light")
		for f in 2:
			_add_visual_box(g, "Flute%d" % f, Vector3(-0.07 + f * 0.14, 2.05, 0.142), Vector3(0.05, 3.0, 0.004), "stone_dark")
		_add_visual_box(g, "Capital", Vector3(0, 3.86, 0.1), Vector3(0.52, 0.22, 0.2), "stone_light")
		_add_visual_box(g, "CapitalMould", Vector3(0, 3.73, 0.085), Vector3(0.46, 0.04, 0.17), "stone_dark")
		k += 1
	# The cornice along the four walls.
	var h := 0.22
	var dep := 0.16
	var cy := PORCH_TOP - h / 2.0
	_add_visual_box(d, "CorniceN", Vector3(0, cy, PORCH_Z0 + dep / 2.0), Vector3(2.0 * PORCH_X, h, dep), "plaster")
	_add_visual_box(d, "CorniceS", Vector3(0, cy, PORCH_Z1 - dep / 2.0), Vector3(2.0 * PORCH_X, h, dep), "plaster")
	for s in [-1.0, 1.0]:
		_add_visual_box(d, "Cornice%s" % ("W" if s < 0 else "E"), Vector3(s * (PORCH_X - dep / 2.0), cy, (PORCH_Z0 + PORCH_Z1) / 2.0), Vector3(dep, h, PORCH_Z1 - PORCH_Z0 - 2.0 * dep), "plaster")


## Solid props against the walls (clear of x −2.2…2.2, the walk from the spawn to the doors).
func _porch_props(solid: Node3D, _d: Node3D) -> void:
	# Stone benches between the side pilasters (0.45 m deep: no navmesh on the seat).
	var k := 0
	for s in [-1.0, 1.0]:
		for z in [[29.68, 30.72], [31.28, 32.32]]:
			var xa: float = s * (PORCH_X - 0.05)
			var xb: float = s * (PORCH_X - 0.5)
			var b := _solid_prop(solid, "PorchBench%d" % k, [minf(xa, xb), z[0], maxf(xa, xb), z[1]], 0.46)
			_add_visual_box(b, "Seat", Vector3(0, 0.42, 0), Vector3(0.45, 0.08, 1.04), "stone_light")
			for e in [-1.0, 1.0]:
				_add_visual_box(b, "Leg%d" % int(e), Vector3(0, 0.19, e * 0.38), Vector3(0.38, 0.38, 0.14), "stone_dark")
			k += 1
	# Planters in the back corners.
	for s in [-1.0, 1.0]:
		var xa: float = s * (PORCH_X - 0.05)
		var xb: float = s * (PORCH_X - 0.65)
		var p := _solid_prop(solid, "PorchPlanter%s" % ("W" if s < 0 else "E"), [minf(xa, xb), 33.2, maxf(xa, xb), 33.8], 0.8)
		_add_visual_box(p, "Body", Vector3(0, 0.36, 0), Vector3(0.56, 0.72, 0.56), "stone_light")
		_add_visual_box(p, "Rim", Vector3(0, 0.75, 0), Vector3(0.6, 0.06, 0.6), "stone_dark")
		_add_visual_box(p, "Soil", Vector3(0, 0.781, 0), Vector3(0.5, 0.004, 0.5), "soil")
		for f in 4:
			_add_visual_box(p, "Foliage%d" % f, Vector3([-0.1, 0.1, 0.0, 0.05][f], 0.965 + f * 0.17, [0.06, -0.06, 0.0, 0.02][f]), Vector3(0.48 - f * 0.09, 0.26, 0.44 - f * 0.08), "foliage" if f % 2 == 0 else "foliage_light")
		_add_visual_box(p, "Trunk", Vector3(0, 0.86, 0), Vector3(0.05, 0.14, 0.05), "wood_dark")
	# A bronze book return box by the entrance, east (its slot facing the porch, +z).
	var ret := _solid_prop(solid, "PorchBookReturn", [3.4, 28.25, 4.2, 28.8], 1.1)
	_add_visual_box(ret, "Body", Vector3(0, 0.55, 0), Vector3(0.8, 1.0, 0.55), "bronze")
	_add_visual_box(ret, "Top", Vector3(0, 1.06, 0), Vector3(0.84, 0.08, 0.59), "bronze")
	_add_visual_box(ret, "Base", Vector3(0, 0.025, 0), Vector3(0.76, 0.05, 0.51), "tool_dark")
	_add_visual_box(ret, "Slot", Vector3(0, 0.85, 0.277), Vector3(0.44, 0.05, 0.004), "tool_dark")
	_add_visual_box(ret, "SlotLip", Vector3(0, 0.89, 0.29), Vector3(0.5, 0.02, 0.03), "brass")
	_add_visual_box(ret, "Plate", Vector3(0, 0.6, 0.277), Vector3(0.36, 0.12, 0.004), "brass")
	_add_text(ret, "PlateText", Vector3(0, 0.6, 0.28), "BOOK RETURN", 22, 0.0016, Color(0.15, 0.1, 0.04))
	# The library hours stand by the entrance, west (blank lines only).
	var st := _solid_prop(solid, "PorchHoursStand", [-4.05, 28.3, -3.35, 28.7], 1.35)
	_add_visual_box(st, "Foot", Vector3(0, 0.03, 0), Vector3(0.5, 0.06, 0.36), "bronze")
	_add_visual_box(st, "Post", Vector3(0, 0.6, 0), Vector3(0.06, 1.1, 0.06), "bronze")
	var board := Node3D.new()
	board.name = "Board"
	board.position = Vector3(0, 1.2, 0.02)
	board.rotation = Vector3(-0.35, 0, 0)   # tilted back like a lectern; local +z its face
	_add(st, board)
	_add_visual_box(board, "Panel", Vector3.ZERO, Vector3(0.66, 0.42, 0.03), "bronze")
	_add_visual_box(board, "Card", Vector3(0, 0, 0.018), Vector3(0.58, 0.34, 0.006), "card_white")
	_add_text(board, "Title", Vector3(0, 0.12, 0.0225), "LIBRARY HOURS", 26, 0.0016, Color(0.12, 0.1, 0.08))
	for t in 4:
		_add_visual_box(board, "Line%d" % t, Vector3(0, 0.05 - t * 0.06, 0.023), Vector3(0.42 - (t % 2) * 0.1, 0.014, 0.004), "keypad_bezel")
	# Litter and recycling bins west of the doors.
	var bins := _solid_prop(solid, "PorchBins", [-3.15, 28.22, -2.45, 28.62], 0.9)
	for b in 2:
		var x := -0.17 + b * 0.34
		_add_visual_cyl(bins, "Bin%d" % b, Vector3(x, 0.42, 0), 0.15, 0.84, "y", "bronze" if b == 0 else "motor_blue", 12)
		_add_visual_cyl(bins, "Lid%d" % b, Vector3(x, 0.87, 0), 0.165, 0.06, "y", "tool_dark", 12)
	# An umbrella stand by the east door and brass rope posts along the walk (solid: the
	# rope lines are thin barriers, 0.22 m, no navmesh on top; the walk stays 4.5 m wide).
	var um := _solid_prop(solid, "PorchUmbrellaStand", [2.47, 28.37, 2.73, 28.63], 0.9)
	_add_visual_cyl(um, "Pot", Vector3(0, 0.27, 0), 0.13, 0.54, "y", "brass", 12)
	for u in 2:
		_add_box_r(um, "Umbrella%d" % u, Vector3(-0.03 + u * 0.06, 0.62, 0.0), Vector3(0.05, 0.7, 0.05), ["tool_dark", "pipe_red"][u], Vector3(0, 0, 0.12 - u * 0.22))
	for s in [-1.0, 1.0]:
		var line := _solid_prop(solid, "PorchRopeLine%s" % ("W" if s < 0 else "E"), [s * 2.35 - 0.11, 29.49, s * 2.35 + 0.11, 32.71], 1.0)
		for i in 4:
			var z := -1.5 + i * 1.0
			_add_visual_cyl(line, "Base%d" % i, Vector3(0, 0.02, z), 0.1, 0.04, "y", "brass", 12)
			_add_visual_box(line, "Post%d" % i, Vector3(0, 0.48, z), Vector3(0.05, 0.88, 0.05), "brass")
			_add_visual_box(line, "Top%d" % i, Vector3(0, 0.95, z), Vector3(0.09, 0.07, 0.09), "brass")
			if i > 0:
				_add_visual_box(line, "Rope%d" % i, Vector3(0, 0.86, z - 0.5), Vector3(0.035, 0.035, 0.9), "rope_red")


## A coffered ceiling (plaster beams on a 3 × 5 grid, rosettes at the crossings) and three
## brass lanterns hanging along the middle.
func _porch_ceiling(ceilings: Node3D) -> void:
	var u := Node3D.new()
	u.name = "PorchCeiling"
	_add(ceilings, u)
	var bh := 0.2
	var by := PORCH_TOP - bh / 2.0
	var xs := [-PORCH_X + 2.0 * PORCH_X / 3.0, -PORCH_X + 4.0 * PORCH_X / 3.0]
	var zs := []
	for k in range(1, 5):
		zs.append(PORCH_Z0 + (PORCH_Z1 - PORCH_Z0) * k / 5.0)
	for x in xs:
		_add_visual_box(u, "BeamZ%d" % int(x * 10), Vector3(x, by, (PORCH_Z0 + PORCH_Z1) / 2.0), Vector3(0.2, bh, PORCH_Z1 - PORCH_Z0 - 0.32), "plaster")
	for z in zs:
		_add_visual_box(u, "BeamX%d" % int(z * 10), Vector3(0, by, z), Vector3(2.0 * PORCH_X - 0.32, bh - 0.02, 0.2), "plaster")
	for x in xs:
		for z in zs:
			_add_visual_box(u, "Rosette%d_%d" % [int(x * 10), int(z * 10)], Vector3(x, PORCH_TOP - bh - 0.02, z), Vector3(0.24, 0.04, 0.24), "brass")
	var k := 0
	for z in [29.86, 31.0, 32.14]:
		var g := Node3D.new()
		g.name = "Lantern%d" % k
		g.position = Vector3(0, PORCH_TOP, z)
		_add(u, g)
		_add_visual_box(g, "Canopy", Vector3(0, -0.03, 0), Vector3(0.16, 0.05, 0.16), "brass")
		_add_visual_box(g, "Chain", Vector3(0, -0.4, 0), Vector3(0.02, 0.7, 0.02), "bronze")
		_add_visual_box(g, "Crown", Vector3(0, -0.79, 0), Vector3(0.26, 0.08, 0.26), "bronze")
		_add_visual_box(g, "Glass", Vector3(0, -1.03, 0), Vector3(0.22, 0.4, 0.22), "lamp_cream")
		for sx in [-0.12, 0.12]:
			for sz in [-0.12, 0.12]:
				_add_visual_box(g, "Bar%d_%d" % [int(sx * 100), int(sz * 100)], Vector3(sx, -1.03, sz), Vector3(0.025, 0.42, 0.025), "bronze")
		_add_visual_box(g, "Bottom", Vector3(0, -1.26, 0), Vector3(0.28, 0.05, 0.28), "bronze")
		_add_visual_box(g, "Finial", Vector3(0, -1.32, 0), Vector3(0.06, 0.07, 0.06), "brass")
		k += 1



## The service stairs' ground landings in the basement's concrete utility: the west landing
## (x −44…−36, z −12…0, off the main stacks at the door x −36, z −9) gets the painted
## band and yellow line on its walls and parapet, a sealed concrete floor (its look, set in
## _build), a walkway line and an arrow to the stair, solid storage and utility props
## (shelving, stacked chairs, boxes, a mop sink and bucket) clear of the walkway and the
## probe (−39, −6), a fire hose cabinet and conduits on the walls, pipes, a cable tray and
## two caged bulkheads overhead (the lamp unchanged, its round fixture hidden in _build),
## and a steel guard rail on the parapet and the ramp's side wall. The east landing (the
## stair top in the electrical room) gets the guard rail on its ramp's side wall and a
## keep-clear box. Colliders unchanged apart from the new props.
const WL_X0 := -43.85     # the west landing's inside faces
const WL_X1 := -36.15
const WL_Z0 := -11.85     # the parapet's landing face (the stair opening west of x −40.5)
const WL_Z1 := -0.15
const WL_WALK := -7.8     # the walkway (stair top ↔ door) runs from the stair to this line


func _build_stair_landings(solid: Node3D, decor: Node3D, ceilings: Node3D) -> void:
	var d := Node3D.new()
	d.name = "WestLanding"
	_add(decor, d)
	_west_landing_walls(d)
	_west_landing_floor(d)
	_west_landing_props(solid, d)
	_west_landing_services(ceilings)
	var e := Node3D.new()
	e.name = "EastLanding"
	_add(decor, e)
	_guard_rail(e, "EastRampRail", Vector3(42.35, 0, -17.85), Vector3(42.35, 0, -8.15))
	_keep_clear(e, Vector3(44.2, 0, -19.1), Vector2(3.2, 1.4))


## The painted band (0.9 m) and yellow line on the landing's walls and parapet faces.
func _west_landing_walls(d: Node3D) -> void:
	var t := 0.016
	var faces := [
		["West", Vector3(WL_X0 + t / 2.0, 0, (WL_Z0 + WL_Z1) / 2.0), Vector3(t, 0, WL_Z1 - WL_Z0)],
		["South", Vector3((WL_X0 + WL_X1) / 2.0, 0, WL_Z1 - t / 2.0), Vector3(WL_X1 - WL_X0, 0, t)],
		["EastN", Vector3(WL_X1 - t / 2.0, 0, (WL_Z0 - 10.0) / 2.0 - 0.0), Vector3(t, 0, -10.0 - WL_Z0)],
		["EastS", Vector3(WL_X1 - t / 2.0, 0, (-8.0 + WL_Z1) / 2.0), Vector3(t, 0, WL_Z1 + 8.0)],
		["Parapet", Vector3((-40.35 + 0.15 + WL_X1) / 2.0, 0, WL_Z0 + t / 2.0), Vector3(WL_X1 - (-40.35 + 0.15), 0, t)],
	]
	for f in faces:
		var c: Vector3 = f[1]
		var s: Vector3 = f[2]
		_add_visual_box(d, "Band" + f[0], Vector3(c.x, BAND_H / 2.0, c.z), Vector3(s.x, BAND_H, s.z), "band_paint")
		_add_visual_box(d, "Line" + f[0], Vector3(c.x, BAND_H + 0.025, c.z), Vector3(s.x, 0.05, s.z), "hazard_yellow")
	# The parapet's top and the ramp side wall's top: a steel guard rail.
	_guard_rail(d, "ParapetRail", Vector3(-40.35, 0, -12.0), Vector3(-36.15, 0, -12.0))
	_guard_rail(d, "RampSideRail", Vector3(-40.35, 0, -21.85), Vector3(-40.35, 0, -12.15))


## A steel guard rail on a parapet's 1.1 m top from `a` to `b` (axis-aligned): a cap,
## posts every metre or so and a round rail.
func _guard_rail(parent: Node3D, node_name: String, a: Vector3, b: Vector3) -> void:
	var g := Node3D.new()
	g.name = node_name
	_add(parent, g)
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	var l := absf(b.x - a.x) if along_x else absf(b.z - a.z)
	var c := (a + b) / 2.0
	var top := Layout.RAIL
	_add_visual_box(g, "Cap", Vector3(c.x, top + 0.015, c.z), Vector3(l, 0.03, 0.34) if along_x else Vector3(0.34, 0.03, l), "steel_beam")
	var n := maxi(2, ceili(l / 1.2) + 1)
	for i in n:
		var f := float(i) / (n - 1)
		var p := a.lerp(b, f)
		_add_visual_box(g, "Post%d" % i, Vector3(p.x, top + 0.13, p.z), Vector3(0.04, 0.2, 0.04), "steel_beam")
	_add_visual_box(g, "Rail", Vector3(c.x, top + 0.25, c.z), Vector3(l, 0.045, 0.045) if along_x else Vector3(0.045, 0.045, l), "steel_shelf")


## A yellow keep-clear box with its words painted on the floor.
func _keep_clear(parent: Node3D, at: Vector3, size: Vector2) -> void:
	var y := 0.0025
	for s in [-1.0, 1.0]:
		_add_visual_box(parent, "KeepClearZ%d" % int(s), Vector3(at.x, y, at.z + s * (size.y / 2.0 - 0.03)), Vector3(size.x, 0.004, 0.06), "hazard_yellow")
		_add_visual_box(parent, "KeepClearX%d" % int(s), Vector3(at.x + s * (size.x / 2.0 - 0.03), y, at.z), Vector3(0.06, 0.004, size.y - 0.12), "hazard_yellow")
	var label := _add_text(parent, "KeepClearText", at + Vector3(0, 0.006, 0), "KEEP CLEAR", 64, 0.004, Color(0.9, 0.72, 0.1))
	label.rotation = Vector3(-PI / 2.0, PI, 0)   # flat on the floor, read from the room (north)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.shaded = true


## The walkway line and an arrow to the stair.
func _west_landing_floor(d: Node3D) -> void:
	var y := 0.0025
	_add_visual_box(d, "WalkLine", Vector3((WL_X0 + WL_X1) / 2.0, y, WL_WALK), Vector3(WL_X1 - WL_X0, 0.004, 0.08), "hazard_yellow")
	var ax := -42.2
	var az := -9.4
	_add_visual_box(d, "ArrowShaft", Vector3(ax, y, az + 0.45), Vector3(0.14, 0.004, 0.9), "hazard_yellow")
	for s in [-1.0, 1.0]:
		_add_box_r(d, "ArrowHead%d" % int(s), Vector3(ax + s * 0.17, y + 0.003, az - 0.12), Vector3(0.14, 0.004, 0.55), "hazard_yellow", Vector3(0, s * PI / 4.0, 0))


## Solid props against the walls, south of the walkway (z > −7.8) and clear of (−39, −6).
func _west_landing_props(solid: Node3D, d: Node3D) -> void:
	var sh := _solid_prop(solid, "LandingShelving", [-43.8, -6.8, -43.25, -2.8], 2.0)
	var turn := Node3D.new()
	turn.name = "Unit"
	turn.rotation_degrees = Vector3(0, 180, 0)   # the box labels towards the landing (+x)
	_add(sh, turn)
	_steel_shelving(turn, Vector3(0.55, 2.0, 4.0), 3)
	# Two stacks of folding chairs by the south wall.
	var ch := _solid_prop(solid, "LandingChairStacks", [-42.6, -0.75, -41.2, -0.2], 1.3)
	for s in 2:
		var x := -0.35 + s * 0.7
		for k in 8:
			var y := 0.42 + k * 0.1
			_add_visual_box(ch, "Seat%d_%d" % [s, k], Vector3(x, y, -0.02 + k * 0.004), Vector3(0.44, 0.03, 0.4), "keypad_bezel" if (k + s) % 2 == 0 else "motor_blue")
		for lx in [-0.2, 0.2]:
			_add_visual_box(ch, "Legs%d_%d" % [s, int(lx * 10)], Vector3(x + lx, 0.6, 0.12), Vector3(0.03, 1.2, 0.03), "steel_beam")
			_add_visual_box(ch, "LegsB%d_%d" % [s, int(lx * 10)], Vector3(x + lx, 0.6, -0.16), Vector3(0.03, 1.2, 0.03), "steel_beam")
	# Boxes by the south wall.
	var bx := _solid_prop(solid, "LandingBoxes", [-40.6, -0.8, -39.2, -0.2], 0.9)
	for k in 4:
		var x := -0.36 + (k % 2) * 0.72
		var y := 0.22 + (0.0 if k < 2 else 0.45)
		_add_box_r(bx, "Box%d" % k, Vector3(x, y, 0.0), Vector3(0.66, 0.44, 0.56 - (k % 2) * 0.04), "cardboard" if k != 2 else "archive_box", Vector3(0, 0.0 if k < 2 else 0.08, 0))
		_add_visual_box(bx, "Tape%d" % k, Vector3(x, y + 0.222, 0.0), Vector3(0.08, 0.004, 0.5), "card_white")
	# A mop sink and a mop bucket on the east wall (x −36.15).
	var sink := _solid_prop(solid, "LandingMopSink", [-36.8, -3.6, -36.2, -2.5], 0.9)
	_add_visual_box(sink, "Basin", Vector3(0, 0.75, 0), Vector3(0.6, 0.3, 1.1), "steel_shelf")
	_add_visual_box(sink, "Inside", Vector3(0, 0.902, 0), Vector3(0.5, 0.004, 1.0), "tool_dark")
	for sz in [-0.45, 0.45]:
		_add_visual_box(sink, "Leg%d" % int(sz * 10), Vector3(0, 0.3, sz), Vector3(0.5, 0.6, 0.06), "steel_beam")
	_add_visual_box(sink, "Tap", Vector3(0.24, 1.15, 0), Vector3(0.12, 0.05, 0.05), "tool_steel")
	_add_visual_box(sink, "TapPipe", Vector3(0.28, 1.04, 0), Vector3(0.03, 0.22, 0.03), "tool_steel")
	_add_visual_box(sink, "MopRack", Vector3(0.28, 1.6, 0), Vector3(0.04, 0.06, 0.9), "tool_dark")
	for m in 3:
		_add_visual_box(sink, "Mop%d" % m, Vector3(0.24, 1.2, -0.3 + m * 0.3), Vector3(0.025, 0.8, 0.025), ["motor_blue", "sticker_yellow", "pipe_red"][m])
	var bucket := _solid_prop(solid, "LandingMopBucket", [-37.4, -4.5, -36.9, -4.0], 0.6)
	_add_visual_box(bucket, "Bucket", Vector3(0, 0.22, 0), Vector3(0.46, 0.4, 0.46), "sticker_yellow")
	_add_visual_box(bucket, "Water", Vector3(0, 0.38, 0), Vector3(0.4, 0.004, 0.4), "wired_glass")
	_add_visual_box(bucket, "Wringer", Vector3(0, 0.48, 0.12), Vector3(0.3, 0.12, 0.18), "tool_dark")
	_add_box_r(bucket, "Handle", Vector3(0, 0.6, -0.02), Vector3(0.025, 0.6, 0.025), "motor_blue", Vector3(0.35, 0, 0))
	# On the walls (visual): a fire hose cabinet, conduits and a junction box.
	var hose := Node3D.new()
	hose.name = "HoseCabinet"
	hose.position = Vector3(WL_X1, 0, -6.0)
	_add(d, hose)
	_add_visual_box(hose, "Body", Vector3(-0.1, 1.3, 0), Vector3(0.2, 0.8, 0.7), "extinguisher_red")
	_add_visual_box(hose, "Glass", Vector3(-0.202, 1.32, 0), Vector3(0.004, 0.56, 0.5), "wired_glass")
	_add_visual_cyl(hose, "Reel", Vector3(-0.12, 1.32, 0), 0.2, 0.1, "x", "pipe_red", 16)
	_add_visual_box(hose, "Handle", Vector3(-0.21, 1.3, 0.3), Vector3(0.02, 0.12, 0.02), "tool_steel")
	_add_visual_box(hose, "Label", Vector3(-0.2015, 0.96, 0), Vector3(0.003, 0.08, 0.4), "card_white")
	for c in [[Vector3(WL_X0 + 0.03, 0, -9.0), "x"], [Vector3(-38.0, 0, WL_Z1 - 0.03), "z"]]:
		var at: Vector3 = c[0]
		_add_visual_box(d, "Conduit%s" % c[1], Vector3(at.x, (1.34 + 4.2) / 2.0, at.z), Vector3(0.035, 4.2 - 1.34, 0.035), "conduit")
		_add_visual_box(d, "JunctionBox%s" % c[1], Vector3(at.x, 1.25, at.z), Vector3(0.06 if c[1] == "x" else 0.18, 0.18, 0.18 if c[1] == "x" else 0.06), "conduit")


## Overhead: two pipes and a cable tray along the west wall, two caged bulkheads.
func _west_landing_services(ceilings: Node3D) -> void:
	var u := Node3D.new()
	u.name = "WestLandingServices"
	_add(ceilings, u)
	var z0 := -11.85
	var z1 := WL_Z1
	var zc := (z0 + z1) / 2.0
	var l := z1 - z0
	_add_visual_box(u, "PipeA", Vector3(-43.55, 3.95, zc), Vector3(0.14, 0.14, l), "pipe_red")
	_add_visual_box(u, "PipeB", Vector3(-43.3, 3.98, zc), Vector3(0.1, 0.1, l), "pipe")
	_add_visual_box(u, "Tray", Vector3(-42.6, 3.9, zc), Vector3(0.4, 0.06, l), "conduit")
	_add_visual_box(u, "TrayCables", Vector3(-42.6, 3.95, zc), Vector3(0.3, 0.04, l - 0.02), "tool_dark")
	var z := z0 + 1.0
	var k := 0
	while z < z1 - 0.3:
		_add_visual_box(u, "Hanger%02d" % k, Vector3(-43.1, 3.86, z), Vector3(1.4, 0.03, 0.04), "steel_beam")
		_add_visual_box(u, "Rod%02d" % k, Vector3(-42.4, 4.03, z), Vector3(0.012, 0.34, 0.012), "steel_beam")
		z += 2.0
		k += 1
	for bz in [-9.0, -3.0]:
		var h := Node3D.new()
		h.name = "Bulkhead%d" % int(-bz)
		h.position = Vector3(-40.0, 4.1, bz)
		_add(u, h)
		_add_visual_box(h, "Back", Vector3(0, 0.05, 0), Vector3(0.34, 0.06, 0.24), "tool_dark")
		_add_visual_box(h, "Dome", Vector3(0, -0.02, 0), Vector3(0.28, 0.1, 0.18), "lamp_cream")
		for c in 3:
			_add_visual_box(h, "CageX%d" % c, Vector3(0, -0.075, -0.07 + c * 0.07), Vector3(0.32, 0.014, 0.014), "tool_dark")
		for c in 2:
			_add_visual_box(h, "CageZ%d" % c, Vector3(-0.1 + c * 0.2, -0.075, 0), Vector3(0.014, 0.014, 0.22), "tool_dark")



func _solid_prop(parent: Node3D, node_name: String, rect: Array, h: float) -> Node3D:
	var size := Vector3(rect[2] - rect[0], h, rect[3] - rect[1])
	var body := _add_box_body(parent, node_name, Vector3((rect[0] + rect[2]) / 2.0, h / 2.0, (rect[1] + rect[3]) / 2.0), size, "crate")
	_strip_meshes(body)
	body.set_meta("why", "loading dock prop (polish): solid like the crates; the model is its look")
	var model := Node3D.new()
	model.name = "Model"
	model.position = Vector3(0, -h / 2.0, 0)
	_add(body, model)
	return model


## A wooden pallet (deck boards, gaps, blocks) standing at `base`.
func _pallet(parent: Node3D, node_name: String, base: Vector3, size: Vector3) -> void:
	var p := Node3D.new()
	p.name = node_name
	p.position = base
	_add(parent, p)
	_add_visual_box(p, "Deck", Vector3(0, size.y - 0.012, 0), Vector3(size.x, 0.024, size.z), "pallet_wood")
	_add_visual_box(p, "Base", Vector3(0, 0.012, 0), Vector3(size.x, 0.024, size.z), "pallet_wood")
	for sx in [-1.0, 0.0, 1.0]:
		_add_visual_box(p, "Block%d" % int(sx + 1), Vector3(sx * (size.x / 2.0 - 0.06), size.y / 2.0, 0), Vector3(0.1, size.y - 0.04, size.z), "pallet_dark")


## Outside the shutter (no collision; the exit's trigger is just past the door, nobody walks
## out here): a night yard with the dock bumpers, the leveller plate, a brick face round the
## door, a parked delivery van and a streetlight. Its own render layer and light.
func _dress_dock_yard(parent: Node) -> void:
	var yard := _group(parent, "DockYard")
	var o := DOCK_X + 0.15   # the outside face
	var parts := [
		["Apron", Vector3(43.1, -0.05, DOCK_Z), Vector3(13.9, 0.1, 18.0), "yard_concrete"],
		["BrickNorth", Vector3(o + 0.025, 2.1, 20.25), Vector3(0.05, 4.2, 4.5), "brick"],
		["BrickSouth", Vector3(o + 0.025, 2.1, 27.75), Vector3(0.05, 4.2, 4.5), "brick"],
		["BrickHeader", Vector3(o + 0.025, DOCK_H + 0.8, DOCK_Z), Vector3(0.05, 1.6, DOCK_W), "brick"],
		["Canopy", Vector3(o + 0.8, 3.3, DOCK_Z), Vector3(1.6, 0.12, 4.4), "keypad_bezel"],
		["BulkheadLamp", Vector3(o + 0.1, 2.95, DOCK_Z), Vector3(0.12, 0.12, 0.35), "glow_sodium"],
		["Leveller", Vector3(o + 0.95, 0.02, DOCK_Z), Vector3(1.9, 0.04, 2.8), "tread_steel"],
		["LevellerEdge", Vector3(o + 1.9, 0.025, DOCK_Z), Vector3(0.1, 0.05, 2.8), "hazard_yellow"],
		["BumperNorth", Vector3(o + 0.07, 0.35, 22.15), Vector3(0.14, 0.45, 0.25), "wire_black"],
		["BumperSouth", Vector3(o + 0.07, 0.35, 25.85), Vector3(0.14, 0.45, 0.25), "wire_black"],
		["BayLineNorth", Vector3(42.0, 0.003, 21.8), Vector3(6.0, 0.006, 0.1), "yard_paint"],
		["BayLineSouth", Vector3(42.0, 0.003, 26.8), Vector3(6.0, 0.006, 0.1), "yard_paint"],
		["Kerb", Vector3(49.9, 0.075, DOCK_Z), Vector3(0.3, 0.15, 18.0), "yard_concrete"],
		["Verge", Vector3(51.2, 0.01, DOCK_Z), Vector3(2.4, 0.02, 18.0), "grass_dark"],
		["FenceRailLow", Vector3(51.6, 0.5, DOCK_Z), Vector3(0.05, 0.05, 18.0), "keypad_bezel"],
		["FenceRailHigh", Vector3(51.6, 1.6, DOCK_Z), Vector3(0.05, 0.05, 18.0), "keypad_bezel"],
		# The van, backed up to the dock.
		["VanBody", Vector3(41.4, 1.45, 24.3), Vector3(4.4, 2.2, 2.0), "van_white"],
		["VanCab", Vector3(44.25, 1.25, 24.3), Vector3(1.3, 1.6, 2.0), "van_white"],
		["VanUnder", Vector3(42.0, 0.5, 24.3), Vector3(5.6, 0.3, 1.8), "keypad_bezel"],
		["VanWindscreen", Vector3(44.91, 1.7, 24.3), Vector3(0.02, 0.55, 1.8), "screen_dark"],
		["VanWindowN", Vector3(44.3, 1.7, 23.295), Vector3(0.8, 0.5, 0.02), "screen_dark"],
		["VanWindowS", Vector3(44.3, 1.7, 25.305), Vector3(0.8, 0.5, 0.02), "screen_dark"],
		["VanBumper", Vector3(39.12, 0.48, 24.3), Vector3(0.16, 0.2, 2.02), "keypad_bezel"],
		["VanDoorSeam", Vector3(39.195, 1.45, 24.3), Vector3(0.01, 2.1, 0.02), "keypad_bezel"],
		["VanTailN", Vector3(39.19, 1.0, 23.42), Vector3(0.02, 0.32, 0.14), "glow_red"],
		["VanTailS", Vector3(39.19, 1.0, 25.18), Vector3(0.02, 0.32, 0.14), "glow_red"],
		["VanStripeN", Vector3(41.4, 1.0, 23.295), Vector3(4.4, 0.12, 0.012), "motor_blue"],
		["VanStripeS", Vector3(41.4, 1.0, 25.305), Vector3(4.4, 0.12, 0.012), "motor_blue"],
		# The streetlight, north of the bay.
		["LampPole", Vector3(38.4, 2.5, 19.8), Vector3(0.12, 5.0, 0.12), "keypad_bezel"],
		["LampArm", Vector3(38.4, 4.95, 20.45), Vector3(0.08, 0.08, 1.4), "keypad_bezel"],
		["LampHead", Vector3(38.4, 4.9, 21.1), Vector3(0.35, 0.12, 0.6), "keypad_bezel"],
		["LampLens", Vector3(38.4, 4.83, 21.1), Vector3(0.3, 0.02, 0.5), "glow_sodium"],
	]
	for z in range(0, 8):
		parts.append(["FencePost%d" % z, Vector3(51.6, 0.9, 15.5 + z * 2.43), Vector3(0.08, 1.8, 0.08), "keypad_bezel"])
	for part in parts:
		_add_visual_box(yard, part[0], part[1], part[2], part[3], LAYER_YARD)
	for x in [40.2, 43.9]:
		for z in [23.32, 25.28]:
			var wheel := _add_visual_cyl(yard, "VanWheel%d_%d" % [int(x * 10), int(z * 10)], Vector3(x, 0.38, z), 0.38, 0.26, "z", "wire_black", 16)
			wheel.set_meta("render_layers", LAYER_YARD)
	_add_text(yard, "VanRearText", Vector3(39.185, 1.85, 24.3), "CITY LIBRARY\nDELIVERIES", 40, 0.004, Color(0.15, 0.25, 0.5), -90.0)
	_add_text(yard, "VanSideText", Vector3(41.4, 1.7, 23.285), "CITY LIBRARY · DELIVERIES", 48, 0.005, Color(0.15, 0.25, 0.5), 180.0)
	var light := OmniLight3D.new()
	light.name = "Streetlight"
	light.position = Vector3(38.4, 4.6, 21.4)
	light.light_color = Color(1.0, 0.78, 0.5)
	light.light_energy = 1.6
	light.omni_range = 14.0
	light.light_cull_mask = LAYER_YARD
	light.shadow_enabled = false
	_add(yard, light)


# --- Dressing --------------------------------------------------------------------------------

## Phase 9: the decorative boxes and stair stripes (no collision; see Layout.DECOR).
func _add_decor(parent: Node3D) -> void:
	for d in Layout.DECOR:
		_add_visual_box(parent, d.name, d.centre, d.size, d.look)
	for st in Layout.STAIR_STRIPES:
		var w: float = (st.x1 - st.x0) / 6.0
		for i in 6:
			_add_visual_box(parent, "%s_%d" % [st.name, i], Vector3(st.x0 + w * (i + 0.5), st.y + 0.006, st.z),
				Vector3(w, 0.012, 0.25), "hazard_yellow" if i % 2 == 0 else "hazard_black")


func _add_sign(parent: Node, s: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Sign_" + String(s.text).validate_node_name().replace(" ", "").replace("·", "").replace("↓", "Down").replace("↑", "Up")
	var base := holder.name
	var k := 2
	while parent.has_node(NodePath(holder.name)):   # the same text on several signs (polish: STORAGE · STAFF ONLY)
		holder.name = "%s_%d" % [base, k]
		k += 1
	holder.position = s.pos
	holder.rotation_degrees = Vector3(0, s.facing, 0)
	_add(parent, holder)
	var board := MeshInstance3D.new()
	board.name = "Board"
	board.mesh = _box_mesh(Vector3(maxf(1.6, String(s.text).length() * 0.19), 0.34, 0.04))
	board.material_override = _look("sign_red" if s.get("red", false) else "sign_board")
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(holder, board)
	var label := Label3D.new()
	label.name = "Text"
	label.text = s.text
	label.position = Vector3(0, 0, 0.03)
	label.pixel_size = 0.004
	label.font_size = 40
	label.outline_size = 0
	label.modulate = Color(1, 0.92, 0.9) if s.get("red", false) else Color(0.95, 0.93, 0.85)
	_add(holder, label)


func _add_label(parent: Node, node_name: String, pos: Vector3, text: String, colour: Color) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.006
	label.font_size = 40
	label.modulate = colour
	label.no_depth_test = true
	_add(parent, label)
	return label


## Expansion Phase 9: the static boxes of Geometry and Dressing (floors, walls,
## ramps, cover, ceilings, door headers, floor patches; not the doors, items,
## signs, lamps or anything in Gameplay) merged into BatchedBoxes, as the
## existing level's builder does (shared/scripts/level/batched_boxes.gd): one MultiMesh
## per 12 m cell, look kind, render layer and shadow setting, split again until
## at most 8 lights reach each piece (the Compatibility renderer's per-mesh
## limit; the existing level's lights near the expansion count too). Collision
## bodies keep their shapes; only their visual tiles move into the batches.
const BATCH_CELL := 12.0
const MAX_LIGHTS_PER_MESH := 8
const BATCH_SCRIPT := "res://shared/scripts/level/batched_boxes.gd"
var _batched := 0
var _batches := 0


func _batch_static_meshes() -> void:
	var found: Array[MeshInstance3D] = []
	for group_name in ["Geometry", "Dressing"]:
		_collect_batchable(_root.get_node(group_name), found)
	var groups := {}   # host -> {key -> {...}}
	for mi in found:
		var host := _batch_host(mi)
		var xf := _world_of(mi) * Transform3D(Basis.from_scale((mi.mesh as BoxMesh).size), Vector3.ZERO)
		var material := mi.material_override as StandardMaterial3D
		# Plain colours share one vertex-colour material; metal and glowing looks keep theirs.
		var kind := "plain" if not material.emission_enabled and material.metallic == 0.0 else String(material.resource_scene_unique_id).trim_prefix("Material_")
		var cell := Vector2i(floori(xf.origin.x / BATCH_CELL), floori(xf.origin.z / BATCH_CELL))
		var shadow := mi.cast_shadow
		var key := "%d_%d_%s_L%d_S%d" % [cell.x, cell.y, kind, mi.layers, int(shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)]
		if not groups.has(host):
			groups[host] = {}
		if not groups[host].has(key):
			groups[host][key] = {"items": [], "material": material, "plain": kind == "plain", "layers": mi.layers, "shadow": shadow}
		groups[host][key].items.append([xf, material.albedo_color])
		mi.get_parent().remove_child(mi)
		mi.free()
		_batched += 1
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
				var centre := _items_aabb(items).get_center()
				var origin := Vector3(snappedf(centre.x, 0.5), snappedf(centre.y, 0.5), snappedf(centre.z, 0.5))
				var data := PackedFloat32Array()
				for it in items:
					BatchedBoxes.pack(data, Transform3D(Basis(), -origin) * it[0], it[1])
				var node := MultiMeshInstance3D.new()
				node.name = "Batch_" + key + ("" if pieces.size() == 1 else "_%d" % k)
				node.set_script(load(BATCH_SCRIPT))
				node.set("boxes", data)
				node.position = _world_of(host).affine_inverse() * origin
				node.material_override = plain if g.plain else g.material
				node.layers = g.layers
				node.cast_shadow = g.shadow
				_add(host, node)
				_batches += 1
	print("batched %d boxes into %d BatchedBoxes" % [_batched, _batches])


func _collect_batchable(node: Node, out: Array[MeshInstance3D]) -> void:
	# Not the signs and lamps, nor the storm drain grate (the pump hides it).
	if node.name in ["Signs", "Lights", Layout.GRATE.name] or node.owner != _root and node != _root:
		return
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is BoxMesh and node.material_override is StandardMaterial3D:
		out.append(node)
	for child in node.get_children():
		_collect_batchable(child, out)


## Batches go to <Geometry or Dressing>/<first group>/Batched (Dressing/Ceilings
## keeps its own, hidden in top-down captures).
func _batch_host(node: Node) -> Node3D:
	var n := node
	while n.get_parent() and n.get_parent().get_parent() != _root:
		n = n.get_parent()
	var group := n as Node3D
	var existing := group.get_node_or_null("Batched") as Node3D
	return existing if existing else _group(group, "Batched")


## Every omni light that can reach the expansion, as [range bounds, cull mask]:
## the expansion's own lamps and the existing level's (read from its scene).
func _light_bounds() -> Array:
	var out := []
	for l in _root.find_children("*", "OmniLight3D", true, false):
		var omni := l as OmniLight3D
		out.append([AABB(_world_of(omni).origin - Vector3.ONE * omni.omni_range, Vector3.ONE * omni.omni_range * 2.0), omni.light_cull_mask])
	var level: Node = (load("res://maps/library/scenes/expanded_library.tscn") as PackedScene).instantiate()
	for l in level.find_children("*", "OmniLight3D", true, false):
		if _under(l, level.get_node_or_null("Expansion")):
			continue
		var omni := l as OmniLight3D
		var at := _world_in(omni, level).origin
		out.append([AABB(at - Vector3.ONE * omni.omni_range, Vector3.ONE * omni.omni_range * 2.0), omni.light_cull_mask])
	level.free()
	return out


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


func _world_of(node: Node) -> Transform3D:
	return _world_in(node, _root)


func _world_in(node: Node, top: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n and n != top:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _under(node: Node, ancestor: Node) -> bool:
	return ancestor != null and ancestor.is_ancestor_of(node)


## Render layers as the existing level's (ground 4) plus the basement (16), so
## the basement's lamps light only the basement and the ground lamps the ground.
func _assign_layers(node: Node) -> void:
	if node is GeometryInstance3D and not (node is Label3D) and node.owner == _root:
		var gi := node as GeometryInstance3D
		if gi.has_meta("render_layers"):
			gi.layers = gi.get_meta("render_layers")
			gi.remove_meta("render_layers")
		else:
			gi.layers = Layout.LAYER_BASEMENT if _global_y(gi) < -0.3 else Layout.LAYER_GROUND
	for child in node.get_children():
		_assign_layers(child)


func _global_y(node: Node3D) -> float:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n and n != _root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		return (t * (node as MeshInstance3D).get_aabb()).get_center().y
	return t.origin.y


# --- Resources -------------------------------------------------------------------------------

func _look(look_name: String) -> StandardMaterial3D:
	var key := "look_" + look_name
	if not _materials.has(key):
		var spec: Array = Layout.DECOR_LOOKS[look_name] if Layout.DECOR_LOOKS.has(look_name) else Palette.LOOKS[look_name]
		var m := StandardMaterial3D.new()
		m.resource_scene_unique_id = "Material_%s" % look_name
		m.albedo_color = spec[0]
		m.roughness = spec[1]
		m.metallic = spec[2]
		if spec[3] > 0.0:
			m.emission_enabled = true
			m.emission = spec[0]
			m.emission_energy_multiplier = spec[3]
		if look_name == "ceiling":
			m.disable_receive_shadows = true
		_materials[key] = m
	return _materials[key]


func _colour(colour: Color) -> StandardMaterial3D:
	var key := colour.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.resource_scene_unique_id = "Material_%s" % key
		m.albedo_color = colour
		m.roughness = 1.0
		_materials[key] = m
	return _materials[key]


func _key(size: Vector3) -> String:
	return ("%.3f_%.3f_%.3f" % [size.x, size.y, size.z]).replace(".", "p").replace("-", "m")


func _box_mesh(size: Vector3) -> BoxMesh:
	var key := _key(size)
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.resource_scene_unique_id = "BoxMesh_%s" % key
		m.size = size
		_meshes[key] = m
	return _meshes[key]


func _box_shape(size: Vector3) -> BoxShape3D:
	var key := _key(size)
	if not _shapes.has(key):
		var s := BoxShape3D.new()
		s.resource_scene_unique_id = "BoxShape_%s" % key
		s.size = size
		_shapes[key] = s
	return _shapes[key]
