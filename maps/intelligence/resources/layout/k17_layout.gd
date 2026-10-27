extends RefCounted
## Shared coordinates for authoring, mission tooling and integration checks.
const SIZE := Vector2(96,108)
const SPAWN := Vector3(-36,.05,51)
const PASS := Vector3(-36,.84,4)
const CODE := Vector3(5.9,1.34,11.5)
const FILE := Vector3(0,-2.85,-47)
const PREP := Vector3(8,.05,-20)
const LATCH := Vector3(42.9,1.2,5)
const EXITS := [Vector3(-36,1,51),Vector3(36,1,51)]
const GATES := [Vector3(-36,1.1,46),Vector3(36,1.1,46)]
const SENSORS := [Vector3(4,-2.8,-38),Vector3(4,-2.8,-42.4)]
const PATROLS := [
	[Vector3(-30,0,22),Vector3(-22,0,22),Vector3(-22,0,38),Vector3(-26,0,38)],
	[Vector3(-40,0,1),Vector3(-32,0,1),Vector3(-32,0,10),Vector3(-40,0,10)],
	[Vector3(1,0,3),Vector3(9,0,3),Vector3(9,0,10),Vector3(1,0,10)],
	[Vector3(38,0,2),Vector3(38,0,14),Vector3(34,0,14),Vector3(34,0,2)],
	[Vector3(-15,0,-19),Vector3(-15,0,-5),Vector3(-1,0,-5),Vector3(-1,0,-19)],
	[Vector3(-6,-4,-45),Vector3(-6,-4,-36),Vector3(-4,-4,-36),Vector3(-4,-4,-45)],
]
const REINFORCEMENT_ROUTES := [
	[Vector3(-18,0,39.5),Vector3(-18,0,18),Vector3(-12,0,18),Vector3(-12,0,11),Vector3(-12,0,7)],
	[Vector3(22,0,-18),Vector3(22,0,18),Vector3(16,0,18),Vector3(16,0,7),Vector3(4,0,7),Vector3(4,-4,-35),Vector3(7,-4,-45)],
	[Vector3(-42,0,42),Vector3(-36,0,42),Vector3(-24,0,42),Vector3(-24,0,24)],
	[Vector3(44,0,-18),Vector3(36,0,-18),Vector3(36,0,-6),Vector3(26,0,-6),Vector3(26,0,24),Vector3(36,0,40)],
]
