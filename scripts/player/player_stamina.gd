class_name PlayerStamina
extends Node

## Sprint stamina for the player (child "Stamina" of the player scene).
## Off by default, so a level that does not switch it on (the tutorial) keeps
## unlimited sprinting; the Expanded Library switches it on with the player's
## use_stamina.
##
## Rules (all values configurable below):
##   - Only sprinting drains stamina: walking, standing, crouching, hiding,
##     using things and being seen by a guard cost nothing.
##   - A sprint can only start with at least `min_to_start` stamina, and stops
##     when stamina reaches zero. After running dry, the sprint key must be
##     released before the next sprint (holding it does not restart a sprint
##     the moment `min_to_start` is reached again).
##   - Stamina refills `regen_delay` seconds after the last sprint ended.
##   - Respawning refills it (FirstPersonPlayer.respawn()).
## Everything is computed from the frame time (delta), including the part of
## a frame left over after the regeneration delay ends, so the result does not
## depend on the frame rate or the physics tick rate.

signal exhausted
signal changed(value: float)

## Off: sprinting is unlimited and stamina is never shown (the tutorial).
## Set from FirstPersonPlayer.use_stamina.
var enabled := false
@export var max_stamina := 100.0
## Units per second while sprinting.
@export var sprint_drain := 20.0
## Units per second while refilling.
@export var regen_rate := 15.0
## Seconds after a sprint ends before stamina starts to refill.
@export var regen_delay := 1.0
## A sprint can only start with at least this much stamina.
@export var min_to_start := 15.0

var stamina := 100.0
## True while the player is sprinting (as allowed by stamina).
var is_sprinting := false
## Seconds of sprinting since this node started (for tests and tuning).
var sprint_time := 0.0

var _delay_left := 0.0
## Set when stamina runs out; cleared when the sprint key is released.
var _locked := false


func _ready() -> void:
	stamina = max_stamina


## Called by the player every physics frame. `wants_sprint`: the sprint key is
## held; `moving`: there is movement input, on the floor, standing up. Returns
## whether the player sprints this frame.
func update(wants_sprint: bool, moving: bool, delta: float) -> bool:
	if not enabled:
		is_sprinting = wants_sprint
		return wants_sprint
	if not wants_sprint:
		_locked = false
	var sprint := wants_sprint and moving and not _locked
	if sprint and not is_sprinting and stamina < min_to_start:
		sprint = false
	if sprint and stamina <= 0.0:
		sprint = false
	is_sprinting = sprint
	var before := stamina
	if sprint:
		stamina = maxf(stamina - sprint_drain * delta, 0.0)
		sprint_time += delta
		_delay_left = regen_delay
		if stamina <= 0.0:
			# Runs dry: this frame was the last one at sprint speed.
			_locked = true
			exhausted.emit()
	else:
		var t := delta
		if _delay_left > 0.0:
			var used := minf(_delay_left, t)
			_delay_left -= used
			t -= used
		if t > 0.0:
			stamina = minf(stamina + regen_rate * t, max_stamina)
	if stamina != before:
		changed.emit(stamina)
	return sprint


## Full stamina, no delay, nothing held (respawn and checkpoint restores).
func refill() -> void:
	stamina = max_stamina
	is_sprinting = false
	_delay_left = 0.0
	_locked = false
	changed.emit(stamina)


## 0–1, for the HUD.
func get_ratio() -> float:
	return clampf(stamina / max_stamina, 0.0, 1.0) if max_stamina > 0.0 else 0.0


## True when a new sprint could start now.
func can_start_sprint() -> bool:
	return not enabled or (stamina >= min_to_start and not _locked)
