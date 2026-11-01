extends RefCounted
## Map-local V5 authoring and runtime contract. No change to the shared inventory.
const TARGET := Vector3(37.6, 0, 17.15)
const TARGET_ANGLE := PI
const STAND := Vector3(37.6, .05, 15.25)
const HOLD_SECONDS := 5.0
const FINALE_SECONDS := 4.0
const DETONATE_AT := .7
const FINALE_WATCHDOG := 6.0
const SMOKE := Vector3(37.6, 3.48, 17.15)
const VIEWS := {
	&"maintenance": [Vector3(46, 7, 28), Vector3(36.8, 3.3, 15.5)],
	&"courtyard": [Vector3(30, 7, 27), Vector3(38, 3.3, 15.5)],
}
