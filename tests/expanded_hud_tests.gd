extends RefCounted

## Expansion Phase 7: HUD and accessibility. Called from tests/test_scene.gd.
##
##   A. Settings: defaults without a file; save → load round trip; broken or
##      out-of-range values fall back; apply() sets the window's interface size
##      and the Master bus; the settings screen's controls change and save them;
##      the main menu and the pause menu open it; Esc closes it without leaving
##      the pause menu.
##   B. The HUD reads the game: stamina bar (and EXHAUSTED while the sprint key
##      is held after running dry), three slots = the inventory, the objective
##      checklist = ObjectiveManager, the journal = clues and documents only.
##   C. Ways out, power, checkpoint (Expanded Library): nothing before entering;
##      on entering the main entrance and the dock with what is known; the
##      badge's place after the locker; the dock's power, control and release
##      only once met; the hidden passage only after its plan; [x] follows the
##      real state; POWER after the switches are seen; the checkpoint name.
##   D. Exits name only known requirements; the hidden passage, the release,
##      codes and the panel never show before they are found.
##   E. After a capture: journal and clues kept, the lists recomputed from the
##      restored state (a route opened after the checkpoint shows closed again).
##   F. Captions: alarm, distraction, switch, stingers, nearby guard footsteps,
##      exhaustion, with a direction; nothing out of earshot; nothing when off.
##   G. Layout: at 1280×720, 1920×1080, 1024×768 and 2560×1440, with every
##      interface size, the HUD panels stay on screen and don't overlap.
##   H. Completion screen: route, time, optional objectives by name.
##   I. Tutorial: its HUD as before (checklist, no stamina, slots, ways out or
##      checkpoint line), captions available, the settings in its pause menu.

const SCENE := "res://scenes/level/expanded_library.tscn"
const TUTORIAL := "res://scenes/level/library_graybox.tscn"
const MENU := "res://scenes/ui/main_menu.tscn"
const GUARD_SCENE := "res://scenes/npc/guard.tscn"
const Layout := preload("res://tools/expanded/expanded_layout.gd")
const X := preload("res://tools/expanded/expansion/expansion_layout.gd")
const TestUtils := preload("res://tests/test_utils.gd")
const S := StealthDirector.Status
const M := "Expansion/Gameplay/Mission/"
const E := "Expansion/Gameplay/Escape/"
const TEST_SETTINGS := "user://test_hud_settings.cfg"

var failures: Array[String] = []
var _host: Node
var _level: Node
var _player: FirstPersonPlayer
var _inventory: PlayerInventory
var _objectives: ObjectiveManager
var _hud: ObjectiveHud
var _stealth: StealthHud
var _routes: EscapeRoutes
var _captions: SoundCaptions
var _guard: Guard
var _route: PatrolRoute
var _saved_path := ""


func run(host: Node) -> Array[String]:
	_host = host
	_saved_path = GameSettings.path
	GameSettings.path = TEST_SETTINGS
	await _check_settings()
	await _load(SCENE)
	await _check_hud_reads_game()
	await _check_ways_out()
	await _check_exit_messages()
	await _check_after_capture()
	await _check_captions()
	await _check_layout()
	await _check_completion()
	await _load(TUTORIAL)
	await _check_tutorial()
	await _unload()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	GameSettings.path = _saved_path
	GameSettings.reset_to_defaults()
	GameSettings.apply(_host.get_tree())
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[expanded-hud] " + message)


# --- A. Settings -----------------------------------------------------------------------------

