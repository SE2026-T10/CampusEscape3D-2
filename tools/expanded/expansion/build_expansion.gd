extends SceneTree

## Development tool: builds the Expanded Library expansion sub-scene,
##   res://scenes/level/expanded_library_expansion.tscn,
## from tools/expanded/expansion/expansion_layout.gd. It writes only that file:
## the existing level (expanded_library.tscn) and its frozen builder are not
## touched. Afterwards rebake the level's navmesh, which includes the
## expansion's geometry:
##   godot --headless --path . --script res://tools/expanded/expansion/build_expansion.gd
##   godot --headless --path . --script res://tools/expanded/expansion/bake_navmesh.gd
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
##   └─ Layout (debug_visuals, F3): zone labels and reserved-space markers
## Colours: the existing level's palette (LOOKS of the frozen builder).

const Layout := preload("res://tools/expanded/expansion/expansion_layout.gd")
const Palette := preload("res://tools/expanded/build_expanded_graybox.gd")
const SCENE_PATH := "res://scenes/level/expanded_library_expansion.tscn"
const LIGHT_SCENE := "res://scenes/props/ceiling_light.tscn"
const SCRIPTS := {
	"door": "res://scripts/systems/objectives/access_door.gd",
	"noise": "res://scripts/systems/noise/noise_maker.gd",
	"hiding": "res://scripts/systems/hiding_spot.gd",
	"item": "res://scripts/systems/inventory/item_pickup.gd",
	"storage": "res://scripts/systems/inventory/item_storage.gd",
	"document": "res://scripts/systems/inventory/document_pickup.gd",
	"tool": "res://scripts/systems/inventory/tool_mechanism.gd",
	"power": "res://scripts/systems/puzzles/power_network.gd",
	"alarm": "res://scripts/systems/puzzles/security_alarm.gd",
	"code_lock": "res://scripts/systems/puzzles/code_lock.gd",
	"breakers": "res://scripts/systems/puzzles/breaker_panel.gd",
	"pump": "res://scripts/systems/puzzles/pump_control.gd",
	"exit": "res://scripts/systems/objectives/exit_door.gd",
	"switch": "res://scripts/systems/security/circuit_switch.gd",
	"camera": "res://scripts/systems/security/security_camera.gd",
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
	_root.editor_description = "Expanded Library expansion content (2026 expansion). Built by tools/expanded/expansion/build_expansion.gd from expansion_layout.gd (%s): the basement / service network (zone G), the electrical room (zone D), the west and east service stairs. New puzzles, mechanics and areas go here, not into expanded_library.tscn, whose builder is frozen. Instanced once into expanded_library.tscn as \"Expansion\", right after \"Gameplay\"; content uses the level's existing systems through their groups." % Layout.VERSION
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
	for f in Layout.FLOORS:
		var r: Array = f.rect
		_add_box_body(zones[f.zone], "Floor_" + f.name, Vector3((r[0] + r[2]) / 2.0, f.y - Layout.FLOOR_T / 2.0, (r[1] + r[3]) / 2.0),
			Vector3(r[2] - r[0], Layout.FLOOR_T, r[3] - r[1]), f.look)
	for w in Layout.WALLS:
		var along_x: bool = w.a[1] == w.b[1]
		var lo: float = minf(w.a[0], w.b[0]) if along_x else minf(w.a[1], w.b[1])
		var hi: float = maxf(w.a[0], w.b[0]) if along_x else maxf(w.a[1], w.b[1])
		var mid := (lo + hi) / 2.0
		var centre := Vector3(mid, (w.y0 + w.y1) / 2.0, w.a[1]) if along_x else Vector3(w.a[0], (w.y0 + w.y1) / 2.0, mid)
		var t := Layout.WALL_T
		var size := Vector3(hi - lo, w.y1 - w.y0, t) if along_x else Vector3(t, w.y1 - w.y0, hi - lo)
		_add_box_body(zones[w.zone], "Wall_" + w.name, centre, size, "wall")
	for ramp in Layout.RAMPS:
		_add_ramp(zones[ramp.zone], ramp)
	for c in Layout.COVER:
		var r: Array = c.rect
		_add_box_body(zones[c.zone], "Cover_" + c.name, Vector3((r[0] + r[2]) / 2.0, c.y + c.h / 2.0, (r[1] + r[3]) / 2.0),
			Vector3(r[2] - r[0], c.h, r[3] - r[1]), c.look)
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
	_add_box_body(zones["G"], g.name, g.centre + Vector3(0, g.height / 2.0, 0), Vector3(g.width, g.height, 0.12), "dark_metal")

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
	_add_mission(_group(gameplay, "Mission"))
	_add_security(_group(gameplay, "Security"))

	var dressing := _group(_root, "Dressing")
	var ceilings := _group(dressing, "Ceilings")
	for c in Layout.CEILINGS:
		var r: Array = c.rect
		_add_visual_box(ceilings, "Ceiling", Vector3((r[0] + r[2]) / 2.0, c.y + 0.05, (r[1] + r[3]) / 2.0), Vector3(r[2] - r[0], 0.1, r[3] - r[1]), "ceiling")
	for c in Layout.ROOFS:
		var r: Array = c.rect
		_add_visual_box(ceilings, "Roof", Vector3((r[0] + r[2]) / 2.0, c.y + 0.1, (r[1] + r[3]) / 2.0), Vector3(r[2] - r[0], 0.2, r[3] - r[1]), "ceiling")
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


func _add_visual_box(parent: Node, node_name: String, centre: Vector3, size: Vector3, look: String) -> void:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = centre
	_add(parent, holder)
	_add_tiles(holder, size, look)
	for m in holder.get_children():
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
			Vector3(width, h, absf(z1 - z0)), "wall")


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
	_add(parent, door)
	var w: float = d.width
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = _box_shape(Vector3(w, 2.4, 1.0) if d.along_x else Vector3(1.0, 2.4, w))
	_add(door, shape)
	var panel := StaticBody3D.new()
	panel.name = "Panel"
	panel.collision_layer = 1
	panel.collision_mask = 0
	panel.position = Vector3(0, Layout.DOOR_HEIGHT / 2.0 - 1.2, 0)
	_add(door, panel)
	var size := Vector3(w, Layout.DOOR_HEIGHT, 0.18) if d.along_x else Vector3(0.18, Layout.DOOR_HEIGHT, w)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = _box_mesh(size)
	mesh.material_override = _colour(Color(0.85, 0.2, 0.18))   # the level's card-gate red
	_add(panel, mesh)
	var pshape := CollisionShape3D.new()
	pshape.name = "Shape"
	pshape.shape = _box_shape(size)
	_add(panel, pshape)
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
	_add(spot, mark)


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
	var cover := _add_tool_mechanism(mission, m.panel_cover, "dark_metal")
	cover.set("hide_model_when_operated", true)
	var breakers := _placed(mission, m.breakers, SCRIPTS.breakers)
	breakers.set("puzzle_name", "Breaker panel")
	breakers.set("circuit", StringName(m.breakers.circuit))
	breakers.set("objective_id", StringName(m.breakers.objective))
	var solution: Array[bool] = []
	solution.assign(m.breakers.solution)
	breakers.set("solution", solution)
	breakers.set("cover_path", breakers.get_path_to(cover))
	_add_visual_box(mission, "BreakerBackplate", m.breakers.pos + Vector3(0, -0.05, -0.03), Vector3(1.1, 0.75, 0.04), "dark_metal")
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
		_add_visual_box(mission, k.name + "Backplate", k.pos + Basis.from_euler(Vector3(0, deg_to_rad(k.facing), 0)) * Vector3(0, 0.05, -0.04),
			Vector3(0.75, 0.55, 0.04) if k.facing == 0.0 or k.facing == 180.0 else Vector3(0.04, 0.55, 0.75), "dark_metal")
		if k.has("cabinet"):
			_add_visual_box(mission, "LockerCabinet", k.cabinet.centre, k.cabinet.size, "dark_metal")
	_add_tool_mechanism(mission, m.pump_crank, "steel")
	var pump := _placed(mission, m.pump, SCRIPTS.pump)
	pump.set("puzzle_name", "Pump")
	pump.set("objective_id", StringName(m.pump.objective))
	var valves: Array[bool] = []
	valves.assign(m.pump.solution)
	pump.set("solution", valves)
	pump.set("crank_path", pump.get_path_to(mission.get_node(String(m.pump_crank.name))))
	pump.set("grate_path", pump.get_path_to(_root.get_node("Geometry/G_ServiceNetwork/" + Layout.GRATE.name)))
	_pump = pump   # its hide_on_solve (the sealed sign) is set once the signs exist
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
	exit.set_meta("zone_id", e.zone)
	_add(mission, exit)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = _box_shape(e.size)
	_add(exit, shape)
	var sign_label := _add_label(exit, "Sign", Vector3(0, 1.5, 0.3), "STORM DRAIN · GRATE JAMMED", Color(1, 0.4, 0.3))
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var noise := Node3D.new()
	noise.name = "Noise"
	noise.set_script(load(SCRIPTS.noise))
	noise.set("radius", 6.0)
	_add(exit, noise)


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
		node.set_meta("zone_id", "D")
		_add(security, node)
	var board := _add_label(security, "SwitchBoardLabel", Layout.SECURITY.labels.switch_board,
		"SURVEILLANCE  ·  ARCHIVE (behind the cover)  ·  SERVICE EXIT", Color(1.0, 0.85, 0.45))
	board.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	board.no_depth_test = false
	board.pixel_size = 0.0035
	board.font_size = 22
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
		cam.set_meta("zone_id", c.zone)
		_add(cameras, cam)


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


# --- Dressing --------------------------------------------------------------------------------

func _add_sign(parent: Node, s: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Sign_" + String(s.text).validate_node_name().replace(" ", "").replace("·", "").replace("↓", "Down").replace("↑", "Up")
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


## Render layers as the existing level's (ground 4) plus the basement (16), so
## the basement's lamps light only the basement and the ground lamps the ground.
func _assign_layers(node: Node) -> void:
	if node is GeometryInstance3D and not (node is Label3D) and node.owner == _root:
		var gi := node as GeometryInstance3D
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
		var spec: Array = Palette.LOOKS[look_name]
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
