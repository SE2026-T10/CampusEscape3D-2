extends "res://maps/isg_museum/scripts/demo_pickup.gd"

@export var exhibit_name := "A2 · Bản phong cảnh nhỏ"
var is_missing := false


func _on_interact(_by: Node) -> bool:
	var objectives := ObjectiveManager.find(self)
	if objectives == null or not objectives.complete(objective_id):
		return false
	is_missing = true
	enabled = false
	collision_layer = 0
	$Canvas.hide()
	$Label3D.text = exhibit_name + "\nKHUNG TRỐNG"
	return true
