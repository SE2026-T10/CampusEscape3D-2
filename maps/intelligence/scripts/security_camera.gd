extends SecurityCamera
## The rotating assembly is lit dynamically, never baked as a stationary shadow.
func _ready() -> void:
	super()
	for mesh in find_children("*","GeometryInstance3D",true,false): mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
	_reset_hook.call_deferred()

func _reset_hook() -> void:
	var cp := CheckpointManager.find(self)
	if cp: cp.respawned.connect(func(_checkpoint):
		meter=0.0
		sees_player=false
		cooldown_left=0.0
		_sweep=0.0
		_sweep_dir=1.0
		_update_visual(is_powered()))
