class_name ItemCatalog
extends RefCounted

## Every carried item the game knows, by id. PlayerInventory, ItemPickup,
## ItemStorage and the HUD read names, kinds and looks from here, so an item is
## described once.
##   TOOL         reusable: needed by designated mechanisms (ToolMechanism)
##   CARD         reusable: opens the AccessDoors whose key_item matches
##   DISTRACTION  single use: thrown with the use key, makes a noise where it lands
## Clue documents are not items: they go to the journal (DocumentPickup).

enum Kind { TOOL, CARD, DISTRACTION }

const TOOLKIT := &"toolkit"
const STAFF_CARD := &"staff_card"
const BOTTLE := &"bottle"
const HARDBACK := &"hardback"
## Expansion Phase 6: the night guard's master badge (the main entrance escape route).
const SECURITY_BADGE := &"security_badge"
## The Study 4 reserve shelf (approved 2026-10-31): three reserve books to put back, and
## its reward, the loading dock shutter's manual release key.
const RESERVE_BOOK_523 := &"reserve_book_523"
## What pressing F (use) says with a reserve book in hand (2026-11-03, on request): a hint
## that it goes back somewhere, not how to use a mechanism.
const RESERVE_USE_HINT := "Looks like this book belongs somewhere."
const RESERVE_BOOK_823 := &"reserve_book_823"
const RESERVE_BOOK_942 := &"reserve_book_942"
const DOCK_KEY := &"dock_key"
## Not a carried item: the rare manuscript's model (the main objective, an AccessCard in the
## Expanded Library that builds its model here; remodelled 2026-11-02).
const RARE_MANUSCRIPT_MODEL := &"rare_manuscript"

## id -> name, kind, look (mesh size, colour, "box" or "cylinder") and, for
## distractions, the noise made where it lands (radius in metres, intensity 0–1).
const ITEMS := {
	TOOLKIT: {"name": "Tool kit", "kind": Kind.TOOL,
		"size": Vector3(0.46, 0.2, 0.26), "colour": Color(0.78, 0.16, 0.12), "shape": "box"},
	STAFF_CARD: {"name": "Staff access card", "kind": Kind.CARD,
		"size": Vector3(0.26, 0.015, 0.17), "colour": Color(0.2, 0.55, 0.95), "shape": "box"},
	SECURITY_BADGE: {"name": "Security master badge", "kind": Kind.CARD,
		"size": Vector3(0.24, 0.02, 0.16), "colour": Color(0.95, 0.75, 0.15), "shape": "box"},
	RESERVE_BOOK_523: {"name": "Reserve book 523.8", "use_hint": RESERVE_USE_HINT, "kind": Kind.TOOL,
		"size": Vector3(0.2, 0.05, 0.27), "colour": Color(0.2, 0.42, 0.3), "shape": "box"},
	RESERVE_BOOK_823: {"name": "Reserve book 823.8", "use_hint": RESERVE_USE_HINT, "kind": Kind.TOOL,
		"size": Vector3(0.2, 0.05, 0.27), "colour": Color(0.6, 0.16, 0.13), "shape": "box"},
	RESERVE_BOOK_942: {"name": "Reserve book 942.1", "use_hint": RESERVE_USE_HINT, "kind": Kind.TOOL,
		"size": Vector3(0.2, 0.05, 0.27), "colour": Color(0.18, 0.28, 0.5), "shape": "box"},
	DOCK_KEY: {"name": "Dock release key", "kind": Kind.TOOL,
		"size": Vector3(0.14, 0.025, 0.06), "colour": Color(0.85, 0.68, 0.25), "shape": "box"},
	BOTTLE: {"name": "Glass bottle", "kind": Kind.DISTRACTION, "noise_radius": 14.0, "noise_intensity": 1.0, "caption": "Glass smashes",
		"size": Vector3(0.09, 0.3, 0.09), "colour": Color(0.3, 0.7, 0.45), "shape": "cylinder"},
	HARDBACK: {"name": "Heavy hardback", "kind": Kind.DISTRACTION, "noise_radius": 10.0, "noise_intensity": 0.8, "caption": "Heavy thud",
		"size": Vector3(0.24, 0.07, 0.32), "colour": Color(0.45, 0.25, 0.14), "shape": "box"},
}