func _check_settings() -> void:
	var tree := _host.get_tree()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	GameSettings.load_settings(true)
	_expect(GameSettings.hud_scale == 1.0 and GameSettings.master_volume == 1.0 and GameSettings.captions, "No file: the defaults.")
	GameSettings.set_hud_scale(tree, 1.25)
	GameSettings.set_master_volume(tree, 0.4)
	GameSettings.set_captions(tree, false)
	_expect(is_equal_approx(tree.root.content_scale_factor, 1.25), "apply(): the interface size is the window's content scale (%s)." % tree.root.content_scale_factor)
	var master := AudioServer.get_bus_index(&"Master")
	_expect(absf(AudioServer.get_bus_volume_db(master) - linear_to_db(0.4)) < 0.01 and not AudioServer.is_bus_mute(master), "apply(): the Master bus at 40 %.")
	GameSettings.reset_to_defaults()
	GameSettings.load_settings(true)
	_expect(GameSettings.hud_scale == 1.25 and is_equal_approx(GameSettings.master_volume, 0.4) and not GameSettings.captions, "Saved and loaded back (%s, %s, %s)." % [GameSettings.hud_scale, GameSettings.master_volume, GameSettings.captions])
	GameSettings.set_master_volume(tree, 0.0)
	_expect(AudioServer.is_bus_mute(master), "0 % mutes the Master bus.")
	var bad := ConfigFile.new()
	bad.set_value("settings", "hud_scale", 3.7)
	bad.set_value("settings", "master_volume", "loud")
	bad.set_value("settings", "captions", 5)
	bad.save(TEST_SETTINGS)
	GameSettings.load_settings(true)
	_expect(GameSettings.hud_scale == 1.0 and GameSettings.master_volume == 1.0 and GameSettings.captions, "Broken values fall back to the defaults.")
	# The main menu's settings screen.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	GameSettings.load_settings(true)
	var menu: MainMenu = (load(MENU) as PackedScene).instantiate()
	menu.change_scene = func(_p): pass
	_host.add_child(menu)
	await _frames(3)
	_expect(menu.settings_button != null and menu.settings_button.text == "Settings", "The main menu has a Settings button.")
	menu.settings_button.pressed.emit()
	await _frames(2)
	var panel := menu.settings_panel
	_expect(panel.visible and panel.scale_button.has_focus(), "Settings opens with the first control focused.")
	panel.scale_button.select(3)
	panel.scale_button.item_selected.emit(3)
	panel.volume_slider.value = 55.0
	panel.captions_button.button_pressed = false
	await _frames(2)
	_expect(GameSettings.hud_scale == 1.25 and is_equal_approx(GameSettings.master_volume, 0.55) and not GameSettings.captions and panel.volume_label.text == "Master volume: 55 %",
		"The controls change the settings (%s, %s, %s, '%s')." % [GameSettings.hud_scale, GameSettings.master_volume, GameSettings.captions, panel.volume_label.text])
	GameSettings.reset_to_defaults()
	GameSettings.load_settings(true)
	_expect(GameSettings.hud_scale == 1.25 and is_equal_approx(GameSettings.master_volume, 0.55) and not GameSettings.captions, "…and they are saved.")
	_expect(panel.captions_button.text == "Sound captions: Off", "The captions switch says Off (%s)." % panel.captions_button.text)
	panel.captions_button.button_pressed = true
	await _frames(1)
	_expect(GameSettings.captions and panel.captions_button.text == "Sound captions: On", "…and On when switched back (%s)." % panel.captions_button.text)
	panel.back_button.pressed.emit()
	await _frames(2)
	_expect(not panel.visible and menu.settings_button.has_focus(), "Back closes it, focus returns to Settings.")
	menu.queue_free()
	await _frames(3)
	# Back to the defaults for the rest of the suite.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	GameSettings.load_settings(true)
	GameSettings.apply(tree)
	print("  [expanded-hud] settings: defaults without a file; 125 %% / 40 %% / captions off saved and loaded; 0 %% mutes; broken values → defaults; the menu's screen changes and saves them, Back returns focus")


# --- B. The HUD reads the game ----------------------------------------------------------------

