extends RefCounted

## Expanded Library — Phase 4 mission tests. Called from tests/test_scene.gd.
## The mission uses the existing systems: ObjectiveManager (five objectives),
## ObjectiveTrigger, AccessCard (the staff card and the manuscript),
## AccessDoor (card doors G2 / G4, one-way doors G3 / SC1), ExitDoor,
## Checkpoint / CheckpointManager, StealthDirector, GameFlow, ObjectiveHud.
##
##   A. Setup: five objectives in order, every piece placed, HUD in sync.
##   B. Full mission with real input (walking, looking, pressing E) from a
##      fresh start to the WIN screen, the HUD checked at every step.
##   C. No bypass: card doors, one-way doors, the manuscript, the card and the
##      exit refuse the player at the wrong time, and closed doors physically
##      block the player (real input) and guard sight, while guards pass.
##   D. Order flexibility: the back gate opened before the manuscript.
##   E. Captures: before the card, right after it, after the manuscript, after
##      the shortcut; repeated captures; level guards reset; no checkpoint
##      during a chase. After every respawn the mission state equals the
##      checkpoint's snapshot and stays consistent (items, doors, objectives,
##      exit, HUD).
##   F. A fresh load after progress starts clean (Restart reloads the scene:
##      tools/map_flow.gd checks the real Restart button).
## Tests other than E's guard reset remove the level guards and use a test
## guard to catch the player, so they don't depend on patrol timing.

const SCENE := "res://scenes/level/expanded_library.tscn"
const GUARD_SCENE := "res://scenes/npc/guard.tscn"
const Layout := preload("res://tools/expanded/expanded_layout.gd")
const TestUtils := preload("res://tests/test_utils.gd")
const S := StealthDirector.Status
const ACTIVE := ObjectiveManager.State.ACTIVE
const COMPLETED := ObjectiveManager.State.COMPLETED
const LOCKED := ObjectiveManager.State.LOCKED
const U := Layout.UPPER_Y
const ENTER := &"enter_library"
const CARD := &"take_card"
const ITEM := &"take_manuscript"
const SHORTCUT := &"unlock_shortcut"
const ESCAPE := &"escape"

## Standing spots (floor level) and what to look at from them.
const IN_LOBBY := Vector3(0, 0, 20)
const AT_CARD := Vector3(3, U, -22.2)
const AT_ITEM := Vector3(32, U, -23.6)
const G2_WEST := Vector3(10.6, U, -11)
const G2_EAST := Vector3(13.4, U, -11)
const G4_WEST := Vector3(10.6, 0, 21)
const G4_EAST := Vector3(13.4, 0, 21)
const G3_WEST := Vector3(28.6, U, -9)
const G3_EAST := Vector3(31.4, U, -9)
const SC1_WEST := Vector3(10.6, 0, 4)
const SC1_EAST := Vector3(13.4, 0, 4)
const AT_EXIT := Vector3(34.3, 0, 24)

var failures: Array[String] = []
var _host: Node
var _level: Node3D
var _map: RID
var _player: FirstPersonPlayer
var _interactor: PlayerInteractor
var _objectives: ObjectiveManager
var _checkpoints: CheckpointManager
var _director: StealthDirector
var _hud: ObjectiveHud
var _card: AccessCard
var _item: AccessCard
var _exit: ExitDoor
var _g2: AccessDoor
var _g3: AccessDoor
var _g4: AccessDoor
var _sc1: AccessDoor
var _guard: Guard
var _route: PatrolRoute
var _escapes := 0


func run(host: Node) -> Array[String]:
	_host = host
	await _load(false)
	_check_setup()
	await _check_full_mission_real_input()
	await _load(false)
	await _check_no_bypass()
	await _load(false)
	await _check_doors_block_player_and_sight()
	await _load(false)
	await _check_card_opens_card_doors()
	await _load(false)
	await _check_order_flexibility()
	await _load(false)
	await _check_caught_before_card()
	await _load(false)
	await _check_caught_after_card()
	await _load(false)
	await _check_caught_after_item()
	await _load(false)
	await _check_caught_after_shortcut()
	await _load(false)
	await _check_repeated_captures()
	await _load(true)
	await _check_level_guards_reset()
	await _check_fresh_load_is_clean()
	await _unload()
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[expanded-mission] " + message)


# --- A. Setup ---------------------------------------------------------------------------------

