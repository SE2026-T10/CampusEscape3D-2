extends RefCounted

## Expanded Library expansion, Phase 4 (puzzles, journal and objectives).
## Called from tests/test_scene.gd.
##
##   A. The objective graph: matches the layout data and the scene patch;
##      every prerequisite exists; no cycle; no mandatory objective depends on
##      an optional one; the archive, the vault and the manuscript need their
##      prerequisites; every mandatory objective has a node that completes it;
##      no hint, title or clue states an answer.
##   B. ObjectiveManager graph mode on its own: parallel objectives, optional
##      ones never needed, level_completed once, restore keeps only consistent
##      progress, hidden objectives and discovery; linear mode unchanged.
##   C. Valid sequences with real input (E, looking, walking where it matters):
##      route 1 (tool kit first, power, card, code, manuscript, loading dock,
##      no optional objective) and route 2 (card first, the pump, the storm
##      drain), both to the WIN screen, the HUD and journal checked.
##   D. Invalid sequences: the archive without the card, the vault without the
##      code, the keypad without power, the manuscript before the vault, the
##      breakers behind the cover, wrong breakers (trip, alarm, guard
##      investigates, retry), wrong codes (alarm, lockout, retry), the exits
##      before their conditions, a stalled pump, a wrong locker combination.
##   E. The optional locker: reward and journal entry; optional objectives
##      never gate the mission.
##   F. Persistence (owner decision: puzzles follow checkpoints): progress
##      after the checkpoint is undone when caught, progress before it kept;
##      attempts, lockouts and alarms reset; the journal and discovered
##      objectives kept; everything still solvable afterwards; revisiting
##      documents never duplicates entries.

const SCENE := "res://scenes/level/expanded_library.tscn"
const GUARD_SCENE := "res://scenes/npc/guard.tscn"
const Layout := preload("res://tools/expanded/expanded_layout.gd")
const X := preload("res://tools/expanded/expansion/expansion_layout.gd")
const TestUtils := preload("res://tests/test_utils.gd")
const S := StealthDirector.Status
const ACTIVE := ObjectiveManager.State.ACTIVE
const COMPLETED := ObjectiveManager.State.COMPLETED
const LOCKED := ObjectiveManager.State.LOCKED
const B := X.BF
const U := Layout.UPPER_Y

const MANDATORY := [&"enter_library", &"take_card", &"find_toolkit", &"open_panel", &"restore_power", &"open_vault", &"take_manuscript", &"escape"]
const OPTIONAL := [&"unlock_shortcut", &"drain_culvert", &"security_locker"]
## The answers (only here, in the scene and in the clues).
const VAULT_CODE := "2691"
const LOCKER_CODE := "136"

## Standing spots (floor level).
const IN_LOBBY := Vector3(0, 0, 20)
const AT_PLAQUE := Vector3(-10.6, 0, 20)
const AT_TOOLKIT := Vector3(-24.8, B, -20.2)
const AT_PANEL := Vector3(41.0, 0, -25.9)
const AT_NOTICE := Vector3(44.5, 0, -24.0)
const AT_CHART := Vector3(26.0, 0, -26.6)
const AT_CARD := Vector3(4.9, U, -23.0)       # beside the desk, off the Staff Offices pad
const AT_MEMO := Vector3(10.6, U, -20.0)
const AT_ROTA := Vector3(4.6, U, -17.0)
const G2_WEST := Vector3(10.6, U, -11)
const AT_KEYPAD := Vector3(26.7, U, -19.3)
const IN_VAULT := Vector3(32, U, -23.6)   # as the mission tests: at the pedestal
const AT_DOCK := Vector3(34.3, 0, 24)
const AT_PUMP := Vector3(0.0, B, -15.5)
const AT_PUMP_LOG := Vector3(5.6, B, -17.0)
const AT_DRAIN := Vector3(0.0, B, -34.6)
const AT_LOCKER := Vector3(-4.7, U, -21.4)
const IN_TUNNEL := Vector3(-30.0, B, -25.0)

var failures: Array[String] = []
var _host: Node
var _level: Node3D
var _player: FirstPersonPlayer
var _inventory: PlayerInventory
var _interactor: PlayerInteractor
var _objectives: ObjectiveManager
var _checkpoints: CheckpointManager
var _director: StealthDirector
var _hud: ObjectiveHud
var _alarm: SecurityAlarm
var _power: PowerNetwork
var _cover: ToolMechanism
var _breakers: BreakerPanel
var _keypad: CodeLock
var _locker: CodeLock
var _crank: ToolMechanism
var _pump: PumpControl
var _vault_door: AccessDoor
var _drain_exit: ExitDoor
var _dock_exit: ExitDoor
var _card: AccessCard
var _manuscript: AccessCard
var _g2: AccessDoor
var _guard: Node3D
var _route: Node3D
var _feedback: Array[String] = []