func _check_hud_reads_game() -> void:
	await _teleport(Vector3(0, 0, 20))
	_expect(_stealth.get_stamina() != null and _stealth._stamina_bar.visible, "Expanded Library: the stamina bar shows.")
	# Run dry with the sprint key held: EXHAUSTED.
	_player.stamina.stamina = 2.0
	Input.action_press("sprint")
	Input.action_press("move_left")
	var exhausted := false
	for i in 120:
		await _host.get_tree().physics_frame
		if _player.stamina.is_exhausted():
			exhausted = true
			break
	_expect(exhausted and _captions.get_shown_texts().has("You're out of breath"), "Running dry: exhausted, and captioned (%s)." % [_captions.get_shown_texts()])
	Input.action_release("move_left")
	Input.action_release("sprint")
	await _frames(3)
	_expect(not _player.stamina.is_exhausted(), "Letting go of Shift ends the exhaustion lock.")
	# Slots = inventory.
	_level.get_node("Expansion/Gameplay/Items/ToolKit").interact(_player)
	await _frames(2)
	_expect(_hud.get_slot_texts() == ["1 Tool kit", "2 —", "3 —"], "Three slots, as carried (%s)." % [_hud.get_slot_texts()])
	# The checklist = ObjectiveManager.
	var expected: Array = []
	expected.append_array(_objectives.get_mandatory_ids())
	expected.append_array(_objectives.get_optional_ids().filter(func(id): return _objectives.is_visible(id)))
	_expect(Array(_hud.get_listed_ids()) == expected, "The checklist lists the mission, then the visible optional objectives.")
	_expect(_hud.get_lines()[0] == "[x] Enter the library" and _hud.get_lines().has("[>] Find the tool kit") == false and _hud.get_lines().has("[x] Find the tool kit"), "Checklist marks follow the objectives (%s)." % [_hud.get_lines()])
	_expect(_hud.get_header_text() == "MISSION %d/8" % _objectives.get_mandatory_ids().filter(func(id): return _objectives.is_completed(id)).size(), "Header counts the mandatory objectives done.")
	# Journal: only clues and documents.
	_level.get_node("Expansion/Gameplay/Documents/PumpRoomLog").interact(_player)
	await _frames(2)
	var text := _hud.get_journal_text()
	_expect(text.contains("CLUES") and text.contains("DOCUMENTS") and text.contains("Pump room log") and not text.contains("MISSION") and not text.contains("[>]"),
		"The journal shows only clues and documents (%s)." % text.left(160))
	_hud.close_journal()
	print("  [expanded-hud] reads the game: stamina bar, EXHAUSTED + caption while Shift is held after running dry; slots = inventory; checklist = objectives; journal = clues + documents only")


# --- C. Ways out, power, checkpoint ------------------------------------------------------------

func _check_ways_out() -> void:
	await _load(SCENE)
	_expect(_hud.get_status_lines() == ["Checkpoint: the entrance"], "Before entering: no ways out known yet (%s)." % [_hud.get_status_lines()])
	await _teleport(Vector3(0, 0, 20))
	var lines := _hud.get_status_lines()
	_expect(lines.has("WAYS OUT") and lines.has("Main entrance: [ ] manuscript · [ ] master badge · [ ] override at the lobby reader")
		and lines.has("Loading dock: [ ] manuscript · [ ] shutter power"), "After entering: the main entrance and the dock with what is known (%s)." % [lines])
	_expect(not _joined().contains("passage") and not _joined().contains("panel") and not _joined().contains("release"), "The hidden passage, the panel and the release are not shown yet.")
	var locker: CodeLock = _level.get_node(M + "SecurityLocker")
	locker.set_entry("136")
	locker.submit()
	await _frames(2)
	_expect(_joined().contains("master badge (Office 1 locker)"), "The locker opening tells where the badge is.")
	_level.get_node("Expansion/Gameplay/Items/LockerBadge").interact(_player)
	await _frames(2)
	_expect(_joined().contains("[x] master badge (Office 1 locker)"), "Carrying the badge ticks it (%s)." % _joined())
	# The dock's control: no power, then (power on) the jammed release.
	var shutter: DockShutter = _level.get_node(E + "DockShutterControl")
	shutter.button.interact(_player)
	await _frames(2)
	_expect(_joined().contains("[ ] SERVICE EXIT power") and _joined().contains("[ ] OPEN on the shutter control") and not _joined().contains("release"),
		"Pressing the control without power: the circuit and the control are known, the release not yet (%s)." % _joined())
	var service: CircuitSwitch = _level.get_node("Expansion/Gameplay/Security/ServiceExitSwitch")
	service.interact(_player)
	await _frames(2)
	_expect(_joined().contains("[x] SERVICE EXIT power") and _joined().contains("POWER Archive OFF · Cameras ON · Service exit ON"), "Power on: ticked; POWER shows the circuits (%s)." % _joined())
	shutter.button.interact(_player)
	await _frames(2)
	_expect(_joined().contains("[ ] free the release (tool kit)"), "Pressing it again: the jammed release becomes known.")
	_level.get_node("Expansion/Gameplay/Items/ToolKit").interact(_player)
	(_level.get_node(E + "DockShutterRelease") as ToolMechanism).interact(_player)
	shutter.button.interact(_player)
	await _frames(2)
	_expect(_joined().contains("[x] free the release (tool kit)") and _joined().contains("[x] OPEN on the shutter control"), "Release freed and OPEN: ticked.")
	# The hidden passage after its plan.
	_level.get_node("Expansion/Gameplay/Documents/CulvertAccessPlan").interact(_player)
	_hud.close_journal()
	await _frames(2)
	_expect(_joined().contains("Hidden maintenance passage: [ ] manuscript · [ ] open the false panel (tunnel) · [ ] drain the culvert (pump room)"), "The plan reveals the passage (%s)." % _joined())
	var cp := _checkpoint("Study Rooms")
	CheckpointManager.find(_level).activate(cp)
	await _frames(2)
	_expect(_joined().contains("Checkpoint: Study Rooms"), "The checkpoint line names the checkpoint.")
	print("  [expanded-hud] ways out: none before entering; main entrance + dock on entering; badge place after the locker, [x] when carried; dock power/control/release only once met; POWER after the switch; passage after its plan; checkpoint name")


