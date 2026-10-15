class_name DocumentPickup
extends Interactable

## A clue document (a note, memo or notice) the player can read. Reading it
## copies it into the journal (PlayerInventory.documents), not into a carried
## slot; the document itself stays where it is and can be read again. The
## journal holds each document once, so nothing is duplicated, and it is kept
## when the player is caught (knowledge is not undone).

@export var document_id: StringName = &"note"
@export var title := "Note"
@export_multiline var text := ""


func _ready() -> void:
	super()
	add_to_group("documents")
	if get_node_or_null("Model") == null:
		_build_model()
	if not _has_shape():
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.5, 0.6, 0.3)
		shape.shape = box
		add_child(shape)


func get_prompt(_by: Node) -> String:
	var inventory := PlayerInventory.find(self)
	if inventory != null and inventory.has_document(document_id):
		return "Read the %s again (in your journal)" % title.to_lower()
	return "Read the %s" % title.to_lower()


func _on_interact(_by: Node) -> bool:
	var inventory := PlayerInventory.find(self)
	if inventory == null or not inventory.enabled:
		return false
	if inventory.add_document(document_id, title, text):
		inventory.notify("Added to your journal: %s  [J]" % title, true)
	inventory.open_document(document_id)
	return true


func _has_shape() -> bool:
	for child in get_children():
		if child is CollisionShape3D:
			return true
	return false


## A clipboard: a board with a sheet of paper, facing local +Z.
func _build_model() -> void:
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	for part in [[Vector3(0.3, 0.42, 0.02), Vector3.ZERO, Color(0.45, 0.32, 0.2)],
			[Vector3(0.25, 0.33, 0.005), Vector3(0, -0.02, 0.012), Color(0.93, 0.92, 0.85)],
			[Vector3(0.12, 0.04, 0.03), Vector3(0, 0.19, 0.012), Color(0.6, 0.6, 0.62)]]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		mesh.mesh = box
		mesh.position = part[1]
		var material := StandardMaterial3D.new()
		material.albedo_color = part[2]
		mesh.material_override = material
		model.add_child(mesh)