func run(host: Node) -> Array[String]:
	_host = host
	_check_graph_unit()
	await _load()
	_check_graph_data()
	await _check_route_dock()
	await _load()
	await _check_route_drain()
	await _load()
	await _check_invalid_sequences()
	await _load()
	await _check_optional_locker()
	await _load()
	await _check_persistence()
	await _unload()
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[expansion-puzzles] " + message)


# --- A. The objective graph ----------------------------------------------------------------------

func _check_graph_data() -> void:
	var ids := _objectives.get_ids()
	var layout_ids: Array[StringName] = []
	for o in X.MISSION_OBJECTIVES:
		layout_ids.append(StringName(o.id))
	_expect(ids == layout_ids, "The scene's objectives should be the layout's MISSION_OBJECTIVES (%s vs %s)." % [ids, layout_ids])
	for o in X.MISSION_OBJECTIVES:
		var id := StringName(o.id)
		_expect(_objectives.get_title(id) == o.title and _objectives.get_hint(id) == o.hint, "%s: title / hint differ from the layout." % id)
		_expect(_objectives.is_optional(id) == o.get("optional", false), "%s: optional flag differs." % id)
	_expect(_objectives.is_graph() and _objectives.get_mandatory_ids() == MANDATORY and _objectives.get_optional_ids() == OPTIONAL,
		"Mandatory %s and optional %s objectives." % [_objectives.get_mandatory_ids(), _objectives.get_optional_ids()])
	# Prerequisites exist, no cycle (a topological order exists), mandatory never needs optional.
	var order: Array[StringName] = []
	var remaining := ids.duplicate()
	while not remaining.is_empty():
		var ready := remaining.filter(func(id): return _objectives.get_requires(id).all(func(r): return order.has(r)))
		if ready.is_empty():
			break
		for id in ready:
			order.append(id)
			remaining.erase(id)
	_expect(remaining.is_empty(), "The objective graph has a cycle or a missing prerequisite: %s." % [remaining])
	for id in ids:
		for r in _objectives.get_requires(id):
			_expect(ids.has(r), "%s requires an unknown objective %s." % [id, r])
			_expect(_objectives.is_optional(id) or not _objectives.is_optional(r), "Mandatory %s must not require optional %s." % [id, r])
	# The required prerequisites.
	_expect(_objectives.get_requires(&"open_vault").has(&"take_card") and _objectives.get_requires(&"open_vault").has(&"restore_power"),
		"Opening the vault needs the card (the archive) and the power.")
	_expect(_objectives.get_requires(&"take_manuscript") == [&"open_vault"], "The manuscript needs the vault open.")
	_expect(_objectives.get_requires(&"escape") == [&"take_manuscript"], "Escaping needs the manuscript.")
	_expect(_vault_door.key_objective_id == &"open_vault" and _keypad.door_path != NodePath() and _manuscript.objective_id == &"take_manuscript",
		"The vault door is keyed to open_vault and opened by the keypad; the manuscript completes take_manuscript.")
	_expect(_g2.key_item == ItemCatalog.STAFF_CARD, "The archive (G2) needs the carried staff card.")
	# Every mandatory objective has something in the level that completes it.
	var completers := {
		&"enter_library": _level.get_node_or_null("Gameplay/EnterLibraryTrigger"), &"take_card": _card,
		&"find_toolkit": _level.get_node_or_null("Expansion/Gameplay/Items/ToolKit"), &"open_panel": _cover,
		&"restore_power": _breakers, &"open_vault": _keypad, &"take_manuscript": _manuscript, &"escape": _dock_exit}
	for id in completers:
		var node = completers[id]
		_expect(node != null and node.get("objective_id") == id, "Nothing completes %s (%s)." % [id, node])
	_expect(_drain_exit.objective_id == &"escape" and _drain_exit.extra_key_objective_id == &"drain_culvert", "The storm drain is a second escape, needing the culvert drained.")
	# No answer in any hint, title or clue text.
	for id in ids:
		var t := _objectives.get_title(id) + " " + _objectives.get_hint(id) + " " + _objectives.get_done_message(id)
		_expect(not t.contains(VAULT_CODE) and not t.contains(LOCKER_CODE), "%s's texts must not give a code away." % id)
	for doc in _level.get_tree().get_nodes_in_group("documents"):
		_expect(not doc.text.contains(VAULT_CODE) and not doc.text.contains(LOCKER_CODE), "%s must not state a code outright." % doc.name)
	print("  [expansion-puzzles] graph: %d objectives (%d mandatory, %d optional), topological order %s; no cycle, no mandatory → optional edge; no code in any text" % [
		ids.size(), MANDATORY.size(), OPTIONAL.size(), " → ".join(order)])


# --- B. ObjectiveManager graph mode --------------------------------------------------------------

