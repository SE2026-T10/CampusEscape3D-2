extends Node3D
## This overlay sits outside the baked environment; use its probes for imported props.
func _ready() -> void:
	for mesh in find_children("*","GeometryInstance3D",true,false):
		mesh.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
