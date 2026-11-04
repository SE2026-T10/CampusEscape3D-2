extends HidingSpot
## K17 cover is directional and physical. The area never removes a clear
## line of sight; a player must be fully inside a recess beside real solids.
func contains_player() -> bool:
	if not super(): return false
	var player:=get_tree().get_first_node_in_group("player") as FirstPersonPlayer
	if player==null or not AreaUtils.box_shapes_contain(self,player.global_position+Vector3(0,.5,0)): return false
	var blocked:=0
	var from:=player.global_position+Vector3(0,.65,0)
	for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
		if _blocked(from,from+direction*2.2): blocked+=1
	return blocked>=2

func is_concealing() -> bool:
	return super() and contains_player()

func conceals_from(guard: Node3D) -> bool:
	if not super(guard): return false
	var eye: Vector3=guard.vision.global_position if guard is Guard and guard.vision else guard.global_position+Vector3(0,1.6,0)
	var player:=get_tree().get_first_node_in_group("player") as FirstPersonPlayer
	if player==null: return false
	for point in player.get_visibility_points():
		if not _blocked(eye,point): return false
	return true

func _blocked(from: Vector3,to: Vector3) -> bool:
	var ray:=PhysicsRayQueryParameters3D.create(from,to,1)
	return not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