func _check_setup() -> void:
	var ids: Array[StringName] = [ENTER, CARD, ITEM, SHORTCUT, ESCAPE]
	_expect(_objectives.get_ids() == ids, "The five objectives should be %s in order, got %s." % [ids, _objectives.get_ids()])
	for i in ids.size():
		_expect(_objectives.get_title(ids[i]) == Layout.OBJECTIVES[i].title, "Objective %d's title should come from the layout." % (i + 1))
	_expect(_objectives.current() == ENTER and _objectives.completed_count() == 0, "A fresh mission starts at 'Enter the library'.")
	for n in [_card, _item, _exit, _g2, _g3, _g4, _sc1, _checkpoints, _hud]:
		_expect(n != null, "A mission node is missing (%s)." % n)
	_expect(_level.get_tree().get_nodes_in_group("objective_manager").size() == 1
		and _level.get_tree().get_nodes_in_group("checkpoint_manager").size() == 1, "Exactly one ObjectiveManager and one CheckpointManager.")
	_expect(_level.get_tree().get_nodes_in_group("checkpoints").size() == Layout.CHECKPOINTS.size(), "Expected %d checkpoints." % Layout.CHECKPOINTS.size())
	for d in [_g2, _g3, _g4, _sc1]:
		_expect(not d.is_open and d.enabled, "%s should start closed." % d.door_name)
		var panel: StaticBody3D = d.get_node("Panel")
		_expect(panel.collision_layer == 1 and not _level.get_node("NavigationRegion3D").is_ancestor_of(panel),
			"%s's panel must be world geometry outside the navmesh region (not baked)." % d.door_name)
	_expect(_card.visible and _item.visible and not _exit.is_unlocked(), "Items on display and the exit locked at the start.")
	_check_consistency("setup")
	print("  [expanded-mission] setup: %s; 4 access doors closed, 2 items, exit locked, %d checkpoints" % [
		" → ".join(ids), Layout.CHECKPOINTS.size()])


# --- B. Full mission with real input ----------------------------------------------------------

func _check_full_mission_real_input() -> void:
	_player.global_position = Layout.SPAWN
	await _frames(5)
	var started := Time.get_ticks_msec()
	var walked := 0.0
	var steps := [
		# [points to walk through, look at (or null), expected current objective after]
		[[IN_LOBBY], null, CARD],
		[[Vector3(-10.35, 0, 21.5), Vector3(-10.35, U, 8), Vector3(2, U, -2), Vector3(3, U, -8), Vector3(3, U, -11),
			Layout.CHECKPOINTS[1].pos, AT_CARD], _card, ITEM],
		[[Vector3(3, U, -11), G2_WEST], _g2, ITEM],
		[[G2_EAST, Vector3(26.5, U, -11), Vector3(26.5, U, -21), AT_ITEM], _item, SHORTCUT],
		[[Vector3(26.5, U, -21), Vector3(26.5, U, -9), G3_WEST], _g3, ESCAPE],
		[[G3_EAST, Vector3(34.35, U, -8.5), Vector3(34.35, 0, 5.5), Layout.CHECKPOINTS[2].pos, Vector3(29, 0, 10),
			Vector3(22, 0, 12), Vector3(27, 0, 20), AT_EXIT], _exit, &""],
	]
	var log := []
	for step in steps:
		for p in step[0]:
			var r: Dictionary = await _walk_to(p)
			walked += r.distance
			if not r.arrived:
				_expect(false, "Full mission: walking to %s got stuck at %s." % [p, _player.global_position])
				_release_all()
				return
		var target = step[1]
		if target != null:
			await _look_at(_aim(target))
			_expect(_interactor.focused == target, "Full mission: looking at %s should focus it (focused %s)." % [target.name, _interactor.focused])
			await _press_interact()
		await _frames(3)
		_expect(_objectives.current() == step[2], "Full mission: after %s the current objective should be '%s', got '%s'." % [
			target.name if target != null else "entering", step[2], _objectives.current()])
		_check_consistency("full mission, %s" % (target.name if target != null else "lobby"))
		log.append("%s (HUD %s)" % [_objectives.current() if _objectives.current() != &"" else &"done", _hud.get_header_text()])
	var flow := GameFlow.find(_level)
	var menus: GameMenus = _level.get_node("GameMenus")
	_expect(_objectives.is_finished() and _director.status == S.ESCAPED and _escapes == 1, "Full mission: the exit should finish the level.")
	_expect(flow.state == GameStateMachine.State.WIN and menus.win_panel.visible, "Full mission: the game should switch to WIN and show the ESCAPED screen.")
	_expect(menus.win_message == Layout.WIN_MESSAGE, "The win screen should say '%s'." % Layout.WIN_MESSAGE)
	_expect(_checkpoints.activations == 2 and _checkpoints.get_respawn_name() == "Storage",
		"The route's two checkpoints should have activated, ending at Storage (got %d, %s)." % [_checkpoints.activations, _checkpoints.get_respawn_name()])
	_expect(_g2.is_open and _g3.is_open and not _g4.is_open and not _sc1.is_open, "Only the doors used should be open.")
	print("  [expanded-mission] full mission with real input: %.0f m walked in %.0f s real time, E pressed 5 times; %s → WIN" % [
		walked, (Time.get_ticks_msec() - started) / 1000.0, ", ".join(log)])


# --- C. No bypass -----------------------------------------------------------------------------

