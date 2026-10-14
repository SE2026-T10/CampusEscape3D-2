class_name AreaUtils
extends RefCounted

## Geometric "is the player in this area" checks for gameplay areas
## (objective triggers, checkpoints).
##
## These are used instead of body_entered / get_overlapping_bodies(). Physics
## overlap reports lag a step behind teleports, and when the player is caught,
## frozen and respawned they report a stale "entered" at the spot where the
## player was caught.


## True if `point` is inside any BoxShape3D child of `area`, with the box
## widened horizontally by `margin`.
static func box_shapes_contain(area: Node3D, point: Vector3, margin := 0.0) -> bool:
	for child in area.get_children():
		var shape := child as CollisionShape3D
		if shape == null or shape.disabled or not (shape.shape is BoxShape3D):
			continue
		var local := shape.global_transform.affine_inverse() * point
		var half: Vector3 = (shape.shape as BoxShape3D).size / 2.0
		if absf(local.x) <= half.x + margin and absf(local.y) <= half.y and absf(local.z) <= half.z + margin:
			return true
	return false


## True if the player (group "player") stands inside `area`'s box shapes.
## `radius` is how far outside the player's centre may be and still count.
static func contains_player(area: Node3D, radius := 0.35) -> bool:
	if not area.is_inside_tree():
		return false
	var player := area.get_tree().get_first_node_in_group("player") as Node3D
	return player != null and box_shapes_contain(area, player.global_position + Vector3(0, 0.5, 0), radius)
