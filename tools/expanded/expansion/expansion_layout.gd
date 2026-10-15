extends RefCounted

## Expanded Library expansion (2026): layout data for the Expansion sub-scene
## (scenes/level/expanded_library_expansion.tscn). The single source of truth
## for what the expansion adds; tools/expanded/expansion/build_expansion.gd
## turns it into the sub-scene and the expansion tests read their points from it.
## The existing level is described by tools/expanded/expanded_layout.gd (v4,
## frozen) and is not changed here; the three doorways that connect the two
## were cut by tools/expanded/expansion/cut_doorways.py.
##
## Units and axes as in the existing layout: metres, x east, z south (north =
## -z), rectangles [x0, z0, x1, z1]. The ground floor stands on y = 0, the
## upper floor on 4.5; the new basement / service network (zone G) on y = BF.
##
## Phase 2 (playable geometry and navigation, no final polish):
##   G  Basement / service network: a service tunnel 4 m wide under the north
##      side of the building, the west service stair (from the main stacks'
##      cross aisle, cut 1), the east service stair (from the electrical room),
##      a pump room, a maintenance bay, a cable bay and the storm drain.
##   D+ The electrical room, an annex east of Book Processing behind a staff
##      card door (cut 2), so zone D still needs the card.
##   B  The main stacks gain two routes: the west service stair (cut 1) and a
##      door into Study 1 (cut 3).
## Reserved for later phases (markers only): the power / security puzzle in
## the electrical room, the pump puzzle, escape 2 (the storm drain, sealed by
## a grate) and escape 3 (the main entrance, under a security lockdown).

const VERSION := "x1"

## Basement floor (top surface), and the slab under the existing ground floor.
const BF := -4.0
const SLAB_BOTTOM := -0.2
const FLOOR_T := 0.2
const WALL_T := 0.3
const GROUND_WALL_TOP := 4.2
const RAIL := 1.1
const DOOR_HEIGHT := 2.6

## The group the level's navmesh is baked from (the NavigationRegion3D and
## the expansion's Geometry node are in it; see bake_navmesh.gd).
const NAV_GROUP := &"expanded_navigation_source"

## Render layers and light masks, as the existing level's (ground 4, upper 8)
## plus one for the basement, so basement lights only light the basement.
const LAYER_GROUND := 4
const LAYER_BASEMENT := 16
const LIGHT_MASK_GROUND := 5      # actors (1) + ground (4), as the existing ground lights
const LIGHT_MASK_BASEMENT := 17   # actors (1) + basement (16)

const ZONES := [
	{"id": "G", "name": "Basement / Service Network", "floor": "basement",
		"areas": [
			{"name": "Service Tunnel", "rect": [-44, -27, 46, -23], "y": BF},
			{"name": "West Service Stair", "rect": [-44, -23, -36, 0], "y": BF},
			{"name": "Maintenance Bay", "rect": [-28, -23, -20, -17], "y": BF},
			{"name": "Pump Room", "rect": [-7, -23, 7, -14], "y": BF},
			{"name": "Storm Drain", "rect": [-2, -40, 2, -27], "y": BF},
			{"name": "East Service Stair", "rect": [36, -23, 46, -6], "y": BF},
			{"name": "Cable Bay", "rect": [42.2, -23, 46, -18], "y": BF}]},
	{"id": "D", "name": "Service and Electrical Rooms (extension)", "floor": "ground",
		"areas": [{"name": "Electrical Room", "rect": [36, -28, 46, -18], "y": 0.0}]},
]

