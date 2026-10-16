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
##
## Phase 3 (x2, stamina and inventory): a provisional set of carried items,
## two storage shelves (the only places items can be left or swapped) and two
## clue documents in the new areas, so the mechanics can be played; the
## electrical room door now checks the carried staff card (key_item). Real
## tool-kit mechanisms and the clue texts come with the Phase 4 puzzles.
##
## Phase 4 (x3, puzzles, journal and objectives): the mission becomes a graph
## (see MISSION_OBJECTIVES). Mandatory: the staff card, the tool kit, the
## electrical panel cover (tool kit), the breaker panel (power), the vault
## keypad (code, security alarm), the manuscript, an escape (loading dock or
## storm drain). Optional: the pump (opens the storm drain), the security
## locker, the archive back gate shortcut. Clues: the wiring chart, the
## archivist's memo with the lobby plaque, the pump room log, the night rota.
## Placed as gameplay only (no geometry, collision or navmesh change).
##
## Phase 5 (x4, security systems): three circuits in the PowerNetwork
## (archive access = the breaker puzzle, surveillance, service exit), two
## circuit switches in the electrical room, four security cameras on the
## surveillance circuit (SECURITY below). The basement guard and the guards'
## expanded_security flag are written into expanded_library.tscn by
## tools/expanded/expansion/security_x4.py.
##
## Phase 6 (x5, escape routes and checkpoints): three escape routes, each with
## its own prerequisites, all needing the manuscript (ESCAPES below):
##   A  the main entrance: it locks behind the player (night lockdown); the
##      security master badge (in the Office 1 locker) and a 4 s override at
##      the lobby badge reader open it; a lobby camera watches the reader.
##   B  the loading dock: the shutter release freed with the tool kit, SERVICE
##      EXIT power, then the shutter control's OPEN button.
##   C  the hidden maintenance passage: a false wall panel in the tunnel's
##      north gap (found through the culvert access plan in the maintenance
##      bay), then the pump drains the culvert and clears the storm drain grate.
## Each exit is walked through (a trigger past the door). The dock exit's
## properties and the guards' checkpoint_snapshot flag are written into
## expanded_library.tscn by tools/expanded/expansion/escape_x5.py.

const VERSION := "x5"

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
		"width": 2.0, "key": "take_card", "key_item": "staff_card", "key_name": "staff access card"},
	# Phase 4: the existing vault doorway (archive hall → vault, upper floor) gets a door the keypad opens.
	{"name": "VaultDoor", "door_name": "Vault Door", "centre": Vector3(28, 4.5, -21), "along_x": false,
		"width": 2.0, "key": "open_vault", "key_name": "vault code"},
	# Phase 6 (escape C): a false wall panel in the tunnel's existing north gap
	# (x -2…2, opposite the pump room door), full height, hidden until the
	# culvert access plan is read; then E works its latch.
	{"name": "MaintenancePanel", "door_name": "Maintenance Panel", "centre": Vector3(0, BF, -27), "along_x": true,
		"width": 4.0, "key": "", "key_name": "hidden latch", "height": SLAB_BOTTOM - BF, "hidden_until": "culvert_access_plan",
		"prompt": "Work the hidden latch (maintenance panel)"},
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
	{"name": "Escape2StormDrain", "text": "ESCAPE C · hidden maintenance passage → storm drain", "pos": Vector3(0, BF, -36)},
	{"name": "Escape3MainEntrance", "text": "ESCAPE A · main entrance (lockdown, badge reader)", "pos": Vector3(0, 0, 29)},
	{"name": "Escape1LoadingDock", "text": "ESCAPE B · loading dock (shutter)", "pos": Vector3(34.6, 0, 24)},
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


