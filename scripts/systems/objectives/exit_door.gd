class_name ExitDoor
extends Interactable

## The library's exit. Using it escapes only when the escape objective is
## ACTIVE, which means every earlier objective (including the access card) is
## done. Otherwise the door rejects the player: it rattles (an INTERACTION
## noise guards can hear, from the optional NoiseMaker child "Noise") and
## emits `rejected` with the reason for the HUD.

signal rejected(reason: String)
signal escaped
## Walk-through exits: messages that are not refusals (e.g. a lockdown engaging).
signal feedback(text: String, good: bool)

@export var objective_id: StringName = ObjectiveManager.ESCAPE
## The objective that unlocks the door (shown as the reason when it is missing).
@export var key_objective_id: StringName = ObjectiveManager.TAKE_CARD

## Sign text while the key objective is not done, and the HUD message when the
## door refuses the player for that reason. "%s" in locked_reason is replaced by
## the current objective's title (lower case).
@export var locked_sign := "LOCKED · ACCESS CARD"
@export var locked_reason := "The exit is locked. You need the access card."
## Prompt while the door would not open.
@export var locked_prompt := "Exit locked (access card needed)"

## A second objective that must be COMPLETED too (optional; e.g. the
## Expanded Library's storm drain needs the culvert drained), and the reason
## shown while it is not.
@export var extra_key_objective_id: StringName = &""
@export var extra_locked_reason := "This way out is still blocked."

## PowerNetwork circuit the door needs (optional; the Expanded Library's loading
## dock shutter needs "service_exit"), and the reason shown without it.
@export var power_circuit: StringName = &""
@export var no_power_reason := "The exit has no power."
@export var no_power_sign := "NO POWER"

## The visible door. It is tinted red while locked and green once the card is taken.
@export var door_mesh: MeshInstance3D

@export_group("Walk-through exit (Expanded Library)")
## Expansion Phase 6. Off (the tutorial): pressing E at the door escapes once
## it is unlocked. On: the door OPENS when its conditions are met (power, the
## extra objective, an unlock() from the route's mechanism) and the player
## escapes by walking into its trigger (an Area3D, `trigger_path`) with the
## key objective (the mission item) done. E at the door says what is missing.
## Without the mission item the trigger refuses, with a message.
@export var walk_through := false
## Area3D the player walks into to escape.
@export var trigger_path: NodePath
## StaticBody3D that blocks the way while the exit is closed (optional).
@export var panel_path: NodePath
## Needs unlock() from a mechanism (badge reader, shutter control); stored at checkpoints.
@export var needs_unlock := false
@export var unlock_reason := "The exit is locked."
## While this objective is not completed the exit is open and its trigger
## disarmed (the main entrance is the way in); once completed it closes (the
## lockdown) until unlocked, and `lockdown_text` is shown.
@export var armed_after_objective: StringName = &""
@export_multiline var lockdown_text := ""
## The escape route this exit is (recorded by ObjectiveManager on escape).
@export var route_id: StringName = &""
@export var route_name := ""
@export var open_sign := "EXIT · OPEN"

## Times the door has refused the player (for tests).
var rejections := 0
## Walk-through: unlocked by its mechanism (stored at checkpoints).
var unlocked := false

var _trigger: Area3D
var _panel: StaticBody3D
var _panel_open := true
var _refuse_cooldown := 0.0

@onready var _noise: NoiseMaker = get_node_or_null("Noise")
@onready var _sign: Label3D = get_node_or_null("Sign")


var _door_material: StandardMaterial3D


func _ready() -> void:
	super()
	prompt = "Escape"
	if door_mesh:
		_door_material = StandardMaterial3D.new()
		door_mesh.material_override = _door_material
	if walk_through:
		add_to_group("checkpoint_state")
		add_to_group("puzzles")   # ObjectiveHud shows `feedback`
		add_to_group("walk_through_exits")
		_trigger = get_node_or_null(trigger_path) as Area3D
		if _trigger:
			_trigger.collision_layer = 0
			_trigger.collision_mask = 2   # player
			_trigger.monitoring = true
			_trigger.body_entered.connect(_on_trigger_entered)
		_panel = get_node_or_null(panel_path) as StaticBody3D
		_apply_panel.call_deferred()
		_connect_walk_through.call_deferred()


func _connect_walk_through() -> void:
	var manager := _manager()
	if manager and not manager.objective_completed.is_connected(_on_objective_completed):
		manager.objective_completed.connect(_on_objective_completed)


func _on_objective_completed(id: StringName) -> void:
	if id == armed_after_objective and lockdown_text != "":
		feedback.emit(lockdown_text, false)