## Walkable slabs [x0, z0, x1, z1] with their top at y. They overlap the walls
## and each other a little so there are no seams.
const FLOORS := [
	{"name": "WestLanding", "zone": "G", "rect": [-44, -12, -35.9, 0], "y": 0.0, "look": "floor_concrete"},
	{"name": "ElectricalRoom", "zone": "D", "rect": [35.9, -28, 46, -18], "y": 0.0, "look": "floor_service"},
	{"name": "Tunnel", "zone": "G", "rect": [-44, -27.15, 46, -23], "y": BF, "look": "floor_concrete"},
	{"name": "WestBasement", "zone": "G", "rect": [-44, -23, -35.85, -12], "y": BF, "look": "floor_concrete"},
	{"name": "EastBasement", "zone": "G", "rect": [36.15, -23, 46, -6], "y": BF, "look": "floor_concrete"},
	{"name": "PumpRoom", "zone": "G", "rect": [-7.15, -23, 7.15, -13.85], "y": BF, "look": "floor_service"},
	{"name": "MaintenanceBay", "zone": "G", "rect": [-28.15, -23, -19.85, -16.85], "y": BF, "look": "floor_concrete"},
	{"name": "StormDrain", "zone": "G", "rect": [-2.15, -40.15, 2.15, -27], "y": BF, "look": "stone"},
]

## Walls: axis-aligned centre lines a → b, WALL_T thick, from y0 to y1.
## Basement walls run up to the underside of the existing ground slab.
const _B0 := BF - FLOOR_T
const WALLS := [
	# West service stair annex (outside the main stacks' west wall).
	{"name": "WestAnnexWest", "zone": "G", "a": [-44, -27.15], "b": [-44, 0.15], "y0": _B0, "y1": GROUND_WALL_TOP},
	{"name": "WestAnnexNorth", "zone": "G", "a": [-44, -27], "b": [-36, -27], "y0": SLAB_BOTTOM, "y1": GROUND_WALL_TOP},
	{"name": "WestAnnexSouth", "zone": "G", "a": [-44, 0], "b": [-36, 0], "y0": SLAB_BOTTOM, "y1": GROUND_WALL_TOP},
	{"name": "WestLandingEdge", "zone": "G", "a": [-44, -12], "b": [-36, -12], "y0": _B0, "y1": SLAB_BOTTOM},
	{"name": "WestLandingRail", "zone": "G", "a": [-40.35, -12], "b": [-36, -12], "y0": SLAB_BOTTOM, "y1": RAIL},
	{"name": "WestRampSide", "zone": "G", "a": [-40.35, -22], "b": [-40.35, -12], "y0": _B0, "y1": RAIL},
	{"name": "WestBasementEast", "zone": "G", "a": [-36, -23], "b": [-36, -12], "y0": _B0, "y1": SLAB_BOTTOM},
	# Service tunnel (under the north side of the building).
	{"name": "TunnelNorthWest", "zone": "G", "a": [-44, -27], "b": [-2, -27], "y0": _B0, "y1": SLAB_BOTTOM},
	{"name": "TunnelNorthEast", "zone": "G", "a": [2, -27], "b": [46, -27], "y0": _B0, "y1": SLAB_BOTTOM},
	{"name": "TunnelSouthA", "zone": "G", "a": [-36, -23], "b": [-25, -23], "y0": _B0, "y1": SLAB_BOTTOM},
	{"name": "TunnelSouthB", "zone": "G", "a": [-23, -23], "b": [-1, -23], "y0": _B0, "y1": SLAB_BOTTOM},
	{"name": "TunnelSouthC", "zone": "G", "a": [1, -23], "b": [36.3, -23], "y0": _B0, "y1": SLAB_BOTTOM},
	# Maintenance bay (door x -25…-23) and pump room (door x -1…1) off the tunnel.
	{"name": "BayWest", "zone": "G", "a": [-28, -23], "b": [-28, -17], "y0": _B0, "y1": SLAB_BOTTOM},
	{"name": "BayEast", "zone": "G", "a": [-20, -23], "b": [-20, -17], "y0": _B0, "y1": SLAB_BOTTOM},
	{"name": "BaySouth", "zone": "G", "a": [-28, -17], "b": [-20, -17], "y0": _B0, "y1": SLAB_BOTTOM},
	{"name": "PumpWest", "zone": "G", "a": [-7, -23], "b": [-7, -14], "y0": _B0, "y1": SLAB_BOTTOM},
	{"name": "PumpEast", "zone": "G", "a": [7, -23], "b": [7, -14], "y0": _B0, "y1": SLAB_BOTTOM},
	{"name": "PumpSouth", "zone": "G", "a": [-7, -14], "b": [7, -14], "y0": _B0, "y1": SLAB_BOTTOM},
	# Storm drain (north from the tunnel, outside the building).
	{"name": "DrainWest", "zone": "G", "a": [-2, -40], "b": [-2, -27], "y0": _B0, "y1": SLAB_BOTTOM},
	{"name": "DrainEast", "zone": "G", "a": [2, -40], "b": [2, -27], "y0": _B0, "y1": SLAB_BOTTOM},
	{"name": "DrainEnd", "zone": "G", "a": [-2, -40], "b": [2, -40], "y0": _B0, "y1": SLAB_BOTTOM},
	# East annex: electrical room (ground) over the east service stair and cable bay.
	{"name": "EastAnnexNorth", "zone": "D", "a": [36, -28], "b": [46, -28], "y0": SLAB_BOTTOM, "y1": GROUND_WALL_TOP},
	{"name": "EastAnnexEast", "zone": "D", "a": [46, -28.15], "b": [46, -5.85], "y0": _B0, "y1": GROUND_WALL_TOP},
	{"name": "EastAnnexSouth", "zone": "D", "a": [36, -6], "b": [46, -6], "y0": _B0, "y1": GROUND_WALL_TOP},
	{"name": "ElectricalSouth", "zone": "D", "a": [36, -18], "b": [42.5, -18], "y0": SLAB_BOTTOM, "y1": GROUND_WALL_TOP},
	{"name": "EastRampSide", "zone": "G", "a": [42.35, -18], "b": [42.35, -8], "y0": _B0, "y1": RAIL},
	{"name": "EastBasementWest", "zone": "G", "a": [36.3, -23], "b": [36.3, -6], "y0": _B0, "y1": SLAB_BOTTOM},
]

