class_name SecurityCamera
extends Node3D

## A security camera (Expanded Library, expansion Phase 5) on the surveillance
## circuit of the level's PowerNetwork.
##   - Powered: it sweeps left and right; if it sees the player (inside its cone
##     and range, nothing in between, not concealed in a hiding spot) its meter
##     fills, faster up close and slower for a crouching player. Full meter:
##     the SecurityAlarm sounds at the player's position (guards nearby hear it
##     and investigate; no instant failure), then a cooldown.
##   - Unpowered: the lens goes dark and it sees nothing. Guards are not affected.
## Lens colour: green scanning, yellow seeing you, red alarm, dark off.
## Not stored at checkpoints: its state follows the power, which is stored.

signal spotted_player(position: Vector3)

@export var camera_name := "Camera"
@export var circuit: StringName = &"surveillance"
@export var view_range := 13.0
@export_range(5.0, 120.0) var fov_degrees := 50.0
## Half the sweep (degrees, around its resting direction) and the sweep speed (degrees per second).
@export var sweep_angle := 35.0
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

var meter := 0.0
var sees_player := false
var cooldown_left := 0.0
## Alarms raised (for tests).
var alarms := 0

var _sweep := 0.0
var _sweep_dir := 1.0
var _head: Node3D
var _lens_material: StandardMaterial3D
var _cone_material: StandardMaterial3D
var _cone: MeshInstance3D


func _ready() -> void:
	add_to_group("security_cameras")
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
		_update_visual(false)
		return
	_sweep += _sweep_dir * sweep_speed * delta
	if absf(_sweep) >= sweep_angle:
		_sweep = clampf(_sweep, -sweep_angle, sweep_angle)
		_sweep_dir = -_sweep_dir
	_head.rotation_degrees = Vector3(-pitch_degrees, _sweep, 0)
	if cooldown_left > 0.0:
		cooldown_left = maxf(cooldown_left - delta, 0.0)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var distance := 0.0
	if player and cooldown_left == 0.0:
		distance = _head.global_position.distance_to(player.global_position)
		sees_player = can_see(player)
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
	_lens_material.albedo_color = colour
	_lens_material.emission = colour
	_lens_material.emission_energy_multiplier = 2.0 if powered else 0.0
	_cone.visible = powered
	_cone_material.albedo_color = Color(colour, 0.07 + 0.1 * clampf(meter / 100.0, 0.0, 1.0))


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
	lens.position = Vector3(0, 0, -0.29)
	_lens_material = StandardMaterial3D.new()
	_lens_material.emission_enabled = true
	lens.material_override = _lens_material
	_head.add_child(lens)
	# A faint view cone so players can read where it looks.
	_cone = MeshInstance3D.new()
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.02
	cone_mesh.bottom_radius = tan(deg_to_rad(fov_degrees / 2.0)) * view_range * 0.6
	cone_mesh.height = view_range * 0.6
	cone_mesh.radial_segments = 16
	cone_mesh.rings = 1
	_cone.mesh = cone_mesh
	_cone.rotation_degrees = Vector3(90, 0, 0)
	_cone.position = Vector3(0, 0, -view_range * 0.3)
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
