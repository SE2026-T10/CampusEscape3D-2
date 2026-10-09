extends RefCounted

## Expanded Library — graybox layout data (version v0).
##
## The single source of truth for the graybox: the builder
## (tools/expanded/build_expanded_graybox.gd) turns it into
## scenes/level/expanded_library.tscn, the design-map tool
## (tools/expanded/draw_layout.gd) draws the top-down plans from it, and the
## tests (tests/expanded_graybox_tests.gd) read the planned locations from it.
##
## Units are metres. x points east, z points south (north = −z is "up" on the
## maps). Rectangles are [x0, z0, x1, z1]. Ground-floor geometry stands on
## y = 0; upper-floor geometry on y = UPPER_Y.
##
## Dimensions follow the existing player (capsule r 0.35 m, 1.8 m tall) and
## guards (r 0.4 m, 1.8 m tall; navmesh agent r 0.5 m, height 1.75 m):
##   - doors 2 m wide (≥ 1 m of navmesh), arches 3–4 m, door headers at 2.6 m
##   - corridors ≥ 3 m, shelf aisles 2.4 m
##   - stairs are 3 m wide ramps rising 4.5 m over 10 m (24°): the player has
##     no step-up, and the navmesh accepts slopes up to 45°

const VERSION := "v1"

const UPPER_Y := 4.5
const SLAB_THICKNESS := 0.3
const GROUND_FLOOR_THICKNESS := 0.2
const WALL_THICKNESS := 0.3
const GROUND_WALL_HEIGHT := 4.2   # up to the underside of the upper slab
const UPPER_WALL_HEIGHT := 3.5
const RAILING_HEIGHT := 1.1
const DOOR_HEIGHT := 2.6
const RAMP_THICKNESS := 0.3
const RAMP_FILLER_STEPS := 10     # stepped blocks that seal the space under a ramp
const HANDRAIL_HEIGHT := 1.0
const HANDRAIL_PANELS := 5        # the balustrade on a ramp's open side, in vertical steps (see the builder)


## Where the player starts (the porch outside the main entrance), facing north.
const SPAWN := Vector3(0, 0.05, 32)

## The six major zones. "areas" are named sub-areas (rooms) shown on the maps.
const ZONES := [
	{"id": "A", "name": "Entrance & Lobby", "floor": "ground", "colour": Color(0.55, 0.62, 0.70),
		"rects": [[-12, 10, 12, 28], [-5, 28, 5, 34]],
		"areas": [{"name": "Lobby", "rect": [-12, 10, 12, 28]}, {"name": "Porch", "rect": [-5, 28, 5, 34]}]},
	{"id": "B", "name": "Main Book Stacks", "floor": "ground", "colour": Color(0.62, 0.52, 0.40),
		"rects": [[-36, -28, -12, 28]],
		"areas": [{"name": "Main Stacks", "rect": [-36, -28, -12, 10]}, {"name": "Browsing Hall", "rect": [-36, 10, -12, 28]}]},
	{"id": "C", "name": "Reading Rooms & Study Wing", "floor": "ground", "colour": Color(0.50, 0.64, 0.50),
		"rects": [[-12, -28, 12, 10]],
		"areas": [{"name": "Reading Hall", "rect": [-12, -14, 12, 10]},
			{"name": "Study 1", "rect": [-12, -28, -6, -14]}, {"name": "Study 2", "rect": [-6, -28, 0, -14]},
			{"name": "Study 3", "rect": [0, -28, 6, -14]}, {"name": "Study 4", "rect": [6, -28, 12, -14]}]},
	{"id": "D", "name": "Restricted Service Corridor", "floor": "ground", "colour": Color(0.66, 0.50, 0.50),
		"rects": [[12, -28, 36, 28]],
		"areas": [{"name": "Service Corridor", "rect": [12, -28, 17, 28]}, {"name": "Book Processing", "rect": [17, -28, 36, -6]},
			{"name": "Storage", "rect": [17, -6, 36, 12]}, {"name": "Loading Dock", "rect": [17, 12, 36, 28]}]},
	{"id": "E", "name": "Staff Offices & Upper Stacks", "floor": "upper", "colour": Color(0.58, 0.56, 0.72),
		"rects": [[-36, -28, 12, 10]],
		"areas": [{"name": "Upper Stacks", "rect": [-36, -28, -6, 10]}, {"name": "Staff Balcony", "rect": [-6, -8, 12, 10]},
			{"name": "Staff Corridor", "rect": [-6, -14, 12, -8]}, {"name": "Office 1", "rect": [-6, -28, 0, -14]},
			{"name": "Office 2", "rect": [0, -28, 6, -14]}, {"name": "Office 3", "rect": [6, -28, 12, -14]}]},
	{"id": "F", "name": "Restricted Archive", "floor": "upper", "colour": Color(0.74, 0.58, 0.40),
		"rects": [[12, -28, 36, -6]],
		"areas": [{"name": "Archive Hall", "rect": [12, -18, 28, -6]}, {"name": "Archive Stacks", "rect": [12, -28, 28, -18]},
			{"name": "Vault", "rect": [28, -28, 36, -18]}, {"name": "Alcove", "rect": [28, -18, 36, -12]},
			{"name": "Staff Stair Landing", "rect": [30, -12, 36, -6]}]},
]