## Stairs: ramps between the ground floor and the basement, 3.35 m wide
## (from the annex wall to the ramp's side wall), 4 m down over 10 m (21.8°).
## "top" is the ground end (y 0), "bottom" the basement end (y BF).
const RAMPS := [
	{"name": "WestServiceStair", "zone": "G", "x0": -43.85, "x1": -40.5, "z_top": -12.0, "z_bottom": -22.0},
	{"name": "EastServiceStair", "zone": "G", "x0": 42.5, "x1": 45.85, "z_top": -18.0, "z_bottom": -8.0},
]
const RAMP_T := 0.3
const RAMP_FILLER_STEPS := 10

## Cover with collision: "low" hides a crouched player, "full" a standing one.
const COVER := [
	{"name": "AlcoveCrate", "zone": "G", "rect": [-38.9, -16.6, -37.1, -15.0], "y": BF, "h": 1.2, "look": "crate"},
	{"name": "BayCrate", "zone": "G", "rect": [-27.6, -21.0, -26.0, -19.4], "y": BF, "h": 1.2, "look": "crate"},
	{"name": "CableBayCrate", "zone": "G", "rect": [43.2, -21.8, 44.8, -20.2], "y": BF, "h": 1.2, "look": "crate_dark"},
	{"name": "TunnelCrateWest", "zone": "G", "rect": [-14.8, -26.85, -13.2, -25.3], "y": BF, "h": 1.2, "look": "crate"},
	{"name": "TunnelCrateEast", "zone": "G", "rect": [18.2, -24.7, 19.8, -23.15], "y": BF, "h": 1.2, "look": "crate"},
	{"name": "PumpMachine", "zone": "G", "rect": [-2.0, -20.2, 2.0, -17.8], "y": BF, "h": SLAB_BOTTOM - BF, "look": "steel"},   # floor to ceiling: full cover, nothing baked on top
	{"name": "ElectricalCabinets", "zone": "D", "rect": [38.0, -27.85, 44.0, -27.1], "y": 0.0, "h": 2.0, "look": "dark_metal"},
]

