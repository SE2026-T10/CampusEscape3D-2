extends Node
## Scene-local, finite dispatch. Never supplies the player's position to AI.
const L := preload("res://maps/intelligence/resources/layout/k17_layout.gd")
const Appearance := preload("res://maps/intelligence/scripts/military_appearance.gd")
const GUARD := preload("res://shared/scenes/npc/guard.tscn")
@export var wave_times := Vector2(10,45)
@export var spawn_grace := 8.0
var spawned_count := 0
var waves := [false,false]
var expired := [false,false]
var _actors: Array[Node] = []
var _routes: Array[Node] = []
var _cancelled := false

func _ready() -> void:
	add_to_group("checkpoint_state")
	_connect.call_deferred()

func _connect() -> void:
	var flow:=GameFlow.find(self)
	if flow: flow.state_changed.connect(func(_from,to):
		if to in [GameStateMachine.State.CAUGHT,GameStateMachine.State.WIN,GameStateMachine.State.FAILED]: _cancelled=true)

func _physics_process(_delta: float) -> void:
	var mission:=get_parent().get_node("Mission") as K17MissionController
	var flow:=GameFlow.find(self)
	if mission.is_test_mode() or not mission.has_file or mission.escaped or _cancelled or flow==null or flow.is_leaving() or flow.state!=GameStateMachine.State.PLAYING: return
	var elapsed:=mission.escape_duration-mission.time_left
	for wave in 2:
		var start: float=wave_times[wave]
		if elapsed<start or waves[wave] or expired[wave]: continue
		for index in range(wave*2,wave*2+2):
			if get_parent().get_parent().get_node("Guards").has_node("Reinforcement%d"%index): continue
			var pos: Vector3=L.REINFORCEMENT_ROUTES[index][0]
			if _safe_position(pos): _spawn(index,pos)
		waves[wave]=_wave_count(wave)==2
		if waves[wave]: mission.queue_radio("Loa K17: Đội phản ứng %d đã vào vị trí. Lam: Tìm vật che, tiếp tục về điểm tập kết!"%(wave+1),7,"wave_"+str(wave))
		elif elapsed>=start+spawn_grace:
			expired[wave]=true
			mission.queue_radio("Loa K17: Chốt tiếp viện đang bị cản. Đội còn lại tiếp tục kiểm tra.",5,"wave_blocked_"+str(wave))

func _wave_count(wave: int) -> int:
	var count:=0
	for index in range(wave*2,wave*2+2):
		if get_parent().get_parent().get_node("Guards").has_node("Reinforcement%d"%index): count+=1
	return count

func _safe_position(pos: Vector3) -> bool:
	var player:=get_tree().get_first_node_in_group("player") as FirstPersonPlayer
	if player==null or player.global_position.distance_to(pos)<12: return false
	var world:=player.get_world_3d()
	var nav:=NavigationServer3D.map_get_closest_point(world.navigation_map,pos)
	if Vector2(nav.x-pos.x,nav.z-pos.z).length()>1: return false
	var offset:=pos+Vector3(0,1.4,0)-player.camera.global_position
	if player.camera.global_basis.z.dot(-offset.normalized())>.4:
		var sight:=PhysicsRayQueryParameters3D.create(player.camera.global_position,pos+Vector3(0,1.4,0),1)
		if world.direct_space_state.intersect_ray(sight).is_empty(): return false
	for actor in get_tree().get_nodes_in_group("guards"):
		if actor.global_position.distance_to(pos)<1.4: return false
	var shape:=SphereShape3D.new()
	shape.radius=.45
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.transform=Transform3D(Basis.IDENTITY,pos+Vector3(0,1,0))
	query.collision_mask=17
	return world.direct_space_state.intersect_shape(query,1).is_empty()

func _spawn(index: int,pos: Vector3) -> void:
	var route:=PatrolRoute.new()
	route.name="DispatchRoute%d"%index
	add_child(route)
	_routes.append(route)
	for p in L.REINFORCEMENT_ROUTES[index]:
		var point:=PatrolPoint.new()
		point.position=p
		point.wait_time=1.2
		route.add_child(point)
	var guard:=GUARD.instantiate() as Guard
	guard.set_script(preload("res://maps/intelligence/scripts/projection_guard.gd"))
	guard.name="Reinforcement%d"%index
	guard.position=pos+Vector3(0,.05,0)
	guard.patrol_route=route
	guard.collision_mask|=16
	guard.checkpoint_snapshot=false
	preload("res://maps/intelligence/resources/layout/k17_v4.gd").configure_guard(guard)
	get_parent().get_parent().get_node("Guards").add_child(guard)
	Appearance.apply(guard)
	_actors.append(guard)
	spawned_count+=1
	print("[K17 dispatch] wave=",index/2+1," actor=",guard.name," origin=",pos)

func get_checkpoint_state() -> Dictionary:
	return {"waves":waves.duplicate(),"expired":expired.duplicate()}

func restore_checkpoint_state(_saved: Dictionary) -> void:
	# Checkpoints are pre-file only: no reinforcements belong to a saved state.
	for node in _actors+_routes:
		if is_instance_valid(node):
			if node.get_parent(): node.get_parent().remove_child(node)
			node.queue_free()
	_actors.clear()
	_routes.clear()
	spawned_count=0
	waves=[false,false]
	expired=[false,false]
	_cancelled=false