## Walkable slabs. Ground floors are split by zone (for colour); the upper
## floor is two slabs, E and F, whose top is at UPPER_Y.
const FLOORS := [
	{"zone": "A", "floor": "ground", "rect": [-12, 10, 12, 28]},
	{"zone": "A", "floor": "ground", "rect": [-5, 28, 5, 34]},
	{"zone": "B", "floor": "ground", "rect": [-36, -28, -12, 28]},
	{"zone": "C", "floor": "ground", "rect": [-12, -28, 12, 10]},
	{"zone": "D", "floor": "ground", "rect": [12, -28, 36, 28]},
	{"zone": "E", "floor": "upper", "rect": [-36, -28, 12, 10]},
	{"zone": "F", "floor": "upper", "rect": [12, -28, 36, -6]},
]

## Walls are axis-aligned segments (centre lines) with openings. An opening is
## centred on "at" (the coordinate along the wall) and "width" wide.
## Opening types:
##   door / arch   open, with a header above DOOR_HEIGHT
##   entrance      the main entrance (open, header)
##   gate          a planned progression gate (open in the graybox, red header)
##   shortcut      a planned one-way shortcut (open in the graybox, amber header)
##   stair         the gap in an upper-floor edge where a stair arrives (no header)
##   exit          the escape door: closed by a door panel (the level stays sealed)
## kind "railing" walls are RAILING_HEIGHT tall (balcony edges).
const WALLS := [
	# --- Ground floor: outside -------------------------------------------------------
	{"floor": "ground", "zone": "A", "a": [-36, 28], "b": [36, 28],
		"openings": [{"at": 0, "width": 4, "type": "entrance", "name": "Main Entrance"}]},
	{"floor": "ground", "zone": "A", "a": [-5, 28], "b": [-5, 34]},
	{"floor": "ground", "zone": "A", "a": [5, 28], "b": [5, 34]},
	{"floor": "ground", "zone": "A", "a": [-5, 34], "b": [5, 34]},
	{"floor": "ground", "zone": "B", "a": [-36, -28], "b": [36, -28]},
	{"floor": "ground", "zone": "B", "a": [-36, -28], "b": [-36, 28]},
	{"floor": "ground", "zone": "D", "a": [36, -28], "b": [36, 28],
		"openings": [{"at": 24, "width": 3, "type": "exit", "name": "Loading Dock Exit"}]},
	# --- Ground floor: inside --------------------------------------------------------
	{"floor": "ground", "zone": "B", "a": [-12, -28], "b": [-12, 28],
		"openings": [{"at": -2, "width": 3, "type": "arch", "name": "Stacks Arch (Reading Hall)"},
			{"at": 24, "width": 3, "type": "arch", "name": "Stacks Arch (Lobby)"}]},
	{"floor": "ground", "zone": "C", "a": [-12, 10], "b": [12, 10],
		"openings": [{"at": 0, "width": 4, "type": "arch", "name": "Reading Hall Doors"}]},
	{"floor": "ground", "zone": "C", "a": [-12, -14], "b": [12, -14],
		"openings": [{"at": -9, "width": 2, "type": "door", "name": "Study 1 Door"},
			{"at": -3, "width": 2, "type": "door", "name": "Study 2 Door"},
			{"at": 3, "width": 2, "type": "door", "name": "Study 3 Door"},
			{"at": 9, "width": 2, "type": "door", "name": "Study 4 Door"}]},
	{"floor": "ground", "zone": "C", "a": [-6, -28], "b": [-6, -14]},
	{"floor": "ground", "zone": "C", "a": [0, -28], "b": [0, -14],
		"openings": [{"at": -24, "width": 2, "type": "door", "name": "Study 2–3 Door"}]},
	{"floor": "ground", "zone": "C", "a": [6, -28], "b": [6, -14]},
	{"floor": "ground", "zone": "D", "a": [12, -28], "b": [12, 28],
		"openings": [{"at": 4, "width": 2, "type": "shortcut", "name": "Service Shortcut SC1"},
			{"at": 21, "width": 2, "type": "gate", "name": "Lobby Staff Door G4"}]},
	{"floor": "ground", "zone": "D", "a": [17, -28], "b": [17, 28],
		"openings": [{"at": -17, "width": 2, "type": "door", "name": "Processing Door"},
			{"at": 2, "width": 2, "type": "door", "name": "Storage Door"},
			{"at": 20, "width": 3, "type": "door", "name": "Dock Door"}]},
	{"floor": "ground", "zone": "D", "a": [17, -6], "b": [36, -6],
		"openings": [{"at": 26, "width": 2, "type": "door", "name": "Processing–Storage Door"}]},
	{"floor": "ground", "zone": "D", "a": [17, 12], "b": [36, 12],
		"openings": [{"at": 22, "width": 3, "type": "door", "name": "Storage–Dock Door"}]},
	# --- Upper floor: edges ----------------------------------------------------------
	{"floor": "upper", "zone": "E", "a": [-36, -28], "b": [36, -28]},
	{"floor": "upper", "zone": "E", "a": [-36, -28], "b": [-36, 10]},
	{"floor": "upper", "zone": "E", "a": [-36, 10], "b": [12, 10], "kind": "railing",
		"openings": [{"at": -34.35, "width": 3, "type": "stair", "name": "S3 Top"},
			{"at": -10.35, "width": 3, "type": "stair", "name": "S1 Top"}]},
	{"floor": "upper", "zone": "E", "a": [12, -6], "b": [12, 10]},
	{"floor": "upper", "zone": "F", "a": [12, -28], "b": [12, -6],
		"openings": [{"at": -11, "width": 2, "type": "gate", "name": "Archive Front Gate G2"}]},
	{"floor": "upper", "zone": "F", "a": [12, -6], "b": [36, -6],
		"openings": [{"at": 34.35, "width": 3, "type": "stair", "name": "S2 Top"}]},
	{"floor": "upper", "zone": "F", "a": [36, -28], "b": [36, -6]},
	# --- Upper floor: inside ---------------------------------------------------------
	{"floor": "upper", "zone": "F", "a": [30, -12], "b": [30, -6],
		"openings": [{"at": -9, "width": 2, "type": "gate", "name": "Archive Back Gate G3"}]},
	{"floor": "upper", "zone": "F", "a": [30, -12], "b": [36, -12]},
	{"floor": "upper", "zone": "F", "a": [28, -28], "b": [28, -18],
		"openings": [{"at": -21, "width": 2, "type": "door", "name": "Vault Door"}]},
	{"floor": "upper", "zone": "F", "a": [28, -18], "b": [36, -18]},
	{"floor": "upper", "zone": "E", "a": [-6, -28], "b": [-6, -8],
		"openings": [{"at": -11, "width": 2, "type": "gate", "name": "Staff Door (Stacks) G1b"}]},
	{"floor": "upper", "zone": "E", "a": [-6, -8], "b": [12, -8],
		"openings": [{"at": 3, "width": 2, "type": "gate", "name": "Staff Wing Door G1a"}]},
	{"floor": "upper", "zone": "E", "a": [-6, -14], "b": [12, -14],
		"openings": [{"at": -3, "width": 2, "type": "door", "name": "Office 1 Door"},
			{"at": 3, "width": 2, "type": "door", "name": "Office 2 Door"},
			{"at": 9, "width": 2, "type": "door", "name": "Office 3 Door"}]},
	{"floor": "upper", "zone": "E", "a": [0, -28], "b": [0, -14]},
	{"floor": "upper", "zone": "E", "a": [6, -28], "b": [6, -14]},
]

