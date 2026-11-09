class_name GroceryStaff
extends Guard

## A store employee: exactly the shared Guard (PATROL / INVESTIGATE / CHASE, vision, hearing),
## plus one thing, alert(): a customer's report. An alerted employee gets a confirmed sighting
## at the reported spot added to what it perceives, so the shared state machine sends it into
## CHASE toward that place. It still has to see the player itself to catch them
## (StealthDirector needs a chasing guard with the player in sight).

## Seconds an unanswered report stays in the perception (it is dropped as soon as CHASE starts).
const REPORT_LIFETIME := 1.5

var _report_position := Vector3.ZERO
var _report_until_msec := 0


func _ready() -> void:
	super()
	add_to_group("grocery_staff")
	GroceryStyle.dress_staff(self, int(get_index()))


## A customer reports the thief at `position`: head there and chase.
func alert(position: Vector3) -> void:
	_report_position = position
	_report_until_msec = Time.get_ticks_msec() + int(REPORT_LIFETIME * 1000.0)
	if machine and machine.current == GuardStateMachine.CHASE:
		# Already chasing: the state only re-targets on its own sighting, so redirect here.
		navigate_to(position, chase_speed)


func is_report_pending() -> bool:
	return Time.get_ticks_msec() < _report_until_msec


func build_perception() -> GuardPerception:
	var p := super()
	if is_report_pending():
		if machine.current == GuardStateMachine.CHASE:
			_report_until_msec = 0  # Answered: the chase is on.
		else:
			p.confirmed_sighting = true
			p.has_sighting_position = true
			p.sighting_position = _report_position
	return p


func reset_to_start() -> void:
	_report_until_msec = 0
	super()
