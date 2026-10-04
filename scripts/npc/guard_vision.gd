class_name GuardVision
extends Node3D

## Line-of-sight perception with a 0–100 detection meter.
##
## Place this node at the NPC's eye height; it looks along its own -Z axis,
## so it turns with the NPC. Each physics frame it checks the target (the
## node in the "player" group) for distance, field of view and an unblocked
## raycast. The meter rises only while the target is actually visible —
## faster up close, slower far away — and drains after losing sight.
##
## AI code must only read can_see_target, detection, awareness and
## last_known_position. The target reference is used for the geometric
## checks alone; the target's live position is never exposed.

signal awareness_changed(previous: Awareness, current: Awareness)
signal target_spotted
signal target_lost

enum Awareness { UNAWARE, SUSPICIOUS, ALERTED }

const DETECTION_MAX := 100.0

@export_group("Sight")
## Furthest distance at which the target can be seen, in metres.
@export var detection_distance := 14.0
## Full width of the vision cone, in degrees.
@export_range(1.0, 180.0) var fov_degrees := 90.0
## Heights on the target (above its origin) that rays are cast to; seeing any one counts.
## Used only if the target has no get_visibility_points() (the player provides its own,
## which follow crouching).
@export var target_sample_heights := PackedFloat32Array([1.5, 0.9, 0.3])
## Physics layers that block sight or are the target (world + player). NPCs are not included.
@export_flags_3d_physics var sight_mask := 3

@export_group("Detection meter")
## Meter gain per second when the target is at or inside near_distance.
@export var max_rise_rate := 60.0
## Meter gain per second when the target is at detection_distance.
@export var min_rise_rate := 12.0
## Distance up to which the meter rises at max_rise_rate.
@export var near_distance := 3.0
## Meter loss per second once the target has been out of sight for decay_delay.
@export var decay_rate := 15.0
## Seconds after losing sight before the meter starts to drain.
@export var decay_delay := 1.0

@export_group("Thresholds")
## Meter value at which the NPC becomes SUSPICIOUS.
@export_range(0.0, 100.0) var suspicious_threshold := 30.0
## Meter value at which the NPC becomes ALERTED.
@export_range(0.0, 100.0) var alert_threshold := 100.0
## How far the meter must fall below a threshold before dropping a level (stops flickering).
@export var hysteresis := 5.0

@export_group("Debug")
## Draw the vision cone, sight line and last known position (debug builds, F3).
@export var draw_debug := true
## Number of rays used to draw the cone outline.
@export_range(4, 64) var debug_cone_rays := 24

## Current meter value, 0–100.
var detection := 0.0
var awareness: Awareness = Awareness.UNAWARE
## True on frames where the target passed the distance, FOV and line-of-sight checks.
var can_see_target := false
## Where the target was standing the last time it was seen (its feet).
var last_known_position := Vector3.ZERO
var has_last_known_position := false
## Seconds since the target was last seen.
var time_since_seen := INF
## Cone end points from the last debug draw (read by tests).
var cone_outline: Array[Vector3] = []

var _target: Node3D
var _debug: Node3D
var _cone_timer := 0.0


func _ready() -> void:
	if draw_debug and OS.is_debug_build():
		_debug = Node3D.new()
		_debug.name = "VisionDebug"
		_debug.top_level = true  # Draw in world space.
		_debug.add_to_group("debug_visuals")
		add_child(_debug)


func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Node3D
	var was_visible := can_see_target
	var distance := 0.0
	can_see_target = false
	if _target:
		distance = global_position.distance_to(_target_points()[0])
		can_see_target = _check_sight()

	if can_see_target:
		time_since_seen = 0.0
		last_known_position = _target.global_position
		has_last_known_position = true
		var factor: float = _target.get_visibility_factor() if _target.has_method("get_visibility_factor") else 1.0
		detection += rise_rate_at(distance) * factor * delta
	else:
		time_since_seen += delta
		if time_since_seen >= decay_delay:
			detection -= decay_rate * delta
	detection = clampf(detection, 0.0, DETECTION_MAX)

	if can_see_target and not was_visible:
		target_spotted.emit()
	elif was_visible and not can_see_target:
		target_lost.emit()
	_update_awareness()

	if _debug and _debug.visible:
		_cone_timer -= delta
		if _cone_timer <= 0.0:
			_cone_timer = 0.1
			_draw_debug()


## Meter gain per second for a visible target at this distance (0 when out of range).
func rise_rate_at(distance: float) -> float:
	if distance > detection_distance:
		return 0.0
	var span := maxf(detection_distance - near_distance, 0.001)
	var closeness := 1.0 - clampf((distance - near_distance) / span, 0.0, 1.0)
	return lerpf(min_rise_rate, max_rise_rate, closeness)