## Stairs: ramps between the floors. Each rises from (z_low, y = 0) to
## (z_high, y = UPPER_Y) between x0 and x1; "open_side" is the side that is
## not against a wall (it gets a handrail). The top end meets an upper slab
## edge, so no hole is cut into the upper floor.
const STAIRS := [
	{"id": "S1", "name": "S1 Main Stair", "zone": "A", "x0": -11.85, "x1": -8.85, "z_low": 20.0, "z_high": 10.0, "open_side": "east"},
	{"id": "S2", "name": "S2 Staff Stair", "zone": "D", "x0": 32.85, "x1": 35.85, "z_low": 4.0, "z_high": -6.0, "open_side": "west"},
	{"id": "S3", "name": "S3 Stacks Stair", "zone": "B", "x0": -35.85, "x1": -32.85, "z_low": 20.0, "z_high": 10.0, "open_side": "east"},
]

## Furniture placeholders. "full" cover is taller than a standing player's
## head (1.8 m); "low" cover hides a crouched player (1.0 m) but not a
## standing one. Rects are footprints; h is the height.
const SHELF_H := 2.2
const COVER := [
	# B: main stacks — six north-south rows, cross aisle at z −11…−7.
	{"zone": "B", "floor": "ground", "kind": "shelf", "rects": [
		[-31.3, -25, -30.7, -11], [-28.3, -25, -27.7, -11], [-25.3, -25, -24.7, -11],
		[-22.3, -25, -21.7, -11], [-19.3, -25, -18.7, -11], [-16.3, -25, -15.7, -11],
		[-31.3, -7, -30.7, 6], [-28.3, -7, -27.7, 6], [-25.3, -7, -24.7, 6],
		[-22.3, -7, -21.7, 6], [-19.3, -7, -18.7, 6], [-16.3, -7, -15.7, 6]], "h": SHELF_H},
	# B: browsing hall — reading tables and one short shelf.
	{"zone": "B", "floor": "ground", "kind": "low", "rects": [
		[-25.5, 14.8, -22.5, 16.2], [-25.5, 22.3, -22.5, 23.7], [-19.5, 14.8, -16.5, 16.2], [-19.5, 22.3, -16.5, 23.7]], "h": 0.8},
	{"zone": "B", "floor": "ground", "kind": "shelf", "rects": [[-30.0, 12, -29.4, 18]], "h": SHELF_H},
	# A: lobby — circulation desk and two planters.
	{"zone": "A", "floor": "ground", "kind": "low", "rects": [[1, 15.4, 7, 16.6]], "h": 1.1},
	{"zone": "A", "floor": "ground", "kind": "low", "rects": [[-7, 13, -5, 14], [5, 25, 7, 26]], "h": 1.0},
	# C: reading hall — six tables and a low bookcase in the middle.
	{"zone": "C", "floor": "ground", "kind": "low", "rects": [
		[-7.5, -9.7, -4.5, -8.3], [-7.5, -3.7, -4.5, -2.3], [-7.5, 2.3, -4.5, 3.7],
		[4.5, -9.7, 7.5, -8.3], [4.5, -3.7, 7.5, -2.3], [4.5, 2.3, 7.5, 3.7]], "h": 0.8},
	{"zone": "C", "floor": "ground", "kind": "low", "rects": [[-2.5, -0.3, 2.5, 0.3]], "h": 1.3},
	# C: study rooms — two carrels per room against the north wall (desk + side panels).
	{"zone": "C", "floor": "ground", "kind": "carrel_desk", "rects": [
		[-11.1, -27.85, -9.9, -27.15], [-8.1, -27.85, -6.9, -27.15], [-5.1, -27.85, -3.9, -27.15], [-2.1, -27.85, -0.9, -27.15],
		[0.9, -27.85, 2.1, -27.15], [3.9, -27.85, 5.1, -27.15], [6.9, -27.85, 8.1, -27.15], [9.9, -27.85, 11.1, -27.15]], "h": 0.75},
	{"zone": "C", "floor": "ground", "kind": "carrel_panel", "rects": [
		[-11.2, -27.85, -11.1, -26.65], [-9.9, -27.85, -9.8, -26.65], [-8.2, -27.85, -8.1, -26.65], [-6.9, -27.85, -6.8, -26.65],
		[-5.2, -27.85, -5.1, -26.65], [-3.9, -27.85, -3.8, -26.65], [-2.2, -27.85, -2.1, -26.65], [-0.9, -27.85, -0.8, -26.65],
		[0.8, -27.85, 0.9, -26.65], [2.1, -27.85, 2.2, -26.65], [3.8, -27.85, 3.9, -26.65], [5.1, -27.85, 5.2, -26.65],
		[6.8, -27.85, 6.9, -26.65], [8.1, -27.85, 8.2, -26.65], [9.8, -27.85, 9.9, -26.65], [11.1, -27.85, 11.2, -26.65]], "h": 1.5},
	{"zone": "C", "floor": "ground", "kind": "low", "rects": [[2.2, -20.4, 3.8, -19.6]], "h": 0.75},  # O1 desk
	# D: processing tables, storage racks, dock crates.
	{"zone": "D", "floor": "ground", "kind": "low", "rects": [
		[20.5, -22.6, 23.5, -21.4], [20.5, -12.6, 23.5, -11.4], [27.5, -22.6, 30.5, -21.4], [27.5, -12.6, 30.5, -11.4]], "h": 0.9},
	{"zone": "D", "floor": "ground", "kind": "rack", "rects": [[20, -2, 22, 0], [20, 6, 22, 8], [26, -2, 28, 0], [26, 6, 28, 8]], "h": 2.0},
	{"zone": "D", "floor": "ground", "kind": "low", "rects": [
		[21.2, 15.2, 22.8, 16.8], [27.2, 15.2, 28.8, 16.8], [21.2, 24.2, 22.8, 25.8], [27.2, 24.2, 28.8, 25.8]], "h": 1.2},
	# E: upper stacks — five rows (the area west of the staff wing stays open
	# in front of the S1 landing), balcony tables, office desks.
	{"zone": "E", "floor": "upper", "kind": "shelf", "rects": [
		[-31.3, -25, -30.7, -12], [-27.3, -25, -26.7, -12], [-23.3, -25, -22.7, -12], [-19.3, -25, -18.7, -12], [-15.3, -25, -14.7, -12],
		[-31.3, -8, -30.7, 4], [-27.3, -8, -26.7, 4], [-23.3, -8, -22.7, 4], [-19.3, -8, -18.7, 4], [-15.3, -8, -14.7, 4]], "h": SHELF_H},
	{"zone": "E", "floor": "upper", "kind": "low", "rects": [[-1.5, -3.7, 1.5, -2.3], [5.5, 2.3, 8.5, 3.7]], "h": 0.8},
	{"zone": "E", "floor": "upper", "kind": "low", "rects": [[-4.5, -24, -1.5, -23], [1.5, -24, 4.5, -23], [7.5, -24, 10.5, -23]], "h": 0.8},
	# F: archive stacks (east-west rows, gap at x 18.5…20.5), hall desk,
	# vault pedestal, alcove crates.
	{"zone": "F", "floor": "upper", "kind": "shelf", "rects": [
		[14, -24.3, 18.5, -23.7], [20.5, -24.3, 25, -23.7], [14, -20.3, 18.5, -19.7], [20.5, -20.3, 25, -19.7],
		[14, -16.3, 18.5, -15.7], [20.5, -16.3, 25, -15.7]], "h": 2.4},
	{"zone": "F", "floor": "upper", "kind": "low", "rects": [[18, -10, 22, -8.8]], "h": 0.8},
	{"zone": "F", "floor": "upper", "kind": "low", "rects": [[31, -25.5, 33, -24.5]], "h": 1.0},
	{"zone": "F", "floor": "upper", "kind": "low", "rects": [[31.5, -16.5, 33.5, -14.5]], "h": 1.2},
]

