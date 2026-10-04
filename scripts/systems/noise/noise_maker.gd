class_name NoiseMaker
extends Node3D

## Reusable component for anything that makes a noise when used: doors, the
## exit, knocked-over objects. Call make_noise() from the object's own code.

@export var type: NoiseEvent.Type = NoiseEvent.Type.INTERACTION
## Override the type's preset values (-1 keeps the preset).
@export var intensity := -1.0
@export var radius := -1.0
@export var source_group := "player"


## Emits the noise at this node's position. Returns the event, or null if the scene has no NoiseSystem.
func make_noise() -> NoiseEvent:
	var system := NoiseSystem.find(self)
	if system == null:
		return null
	return system.emit_noise(global_position, type, source_group, intensity, radius)