func _check_no_bypass() -> void:
	var noise := NoiseSystem.find(_level)
	# The card can't be taken before entering the library.
	await _stand_and_look(AT_CARD, _aim(_card))
	_expect(_interactor.focused == _card and _hud.get_prompt_text() == "[E] Staff access card (not yet)",
		"The card before entering should say 'not yet', got '%s'." % _hud.get_prompt_text())
	_expect(not _interactor.try_interact() and _card.visible, "The card must not be taken before entering the library.")
	await _teleport(IN_LOBBY)
	_expect(_objectives.current() == CARD, "Entering the lobby completes O1.")
	# Card doors without the card, from both sides.
	for check in [[_g2, G2_WEST], [_g2, G2_EAST], [_g4, G4_WEST], [_g4, G4_EAST]]:
		var door: AccessDoor = check[0]
		var before := noise.emitted_count
		await _stand_and_look(check[1], _aim(door))
		_expect(_interactor.focused == door, "%s should be focused from %s." % [door.door_name, check[1]])
		_expect(_hud.get_prompt_text() == "[E] %s · locked (staff access card needed)" % door.door_name, "Locked prompt, got '%s'." % _hud.get_prompt_text())
		_expect(not _interactor.try_interact() and not door.is_open, "%s must not open without the card." % door.door_name)
		_expect(_hud.get_message_text() == "%s is locked. You need the staff access card." % door.door_name, "Rejection message, got '%s'." % _hud.get_message_text())
		_expect(noise.emitted_count == before + 1, "Rattling %s should make a noise." % door.door_name)
	# The back gate only opens from the archive, the service shortcut only from the corridor.
	for check in [[_g3, G3_EAST], [_sc1, SC1_WEST]]:
		var door: AccessDoor = check[0]
		await _stand_and_look(check[1], _aim(door))
		_expect(_hud.get_prompt_text() == "[E] %s · locked from this side" % door.door_name, "One-way prompt, got '%s'." % _hud.get_prompt_text())
		_expect(not _interactor.try_interact() and not door.is_open, "%s must not open from the wrong side." % door.door_name)
		_expect(_hud.get_message_text() == "%s only opens from the other side." % door.door_name, "One-way message, got '%s'." % _hud.get_message_text())
	# The manuscript before the card (teleported into the vault).
	await _stand_and_look(AT_ITEM, _aim(_item))
	_expect(_hud.get_prompt_text() == "[E] Rare manuscript (not yet)" and not _interactor.try_interact() and _item.visible,
		"The manuscript must not be taken before the card.")
	# The back gate opened from inside before the card does not complete anything yet.
	# The exit before the shortcut: rejected, explained, no escape.
	await _stand_and_look(AT_EXIT, _aim(_exit))
	_expect(_hud.get_prompt_text() == "[E] " + Layout.EXIT_DOOR.prompt, "Exit prompt, got '%s'." % _hud.get_prompt_text())
	_expect(not _interactor.try_interact() and _exit.rejections == 1 and _director.status != S.ESCAPED, "The exit must reject the player.")
	_expect(_hud.get_message_text() == "The loading dock exit is sealed. First: take a staff access card.",
		"The exit should say what is missing, got '%s'." % _hud.get_message_text())
	_expect(_exit._sign.text == Layout.EXIT_DOOR.sign, "The exit sign should say %s." % Layout.EXIT_DOOR.sign)
	# Card and manuscript taken but the shortcut not unlocked: the exit is still sealed.
	_objectives.complete(CARD)
	_objectives.complete(ITEM)
	await _stand_and_look(AT_EXIT, _aim(_exit))
	_expect(not _interactor.try_interact() and _director.status != S.ESCAPED, "The exit must stay sealed until the back gate is open.")
	_expect(_hud.get_message_text() == "The loading dock exit is sealed. First: unlock the archive back gate.", "Got '%s'." % _hud.get_message_text())
	_check_consistency("no bypass")
	print("  [expanded-mission] no bypass: card, manuscript, G2 / G4 (both sides), G3 / SC1 (wrong side) and the exit all refused; %d rattles" % (
		_g2.rejections + _g4.rejections + _g3.rejections + _sc1.rejections + _exit.rejections))


