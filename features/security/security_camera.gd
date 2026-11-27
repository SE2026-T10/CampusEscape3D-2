class_name SecurityCamera
extends Node3D

## A security camera (Expanded Library, expansion Phase 5) on the surveillance
## circuit of the level's PowerNetwork.
##   - Powered: it watches one direction (stationary since 2026-11-02, on request;
##     `sweep_angle` > 0 still sweeps); if it sees the player (inside its cone
##     and range, nothing in between, not concealed in a hiding spot) its meter
##     fills, faster up close and slower for a crouching player. Full meter:
##     the SecurityAlarm sounds at the player's position (guards nearby hear it
##     and investigate; no instant failure), then a cooldown.
##   - Unpowered: the lens goes dark and it sees nothing. Guards are not affected.
## Lens colour: green scanning, yellow seeing you, red alarm, dark off.
## The view cone players see is cast with rays (`cone_rings` × `cone_segments` across the
## cone, physics layer 1: walls, floors, closed doors), each stopped where it hits, so it
## never shows through a wall or a floor; refreshed every `cone_refresh` seconds while
## powered (a door opening or closing changes it), the mesh rebuilt only on a change.
## Not stored at checkpoints: its state follows the power, which is stored.

signal spotted_player(position: Vector3)

@export var camera_name := "Camera"
@export var circuit: StringName = &"surveillance"
@export var view_range := 13.0
@export_range(5.0, 120.0) var fov_degrees := 50.0
## Half the sweep (degrees, around its resting direction) and the sweep speed (degrees per
## second). 0: stationary (the default since 2026-11-02, on request).
@export var sweep_angle := 0.0
@export var sweep_speed := 18.0
## Downward tilt of the lens (degrees).
@export var pitch_degrees := 25.0
## Meter gain per second near (3 m) and at view_range; loss per second out of sight.
@export var near_rise := 70.0
@export var far_rise := 20.0
@export var decay := 25.0
## Alarm noise radius and seconds before it can raise the alarm again.
@export var alarm_radius := 25.0
@export var cooldown := 8.0
## The visible cone: its length (a share of view_range, as before), resolution and refresh.
@export var cone_length := 0.6
@export var cone_rings := 8
@export var cone_segments := 32
@export var cone_refresh := 0.5

## The lens, in the head's frame.
const LENS := Vector3(0, 0, -0.29)
## Each cone ray ends this far before what it hits, so the cone's end never flickers
## into the wall or floor it lies on.
const CONE_GAP := 0.05
## The cone's opacity while the camera sees nothing (was 0.07; it rises to 0.17 as before).
const CONE_REST_ALPHA := 0.035
## The view cone's render layer (11): no light includes it; cameras draw every layer.
const CONE_LAYER := 1 << 10

var meter := 0.0
var sees_player := false
var cooldown_left := 0.0
## Alarms raised (for tests).
var alarms := 0

var _sweep := 0.0
var _sweep_dir := 1.0
var _head: Node3D
var _lens_material: StandardMaterial3D
var _player: Node3D
var _visual_state := Vector3(-1, -1, -1)
var _cone_material: StandardMaterial3D
var _cone: MeshInstance3D
var _cone_dirs := PackedVector3Array()
var _cone_lengths := PackedFloat32Array()
var _cone_clock := 0.0
## Spreads the cameras' cone refreshes over the refresh period, so their rays are not all
## cast on the same frame.
var _cone_stagger := 0.0
static var _cameras_made := 0
## Times the cone's mesh was rebuilt (for tests).
var cone_builds := 0


func _ready() -> void:
	add_to_group("security_cameras")
	_cone_stagger = float(_cameras_made % 5) / 5.0
	_cameras_made += 1
	_build()


func is_powered() -> bool:
	var network := get_tree().get_first_node_in_group("power_network")
	return network == null or network.is_powered(circuit)


## The direction the lens looks now (world space).
func look_direction() -> Vector3:
	return -_head.global_basis.z


