extends Node
## K17's authored meshes on the shared animated joints. No changes to AI or motion.
const BASE := "res://maps/intelligence/assets/models/"
const PARTS := {
	"Model/Hips/Pelvis": "soldier_pelvis", "Model/Hips/Torso/Chest": "soldier_torso",
	"Model/Hips/Torso/Head/Face": "soldier_head",
	"Model/Hips/Torso/ArmL/Sleeve": "soldier_arm", "Model/Hips/Torso/ArmR/Sleeve": "soldier_arm",
	"Model/Hips/Torso/ArmL/Hand": "soldier_hand", "Model/Hips/Torso/ArmR/Hand": "soldier_hand",
	"Model/Hips/LegL/Trouser": "soldier_leg", "Model/Hips/LegR/Trouser": "soldier_leg",
	"Model/Hips/LegL/Shoe": "soldier_boot", "Model/Hips/LegR/Shoe": "soldier_boot"}

func _ready() -> void:
	for guard in get_parent().get_node("Guards").get_children():
		apply(guard)

static func apply(guard: Node3D) -> void:
	if guard.has_meta("military_applied"): return
	guard.set_meta("military_applied",true)
	for mesh in guard.get_node("Model").find_children("*","MeshInstance3D",true,false): mesh.visible=false
	for path in PARTS:
		var original:=guard.get_node(path) as Node3D
		var part: Node3D=(load(BASE+PARTS[path]+".glb") as PackedScene).instantiate()
		part.name="Military"+str(original.name)
		part.position=original.position
		original.get_parent().add_child(part)
		for mesh in part.find_children("*","GeometryInstance3D",true,false):
			mesh.gi_mode=GeometryInstance3D.GI_MODE_DYNAMIC
			mesh.layers=2 # Excluded only from the empty-corridor projection camera.