func _check_graph_unit() -> void:
	var m := ObjectiveManager.new()
	var finished := [0]
	m.level_completed.connect(func(): finished[0] += 1)
	m.setup([{"id": "a"}, {"id": "b", "requires": ["a"]}, {"id": "c", "requires": ["a"]}, {"id": "d", "requires": ["b", "c"]},
		{"id": "o", "optional": true, "hidden": true}, {"id": "p", "optional": true, "requires": ["d"]}])
	_expect(m.is_graph() and m.get_state(&"a") == ACTIVE and m.get_state(&"o") == ACTIVE and m.get_state(&"b") == LOCKED, "Graph start states.")
	_expect(not m.complete(&"b") and m.complete(&"a"), "Only ACTIVE objectives complete.")
	_expect(m.get_state(&"b") == ACTIVE and m.get_state(&"c") == ACTIVE and m.current() == &"b", "Two objectives ACTIVE in parallel; current() is the first.")
	_expect(m.complete(&"c") and m.get_state(&"d") == LOCKED and m.complete(&"b") and m.get_state(&"d") == ACTIVE, "Any order; d needs both.")
	_expect(not m.is_visible(&"o") and m.discover(&"o") and m.is_visible(&"o") and not m.discover(&"o"), "Hidden until discovered, once.")
	var snapshot := m.get_progress()
	_expect(m.complete(&"d") and m.is_finished() and finished[0] == 1, "The last mandatory objective finishes the level, optional ones open.")
	_expect(m.complete(&"o") and finished[0] == 1, "Completing an optional objective afterwards doesn't finish it again.")
	m.restore(snapshot)
	_expect(m.get_state(&"d") == ACTIVE and not m.is_finished() and m.get_state(&"o") == ACTIVE and m.is_discovered(&"o"),
		"restore() goes back to the snapshot; discovery is kept.")
	m.restore({&"d": COMPLETED, &"a": COMPLETED})
	_expect(m.get_state(&"a") == COMPLETED and m.get_state(&"d") == LOCKED and m.get_state(&"b") == ACTIVE,
		"restore() drops a COMPLETED objective whose prerequisites are not completed.")
	_expect(m.try_complete(&"b") and not m.try_complete(&"d") and not m.try_complete(&""), "try_complete only completes ACTIVE ones.")
	m.free()
	# Linear mode is untouched (the tutorial's flow).
	var l := ObjectiveManager.new()
	l.setup(ObjectiveManager.MVP_OBJECTIVES)
	_expect(not l.is_graph() and l.current() == ObjectiveManager.ENTER_LIBRARY and not l.complete(ObjectiveManager.TAKE_CARD), "Linear mode as before.")
	l.complete(ObjectiveManager.ENTER_LIBRARY)
	_expect(l.current() == ObjectiveManager.REACH_RESTRICTED and l.get_mandatory_ids().size() == 5, "Linear: one ACTIVE objective at a time.")
	l.free()
	print("  [expansion-puzzles] ObjectiveManager graph mode: parallel objectives, any order, optional never needed, finish once, consistent restore, hidden/discover; linear mode unchanged")


# --- C. Valid sequences --------------------------------------------------------------------------

func _check_route_dock() -> void:
	var log := []
	await _teleport(IN_LOBBY)
	_expect(_objectives.is_completed(&"enter_library") and _objectives.get_state(&"take_card") == ACTIVE and _objectives.get_state(&"find_toolkit") == ACTIVE,
		"Entering: the card and the tool kit are both open, in any order.")
	_expect(_journal_text_all().find(VAULT_CODE) < 0, "Nothing reveals the code before the clues are found.")
	await _use(_doc("LobbyPlaque"), AT_PLAQUE)
	_expect(_inventory.has_document(&"lobby_plaque"), "The plaque is a clue in the journal.")
	# The tool kit, then the panel cover with it.
	await _use(_level.get_node("Expansion/Gameplay/Items/ToolKit"), AT_TOOLKIT)
	_expect(_objectives.is_completed(&"find_toolkit") and _objectives.get_state(&"open_panel") == ACTIVE, "Tool kit found; the panel comes up.")
	await _use(_doc("ElectricalNotice"), AT_NOTICE)
	await _use(_cover, AT_PANEL)
	_expect(_cover.is_operated and _objectives.is_completed(&"open_panel") and _inventory.has(ItemCatalog.TOOLKIT), "Cover off with the tool kit (kept).")
	log.append("cover")
	# The wiring chart, then the breakers: A1, A3, A4 on; MAIN.
	await _use(_doc("WiringChart"), AT_CHART)
	for i in [0, 2, 3]:
		await _use(_breakers.breakers[i], AT_PANEL)
	await _use(_breakers.main_switch, AT_PANEL)
	_expect(_breakers.is_solved and _power.is_powered(&"archive_vault") and _objectives.is_completed(&"restore_power"), "The right breakers power the vault.")
	_expect(_hud.get_message_text().contains("Power restored"), "Power feedback (%s)." % _hud.get_message_text())
	log.append("power")
	# The card, the memo, the archive.
	await _use(_card, AT_CARD)
	await _use(_doc("ArchivistMemo"), AT_MEMO)
	await _use(_g2, G2_WEST)
	_expect(_g2.is_open and _objectives.get_state(&"open_vault") == ACTIVE, "The archive is open and the vault comes up.")
	_expect(_keypad.has_power() and _keypad.get_display_text().contains("ENTER CODE"), "The keypad has power (%s)." % _keypad.get_display_text())
	await _enter_code(_keypad, VAULT_CODE, AT_KEYPAD)
	_expect(_keypad.is_solved and _vault_door.is_open and _objectives.is_completed(&"open_vault"), "The code opens the vault.")
	log.append("vault")
	await _use(_manuscript, IN_VAULT)
	_expect(_objectives.is_completed(&"take_manuscript") and _objectives.get_state(&"escape") == ACTIVE and _dock_exit.is_unlocked(), "Manuscript taken; the dock is open.")
	_expect(not _drain_exit.is_unlocked(), "The storm drain stays shut (culvert not drained).")
	_expect(_hud.get_header_text() == "MISSION 7/8", "HUD header %s." % _hud.get_header_text())
	await _use(_dock_exit, AT_DOCK)
	var flow := GameFlow.find(_level)
	_expect(_objectives.is_finished() and _director.status == S.ESCAPED and flow.state == GameStateMachine.State.WIN,
		"Escaping through the dock wins (state %s)." % flow.state)
	_expect(OPTIONAL.all(func(id): return not _objectives.is_completed(id)), "The mission is won with no optional objective done.")
	var menus: GameMenus = _level.get_node("GameMenus")
	_expect(menus.get_objectives_text() == "Mission objectives 8/8 complete · optional 0/3", "Win text: %s." % menus.get_objectives_text())
	print("  [expansion-puzzles] route 1 (real input): plaque → tool kit → notice → %s → card → memo → G2 → code → manuscript → loading dock: WIN, 0/3 optional" % " → ".join(log))