func _check_doors_block_player_and_sight() -> void:
	await _teleport(IN_LOBBY)
	# Real input into each closed door: the player stops at the panel.
	for check in [[_g2, G2_WEST, 1.0], [_g4, G4_WEST, 1.0], [_g3, G3_EAST, -1.0], [_sc1, SC1_WEST, 1.0]]:
		var door: AccessDoor = check[0]
		var crossed := await _push_through(check[1], door.global_position.x, check[2])
		_expect(not crossed, "The player must not get through the closed %s (reached x %.2f)." % [door.door_name, _player.global_position.x])
	# A guard on the far side of the closed front gate can't see the player; once it is open, it can.
	_spawn_guard(Vector3(17, U, -11), PI / 2.0)   # facing west (−x)
	await _frames(5)
	await _teleport(Vector3(8, U, -11))
	await _frames(90)
	var seen_closed := _guard.vision.can_see_target or _guard.vision.detection > 0.0
	_g2.open()
	await _frames(90)
	var seen_open := _guard.vision.can_see_target or _guard.vision.detection > 0.0
	_expect(not seen_closed and seen_open, "A closed door should block sight and an open one not (closed %s, open %s)." % [seen_closed, seen_open])
	_clear_guard()
	await _frames(3)
	# Open doors let the player through (real input), both ways.
	for d in [_g4, _g3, _sc1]:
		d.open()
	await _frames(3)
	var passes := 0
	for check in [[G2_WEST, 12.0, 1.0], [G2_EAST, 12.0, -1.0], [G4_WEST, 12.0, 1.0], [G3_EAST, 30.0, -1.0], [G3_WEST, 30.0, 1.0], [SC1_WEST, 12.0, 1.0]]:
		if await _push_through(check[0], check[1], check[2]):
			passes += 1
		else:
			_expect(false, "The player should get through the open doorway at %s." % check[0])
	# Guards were never blocked: the doorways stay on the navmesh in every state.
	for d in [_g2, _g3, _g4, _sc1]:
		var c: Vector3 = d.global_position - Vector3(0, 1.2, 0)
		var closest := NavigationServer3D.map_get_closest_point(_map, c)
		_expect(Vector2(closest.x - c.x, closest.z - c.z).length() < 0.3, "The navmesh must still run through %s." % d.door_name)
	print("  [expanded-mission] doors: closed G2, G4, G3, SC1 stop the walking player and block a guard's sight; open, all 6 crossings pass (%d/6); doorways stay on the navmesh" % passes)


func _check_card_opens_card_doors() -> void:
	await _teleport(IN_LOBBY)
	await _stand_and_look(AT_CARD, _aim(_card))
	_expect(_hud.get_prompt_text() == "[E] Take the staff access card", "Card prompt, got '%s'." % _hud.get_prompt_text())
	_expect(_interactor.try_interact() and not _card.visible and _objectives.current() == ITEM, "Taking the card completes O2.")
	_expect(_hud.get_message_text() == Layout.OBJECTIVES[1].done, "HUD confirms the card, got '%s'." % _hud.get_message_text())
	for check in [[_g2, G2_WEST], [_g4, G4_EAST]]:
		var door: AccessDoor = check[0]
		await _stand_and_look(check[1], _aim(door))
		_expect(_hud.get_prompt_text() == "[E] Open the %s" % door.door_name.to_lower(), "Prompt with the card, got '%s'." % _hud.get_prompt_text())
		_expect(_interactor.try_interact() and door.is_open and not door.enabled, "%s opens with the card." % door.door_name)
		_expect(_hud.get_message_text() == "%s opened" % door.door_name, "HUD confirms the door, got '%s'." % _hud.get_message_text())
		await _frames(2)
		_expect(_interactor.focused == null, "An open door is no longer an interaction target.")
	# The card opens only the card doors.
	await _stand_and_look(G3_EAST, _aim(_g3))
	_expect(not _interactor.try_interact() and not _g3.is_open, "The card does not open the one-way back gate from outside.")
	_check_consistency("card doors")
	print("  [expanded-mission] card: taken in Office 2; G2 and G4 open with it and stay open; G3 still one-way")


# --- D. Order flexibility ---------------------------------------------------------------------

func _check_order_flexibility() -> void:
	await _teleport(IN_LOBBY)
	_objectives.complete(CARD)
	await _stand_and_look(G3_WEST, _aim(_g3))
	_expect(_interactor.try_interact() and _g3.is_open, "The back gate opens from the archive side before the manuscript.")
	await _frames(3)
	_expect(_objectives.get_state(SHORTCUT) == LOCKED and _objectives.current() == ITEM, "Opening the gate early does not skip ahead.")
	_check_consistency("gate before manuscript")
	await _stand_and_look(AT_ITEM, _aim(_item))
	_expect(_interactor.try_interact(), "Take the manuscript.")
	await _frames(3)
	_expect(_objectives.is_completed(SHORTCUT) and _objectives.current() == ESCAPE and _exit.is_unlocked(),
		"With the gate already open, taking the manuscript completes the shortcut objective too (current %s)." % _objectives.current())
	_check_consistency("manuscript after gate")
	await _stand_and_look(AT_EXIT, _aim(_exit))
	_expect(_hud.get_prompt_text() == "[E] Escape" and _interactor.try_interact() and _director.status == S.ESCAPED, "The exit opens once both are done.")
	print("  [expanded-mission] order: back gate before the manuscript works (O4 completes when it comes up), then escape")


# --- E. Captures and checkpoints ----------------------------------------------------------------

