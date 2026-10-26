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
## Render layers of the books (the default, 1, is what the tutorial uses; a level
## can put them on its own layers, e.g. to choose which lights reach them).
@export_flags_3d_render var layers := 1:
	set(value):
		layers = value
		if _instance:
			_instance.layers = value
## Beyond this distance (metres) from the camera the books are not drawn and the
## bookcase shows its own box; 0 (the default, what the tutorial uses) draws them
## at any distance. For levels with many bookcases.
@export var draw_distance := 0.0:
	set(value):
		draw_distance = value
		if _instance:
			_instance.visibility_range_end = value
## Bay width (metres) along the bookcase: > 0 adds an upright between bays, which the
## books keep clear of, and lets `sparse` thin out whole bays. 0 (the default, what the
## tutorial uses) gives one continuous run of books per shelf, exactly as before.
@export var bay := 0.0:
	set(value):
		bay = value
		_rebuild()
## With `bay` > 0: the share of shelf bays (0…1) that are half empty, their last book
## leaning on the others. Chosen from `book_seed` too, so the layout stays stable.
@export_range(0.0, 1.0) var sparse := 0.0:
	set(value):
		sparse = value
		_rebuild()
## Colour of the shelf boards and uprights.
@export var board_colour := Color(0.28, 0.18, 0.1):
	set(value):
		board_colour = value
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
	_instance.layers = layers
	_instance.visibility_range_end = draw_distance
	_instance.visibility_range_end_margin = 1.0 if draw_distance > 0.0 else 0.0
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
	if bay > 0.0:
		_layout_bays(transforms, colours, rng, along_x, length, depth, row_h)
		return [transforms, colours]
	for side in [-1.0, 1.0]:
		for r in rows:
			var floor_y := -size.y / 2.0 + r * row_h
			# Board along the face.
			_add(transforms, colours, along_x, Vector3(length, 0.035, 0.08), 0.0, floor_y + 0.0175, side * (depth / 2.0 - 0.02), board_colour)
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


## The bay layout (`bay` > 0): uprights between bays, books per bay, some bays half
## empty with their last book leaning on the others.
func _layout_bays(transforms: Array[Transform3D], colours: Array[Color], rng: RandomNumberGenerator,
		along_x: bool, length: float, depth: float, row_h: float) -> void:
	var bays := maxi(1, roundi(length / bay))
	var w_bay := length / bays
	const POST := 0.035
	for i in bays + 1:
		var at := -length / 2.0 + i * w_bay
		at = clampf(at, -length / 2.0 + POST / 2.0, length / 2.0 - POST / 2.0)
		_add(transforms, colours, along_x, Vector3(POST, size.y, depth + 0.05), at, 0.0, 0.0, board_colour)
	for side in [-1.0, 1.0]:
		for r in rows:
			var floor_y := -size.y / 2.0 + r * row_h
			_add(transforms, colours, along_x, Vector3(length, 0.035, 0.08), 0.0, floor_y + 0.0175, side * (depth / 2.0 - 0.02), board_colour)
			for b in bays:
				var x0 := -length / 2.0 + b * w_bay + POST / 2.0 + 0.01
				var x1 := x0 + w_bay - POST - 0.02
				var thin := rng.randf() < sparse
				var stop := x1 - 0.06
				if thin:
					stop = x0 + (x1 - x0) * rng.randf_range(0.3, 0.6)
				var t := x0
				var last_h := row_h * 0.7
				while t < stop:
					var w := rng.randf_range(0.045, 0.1)
					if t + w > x1:
						break
					if not thin and rng.randf() < 0.06:
						t += w * 2.0
						continue
					var h := row_h * rng.randf_range(0.55, 0.82)
					var d := rng.randf_range(0.16, 0.22)
					var colour: Color = PALETTE[rng.randi() % PALETTE.size()].lightened(rng.randf_range(-0.08, 0.12))
					_add(transforms, colours, along_x, Vector3(w, h, d), t + w / 2.0, floor_y + 0.035 + h / 2.0, side * (depth / 2.0 - d / 2.0 + 0.025), colour)
					t += w + 0.004
					last_h = h
				if thin and t < x1 - 0.2:
					# A book leaning on the last one: tilted about the shelf's depth axis.
					var w := 0.05
					var h := minf(last_h, row_h * 0.7)
					var tilt := 0.32
					var base := t + 0.01 + h * sin(tilt) / 2.0 + w / 2.0
					var colour: Color = PALETTE[rng.randi() % PALETTE.size()]
					var scale := Vector3(w, h, 0.18) if along_x else Vector3(0.18, h, w)
					# Its top towards the bay's books (towards −along) on either axis.
					var basis := Basis(Vector3.FORWARD if along_x else Vector3.RIGHT, -tilt) * Basis.from_scale(scale)
					var y := floor_y + 0.035 + h * cos(tilt) / 2.0 + w * sin(tilt) / 2.0
					var across: float = side * (depth / 2.0 - 0.09 + 0.025)
					var origin := Vector3(base, y, across) if along_x else Vector3(across, y, base)
					transforms.append(Transform3D(basis, origin))
					colours.append(colour)


func _add(transforms: Array[Transform3D], colours: Array[Color], along_x: bool, box: Vector3, along: float, y: float, across: float, colour: Color) -> void:
	var scale := Vector3(box.x, box.y, box.z) if along_x else Vector3(box.z, box.y, box.x)
	var origin := Vector3(along, y, across) if along_x else Vector3(across, y, along)
	transforms.append(Transform3D(Basis.from_scale(scale), origin))
	colours.append(colour)
