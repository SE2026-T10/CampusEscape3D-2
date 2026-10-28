extends RefCounted
## V6 coordinates are shared by geometry, gameplay, perception and walking tests.
const VERSION := "v6-projection"
const HOME := Vector3(3.0,-4.0,-50.6)
const GRIP_OFFSET := Vector3(0,0,1.05)
const YAW := PI/2.0
const POST := Vector3(-17,-4,-47)
const POST_YAW := -PI/2.0
const POST_EYE := POST+Vector3(0,1.6,0)
const FILE := Vector3(-13,-2.85,-41.2)
const PREP := Vector3(4.25,-3.95,-50.6)
const HALL_Z := -47.0
const BAYS := [Vector3(-3,-4,-50.7),Vector3(-10,-4,-50.7)]
const BAY_ENTRIES := [Vector3(-.4,-4,-50.7),Vector3(-6.9,-4,-50.7)]
const DOCK := Vector3(-11,-4,-47)
const PATROL := [Vector3(-5,-4,-35.7),Vector3(-5,-4,-43.5),Vector3(-5,-4,-35.7),Vector3(-15.8,-4,-35.7)]
const PUSH_SPEED := .72
const REVERSE_SPEED := .5
const SIDE_SPEED := .64
# Covers the moment a cart corner emerges from the L-shaped bay. A narrower
# 12-degree limit exposed hardware before a player could regain calibration.
const ANGLE_LIMIT := 18.0
const MAX_REFERENCE_SHIFT := .65
const SCREEN_SIZE := Vector2(2.2,2.24)
const SCREEN_CENTER := Vector3(0,1.12,-.12)
const ROOM_EXIT := Vector3(-12,-2.8,-39)
const AISLE_EXIT := Vector3(1.8,-2.8,-36.5)
const OBSERVATION := Vector3(-9.85,-4,-39.85)