func _check_route_drain() -> void:
	await _teleport(IN_LOBBY)
	# Card first this time.
	await _use(_card, AT_CARD)
	_expect(_objectives.is_completed(&"take_card") and _objectives.get_state(&"open_vault") == LOCKED, "Card first: the vault still needs power.")
	await _use(_g2, G2_WEST)
	await _stand_and_look(AT_KEYPAD, _keypad.dials[0].global_position)
	_expect(_hud.get_prompt_text().contains("no power"), "The unpowered keypad says so (%s)." % _hud.get_prompt_text())
	await _use(_level.get_node("Expansion/Gameplay/Items/ToolKit"), AT_TOOLKIT)
	# The optional pump: discovered by its log.
	_expect(not _objectives.is_visible(&"drain_culvert") and not _hud.get_lines().any(func(l): return l.contains("culvert")), "The pump objective is hidden at first.")
	await _use(_doc("PumpRoomLog"), AT_PUMP_LOG)
	_expect(_objectives.is_visible(&"drain_culvert") and _hud.get_lines().any(func(l): return l.contains("(optional) Drain the storm culvert")), "Reading the log reveals it, as optional.")
	await _use(_crank, AT_PUMP + Vector3(-3.4, 0, 0))
	for i in [0, 2]:
		await _use(_pump.valves[i], AT_PUMP + Vector3(_pump.valves[i].global_position.x, 0, 0))
	await _use(_pump.start_lever, AT_PUMP + Vector3(_pump.start_lever.global_position.x, 0, 0))
	var grate := _level.get_node("Expansion/Geometry/G_ServiceNetwork/StormDrainGrate") as StaticBody3D
	_expect(_pump.is_solved and _objectives.is_completed(&"drain_culvert") and not grate.visible and grate.collision_layer == 0,
		"The pump drains the culvert and clears the grate.")
	_expect(not (_level.get_node("Expansion/Dressing/Signs/Sign_STORMDRAINSEALED") as Node3D).visible, "The STORM DRAIN · SEALED sign goes once it is drained.")
	# Power and vault.
	await _use(_cover, AT_PANEL)
	_breakers.set_setting([true, false, true, true])
	await _use(_breakers.main_switch, AT_PANEL)
	await _enter_code(_keypad, VAULT_CODE, AT_KEYPAD)
	await _use(_manuscript, IN_VAULT)
	# Out through the storm drain.
	await _stand_and_look(AT_DRAIN, _drain_exit.global_position)
	_expect(_interactor.focused == _drain_exit and _hud.get_prompt_text() == "[E] Escape", "Storm drain prompt: %s." % _hud.get_prompt_text())
	await _press("interact")
	_expect(_objectives.is_finished() and _director.status == S.ESCAPED and GameFlow.find(_level).state == GameStateMachine.State.WIN, "Escaping through the storm drain wins.")
	print("  [expansion-puzzles] route 2 (real input): card → G2 (keypad: no power) → tool kit → pump log (optional revealed) → crank → valves 1+3 → START (grate cleared) → power → code → manuscript → storm drain: WIN")


# --- D. Invalid sequences ------------------------------------------------------------------------

