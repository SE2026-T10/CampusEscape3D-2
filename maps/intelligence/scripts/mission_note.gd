extends DocumentPickup
@export var instruction := false

func _ready() -> void:
	super()
	for mesh in find_children("*","GeometryInstance3D",true,false): mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
	_connect_knowledge.call_deferred()

func _connect_knowledge() -> void:
	var objectives := ObjectiveManager.find(self)
	if instruction and objectives:
		objectives.objective_changed.connect(func(_id,_state): _sync_knowledge.call_deferred())
		_sync_knowledge()

func _sync_knowledge() -> void:
	if instruction and is_read(): ObjectiveManager.find(self).try_complete(K17MissionController.CODE)

func get_prompt(_by: Node) -> String:
	return ("Đọc lại: " if is_read() else "Đọc: ")+title+" [J: nhật ký]"

func _on_interact(by: Node) -> bool:
	var ok := super(by)
	_sync_knowledge()
	return ok
