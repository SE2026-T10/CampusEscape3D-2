class_name BadgeReader
extends Interactable

## The main entrance's badge reader (Expanded Library, expansion Phase 6,
## escape route A). With the security master badge carried, E starts an
## override of the night lockdown: the player must stay at the reader for
## `hold_time` seconds (moving away or being caught interrupts it). The reader
## beeps when the override starts and the bolts bang when it ends: noises
## guards nearby hear. A lobby camera watches it. When the override completes
## the exit (`exit_path`, the MainEntranceExit ExitDoor) is unlocked.
## The badge is only checked, never used up. Nothing here is stored at
## checkpoints: the exit stores whether it is unlocked, and a respawn
## cancels an override in progress.

signal feedback(text: String, good: bool)
signal rejected(reason: String)

@export var reader_name := "Badge reader"
## ItemCatalog id of the credential.
@export var required_item: StringName = ItemCatalog.SECURITY_BADGE
@export var exit_path: NodePath
## Seconds the player must stay at the reader.
@export var hold_time := 4.0
## Horizontal distance (metres) the player may move from the reader during the override.
@export var max_distance := 2.5
## Noises guards can hear: the start beep and the bolts at the end.
@export var beep_radius := 12.0
@export var bolts_radius := 16.0

var overriding := false
var override_left := 0.0
## Overrides started / interrupted (for tests).
var overrides_started := 0
var interruptions := 0
var rejections := 0

var _screen: Label3D
var _material: StandardMaterial3D


func _ready() -> void:
	super()
	add_to_group("puzzles")   # ObjectiveHud shows `feedback`
	add_to_group("badge_readers")
	_build()
	_connect_late.call_deferred()


func _connect_late() -> void:
	var checkpoints := CheckpointManager.find(self)
	if checkpoints and not checkpoints.respawned.is_connected(_on_respawned):
		checkpoints.respawned.connect(_on_respawned)


func get_exit() -> ExitDoor:
	return get_node_or_null(exit_path) as ExitDoor


func is_done() -> bool:
	var exit := get_exit()
	return exit != null and exit.unlocked


func _has_badge(by: Node) -> bool:
	var inventory := by.get_node_or_null("Inventory") as PlayerInventory if by else null
	if inventory == null:
		inventory = PlayerInventory.find(self)
	return inventory != null and inventory.enabled and inventory.has(required_item)


func get_prompt(by: Node) -> String:
	if is_done():
		return "%s · lockdown lifted" % reader_name
	if overriding:
		return "%s · overriding… stay here (%d s)" % [reader_name, ceili(override_left)]
	if not _has_badge(by):
		return "%s · %s needed" % [reader_name, ItemCatalog.item_name(required_item).to_lower()]
	return "%s: override the lockdown (%d s)" % [reader_name, int(hold_time)]


func _on_interact(by: Node) -> bool:
	if is_done():
		feedback.emit("The lockdown is already lifted: the main entrance is open.", true)
		return false
	if overriding:
		return false
	if not _has_badge(by):
		rejections += 1
		rejected.emit("%s: it needs the %s." % [reader_name, ItemCatalog.item_name(required_item).to_lower()])
		return false
	overriding = true
	override_left = hold_time
	overrides_started += 1
	_noise(beep_radius, 0.7, "Badge reader beeps")
	feedback.emit("Lockdown override started: stay at the reader for %d s." % int(hold_time), true)
	return true


func _process(delta: float) -> void:
	_update_screen()
	if not overriding:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var director := StealthDirector.find(self)
	var away := player == null or Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length() > max_distance
	if away or (director and director.status in [StealthDirector.Status.CAUGHT, StealthDirector.Status.ESCAPED]):
		cancel("Override interrupted: you left the reader. Start again.")
		return
	override_left = maxf(override_left - delta, 0.0)
	if override_left == 0.0:
		overriding = false
		var exit := get_exit()
		if exit:
			exit.unlock()
		_noise(bolts_radius, 1.0, "Door bolts bang open")
		feedback.emit("Lockdown lifted: the main entrance is open.", true)


## Stops an override in progress (with a message if `text` is set).
func cancel(text := "") -> void:
	if not overriding:
		return
	overriding = false
	override_left = 0.0
	interruptions += 1
	if text != "":
		feedback.emit(text, false)


func _on_respawned(_checkpoint: Checkpoint) -> void:
	cancel()


func _noise(radius: float, intensity: float, caption := "") -> void:
	var system := NoiseSystem.find(self)
	if system:
		system.emit_noise(global_position, NoiseEvent.Type.INTERACTION, "environment", intensity, radius, -1.0, caption)


func _update_screen() -> void:
	if _screen == null:
		return
	var colour := Color(0.85, 0.2, 0.18)
	if is_done():
		_screen.text = "OPEN"
		colour = Color(0.3, 0.9, 0.45)
	elif overriding:
		_screen.text = "OVERRIDE %d%%" % int(100.0 * (1.0 - override_left / maxf(hold_time, 0.01)))
		colour = Color(1.0, 0.8, 0.2)
	else:
		_screen.text = "LOCKDOWN"
	_screen.modulate = colour
	_material.albedo_color = colour
	_material.emission = colour


func _build() -> void:
	if get_node_or_null("Shape") == null:
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		var box := BoxShape3D.new()
		box.size = Vector3(0.3, 0.4, 0.2)
		shape.shape = box
		add_child(shape)
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18, 0.28, 0.06)
	body.mesh = mesh
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.13, 0.15)
	body.material_override = dark
	add_child(body)
	var light := MeshInstance3D.new()
	var light_mesh := BoxMesh.new()
	light_mesh.size = Vector3(0.12, 0.04, 0.02)
	light.mesh = light_mesh
	light.position = Vector3(0, 0.09, 0.035)
	_material = StandardMaterial3D.new()
	_material.emission_enabled = true
	_material.emission_energy_multiplier = 1.5
	light.material_override = _material
	add_child(light)
	_screen = Label3D.new()
	_screen.font_size = 26
	_screen.pixel_size = 0.003
	_screen.outline_size = 8
	_screen.position = Vector3(0, 0.25, 0.04)
	add_child(_screen)
	var title := Label3D.new()
	title.text = "BADGE READER · NIGHT LOCKDOWN"
	title.font_size = 18
	title.pixel_size = 0.003
	title.outline_size = 6
	title.position = Vector3(0, 0.36, 0.04)
	add_child(title)
	_update_screen()