func _check_invalid_sequences() -> void:
	var noise := NoiseSystem.find(_level)
	await _teleport(IN_LOBBY)
	# The archive without the card.
	await _stand_and_look(G2_WEST, _aim(_g2))
	_expect(not _interactor.try_interact() and not _g2.is_open, "G2 refuses without the card.")
	# The vault door from inside the archive (teleported), without the code.
	await _stand_and_look(Vector3(26.6, U, -21), _aim(_vault_door))
	_expect(_interactor.focused == _vault_door and _hud.get_prompt_text() == "[E] Vault Door · locked (vault code needed)", "Vault door prompt: %s." % _hud.get_prompt_text())
	_expect(not _interactor.try_interact() and not _vault_door.is_open, "The vault door can't be opened by hand.")
	_expect(not await _push_through(Vector3(26.4, U, -21), 28.0, 1.0), "The closed vault door stops the player.")
	# The manuscript before the vault is open (teleported in).
	await _stand_and_look(IN_VAULT, _aim(_manuscript))
	_expect(_hud.get_prompt_text() == "[E] Rare manuscript (not yet)" and not _interactor.try_interact() and _manuscript.visible, "The manuscript can't be taken before the vault puzzle.")
	# The keypad without power.
	await _enter_code(_keypad, VAULT_CODE, AT_KEYPAD, false)
	_keypad.set_entry(VAULT_CODE)
	await _use(_keypad.enter, AT_KEYPAD)
	_expect(not _keypad.is_solved and not _vault_door.is_open and _keypad.get_display_text().contains("NO POWER"), "No power: even the right code does nothing.")
	_expect(_hud.get_message_text().contains("no power"), "No-power feedback (%s)." % _hud.get_message_text())
	# The breakers behind the cover; the cover without the tool kit.
	await _stand_and_look(AT_PANEL, _breakers.breakers[0].global_position)
	_expect(_interactor.focused == _cover and _hud.get_prompt_text() == "[E] Electrical panel cover · locked (tool kit needed)", "The cover is in front: %s." % _hud.get_prompt_text())
	_expect(not _interactor.try_interact() and not _cover.is_operated, "The cover needs the tool kit.")
	_expect(not _breakers.breakers[0].interact(_player) and _breakers.breakers[0].index == 0, "Breakers can't be used behind the cover.")
	_breakers.engage()
	_expect(not _breakers.is_solved and _breakers.trips == 0, "MAIN does nothing behind the cover.")
	# Wrong breakers: trip, alarm, a guard investigates, the breakers reset; then the right setting works.
	await _use(_level.get_node("Expansion/Gameplay/Items/ToolKit"), AT_TOOLKIT)
	await _use(_cover, AT_PANEL)
	_spawn_guard(Vector3(38.0, 0, -20.0), PI)   # in the electrical room, facing south, away from the panel
	await _frames(5)
	var alarms := _alarm.alarms_raised
	for i in [0, 1, 2, 3]:
		await _use(_breakers.breakers[i], AT_PANEL)   # all four ON: A2 must stay off
	await _use(_breakers.main_switch, AT_PANEL)
	_expect(_breakers.trips == 1 and not _breakers.is_solved and not _power.is_powered(&"archive_vault"), "Wrong breakers trip the main.")
	_expect(_breakers.get_setting() == [false, false, false, false], "The breakers drop back to OFF.")
	_expect(_alarm.alarms_raised == alarms + 1 and _alarm.is_active(), "A trip sounds the alarm.")
	var stealth: StealthHud = _level.get_node("StealthHud")
	await _frames(2)
	_expect(stealth._banner.text.begins_with("ALARM"), "The HUD shows the alarm (%s)." % stealth._banner.text)
	_expect(_hud.get_message_text().contains("tripped") and not _hud.get_message_text().contains("A1"), "Trip feedback, no answer: %s." % _hud.get_message_text())
	var investigated := await _until_true(func(): return _guard.machine.current == GuardStateMachine.INVESTIGATE, 120)
	_expect(investigated, "A guard in the room investigates the trip.")
	_clear_guard()
	_breakers.set_setting([true, false, true, true])
	_breakers.engage()
	_expect(_breakers.is_solved and _power.is_powered(&"archive_vault"), "The right setting works right after a trip.")
	# Wrong codes: an alarm each, a lockout after three, then the right code works.
	_inventory.add(ItemCatalog.STAFF_CARD)
	_objectives.complete(&"take_card")
	alarms = _alarm.alarms_raised
	for k in 3:
		await _enter_code(_keypad, "1234", AT_KEYPAD)
	_expect(not _keypad.is_solved and _keypad.wrong_attempts == 3 and _alarm.alarms_raised == alarms + 3, "Three wrong codes: three alarms.")
	_expect(_keypad.lockout_left > 0.0 and _keypad.get_display_text().contains("LOCKED OUT"), "Locked out after three (%s)." % _keypad.get_display_text())
	_expect(_hud.get_message_text().contains("Locked out") and not _hud.get_message_text().contains(VAULT_CODE), "Lockout feedback: %s." % _hud.get_message_text())
	_keypad.set_entry(VAULT_CODE)
	_keypad.submit()
	_expect(not _keypad.is_solved, "Even the right code is refused during the lockout.")
	Engine.time_scale = 8.0
	await _until_true(func(): return _keypad.lockout_left == 0.0, 600)
	Engine.time_scale = 1.0
	_expect(_keypad.attempts_left == 3, "After the lockout: fresh tries.")
	await _enter_code(_keypad, VAULT_CODE, AT_KEYPAD)
	_expect(_keypad.is_solved and _vault_door.is_open, "The right code after the lockout opens the vault.")
	# Exits before their conditions.
	var before := noise.emitted_count
	await _stand_and_look(AT_DOCK, _aim(_dock_exit))
	_expect(not _interactor.try_interact() and _director.status != S.ESCAPED, "The dock refuses without the manuscript.")
	_expect(_hud.get_message_text() == "The loading dock exit is sealed until you have the rare manuscript.", "Dock message: %s." % _hud.get_message_text())
	await _use(_manuscript, IN_VAULT)
	await _stand_and_look(AT_DRAIN, _drain_exit.global_position)
	_expect(_hud.get_prompt_text() == "[E] Storm drain (blocked)" and not _interactor.try_interact() and _director.status != S.ESCAPED,
		"The storm drain refuses with the manuscript but the culvert flooded.")
	_expect(_hud.get_message_text() == "The grate is jammed shut while the culvert is flooded.", "Drain message: %s." % _hud.get_message_text())
	_expect(noise.emitted_count > before, "Rattling the exits makes noise.")
	# The pump: a stall, then the right valves.
	await _use(_crank, AT_PUMP + Vector3(-3.4, 0, 0))
	var stall_noise := noise.emitted_count
	await _use(_pump.start_lever, AT_PUMP + Vector3(_pump.start_lever.global_position.x, 0, 0))   # all valves shut
	_expect(_pump.stalls == 1 and not _pump.is_solved and noise.emitted_count > stall_noise, "Wrong valves stall the pump loudly.")
	_expect(_hud.get_message_text().contains("stalls") and not _hud.get_message_text().contains("middle"), "Stall feedback: %s." % _hud.get_message_text())
	_pump.set_setting([true, false, true])
	_pump.start()
	_expect(_pump.is_solved and _drain_exit.is_unlocked(), "The right valves after a stall drain it; the drain is open (solved %s, culvert %s, escape %s, manuscript %s)." % [
		_pump.is_solved, _objectives.get_state(&"drain_culvert"), _objectives.get_state(&"escape"), _objectives.get_state(&"take_manuscript")])
	print("  [expansion-puzzles] invalid: G2 without card, vault door by hand (blocked), manuscript early, keypad unpowered, breakers behind the cover all refused; wrong breakers → trip + alarm + guard investigates, retry ok; 3 wrong codes → 3 alarms + 20 s lockout, then ok; exits refused until their conditions; pump stall, retry ok")


