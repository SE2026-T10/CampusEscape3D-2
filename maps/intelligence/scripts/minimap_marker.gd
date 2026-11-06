extends Control
## This retained canvas item rotates/moves without redrawing the static floor plan.
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_circle(Vector2.ZERO,8,Color("091719"))
	var arrow := PackedVector2Array([Vector2(0,-8),Vector2(5,5),Vector2(0,2),Vector2(-5,5)])
	draw_colored_polygon(arrow,Color("69ffe1"))
	arrow.append(arrow[0])
	draw_polyline(arrow,Color("e4fff6"),1,true)