func _check_caught_before_card() -> void:
	await _teleport(IN_LOBBY)
	await _teleport(Vector3(3, U, -11))
	await _catch_and_respawn(Vector3(3, U, -11), Vector3(0.5, U, -11))
	_expect(_player.global_position.distance_to(Layout.SPAWN) < 0.4, "Caught before any checkpoint: respawn at the entrance (%.2f m away)." % _player.global_position.distance_to(Layout.SPAWN))
	_expect(_objectives.current() == ENTER and _objectives.completed_count() == 0, "Before any checkpoint, the mission restarts from O1 (as in the tutorial).")
	await _check_restored("caught before the card")
	print("  [expanded-mission] caught before the card: respawn at the entrance, mission back to O1")


func _check_caught_after_card() -> void:
	var cp := _checkpoint(1)
	await _teleport(IN_LOBBY)
	await _teleport(Layout.CHECKPOINTS[1].pos)
	_expect(_checkpoints.active == cp, "Walking onto the Staff Offices pad activates it.")
	await _stand_and_look(AT_CARD, _aim(_card))
	_interactor.try_interact()
	await _stand_and_look(G2_WEST, _aim(_g2))
	_interactor.try_interact()
	_expect(_card.is_taken() and _g2.is_open, "Card taken and front gate opened after the checkpoint.")
	await _catch_and_respawn(Vector3(3, U, -20.5), Vector3(3, U, -18.5))
	_expect(_player.global_position.distance_to(cp.get_spawn_transform().origin) < 0.4, "Respawn at Staff Offices.")
	_expect(not _card.is_taken() and _card.visible and _objectives.current() == CARD, "The card goes back on the desk.")
	_expect(not _g2.is_open and _g2.enabled, "The front gate opened with that card is closed again.")
	await _check_restored("caught right after the card")
	# Retake the card, step back on the pad: the checkpoint now keeps the card.
	await _stand_and_look(AT_CARD, _aim(_card))
	_expect(_interactor.try_interact(), "The card can be taken again.")
	var n := _checkpoints.activations
	await _teleport(Layout.CHECKPOINTS[1].pos)
	_expect(_checkpoints.activations == n + 1 and _checkpoints.saved_progress.get(CARD) == COMPLETED, "Re-entering the pad with new progress saves it.")
	await _catch_and_respawn(Vector3(3, U, -11), Vector3(0.5, U, -11))
	_expect(_card.is_taken() and _objectives.current() == ITEM and not _g2.is_open, "Card kept after the checkpoint saved it; the gate is still to open.")
	await _check_restored("caught after the card was saved")
	await _stand_and_look(G2_WEST, _aim(_g2))
	_expect(_interactor.try_interact() and _g2.is_open, "The kept card still opens the gate.")
	print("  [expanded-mission] caught right after the card: card back on the desk and G2 closed; after saving it at the pad: card kept, G2 reopens")


func _check_caught_after_item() -> void:
	var cp := _checkpoint(1)
	await _teleport(IN_LOBBY)
	await _stand_and_look(AT_CARD, _aim(_card))
	_interactor.try_interact()
	await _teleport(Layout.CHECKPOINTS[1].pos)
	_expect(_checkpoints.active == cp and _checkpoints.saved_progress.get(CARD) == COMPLETED, "Checkpoint saved with the card.")
	await _stand_and_look(G2_WEST, _aim(_g2))
	_interactor.try_interact()
	await _stand_and_look(AT_ITEM, _aim(_item))
	_interactor.try_interact()
	_expect(_objectives.current() == SHORTCUT and not _item.visible, "Manuscript taken.")
	await _catch_and_respawn(Vector3(31, U, -22), Vector3(33.5, U, -22))
	_expect(_item.visible and _objectives.current() == ITEM and _card.is_taken(), "The manuscript is back in the vault; the card is kept.")
	_expect(not _g2.is_open, "The gate opened after the checkpoint is closed again.")
	await _check_restored("caught after the manuscript")
	print("  [expanded-mission] caught after the manuscript: manuscript back on its pedestal, card kept, G2 closed")


func _check_caught_after_shortcut() -> void:
	await _teleport(IN_LOBBY)
	await _stand_and_look(AT_CARD, _aim(_card))
	_interactor.try_interact()
	await _teleport(Layout.CHECKPOINTS[1].pos)
	await _stand_and_look(G2_WEST, _aim(_g2))
	_interactor.try_interact()
	await _stand_and_look(AT_ITEM, _aim(_item))
	_interactor.try_interact()
	await _stand_and_look(G3_WEST, _aim(_g3))
	_interactor.try_interact()
	_expect(_g3.is_open and _objectives.current() == ESCAPE, "Back gate unlocked: escape is next.")
	# Caught before reaching the Storage pad: back to Staff Offices, all of it undone.
	await _catch_and_respawn(Vector3(33, U, -9), Vector3(33, U, -11))
	_expect(not _g3.is_open and not _g2.is_open and _item.visible and _objectives.current() == ITEM, "Back gate, front gate and manuscript all reset to the Staff Offices snapshot.")
	await _check_restored("caught after the shortcut, before Storage")
	# Again, this time over the Storage pad, then caught in the dock.
	await _stand_and_look(G2_WEST, _aim(_g2))
	_interactor.try_interact()
	await _stand_and_look(AT_ITEM, _aim(_item))
	_interactor.try_interact()
	await _stand_and_look(G3_WEST, _aim(_g3))
	_interactor.try_interact()
	await _teleport(G3_EAST)
	await _teleport(Layout.CHECKPOINTS[2].pos)
	_expect(_checkpoints.active == _checkpoint(2), "The Storage pad activates.")
	await _catch_and_respawn(Vector3(24, 0, 20), Vector3(24, 0, 22.5))
	_expect(_player.global_position.distance_to(_checkpoint(2).get_spawn_transform().origin) < 0.4, "Respawn at Storage.")
	_expect(_g3.is_open and _g2.is_open and not _item.visible and _objectives.current() == ESCAPE and _exit.is_unlocked(),
		"Everything saved at Storage is kept: gates open, manuscript held, exit unlocked.")
	await _check_restored("caught after Storage")
	await _stand_and_look(AT_EXIT, _aim(_exit))
	_expect(_interactor.try_interact() and _director.status == S.ESCAPED, "Escape still works after the respawn.")
	print("  [expanded-mission] caught after the shortcut: before Storage → everything since Staff Offices undone; after Storage → kept, then escaped")