## Phase 3 (x2): provisional carried items (ItemPickup, ids from ItemCatalog),
## lying on top of the basement crates (crate top = BF + 1.2).
const ITEMS := [
	{"name": "ToolKit", "item": "toolkit", "zone": "G", "pos": Vector3(-26.8, BF + 1.2, -20.2), "yaw": 20.0, "objective": "find_toolkit"},
	{"name": "BottleTunnel", "item": "bottle", "zone": "G", "pos": Vector3(-14.0, BF + 1.2, -26.1), "yaw": 0.0},
	{"name": "HardbackTunnel", "item": "hardback", "zone": "G", "pos": Vector3(19.0, BF + 1.2, -23.9), "yaw": 30.0},
	{"name": "BottleCableBay", "item": "bottle", "zone": "G", "pos": Vector3(44.0, BF + 1.2, -21.0), "yaw": 0.0},
	# Phase 4: inside the Office 1 security locker (appears when it is opened).
	{"name": "LockerBottle", "item": "bottle", "zone": "E", "pos": Vector3(-5.0, 4.5, -22.4), "yaw": 0.0, "available": false},
	# Phase 6: the credential for escape A, also in the locker.
	{"name": "LockerBadge", "item": "security_badge", "zone": "E", "pos": Vector3(-5.0, 4.5, -21.7), "yaw": 0.0, "available": false},
]
## Storage shelves (ItemStorage): wall-mounted, no collision (nothing baked, no
## route changed). "pos" is the shelf surface, 1 m above the floor; "facing"
## turns the shelf's front (local +Z) away from the wall (degrees about Y).
const STORAGE := [
	{"name": "MaintenanceShelf", "title": "Maintenance shelf", "zone": "G", "pos": Vector3(-20.36, BF + 1.0, -20.0), "facing": -90.0},
	{"name": "ElectricalShelf", "title": "Electrical room shelf", "zone": "D", "pos": Vector3(39.5, 1.0, -18.36), "facing": 180.0},
]
## Clue documents (DocumentPickup): clipboards on walls at 1.4 m. Provisional
## texts; Phase 4 gives them their puzzle clues.
const DOCUMENTS := [
	{"name": "PumpRoomLog", "id": "pump_room_log", "title": "Pump room log", "zone": "G",
		"pos": Vector3(6.83, BF + 1.4, -17.0), "facing": -90.0, "discovers": "drain_culvert",
		"text": "Night log, pump room.\nThe culvert floods every storm, and the storm drain grate jams shut until it is pumped dry.\nTo drain it: free the crank first (it seizes; use the tool kit), open the two outer valves, keep the middle valve SHUT, then pull START. Any other setting stalls the pump with a bang you can hear upstairs.\n— Facilities, night shift"},
	{"name": "ElectricalNotice", "id": "electrical_notice", "title": "Electrical room notice", "zone": "D",
		"pos": Vector3(45.83, 1.4, -24.0), "facing": -90.0,
		"text": "NOTICE TO STAFF\nThe archive sub-panel is behind the screwed-on cover (the tool kit is in the maintenance bay downstairs).\nThe wiring chart is pinned up in Book Processing. A wrong breaker setting trips the main, loudly.\n— Library facilities"},
	# Phase 4 clues.
	{"name": "WiringChart", "id": "wiring_chart", "title": "Wiring chart", "zone": "D",
		"pos": Vector3(26.0, 1.4, -27.83), "facing": 0.0,
		"text": "WIRING CHART · ARCHIVE SUB-PANEL (electrical room)\nA3 VAULT LOCK feeds the vault keypad. It only holds while A4 SECURITY GRID is live (the lock reports to security).\nA1 ARCHIVE LIGHTS shares A3's feed: with A1 off, the vault lock browns out.\nA2 SUMP PUMP: never energise A2 from this panel while the basement is wet. It trips the main.\nSet the breakers first, then engage MAIN.\n— Facilities"},
	{"name": "ArchivistMemo", "id": "archivist_memo", "title": "Archivist's memo", "zone": "E",
		"pos": Vector3(11.83, 5.9, -20.0), "facing": -90.0,
		"text": "MEMO · Head archivist\nAfter the audit, security reset the vault keypad. The new code is the year this library was founded, with its digits in reverse order.\nThe year is on the plaque in the lobby if you forget it. Do not write the code itself down anywhere!\n— M. Ortega"},
	{"name": "LobbyPlaque", "id": "lobby_plaque", "title": "Foundation plaque", "zone": "A", "kind": "clue", "model": "plaque",
		"pos": Vector3(-11.83, 1.7, 20.0), "facing": 90.0,
		"display": "CAMPUS LIBRARY\nFOUNDED 1962\nKnowledge kept, knowledge shared",
		"text": "A brass plate in the lobby: Campus Library, founded 1962."},
	{"name": "NightRota", "id": "night_rota", "title": "Night security rota", "zone": "E",
		"pos": Vector3(5.83, 5.9, -17.0), "facing": -90.0, "discovers": "security_locker",
		"text": "NIGHT SECURITY ROTA\nOkoro: 21:00\nLindqvist: 03:00\nBrand: 06:00\nSecurity locker (Office 1): the combination is the last digit of each start hour, in rota order."},
	{"name": "PatrolNotes", "id": "patrol_notes", "title": "Patrol notes", "zone": "E", "available": false,
		"pos": Vector3(-5.83, 5.75, -23.3), "facing": 90.0,
		"text": "PATROL NOTES (security locker)\nEvery guard keeps to a fixed loop and stops briefly at its corners: wait for the pause, then move.\nOne guard walks the whole basement tunnel. An alarm draws whoever hears it to the spot. Be somewhere else by then.\nThe master badge in this locker overrides the night lockdown at the main entrance reader. The override takes a few seconds and the lobby camera watches the reader.\n— Night shift"},
	# Phase 6 (escape C): the clue to the hidden maintenance panel.
	{"name": "CulvertAccessPlan", "id": "culvert_access_plan", "title": "Culvert access plan", "zone": "G",
		"pos": Vector3(-23.5, BF + 1.4, -17.17), "facing": 180.0,
		"text": "FACILITIES · CULVERT ACCESS\nAfter the 2019 flood the culvert access opposite the pump room door was boarded over with a false wall panel. Its latch still works: press the panel's right-hand edge.\nBeyond it the storm drain runs out under the grounds, but the grate at its end jams while the culvert is flooded. Pump it dry first.\n— Facilities"},
]

