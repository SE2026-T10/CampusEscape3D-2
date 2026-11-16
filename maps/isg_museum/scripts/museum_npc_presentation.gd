extends Node

@export_enum("teammate","receptionist") var role := "teammate"
var talking := false
var watching := false
var current_animation := ""
var playback_changes := 0
var visual: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var look: SkeletonModifier3D

func _ready() -> void:
	visual = get_parent().get_node("Visual")
	skeleton = visual.get_node("VisualPivot/GuardRig/Skeleton3D")
	animation = visual.get_node("AnimationPlayer")
	look = preload("res://maps/isg_museum/scripts/npc_watch_modifier.gd").new()
	look.name = "WatchModifier"
	skeleton.add_child(look)
	apply_role_materials(role)
	reset_presentation()

func set_talking(active: bool) -> void:
	if talking==active: return
	talking = active
	_update_animation()

func set_watching(target: Node3D, enabled: bool) -> void:
	watching = enabled and is_instance_valid(target)
	look.target = target if watching else null
	look.enabled = watching
	_update_animation()

func _update_animation() -> void:
	var wanted := "standing_talk" if talking else "standing_idle"
	if role=="receptionist": wanted = "seated_watch" if watching else "seated_talk" if talking else "seated_idle"
	if current_animation==wanted: return
	current_animation = wanted
	playback_changes += 1
	animation.play(wanted,.2)

func reset_presentation() -> void:
	talking = false
	watching = false
	look.target = null
	look.enabled = false
	look.yaw = 0
	look.pitch = 0
	current_animation = ""
	animation.stop()
	_update_animation()
	animation.advance(0)

func apply_role_materials(value: StringName) -> void:
	role = value
	var colours := {"Object_5":Color(.43,.49,.38),"Object_6":Color(.17,.27,.22),"Object_8":Color(.20,.25,.22)} if role=="teammate" else {
		"Object_5":Color(.66,.59,.49),"Object_6":Color(.34,.26,.20),"Object_8":Color(.30,.28,.25)}
	for mesh: MeshInstance3D in skeleton.get_children().filter(func(n): return n is MeshInstance3D):
		# The two detached handheld weapon meshes are safe to hide for civilian roles.
		if mesh.name in ["Object_9","Object_10"]: mesh.hide()
		if String(mesh.name) not in colours: continue
		for s in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(s).duplicate() as StandardMaterial3D
			mat.albedo_color = colours[String(mesh.name)]
			mesh.set_surface_override_material(s,mat)

func bone_position(name: String) -> Vector3:
	skeleton.force_update_all_bone_transforms()
	return skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_"+name)).origin
