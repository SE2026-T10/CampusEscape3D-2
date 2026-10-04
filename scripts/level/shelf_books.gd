@tool
class_name ShelfBooks
extends Node3D

## Fills a bookcase with low-poly books and shelf boards: one MultiMesh of
## coloured boxes, built when the scene loads (in the editor too). Decoration
## only, with no collision; the bookcase's own collider is what blocks sight
## and movement. Put it as a child of the bookcase body, centred on it.
##
## The generated mesh is an unsaved internal child, so the scene file stays
## small and the books are rebuilt identically from `book_seed` every time.

## Size of the bookcase box (local), metres. Books line the two long faces.
@export var size := Vector3(0.6, 2.2, 10.0):
	set(value):
		size = value
		_rebuild()
## Shelf rows per side.
@export_range(1, 8) var rows := 4:
	set(value):
		rows = value
		_rebuild()
## Same seed → same books.
@export var book_seed := 1:
	set(value):
		book_seed = value
		_rebuild()

const PALETTE := [Color(0.55, 0.14, 0.12), Color(0.16, 0.32, 0.22), Color(0.17, 0.25, 0.42), Color(0.62, 0.47, 0.2),
	Color(0.4, 0.25, 0.15), Color(0.7, 0.62, 0.48), Color(0.3, 0.14, 0.28), Color(0.12, 0.12, 0.14), Color(0.48, 0.18, 0.1)]
const BOARD := Color(0.28, 0.18, 0.1)

var _instance: MultiMeshInstance3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _instance:
		_instance.queue_free()
	_instance = MultiMeshInstance3D.new()
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_instance)  # no owner: never saved into the scene
	_instance.multimesh = build_multimesh()


## The books and boards as a MultiMesh of unit boxes (scale = size, colour per instance).
func build_multimesh() -> MultiMesh:
	var layout := compute_layout()
	var transforms: Array = layout[0]
	var colours: Array = layout[1]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	box.material = material
	mm.mesh = box
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colours[i])
	return mm


## [transforms, colours] for every book and board. Pure: the same inputs give the same layout.
func compute_layout() -> Array:
	var along_x := size.x > size.z
	var length := size.x if along_x else size.z
	var depth := size.z if along_x else size.x
	var rng := RandomNumberGenerator.new()
	rng.seed = book_seed
	var transforms: Array[Transform3D] = []
	var colours: Array[Color] = []
	var row_h := size.y / rows
	for side in [-1.0, 1.0]:
		for r in rows:
			var floor_y := -size.y / 2.0 + r * row_h
			# Board along the face.
			_add(transforms, colours, along_x, Vector3(length, 0.035, 0.08), 0.0, floor_y + 0.0175, side * (depth / 2.0 - 0.02), BOARD)
			var t := -length / 2.0 + 0.04
			while t < length / 2.0 - 0.06:
				var w := rng.randf_range(0.045, 0.1)
				if rng.randf() < 0.06:
					t += w * 2.0  # a gap
					continue
				var h := row_h * rng.randf_range(0.55, 0.82)
				var d := rng.randf_range(0.16, 0.22)
				var colour: Color = PALETTE[rng.randi() % PALETTE.size()].lightened(rng.randf_range(-0.08, 0.12))
				_add(transforms, colours, along_x, Vector3(w, h, d), t + w / 2.0, floor_y + 0.035 + h / 2.0, side * (depth / 2.0 - d / 2.0 + 0.025), colour)
				t += w + 0.004
	return [transforms, colours]


func _add(transforms: Array[Transform3D], colours: Array[Color], along_x: bool, box: Vector3, along: float, y: float, across: float, colour: Color) -> void:
	var scale := Vector3(box.x, box.y, box.z) if along_x else Vector3(box.z, box.y, box.x)
	var origin := Vector3(along, y, across) if along_x else Vector3(across, y, along)
	transforms.append(Transform3D(Basis.from_scale(scale), origin))
	colours.append(colour)