func _joined() -> String:
	return "\n".join(_hud.get_status_lines())


# --- D. Exit messages name only known requirements ----------------------------------------------

func _check_exit_messages() -> void:
	await _load(SCENE)
	await _teleport(Vector3(0, 0, 20))
	var dock: ExitDoor = _level.get_node("Gameplay/ExitDoor")
	var main: ExitDoor = _level.get_node(E + "MainEntranceExit")
	var drain: ExitDoor = _level.get_node(M + "StormDrainExit")
	_expect(dock.rejection_reason() == "You can't leave without the rare manuscript.", "Dock without the manuscript: the manuscript first.")
	await _get_manuscript()
	var reason := dock.rejection_reason()
	_expect(reason == "Loading dock: shutter power needed.", "Dock, manuscript held: only the known requirement (%s)." % reason)
	(_level.get_node("Expansion/Gameplay/Security/ServiceExitSwitch") as CircuitSwitch).interact(_player)
	reason = dock.rejection_reason()
	_expect(reason == "The loading dock won't open yet. Look around it for a way." and not reason.contains("release") and not reason.contains("OPEN"),
		"Powered but nothing else known: a hint, no names (%s)." % reason)
	dock.interact(_player)   # E at the door: the control beside it becomes known
	reason = dock.rejection_reason()
	_expect(reason == "Loading dock: OPEN on the shutter control needed.", "After trying the door: the control (%s)." % reason)
	reason = main.rejection_reason()
	_expect(reason == "Main entrance: master badge needed." and not reason.contains("Office 1"), "Main entrance: the badge, without its place (%s)." % reason)
	reason = drain.rejection_reason()
	_expect(not reason.contains("pump") and not reason.contains("panel") and not reason.contains("culvert"), "The drain says nothing specific before its plan (%s)." % reason)
	var all_text := _joined() + "\n" + _hud.get_journal_text() + "\n" + _hud.get_prompt_text()
	for answer in ["2691", "136", "A1", "valve"]:
		_expect(not all_text.contains(answer), "No puzzle answer (%s) on the HUD." % answer)
	print("  [expanded-hud] exit messages: manuscript first; then only known requirements; unknown ones as a hint without names; the badge without its place; the drain silent before its plan; no codes on the HUD")


# --- E. After a capture ---------------------------------------------------------------------------

func _check_after_capture() -> void:
	await _load(SCENE)
	await _teleport(Vector3(0, 0, 20))
	var cp := _checkpoint("Study Rooms")
	CheckpointManager.find(_level).activate(cp)
	await _teleport(Vector3(-8, 0, -5))
	var service: CircuitSwitch = _level.get_node("Expansion/Gameplay/Security/ServiceExitSwitch")
	service.interact(_player)
	_level.get_node("Expansion/Gameplay/Documents/CulvertAccessPlan").interact(_player)
	_hud.close_journal()
	var docs := _inventory.documents.size()
	await _frames(2)
	_expect(_joined().contains("[x] SERVICE EXIT power") and _joined().contains("Hidden maintenance passage"), "Before the capture: power on, passage known.")
	await _catch_and_respawn(Vector3(-8, 0, -9), Vector3(-8, 0, -10.5))
	await _frames(3)
	_expect(_inventory.documents.size() == docs, "The journal keeps every document and clue (%d → %d)." % [docs, _inventory.documents.size()])
	_expect(_joined().contains("[ ] SERVICE EXIT power") and _joined().contains("POWER Archive OFF · Cameras ON · Service exit OFF") and _joined().contains("Hidden maintenance passage"),
		"After the capture: the power shows restored (off), the passage stays known (%s)." % _joined())
	_expect(_hud.get_header_text() == "MISSION 1/8" and _hud.get_lines()[0] == "[x] Enter the library", "Objectives as at the checkpoint.")
	print("  [expanded-hud] after a capture: journal and clues kept (%d), ways out and power recomputed from the restored state, objectives as stored" % docs)


