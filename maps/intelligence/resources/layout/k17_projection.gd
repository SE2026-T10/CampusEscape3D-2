extends RefCounted
## V6 coordinates are shared by geometry, gameplay, perception and walking tests.
const VERSION := "v6-b1-refined"
const HOME := Vector3(3.0,-4.0,-50.6)
const GRIP_OFFSET := Vector3(0,0,1.05)
const YAW := PI/2.0
const POST := Vector3(-26.5,-4,-47)
const POST_YAW := -PI/2.0
const POST_EYE := POST+Vector3(0,1.6,0)
const FILE := Vector3(-19,-2.85,-41.2)
const PREP := Vector3(4.25,-3.95,-50.6)
const HALL_Z := -47.0
const BAYS := [Vector3(-2.3,-4,-50.05),Vector3(-11.8,-4,-50.05)]
const BAY_ENTRIES := [Vector3(.2,-4,-50.05),Vector3(-8.8,-4,-50.05)]
const DOCK := Vector3(-16.5,-4,-47)
const PATROL := [Vector3(-3,-4,-36.3),Vector3(-3,-4,-43.2),Vector3(-3,-4,-36.3),Vector3(-10.2,-4,-36.3),Vector3(-10.2,-4,-43.2),Vector3(-10.2,-4,-36.3)]
const HALL_TOP := -48.475
const HALL_BOTTOM := -45.525
const HALL_WIDTH := 2.6
const SOLID_WIDTH := 2.50
const SCREEN_HEIGHT := 2.50
const SENSOR_WIDTH := 4.05
const ROOM_DOOR := Vector3(-14,-2.8,HALL_BOTTOM)
const ROOM_LOCK := Vector3(-15.85,-2.6,-45.55)
const CCTV := Vector3(-26.45,-1.75,-47)
const TERMINAL := Vector3(-26.5,-3.1,-48.1)
const HACK := Vector3(4,-2.6,-52.55)
const NATURAL_INTERVAL := 30.0
const NATURAL_DURATION := 9.5
const CALL_DELAY := 1.5
const CALL_DURATION := 10.0
const CALL_COOLDOWN := 25.0
const CALL_WINDOW := 60.0
const CALL_LOCKOUT := 45.0
const PUSH_SPEED := .85
const REVERSE_SPEED := .85
const SIDE_SPEED := .9
# Covers the moment a cart corner emerges from the L-shaped bay. A narrower
# 12-degree limit exposed hardware before a player could regain calibration.
const ANGLE_LIMIT := 18.0
const MAX_REFERENCE_SHIFT := .65
const SCREEN_SIZE := Vector2(2.60,SCREEN_HEIGHT)
const SCREEN_CENTER := Vector3(0,SCREEN_HEIGHT/2,-.12)