## Hiding spots (HidingSpot, as the existing level's): crouched behind cover.
const HIDING := [
	{"name": "Basement alcove", "zone": "G", "pos": Vector3(-38.0, BF, -14.0)},
	{"name": "Maintenance bay", "zone": "G", "pos": Vector3(-26.8, BF, -18.2)},
	{"name": "Cable bay", "zone": "G", "pos": Vector3(44.0, BF, -19.0)},
]

## Access doors (AccessDoor). Cut 2 keeps zone D behind the staff card.
const DOORS := [
	{"name": "ElectricalRoomDoor", "door_name": "Electrical Room Door", "centre": Vector3(36, 0, -23), "along_x": false,
		"width": 2.0, "key": "take_card", "key_name": "staff access card"},
]

## Seals: invisible colliders (no mesh) that keep the navmesh as it was where
## the larger bake area changes it. With geometry east of the building, the
## bake no longer treats the east wall's top (4.2 m, where the S2 stair runs
## along it at that height) as the map's edge, and the stair-top navmesh ran
## onto the wall. A 0.3 m cap on the wall top along S2, inside the existing
## decorative upper wall's volume (which already looks solid), restores it.
const SEALS := [
	{"name": "S2WallTopCap", "zone": "D", "centre": Vector3(36.0, 4.35, -1.0), "size": Vector3(0.3, 0.3, 10.3)},
]

## The storm drain's grate: solid, closed for now (escape 2, reserved).
const GRATE := {"name": "StormDrainGrate", "centre": Vector3(0, BF, -37.0), "width": 3.7, "height": 3.6}

## Visual only (no collision): basement ceilings under open space or annexes, and the annex roofs.
const CEILINGS := [
	{"rect": [-36, -27, 36.3, -23], "y": -0.25},   # tunnel, under the building's slab
	{"rect": [36.3, -27, 46, -18], "y": -0.25},    # tunnel's east end and the cable bay (under the electrical room)
	{"rect": [-7, -23, 7, -14], "y": -0.25},
	{"rect": [-28, -23, -20, -17], "y": -0.25},
	{"rect": [-2, -40, 2, -28], "y": -0.25},
]
const ROOFS := [
	{"rect": [-44.15, -27.15, -36, 0.15], "y": GROUND_WALL_TOP},
	{"rect": [36, -28.15, 46.15, -5.85], "y": GROUND_WALL_TOP},
]

## Lights: the existing scenes/props/ceiling_light.tscn, at floor level "pos"
## (its lamp hangs 3.1 m above; basement lamps hang under the 3.6 m ceiling).
const LIGHTS := [
	{"pos": Vector3(-40, 0, -6), "basement": false},
	{"pos": Vector3(41, 0, -23), "basement": false},
	{"pos": Vector3(39, 0, -12), "basement": false},
	{"pos": Vector3(-40, BF, -25), "basement": true},
	{"pos": Vector3(-28, BF, -25), "basement": true},
	{"pos": Vector3(-16, BF, -25), "basement": true},
	{"pos": Vector3(-4, BF, -25), "basement": true},
	{"pos": Vector3(8, BF, -25), "basement": true},
	{"pos": Vector3(20, BF, -25), "basement": true},
	{"pos": Vector3(32, BF, -25), "basement": true},
	{"pos": Vector3(42, BF, -25), "basement": true},
	{"pos": Vector3(-38, BF, -17), "basement": true},
	{"pos": Vector3(-24, BF, -20), "basement": true},
	{"pos": Vector3(-4.5, BF, -18.5), "basement": true},
	{"pos": Vector3(0, BF, -33), "basement": true},
	{"pos": Vector3(39, BF, -15), "basement": true},
	{"pos": Vector3(39, BF, -9), "basement": true},
]
## Basement lamps hang this much lower than ground ones (the ceiling is 3.6 m).
const BASEMENT_LAMP_DROP := 0.45

