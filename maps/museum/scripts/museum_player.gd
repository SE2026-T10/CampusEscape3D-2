extends FirstPersonPlayer

## Museum-only carrying rules. Other maps keep the shared player unchanged.
signal carry_changed(painting: Node3D)

@export var carry_walk_speed := 2.0
@export var carry_crouch_speed := 1.1

var carried_painting: Node3D


func is_carrying() -> bool:
	return is_instance_valid(carried_painting)


func begin_carry(painting: Node3D) -> bool:
	if not is_instance_valid(painting) or is_carrying() or not _is_playing():
		return false
	carried_painting = painting
	_clamp_carry_velocity()
	if stamina:
		stamina.is_sprinting = false
	carry_changed.emit(carried_painting)
	return true


func end_carry(painting: Node3D) -> void:
	if carried_painting != painting:
		return
	carried_painting = null
	carry_changed.emit(null)


func get_target_velocity(input_dir: Vector2, sprinting: bool) -> Vector3:
	if not is_carrying():
		return super(input_dir, sprinting)
	var direction := global_basis * Vector3(input_dir.x, 0.0, input_dir.y)
	direction.y = 0.0
	return direction.limit_length(1.0) * _carry_speed()


func _physics_process(delta: float) -> void:
	if not is_carrying():
		super(delta)
		return
	# The shared controller passes the sprint key to stamina before choosing its
	# velocity. Carrying has its own short branch so Shift never consumes stamina.
	if global_position.y < fall_limit_y:
		respawn()
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	_update_crouch(delta)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if stamina:
		stamina.update(false, input_dir.length_squared() > 0.01 and not is_crouching, delta)
	_clamp_carry_velocity()
	var target := get_target_velocity(input_dir, false)
	var horizontal := calculate_horizontal_velocity(Vector3(velocity.x, 0.0, velocity.z), target, delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.physical_keycode == KEY_Q or event.keycode == KEY_Q) \
			and is_carrying() and _is_playing():
		if carried_painting.has_method("try_drop"):
			carried_painting.call("try_drop")
		get_viewport().set_input_as_handled()
		return
	super(event)


func _carry_speed() -> float:
	return maxf(0.0, carry_crouch_speed if is_crouching else carry_walk_speed)


func _clamp_carry_velocity() -> void:
	var horizontal := Vector2(velocity.x, velocity.z).limit_length(_carry_speed())
	velocity.x = horizontal.x
	velocity.z = horizontal.y


func _is_playing() -> bool:
	var flow := GameFlow.find(self)
	return flow != null and flow.state == GameStateMachine.State.PLAYING and not flow.is_leaving()