# --- F. Captions -------------------------------------------------------------------------------------

func _check_captions() -> void:
	await _load(SCENE)
	await _teleport(Vector3(0, 0, 0))
	_player.rotation.y = 0.0   # facing -z
	var noise := NoiseSystem.find(_level)
	SecurityAlarm.find(_level).raise_alarm(Vector3(0, 0, 8), "test", 22.0)   # behind
	noise.emit_noise(Vector3(-6, 0, 0), NoiseEvent.Type.INTERACTION, "distraction", 1.0, 14.0, -1.0, "Glass smashes")   # left
	noise.emit_noise(Vector3(0, 0, -6), NoiseEvent.Type.INTERACTION, "environment", 0.6, 9.0, -1.0, "Breaker clunk")   # ahead
	noise.emit_noise(Vector3(40, 0, 0), NoiseEvent.Type.INTERACTION, "environment", 0.6, 9.0, -1.0, "Far clunk")   # out of earshot
	noise.emit_noise(Vector3(0, 0, -3), NoiseEvent.Type.RUN, "player")   # the player's own steps: not captioned
	await _frames(2)
	var shown := _captions.get_shown_texts()
	_expect(shown.has("↓ ALARM ringing") and shown.has("← Glass smashes") and shown.has("↑ Breaker clunk") and not _captions.history.has("Far clunk") and shown.size() == 3,
		"Captions with directions, nothing out of earshot or from your own steps (%s)." % [shown])
	SecurityAlarm.find(_level).clear()
	# Upstairs: "above".
	noise.emit_noise(Vector3(0, Layout.UPPER_Y, -2), NoiseEvent.Type.INTERACTION, "environment", 0.6, 9.0, -1.0, "Shutter rattles up")
	await _frames(1)
	_expect(_captions.get_shown_texts().has("↑ above Shutter rattles up"), "Another floor is marked (%s)." % [_captions.get_shown_texts()])
	# A real switch and a thrown bottle.
	(_level.get_node("Expansion/Gameplay/Security/SurveillanceSwitch") as CircuitSwitch).interact(_player)
	var item := ThrownItem.new()
	item.setup(ItemCatalog.BOTTLE, _player.global_position + Vector3(2, 1.5, 0), _player.global_position + Vector3(4, 0, 0), 0.2)
	_level.add_child(item)
	await _frames(30)
	_expect(_captions.history.has("Glass smashes") and _captions.history.count("Breaker clunk") >= 1, "A thrown bottle and a switch are captioned by the game itself.")
	# A guard: noticing (stinger) and footsteps.
	await _frames(240)
	_spawn_guard([Vector3(4, 0, -6), Vector3(4, 0, 8)], Vector3(0, 0, 1))
	var heard_steps := false
	for i in 300:
		await _host.get_tree().physics_frame
		if _captions.history.has("Footsteps"):
			heard_steps = true
			break
	_expect(heard_steps, "A guard walking nearby: footsteps captioned.")
	_player.global_position = Vector3(4, 0.05, -1)
	var noticed := false
	for i in 300:
		await _host.get_tree().physics_frame
		if _captions.history.has("A guard notices you") or _captions.history.has("Guard shouts: you've been spotted!"):
			noticed = true
			break
	_expect(noticed, "Being noticed is captioned (%s)." % [_captions.history.slice(-4)])
	_clear_guard()
	await _teleport(Vector3(0, 0, 0))
	await _frames(240)
	# Off: nothing.
	GameSettings.captions = false
	var before := _captions.history.size()
	noise.emit_noise(Vector3(0, 0, -6), NoiseEvent.Type.INTERACTION, "environment", 0.6, 9.0, -1.0, "Breaker clunk")
	await _frames(2)
	_expect(_captions.history.size() == before and not _captions.visible, "Captions off: nothing shown.")
	GameSettings.captions = true
	print("  [expanded-hud] captions: alarm ↓, distraction ←, switch ↑, another floor 'above'; real switch, bottle, guard footsteps and being noticed; nothing out of earshot, nothing for your own steps, nothing when off")