## Header colours over the three cut doorways, on both faces (decoration).
const DOOR_HEADERS := [
	{"name": "WestServiceDoor", "x": -36.0, "z": -9.0, "width": 2.0, "look": "header"},
	{"name": "ElectricalRoomDoor", "x": 36.0, "z": -23.0, "width": 2.0, "look": "restricted"},
	{"name": "Study1StacksDoor", "x": -12.0, "z": -21.0, "width": 2.0, "look": "header"},
]

## Signs (Label3D, no collision), as the existing level's: text 3.05 m up on
## the ground floor, 2.6 m in the basement; facing in degrees about y.
const SIGNS := [
	{"text": "SERVICE STAIR ↓", "pos": Vector3(-35.83, 3.05, -9.0), "facing": 90.0},
	{"text": "ELECTRICAL · STAFF CARD", "pos": Vector3(35.83, 3.05, -23.0), "facing": -90.0, "red": true},
	{"text": "STUDY 1", "pos": Vector3(-12.17, 3.05, -21.0), "facing": -90.0},
	{"text": "STACKS", "pos": Vector3(-11.83, 3.05, -21.0), "facing": 90.0},
	{"text": "PUMP ROOM", "pos": Vector3(0.0, BF + 2.75, -22.83), "facing": 180.0},
	{"text": "STORM DRAIN · SEALED", "pos": Vector3(0.0, BF + 2.75, -36.9), "facing": 0.0, "red": true},
	{"text": "SERVICE STAIR ↑ ELECTRICAL", "pos": Vector3(45.83, BF + 2.75, -12.0), "facing": -90.0},
	{"text": "SERVICE STAIR ↑ STACKS", "pos": Vector3(-43.83, BF + 2.75, -24.5), "facing": 90.0},
]

## Reserved spaces for later phases (markers under Layout, shown with F3).
const RESERVED := [
	{"name": "PowerSecurityPuzzle", "text": "RESERVED · power / security puzzle", "pos": Vector3(41, 0, -26)},
	{"name": "PumpPuzzle", "text": "RESERVED · pump puzzle", "pos": Vector3(0, BF, -16)},
	{"name": "Escape2StormDrain", "text": "ESCAPE 2 (reserved) · storm drain grate", "pos": Vector3(0, BF, -36)},
	{"name": "Escape3MainEntrance", "text": "ESCAPE 3 (reserved) · main entrance, security lockdown", "pos": Vector3(0, 0, 29)},
	{"name": "Escape1LoadingDock", "text": "ESCAPE 1 · loading dock (existing mission exit)", "pos": Vector3(34.6, 0, 24)},
]

## Points for the tests: where each new area is walked to.
const PROBES := {
	"stacks_cross_aisle": Vector3(-33.5, 0, -9),
	"west_landing": Vector3(-39, 0, -6),
	"west_basement": Vector3(-42, BF, -25),
	"basement_alcove": Vector3(-38, BF, -18),
	"maintenance_bay": Vector3(-24, BF, -19),
	"tunnel_middle": Vector3(-10, BF, -25),
	"pump_room": Vector3(-4, BF, -16),
	"storm_drain": Vector3(0, BF, -32),
	"east_tunnel_end": Vector3(40, BF, -25),
	"cable_bay": Vector3(44, BF, -19),
	"east_basement": Vector3(39, BF, -10),
	"electrical_room": Vector3(40, 0, -23),
	"book_processing": Vector3(33, 0, -23),
	"study_1": Vector3(-9, 0, -21),
	"stacks_by_study": Vector3(-14, 0, -21),
}
## Points that must stay unreachable: beyond the drain's grate, inside walls, outside.
const SEALED := {
	"beyond_grate": Vector3(0, BF, -38.8),
	"outside_west": Vector3(-48, 0, -8),
	"outside_east": Vector3(50, 0, -15),
	"outside_north": Vector3(0, 0, -44),
	"under_the_lobby": Vector3(0, BF, 18),
}
