extends RefCounted
const Utils := preload("res://tests/test_utils.gd")
const M := preload("res://maps/intelligence/scripts/mission_controller.gd")
var host: Node
var level: Node3D
var player: FirstPersonPlayer
var mission: K17MissionController
var flow: GameFlow
var failures: Array[String] = []
var checks := 0

func run(parent: Node) -> Array[String]:
	host = parent
	level = (load("res://maps/intelligence/scenes/intelligence_k17.tscn") as PackedScene).instantiate()
	_expect(await Utils.add_level_and_wait_for_navigation(host,level,Vector3(-36,.05,51)),"Scene navigation ready")
	player = level.get_node("Player")
	player.set_physics_process(false)
	mission = level.get_node("Gameplay/Mission")
	flow = GameFlow.find(level)
	level.get_node("Gameplay/Reinforcements").process_mode = Node.PROCESS_MODE_DISABLED
	for guard in level.get_node("Guards").get_children(): guard.process_mode = Node.PROCESS_MODE_DISABLED
	var cover_ray := PhysicsRayQueryParameters3D.create(Vector3(-1,1.6,-19),Vector3(8,1,-20),1)
	var cover_hit := level.get_world_3d().direct_space_state.intersect_ray(cover_ray)
	_expect(not cover_hit.is_empty() and str(cover_hit.collider.name).begins_with("CheckpointSide"),"Checkpoint's west rack blocks the archive patrol's sight line")
	var sensor := mission.get_security_node("Sensor0") as K17SensorLane
	var sensor2 := mission.get_security_node("Sensor1") as K17SensorLane
	sensor.set_physics_process(false)
	sensor2.set_physics_process(false)
	var noise := NoiseSystem.find(level)
	player.global_position = Vector3(4,-3.95,-38)
	await _frames(3)
	for phase in [1.0,4.5]:
		sensor.phase_clock = phase
		sensor._physics_process(0.0)
	_expect(sensor.trips == 0,"Safe and warning phases do not alarm")
	sensor.phase_clock = 5.5
	var noises := noise.emitted_count
	sensor._physics_process(0.0)
	_expect(sensor.trips == 1 and mission.sensor_trips == 1 and noise.emitted_count == noises+1,"Live beam intersection raises one real alarm noise")
	_expect(StealthDirector.find(level).catches == 0,"Sensor is not an instant guard capture")
	var event := noise.get_active_events()[-1]
	_expect(event.position.distance_to(sensor.global_position) < .01,"Alarm noise originates at the sensor")
	sensor._physics_process(0.0)
	_expect(sensor.trips == 1,"Continuous contact is debounced")
	var wall := StaticBody3D.new()
	wall.position = Vector3(3.2,-3.4,-38)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.15,1.2,.6)
	collision.shape = shape
	wall.add_child(collision)
	level.add_child(wall)
	await _frames(3)
	sensor.cooldown_left = 0.0
	sensor._physics_process(0.0)
	_expect(sensor.trips == 1,"Physical cover interrupts the beam sight ray")
	wall.queue_free()
	await _frames(3)
	sensor.restore_checkpoint_state({"phase":2.0})
	_expect(sensor.get_phase() == 0 and sensor.cooldown_left == 0.0,"Sensor restores its saved phase and clears transient alarm contact")
	player.global_position = Vector3(8,.05,-20)
	var radio := mission.get_security_node("Radio") as K17Radio
	radio.set_physics_process(false)
	_expect(radio.interact(player),"Radio accepts a delayed transmission")
	_expect(not radio.interact(player),"Pending radio cannot be spammed")
	radio._physics_process(1.0)
	var pending := radio.pending_left
	flow.pause()
	radio._physics_process(10.0)
	_expect(radio.pending_left == pending,"Pause freezes radio countdown")
	flow.resume()
	noises = noise.emitted_count
	radio._physics_process(4.0)
	_expect(radio.uses == 1 and noise.emitted_count == noises+2,"One transmission fires once through both physical PA speakers")
	event = noise.get_active_events()[-1]
	_expect(event.source_group == &"radio" and event.position.distance_to(radio.get_node("IndoorStatic").global_position) < .01,"Radio noise comes from its visible PA speaker, not the player")
	radio._physics_process(30.0)
	_expect(radio.uses == 1,"Cooldown expiration never replays the transmission")
	radio.interact(player)
	radio.restore_checkpoint_state({})
	radio._physics_process(10.0)
	_expect(radio.pending_left == 0.0 and radio.uses == 1 and not radio.get_node("Static").playing,"Retry cancels pending radio and old audio")
	var latch := mission.get_security_node("PreparedLatch") as Interactable
	await _use(latch,Vector3(41.2,.05,5))
	_expect(mission.backdoor_prepared,"Actual held interaction prepares the optional backdoor")
	var saved_prepared := mission.get_checkpoint_state()
	mission.backdoor_prepared = false
	mission.restore_checkpoint_state(saved_prepared)
	_expect(mission.backdoor_prepared,"Preparation participates in the mission snapshot")
	var back := mission.get_security_node("MaintenanceGate") as K17LockdownGate
	var front := mission.get_security_node("CourtyardGate") as K17LockdownGate
	_expect(back.get_hold_duration(player) == 0.0,"Preparation grants instant backdoor release")
	mission.backdoor_prepared = false
	_expect(back.get_hold_duration(player) == 8.0,"Unprepared release costs eight seconds")
	var map := level.get_world_3d().navigation_map
	var start := Vector3(36,.15,44)
	var finish := Vector3(36,.15,48)
	var open_path := NavigationServer3D.map_get_path(map,start,finish,true)
	_expect(not open_path.is_empty() and open_path[-1].distance_to(finish) < 1.0,"Open gate walking link connects the two baked islands")
	back.request_close()
	front.request_close()
	await _frames(8)
	_expect(back.is_closed and front.is_closed and back.get_node("Panel").collision_layer == 1,"Solid gates actually close")
	_expect(not back.get_node("WalkingLink").enabled and not front.get_node("WalkingLink").enabled,"Closed gates disable their navigation links")
	var closed_path := NavigationServer3D.map_get_path(map,start,finish,true)
	_expect(closed_path.is_empty() or closed_path[-1].distance_to(finish) > 1.0,"Baked navmesh cannot silently route through closed gates")
	var objectives := ObjectiveManager.find(level)
	for id in [M.ENTER,M.PASS,M.CODE,M.ARCHIVE,M.FILE]: objectives.complete(id)
	await _use(back,Vector3(36,.05,44.35))
	_expect(not back.is_closed and back.get_node("WalkingLink").enabled,"Actual unprepared eight-second hold opens the backdoor")
	await _frames(6)
	var restored_path := NavigationServer3D.map_get_path(map,start,finish,true)
	_expect(not restored_path.is_empty() and restored_path[-1].distance_to(finish) < 1.0,"Opening restores traversable navigation")
	back.restore_checkpoint_state({"closed":false})
	player.global_position = Vector3(36,.05,46)
	back.request_close()
	back._physics_process(2.0)
	_expect(not back.is_closed and back.closing_pending,"Occupied threshold delays closure")
	back._physics_process(2.0)
	_expect(not back.is_closed and not back.closing_pending and back.safety_aborts == 1,"Safety reversal ends within the finite grace period")
	_expect(player.global_position.distance_to(Vector3(36,.05,46)) < .01,"Gate does not crush or teleport its occupant")
	player.global_position = Vector3(8,.05,-20)
	mission.time_left = 120.0
	mission.lockdown_warned = false
	mission.lockdown_closed = false
	mission.reinforcement_sent = false
	noises = noise.emitted_count
	mission._physics_process(105.0)
	_expect(mission.lockdown_warned and mission.lockdown_closed and mission.reinforcement_sent,"Large ticks process every crossed lockdown milestone")
	_expect(noise.emitted_count == noises+1,"Reinforcement uses a real loudspeaker noise once")
	mission._physics_process(.01)
	_expect(noise.emitted_count == noises+1,"Milestones never repeat")
	var clock := mission.time_left
	flow.pause()
	mission._physics_process(5.0)
	_expect(mission.time_left == clock,"Pause freezes the lockdown schedule")
	flow.resume()
	# A real checkpoint: store before the file, then undo all later security changes.
	CheckpointManager.find(level).restore_checkpoint()
	objectives.restore({})
	for id in [M.ENTER,M.PASS,M.CODE]: objectives.complete(id)
	level.get_node("Gameplay/ArchiveDoor").open()
	mission.backdoor_prepared = true
	sensor.phase_clock = 1.5
	player.global_position = Vector3(8,.05,-20)
	await _frames(6)
	var checkpoint := CheckpointManager.find(level)
	_expect(checkpoint.active != null,"Pre-file checkpoint activates normally")
	var sensor_phase: float = checkpoint.saved_state[String(checkpoint.get_path_to(sensor))].phase
	objectives.complete(M.FILE)
	radio.cooldown_left = 0.0
	radio.interact(player)
	back.request_close()
	front.request_close()
	await _frames(5)
	sensor.phase_clock = 7.0
	mission._physics_process(105.0)
	_expect(flow.fail("security retry fixture"),"Failure state reached with security changes in progress")
	_expect(flow.retry_checkpoint(),"Failure menu can retry the complete security snapshot")
	await _frames(4)
	_expect(not mission.has_file and mission.backdoor_prepared and not mission.lockdown_warned and not mission.reinforcement_sent,"Retry restores mission, preparation and milestone flags")
	_expect(not front.is_closed and not back.is_closed and front.get_node("WalkingLink").enabled and back.get_node("WalkingLink").enabled,"Retry restores physical gates and nav links together")
	_expect(sensor.phase_clock == sensor_phase and radio.pending_left == 0.0,"Retry restores sensor rhythm and discards old delayed transmissions")
	_expect(not SecurityAlarm.find(level).is_active(),"Retry clears sensor alarm")
	_expect(player.get_node("Interactor").hold_target == null,"Retry has no stale held interaction")
	Input.action_release("interact")
	host.get_tree().paused = false
	level.queue_free()
	await _frames(40)
	print("K17 SECURITY CHECKS: ",checks," checks; ",failures.size()," failures")
	return failures

func _use(target: Interactable,position: Vector3) -> void:
	player.global_position = position
	player.camera.look_at(target.global_position)
	await _frames(3)
	var interactor := player.get_node("Interactor") as PlayerInteractor
	_expect(interactor.focused == target,"Interaction ray reaches "+str(target.name))
	var duration := target.get_hold_duration(player)
	Input.action_press("interact")
	_expect(interactor.try_interact(),"Held/instant interaction starts for "+str(target.name))
	await _frames(ceili(duration*Engine.physics_ticks_per_second)+3)
	Input.action_release("interact")
	await _frames(2)

func _frames(count: int) -> void:
	for i in count: await host.get_tree().physics_frame

func _expect(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures.append("[K17 security] "+message)
