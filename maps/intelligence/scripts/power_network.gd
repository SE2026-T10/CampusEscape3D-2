extends PowerNetwork
## Backup is driven by mission time, so pause/failure never leaves a timer behind.
@export var backup_at := 15.0
var backup_active := false
var backup_starts := 0
var main_on := true

func _ready() -> void:
	circuits = {&"surveillance":true}
	super()

func set_powered(circuit: StringName,on: bool) -> void:
	if circuit == &"surveillance":
		if backup_active: return
		main_on = on
	super(circuit,on)
	if not on and is_inside_tree():
		var objectives:=ObjectiveManager.find(self)
		if objectives: objectives.try_complete(K17MissionController.CAMERAS_OFF)

func _physics_process(_delta: float) -> void:
	var mission := get_tree().get_first_node_in_group("k17_mission") as K17MissionController
	var flow := GameFlow.find(self)
	if mission == null or flow == null or flow.state != GameStateMachine.State.PLAYING: return
	if mission.has_file and not backup_active and mission.escape_duration-mission.time_left >= backup_at:
		backup_active = true
		backup_starts += 1
		super.set_powered(&"surveillance",true)
		NoiseSystem.find(self).emit_noise(Vector3(42,1,11),NoiseEvent.Type.INTERACTION,&"generator",.65,12,-1,"Máy phát dự phòng")
		AudioDirector.find(self).play_sfx("mech_clunk",-12)
		mission.queue_radio("Loa K17: Nguồn dự phòng đã hoạt động. Lam: Camera đã sáng lại, quan sát trước khi băng qua!",7,"backup")

func get_checkpoint_state() -> Dictionary:
	return {"powered":_powered.duplicate(),"main_on":main_on,"backup":backup_active}

func restore_checkpoint_state(state: Dictionary) -> void:
	backup_active = false
	backup_starts = 0
	main_on = bool(state.get("main_on",true))
	super(state)
	backup_active = bool(state.get("backup",false))
