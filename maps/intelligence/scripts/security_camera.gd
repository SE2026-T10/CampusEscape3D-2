extends SecurityCamera
## The rotating assembly is lit dynamically, never baked as a stationary shadow.
func _ready() -> void:
	super()
	# A real bracket carries the assembly. Keep the gameplay perception,
	# but remove the floating billboard and translucent cone from this map.
	for child in get_children():
		if child is Label3D: child.visible=false
	for mesh in find_children("*","GeometryInstance3D",true,false): mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
	_reset_hook.call_deferred()

func _update_visual(powered: bool) -> void:
	super(powered)
	if _cone: _cone.visible=false

func can_see(player: Node3D) -> bool:
	# Unlike the common camera's generic hiding flag, K17 always checks real
	# sight lines. Looking through the open side of a recess still sees you.
	var from:=_head.global_position
	for point in player.get_visibility_points():
		var direction: Vector3=point-from
		if direction.length()>view_range or rad_to_deg(look_direction().angle_to(direction))>fov_degrees*.5: continue
		var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,point,3))
		if not hit.is_empty() and hit.collider==player: return true
	return false

func _reset_hook() -> void:
	var cp := CheckpointManager.find(self)
	if cp: cp.respawned.connect(func(_checkpoint):
		meter=0.0
		sees_player=false
		cooldown_left=0.0
		_sweep=0.0
		_sweep_dir=1.0
		_update_visual(is_powered()))
