extends Node3D
## Both boards read the state that controls the gate collider and walking link.
@export var ground_fork := false
@export var yard_split := false
@onready var _mission := MapHudProvider.find_for(self) as K17MissionController
@onready var _yard: Label3D = $Yard
@onready var _service: Label3D = $Service


func _process(_delta: float) -> void:
	if not _mission: return
	var yard := "A · LÊN SÂN   ↑"
	if ground_fork: yard = "←   A · VÒNG SÂN"
	if yard_split: yard = "A · VÒNG MÉP NAM   ↑"
	var service := "←   B · BẢO TRÌ"
	if _mission.has_file:
		yard += "\n" + _mission.route_status(0)
		service += "\n" + _mission.route_status(1)
	_yard.modulate = _mission.route_colour(0)
	_service.modulate = _mission.route_colour(1)
	if _yard.text != yard: _yard.text = yard
	if _service.text != service: _service.text = service