## True if `point` is within detection_distance and inside the cone, ignoring walls.
func is_in_view(point: Vector3) -> bool:
	var to_point := point - global_position
	if to_point.length() > detection_distance or to_point.length_squared() < 0.0001:
		return false
	var forward := -global_basis.z
	return rad_to_deg(forward.angle_to(to_point)) <= fov_degrees / 2.0


## Clears the stored last known position (for later phases, e.g. after a search).
func forget_last_known_position() -> void:
	has_last_known_position = false


func _check_sight() -> bool:
	var space := get_world_3d().direct_space_state
	var exclude := [get_parent().get_rid()] if get_parent() is CollisionObject3D else []
	for point in _target_points():
		if not is_in_view(point):
			continue
		var query := PhysicsRayQueryParameters3D.create(global_position, point, sight_mask, exclude)
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and hit.collider == _target:
			return true
	return false


## Points on the target to aim at: its own visibility points if it has them.
func _target_points() -> PackedVector3Array:
	if _target.has_method("get_visibility_points"):
		return _target.get_visibility_points()
	var points := PackedVector3Array()
	for height in target_sample_heights:
		points.append(_target.global_position + Vector3(0, height, 0))
	return points


## Resets the meter and memory (used when the level resets after the player is caught).
func reset() -> void:
	detection = 0.0
	awareness = Awareness.UNAWARE
	can_see_target = false
	has_last_known_position = false
	time_since_seen = INF


func _update_awareness() -> void:
	var level := Awareness.UNAWARE
	if detection >= alert_threshold or (awareness == Awareness.ALERTED and detection > alert_threshold - hysteresis):
		level = Awareness.ALERTED
	elif detection >= suspicious_threshold or (awareness >= Awareness.SUSPICIOUS and detection > suspicious_threshold - hysteresis):
		level = Awareness.SUSPICIOUS
	if level != awareness:
		var previous := awareness
		awareness = level
		awareness_changed.emit(previous, level)


## Meter as text, e.g. "SUSPICIOUS [####------] 42".
func get_debug_text() -> String:
	var filled := int(round(detection / 10.0))
	return "%s [%s%s] %d%s" % [Awareness.keys()[awareness], "#".repeat(filled), "-".repeat(10 - filled),
		int(detection), "  SEES PLAYER" if can_see_target else ""]


# --- Debug drawing --------------------------------------------------------------

func _draw_debug() -> void:
	for child in _debug.get_children():
		child.queue_free()
	var colour: Color = [Color(0.3, 1.0, 0.4), Color(1.0, 0.85, 0.1), Color(1.0, 0.2, 0.15)][awareness]
	_debug.add_child(_make_mesh(_cone_mesh(), colour, 0.25))
	if not can_see_target and not has_last_known_position:
		return  # Nothing else to draw (an empty surface would log an engine error).
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	if can_see_target:
		lines.surface_add_vertex(global_position)
		lines.surface_add_vertex(_target_points()[1])
	if has_last_known_position:
		# A small cross with a post marks the last known position.
		var p := last_known_position + Vector3(0, 0.05, 0)
		for offset in [Vector3(0.4, 0, 0.4), Vector3(0.4, 0, -0.4)]:
			lines.surface_add_vertex(p - offset)
			lines.surface_add_vertex(p + offset)
		lines.surface_add_vertex(p)
		lines.surface_add_vertex(p + Vector3(0, 1.0, 0))
	lines.surface_end()
	_debug.add_child(_make_mesh(lines, Color(1.0, 0.3, 0.9), 1.0))


## Floor-level fan showing the cone, cut short wherever walls block the rays.
func _cone_mesh() -> ImmediateMesh:
	var space := get_world_3d().direct_space_state
	var floor_y := (get_parent() as Node3D).global_position.y + 0.12 if get_parent() is Node3D else global_position.y - 1.5
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var half := deg_to_rad(fov_degrees / 2.0)
	var points: Array[Vector3] = []
	for i in debug_cone_rays + 1:
		var angle := lerpf(-half, half, float(i) / debug_cone_rays)
		var direction := forward.rotated(Vector3.UP, angle)
		var end := global_position + direction * detection_distance
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(global_position, end, 1))
		var reach: Vector3 = hit.position if not hit.is_empty() else end
		points.append(Vector3(reach.x, floor_y, reach.z))
	var origin := Vector3(global_position.x, floor_y, global_position.z)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size() - 1:
		mesh.surface_add_vertex(origin)
		mesh.surface_add_vertex(points[i])
		mesh.surface_add_vertex(points[i + 1])
	mesh.surface_end()
	cone_outline = points
	return mesh


func _make_mesh(mesh: Mesh, colour: Color, alpha: float) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(colour, alpha)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