## The five mandatory objectives (planned; the mission is built in a later
## phase). "pos" is where the player stands to complete it.
const OBJECTIVES := [
	{"id": "o1_key_code", "title": "Find the staff key code", "zone": "C", "pos": Vector3(3, 0, -18.8),
		"note": "Study 3, on the desk. Opens the staff doors (G1a, G1b, G4)."},
	{"id": "o2_keycard", "title": "Take the archive keycard", "zone": "E", "pos": Vector3(3, UPPER_Y, -22.2),
		"note": "Office 2, behind the staff-wing doors."},
	{"id": "o3_manuscript", "title": "Retrieve the rare manuscript", "zone": "F", "pos": Vector3(32, UPPER_Y, -23.6),
		"note": "Archive vault. The archive gates G2 / G3 need the keycard."},
	{"id": "o4_loading_dock", "title": "Reach the loading dock", "zone": "D", "pos": Vector3(27, 0, 20),
		"note": "Return route: back gate → S2 staff stair → storage → dock."},
	{"id": "o5_escape", "title": "Escape through the loading-dock exit", "zone": "D", "pos": Vector3(34.6, 0, 24),
		"note": "The exit door in the east wall."},
]

## Planned gates and shortcut (the doorways named in WALLS). They are open in
## the graybox; locking them is part of the mission phase.
const GATES := [
	{"opening": "Staff Wing Door G1a", "needs": "staff key code (O1)", "guards": "staff wing (O2)"},
	{"opening": "Staff Door (Stacks) G1b", "needs": "staff key code (O1)", "guards": "staff wing (O2)"},
	{"opening": "Lobby Staff Door G4", "needs": "staff key code (O1)", "guards": "service corridor from the lobby"},
	{"opening": "Archive Front Gate G2", "needs": "archive keycard (O2)", "guards": "restricted archive (O3)"},
	{"opening": "Archive Back Gate G3", "needs": "archive keycard (O2)", "guards": "restricted archive (O3)"},
	{"opening": "Service Shortcut SC1", "needs": "one-way: opened from the corridor side", "guards": "shortcut corridor → reading hall"},
]

