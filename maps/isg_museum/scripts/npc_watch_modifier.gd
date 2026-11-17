extends SkeletonModifier3D

## Apply limited additive look AFTER animation. Native modifier rollback keeps
## the next animation frame clean; neither the hips nor the Area3D is rotated.
var target: Node3D
var enabled := false
var yaw := 0.0
var pitch := 0.0
var last_head_pose := Quaternion.IDENTITY
var last_hips := Vector3.ZERO

func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk==null: return
	var head := sk.find_bone("mixamorig_Head")
	var wanted_yaw := 0.0
	var wanted_pitch := 0.0
	if enabled and is_instance_valid(target):
		var eye := sk.global_transform*sk.get_bone_global_pose(head).origin
		var direction := sk.global_basis.inverse()*(target.global_position+Vector3.UP*1.5-eye)
		wanted_yaw = clampf(atan2(direction.x,direction.z),-.65,.65)
		wanted_pitch = clampf(-atan2(direction.y,Vector2(direction.x,direction.z).length()),-.18,.18)
	var weight := 1.0-exp(-5.0*delta)
	yaw = lerpf(yaw,wanted_yaw,weight)
	pitch = lerpf(pitch,wanted_pitch,weight)
	for entry in [["mixamorig_Spine2",.25],["mixamorig_Head",.75]]:
		var index := sk.find_bone(entry[0])
		var parent := sk.get_bone_parent(index)
		var parent_basis := sk.get_bone_global_pose(parent).basis.orthonormalized()
		var delta_basis := Basis(Vector3.UP,yaw*entry[1])*Basis(Vector3.RIGHT,pitch*entry[1])
		var local_delta := parent_basis.inverse()*delta_basis*parent_basis
		sk.set_bone_pose_rotation(index,(local_delta*Basis(sk.get_bone_pose_rotation(index))).get_rotation_quaternion())
	last_head_pose = sk.get_bone_pose_rotation(head)
	last_hips = sk.get_bone_global_pose(0).origin
