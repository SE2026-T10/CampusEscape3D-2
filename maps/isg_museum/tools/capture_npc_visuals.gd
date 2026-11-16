extends SceneTree

const BASE := "res://maps/isg_museum/"
const OUT := BASE+"docs/npc-art-v1/"
var level: Node3D
var camera: Camera3D
var audit := []
var n0: Node3D
var receptionist: Node3D

func _initialize() -> void:
	run.call_deferred()

func frames(n: int) -> void:
	for i in n: await process_frame

func photo(id: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+id+".png")
	var a = n0.get_node("Presentation")
	var b = receptionist.get_node("Presentation")
	audit.append({"id":id,"n0":a.current_animation,"reception":b.current_animation,"talking":[a.talking,b.talking],
		"hips":str(b.bone_position("Hips")),"foot":str(b.bone_position("LeftFoot")),"watch_yaw":b.look.yaw})

func run() -> void:
	root.size = Vector2i(1280,720)
	level = load(BASE+"scenes/museum.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	for actor in get_nodes_in_group("guards"):
		actor.set_physics_process(false)
		actor.agent.avoidance_enabled = false
		actor.vision.set_physics_process(false)
		actor.hearing.set_physics_process(false)
	level.get_node("StealthDirector").set_physics_process(false)
	var player = level.get_node("Player")
	player.set_physics_process(false)
	player.get_node("Noise").set_physics_process(false)
	for node in level.get_children():
		if node is CanvasLayer: node.hide()
	for node in get_nodes_in_group("debug_visuals"):
		if node is Node3D: node.hide()
	n0 = level.get_node("NavigationRegion3D/Teammate")
	receptionist = level.get_node("NavigationRegion3D/ServiceExpansion/Receptionist")
	var contract_ui = get_first_node_in_group("museum_contract_ui")
	var service = get_first_node_in_group("museum_service_ui")
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.position = Vector3(18.2,1.45,34)
	camera.look_at(Vector3(20.5,.9,31.5))
	await frames(30)
	await photo("n0-idle")
	player.position = Vector3(20.5,0,33.3)
	n0.interact(player)
	# Hide UI controls for pose review while retaining the real modal session.
	contract_ui.panel.hide()
	contract_ui._backdrop.hide()
	await frames(60)
	await photo("n0-talking")
	contract_ui.accept_button.pressed.emit()
	player.position = Vector3(18,0,35)
	contract_ui.open_contract()
	contract_ui.panel.show()
	contract_ui._backdrop.show()
	await frames(30)
	await photo("remote-contract")
	contract_ui.close_sheet()
	player.position = Vector3(31.1,0,27)
	camera.position = Vector3(32.8,1.4,29.4)
	camera.look_at(Vector3(33.05,.85,27))
	await frames(30)
	await photo("reception-idle-side")
	receptionist.interact(player)
	service.panel.hide()
	service.backdrop.hide()
	await frames(60)
	await photo("reception-talking-side")
	camera.position = Vector3(30.4,1.6,27)
	camera.look_at(Vector3(33.05,1.0,27))
	await frames(15)
	await photo("reception-talking-front")
	for i in 3: service.answer((service.questions[0].correct+1)%4)
	player.position = Vector3(31.1,0,28.3)
	await frames(60)
	await photo("reception-watch")
	await frames(260)
	for i in 3: service.answer(service.questions[service.question_index].correct)
	await frames(20)
	await photo("reception-ticket-session")
	service.close_panel()
	player.position = Vector3(18,0,35)
	service.open_ticket(null,player)
	service.panel.show()
	service.backdrop.show()
	await frames(30)
	await photo("remote-ticket")
	service.close_panel()
	# Wardrobe comparison: reposition only this QA instance's actors, no saved edits.
	var guard := level.get_node("Guard_G5") as Node3D
	guard.position = Vector3(19,0,33)
	guard.rotation.y = PI
	n0.position = Vector3(21,1,33)
	n0.rotation.y = 0
	receptionist.position = Vector3(22.65,1.15,33)
	receptionist.get_node("Visual").rotation.y = PI
	var chair := level.get_node("NavigationRegion3D/ServiceExpansion/EnvironmentArt/Chair") as Node3D
	chair.position = Vector3(23,0,33)
	chair.rotation.y = PI/2
	camera.position = Vector3(21,1.5,37)
	camera.look_at(Vector3(21,.9,33))
	await frames(30)
	await photo("role-colours-qa")
	var file := FileAccess.open(OUT+"capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(audit,"\t")+"\n")
	file.close()
	current_scene = null
	level.free()
	camera.free()
	quit()