func _check_repeated_captures() -> void:
	await _teleport(IN_LOBBY)
	await _stand_and_look(AT_CARD, _aim(_card))
	_interactor.try_interact()
	await _teleport(Layout.CHECKPOINTS[1].pos)
	var saved_progress := _checkpoints.saved_progress.duplicate()
	var saved_state := _checkpoints.saved_state.duplicate(true)
	var activations := _checkpoints.activations
	var rounds := 5
	for i in rounds:
		# Different progress each round before being caught.
		await _stand_and_look(G2_WEST, _aim(_g2))
		_interactor.try_interact()
		if i % 2 == 0:
			await _stand_and_look(AT_ITEM, _aim(_item))
			_interactor.try_interact()
		if i % 3 == 0:
			await _stand_and_look(G3_WEST, _aim(_g3))
			_interactor.try_interact()
		await _catch_and_respawn(Vector3(20, U, -11), Vector3(22.5, U, -11))
		_expect(_objectives.get_progress() == saved_progress and _checkpoints.get_mission_state() == saved_state,
			"Capture %d: the mission state should equal the checkpoint's snapshot." % (i + 1))
		await _check_restored("capture %d" % (i + 1))
	_expect(_director.catches == rounds and _checkpoints.activations == activations, "Captures counted, no extra checkpoint activations.")
	_expect(_hud.get_header_text() == "OBJECTIVE 3/5" and _hud.get_current_text() == Layout.OBJECTIVES[2].title, "HUD back at O3 after the captures.")
	# No checkpoint during a chase.
	_spawn_guard(Vector3(-3, 0, -10), 0.0)
	await _frames(3)
	await _teleport(Vector3(-3, 0, -16.5))
	await _until(func(): return _director.status == S.CHASE, 400)
	_expect(_director.status == S.CHASE, "Standing in front of the guard starts a chase.")
	await _teleport(Layout.CHECKPOINTS[0].pos)
	_expect(_checkpoints.active == _checkpoint(1) and not _checkpoint(0).is_active, "A checkpoint must not activate during a chase.")
	_clear_guard()
	print("  [expanded-mission] repeated captures: %d captures with different progress, state equals the snapshot every time; no checkpoint during a chase" % rounds)


func _check_level_guards_reset() -> void:
	var guards: Array[Guard] = []
	var starts := {}
	for g in _level.get_node("Guards").get_children():
		if g is Guard:
			guards.append(g)
			starts[g] = g.global_position
	await _teleport(Layout.CHECKPOINTS[0].pos)   # a respawn spot no patrol watches
	Engine.time_scale = 4.0
	await _frames(240)
	Engine.time_scale = 1.0
	var moved := guards.filter(func(g): return g.global_position.distance_to(starts[g]) > 1.0).size()
	await _catch_and_respawn(Vector3(3, U, -11), Vector3(0.5, U, -11))
	var off := 0
	for g in guards:
		if g.global_position.distance_to(starts[g]) > 0.3 or g.machine.current != GuardStateMachine.PATROL \
				or g.vision.detection > 0.0 or g.vision.has_last_known_position:
			off += 1
	_expect(off == 0, "%d level guard(s) not back at their start, on patrol, with a clear memory after the respawn." % off)
	_expect(_director.status == S.NONE, "The detection status should be clear after the respawn.")
	await _check_restored("level guards")
	print("  [expanded-mission] level guards: %d of %d had moved; after the capture all 6 at their starts, PATROL, detection 0" % [moved, guards.size()])


# --- F. Fresh load ----------------------------------------------------------------------------

