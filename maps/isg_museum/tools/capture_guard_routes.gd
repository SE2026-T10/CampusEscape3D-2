extends SceneTree

## Offline route QA: existing G1 with a temporary patrol route, unchanged
## navigation/collision/movement code. G6 then inspects a genuinely emptied T1.
const BASE := "res://maps/isg_museum/"
const ReportPaths := preload("res://maps/isg_museum/tools/report_paths.gd")
const OUT := BASE+"docs/reports/guard-art-v1/"
var level: Node3D
var camera: Camera3D
var results := []

var output_dir := OUT

func out_path(filename: String) -> String:
	return ReportPaths.artifact(output_dir,filename)

func _initialize() -> void:
	output_dir = ReportPaths.output_root(OUT)
	run.call_deferred()

func frames(n: int) -> void:
	for i in n: await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	level = load(BASE+"scenes/museum.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.get_node("StealthDirector").set_physics_process(false)
	level.get_node("Player").set_physics_process(false)
	for child in level.get_children():
		if child is CanvasLayer: child.hide()
		if child is Guard:
			child.set_physics_process(false)
			child.vision.set_physics_process(false)
			child.hearing.set_physics_process(false)
			child.agent.avoidance_enabled = false
			if child.name != "Guard_G1": child.collision_layer = 0 # Frozen QA extras must not block the filmed route.
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	await frames(20)
	var actor := level.get_node("Guard_G1") as Guard
	actor.set_physics_process(true)
	# Use the same local endpoints as verify_blockout; intermediate targets at
	# two elevations can project onto the wrong flight at their shared landing.
	actor.machine.current = GuardStateMachine.NONE
	for mirror in [false,true]:
		var lower := Vector3(28,.1,4.25) if mirror else Vector3(8,.1,28.25)
		var upper := Vector3(28,4.6,1.75) if mirror else Vector3(8,4.6,25.75)
		actor.position = lower
		actor.velocity = Vector3.ZERO
		var reached := true
		for destination in [upper,lower]:
			actor.navigate_to(destination,actor.patrol_speed)
			var arrived := false
			for tick in 900:
				var target := actor.position+Vector3(0,.9,0)
				var best := target
				var clearance := -1.0
				# Stay in the same flight's Z band: crossing its centre divider
				# would hide the animated legs even though traversal succeeds.
				for side in [-1.0,1.0]:
					var desired := target+Vector3(side*2.5,.6,0)
					var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(target,desired,1))
					var candidate: Vector3 = target+(hit.position-target)*.85 if not hit.is_empty() else desired
					if candidate.distance_to(target)>clearance:
						best = candidate
						clearance = candidate.distance_to(target)
				camera.position = best
				camera.look_at(target)
				await frames(1)
				if actor.position.distance_to(destination)<.6:
					arrived = true
					break
			reached = reached and arrived
		results.append({"stair":"B" if mirror else "A","up_and_down":reached,"position":str(actor.position)})
		print("STAIR ",results[-1])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_path("stair-"+("b" if mirror else "a")+".png"))
	actor.set_physics_process(false)
	var inspector = level.get_node("Guard_G6")
	var painting = level.get_node("Interactables/Painting_T1")
	var player = level.get_node("Player")
	player.position = painting.global_position+Vector3(1.4,-1.5,0)
	painting.interact(player)
	player.position = Vector3(18,0,35)
	inspector.position = Vector3(2.25,4.5,12)
	inspector.velocity = Vector3.ZERO
	inspector.rotation.y = PI/2
	inspector.inspection_phase = &"inspection"
	camera.position = Vector3(4,6,14)
	camera.look_at(Vector3(.5,5.6,12))
	await frames(20)
	var seen: bool = inspector.can_see_frame()
	var reported: bool = inspector.report_missing()
	await frames(45)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_path("g6-empty-frame.png"))
	results.append({"g6_sees_frame":seen,"g6_reported":reported,"missing":painting.is_artwork_missing()})
	print("G6 ",results[-1])
	FileAccess.open(out_path("routes.json"),FileAccess.WRITE).store_string(JSON.stringify(results,"\t")+"\n")
	current_scene = null
	level.free()
	camera.free()
	quit()