static func has_item(id: StringName) -> bool:
	return ITEMS.has(id)


static func item_name(id: StringName) -> String:
	return ITEMS[id].name if ITEMS.has(id) else String(id)


## What using the item with F says, if it has its own line ("" for the kind's usual hint).
static func use_hint(id: StringName) -> String:
	return String(ITEMS[id].get("use_hint", "")) if ITEMS.has(id) else ""


static func get_kind(id: StringName) -> Kind:
	return ITEMS[id].kind if ITEMS.has(id) else Kind.TOOL


## Tools and cards are never used up; distractions are.
static func is_reusable(id: StringName) -> bool:
	return get_kind(id) != Kind.DISTRACTION


## A small low-poly model for the item, resting on y = 0, centred on x and z, about
## its "size" (remodelled 2026-11-02, on request: built from a few boxes, cylinders and a
## torus per item instead of one coloured box). A "Model" Node3D of MeshInstance3D parts.
static func make_model(id: StringName) -> Node3D:
	var info: Dictionary = ITEMS.get(id, ITEMS[TOOLKIT])
	var model := Node3D.new()
	model.name = "Model"
	var c: Color = info.colour
	match id:
		TOOLKIT:
			_toolbox(model, c)
		STAFF_CARD:
			_id_card(model, info.size, c, Color(0.97, 0.97, 0.95), false)
		SECURITY_BADGE:
			_id_card(model, info.size, Color(0.1, 0.13, 0.25), c, true)
		RESERVE_BOOK_523, RESERVE_BOOK_823, RESERVE_BOOK_942:
			_book(model, info.size, c, true)
		HARDBACK:
			_book(model, info.size, c, false)
		DOCK_KEY:
			_key(model, c)
		BOTTLE:
			_bottle(model, c)
		RARE_MANUSCRIPT_MODEL:
			_manuscript(model)
		_:
			_part(model, BoxMesh.new(), info.size, Vector3(0, info.size.y / 2.0, 0), _mat(c))
	return model