func _process(delta: float) -> void:
	if walk_through:
		_refuse_cooldown = maxf(_refuse_cooldown - delta, 0.0)
		_apply_panel()
		var ready := is_unlocked()
		var colour_w := Color(0.3, 0.9, 0.45) if ready else Color(0.8, 0.18, 0.15)
		if _door_material:
			_door_material.albedo_color = colour_w
		if _sign:
			# The text says whether the way is open; the colour whether walking out would escape.
			_sign.text = open_sign if is_open() else (locked_sign if not _key_done() else _walk_reason_sign())
			_sign.modulate = colour_w.lightened(0.2)
		return
	var has_key := _manager() != null and _manager().is_completed(key_objective_id) and _extra_done() and _has_power()
	var colour := Color(0.3, 0.9, 0.45) if has_key else Color(0.8, 0.18, 0.15)
	if _door_material:
		_door_material.albedo_color = colour
	if _sign:
		# The mission item comes first; once it is held, a missing power supply is what the sign shows.
		var key_done := _manager() != null and _manager().is_completed(key_objective_id)
		_sign.text = "EXIT · UNLOCKED" if has_key else (no_power_sign if key_done and not _has_power() else locked_sign)
		_sign.modulate = colour.lightened(0.2)


func get_prompt(_by: Node) -> String:
	if walk_through:
		if is_unlocked():
			return "%s: open · walk through to escape" % route_name
		if is_open() and _armed():
			return "%s: open (the rare manuscript first)" % route_name
		return locked_prompt
	return "Escape" if is_unlocked() else locked_prompt


## True when using the door (walk-through: walking into its trigger) would escape.
func is_unlocked() -> bool:
	var manager := _manager()
	return manager != null and manager.get_state(objective_id) == ObjectiveManager.State.ACTIVE and _extra_done() and _has_power() \
		and (not walk_through or (is_open() and _armed()))


## Walk-through: the way is open (the panel is out of the way).
func is_open() -> bool:
	if not walk_through:
		return is_unlocked()
	if not _armed():
		return true   # before the lockdown: the way in
	return (not needs_unlock or unlocked) and _has_power() and _extra_done()


## Walk-through: opens the exit (from its mechanism) once its other conditions hold.
func unlock() -> void:
	if unlocked:
		return
	unlocked = true
	_apply_panel()


func _armed() -> bool:
	return armed_after_objective == &"" or (_manager() != null and _manager().is_completed(armed_after_objective))


func _key_done() -> bool:
	return _manager() != null and _manager().is_completed(key_objective_id)


func _walk_reason_sign() -> String:
	if not _has_power():
		return no_power_sign
	return locked_sign


func _apply_panel() -> void:
	var open := is_open()
	if open == _panel_open and _panel and _panel.visible == not open:
		return
	_panel_open = open
	if _panel:
		_panel.visible = not open
		# Only the layer changes (allowed at any time, also mid physics step).
		_panel.collision_layer = 0 if open else 1


func _on_trigger_entered(body: Node) -> void:
	if not body.is_in_group("player") or not _armed():
		return
	if is_unlocked():
		_escape()
		return
	if _refuse_cooldown > 0.0:
		return
	_refuse_cooldown = 1.5
	rejections += 1
	rejected.emit(rejection_reason())


func _escape() -> void:
	var manager := _manager()
	if manager:
		manager.record_escape_route(route_id, route_name)
		manager.complete(objective_id)
	var director := StealthDirector.find(self)
	if director:
		director.finish_level()
	escaped.emit()


func get_checkpoint_state() -> Dictionary:
	return {"unlocked": unlocked}


func restore_checkpoint_state(state: Dictionary) -> void:
	unlocked = bool(state.get("unlocked", false))
	_refuse_cooldown = 0.0
	_apply_panel()


func _has_power() -> bool:
	if power_circuit == &"":
		return true
	var network := get_tree().get_first_node_in_group("power_network")
	return network != null and network.is_powered(power_circuit)


func _extra_done() -> bool:
	return extra_key_objective_id == &"" or (_manager() != null and _manager().is_completed(extra_key_objective_id))


func _on_interact(_by: Node) -> bool:
	if walk_through:
		# E never escapes here: it explains (the trigger is the way out).
		if is_unlocked():
			feedback.emit("%s is open: walk through to escape." % route_name, true)
			return true
		rejections += 1
		if _noise:
			_noise.make_noise()
		rejected.emit(rejection_reason())
		return false
	if is_unlocked():
		_manager().complete(objective_id)
		var director := StealthDirector.find(self)
		if director:
			director.finish_level()
		escaped.emit()
		return true
	rejections += 1
	if _noise:
		_noise.make_noise()
	rejected.emit(rejection_reason())
	return false


## Why the door won't open right now.
func rejection_reason() -> String:
	var manager := _manager()
	if manager == null:
		return "The exit is locked."
	if walk_through:
		# The mission item first, then the route's own conditions.
		if not manager.is_completed(key_objective_id):
			return locked_reason
		if not _extra_done():
			return extra_locked_reason
		if not _has_power():
			return no_power_reason
		if needs_unlock and not unlocked:
			return unlock_reason
		return "The exit won't open yet: %s first." % manager.get_title(manager.current()).to_lower()
	if not _extra_done():
		return extra_locked_reason
	if not manager.is_completed(key_objective_id):
		return locked_reason % manager.get_title(manager.current()).to_lower() if locked_reason.contains("%s") else locked_reason
	if not _has_power():
		return no_power_reason
	return "The exit won't open yet: %s first." % manager.get_title(manager.current()).to_lower()


func _manager() -> ObjectiveManager:
	return ObjectiveManager.find(self)