## Guard patrol loops. A loop with a "guard" gets a guard (scenes/npc/guard.tscn)
## under the scene's "Guards" node, starting at its first point and facing the
## second; a loop without one stays a planned PatrolRoute under
## "Layout/PlannedPatrols". Points are [x, z] on the loop's floor "y", or
## [x, y, z] for a loop that changes floors. "wait" (optional) is the seconds
## to wait at every point (the guard's default is 2 s). Guards use the existing
## AI unchanged: PATROL / INVESTIGATE / CHASE.
const PATROLS := [
	{"id": "P1", "name": "Lobby", "zone": "A", "y": 0.0, "guard": "GuardLobby",
		"points": [[-6, 15.5], [8, 13], [9, 25], [-6, 25]]},
	{"id": "P2", "name": "Main Stacks", "zone": "B", "y": 0.0, "guard": "GuardStacksOuter",
		"points": [[-14, -24], [-14, 4], [-33.5, 4], [-33.5, -24]]},
	{"id": "P2b", "name": "Stacks Inner", "zone": "B", "y": 0.0, "guard": "GuardStacksInner",
		"points": [[-17.5, -9], [-29.5, -9], [-29.5, 8], [-20, 19], [-14.5, 8]]},
	{"id": "P3", "name": "Reading Hall", "zone": "C", "y": 0.0, "points": [[-9.5, -11.5], [9.5, -11.5], [9.5, 7], [-9.5, 7]]},
	{"id": "P4", "name": "Service Corridor", "zone": "D", "y": 0.0, "points": [[14.5, -25], [14.5, 24], [26, 20], [25, 3]]},
	{"id": "P5", "name": "Upper Stacks", "zone": "E", "y": UPPER_Y, "guard": "GuardUpper",
		"points": [[-13, -25], [-13, 6], [-33.5, 2], [-33.5, -25]]},
	{"id": "P6", "name": "Staff Corridor", "zone": "E", "y": UPPER_Y, "points": [[-3, -11], [9, -11], [3, -18.5]]},
	{"id": "P7", "name": "Archive", "zone": "F", "y": UPPER_Y, "guard": "GuardArchive",
		"points": [[14, -9], [26.5, -9], [26.5, -26], [14, -26]]},
	# Connecting patrol: reading hall → lobby → up S1 → balcony → staff corridor (G1a)
	# → upper stacks (G1b) → down S3 → browsing hall → main stacks → reading hall.
	{"id": "P8", "name": "Connector", "zone": "A", "y": 0.0, "guard": "GuardConnector", "wait": 1.5,
		"points": [[0, 0, -5], [-3, 0, 15], [-10.35, UPPER_Y, 6.5], [4, UPPER_Y, 1], [3, UPPER_Y, -11],
			[-9, UPPER_Y, -11], [-30, UPPER_Y, 6], [-28, 0, 19]]},
]


