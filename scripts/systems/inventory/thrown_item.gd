class_name ThrownItem
extends Node3D

## A thrown distraction: flies along a short arc to where it lands, makes its
## noise there through the level's NoiseSystem (source "distraction", so guards
## hear it like any other noise and investigate), then lies there a few seconds
## and disappears. Created by PlayerInventory.throw_selected().

## Arc height at the middle of the flight, in metres.
const ARC_HEIGHT := 1.2
## Seconds the item lies where it landed before it disappears.
const LINGER_TIME := 6.0

var item_id: StringName
var start := Vector3.ZERO
var landing := Vector3.ZERO
var flight_time := 0.45
var landed := false
## The noise made on landing (null until then, or if the level has no NoiseSystem).
var noise: NoiseEvent

var _time := 0.0


func setup(id: StringName, from: Vector3, to: Vector3, seconds: float) -> void:
	item_id = id
	start = from
	landing = to
	flight_time = maxf(seconds, 0.01)


func _ready() -> void:
	add_to_group("thrown_items")
	add_child(ItemCatalog.make_model(item_id))
	global_position = start


func _physics_process(delta: float) -> void:
	_time += delta
	if landed:
		if _time > flight_time + LINGER_TIME:
			queue_free()
		return
	var t := clampf(_time / flight_time, 0.0, 1.0)
	global_position = start.lerp(landing, t) + Vector3.UP * ARC_HEIGHT * 4.0 * t * (1.0 - t)
	rotation.x += delta * 9.0
	if t >= 1.0:
		_land()


func _land() -> void:
	landed = true
	global_position = landing
	rotation = Vector3(0, rotation.y, 0)
	var info: Dictionary = ItemCatalog.ITEMS[item_id]
	var system := NoiseSystem.find(self)
	if system:
		noise = system.emit_noise(landing, NoiseEvent.Type.INTERACTION, "distraction",
			info.get("noise_intensity", 0.8), info.get("noise_radius", 10.0))
