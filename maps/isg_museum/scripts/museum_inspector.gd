extends Guard

## Museum-local evidence: the inspector knows the frame and search stops,
## never the player's position unless normal vision/hearing supplies evidence.
signal artwork_discovered
signal notice(text: String)

const MuseumPatrol = preload("res://maps/isg_museum/scripts/museum_patrol_state.gd")
const MuseumInvestigation = preload("res://maps/isg_museum/scripts/museum_investigate_state.gd")

@export_node_path("Area3D") var painting_path: NodePath
@export var inspection_point_name: StringName = &"Inspect_T1"
@export_node_path("Node3D") var search_points_path: NodePath
@export var inspection_duration := 2.0
@export var discovery_delay := 0.4
@export var frame_detection_distance := 6.0
@export var search_stop_duration := 1.5

var discovery_reported := false
var discovery_count := 0
var inspection_visits := 0
var inspection_phase: StringName = &"patrol"
var _speech_left := 0.0

@onready var painting: Area3D = get_node_or_null(painting_path)
@onready var speech: Label3D = $Speech


func _create_machine() -> void:
	machine = GuardStateMachine.new(self, MuseumPatrol.new(), MuseumInvestigation.new())
	machine.transitioned.connect(func(from: int, to: int, reason: String):
		if to == GuardStateMachine.CHASE:
			inspection_phase = &"chase"
		ai_state_changed.emit(from, to, reason))


func _physics_process(delta: float) -> void:
	super(delta)
	if _speech_left > 0.0:
		_speech_left = maxf(0, _speech_left-delta)
		speech.visible = _speech_left > 0.0


func is_inspection_point(index: int) -> bool:
	if patrol_route == null:
		return false
	var points: Array[Marker3D] = []
	for point in patrol_route.get_children():
		if point is Marker3D:
			points.append(point)
	return index >= 0 and index < points.size() and points[index].name == inspection_point_name


func frame_position() -> Vector3:
	if painting and painting.get_node_or_null("InspectionTarget"):
		return painting.get_node("InspectionTarget").global_position
	return painting.global_position if painting else global_position


func face_frame() -> void:
	var offset := frame_position()-global_position
	face_yaw(atan2(-offset.x,-offset.z))


func can_see_frame() -> bool:
	if painting == null or vision == null or not painting.is_visible_in_tree():
		return false
	var target := frame_position()
	if vision.global_position.distance_to(target) > frame_detection_distance:
		return false
	if absf(vision.global_position.y-target.y) > 1.2 or not vision.is_in_view(target):
		return false
	var query := PhysicsRayQueryParameters3D.create(vision.global_position,target,1,[get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func report_missing() -> bool:
	if discovery_reported or inspection_phase != &"inspection" or painting == null:
		return false
	if not painting.is_artwork_missing() or not can_see_frame():
		return false
	var flow := GameFlow.find(self)
	if flow == null or flow.state != GameStateMachine.State.PLAYING:
		return false
	if not machine.request_transition(GuardStateMachine.INVESTIGATE,"missing artwork T1",global_position):
		return false
	discovery_reported = true
	discovery_count += 1
	var message := "G6 đã phát hiện thiếu tác phẩm T1"
	speech.text = "G6: Tranh T1 đâu rồi?\nKiểm tra phòng A!"
	speech.show()
	_speech_left = 6.0
	notice.emit(message)
	artwork_discovered.emit()
	return true


func room_search_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	var route := get_node_or_null(search_points_path)
	if route:
		for point in route.get_children():
			if point is Marker3D:
				points.append(point.global_position)
	return points