## World position of point `k` of a patrol loop.
static func patrol_point(patrol: Dictionary, k: int) -> Vector3:
	var p: Array = patrol.points[k]
	return Vector3(p[0], p[1], p[2]) if p.size() == 3 else Vector3(p[0], patrol.y, p[1])


## Planned hiding opportunities (crouched behind or inside cover).
const HIDING := [
	{"name": "Study 1 carrel", "zone": "C", "pos": Vector3(-10.5, 0, -26.8)},
	{"name": "Study 3 carrel", "zone": "C", "pos": Vector3(4.5, 0, -26.8)},
	{"name": "Reading table", "zone": "C", "pos": Vector3(-6, 0, -4.4)},
	{"name": "Browsing shelf", "zone": "B", "pos": Vector3(-28.8, 0, 15)},
	{"name": "Circulation desk", "zone": "A", "pos": Vector3(4, 0, 17.3)},
	{"name": "Storage rack", "zone": "D", "pos": Vector3(24, 0, 7)},
	{"name": "Dock crate", "zone": "D", "pos": Vector3(28, 0, 17.6)},
	{"name": "Upper stacks aisle", "zone": "E", "pos": Vector3(-29, UPPER_Y, -18)},
	{"name": "Office 3 desk", "zone": "E", "pos": Vector3(9, UPPER_Y, -24.8)},
	{"name": "Archive alcove", "zone": "F", "pos": Vector3(32.5, UPPER_Y, -13.6)},
]