## Phase 4 (x3): the puzzles and their supports, built under Expansion/Gameplay/Mission.
## Answers live only here, in the scene and in the clues: never in objective hints.
const MISSION := {
	"panel_cover": {"name": "ElectricalPanelCover", "pos": Vector3(41.0, 1.35, -26.9), "facing": 0.0, "zone": "D",
		"mechanism_name": "Electrical panel cover", "action_text": "Unscrew the cover", "objective": "open_panel",
		"size": Vector3(1.05, 0.7, 0.05)},
	"breakers": {"name": "BreakerPanel", "pos": Vector3(41.0, 1.35, -27.02), "facing": 0.0, "zone": "D",
		"circuit": "archive_access", "solution": [true, false, true, true], "objective": "restore_power"},
	"vault_keypad": {"name": "VaultKeypad", "pos": Vector3(27.83, 5.85, -19.3), "facing": -90.0, "zone": "F",
		"code": "2691", "power": "archive_access", "alarm": true, "attempts": 3, "lockout": 20.0,
		"objective": "open_vault", "door": "VaultDoor", "title": "Vault keypad"},
	"locker": {"name": "SecurityLocker", "pos": Vector3(-5.83, 5.85, -21.4), "facing": 90.0, "zone": "E",
		"code": "136", "power": "", "alarm": false, "attempts": 3, "lockout": 10.0,
		"objective": "security_locker", "reveal": ["Items/LockerBottle", "Items/LockerBadge", "Documents/PatrolNotes"], "title": "Security locker",
		"cabinet": {"centre": Vector3(-5.6, 5.4, -22.4), "size": Vector3(0.45, 1.8, 0.9)}},
	"pump_crank": {"name": "PumpCrank", "pos": Vector3(-3.4, BF + 1.0, -14.27), "facing": 180.0, "zone": "G",
		"mechanism_name": "Pump crank", "action_text": "Free the seized crank", "size": Vector3(0.4, 0.4, 0.12)},
	"pump": {"name": "PumpControl", "pos": Vector3(0.0, BF + 1.2, -14.3), "facing": 180.0, "zone": "G",
		"solution": [true, false, true], "objective": "drain_culvert"},
	"drain_exit": {"name": "StormDrainExit", "pos": Vector3(0.0, BF + 1.2, -35.8), "zone": "G",
		"size": Vector3(3.6, 2.4, 1.0)},
}

