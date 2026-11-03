@tool
extends Node
## Applied in both editor and runtime: moving bodies receive probes and must
## never become stationary shadows in the compound's baked lighting.
func _ready() -> void:
	for mesh in get_parent().find_children("*","GeometryInstance3D",true,false):
		mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