## Intended player routes (design intent, drawn on the maps and walked by the tests).
const ROUTES := [
	{"name": "Main route", "colour": Color(0.25, 0.95, 0.95), "points": [
		Vector3(0, 0, 32), Vector3(0, 0, 20), Vector3(0, 0, 10), Vector3(3, 0, -14), Vector3(3, 0, -18.8),
		Vector3(3, 0, -14), Vector3(0, 0, 10), Vector3(-10.35, 0, 21.5), Vector3(-10.35, UPPER_Y, 8),
		Vector3(2, UPPER_Y, -2), Vector3(3, UPPER_Y, -8), Vector3(3, UPPER_Y, -11), Vector3(3, UPPER_Y, -22.2),
		Vector3(3, UPPER_Y, -11), Vector3(12, UPPER_Y, -11), Vector3(26.5, UPPER_Y, -11), Vector3(26.5, UPPER_Y, -21),
		Vector3(32, UPPER_Y, -23.6), Vector3(26.5, UPPER_Y, -21), Vector3(26.5, UPPER_Y, -9), Vector3(30, UPPER_Y, -9),
		Vector3(34.35, UPPER_Y, -8.5), Vector3(34.35, 0, 5.5), Vector3(29, 0, 10), Vector3(22, 0, 12),
		Vector3(27, 0, 20), Vector3(34.6, 0, 24)]},
	{"name": "Alternative: stacks stair to the staff wing", "colour": Color(0.55, 0.75, 1.0), "points": [
		Vector3(0, 0, 20), Vector3(-12, 0, 24), Vector3(-20, 0, 19), Vector3(-34.35, 0, 21.5),
		Vector3(-34.35, UPPER_Y, 8), Vector3(-33.5, UPPER_Y, 5), Vector3(-13, UPPER_Y, 5),
		Vector3(-13, UPPER_Y, -10), Vector3(-6, UPPER_Y, -11), Vector3(3, UPPER_Y, -11)]},
	{"name": "Alternative: service corridor to the archive back gate", "colour": Color(1.0, 0.6, 0.85), "points": [
		Vector3(3, UPPER_Y, -11), Vector3(2, UPPER_Y, -2), Vector3(-10.35, UPPER_Y, 8), Vector3(-10.35, 0, 21.5),
		Vector3(12, 0, 21), Vector3(14.5, 0, 10), Vector3(17, 0, 2), Vector3(29, 0, 9),
		Vector3(34.35, 0, 5.5), Vector3(34.35, UPPER_Y, -8.5), Vector3(30, UPPER_Y, -9), Vector3(26.5, UPPER_Y, -11)]},
	{"name": "Shortcut SC1 (one-way, corridor → reading hall)", "colour": Color(1.0, 0.8, 0.2), "points": [
		Vector3(14.5, 0, 4), Vector3(12, 0, 4), Vector3(8, 0, 4)]},
]