func _check_fresh_load_is_clean() -> void:
	# Make progress in this instance, then load the scene again (what Restart does).
	_objectives.complete(ENTER)
	_objectives.complete(CARD)
	_g2.open()
	await _teleport(Layout.CHECKPOINTS[1].pos)
	await _load(false)
	_expect(_objectives.current() == ENTER and _objectives.completed_count() == 0 and _card.visible and _item.visible,
		"A fresh load starts at O1 with both items in place.")
	_expect(not (_g2.is_open or _g3.is_open or _g4.is_open or _sc1.is_open), "A fresh load has every access door closed.")
	_expect(_checkpoints.active == null and _checkpoints.activations == 0 and _director.catches == 0, "A fresh load has no checkpoint and no captures.")
	_expect(_hud.get_header_text() == "OBJECTIVE 1/5", "A fresh load's HUD starts at objective 1.")
	_check_consistency("fresh load")
	print("  [expanded-mission] fresh load after progress: O1, items in place, doors closed, no checkpoint")


# --- Consistency -------------------------------------------------------------------------------

## The invariants that must always hold, whatever happened before.
func _check_consistency(label: String) -> void:
	var active := 0
	for id in _objectives.get_ids():
		if _objectives.get_state(id) == ACTIVE:
			active += 1
	_expect(active == (0 if _objectives.is_finished() else 1), "%s: exactly one objective should be ACTIVE." % label)
	for item in [_card, _item]:
		var taken := _objectives.is_completed(item.objective_id)
		_expect(item.visible == not taken and item.enabled == not taken, "%s: %s must be on display exactly while its objective is not done." % [label, item.name])
	for door in [_g2, _g4]:
		_expect(not door.is_open or _objectives.is_completed(door.key_objective_id), "%s: %s is open without the card." % [label, door.door_name])
		_expect(door.enabled == not door.is_open and door.get_node("Panel").collision_layer == (0 if door.is_open else 1),
			"%s: %s's panel and interaction must match its state." % [label, door.door_name])
	_expect(not _objectives.is_completed(SHORTCUT) or _g3.is_open, "%s: the shortcut objective is done but the back gate is closed." % label)
	_expect(not (_g3.is_open and _objectives.get_state(SHORTCUT) == ACTIVE), "%s: the back gate is open but its objective is still ACTIVE." % label)
	_expect(_exit.is_unlocked() == (_objectives.current() == ESCAPE), "%s: the exit must be unlocked exactly when escape is current." % label)
	_expect(_hud.get_current_text() == _objectives.get_title(_objectives.current()), "%s: HUD shows '%s'." % [label, _hud.get_current_text()])
	var lines := _hud.get_lines()
	var ids := _objectives.get_ids()
	for i in ids.size():
		var mark: String = {COMPLETED: "[x]", ACTIVE: "[>]", LOCKED: "[ ]"}[_objectives.get_state(ids[i])]
		_expect(i < lines.size() and lines[i].begins_with(mark), "%s: HUD checklist line %d out of sync." % [label, i + 1])


## After a respawn: the snapshot is restored and consistent.
func _check_restored(label: String) -> void:
	await _frames(3)
	_expect(_objectives.get_progress() == _checkpoints.saved_progress, "%s: objective progress should equal the checkpoint's." % label)
	_expect(_checkpoints.get_mission_state() == _checkpoints.saved_state, "%s: door states should equal the checkpoint's." % label)
	_expect(_director.status == S.NONE and _player.process_mode != Node.PROCESS_MODE_DISABLED, "%s: the player should be back in control." % label)
	_check_consistency(label)


# --- Helpers ---------------------------------------------------------------------------------

func _load(keep_guards: bool) -> void:
	await _unload()
	_level = (load(SCENE) as PackedScene).instantiate()
	if not keep_guards:
		for g in _level.get_node("Guards").get_children():
			if g is Guard:
				g.get_parent().remove_child(g)
				g.free()
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, _level, Layout.SPAWN), "Navigation never became ready.")
	_map = _level.get_world_3d().navigation_map
	_player = _level.get_node("Player")
	_interactor = _player.get_node("Interactor")
	_objectives = _level.get_node_or_null("Gameplay/ObjectiveManager")
	_checkpoints = _level.get_node_or_null("Gameplay/CheckpointManager")
	_director = _level.get_node("StealthDirector")
	_hud = _level.get_node_or_null("ObjectiveHud")
	_card = _level.get_node_or_null("Gameplay/StaffAccessCard")
	_item = _level.get_node_or_null("Gameplay/RareManuscript")
	_exit = _level.get_node_or_null("Gameplay/ExitDoor")
	_g2 = _level.get_node_or_null("Gameplay/ArchiveFrontGateG2")
	_g3 = _level.get_node_or_null("Gameplay/ArchiveBackGateG3")
	_g4 = _level.get_node_or_null("Gameplay/LobbyStaffDoorG4")
	_sc1 = _level.get_node_or_null("Gameplay/ServiceShortcutSC1")
	_guard = null
	_route = null
	_escapes = 0
	if _exit:
		_exit.escaped.connect(func(): _escapes += 1)
	GameFlow.find(_level).change_scene = func(_path: String): pass
	await _frames(10)


