class_name NoiseEvent
extends RefCounted

## One noise in the world. Created by NoiseSystem.emit_noise(); listeners must
## treat it as read-only. A noise carries where and how loud, never who made
## it beyond a coarse source group (so guards can ignore their own noises).

enum Type { WALK, RUN, INTERACTION }

## Default effective radius (metres), intensity (0–1) and lifetime (seconds) per type.
const PRESETS := {
	Type.WALK: {"radius": 5.0, "intensity": 0.4, "lifetime": 0.5},
	Type.RUN: {"radius": 12.0, "intensity": 1.0, "lifetime": 0.5},
	Type.INTERACTION: {"radius": 8.0, "intensity": 0.7, "lifetime": 1.0},
}

## Unique within its NoiseSystem; used by listeners to avoid processing an event twice.
var id := 0
var type: Type = Type.WALK
var position := Vector3.ZERO
## Loudness at the source, 0–1.
var intensity := 0.0
## Distance in open space at which the noise fades to nothing.
var radius := 0.0
## NoiseSystem clock time when the noise was made (seconds of game time).
var timestamp := 0.0
## Seconds after timestamp during which the event is still current.
var lifetime := 0.5
## Coarse origin, e.g. "player" or "environment". Never a node reference.
var source_group := ""


func type_name() -> String:
	return Type.keys()[type]


func age(now: float) -> float:
	return now - timestamp


func is_expired(now: float) -> bool:
	return age(now) > lifetime


## Loudness heard at `distance` with an effective radius `effective_radius` (0 when out of range).
func loudness_at(distance: float, effective_radius: float) -> float:
	if effective_radius <= 0.0 or distance >= effective_radius:
		return 0.0
	return intensity * (1.0 - distance / effective_radius)
