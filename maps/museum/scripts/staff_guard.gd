extends Guard

signal notice(message: String)
signal phase_changed(phase: StringName)

const RestState = preload("res://maps/museum/scripts/staff_rest_state.gd")
const SearchState = preload("res://maps/museum/scripts/staff_search_state.gd")

@export var wake_loudness := 0.45
@export var observe_duration := 6.0
@export var room_search_duration := 24.0
@export var settle_duration := 3.0

var phase: StringName = &"sleeping"
var wake_count := 0
var sleep_count := 0
var _rest_left := 0.0
var _seat := Vector3.ZERO
var _seat_yaw := 0.0
var _cone: MeshInstance3D
var _cone_clock := 0.0
var _status: Label3D


func _ready() -> void:
	_seat = global_position
	_seat.y = 0.0
	_seat_yaw = rotation.y
	super()
	_status = Label3D.new()
	_status.position = Vector3(0,1.85,0)
	_status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status.font_size = 40
	_status.pixel_size = 0.003
	_status.outline_size = 8
	add_child(_status)
	_cone = MeshInstance3D.new()
	_cone.top_level = true
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1,0.75,0.15,0.16)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone.material_override = mat
	add_child(_cone)
	vision.set_physics_process(false)
	vision.reset()
	_refresh_status()


func _create_machine() -> void:
	machine = GuardStateMachine.new(self,RestState.new(),SearchState.new())
	machine.transitioned.connect(func(from: int,to: int,reason: String):
		if to == GuardStateMachine.CHASE:
			stand_up()
			set_phase(&"chasing")
			notice.emit("G3 đã nhìn rõ bạn — đang truy đuổi!")
		ai_state_changed.emit(from,to,reason))


func is_seated() -> bool:
	return phase in [&"sleeping",&"observing",&"settling"]


func set_phase(value: StringName) -> void:
	phase = value
	_refresh_status()
	phase_changed.emit(phase)


func go_to_sleep() -> void:
	stop_moving()
	velocity = Vector3.ZERO
	rotation.y = _seat_yaw
	vision.reset()
	vision.set_physics_process(false)
	vision.position.y = 1.25
	hearing.position.y = 1.25
	_pending_noise = {}
	hearing.reset()
	sleep_count += 1
	set_phase(&"sleeping")


func stand_up() -> void:
	vision.position.y = 1.6
	hearing.position.y = 1.6
	vision.set_physics_process(true)


func hear_noise(at: Vector3, loudness := 1.0) -> void:
	var flow := GameFlow.find(self)
	if flow == null or flow.state != GameStateMachine.State.PLAYING:
		return
	if phase in [&"sleeping",&"observing",&"settling"]:
		# WALK intensity never exceeds 0.4; only a loud heard event wakes G3.
		if loudness < wake_loudness:
			return
		if phase == &"sleeping":
			wake_count += 1
			vision.reset()
			vision.set_physics_process(true)
			notice.emit("G3 bị đánh thức bởi tiếng động. Hãy tránh tầm nhìn!")
		set_phase(&"observing")
		_rest_left = observe_duration
		var direction := at-global_position
		face_yaw(atan2(-direction.x,-direction.z))
		return
	super(at,loudness)


func build_perception() -> GuardPerception:
	if phase == &"sleeping":
		return GuardPerception.new()
	return super()


func return_to_seat() -> void:
	stand_up()
	set_phase(&"returning")
	navigate_to(_seat,patrol_speed)


func update_rest(delta: float) -> void:
	match phase:
		&"sleeping":
			stop_moving()
		&"observing",&"settling":
			_rest_left -= delta
			if _rest_left <= 0.0 and not vision.can_see_target:
				go_to_sleep()
		&"returning":
			# A closed door must not leave G3 stranded outside forever after a chase.
			var door := get_parent().get_node_or_null("NavigationRegion3D/Doors/Staff")
			if door != null and not door.is_open and global_position.x < 27 \
					and absf(global_position.y) < 0.7 and global_position.distance_to(door.global_position) < 2.2:
				if door.interact(self):
					navigate_to(_seat,patrol_speed)
			if Vector2(global_position.x-_seat.x,global_position.z-_seat.z).length() < 0.6:
				if _seat_is_free():
					stop_moving()
					global_position = _seat
					velocity = Vector3.ZERO
					rotation.y = _seat_yaw
					vision.position.y = 1.25
					hearing.position.y = 1.25
					_rest_left = settle_duration
					set_phase(&"settling")
			elif is_stuck() or has_arrived():
				navigate_to(_seat,patrol_speed)


func _seat_is_free() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.8
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY,_seat+Vector3(0,0.93,0))
	query.collision_mask = 6
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()


func room_point(at: Vector3) -> Vector3:
	var point := Vector3(clampf(at.x,28,35),0.0,clampf(at.z,7,17))
	var projected := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map,point)
	if projected.y <= 0.6:
		return projected
	var best := patrol_route.get_point_position(0)
	for i in patrol_route.get_point_count():
		var candidate := patrol_route.get_point_position(i)
		if candidate.distance_to(point) < best.distance_to(point):
			best = candidate
	return best


func _physics_process(delta: float) -> void:
	super(delta)
	if phase == &"sleeping":
		vision.reset()
	_cone_clock -= delta
	if _cone_clock <= 0.0:
		_cone_clock = 0.12
		_update_cone()


func _refresh_status() -> void:
	if not is_instance_valid(_status):
		return
	_status.text = {&"sleeping":"G3 · Zzz",&"observing":"G3 · ĐANG QUAN SÁT",
		&"searching":"G3 · KIỂM TRA PHÒNG",&"returning":"G3 · VỀ GHẾ",
		&"settling":"G3 · NGỒI XUỐNG",&"chasing":"G3 · TRUY ĐUỔI"}.get(phase,"G3")
	_status.modulate = Color(0.7,0.85,1) if phase == &"sleeping" else Color(1,0.8,0.3)


func _update_cone() -> void:
	if not is_instance_valid(_cone):
		return
	_cone.visible = phase != &"sleeping"
	if not _cone.visible:
		return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge: Array[Vector3] = []
	var origin := global_position+Vector3(0,0.025,0)
	_cone.material_override.albedo_color = Color(1,0.15,0.1,0.2) if phase == &"chasing" else Color(1,0.75,0.15,0.16)
	for i in 25:
		var angle := rotation.y-deg_to_rad(vision.fov_degrees/2)+deg_to_rad(vision.fov_degrees)*i/24
		var direction := Vector3(-sin(angle),0,-cos(angle))
		var end := vision.global_position+direction*minf(vision.detection_distance,8.0)
		var hit := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(vision.global_position,end,1))
		if not hit.is_empty():
			end = hit.position
		edge.append(Vector3(end.x,origin.y,end.z))
	for i in 24:
		mesh.surface_add_vertex(origin)
		mesh.surface_add_vertex(edge[i])
		mesh.surface_add_vertex(edge[i+1])
	mesh.surface_end()
	_cone.mesh = mesh
	_cone.global_transform = Transform3D.IDENTITY