func _unload() -> void:
	Engine.time_scale = 1.0
	_release_all()
	if _level and is_instance_valid(_level):
		_level.queue_free()
		_level = null
		await _frames(30)


func _checkpoint(i: int) -> Checkpoint:
	return _level.get_node("Gameplay/" + Layout.CHECKPOINTS[i].node)


## Where to aim at an interactable: its centre (doors: chest height).
func _aim(node: Node3D) -> Vector3:
	return node.global_position


func _teleport(at: Vector3) -> void:
	_player.global_position = at + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	await _frames(4)


func _stand_and_look(at: Vector3, target: Vector3) -> void:
	_player.global_position = at + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	await _look_at(target)


func _look_at(target: Vector3) -> void:
	var at := _player.global_position
	_player.rotation.y = atan2(-(target.x - at.x), -(target.z - at.z))
	var eye := at.y + _player.stand_eye_height
	var flat := Vector2(target.x - at.x, target.z - at.z).length()
	_player.head.rotation.x = atan2(target.y - eye, flat)
	await _frames(4)


## Presses and releases the interact key as real input events.
func _press_interact() -> void:
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(2)
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)


## Walks with real input (W held, turned toward the next path corner) from
## `from` across the wall at x = `wall_x` in direction `dir` (±1) for 2.5 s.
## Returns true if the player got 1 m past the wall.
func _push_through(from: Vector3, wall_x: float, dir: float) -> bool:
	await _teleport(from)
	_player.rotation.y = atan2(-dir, 0.0)
	_player.head.rotation.x = 0.0
	Input.action_press("move_forward")
	var crossed := false
	for i in 150:
		await _host.get_tree().physics_frame
		if (_player.global_position.x - wall_x) * dir > 1.0:
			crossed = true
			break
	_release_all()
	await _frames(4)
	return crossed


## Walks to `target` with real input along the navmesh path (sprinting).
func _walk_to(target: Vector3) -> Dictionary:
	var result := {"arrived": false, "distance": 0.0}
	var path := NavigationServer3D.map_get_path(_map, _player.global_position, target, true)
	if path.is_empty():
		return result
	var index := 0
	var anchor := _player.global_position
	var anchor_frame := 0
	var last := _player.global_position
	Input.action_press("sprint")
	Input.action_press("move_forward")
	for frame in 60 * 90:
		var here := _player.global_position
		result.distance += here.distance_to(last)
		last = here
		while index < path.size() - 1 and Vector2(path[index].x - here.x, path[index].z - here.z).length() < 0.45:
			index += 1
		if Vector2(target.x - here.x, target.z - here.z).length() < 0.4 and absf(target.y - here.y) < 0.8:
			result.arrived = true
			break
		var to := path[index] - here
		_player.rotation.y = atan2(-to.x, -to.z)
		if frame - anchor_frame >= 90:
			if here.distance_to(anchor) < 0.3:
				break
			anchor = here
			anchor_frame = frame
		await _host.get_tree().physics_frame
	_release_all()
	await _frames(6)
	return result


func _release_all() -> void:
	for a in ["move_forward", "move_backward", "move_left", "move_right", "sprint", "crouch"]:
		Input.action_release(a)


## A test guard at `guard_at` facing the player at `at` catches them; waits for the respawn.
func _catch_and_respawn(at: Vector3, guard_at: Vector3) -> void:
	var to_player := Vector2(at.x - guard_at.x, at.z - guard_at.z)
	_spawn_guard(guard_at, atan2(-to_player.x, -to_player.y))
	await _frames(3)
	await _teleport(at)
	await _until(func(): return _director.status == S.CAUGHT, 600)
	_expect(_director.status == S.CAUGHT, "The test guard should catch the player at %s." % at)
	await _until(func(): return _director.status != S.CAUGHT, int(_director.reset_delay * Engine.physics_ticks_per_second) + 30)
	_clear_guard()
	await _frames(5)


func _spawn_guard(at: Vector3, yaw: float) -> void:
	_clear_guard()
	_route = PatrolRoute.new()
	var post := PatrolPoint.new()
	post.position = at
	post.wait_time = 300.0
	_route.add_child(post)
	_level.add_child(_route)
	_guard = (load(GUARD_SCENE) as PackedScene).instantiate()
	_guard.name = "MissionTestGuard"
	_guard.patrol_route = _route
	_guard.position = at + Vector3(0, 0.05, 0)
	_guard.rotation.y = yaw
	_level.add_child(_guard)


func _clear_guard() -> void:
	if _guard and is_instance_valid(_guard):
		_guard.get_parent().remove_child(_guard)
		_guard.free()
	if _route and is_instance_valid(_route):
		_route.get_parent().remove_child(_route)
		_route.free()
	_guard = null
	_route = null


func _until(done: Callable, max_frames: int) -> void:
	for i in max_frames:
		if done.call():
			return
		await _host.get_tree().physics_frame


func _frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
