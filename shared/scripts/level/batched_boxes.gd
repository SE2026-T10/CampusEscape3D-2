@tool
class_name BatchedBoxes
extends MultiMeshInstance3D

## Draws many coloured boxes as one MultiMesh of unit boxes, built when the scene
## loads (in the editor too), as ShelfBooks builds its books. Decoration only,
## with no collision. The Expanded Library's builder
## (maps/library/tools/build_expanded_graybox.gd) merges the level's static boxes
## into these, so the renderer draws a few batches instead of thousands of meshes.
##
## The boxes are kept as plain data (`boxes`) and the MultiMesh is never saved:
## a MultiMesh's instances live in the renderer, which a headless build (the
## level builder, the tests) does not keep, so a saved one would come back empty.

## Per box STRIDE floats: its transform (basis x, y and z, then origin; the basis
## scales a unit cube to the box) and its colour (r, g, b, a).
@export var boxes := PackedFloat32Array():
	set(value):
		boxes = value
		_rebuild()

const STRIDE := 16

static var _unit_box: BoxMesh


func _ready() -> void:
	_rebuild()


func _validate_property(property: Dictionary) -> void:
	if property.name == "multimesh":
		property.usage &= ~PROPERTY_USAGE_STORAGE   # rebuilt from `boxes`


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _unit_box == null:
		_unit_box = BoxMesh.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _unit_box
	mm.instance_count = box_count()
	for i in box_count():
		mm.set_instance_transform(i, box_transform(i))
		mm.set_instance_color(i, box_color(i))
	multimesh = mm


func box_count() -> int:
	return boxes.size() / STRIDE


## Box `i`'s transform in this node's space (applied to a unit cube centred on the origin).
func box_transform(i: int) -> Transform3D:
	var o := i * STRIDE
	return Transform3D(Vector3(boxes[o], boxes[o + 1], boxes[o + 2]), Vector3(boxes[o + 3], boxes[o + 4], boxes[o + 5]),
		Vector3(boxes[o + 6], boxes[o + 7], boxes[o + 8]), Vector3(boxes[o + 9], boxes[o + 10], boxes[o + 11]))


func box_color(i: int) -> Color:
	var o := i * STRIDE + 12
	return Color(boxes[o], boxes[o + 1], boxes[o + 2], boxes[o + 3])


## The bounds of box `i` in this node's space.
func box_aabb(i: int) -> AABB:
	return box_transform(i) * AABB(-Vector3.ONE / 2.0, Vector3.ONE)


## The bounds of all the boxes in this node's space (works without a renderer).
func local_aabb() -> AABB:
	if box_count() == 0:
		return AABB()
	var bounds := box_aabb(0)
	for i in range(1, box_count()):
		bounds = bounds.merge(box_aabb(i))
	return bounds


## Appends a box to a `boxes` array (used by the level builder).
static func pack(into: PackedFloat32Array, transform: Transform3D, colour: Color) -> void:
	var b := transform.basis
	into.append_array([b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z,
		transform.origin.x, transform.origin.y, transform.origin.z, colour.r, colour.g, colour.b, colour.a])
