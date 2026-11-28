extends AudioDirector

const VICTORY_CUE := preload("res://shared/assets/audio/victory.wav")

@onready var _room: Area3D = $"../Gameplay/ProjectionRoom"
@onready var _mission: K17MissionController = $"../Gameplay/Mission"
@onready var _listener: FirstPersonPlayer = $"../Player"

func _ready() -> void:
	super()
	_ui.stream = VICTORY_CUE


func _process(delta: float) -> void:
	var previous_level := _ambience.volume_db
	super(delta)
	if get_tree().paused: return
	# Leave positional footsteps and guard cues audible in the archive.
	var quiet_room := not _mission.has_file and _room.overlaps_body(_listener)
	_ambience.volume_db = move_toward(previous_level, -28.0 if quiet_room else -14.0, 22.0*delta)


func _on_objective_completed(id: StringName) -> void:
	# The mission alarm and the victory cue already cover these two objectives.
	if id != K17MissionController.FILE and id != K17MissionController.ESCAPE:
		super(id)
