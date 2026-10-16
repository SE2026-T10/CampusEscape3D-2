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

## id -> name, kind, look (mesh size, colour, "box" or "cylinder") and, for
## distractions, the noise made where it lands (radius in metres, intensity 0–1).
const ITEMS := {
	TOOLKIT: {"name": "Tool kit", "kind": Kind.TOOL,
		"size": Vector3(0.46, 0.2, 0.26), "colour": Color(0.78, 0.16, 0.12), "shape": "box"},
	STAFF_CARD: {"name": "Staff access card", "kind": Kind.CARD,
		"size": Vector3(0.26, 0.015, 0.17), "colour": Color(0.2, 0.55, 0.95), "shape": "box"},
	SECURITY_BADGE: {"name": "Security master badge", "kind": Kind.CARD,
		"size": Vector3(0.24, 0.02, 0.16), "colour": Color(0.95, 0.75, 0.15), "shape": "box"},
	BOTTLE: {"name": "Glass bottle", "kind": Kind.DISTRACTION, "noise_radius": 14.0, "noise_intensity": 1.0,
		"size": Vector3(0.09, 0.3, 0.09), "colour": Color(0.3, 0.7, 0.45), "shape": "cylinder"},
	HARDBACK: {"name": "Heavy hardback", "kind": Kind.DISTRACTION, "noise_radius": 10.0, "noise_intensity": 0.8,
		"size": Vector3(0.24, 0.07, 0.32), "colour": Color(0.45, 0.25, 0.14), "shape": "box"},
}


static func has_item(id: StringName) -> bool:
	return ITEMS.has(id)


static func item_name(id: StringName) -> String:
	return ITEMS[id].name if ITEMS.has(id) else String(id)


static func get_kind(id: StringName) -> Kind:
	return ITEMS[id].kind if ITEMS.has(id) else Kind.TOOL


## Tools and cards are never used up; distractions are.
static func is_reusable(id: StringName) -> bool:
	return get_kind(id) != Kind.DISTRACTION


## A small low-poly mesh for the item, resting on y = 0.
static func make_model(id: StringName) -> MeshInstance3D:
	var info: Dictionary = ITEMS.get(id, ITEMS[TOOLKIT])
	var size: Vector3 = info.size
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Model"
	if info.shape == "cylinder":
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = size.x * 0.45
		cylinder.bottom_radius = size.x / 2.0
		cylinder.height = size.y
		cylinder.radial_segments = 8
		cylinder.rings = 1
		mesh_instance.mesh = cylinder
	else:
		var box := BoxMesh.new()
		box.size = size
		mesh_instance.mesh = box
	mesh_instance.position.y = size.y / 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = info.colour
	material.roughness = 0.6
	mesh_instance.material_override = material
	return mesh_instance
