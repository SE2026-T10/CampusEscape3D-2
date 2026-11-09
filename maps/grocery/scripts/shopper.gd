class_name Shopper
extends Guard

## A customer. It walks a route and looks with the shared GuardVision like a guard, but:
##   - it never chases or catches anyone: its perception is always empty, so the state machine
##     stays on PATROL;
##   - it only cares about a thief. While the player carries the stolen item (GroceryHeist) and
##     this customer can see them, a witness timer runs (faster when the player is close or
##     standing; slower when crouched, via get_visibility_factor). At report_time seconds the
##     customer reports: every GroceryStaff within report_radius is alerted to the player's spot
##     and the customer shows "!" for a while. After report_cooldown seconds it may report again,
##     which re-targets the staff if the thief is still in sight.
## A shopper leaves the "guards" group (so the stealth HUD and catch rules, which are about the
## staff, ignore it) and joins "shoppers"; it resets itself when the level resets.

signal reported(position: Vector3)

## Seconds of seeing the thief (at full visibility) before reporting.
@export var report_time := 1.5
## Seconds before the same customer can report again.
@export var report_cooldown := 8.0
## Staff further than this (metres) from the thief are not alerted.
@export var report_radius := 60.0
## Seconds the "!" stays above the customer after a report.
@export var alert_display_time := 3.0

var witness_time := 0.0
var report_count := 0
var _cooldown_left := 0.0
var _alert_left := 0.0


func _ready() -> void:
	super()
	remove_from_group("guards")
	add_to_group("shoppers")
	GroceryStyle.dress_customer(self, int(get_index()))
	_bind_level_reset.call_deferred()


func _bind_level_reset() -> void:
	var director := StealthDirector.find(self)
	if director and not director.level_reset.is_connected(reset_to_start):
		director.level_reset.connect(reset_to_start)


func reset_to_start() -> void:
	witness_time = 0.0
	_cooldown_left = 0.0
	_alert_left = 0.0
	super()


## A shopper perceives nothing for the AI (it never leaves PATROL); witnessing is done here.
func build_perception() -> GuardPerception:
	_witness(get_physics_process_delta_time())
	return GuardPerception.new()


func _witness(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_alert_left = maxf(_alert_left - delta, 0.0)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var heist := GroceryHeist.find(self)
	if player == null or heist == null or vision == null \
			or not heist.has_loot() or not vision.can_see_target or _cooldown_left > 0.0:
		witness_time = maxf(witness_time - delta, 0.0)
		return
	var factor: float = player.get_visibility_factor() if player.has_method("get_visibility_factor") else 1.0
	witness_time += delta * factor
	if witness_time >= report_time:
		report(player.global_position)


## Calls the staff to `position` now (also used directly by tests).
func report(position: Vector3) -> void:
	witness_time = 0.0
	_cooldown_left = report_cooldown
	_alert_left = alert_display_time
	report_count += 1
	for node in get_tree().get_nodes_in_group("grocery_staff"):
		var staff := node as GroceryStaff
		if staff and staff.global_position.distance_to(position) <= report_radius:
			staff.alert(position)
	reported.emit(position)


func is_alerting() -> bool:
	return _alert_left > 0.0


func _update_alert_icon() -> void:
	if alert_icon == null:
		return
	if is_alerting():
		alert_icon.text = "!"
		alert_icon.modulate = Color(1.0, 0.25, 0.2)
		alert_icon.visible = true
	elif vision and vision.can_see_target and witness_time > 0.0:
		alert_icon.text = "?"
		alert_icon.modulate = Color(1, 1, 1, clampf(witness_time / report_time, 0.3, 1.0))
		alert_icon.visible = true
	else:
		alert_icon.visible = false
