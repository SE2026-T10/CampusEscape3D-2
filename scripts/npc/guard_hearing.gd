class_name GuardHearing
extends Node3D

## Hearing for an NPC. Receives NoiseEvents from the level's NoiseSystem and
## decides whether this NPC heard them:
##   - range: distance < event radius × sensitivity (halved through walls)
##   - staleness: events older than max_event_age (or their lifetime) are ignored
##   - duplicates: each event id is processed once; repeated noises near the
##     same estimated spot within merge_window are merged into one report
## A heard noise is reported as an ESTIMATED position (never the exact
## source): the error grows with distance and through walls, and is
## deterministic per listener and event. Reports go to the parent's
## hear_noise(position, loudness) if it has one, and to noise_reported.

signal noise_reported(estimated_position: Vector3, loudness: float, event: NoiseEvent)

## Multiplier on every event's radius: 1 = normal hearing.
@export var sensitivity := 1.0
## Radius multiplier when a wall is between the noise and the listener.
@export_range(0.0, 1.0) var wall_factor := 0.5
## Events older than this when processed are stale and ignored (seconds of game time).
@export var max_event_age := 0.75
## Ignore noises quieter than this after distance falloff (0–1).
@export var min_loudness := 0.02
## Position estimate error: base metres plus metres per metre of distance, capped.
@export var error_base := 0.4
@export var error_per_metre := 0.12
@export var error_max := 3.0
## Extra error multiplier for noises heard through a wall.
@export var wall_error_factor := 1.5
## Noises within this distance of the last report's estimate, and within merge_window seconds, are merged.
@export var merge_radius := 2.5
@export var merge_window := 1.0
## Source groups this listener ignores (an NPC does not investigate its own kind).
@export var ignored_source_groups := PackedStringArray(["guards"])

## Counters for tests and the debug view.
var heard_count := 0
var reported_count := 0
var merged_count := 0
var stale_count := 0
var duplicate_count := 0
## Last report, for debugging.
var last_estimate := Vector3.ZERO
var last_report_type := ""
var has_report := false

var _queue: Array[NoiseEvent] = []
var _processed_ids := {}
var _processed_order: Array[int] = []
var _last_report_time := -INF
var _seed := 0
var _debug: MeshInstance3D
var _debug_time_left := 0.0


func _ready() -> void:
	add_to_group("noise_listeners")
	_seed = hash(String(get_parent().name if get_parent() else name))
	if OS.is_debug_build():
		# Orange cross where this listener thinks the last noise came from (F3).
		_debug = MeshInstance3D.new()
		_debug.top_level = true
		_debug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.0, 0.6, 0.1)
		_debug.material_override = material
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for offset in [Vector3(0.35, 0, 0.35), Vector3(0.35, 0, -0.35)]:
			mesh.surface_add_vertex(-offset + Vector3(0, 0.08, 0))
			mesh.surface_add_vertex(offset + Vector3(0, 0.08, 0))
		mesh.surface_add_vertex(Vector3(0, 0.08, 0))
		mesh.surface_add_vertex(Vector3(0, 0.7, 0))
		mesh.surface_end()
		_debug.mesh = mesh
		_debug.add_to_group("debug_visuals")
		add_child(_debug)
		_debug.global_position = Vector3(0, -1000, 0)


## Called by NoiseSystem for every new event. Cheap checks only; the rest
## happens on this listener's next physics frame.
func receive(event: NoiseEvent) -> void:
	if _processed_ids.has(event.id):
		duplicate_count += 1
		return
	_mark_processed(event.id)
	if event.source_group in ignored_source_groups:
		return
	if global_position.distance_to(event.position) >= event.radius * sensitivity:
		return  # Out of range even without walls.
	_queue.append(event)


func _physics_process(delta: float) -> void:
	if _debug:
		_debug_time_left -= delta
		if _debug_time_left <= 0.0:
			_debug.global_position = Vector3(0, -1000, 0)  # Hide the marker off-level.
	if _queue.is_empty():
		return
	var system := NoiseSystem.find(self)
	var now := system.now if system else 0.0
	var events := _queue
	_queue = []
	# Loudest first, so a merge keeps the most informative report.
	events.sort_custom(func(a: NoiseEvent, b: NoiseEvent): return a.intensity > b.intensity)
	for event in events:
		process_event(event, now)


## Full hearing decision for one event at time `now`. Returns true if it was reported.
func process_event(event: NoiseEvent, now: float) -> bool:
	if event.age(now) > minf(max_event_age, event.lifetime):
		stale_count += 1
		return false
	var distance := global_position.distance_to(event.position)
	var blocked := _wall_between(event.position)
	var effective_radius := event.radius * sensitivity * (wall_factor if blocked else 1.0)
	var loudness := event.loudness_at(distance, effective_radius)
	if loudness < min_loudness:
		return false
	heard_count += 1
	var estimate := estimate_position(event, distance, blocked)
	if has_report and now - _last_report_time <= merge_window and estimate.distance_to(last_estimate) <= merge_radius:
		merged_count += 1
		return false
	has_report = true
	last_estimate = estimate
	last_report_type = event.type_name()
	_last_report_time = now
	reported_count += 1
	noise_reported.emit(estimate, loudness, event)
	if _debug:
		_debug.global_position = estimate
		_debug_time_left = 3.0
	var parent := get_parent()
	if parent and parent.has_method("hear_noise"):
		parent.hear_noise(estimate, loudness)
	return true


## Where this listener thinks the noise came from: the source plus an offset
## whose size grows with distance (and through walls) and whose direction is
## fixed per listener and event. Never exactly the source.
func estimate_position(event: NoiseEvent, distance: float, blocked: bool) -> Vector3:
	var error := minf(error_base + error_per_metre * distance, error_max)
	if blocked:
		error = minf(error * wall_error_factor, error_max * wall_error_factor)
	# String hashes of similar names ("GuardA", "GuardB") differ only slightly,
	# so mix the bits properly to make each listener's error direction independent.
	var h := _mix(_mix(event.id) ^ _seed)
	var angle := float(h % 3600) / 3600.0 * TAU
	# Between 60% and 100% of the error, so the estimate is never spot on.
	var size := error * (0.6 + 0.4 * float((h / 3600) % 1000) / 1000.0)
	return event.position + Vector3(cos(angle) * size, 0.0, sin(angle) * size)


## 32-bit integer hash with good bit mixing (from the "lowbias32" family).
static func _mix(value: int) -> int:
	var x := value & 0xFFFFFFFF
	x = ((x >> 16) ^ x) * 0x45d9f3b & 0xFFFFFFFF
	x = ((x >> 16) ^ x) * 0x45d9f3b & 0xFFFFFFFF
	return ((x >> 16) ^ x) & 0x7FFFFFFF


func _wall_between(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position, point + Vector3(0, 0.5, 0), 1)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _mark_processed(id: int) -> void:
	_processed_ids[id] = true
	_processed_order.append(id)
	if _processed_order.size() > 256:  # Bounded memory.
		_processed_ids.erase(_processed_order.pop_front())


## Short text for the guard label, e.g. "heard RUN → (3.1, 8.0)".
func get_debug_text() -> String:
	if not has_report:
		return "heard nothing"
	return "heard %s → (%.1f, %.1f)" % [last_report_type, last_estimate.x, last_estimate.z]
