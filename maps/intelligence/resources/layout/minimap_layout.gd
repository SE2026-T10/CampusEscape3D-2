extends Resource
## Generated from the same authoring geometry as the playable K17 scene.
@export var ground_bounds := Rect2(-48,-53,96,108)
@export var basement_bounds := Rect2(-12,-52,48,30)
@export var ground: Dictionary = {}
@export var basement: Dictionary = {}
@export var stairs: Array[Rect2] = []

func bounds_for(floor_id: int) -> Rect2:
	return basement_bounds if floor_id==1 else ground_bounds

func shapes_for(floor_id: int,kind: String) -> Array:
	return (basement if floor_id==1 else ground).get(kind,[])