## Phase 4 (x3): the Expanded Library's objectives (ObjectiveManager graph mode),
## written into expanded_library.tscn by tools/expanded/expansion/mission_x3.py.
const MISSION_OBJECTIVES := [
	{"id": "enter_library", "title": "Enter the library", "hint": "Go in through the main entrance.",
		"done": "Inside. The main doors locked behind you (night lockdown)"},
	{"id": "take_card", "requires": ["enter_library"], "title": "Take a staff access card",
		"hint": "Staff offices, upper floor: up the main stair (or the stacks stair), through the staff wing.",
		"done": "Staff access card taken: staff doors open while you carry it"},
	{"id": "find_toolkit", "requires": ["enter_library"], "title": "Find the tool kit",
		"hint": "Somewhere in the basement maintenance areas. The west service door in the main stacks leads down.",
		"done": "Tool kit found"},
	{"id": "open_panel", "requires": ["find_toolkit"], "title": "Open the archive power panel",
		"hint": "In the electrical room (east annex). Its cover is screwed shut.",
		"done": "Panel cover off: the breakers are exposed"},
	{"id": "restore_power", "requires": ["open_panel"], "title": "Restore power to the vault",
		"hint": "Set the breakers, then engage MAIN. Facilities pinned up a wiring chart somewhere in the service wing.",
		"done": "The archive vault has power"},
	{"id": "open_vault", "requires": ["take_card", "restore_power"], "title": "Open the archive vault",
		"hint": "The vault keypad is in the archive (through the Archive Front Gate, upper floor). The head archivist left a reminder of the code.",
		"done": "Vault open"},
	{"id": "take_manuscript", "requires": ["open_vault"], "title": "Retrieve the rare manuscript",
		"hint": "On the pedestal inside the vault.",
		"done": "Manuscript retrieved. Now get out: the main entrance, the loading dock or a hidden way"},
	{"id": "escape", "requires": ["take_manuscript"], "title": "Escape with the manuscript",
		"hint": "Three ways out, each needing something different: the main entrance (locked down; security has a master badge), the loading dock (its shutter needs power) or a hidden maintenance passage in the basement.",
		"done": "Escaped"},
	{"id": "unlock_shortcut", "requires": ["take_card"], "optional": true, "title": "Unlock the archive back gate (shortcut)",
		"hint": "East side of the archive hall. It only opens from inside the archive.",
		"done": "Back gate open: the staff stair leads down to the loading dock"},
	{"id": "drain_culvert", "optional": true, "hidden": true, "title": "Drain the storm culvert",
		"hint": "Pump room, basement. The pump room log explains the valves.",
		"done": "Culvert drained: the storm drain is a way out"},
	{"id": "security_locker", "optional": true, "hidden": true, "title": "Open the security locker",
		"hint": "Office 1, upper floor. The night rota mentions the combination.",
		"done": "Security locker open"},
]


