class_name GroceryStyle
extends RefCounted

## Re-dresses the shared guard model for this map (no shared file is touched). The model is a
## handful of boxes, so the change is done by repainting the parts by name and adding a few boxes:
##   staff     white polo, coloured apron with a name tag, dark trousers, a store cap (some);
##   customers everyday clothes that differ per person (shirt, trousers, hair, skin), sometimes a
##             beanie or a cap, and a shopping basket, a tote bag or a backpack.
## Everything is picked from the variant index, so the same walker always looks the same.

const POLO := Color(0.94, 0.94, 0.9)
const STAFF_TROUSERS := Color(0.17, 0.19, 0.27)
const APRONS := [Color(0.16, 0.55, 0.3), Color(0.2, 0.4, 0.75), Color(0.9, 0.5, 0.15)]
const STAFF_CAP := Color(0.78, 0.15, 0.15)

const SHIRTS := [Color(0.85, 0.4, 0.2), Color(0.3, 0.45, 0.8), Color(0.75, 0.7, 0.2),
	Color(0.6, 0.3, 0.65), Color(0.85, 0.85, 0.82), Color(0.35, 0.35, 0.4), Color(0.7, 0.2, 0.3)]
const TROUSERS := [Color(0.2, 0.28, 0.5), Color(0.35, 0.3, 0.25), Color(0.15, 0.15, 0.17), Color(0.5, 0.5, 0.45)]
const HAIR := [Color(0.1, 0.07, 0.05), Color(0.35, 0.22, 0.1), Color(0.75, 0.6, 0.3), Color(0.6, 0.6, 0.6)]
const SKIN := [Color(0.86, 0.68, 0.54), Color(0.65, 0.46, 0.33), Color(0.95, 0.8, 0.68), Color(0.48, 0.33, 0.24)]
const HATS := [Color(0.25, 0.3, 0.55), Color(0.55, 0.2, 0.2), Color(0.3, 0.3, 0.3)]


static func dress_staff(guard: Node, variant := 0) -> void:
	_paint(guard, ["Chest", "Sleeve"], POLO)
	_paint(guard, ["Trouser"], STAFF_TROUSERS)
	_hide(guard, ["Badge"])
	var torso := guard.get_node_or_null("Model/Hips/Torso") as Node3D
	if torso:
		var apron: Color = APRONS[variant % APRONS.size()]
		_part(torso, "Apron", Vector3(0.45, 0.46, 0.03), Vector3(0, 0.23, -0.145), apron)
		_part(torso, "ApronSkirt", Vector3(0.4, 0.3, 0.03), Vector3(0, -0.12, -0.13), apron)
		_part(torso, "ApronStrap", Vector3(0.05, 0.1, 0.27), Vector3(-0.12, 0.48, 0), apron)
		_part(torso, "ApronStrapR", Vector3(0.05, 0.1, 0.27), Vector3(0.12, 0.48, 0), apron)
		_part(torso, "NameTag", Vector3(0.1, 0.055, 0.01), Vector3(-0.1, 0.36, -0.165), Color(0.97, 0.97, 0.97))
	if variant % 2 == 0:
		_paint(guard, ["Cap", "Brim"], STAFF_CAP)
	else:
		_hide(guard, ["Cap", "Brim"])


static func dress_customer(guard: Node, index: int) -> void:
	_paint(guard, ["Chest", "Sleeve"], SHIRTS[index % SHIRTS.size()])
	_paint(guard, ["Trouser"], TROUSERS[(index * 3 + 1) % TROUSERS.size()])
	_paint(guard, ["Hair"], HAIR[(index * 2 + 1) % HAIR.size()])
	_paint(guard, ["Face", "Hand"], SKIN[(index + 1) % SKIN.size()])
	_hide(guard, ["Badge"])
	match index % 3:
		0:  # Beanie: no brim.
			_paint(guard, ["Cap"], HATS[index % HATS.size()])
			_hide(guard, ["Brim"])
		1:  # Baseball cap.
			_paint(guard, ["Cap", "Brim"], HATS[(index + 1) % HATS.size()])
		_:  # Bare-headed.
			_hide(guard, ["Cap", "Brim"])
	var torso := guard.get_node_or_null("Model/Hips/Torso") as Node3D
	var right_hand := guard.get_node_or_null("Model/Hips/Torso/ArmR/Hand") as Node3D
	var left_hand := guard.get_node_or_null("Model/Hips/Torso/ArmL/Hand") as Node3D
	match index % 4:
		0, 2:  # Shopping basket in the right hand.
			if right_hand:
				_part(right_hand, "Basket", Vector3(0.32, 0.16, 0.22), Vector3(0, -0.14, -0.03), Color(0.85, 0.2, 0.15))
				_part(right_hand, "BasketHandle", Vector3(0.03, 0.14, 0.03), Vector3(0, -0.02, 0), Color(0.15, 0.15, 0.15))
		1:  # Tote bag in the left hand.
			if left_hand:
				_part(left_hand, "Tote", Vector3(0.22, 0.28, 0.08), Vector3(0, -0.2, 0), Color(0.85, 0.78, 0.55))
		3:  # Backpack.
			if torso:
				_part(torso, "Backpack", Vector3(0.3, 0.38, 0.14), Vector3(0, 0.25, 0.2), Color(0.25, 0.4, 0.3))


static func _material(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.8
	return m


static func _paint(guard: Node, names: Array, colour: Color) -> void:
	var material := _material(colour)
	for part in names:
		for node in guard.find_children(part, "MeshInstance3D", true, false):
			(node as MeshInstance3D).material_override = material


static func _hide(guard: Node, names: Array) -> void:
	for part in names:
		for node in guard.find_children(part, "MeshInstance3D", true, false):
			(node as MeshInstance3D).visible = false


static func _part(parent: Node3D, part_name: String, size: Vector3, at: Vector3, colour: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _material(colour)
	mi.position = at
	parent.add_child(mi)
