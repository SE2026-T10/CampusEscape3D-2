extends RefCounted
## Real input, rays and lifecycle for opt-in held interactions; defaults stay instant.
class CounterTarget extends Interactable:
	var count := 0
	var allowed := true
	func can_interact(by: Node) -> bool: return super(by) and allowed
	func _on_interact(_by: Node) -> bool:
		count += 1
		return true

var host: Node
var failures: Array[String] = []
var checks := 0
var interactor: PlayerInteractor
var player: FirstPersonPlayer
var target: CounterTarget

func run(parent: Node) -> Array[String]:
	host = parent
	var level := Node3D.new()
	player = (load("res://shared/scenes/player/player.tscn") as PackedScene).instantiate()
	level.add_child(player)
	target = CounterTarget.new()
	target.position = Vector3(0,1.5,-1.5)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.8,.8,.3)
	shape.shape = box
	target.add_child(shape)
	level.add_child(target)
	host.add_child(level)
	player.set_physics_process(false)
	interactor = player.get_node("Interactor")
	player.camera.look_at(target.global_position)
	await _frames(3)
	_expect(target.hold_duration == 0.0 and interactor.try_interact() and target.count == 1,"Legacy zero-duration use stays immediate")
	target.count = 0
	target.hold_duration = .25
	_press(true)
	await _frames(5)
	_expect(target.count == 0 and interactor.get_hold_progress() > 0.0,"Held use advances without completing early")
	_press(false)
	_expect(interactor.hold_target == null and interactor.get_hold_progress() == 0.0,"Release cancels progress")
	_press(true)
	await _frames(20)
	_expect(target.count == 1,"Holding completes once")
	await _frames(20)
	_expect(target.count == 1,"Keeping E held does not auto-repeat")
	_press(false)
	_press(true)
	await _frames(20)
	_expect(target.count == 2,"A new press after release can use again")
	_press(false)
	await _begin()
	target.position.z = -10
	await _frames(3)
	_expect(interactor.hold_target == null and target.count == 2,"Leaving reach cancels without success")
	target.position.z = -1.5
	await _frames(3)
	await _begin()
	player.camera.rotation.y += PI
	await _frames(3)
	_expect(interactor.hold_target == null,"Looking away cancels")
	player.camera.look_at(target.global_position)
	await _frames(3)
	await _begin()
	var wall := StaticBody3D.new()
	wall.position = Vector3(0,1.5,-.7)
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(1,2,.15)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	level.add_child(wall)
	await _frames(3)
	_expect(interactor.hold_target == null,"A new physical obstruction cancels the hold")
	wall.queue_free()
	await _frames(3)
	await _begin()
	target.allowed = false
	await _frames(3)
	_expect(interactor.hold_target == null,"Changed target prerequisites cancel")
	target.allowed = true
	await _begin()
	host.get_tree().paused = true
	await _frames(3)
	_expect(interactor.hold_target == null,"Pause cancels even though normal actors stop processing")
	host.get_tree().paused = false
	await _frames(18)
	_expect(target.count == 2,"Resuming while E remains held does not complete or restart")
	await _begin()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	_expect(interactor.hold_target == null,"Capture-style actor freezing cancels the hold")
	player.process_mode = Node.PROCESS_MODE_INHERIT
	_press(false)
	level.queue_free()
	await _frames(30)
	print("HOLD INTERACTION CHECKS: ",checks," checks; ",failures.size()," failures")
	return failures

func _begin() -> void:
	_press(false)
	await _frames(2)
	_press(true)
	await _frames(3)
	_expect(interactor.hold_target == target,"A fresh hold starts through input")

func _press(down: bool) -> void:
	if down: Input.action_press("interact")
	else: Input.action_release("interact")
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = down
	host.get_tree().root.push_input(event)

func _frames(count: int) -> void:
	for i in count: await host.get_tree().physics_frame

func _expect(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures.append("[hold] "+message)