## Phase 5 (x4): switches (CircuitSwitch, on the electrical room cabinets) and
## cameras (SecurityCamera: "pos" is the mount, "look" a point it faces at rest).
const UY := 4.5
const SECURITY := {
	"switches": [
		{"name": "SurveillanceSwitch", "circuit": "surveillance", "title": "SURVEILLANCE", "pos": Vector3(38.8, 1.35, -27.02),
			"on": "Surveillance power ON: the cameras are watching again.",
			"off": "Surveillance power OFF: the cameras go dark. The guards are not affected."},
		{"name": "ServiceExitSwitch", "circuit": "service_exit", "title": "SERVICE EXIT", "pos": Vector3(43.2, 1.35, -27.02),
			"on": "Service power ON: the loading dock shutter has power.",
			"off": "Service power OFF: the loading dock shutter is dead.",
			"reboots": "surveillance", "lock": 30.0,
			"reboot": "Service ON: dock powered. Security rebooted: cameras ON, switch locked 30 s."},
	],
	"cameras": [
		{"name": "CameraStaffCorridor", "title": "staff corridor", "zone": "E", "pos": Vector3(11.6, UY + 3.0, -13.6), "look": Vector3(-6.0, UY, -9.0)},
		{"name": "CameraArchiveHall", "title": "archive hall", "zone": "F", "pos": Vector3(27.6, UY + 3.0, -6.4), "look": Vector3(16.0, UY, -17.0)},
		{"name": "CameraLoadingDock", "title": "loading dock", "zone": "D", "pos": Vector3(35.6, 3.5, 12.4), "look": Vector3(22.0, 0.0, 25.0)},
		{"name": "CameraTunnel", "title": "service tunnel", "zone": "G", "pos": Vector3(12.0, SLAB_BOTTOM - 0.5, -23.25), "look": Vector3(-8.0, BF, -25.0)},
		# Phase 6: a fixed camera looking down at the main entrance's badge reader
		# (escape A) only: no sweep, a narrow view, so the doorway and the spot
		# behind the entrance screen stay out of it.
		{"name": "CameraLobby", "title": "main entrance", "zone": "A", "pos": Vector3(2.9, 3.4, 26.0), "look": Vector3(2.9, 0.6, 27.8),
			"fov": 40.0, "sweep": 0.0, "range": 6.0},
	],
	"labels": {"switch_board": Vector3(41.0, 2.25, -27.0)},
}



## Phase 6 (x5): the escape routes (Expansion/Gameplay/Escape). Each exit is an
## ExitDoor in walk-through mode: it opens when its conditions hold and the
## player escapes by walking into its trigger with the manuscript. Triggers sit
## just past the door, so a closed door keeps them out of reach.
const ESCAPES := {
	"main_entrance": {"name": "MainEntranceExit", "route": "main_entrance", "route_name": "Main entrance", "zone": "A",
		"pos": Vector3(0.0, 1.2, 27.5), "size": Vector3(4.0, 2.4, 0.6),
		"panel": {"centre": Vector3(0.0, 1.5, 28.0), "size": Vector3(4.0, 3.0, 0.2)},
		"trigger": {"centre": Vector3(0.0, 1.2, 28.85), "size": Vector3(4.0, 2.4, 1.2)},
		"armed_after": "enter_library",
		# The lockdown is announced by enter_library's "done" text (MISSION_OBJECTIVES), so it isn't hidden by it.
		"lockdown": "",
		"locked_sign": "MAIN ENTRANCE · NIGHT LOCKDOWN", "open_sign": "MAIN ENTRANCE · OPEN",
		"locked_prompt": "Main entrance (night lockdown)",
		"unlock_reason": "The main entrance is under the night lockdown. Override it at the badge reader (security master badge)."},
	"badge_reader": {"name": "BadgeReader", "pos": Vector3(2.9, 1.3, 27.8), "facing": 180.0, "zone": "A", "hold": 4.0},
	"dock_release": {"name": "DockShutterRelease", "pos": Vector3(35.83, 1.1, 21.4), "facing": -90.0, "zone": "D",
		"mechanism_name": "Dock shutter release", "action_text": "Free the jammed release", "size": Vector3(0.5, 0.4, 0.1)},
	"dock_shutter": {"name": "DockShutterControl", "pos": Vector3(35.83, 1.3, 26.4), "facing": -90.0, "zone": "D"},
	"dock_trigger": {"name": "DockExitTrigger", "centre": Vector3(36.4, 1.2, 24.0), "size": Vector3(0.7, 2.4, 3.0)},
	"drain_trigger": {"name": "Trigger", "offset": Vector3(0.0, 0.0, -2.8), "size": Vector3(3.6, 2.4, 1.6)},
}