# --- E. The optional locker ----------------------------------------------------------------------

func _check_optional_locker() -> void:
	await _teleport(IN_LOBBY)
	var bottle: ItemPickup = _level.get_node("Expansion/Gameplay/Items/LockerBottle")
	var notes: DocumentPickup = _doc("PatrolNotes")
	_expect(not bottle.visible and not bottle.enabled and not notes.visible, "The locker's contents are not there before it is opened.")
	_expect(not _objectives.is_visible(&"security_locker"), "The locker objective is hidden at first.")
	await _use(_doc("NightRota"), AT_ROTA)
	_expect(_objectives.is_visible(&"security_locker"), "The rota reveals the locker objective.")
	var alarms := _alarm.alarms_raised
	await _enter_code(_locker, "999", AT_LOCKER)
	_expect(not _locker.is_solved and _alarm.alarms_raised == alarms and _hud.get_message_text().contains("rejected"), "A wrong combination: refused, no alarm (a small noise).")
	await _enter_code(_locker, LOCKER_CODE, AT_LOCKER)
	_expect(_locker.is_solved and _objectives.is_completed(&"security_locker") and bottle.visible and notes.visible, "The right combination opens it: a bottle and patrol notes.")
	await _use(notes, Vector3(-4.6, U, -23.3))
	_expect(_inventory.has_document(&"patrol_notes"), "The patrol notes go to the journal.")
	_expect(not _objectives.is_finished() and _objectives.current() == &"take_card", "An optional objective doesn't move the mission.")
	await _press("journal")   # opened by reading: J closes it
	_expect(not _hud.is_journal_open(), "J closes a journal opened by reading.")
	await _press("journal")   # opened with J: pages through the documents
	var text := _hud.get_journal_text()
	_expect(text.contains("MISSION") and text.contains("OPTIONAL") and text.contains("[x] Open the security locker") and text.contains("CLUES") == false,
		"The journal lists the mission and the optional objectives apart (%s)." % text.left(200))
	await _press("journal")
	await _press("journal")
	print("  [expansion-puzzles] optional locker: hidden until the rota, wrong combination refused (no alarm), right one → bottle + patrol notes; mission unaffected")


# --- F. Persistence ------------------------------------------------------------------------------

