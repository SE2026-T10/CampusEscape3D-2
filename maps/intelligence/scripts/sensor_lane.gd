class_name K17SensorLane
extends Node3D
## The beam volume and warning cycle are gameplay; the emissive rods show that state.
@export var cycle_duration := 8.0
@export var safe_duration := 4.0
@export var warning_duration := 1.0
@export var phase_offset := 0.0
var phase_clock := 0.0
var cooldown_left := 0.0
var trips := 0
var _last_phase := -1
var _material: StandardMaterial3D

func _ready() -> void:
	add_to_group("checkpoint_state")
	add_to_group("k17_sensors")
	_material = $Indicator.material_override.duplicate()
	$Indicator.material_override = _material
	_update_visual()

func get_phase() -> int:
	var t := fposmod(phase_clock + phase_offset, cycle_duration)
	return 0 if t < safe_duration else (1 if t < safe_duration + warning_duration else 2)

func seconds_until_change() -> float:
	var t := fposmod(phase_clock + phase_offset, cycle_duration)
	return (safe_duration if get_phase() == 0 else safe_duration + warning_duration if get_phase() == 1 else cycle_duration) - t

func _physics_process(delta: float) -> void:
	var flow := GameFlow.find(self)
	if flow == null or flow.state != GameStateMachine.State.PLAYING:
		return
	phase_clock = fposmod(phase_clock + delta, cycle_duration)
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	_update_visual()
	if get_phase() != 2 or cooldown_left > 0.0 or not AreaUtils.contains_player($Detection):
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var from := global_position + Vector3(-1.65, -.7, 0)
	var query := PhysicsRayQueryParameters3D.create(from, player.global_position + Vector3(0,.5,0), 1)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return
	trips += 1
	cooldown_left = cycle_duration
	var mission := MapHudProvider.find_for(self) as K17MissionController
	if mission: mission.record_sensor_trip(global_position)

func _update_visual() -> void:
	var phase := get_phase()
	if phase != _last_phase:
		var colour: Color = [Color("55d497"),Color("edb347"),Color("ed4339")][phase]
		_material.albedo_color = colour
		_material.emission = colour
		for beam in $Beams.get_children():
			beam.visible = phase != 0
			beam.material_override = _material
		if phase == 1 and _last_phase >= 0: $Relay.play()
		_last_phase = phase
	var text := "%s / %d GIÂY" % [["XANH: ĐƯỢC QUA","VÀNG: SẮP QUÉT","ĐỎ: DỪNG LẠI"][phase],ceili(seconds_until_change())]
	if $Status.text != text: $Status.text = text
	if $StatusBack.text != text: $StatusBack.text = text

func get_checkpoint_state() -> Dictionary:
	return {"phase": phase_clock}

func restore_checkpoint_state(saved: Dictionary) -> void:
	phase_clock = float(saved.get("phase",0.0))
	cooldown_left = 0.0
	_last_phase = -1
	$Relay.stop()
	_update_visual()