# --- G. Layout ---------------------------------------------------------------------------------------

func _check_layout() -> void:
	await _load(SCENE)
	await _teleport(Vector3(0, 0, 20))
	# The busiest state: every way out known, power seen, items, captions.
	_level.get_node("Expansion/Gameplay/Items/ToolKit").interact(_player)
	_level.get_node("Gameplay/StaffAccessCard").interact(_player)
	(_level.get_node("Expansion/Gameplay/Security/ServiceExitSwitch") as CircuitSwitch).interact(_player)
	_level.get_node("Expansion/Gameplay/Documents/CulvertAccessPlan").interact(_player)
	_hud.close_journal()
	var locker: CodeLock = _level.get_node(M + "SecurityLocker")
	locker.set_entry("136")
	locker.submit()
	var shutter: DockShutter = _level.get_node(E + "DockShutterControl")
	shutter.button.interact(_player)
	shutter.button.interact(_player)
	for k in 4:
		NoiseSystem.find(_level).emit_noise(_player.global_position + Vector3(k, 0, -3), NoiseEvent.Type.INTERACTION, "environment", 0.6, 9.0, -1.0, "Caption %d is a fairly long one" % k)
	var window := _host.get_window()
	var original_size := window.size
	var checked := 0
	var max_pages := 0
	var problems: Array[String] = []
	for res in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1024, 768), Vector2i(2560, 1440)]:
		window.size = res
		for s in GameSettings.HUD_SCALES:
			GameSettings.hud_scale = s
			GameSettings.apply(_host.get_tree())
			await _process_frames(3)
			var visible := _hud.get_viewport().get_visible_rect()
			var c: Dictionary = _hud.get_layout_controls()
			var rects := {"objectives": c.objectives.get_global_rect(), "status": c.status.get_global_rect(), "slots": c.slots.get_global_rect(),
				"captions": _captions.get_global_rect(), "stamina": _stealth._stamina_bar.get_global_rect(), "stance": _stealth._stance.get_global_rect()}
			for key in rects:
				var r: Rect2 = rects[key]
				if not visible.grow(1.0).encloses(r):
					problems.append("%s %s @%d%%: %s off screen %s (visible %s)" % [res, "", int(s * 100), key, r, visible.size])
			for pair in [["objectives", "status"], ["objectives", "captions"], ["status", "stamina"], ["status", "captions"], ["captions", "stamina"], ["slots", "captions"], ["slots", "stamina"], ["objectives", "slots"]]:
				if rects[pair[0]].intersects(rects[pair[1]]):
					problems.append("%s @%d%%: %s overlaps %s" % [res, int(s * 100), pair[0], pair[1]])
			# Journal open: it takes the left side, the status panel hides.
			_hud.open_journal(&"")
			await _process_frames(2)
			var jr: Rect2 = c.journal.get_global_rect()
			if c.status.visible or not visible.grow(1.0).encloses(jr) or jr.intersects(rects.objectives) or jr.intersects(rects.captions) or jr.intersects(rects.stamina):
				problems.append("%s @%d%%: journal layout (status visible %s, journal %s)" % [res, int(s * 100), c.status.visible, c.journal.get_global_rect()])
			# J pages through every clue and document; each page fits.
			var seen := ""
			var pages := 0
			while _hud.is_journal_open() and pages < 12:
				seen += _hud.get_journal_text() + "\n"
				jr = c.journal.get_global_rect()
				if not visible.grow(1.0).encloses(jr) or jr.intersects(rects.captions) or jr.intersects(rects.stamina):
					problems.append("%s @%d%%: journal page %d overlaps (%s)" % [res, int(s * 100), pages + 1, jr])
				_hud.next_journal_page()
				await _process_frames(1)
				pages += 1
			for d in _inventory.documents:
				if not seen.contains(d.title + ":") and not seen.contains("[b]%s[/b]" % d.title):
					problems.append("%s @%d%%: journal entry '%s' unreachable with J" % [res, int(s * 100), d.title])
			_hud.close_journal()
			if res == Vector2i(1024, 768) and is_equal_approx(s, 1.25):
				max_pages = pages
			checked += 1
	window.size = original_size
	GameSettings.hud_scale = 1.0
	GameSettings.apply(_host.get_tree())
	await _process_frames(2)
	_expect(problems.is_empty(), "Layout problems: %s." % "; ".join(problems))
	print("  [expanded-hud] layout: %d resolution × interface size combinations (1280×720, 1920×1080, 1024×768, 2560×1440 × 90–125 %%), panels on screen, no overlaps, journal and status panel take turns, every journal entry reachable with J (%d pages at 1024×768 125 %%)" % [checked, max_pages])


