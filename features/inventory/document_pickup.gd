class_name DocumentPickup
extends Interactable

## A clue document (a note, memo or notice) the player can read. Reading it
## copies it into the journal (PlayerInventory.documents), not into a carried
## slot; the document itself stays where it is and can be read again. The
## journal holds each document once, so nothing is duplicated, and it is kept
## when the player is caught (knowledge is not undone).
##
## kind "clue" is a short environmental detail (a plaque, a label) rather than a
## note: it is listed under CLUES in the journal. `discovers_objective` reveals
## a hidden optional objective when read (ObjectiveManager.discover()).
## `display_text` is shown on the object itself (a plaque's engraving), so it
## can be read in the world without using it.

@export var document_id: StringName = &"note"
@export var title := "Note"
@export_multiline var text := ""
## "document" or "clue".
@export_enum("document", "clue") var kind := "document"
## "clipboard" (a note on a board) or "plaque" (a brass plate).
@export_enum("clipboard", "plaque") var model := "clipboard"
## Hidden optional objective revealed by reading this (empty: none).
@export var discovers_objective: StringName = &""
## Text drawn on the object (empty: none).
@export var display_text := ""
## False while it is not there yet (e.g. inside a locked locker; CodeLock reveals it).
@export var available := true
## A floating "!" over it until it is read (in the journal), then never again: it checks
## the journal, so it stays gone after a catch (the journal is kept). Off by default.
@export var show_marker := false
## Where the "!" floats, from the node (it bobs and pulses around this point).
@export var marker_offset := Vector3(0, 0.8, 0)
## The "!"'s size (Label3D pixel size; 0.004 is about 0.38 m tall).
@export var marker_pixel_size := 0.004

var _marker: Label3D
var _marker_time := 0.0


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
	if show_marker:
		_build_marker()
	set_available(available)


func set_available(on: bool) -> void:
	available = on
	visible = on
	enabled = on
	_refresh_marker()


## True once this document is in the player's journal.
func is_read() -> bool:
	var inventory := PlayerInventory.find(self)
	return inventory != null and inventory.has_document(document_id)


func _build_marker() -> void:
	_marker = Label3D.new()
	_marker.name = "Marker"
	_marker.text = "!"
	_marker.font_size = 96
	_marker.pixel_size = marker_pixel_size
	_marker.outline_size = 18
	_marker.modulate = Color(1.0, 0.82, 0.1)
	_marker.outline_modulate = Color(0.12, 0.08, 0.0)
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.position = marker_offset
	add_child(_marker)


## Shows the "!" while it is there and unread; processes only while it shows.
func _refresh_marker() -> void:
	if _marker == null:
		return
	var on := available and not (is_inside_tree() and is_read())
	_marker.visible = on
	set_process(on)


func _process(delta: float) -> void:
	if _marker == null or not _marker.visible:
		set_process(false)
		return
	if is_read():   # read elsewhere (e.g. restored with the journal)
		_refresh_marker()
		return
	_marker_time += delta
	_marker.position = marker_offset + Vector3(0, sin(_marker_time * 2.4) * 0.05, 0)
	var pulse := 1.0 + 0.08 * sin(_marker_time * 4.8)
	_marker.scale = Vector3.ONE * pulse


func get_prompt(_by: Node) -> String:
	var inventory := PlayerInventory.find(self)
	var verb := "Examine" if kind == "clue" else "Read"
	if inventory != null and inventory.has_document(document_id):
		return "%s the %s again (in your journal)" % [verb, title.to_lower()]
	return "%s the %s" % [verb, title.to_lower()]


func _on_interact(_by: Node) -> bool:
	var inventory := PlayerInventory.find(self)
	if inventory == null or not inventory.enabled:
		return false
	if inventory.add_document(document_id, title, text, kind):
		inventory.notify("Added to your journal: %s  [J]" % title, true)
	if discovers_objective != &"":
		var objectives := ObjectiveManager.find(self)
		if objectives:
			objectives.discover(discovers_objective)
	inventory.open_document(document_id)
	_refresh_marker()
	return true


func _has_shape() -> bool:
	for child in get_children():
		if child is CollisionShape3D:
			return true
	return false


## A clipboard (a board with a sheet of paper) or a plaque, facing local +Z.
func _build_model() -> void:
	var holder := Node3D.new()
	holder.name = "Model"
	add_child(holder)
	if display_text != "":
		var label := Label3D.new()
		label.text = display_text
		label.font_size = 26
		label.pixel_size = 0.0035
		label.position = Vector3(0, 0, 0.03)
		label.modulate = Color(0.2, 0.15, 0.08) if model == "plaque" else Color(0.1, 0.1, 0.12)
		label.outline_size = 0
		holder.add_child(label)
	var parts := [[Vector3(0.7, 0.4, 0.03), Vector3.ZERO, Color(0.78, 0.62, 0.3)],
			[Vector3(0.74, 0.44, 0.015), Vector3(0, 0, -0.012), Color(0.35, 0.25, 0.12)]] if model == "plaque" else [[Vector3(0.3, 0.42, 0.02), Vector3.ZERO, Color(0.45, 0.32, 0.2)],
			[Vector3(0.25, 0.33, 0.005), Vector3(0, -0.02, 0.012), Color(0.93, 0.92, 0.85)],
			[Vector3(0.12, 0.04, 0.03), Vector3(0, 0.19, 0.012), Color(0.6, 0.6, 0.62)]]
	for part in parts:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		mesh.mesh = box
		mesh.position = part[1]
		var material := StandardMaterial3D.new()
		material.albedo_color = part[2]
		mesh.material_override = material
		holder.add_child(mesh)
