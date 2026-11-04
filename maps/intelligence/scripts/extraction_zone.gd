extends Area3D

@export var route_id: StringName = &"courtyard"
@export var route_name := "Sân tiếp vận"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	add_to_group("k17_extraction")


func _physics_process(_delta: float) -> void:
	if not AreaUtils.contains_player(self):
		return
	var mission := MapHudProvider.find_for(self) as K17MissionController
	if mission:
		mission.try_extract(route_id, route_name)