static func _mat(colour: Color, roughness := 0.6, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = roughness
	m.metallic = metallic
	if colour.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _part(parent: Node3D, mesh: PrimitiveMesh, size: Vector3, at: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.rotation = rot
	mi.material_override = material
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	return _part(parent, BoxMesh.new(), size, at, material)


static func _cylinder(parent: Node3D, top: float, bottom: float, height: float, at: Vector3, material: Material, sides := 12) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = top
	cyl.bottom_radius = bottom
	cyl.height = height
	cyl.radial_segments = sides
	cyl.rings = 1
	return _part(parent, cyl, Vector3.ZERO, at, material)


## A red steel tool box: body, lid, a dark seam, two latches and a carry handle.
static func _toolbox(m: Node3D, c: Color) -> void:
	var red := _mat(c, 0.45, 0.3)
	var steel := _mat(Color(0.72, 0.73, 0.75), 0.35, 0.8)
	var black := _mat(Color(0.08, 0.08, 0.09), 0.7)
	_box(m, Vector3(0.46, 0.13, 0.26), Vector3(0, 0.065, 0), red)
	_box(m, Vector3(0.47, 0.05, 0.27), Vector3(0, 0.155, 0), _mat(c.darkened(0.15), 0.45, 0.3))
	_box(m, Vector3(0.464, 0.008, 0.264), Vector3(0, 0.131, 0), black)
	for x in [-0.15, 0.15]:
		_box(m, Vector3(0.045, 0.05, 0.012), Vector3(x, 0.13, 0.138), steel)
		_box(m, Vector3(0.02, 0.045, 0.02), Vector3(x * 0.6, 0.2, 0), black)
	_box(m, Vector3(0.22, 0.025, 0.035), Vector3(0, 0.232, 0), black)


## An ID card lying flat: a coloured card with a white panel, a photo, text lines, a chip
## and a clip; `badge`: a navy card with a gold band and seal (the master badge).
static func _id_card(m: Node3D, size: Vector3, card: Color, accent: Color, badge: bool) -> void:
	var t := size.y
	var w := size.x
	var d := size.z
	_box(m, Vector3(w, t, d), Vector3(0, t / 2.0, 0), _mat(card, 0.4))
	var top := t + 0.001
	var ink := _mat(Color(0.15, 0.16, 0.2), 0.5)
	if badge:
		_box(m, Vector3(w, 0.002, d * 0.26), Vector3(0, top, -d * 0.32), _mat(accent, 0.3, 0.6))
		_cylinder(m, d * 0.16, d * 0.16, 0.004, Vector3(w * 0.27, top + 0.001, d * 0.12), _mat(accent, 0.25, 0.85), 16)
		_cylinder(m, d * 0.1, d * 0.1, 0.005, Vector3(w * 0.27, top + 0.002, d * 0.12), _mat(card.lightened(0.15), 0.4), 16)
	else:
		_box(m, Vector3(w * 0.62, 0.002, d * 0.62), Vector3(w * 0.1, top, d * 0.1), _mat(accent, 0.5))
		_box(m, Vector3(w * 0.12, 0.003, d * 0.16), Vector3(-w * 0.34, top + 0.001, -d * 0.2), _mat(Color(0.85, 0.7, 0.3), 0.3, 0.7))
	# The photo and the text lines.
	_box(m, Vector3(w * 0.24, 0.003, d * 0.42), Vector3(-w * 0.12 if not badge else -w * 0.28, top + 0.001, d * 0.14), _mat(Color(0.62, 0.66, 0.72), 0.5))
	for k in 3:
		var x := w * 0.17 if not badge else -w * 0.02
		_box(m, Vector3(w * (0.3 - 0.06 * k), 0.003, d * 0.05), Vector3(x, top + 0.001, d * (0.0 + 0.13 * k)), ink if not badge else _mat(accent, 0.4))
	# The clip at the short end.
	var steel := _mat(Color(0.75, 0.76, 0.78), 0.3, 0.8)
	_box(m, Vector3(w * 0.12, t + 0.008, d * 0.1), Vector3(-w * 0.5 - w * 0.03, (t + 0.008) / 2.0, 0), steel)


## A book lying flat, its spine along −x: two covers, a cream page block and the spine;
## `reserve`: a white call-number label on the spine and a sticker on the cover; else
## (the hardback) gold bands on the spine.
static func _book(m: Node3D, size: Vector3, c: Color, reserve: bool) -> void:
	var cover := _mat(c, 0.7)
	var ct := 0.006
	_box(m, Vector3(size.x, ct, size.z), Vector3(0, ct / 2.0, 0), cover)
	_box(m, Vector3(size.x, ct, size.z), Vector3(0, size.y - ct / 2.0, 0), cover)
	_box(m, Vector3(0.008, size.y, size.z), Vector3(-size.x / 2.0 + 0.004, size.y / 2.0, 0), cover)
	_box(m, Vector3(size.x - 0.018, size.y - 2.0 * ct, size.z - 0.014), Vector3(0.001, size.y / 2.0, 0), _mat(Color(0.93, 0.9, 0.8), 0.9))
	if reserve:
		var white := _mat(Color(0.97, 0.97, 0.95), 0.6)
		_box(m, Vector3(0.002, size.y * 0.6, 0.05), Vector3(-size.x / 2.0 - 0.001, size.y / 2.0, size.z * 0.3), white)
		_box(m, Vector3(size.x * 0.42, 0.002, size.z * 0.16), Vector3(size.x * 0.08, size.y + 0.001, -size.z * 0.28), white)
		_box(m, Vector3(size.x * 0.6, 0.002, 0.012), Vector3(size.x * 0.08, size.y + 0.001, size.z * 0.05), _mat(Color(0.95, 0.8, 0.2), 0.5))
	else:
		var gold := _mat(Color(0.85, 0.68, 0.3), 0.3, 0.8)
		for z in [-0.35, -0.3, 0.3, 0.35]:
			_box(m, Vector3(0.003, size.y * 0.9, 0.008), Vector3(-size.x / 2.0 - 0.0015, size.y / 2.0, size.z * z), gold)


## A big brass key lying flat (bow, shank, bit) on a ring with a red tag.
static func _key(m: Node3D, c: Color) -> void:
	var brass := _mat(c, 0.3, 0.85)
	var y := 0.006
	var bow := TorusMesh.new()
	bow.inner_radius = 0.012
	bow.outer_radius = 0.024
	bow.rings = 16
	bow.ring_segments = 6
	_part(m, bow, Vector3.ZERO, Vector3(-0.04, y, 0), brass)
	_box(m, Vector3(0.085, 0.01, 0.012), Vector3(0.022, y, 0), brass)
	_box(m, Vector3(0.012, 0.01, 0.022), Vector3(0.056, y, 0.014), brass)
	_box(m, Vector3(0.01, 0.01, 0.014), Vector3(0.038, y, 0.01), brass)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.009
	ring.outer_radius = 0.012
	ring.rings = 12
	ring.ring_segments = 4
	_part(m, ring, Vector3.ZERO, Vector3(-0.072, 0.003, 0), _mat(Color(0.72, 0.73, 0.75), 0.3, 0.8))
	_box(m, Vector3(0.05, 0.004, 0.03), Vector3(-0.1, 0.003, 0.0), _mat(Color(0.8, 0.12, 0.1), 0.5))
	_box(m, Vector3(0.03, 0.002, 0.012), Vector3(-0.102, 0.006, 0.0), _mat(Color(0.97, 0.97, 0.95), 0.5))


## A green glass bottle: body, shoulder, neck, lip and a paper label.
static func _bottle(m: Node3D, c: Color) -> void:
	var glass := _mat(Color(c.r * 0.6, c.g * 0.8, c.b * 0.6, 0.78), 0.08)
	glass.metallic_specular = 0.8
	_cylinder(m, 0.045, 0.045, 0.19, Vector3(0, 0.095, 0), glass)
	_cylinder(m, 0.017, 0.045, 0.05, Vector3(0, 0.215, 0), glass)
	_cylinder(m, 0.016, 0.016, 0.05, Vector3(0, 0.265, 0), glass)
	_cylinder(m, 0.019, 0.019, 0.012, Vector3(0, 0.294, 0), glass)
	_cylinder(m, 0.0465, 0.0465, 0.075, Vector3(0, 0.09, 0), _mat(Color(0.92, 0.86, 0.66), 0.8))


## The rare manuscript: an old leather-bound volume (the size of its old box), gold corners,
## raised bands on the spine, a clasp and a seal (AccessCard adds its glow).
static func _manuscript(m: Node3D) -> void:
	var size := Vector3(0.3, 0.08, 0.4)
	var leather := _mat(Color(0.42, 0.13, 0.1), 0.75)
	var gold := _mat(Color(0.88, 0.7, 0.3), 0.3, 0.85)
	var ct := 0.01
	_box(m, Vector3(size.x, ct, size.z), Vector3(0, ct / 2.0, 0), leather)
	_box(m, Vector3(size.x, ct, size.z), Vector3(0, size.y - ct / 2.0, 0), leather)
	_box(m, Vector3(0.014, size.y, size.z), Vector3(-size.x / 2.0 + 0.007, size.y / 2.0, 0), leather)
	_box(m, Vector3(size.x - 0.03, size.y - 2.0 * ct, size.z - 0.024), Vector3(0.003, size.y / 2.0, 0), _mat(Color(0.86, 0.78, 0.6), 0.95))
	for z in [-0.32, -0.12, 0.12, 0.32]:
		_box(m, Vector3(0.006, size.y + 0.004, 0.018), Vector3(-size.x / 2.0 - 0.002, size.y / 2.0, size.z * z), leather)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_box(m, Vector3(0.05, 0.004, 0.05), Vector3(cx * (size.x / 2.0 - 0.024), size.y + 0.001, cz * (size.z / 2.0 - 0.024)), gold)
	_cylinder(m, 0.05, 0.05, 0.004, Vector3(0.01, size.y + 0.002, 0), gold, 20)
	_cylinder(m, 0.032, 0.032, 0.005, Vector3(0.01, size.y + 0.003, 0), leather, 20)
	_box(m, Vector3(0.05, size.y + 0.006, 0.03), Vector3(size.x / 2.0 - 0.01, size.y / 2.0, 0), _mat(Color(0.3, 0.09, 0.07), 0.7))
	_box(m, Vector3(0.03, 0.006, 0.04), Vector3(size.x / 2.0 - 0.03, size.y + 0.003, 0), gold)
