class_name PickupMarker
extends Label3D

## A floating "!" over something to pick up (requested by the owner on 2026-11-02): the
## clue documents' marker (DocumentPickup), a little smaller by default. It shows while its
## parent is visible (an item hidden once taken hides it too) and bobs and pulses only then.

## Where it floats, from its parent (it bobs around this point).
var base := Vector3.ZERO
var _time := 0.0


func _init(at := Vector3.ZERO, pixel := 0.003) -> void:
	name = "Marker"
	text = "!"
	font_size = 96
	pixel_size = pixel
	outline_size = 18
	modulate = Color(1.0, 0.82, 0.1)
	outline_modulate = Color(0.12, 0.08, 0.0)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	base = at
	position = at


func _ready() -> void:
	set_process(is_visible_in_tree())


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		set_process(is_visible_in_tree())


func _process(delta: float) -> void:
	_time += delta
	position = base + Vector3(0, sin(_time * 2.4) * 0.04, 0)
	scale = Vector3.ONE * (1.0 + 0.08 * sin(_time * 4.8))