## Points that must be reachable on the navmesh: one or more per room, and
## the aisles between shelf rows.
const PROBES := [
	Vector3(0, 0, 31), Vector3(0, 0, 20), Vector3(-24, 0, 19), Vector3(-24, 0, -9), Vector3(0, 0, -5),
	Vector3(-9, 0, -20), Vector3(-3, 0, -20), Vector3(3, 0, -17), Vector3(9, 0, -20),
	Vector3(14.5, 0, 0), Vector3(25, 0, -17), Vector3(25, 0, 3), Vector3(25, 0, 20),
	Vector3(-33.5, 0, -18), Vector3(-29.5, 0, -18), Vector3(-26.5, 0, -18), Vector3(-23.5, 0, -18),
	Vector3(-20.5, 0, -18), Vector3(-17.5, 0, -18), Vector3(-14, 0, -18),
	Vector3(-29.5, 0, 0), Vector3(-26.5, 0, 0), Vector3(-23.5, 0, 0), Vector3(-20.5, 0, 0), Vector3(-17.5, 0, 0),
	Vector3(-24, UPPER_Y, -10), Vector3(-29, UPPER_Y, -18), Vector3(-25, UPPER_Y, -18), Vector3(-21, UPPER_Y, -18),
	Vector3(-17, UPPER_Y, -18), Vector3(-29, UPPER_Y, -2), Vector3(-25, UPPER_Y, -2), Vector3(-21, UPPER_Y, -2),
	Vector3(-17, UPPER_Y, -2), Vector3(-10, UPPER_Y, 0), Vector3(3, UPPER_Y, 2), Vector3(3, UPPER_Y, -11),
	Vector3(-3, UPPER_Y, -20), Vector3(3, UPPER_Y, -18), Vector3(9, UPPER_Y, -20),
	Vector3(20, UPPER_Y, -12), Vector3(16, UPPER_Y, -22), Vector3(23, UPPER_Y, -22), Vector3(16, UPPER_Y, -18),
	Vector3(23, UPPER_Y, -18), Vector3(32, UPPER_Y, -21), Vector3(29.5, UPPER_Y, -15), Vector3(33, UPPER_Y, -9),
]


## The opening called `name` as {wall, opening, centre (Vector3 on its floor), along_x}.
static func find_opening(name: String) -> Dictionary:
	for wall in WALLS:
		for opening in wall.get("openings", []):
			if opening.name == name:
				return {"wall": wall, "opening": opening, "centre": opening_centre(wall, opening),
					"along_x": wall.a[1] == wall.b[1]}
	return {}


## World position of an opening's centre, on its floor.
static func opening_centre(wall: Dictionary, opening: Dictionary) -> Vector3:
	var y := floor_y(wall.floor)
	if wall.a[1] == wall.b[1]:
		return Vector3(opening.at, y, wall.a[1])
	return Vector3(wall.a[0], y, opening.at)


static func floor_y(floor_name: String) -> float:
	return UPPER_Y if floor_name == "upper" else 0.0


## Bottom (ground, just outside the ramp's low end) and top (upper floor, just
## past its high end) of a stair.
static func stair_ends(stair: Dictionary) -> Array[Vector3]:
	var x: float = (stair.x0 + stair.x1) / 2.0
	var dir: float = signf(stair.z_high - stair.z_low)   # −1: rises toward −z (north)
	return [Vector3(x, 0, stair.z_low - dir * 1.5), Vector3(x, UPPER_Y, stair.z_high + dir * 2.5)]


static func zone(id: String) -> Dictionary:
	for z in ZONES:
		if z.id == id:
			return z
	return {}