# --- H. Completion screen ---------------------------------------------------------------------------

func _check_completion() -> void:
	await _load(SCENE)
	await _teleport(Vector3(0, 0, 20))
	var locker: CodeLock = _level.get_node(M + "SecurityLocker")
	locker.set_entry("136")
	locker.submit()
	await _get_manuscript()
	(_level.get_node("Expansion/Gameplay/Security/ServiceExitSwitch") as CircuitSwitch).interact(_player)
	(_level.get_node(E + "DockShutterRelease") as ToolMechanism).interact(_player)
	(_level.get_node(E + "DockShutterControl") as DockShutter).button.interact(_player)
	await _teleport(Vector3(34.6, 0, 24))
	_player.rotation.y = -PI / 2.0
	Input.action_press("move_forward")
	for i in 120:
		await _host.get_tree().physics_frame
		if StealthDirector.find(_level).status == S.ESCAPED:
			break
	Input.action_release("move_forward")
	await _frames(3)
	var menus: GameMenus = _level.get_node("GameMenus")
	menus.refresh()
	var objectives_text := menus.get_objectives_text()
	_expect(menus.win_panel.visible and menus.get_win_text().begins_with("Time ") and objectives_text == "Mission objectives 8/8 complete · optional 1/3\nOptional: Open the security locker\nEscape route: Loading dock",
		"The completion screen: time, optional objectives by name, the route (%s / %s)." % [menus.get_win_text(), objectives_text])
	print("  [expanded-hud] completion: '%s' / '%s'" % [menus.get_win_text(), objectives_text.replace("\n", " | ")])


# --- I. Tutorial ---------------------------------------------------------------------------------------

func _check_tutorial() -> void:
	await _teleport(Vector3(0, 0, 14))
	_expect(_stealth.get_stamina() == null and not _stealth._stamina_bar.visible, "Tutorial: no stamina bar.")
	_expect(_hud.get_inventory() == null and not _hud._slots.visible, "Tutorial: no slots.")
	_expect(_hud.get_status_lines().is_empty() and not _hud.get_layout_controls().status.visible, "Tutorial: no ways-out / power / checkpoint panel.")
	_expect(_hud.get_header_text().begins_with("OBJECTIVE ") and _hud.get_lines().size() == _objectives.get_ids().size(), "Tutorial: its checklist as before (%s)." % _hud.get_header_text())
	_expect(_captions != null, "Tutorial: captions available.")
	NoiseSystem.find(_level).emit_noise(_player.global_position + Vector3(0, 0, -4), NoiseEvent.Type.INTERACTION, "environment", 0.6, 9.0, -1.0, "Test clunk")
	await _frames(1)
	_expect(_captions.get_shown_texts().has("↑ Test clunk"), "Tutorial: captions shown.")
	var flow := GameFlow.find(_level)
	flow.pause()
	await _frames(3)
	var menus: GameMenus = _level.get_node("GameMenus")
	_expect(menus.pause_panel.visible and menus.settings_button != null, "Tutorial pause menu: Settings.")
	menus.settings_button.pressed.emit()
	await _frames(2)
	_expect(menus.settings_panel.visible, "Settings open from the pause menu.")
	var esc := InputEventAction.new()
	esc.action = "pause"
	esc.pressed = true
	Input.parse_input_event(esc)
	var esc_cancel := InputEventAction.new()
	esc_cancel.action = "ui_cancel"
	esc_cancel.pressed = true
	Input.parse_input_event(esc_cancel)
	await _frames(3)
	_expect(not menus.settings_panel.visible and flow.state == GameStateMachine.State.PAUSED, "Esc closes the settings and stays paused (state %s)." % flow.state)
	flow.resume()
	await _frames(3)
	print("  [expanded-hud] tutorial: no stamina/slots/ways-out panel, checklist as before, captions shown, Settings in the pause menu, Esc closes it and stays paused")


