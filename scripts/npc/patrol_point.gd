class_name PatrolPoint
extends Marker3D

## One stop on a PatrolRoute. Place it on walkable floor.

## Seconds the guard waits here before walking on. -1 uses the guard's default_wait_time.
@export_range(-1.0, 60.0, 0.1) var wait_time := -1.0
