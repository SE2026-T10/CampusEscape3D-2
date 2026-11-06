extends "res://maps/isg_museum/scripts/demo_pickup.gd"

## T1 leaves physical evidence for its inspector after the canvas is taken.
## The frame is visual only; it never changes walking/navigation collision.
signal artwork_taken

var _is_missing := false
var is_missing: bool:
	get:
		return _is_missing

@onready var inspection_target: Marker3D = $InspectionTarget


func is_artwork_missing() -> bool:
	return _is_missing


func _on_interact(_by: Node) -> bool:
	var objectives := ObjectiveManager.find(self)
	if objectives == null or not objectives.complete(objective_id):
		return false
	_is_missing = true
	enabled = false
	# Keep the root and its frame visible; only the artwork is removed.
	# An invisible interaction Area must not block selecting objects behind it.
	collision_layer = 0
	$Canvas.hide()
	$Label3D.text = "T1 · KHUNG TRỐNG"
	artwork_taken.emit()
	return true
