extends GuardHearing

## Running in the same small enclosed room is audible around low furniture.
@export var room_run_sensitivity := 2.0


func process_event(event: NoiseEvent, now: float) -> bool:
	var actor := get_parent()
	# Discard quiet events before the shared merge window: a quiet footstep must
	# never suppress a subsequent loud RUN/bottle at the same estimated location.
	if actor.is_seated() and event.intensity < actor.wake_loudness:
		return false
	if actor.is_seated() and event.type == NoiseEvent.Type.RUN \
			and _inside_staff_room(event.position) and _inside_staff_room(global_position):
		# Only this listener's same-room RUN acoustics change. Preserve the shared
		# event, age/range/dedup rules and estimated location; walls/floors outside
		# this room still use the normal attenuation path.
		var previous_sensitivity := sensitivity
		var previous_wall_factor := wall_factor
		sensitivity = maxf(sensitivity,room_run_sensitivity)
		wall_factor = 1.0
		var reported := super(event,now)
		sensitivity = previous_sensitivity
		wall_factor = previous_wall_factor
		return reported
	return super(event,now)


func _inside_staff_room(point: Vector3) -> bool:
	return point.x > 27.15 and point.x < 35.85 and point.z > 6.15 and point.z < 17.85 \
		and point.y >= -0.2 and point.y < 2.2