# --- Helpers ------------------------------------------------------------------------------------------

func _get_manuscript() -> void:
	var toolkit := _level.get_node("Expansion/Gameplay/Items/ToolKit") as ItemPickup
	if not _inventory.has(ItemCatalog.TOOLKIT) and toolkit.available:
		toolkit.interact(_player)
	if not _objectives.is_completed(&"take_card"):
		_level.get_node("Gameplay/StaffAccessCard").interact(_player)
	var cover := _level.get_node(M + "ElectricalPanelCover") as ToolMechanism
	if not cover.is_operated:
		cover.interact(_player)
	var breakers: BreakerPanel = _level.get_node(M + "BreakerPanel")
	if not breakers.is_solved:
		breakers.set_setting([true, false, true, true])
		breakers.engage()
	var keypad: CodeLock = _level.get_node(M + "VaultKeypad")
	if not keypad.is_solved:
		keypad.set_entry("2691")
		keypad.submit()
	await _frames(3)
	_level.get_node("Gameplay/RareManuscript").interact(_player)
	await _frames(2)


func _checkpoint(cp_name: String) -> Checkpoint:
	for cp in _level.get_tree().get_nodes_in_group("checkpoints"):
		if cp.checkpoint_name == cp_name:
			return cp
	return null


func _load(path: String) -> void:
	await _unload()
	_level = (load(path) as PackedScene).instantiate()
	for g in _level.get_node("Guards").get_children():
		if g is Guard:
			g.get_parent().remove_child(g)
			g.free()
	var probe := Layout.SPAWN if path == SCENE else Vector3(0, 0, 18)
	_expect(await TestUtils.add_level_and_wait_for_navigation(_host, _level, probe), "Navigation never became ready.")
	_player = _level.get_node("Player")
	_inventory = _player.get_node("Inventory")
	_objectives = ObjectiveManager.find(_level)
	_hud = _level.get_node("ObjectiveHud")
	_stealth = _level.get_node("StealthHud")
	_captions = _stealth.captions
	_routes = EscapeRoutes.find(_level)
	_guard = null
	_route = null
	GameFlow.find(_level).change_scene = func(_p): pass
	await _frames(10)


func _unload() -> void:
	for a in ["move_forward", "move_left", "sprint", "crouch"]:
		Input.action_release(a)
	if _level and is_instance_valid(_level):
		_level.queue_free()
		await _frames(30)
	_level = null


func _teleport(at: Vector3) -> void:
	_player.global_position = at + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	await _frames(4)


func _catch_and_respawn(at: Vector3, guard_at: Vector3) -> void:
	var to_player := Vector2(at.x - guard_at.x, at.z - guard_at.z)
	_spawn_guard([guard_at], Vector3(to_player.x, 0, to_player.y))
	_guard.patrol_route.get_child(0).wait_time = 300.0
	await _teleport(at)
	var director := StealthDirector.find(_level)
	for i in 600:
		if director.status == S.CAUGHT:
			break
		await _host.get_tree().physics_frame
	_expect(director.status == S.CAUGHT, "The test guard should catch the player.")
	for i in int(director.reset_delay * 60) + 30:
		if director.status != S.CAUGHT:
			break
		await _host.get_tree().physics_frame
	_clear_guard()
	await _frames(5)


func _spawn_guard(points: Array, facing: Vector3) -> void:
	_clear_guard()
	_route = PatrolRoute.new()
	for p in points:
		var post := PatrolPoint.new()
		post.position = p
		post.wait_time = 0.3
		_route.add_child(post)
	_level.add_child(_route)
	_guard = (load(GUARD_SCENE) as PackedScene).instantiate()
	_guard.patrol_route = _route
	_guard.position = points[0] + Vector3(0, 0.05, 0)
	_guard.rotation.y = atan2(-facing.x, -facing.z)
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


## Rendered frames (the HUD updates in _process; several physics frames can
## pass within one rendered frame, e.g. after a window resize).
func _process_frames(count: int) -> void:
	for i in count:
		await _host.get_tree().process_frame


func _frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