func _check_persistence() -> void:
	var study: Checkpoint = _level.get_node("Gameplay/" + Layout.CHECKPOINTS[0].node)
	await _teleport(IN_LOBBY)
	await _use(_level.get_node("Expansion/Gameplay/Items/ToolKit"), AT_TOOLKIT)
	await _use(_doc("WiringChart"), AT_CHART)
	_checkpoints.activate(study)   # saved: tool kit carried, nothing solved
	# Solved after the checkpoint: cover, power; a document read; the pump log read.
	await _use(_cover, AT_PANEL)
	_breakers.set_setting([true, false, true, true])
	await _use(_breakers.main_switch, AT_PANEL)
	await _use(_doc("PumpRoomLog"), AT_PUMP_LOG)
	_expect(_breakers.is_solved and _objectives.is_completed(&"restore_power"), "Power restored after the checkpoint.")
	await _catch_and_respawn(IN_TUNNEL, IN_TUNNEL + Vector3(5, 0, 0))
	_expect(not _cover.is_operated and not _breakers.is_solved and not _power.is_powered(&"archive_vault") and _breakers.get_setting() == [false, false, false, false],
		"Caught: the cover, breakers and power are back as at the checkpoint.")
	_expect(_objectives.get_state(&"open_panel") == ACTIVE and _objectives.get_state(&"restore_power") == LOCKED, "Their objectives are undone too.")
	_expect(_inventory.has_document(&"pump_room_log") and _inventory.has_document(&"wiring_chart") and _objectives.is_visible(&"drain_culvert"),
		"The journal and the discovered optional objective are kept.")
	_expect(_inventory.has(ItemCatalog.TOOLKIT), "The tool kit (carried at the checkpoint) is kept.")
	_check_consistency("after catch 1")
	# Solve again and save; then a wrong code and a lockout; caught → solved puzzles kept, attempts reset.
	await _use(_cover, AT_PANEL)
	_breakers.set_setting([true, false, true, true])
	_breakers.engage()
	if not _inventory.has(ItemCatalog.STAFF_CARD):
		_inventory.add(ItemCatalog.STAFF_CARD)
	_objectives.complete(&"take_card")
	_checkpoints.activate(study)
	for k in 3:
		await _enter_code(_keypad, "0000", AT_KEYPAD)
	_expect(_keypad.lockout_left > 0.0 and _alarm.is_active(), "Locked out, alarm sounding.")
	await _catch_and_respawn(IN_TUNNEL, IN_TUNNEL + Vector3(5, 0, 0))
	_expect(_breakers.is_solved and _power.is_powered(&"archive_vault") and _cover.is_operated, "Saved puzzles stay solved.")
	_expect(_keypad.lockout_left == 0.0 and _keypad.attempts_left == 3 and not _alarm.is_active(), "Respawn: fresh tries, no lockout, no alarm.")
	# The vault opened and the manuscript taken after the checkpoint: undone, then solvable again.
	await _enter_code(_keypad, VAULT_CODE, AT_KEYPAD)
	await _use(_manuscript, IN_VAULT)
	_expect(_objectives.get_state(&"escape") == ACTIVE, "Manuscript taken.")
	await _catch_and_respawn(IN_TUNNEL, IN_TUNNEL + Vector3(5, 0, 0))
	_expect(not _keypad.is_solved and not _vault_door.is_open and _manuscript.visible and _objectives.get_state(&"open_vault") == ACTIVE,
		"Caught: the vault is closed and the manuscript back, the keypad unsolved.")
	_check_consistency("after catch 3")
	await _enter_code(_keypad, VAULT_CODE, AT_KEYPAD)
	await _use(_manuscript, IN_VAULT)
	_expect(_objectives.get_state(&"escape") == ACTIVE and _dock_exit.is_unlocked(), "Everything is still solvable after the captures.")
	# Revisiting documents never duplicates journal entries.
	var count := _inventory.documents.size()
	await _use(_doc("WiringChart"), AT_CHART)
	await _use(_doc("PumpRoomLog"), AT_PUMP_LOG)
	_expect(_inventory.documents.size() == count, "Re-reading documents adds nothing (%d → %d)." % [count, _inventory.documents.size()])
	_check_consistency("after revisits")
	print("  [expansion-puzzles] persistence: puzzles solved after the checkpoint undone when caught (objectives too), saved ones kept; tries/lockout/alarm reset; journal (%d entries) and discovered objectives kept; still solvable; no duplicate entries" % count)


## Puzzles and objectives agree.
func _check_consistency(label: String) -> void:
	var pairs := [[_cover.is_operated, &"open_panel"], [_breakers.is_solved, &"restore_power"], [_keypad.is_solved, &"open_vault"],
		[_pump.is_solved, &"drain_culvert"], [_locker.is_solved, &"security_locker"]]
	for p in pairs:
		var done: bool = _objectives.is_completed(p[1])
		var active: bool = _objectives.get_state(p[1]) == ACTIVE
		_expect(done == p[0] or (not done and not active and p[0]), "%s: %s is %s but its puzzle solved=%s." % [label, p[1], _objectives.get_state(p[1]), p[0]])
	_expect(_power.is_powered(&"archive_vault") == _breakers.is_solved, "%s: power and breakers disagree." % label)
	_expect(_vault_door.is_open == _keypad.is_solved, "%s: vault door and keypad disagree." % label)
	_expect(_manuscript.visible == not _objectives.is_completed(&"take_manuscript"), "%s: manuscript and objective disagree." % label)


