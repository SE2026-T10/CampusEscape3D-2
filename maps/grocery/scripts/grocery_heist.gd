class_name GroceryHeist
extends MapHudProvider

## The Morning Grocery mission: which item must be stolen this run, and where it is.
##
## One of ITEMS and one of the "loot_spots" markers are drawn when the scene loads, so every
## Restart is a new heist. Being caught and respawning does not redraw (the scene is not
## reloaded). `seed_value` (0 = random) and `forced_item` / `forced_spot` make a draw
## reproducible for tests and level design.
##
## It also is the map's MapHudProvider: the HUD shows the target and whether it is in hand.
## "Carrying the loot" is read from the objective flow (STEAL completed), so it follows the
## checkpoint restore with no state of its own.

const STEAL := &"steal_item"
const ENTER := &"enter_store"
const REACH_EXIT := &"reach_exit"
const ESCAPE := &"escape"

## id -> what the target is. Looks are built from boxes/cylinders by make_model().
const ITEMS := [
	{"id": &"saffron", "name": "Premium saffron tin", "size": Vector3(0.12, 0.1, 0.12), "colour": Color(0.85, 0.45, 0.1), "shape": "cylinder"},
	{"id": &"whisky", "name": "Aged whisky bottle", "size": Vector3(0.1, 0.34, 0.1), "colour": Color(0.55, 0.3, 0.1), "shape": "cylinder"},
	{"id": &"cigars", "name": "Box of cigars", "size": Vector3(0.28, 0.08, 0.16), "colour": Color(0.35, 0.2, 0.12), "shape": "box"},
	{"id": &"formula", "name": "Imported baby formula", "size": Vector3(0.16, 0.22, 0.16), "colour": Color(0.3, 0.55, 0.85), "shape": "cylinder"},
	{"id": &"caviar", "name": "Jar of caviar", "size": Vector3(0.09, 0.07, 0.09), "colour": Color(0.1, 0.1, 0.14), "shape": "cylinder"},
]

## 0 draws randomly; any other value gives the same draw every time.
@export var seed_value := 0
## Index into ITEMS / the loot_spots group; -1 leaves it to the draw.
@export var forced_item := -1
@export var forced_spot := -1
@export var loot: Loot
## Marker3D nodes (group "loot_spots") are read in tree order.
@export var spots_group := &"loot_spots"

## The chosen ITEMS entry and the index of the chosen spot (set in _ready).
var item: Dictionary = {}
var spot_index := -1


func _ready() -> void:
	super()
	add_to_group("grocery_heist")
	var spots := get_tree().get_nodes_in_group(spots_group)
	var pick := choose(seed_value, ITEMS.size(), spots.size(), forced_item, forced_spot)
	item = ITEMS[pick.item]
	spot_index = pick.spot
	var manager := ObjectiveManager.find(self)
	if manager:
		manager.setup(build_objectives(item.name))
	if loot:
		if spot_index >= 0:
			loot.global_position = (spots[spot_index] as Node3D).global_position
		loot.set_item(item)


static func find(node: Node) -> GroceryHeist:
	if not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group("grocery_heist") as GroceryHeist


## The draw: {item: index, spot: index}. Pure, so tests can check it without a scene.
## `spot_count` 0 gives spot -1 (nothing to place the loot on).
static func choose(seed_value: int, item_count: int, spot_count: int, forced_item := -1, forced_spot := -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	var picked_item := rng.randi_range(0, item_count - 1)
	var picked_spot := rng.randi_range(0, spot_count - 1) if spot_count > 0 else -1
	if forced_item >= 0:
		picked_item = mini(forced_item, item_count - 1)
	if forced_spot >= 0 and spot_count > 0:
		picked_spot = mini(forced_spot, spot_count - 1)
	return {"item": picked_item, "spot": picked_spot}


## The mission as ObjectiveManager objectives, with the target's name in the steal step.
static func build_objectives(item_name: String) -> Array[Dictionary]:
	return [
		{"id": ENTER, "title": "Walk into the store",
			"hint": "Go through the front doors like any other customer.", "done": "You're inside"},
		{"id": STEAL, "title": "Steal: %s" % item_name,
			"hint": "Find it on the shelves. Customers and staff must not see you take it.", "done": "%s taken" % item_name},
		{"id": REACH_EXIT, "title": "Get to a back exit",
			"hint": "Back door or the stockroom door. Staff will come if a customer sees you.", "done": "Exit reached"},
		{"id": ESCAPE, "title": "Slip out",
			"hint": "Use E at the exit door.", "done": "Escaped with the goods"},
	]


## True while the target is in the player's hands.
func has_loot() -> bool:
	var manager := ObjectiveManager.find(self)
	return manager != null and manager.is_completed(STEAL)


# --- MapHudProvider ----------------------------------------------------------------------------

func get_status_lines() -> Array[String]:
	var lines: Array[String] = []
	if item.is_empty():
		return lines
	lines.append("TARGET: %s" % item.name)
	lines.append("IN HAND: %s" % ("yes - get out unseen" if has_loot() else "not yet"))
	return lines


func get_result_lines() -> Array[String]:
	var lines: Array[String] = []
	if not item.is_empty():
		lines.append("Stolen: %s" % item.name)
	return lines


# --- Models ------------------------------------------------------------------------------------

## A small model of an ITEMS entry, resting on y = 0 and centred on x/z, in a node named "Model".
static func make_model(entry: Dictionary) -> Node3D:
	var model := Node3D.new()
	model.name = "Model"
	var size: Vector3 = entry.size
	var material := StandardMaterial3D.new()
	material.albedo_color = entry.colour
	material.roughness = 0.5
	var mi := MeshInstance3D.new()
	if entry.shape == "cylinder":
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = size.x / 2.0
		cylinder.bottom_radius = size.x / 2.0
		cylinder.height = size.y
		mi.mesh = cylinder
	else:
		var box := BoxMesh.new()
		box.size = size
		mi.mesh = box
	mi.material_override = material
	mi.position = Vector3(0, size.y / 2.0, 0)
	model.add_child(mi)
	return model
