class_name NoiseSystem
extends Node3D

## Per-level noise event hub (a node in the level scene, not an autoload).
## Emitters call emit_noise(); every node in the "noise_listeners" group gets
## receive(event) straight away and decides for itself whether it heard it.
## Recent events are kept until they expire, for late listeners' staleness
## checks and for the debug rings (F3).

signal noise_emitted(event: NoiseEvent)

## Game-time clock (scaled physics time) used for timestamps.
var now := 0.0
## Total events emitted (read by tests and the debug panel).
var emitted_count := 0

var _next_id := 1
var _active: Array[NoiseEvent] = []
var _debug: MeshInstance3D


## Finds the NoiseSystem in the current scene, or null if the scene has none.
static func find(node: Node) -> NoiseSystem:
	return node.get_tree().get_first_node_in_group("noise_system") as NoiseSystem if node.is_inside_tree() else null


func _ready() -> void:
	add_to_group("noise_system")
	if OS.is_debug_build():
		_debug = MeshInstance3D.new()
		_debug.top_level = true
		_debug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_debug.material_override = material
		_debug.add_to_group("debug_visuals")
		add_child(_debug)


func _physics_process(delta: float) -> void:
	now += delta
	_active = _active.filter(func(e: NoiseEvent): return not e.is_expired(now))
	if _debug and _debug.visible:
		_draw_rings()


## Makes a noise. Values left at -1 come from the type's preset.
## Returns the event (already delivered to listeners).
func emit_noise(position: Vector3, type: NoiseEvent.Type, source_group := "environment",
		intensity := -1.0, radius := -1.0, lifetime := -1.0) -> NoiseEvent:
	var preset: Dictionary = NoiseEvent.PRESETS[type]
	var event := NoiseEvent.new()
	event.id = _next_id
	_next_id += 1
	event.type = type
	event.position = position
	event.intensity = preset.intensity if intensity < 0.0 else intensity
	event.radius = preset.radius if radius < 0.0 else radius
	event.lifetime = preset.lifetime if lifetime < 0.0 else lifetime
	event.timestamp = now
	event.source_group = source_group
	emitted_count += 1
	_active.append(event)
	noise_emitted.emit(event)
	for listener in get_tree().get_nodes_in_group("noise_listeners"):
		listener.receive(event)
	return event


## Events that have not expired yet.
func get_active_events() -> Array[NoiseEvent]:
	return _active.filter(func(e: NoiseEvent): return not e.is_expired(now))


func _draw_rings() -> void:
	var mesh := ImmediateMesh.new()
	var drew := false
	for event in _active:
		var fade := clampf(1.0 - event.age(now) / maxf(event.lifetime, 0.01), 0.0, 1.0)
		var colour: Color = [Color(0.6, 0.9, 1.0), Color(1.0, 0.5, 0.2), Color(0.9, 0.4, 1.0)][event.type]
		colour.a = fade
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for i in 33:
			var angle := TAU * i / 32.0
			mesh.surface_set_color(colour)
			mesh.surface_add_vertex(event.position + Vector3(cos(angle) * event.radius, 0.1, sin(angle) * event.radius))
		mesh.surface_end()
		drew = true
	_debug.mesh = mesh if drew else null