func _physics_process(delta: float) -> void:
	var powered := is_powered()
	sees_player = false
	if not powered:
		meter = 0.0
		cooldown_left = 0.0
		_cone_clock = 0.0   # cast again as soon as the power is back
		_update_visual(false)
		return
	if sweep_angle > 0.0:
		_sweep += _sweep_dir * sweep_speed * delta
		if absf(_sweep) >= sweep_angle:
			_sweep = clampf(_sweep, -sweep_angle, sweep_angle)
			_sweep_dir = -_sweep_dir
	else:
		_sweep = 0.0
	_head.rotation_degrees = Vector3(-pitch_degrees, _sweep, 0)
	_cone_clock -= delta
	if _cone_clock <= 0.0:
		_cone_clock = cone_refresh * (1.0 + _cone_stagger) if sweep_angle <= 0.0 else 0.1
		_cone_stagger = 0.0   # only the first wait is offset
		update_cone()
	if cooldown_left > 0.0:
		cooldown_left = maxf(cooldown_left - delta, 0.0)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	var player := _player
	var distance := 0.0
	if player and cooldown_left == 0.0:
		distance = _head.global_position.distance_to(player.global_position)
		# Expansion Phase 9: no rays or hiding-spot checks for a player well out of range.
		sees_player = distance <= view_range + 2.0 and can_see(player)
	if sees_player:
		var closeness := 1.0 - clampf((distance - 3.0) / maxf(view_range - 3.0, 0.1), 0.0, 1.0)
		var factor: float = player.get_visibility_factor() if player.has_method("get_visibility_factor") else 1.0
		meter += lerpf(far_rise, near_rise, closeness) * factor * delta
		if meter >= 100.0:
			_raise(player.global_position)
	else:
		meter = maxf(meter - decay * delta, 0.0)
	_update_visual(true)


## True if the camera, as it points now, sees `player`.
func can_see(player: Node3D) -> bool:
	for spot in get_tree().get_nodes_in_group("hiding_spots"):
		if spot.has_method("is_concealing") and spot.is_concealing():
			return false
	var points: PackedVector3Array = player.get_visibility_points() if player.has_method("get_visibility_points") \
		else PackedVector3Array([player.global_position + Vector3(0, 1.0, 0)])
	var from := _head.global_position
	var forward := look_direction()
	var space := get_world_3d().direct_space_state
	for point in points:
		var to := point - from
		if to.length() > view_range or rad_to_deg(forward.angle_to(to)) > fov_degrees / 2.0:
			continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, point, 3))
		if not hit.is_empty() and hit.collider == player:
			return true
	return false


## Casts the visible cone's rays from the lens and rebuilds its mesh if any length changed.
func update_cone() -> void:
	var space := get_world_3d().direct_space_state
	var xf := _head.global_transform
	var from := xf * LENS
	var full := view_range * cone_length
	var changed := false
	for i in _cone_dirs.size():
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, xf * (LENS + _cone_dirs[i] * full), 1))
		var d := full if hit.is_empty() else maxf(from.distance_to(hit.position) - CONE_GAP, 0.05)
		if absf(d - _cone_lengths[i]) > 0.01:
			_cone_lengths[i] = d
			changed = true
	if changed:
		_build_cone_mesh()


## The length of the visible cone along its axis now (for tests).
func cone_axis_length() -> float:
	return _cone_lengths[0] if not _cone_lengths.is_empty() else 0.0


## Ray directions across the cone (head frame, −z ahead): the axis, then `cone_rings`
## rings of `cone_segments`, the last on the cone's edge.
func _make_cone_dirs() -> void:
	_cone_dirs.clear()
	_cone_dirs.append(Vector3(0, 0, -1))
	var half := deg_to_rad(fov_degrees / 2.0)
	for k in range(1, cone_rings + 1):
		var t := half * float(k) / float(cone_rings)
		for j in cone_segments:
			var p := TAU * float(j) / float(cone_segments)
			_cone_dirs.append(Vector3(sin(t) * cos(p), sin(t) * sin(p), -cos(t)))
	_cone_lengths.resize(_cone_dirs.size())
	_cone_lengths.fill(view_range * cone_length)