# --- Helpers ---------------------------------------------------------------------------------

func _load() -> void:
	await _unload()
	_level = (load(SCENE) as PackedScene).instantiate()
	for g in _level.get_node("Guards").get_children():
		if g is Guard:
			g.get_parent().remove_child(g)
			g.free()
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, _level, Layout.SPAWN), "Navigation never became ready.")
	_player = _level.get_node("Player")
	_inventory = _player.get_node("Inventory")
	_interactor = _player.get_node("Interactor")
	_objectives = _level.get_node("Gameplay/ObjectiveManager")
	_checkpoints = _level.get_node("Gameplay/CheckpointManager")
	_director = _level.get_node("StealthDirector")
	_hud = _level.get_node("ObjectiveHud")
	var m := "Expansion/Gameplay/Mission/"
	_alarm = _level.get_node(m + "SecurityAlarm")
	_power = _level.get_node(m + "PowerNetwork")
	_cover = _level.get_node(m + "ElectricalPanelCover")
	_breakers = _level.get_node(m + "BreakerPanel")
	_keypad = _level.get_node(m + "VaultKeypad")
	_locker = _level.get_node(m + "SecurityLocker")
	_crank = _level.get_node(m + "PumpCrank")
	_pump = _level.get_node(m + "PumpControl")
	_drain_exit = _level.get_node(m + "StormDrainExit")
	_vault_door = _level.get_node("Expansion/Gameplay/VaultDoor")
	_dock_exit = _level.get_node("Gameplay/ExitDoor")
	_card = _level.get_node("Gameplay/StaffAccessCard")
	_manuscript = _level.get_node("Gameplay/RareManuscript")
	_g2 = _level.get_node("Gameplay/ArchiveFrontGateG2")
	_guard = null
	_route = null
	GameFlow.find(_level).change_scene = func(_path: String): pass
	await _frames(10)


func _unload() -> void:
	Engine.time_scale = 1.0
	_release_all()
	_clear_guard()
	if _level and is_instance_valid(_level):
		_level.queue_free()
		_level = null
		await _frames(30)


func _doc(node_name: String) -> DocumentPickup:
	return _level.get_node("Expansion/Gameplay/Documents/" + node_name)


func _journal_text_all() -> String:
	var t := ""
	for d in _inventory.documents:
		t += d.text
	return t


func _aim(node: Node3D) -> Vector3:
	return node.global_position


## Stands at `at`, looks at `target`, checks it is focused and presses E `times` times.
func _use(target: Node3D, at: Vector3, times := 1) -> void:
	await _stand_and_look(at, _aim(target))
	_expect(_interactor.focused == target, "%s should be in reach from %s (focused %s, prompt %s)." % [
		target.name, at, _interactor.focused.name if _interactor.focused else "nothing", _hud.get_prompt_text()])
	for k in times:
		await _press("interact")


## Turns each dial with E to the code's digit, then presses ENTER (unless submit is false).
func _enter_code(lock: CodeLock, code: String, at: Vector3, submit := true) -> void:
	for i in code.length():
		var dial := lock.dials[i]
		var turns := (int(code[i]) - dial.index + 10) % 10
		if dial.blocked_reason != "":
			continue
		await _use(dial, at, turns)
	if submit:
		await _use(lock.enter, at)


func _teleport(at: Vector3) -> void:
	_player.global_position = at + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	await _frames(4)


func _stand_and_look(at: Vector3, target: Vector3) -> void:
	_player.global_position = at + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	await _frames(2)
	var eye := at.y + _player.stand_eye_height
	_player.rotation.y = atan2(-(target.x - at.x), -(target.z - at.z))
	_player.head.rotation.x = atan2(target.y - eye, Vector2(target.x - at.x, target.z - at.z).length())
	await _frames(4)


func _press(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(2)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)


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


func _release_all() -> void:
	for a in ["move_forward", "move_backward", "move_left", "move_right", "sprint", "crouch"]:
		Input.action_release(a)


func _catch_and_respawn(at: Vector3, guard_at: Vector3) -> void:
	var to_player := Vector2(at.x - guard_at.x, at.z - guard_at.z)
	_spawn_guard(guard_at, atan2(-to_player.x, -to_player.y))
	await _frames(3)
	await _teleport(at)
	await _until_true(func(): return _director.status == S.CAUGHT, 600)
	_expect(_director.status == S.CAUGHT, "The test guard should catch the player at %s." % at)
	await _until_true(func(): return _director.status != S.CAUGHT, int(_director.reset_delay * Engine.physics_ticks_per_second) + 30)
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
	_guard.name = "PuzzleTestGuard"
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


func _until_true(done: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if done.call():
			return true
		await _host.get_tree().physics_frame
	return done.call()


func _frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
