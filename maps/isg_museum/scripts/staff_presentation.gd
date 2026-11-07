extends GuardPresentation

var _rest_pose := {}
var _shins: Array[Node3D] = []
var _was_seated := false


func _ready() -> void:
	super()
	for path in ["Model/Hips","Model/Hips/Torso","Model/Hips/Torso/Head",
		"Model/Hips/Torso/ArmL","Model/Hips/Torso/ArmR","Model/Hips/LegL",
		"Model/Hips/LegR","Model/Hips/LegL/Trouser","Model/Hips/LegR/Trouser"]:
		var node := _guard.get_node(path) as Node3D
		_rest_pose[node] = node.transform
	for side in ["L","R"]:
		var leg := _guard.get_node("Model/Hips/Leg"+side) as Node3D
		var knee := Node3D.new()
		leg.add_child(knee)
		knee.position = Vector3(0,-0.43,0)
		knee.rotation.x = -PI/2
		var shin := MeshInstance3D.new()
		shin.mesh = leg.get_node("Trouser").mesh
		shin.scale.y = 0.675
		shin.position.y = -0.27
		knee.add_child(shin)
		var shoe := MeshInstance3D.new()
		shoe.mesh = leg.get_node("Shoe").mesh
		shoe.position = Vector3(0,-0.57,-0.04)
		knee.add_child(shoe)
		knee.hide()
		_shins.append(knee)


func _process(delta: float) -> void:
	if _guard == null:
		return
	if _guard.is_seated():
		_anim.stop()
		current_animation = ""
		_steps.stop()
		_gear.stop()
		_guard.get_node("Model/Hips").position.y = 0.63
		_guard.get_node("Model/Hips/Torso").rotation.x = -0.08 if _guard.phase == &"sleeping" else 0.0
		_guard.get_node("Model/Hips/Torso/Head").rotation.x = -0.22 if _guard.phase == &"sleeping" else 0.0
		for eye in ["EyeL","EyeR"]:
			_guard.get_node("Model/Hips/Torso/Head/"+eye).scale.y = 0.15 if _guard.phase == &"sleeping" else 1.0
		for side in ["L","R"]:
			_guard.get_node("Model/Hips/Torso/Arm"+side).rotation = Vector3(0.5,0,0.14 if side == "L" else -0.14)
			_guard.get_node("Model/Hips/Leg"+side).position.y = -0.02
			_guard.get_node("Model/Hips/Leg"+side).rotation.x = PI/2
			_guard.get_node("Model/Hips/Leg"+side+"/Trouser").scale.y = 0.55
			_guard.get_node("Model/Hips/Leg"+side+"/Trouser").position.y = -0.22
			_guard.get_node("Model/Hips/Leg"+side+"/Shoe").hide()
		for shin in _shins:
			shin.show()
		_was_seated = true
		return
	if _was_seated:
		for eye in ["EyeL","EyeR"]:
			_guard.get_node("Model/Hips/Torso/Head/"+eye).scale.y = 1.0
		for node: Node3D in _rest_pose:
			node.transform = _rest_pose[node]
		for side in ["L","R"]:
			_guard.get_node("Model/Hips/Leg"+side+"/Shoe").show()
		for shin in _shins:
			shin.hide()
		_was_seated = false
	super(delta)