## The cone's mesh from the rays: its side from the lens to the edge rays' ends and its end
## surface through all the rays' ends (lying on the walls and floors they reach).
func _build_cone_mesh() -> void:
	var pts := PackedVector3Array()
	for i in _cone_dirs.size():
		pts.append(LENS + _cone_dirs[i] * _cone_lengths[i])
	var s := cone_segments
	var v := PackedVector3Array()
	var rim := 1 + (cone_rings - 1) * s
	for j in s:
		v.append_array([LENS, pts[rim + j], pts[rim + (j + 1) % s]])
	for j in s:
		v.append_array([pts[0], pts[1 + j], pts[1 + (j + 1) % s]])
	for k in range(1, cone_rings):
		var r0 := 1 + (k - 1) * s
		var r1 := 1 + k * s
		for j in s:
			var j1 := (j + 1) % s
			v.append_array([pts[r0 + j], pts[r1 + j], pts[r1 + j1]])
			v.append_array([pts[r0 + j], pts[r1 + j1], pts[r0 + j1]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cone.mesh = mesh
	cone_builds += 1


func _raise(at: Vector3) -> void:
	alarms += 1
	meter = 0.0
	cooldown_left = cooldown
	spotted_player.emit(at)
	var alarm := get_tree().get_first_node_in_group("security_alarm")
	if alarm:
		alarm.raise_alarm(at, "Camera (%s) spotted you" % camera_name, alarm_radius)


func _update_visual(powered: bool) -> void:
	var colour := Color(0.05, 0.05, 0.06)
	if powered:
		colour = Color(1.0, 0.2, 0.15) if cooldown_left > 0.0 else (Color(1.0, 0.85, 0.2) if meter > 0.0 else Color(0.25, 0.9, 0.35))
	# Expansion Phase 9: the materials are only touched when what they show changes.
	var state := Vector3(colour.r + colour.g * 2.0 + colour.b * 4.0, float(powered), snappedf(meter, 2.0))
	if state == _visual_state:
		return
	_visual_state = state
	_lens_material.albedo_color = colour
	_lens_material.emission = colour
	_lens_material.emission_energy_multiplier = 2.0 if powered else 0.0
	_cone.visible = powered
	# Softer at rest (2026-11-03): a faint cone while the camera sees nothing, as strong as
	# before once it is noticing the player.
	_cone_material.albedo_color = Color(colour, CONE_REST_ALPHA + 0.13 * clampf(meter / 100.0, 0.0, 1.0))


func _build() -> void:
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.85, 0.86, 0.88)
	var mount := MeshInstance3D.new()
	var mount_mesh := BoxMesh.new()
	mount_mesh.size = Vector3(0.12, 0.12, 0.4)
	mount.mesh = mount_mesh
	mount.material_override = body_material
	mount.position = Vector3(0, 0, 0.3)
	add_child(mount)
	_head = Node3D.new()
	_head.name = "Head"
	_head.rotation_degrees = Vector3(-pitch_degrees, 0, 0)
	add_child(_head)
	var housing := MeshInstance3D.new()
	var housing_mesh := BoxMesh.new()
	housing_mesh.size = Vector3(0.3, 0.26, 0.55)
	housing.mesh = housing_mesh
	housing.material_override = body_material
	_head.add_child(housing)
	var lens := MeshInstance3D.new()
	var lens_mesh := CylinderMesh.new()
	lens_mesh.top_radius = 0.09
	lens_mesh.bottom_radius = 0.09
	lens_mesh.height = 0.05
	lens.mesh = lens_mesh
	lens.rotation_degrees = Vector3(90, 0, 0)
	lens.position = LENS
	_lens_material = StandardMaterial3D.new()
	_lens_material.emission_enabled = true
	lens.material_override = _lens_material
	_head.add_child(lens)
	# A faint view cone so players can read where it looks: cast with rays, it stops at
	# walls and floors (update_cone, on the first physics frame and then every cone_refresh).
	_cone = MeshInstance3D.new()
	_cone.name = "ViewCone"
	_make_cone_dirs()
	_build_cone_mesh()
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Unshaded, so it needs no light: on a render layer no light's cull mask includes
	# (layer 11), it is paired with none and never counts toward a mesh's 8 lights.
	_cone.layers = CONE_LAYER
	_cone_material = StandardMaterial3D.new()
	_cone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone.material_override = _cone_material
	_head.add_child(_cone)
	var label := Label3D.new()
	label.text = "CAM · %s" % camera_name.to_upper()
	label.font_size = 18
	label.pixel_size = 0.004
	label.position = Vector3(0, 0.35, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	add_child(label)
	_update_visual(is_powered())
