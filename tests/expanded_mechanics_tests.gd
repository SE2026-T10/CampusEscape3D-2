extends RefCounted

## Expanded Library expansion, Phase 3 (stamina and inventory). Called from
## tests/test_scene.gd.
##
##   A. Stamina rules on PlayerStamina itself, at many frame times (30, 60,
##      120, 144 Hz, odd and uneven steps): 5 s of sprint from full, sprint
##      stops at zero, 1 s delay then 15/s, 15 needed to start, the key must be
##      released after running dry, refill, configurable values, off = as before.
##   B. Stamina on the real player in the Expanded Library with real input, at
##      30, 60 and 120 physics ticks per second: same sprint time and distance;
##      walking, standing with sprint held, crouching, hiding, using things and
##      being watched by a guard cost nothing; respawning refills.
##   C. Inventory with real input (E, 1–3, F, J): three slots and never more;
##      the fourth item (and the staff card) refused with full hands; tools and
##      cards are not used up by mechanisms, doors or the use key; one
##      distraction used per successful throw (one noise, a guard investigates),
##      none for a failed throw; documents go to the journal, once each.
##   D. Storage shelves: leave, take back and swap only there; items are
##      neither created nor lost.
##   E. Card doors check the carried card (not just the objective).
##   F. Checkpoints: being caught restores the carried slots, shelves and
##      pickups to the checkpoint, never duplicating an item, again and again;
##      stamina is full after the respawn.
##   G. The tutorial is unchanged: no stamina, no inventory, no item HUD, the
##      pause menu's controls as before, unlimited sprint.

const SCENE := "res://scenes/level/expanded_library.tscn"
const TUTORIAL := "res://scenes/level/library_graybox.tscn"
const GUARD_SCENE := "res://scenes/npc/guard.tscn"
const Layout := preload("res://tools/expanded/expanded_layout.gd")
const X := preload("res://tools/expanded/expansion/expansion_layout.gd")
const TestUtils := preload("res://tests/test_utils.gd")
const S := StealthDirector.Status
const B := X.BF

## Where to stand (floor) to reach each provisional item, from expansion_layout ITEMS.
const STAND := {
	"ToolKit": Vector3(-24.8, B, -20.2),
	"BottleTunnel": Vector3(-14.0, B, -24.3),
	"HardbackTunnel": Vector3(19.0, B, -25.6),
	"BottleCableBay": Vector3(44.0, B, -19.2),
}
## A straight, clear run along the service tunnel (for sprint timing).
const RUN_START := Vector3(-35.0, B, -24.8)

var failures: Array[String] = []
var _host: Node
var _level: Node3D
var _player: FirstPersonPlayer
var _inventory: PlayerInventory
var _stamina: PlayerStamina
var _interactor: PlayerInteractor
var _objectives: ObjectiveManager
var _checkpoints: CheckpointManager
var _director: StealthDirector
var _hud: ObjectiveHud
var _guard: Node3D
var _route: Node3D
var _noises: Array[NoiseEvent] = []


func run(host: Node) -> Array[String]:
	_host = host
	_check_stamina_rules()
	await _check_stamina_in_level()
	await _check_inventory()
	await _check_storage()
	await _check_card_doors()
	await _check_checkpoints()
	await _check_tutorial_unchanged()
	await _unload()
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[expansion-mechanics] " + message)


# --- A. Stamina rules --------------------------------------------------------------------------

func _check_stamina_rules() -> void:
	var rates := [30.0, 60.0, 120.0, 144.0, 7.0]
	var report := []
	for hz in rates:
		var dt: float = 1.0 / hz
		var s := _new_stamina()
		# 1. From full, a held sprint lasts 5 s (100 / 20), within one step, and stops at zero.
		var t := 0.0
		var sprinting_time := 0.0
		while t < 7.0:
			if s.update(true, true, dt):
				sprinting_time += dt
			t += dt
		_expect(absf(sprinting_time - 5.0) <= dt + 1e-6, "%.0f Hz: a full sprint should last 5 s (lasted %.3f s)." % [hz, sprinting_time])
		_expect(not s.is_sprinting, "%.0f Hz: the sprint must stop at zero stamina." % hz)
		# 2. Still held after running dry: no new sprint even once 15+ has refilled (needs a release).
		_run(s, true, true, 1.0, dt)
		_expect(s.stamina >= s.min_to_start and not s.update(true, true, dt),
			"%.0f Hz: holding sprint after running dry must not restart it (stamina %.1f)." % [hz, s.stamina])
		s.update(false, true, dt)
		_expect(s.update(true, true, dt), "%.0f Hz: after releasing the key, a sprint with %.1f stamina should start." % [hz, s.stamina])
		s.free()
		# 3. Delay then regeneration, counted to the exact time (leftover of the step after the delay included).
		s = _new_stamina()
		_run(s, true, true, 2.0, dt)                # 2 s sprint: 60 left (±1 step)
		var after_sprint := s.stamina
		_run(s, false, true, 0.5, dt)
		var during_delay := s.stamina
		_run(s, false, true, 2.5, dt)               # 3 s after the sprint ended: 2 s of regeneration
		var expected := minf(after_sprint + 2.0 * 15.0, 100.0)
		_expect(is_equal_approx(during_delay, after_sprint), "%.0f Hz: no regeneration during the 1 s delay (%.2f → %.2f)." % [hz, after_sprint, during_delay])
		_expect(absf(s.stamina - expected) < 15.0 * dt + 1e-4, "%.0f Hz: 1 s delay then 15/s: expected %.2f, got %.2f." % [hz, expected, s.stamina])
		s.free()
		# 4. From zero to full: 1 s + 100 / 15 s.
		s = _new_stamina()
		s.stamina = 0.0
		s._delay_left = s.regen_delay
		var full_after := 0.0
		while s.stamina < s.max_stamina and full_after < 20.0:
			s.update(false, false, dt)
			full_after += dt
		_expect(absf(full_after - (1.0 + 100.0 / 15.0)) <= dt + 1e-6, "%.0f Hz: empty to full should take %.3f s (took %.3f s)." % [hz, 1.0 + 100.0 / 15.0, full_after])
		s.free()
		report.append("%.0f Hz %.3f s" % [hz, sprinting_time])
	# Uneven steps (a stuttering frame rate) give the same totals.
	var s := _new_stamina()
	var steps := [0.004, 0.033, 0.017, 0.05, 0.008, 0.021]
	var t := 0.0
	var i := 0
	var sprinted := 0.0
	while t < 7.0:
		var dt: float = steps[i % steps.size()]
		if s.update(true, true, dt):
			sprinted += dt
		t += dt
		i += 1
	_expect(absf(sprinted - 5.0) <= 0.05 + 1e-6, "Uneven steps: a full sprint should last 5 s (lasted %.3f s)." % sprinted)
	s.free()
	# 5. 15 needed to start; a running sprint continues below 15.
	s = _new_stamina()
	s.stamina = 14.9
	_expect(not s.can_start_sprint() and not s.update(true, true, 1.0 / 60.0), "A sprint must not start with 14.9 stamina.")
	s.stamina = 15.0
	_expect(s.update(true, true, 1.0 / 60.0), "A sprint should start with 15 stamina.")
	_expect(s.update(true, true, 1.0 / 60.0) and s.stamina < 15.0, "A running sprint continues below 15.")
	# 6. Nothing drains without a moving sprint: walking, standing with sprint held, crouching (moving = false).
	s.refill()
	_run(s, false, true, 10.0, 1.0 / 60.0)
	_run(s, true, false, 10.0, 1.0 / 60.0)
	_expect(s.stamina == 100.0, "Walking and standing (sprint held) must not drain stamina (%.2f)." % s.stamina)
	# 7. refill() (respawn).
	_run(s, true, true, 3.0, 1.0 / 60.0)
	s.refill()
	_expect(s.stamina == 100.0 and s.can_start_sprint(), "refill() should give full stamina and allow a sprint.")
	s.free()
	# 8. Configurable values.
	s = _new_stamina()
	s.max_stamina = 50.0
	s.stamina = 50.0
	s.sprint_drain = 10.0
	var lasted := 0.0
	for k in 600:
		if s.update(true, true, 1.0 / 60.0):
			lasted += 1.0 / 60.0
	_expect(absf(lasted - 5.0) <= 1.0 / 60.0 + 1e-6, "Configured 50 / 10 per s should give a 5 s sprint (%.3f s)." % lasted)
	s.free()
	# 9. Off: unlimited, unchanged.
	s = PlayerStamina.new()
	_run(s, true, true, 30.0, 1.0 / 60.0)
	_expect(s.update(true, true, 1.0 / 60.0) and s.stamina == 100.0, "With stamina off, sprinting is unlimited and nothing drains.")
	s.free()
	print("  [expansion-mechanics] stamina rules: full sprint %s; 1 s delay then 15/s; empty→full 7.667 s; 15 to start; release after running dry" % ", ".join(report))


func _new_stamina() -> PlayerStamina:
	var s := PlayerStamina.new()
	s.enabled = true
	s.stamina = s.max_stamina
	return s


func _run(s: PlayerStamina, sprint: bool, moving: bool, seconds: float, dt: float) -> void:
	var t := 0.0
	while t < seconds - 1e-9:
		s.update(sprint, moving, dt)
		t += dt


# --- B. Stamina on the player ------------------------------------------------------------------

func _check_stamina_in_level() -> void:
	await _load(false)
	_expect(_stamina != null and _stamina.enabled and _player.use_stamina, "The Expanded Library's player should have stamina switched on.")
	if _stamina == null:
		return
	var results := []
	for hz in [60, 30, 120]:
		Engine.physics_ticks_per_second = hz
		await _frames(5)
		var r: Dictionary = await _sprint_run(6.0)
		results.append(r)
	Engine.physics_ticks_per_second = 60
	await _frames(5)
	var base: Dictionary = results[0]
	for r in results:
		_expect(absf(r.sprint_time - 5.0) <= 2.0 / r.hz + 1e-6, "%d Hz: sprint with real input should last 5 s (lasted %.3f s)." % [r.hz, r.sprint_time])
		_expect(absf(r.distance - base.distance) < 0.5, "%d Hz: distance in 6 s should match 60 Hz (%.2f m vs %.2f m)." % [r.hz, r.distance, base.distance])
		_expect(r.end_speed < _player.walk_speed + 0.2, "%d Hz: after running dry the player walks (%.2f m/s)." % [r.hz, r.end_speed])
		_expect(r.peak_speed > _player.sprint_speed - 0.2, "%d Hz: sprint speed reached (%.2f m/s)." % [r.hz, r.peak_speed])
	print("  [expansion-mechanics] real-input sprint, 6 s: %s" % ", ".join(results.map(func(r): return "%d Hz %.3f s sprint, %.2f m" % [r.hz, r.sprint_time, r.distance])))

	# Walking, standing with sprint held, crouch-walking with sprint held: no drain.
	await _teleport(RUN_START)
	_player.rotation.y = -PI / 2.0
	_stamina.refill()
	Input.action_press("move_forward")
	await _seconds(2.0)
	_release_all()
	Input.action_press("sprint")
	await _seconds(1.5)
	Input.action_press("crouch")
	Input.action_press("move_forward")
	await _seconds(1.5)
	_release_all()
	await _frames(20)
	_expect(_stamina.stamina == 100.0, "Walking, standing with sprint held and crouch-walking must not drain stamina (%.2f)." % _stamina.stamina)
	# Hiding (crouched in a hiding spot, sprint held).
	var spot: HidingSpot = _level.get_node("Expansion/Gameplay/HidingSpots/Maintenancebay")
	await _teleport(spot.global_position - Vector3(0, 0.6, 0))
	Input.action_press("crouch")
	Input.action_press("sprint")
	await _seconds(1.5)
	_expect(spot.contains_player() and _stamina.stamina == 100.0, "Hiding (crouched, sprint held) must not drain stamina (%.2f)." % _stamina.stamina)
	_release_all()
	await _frames(20)
	# Using things (reading a document, three times).
	var doc: DocumentPickup = _level.get_node("Expansion/Gameplay/Documents/PumpRoomLog")
	await _stand_and_look(doc.global_position + Vector3(-1.2, -1.4, 0), doc.global_position)
	for k in 3:
		await _press("interact")
	_expect(_stamina.stamina == 100.0, "Using things must not drain stamina.")
	# Being watched by a guard: detection does not touch stamina.
	_stamina.stamina = 50.0
	_stamina._delay_left = 0.0
	_stamina.regen_rate = 0.0       # isolate: any change would come from detection
	await _teleport(Vector3(-20.0, B, -25.0))
	_spawn_guard(Vector3(-8.0, B, -25.0), PI / 2.0)
	var watched := 0
	for k in 75:
		await _host.get_tree().physics_frame
		if _director.status == S.CAUGHT:
			break
		if _guard.vision.detection > 0.0:
			watched += 1
	_expect(_director.status != S.CAUGHT, "The watching guard should not have caught the player yet.")
	_expect(watched > 15 and _stamina.stamina == 50.0, "Being seen must not change stamina (seen %d frames, stamina %.2f)." % [watched, _stamina.stamina])
	_clear_guard()
	_stamina.regen_rate = 15.0
	# Respawn refills.
	_stamina.stamina = 3.0
	_player.respawn()
	_expect(_stamina.stamina == 100.0, "Respawning should refill stamina.")
	await _frames(5)
	print("  [expansion-mechanics] no drain walking, standing, crouching, hiding, using things or being seen (seen %d frames); respawn refills" % watched)


## Sprints with real input along the service tunnel for `seconds` of physics time.
func _sprint_run(seconds: float) -> Dictionary:
	await _teleport(RUN_START)
	_player.rotation.y = -PI / 2.0
	_player.head.rotation.x = 0.0
	_stamina.refill()
	_stamina.sprint_time = 0.0
	await _frames(3)
	var start := _player.global_position
	var hz := Engine.physics_ticks_per_second
	var peak := 0.0
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var t := 0.0
	var speed := 0.0
	while t < seconds - 1e-6:
		await _host.get_tree().physics_frame
		t += 1.0 / hz
		speed = Vector2(_player.velocity.x, _player.velocity.z).length()
		peak = maxf(peak, speed)
	var distance := Vector2(_player.global_position.x - start.x, _player.global_position.z - start.z).length()
	_release_all()
	await _frames(10)
	return {"hz": hz, "sprint_time": _stamina.sprint_time, "distance": distance, "peak_speed": peak, "end_speed": speed}


# --- C. Inventory ------------------------------------------------------------------------------

func _check_inventory() -> void:
	await _load(false)
	_expect(_inventory != null and _inventory.enabled and _inventory.slot_count == 3 and _inventory.count() == 0,
		"The Expanded Library's player should have an empty three-slot inventory.")
	_expect(_inventory.is_in_group("checkpoint_state"), "The carried slots should be stored at checkpoints.")
	for n in ["Items/ToolKit", "Items/BottleTunnel", "Items/HardbackTunnel", "Items/BottleCableBay", "Storage/MaintenanceShelf",
			"Storage/ElectricalShelf", "Documents/PumpRoomLog", "Documents/ElectricalNotice"]:
		_expect(_level.get_node_or_null("Expansion/Gameplay/" + n) != null, "Missing Expansion/Gameplay/%s." % n)
	_expect(_hud.get_slot_texts() == ["1 —", "2 —", "3 —"], "The HUD should show three empty slots (%s)." % [_hud.get_slot_texts()])

	# Three pickups with E.
	for n in ["ToolKit", "BottleTunnel", "HardbackTunnel"]:
		var ok: bool = await _take(n)
		_expect(ok, "Taking %s with E should work." % n)
	_expect(_inventory.slots == [ItemCatalog.TOOLKIT, ItemCatalog.BOTTLE, ItemCatalog.HARDBACK], "Slots after three pickups: %s." % [_inventory.slots])
	_expect(_hud.get_slot_texts() == ["1 Tool kit", "2 Glass bottle", "3 Heavy hardback"], "HUD slots: %s." % [_hud.get_slot_texts()])
	# The fourth is refused.
	var fourth: ItemPickup = _item("BottleCableBay")
	await _stand_and_look(STAND.BottleCableBay, _aim(fourth))
	_expect(_interactor.focused == fourth and _hud.get_prompt_text().contains("hands full (3/3)"),
		"With full hands a pickup should say so (prompt %s)." % _hud.get_prompt_text())
	await _press("interact")
	_expect(_inventory.count() == 3 and not fourth.taken and fourth.visible, "A fourth item must be refused (carrying %d)." % _inventory.count())
	_expect(_hud.get_message_text().contains("Hands full"), "Refusing should explain why (message %s)." % _hud.get_message_text())
	_expect(not _inventory.add(ItemCatalog.BOTTLE) and _inventory.count() == 3, "add() must never go past three slots.")
	# The staff card is refused too with full hands (its objective stays open).
	_objectives.complete(ObjectiveManager.find(_level).get_ids()[0])
	var card: AccessCard = _level.get_node("Gameplay/StaffAccessCard")
	_expect(not card.interact(_player) and not _objectives.is_completed(&"take_card") and card.visible,
		"The staff card must be refused with full hands, leaving its objective open.")

	# Selecting with 1–3.
	await _press("item_slot_2")
	_expect(_inventory.selected == 1 and _inventory.selected_item() == ItemCatalog.BOTTLE, "Key 2 should select slot 2.")
	await _press("item_slot_1")
	_expect(_inventory.selected == 0, "Key 1 should select slot 1.")

	# Reusable: the tool kit operates a mechanism and stays; F with it selected uses nothing up.
	var mechanism := ToolMechanism.new()
	mechanism.mechanism_name = "Test panel"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.6, 0.3)
	shape.shape = box
	mechanism.add_child(shape)
	mechanism.position = Vector3(-24.0, B + 1.2, -21.6)
	_level.add_child(mechanism)
	var second := ToolMechanism.new()
	second.mechanism_name = "Test valve"
	second.add_child(shape.duplicate())
	second.position = Vector3(-22.0, B + 1.2, -21.6)
	_level.add_child(second)
	await _frames(3)
	await _stand_and_look(Vector3(-24.0, B, -20.0), mechanism.global_position)
	await _press("interact")
	await _stand_and_look(Vector3(-22.0, B, -20.0), second.global_position)
	await _press("interact")
	for k in 3:
		await _press("use_item")
	_expect(mechanism.is_operated and second.is_operated and _inventory.has(ItemCatalog.TOOLKIT) and _inventory.count() == 3,
		"The tool kit should operate two mechanisms and still be carried (F three times uses nothing up).")
	_inventory.take_from_slot(0)
	var third := ToolMechanism.new()
	third.add_child(shape.duplicate())
	third.position = Vector3(-26.0, B + 1.2, -21.6)
	_level.add_child(third)
	await _frames(3)
	_expect(not third.interact(_player) and not third.is_operated and third.rejections == 1, "A mechanism must refuse without the tool kit.")
	_inventory.put_in_slot(0, ItemCatalog.TOOLKIT)
	for m in [mechanism, second, third]:
		m.queue_free()

	# Distractions: one used per successful throw, one noise, a guard investigates.
	var system := NoiseSystem.find(_level)
	_noises.clear()
	system.noise_emitted.connect(_on_noise)
	await _stand_and_look(Vector3(-30.0, B, -25.0), Vector3(-30.0 + 9.0, B, -25.0))
	_spawn_guard(Vector3(-13.0, B, -24.5), -PI / 2.0)   # 8 m past the landing spot, looking away (east)
	await _frames(5)
	await _press("item_slot_2")
	await _press("use_item")
	_expect(_inventory.get_item(1) == &"" and _inventory.distractions_used == 1 and _inventory.count() == 2,
		"A successful throw uses up exactly that bottle (slots %s)." % [_inventory.slots])
	await _press("use_item")   # slot 2 is now empty
	_expect(_inventory.distractions_used == 1 and _inventory.count() == 2, "Using an empty slot must use nothing.")
	var investigated := false
	for k in 120:
		await _host.get_tree().physics_frame
		if _guard.machine.current == GuardStateMachine.INVESTIGATE:
			investigated = true
	var thrown := _noises.filter(func(e: NoiseEvent): return e.source_group == "distraction")
	_expect(thrown.size() == 1, "One throw should make exactly one noise (made %d)." % thrown.size())
	_expect(investigated, "A guard 8 m from where the bottle lands should investigate it.")
	if not thrown.is_empty():
		var landing: Vector3 = thrown[0].position
		_expect(absf(landing.y - B) < 0.2 and absf(landing.x + 21.0) < 1.5, "The bottle should land on the tunnel floor about 9 m ahead (%s)." % landing)
	_clear_guard()
	# A failed throw (aimed at the wall right in front) uses nothing.
	await _press("item_slot_3")
	await _stand_and_look(Vector3(-30.0, B, -26.0), Vector3(-30.0, B + 1.6, -28.0))
	await _press("use_item")
	_expect(_inventory.get_item(2) == ItemCatalog.HARDBACK and _inventory.distractions_used == 1,
		"A throw with nowhere to land must not use the item.")
	_expect(_hud.get_message_text().contains("Nowhere to throw"), "A failed throw should say why (%s)." % _hud.get_message_text())
	# A second successful throw: one more.
	await _stand_and_look(Vector3(-30.0, B, -25.0), Vector3(-22.0, B, -25.0))
	await _press("use_item")
	await _seconds(1.0)
	thrown = _noises.filter(func(e: NoiseEvent): return e.source_group == "distraction")
	_expect(_inventory.distractions_used == 2 and _inventory.count() == 1 and thrown.size() == 2,
		"Second throw: two used, two noises (used %d, noises %d)." % [_inventory.distractions_used, thrown.size()])
	system.noise_emitted.disconnect(_on_noise)

	# Documents: journal, not slots; once each.
	var before := _inventory.slots.duplicate()
	var log_doc: DocumentPickup = _level.get_node("Expansion/Gameplay/Documents/PumpRoomLog")
	await _stand_and_look(log_doc.global_position + Vector3(-1.3, -1.4, 0), log_doc.global_position)
	_expect(_interactor.focused == log_doc, "The pump room log should be readable.")
	await _press("interact")
	await _press("interact")
	# Documents only: since expansion Phase 7 the journal also holds route clues.
	var docs_only := func() -> int: return _inventory.documents.filter(func(d): return d.get("kind", "document") == "document").size()
	_expect(docs_only.call() == 1 and _inventory.has_document(&"pump_room_log") and _inventory.slots == before,
		"Reading twice: one journal entry, carried slots unchanged (journal %d)." % docs_only.call())
	_expect(_hud.is_journal_open(), "Reading a document should open the journal.")
	await _press("journal")
	_expect(not _hud.is_journal_open(), "J should close the journal.")
	await _press("journal")
	_expect(_hud.is_journal_open(), "J should open the journal.")
	await _press("journal")
	var notice: DocumentPickup = _level.get_node("Expansion/Gameplay/Documents/ElectricalNotice")
	_expect(notice.interact(_player) and docs_only.call() == 2 and _inventory.slots == before,
		"A second document: two journal entries, slots unchanged.")
	print("  [expansion-mechanics] inventory: 3 slots, 4th item and the card refused with full hands; tool kit operated 2 mechanisms and F ×3, still carried; 2 throws → 2 used, 2 noises, guard investigated; failed throw used nothing; journal 2 documents, read twice = once")


func _on_noise(event: NoiseEvent) -> void:
	_noises.append(event)


# --- D. Storage shelves ------------------------------------------------------------------------

func _check_storage() -> void:
	await _load(false)
	var shelf: ItemStorage = _level.get_node("Expansion/Gameplay/Storage/MaintenanceShelf")
	var totals := _totals()
	for n in ["ToolKit", "BottleTunnel", "HardbackTunnel"]:
		await _take(n)
	_expect(_inventory.count() == 3, "Three items for the shelf test.")
	# Leave the selected item (slot 2) with E.
	await _press("item_slot_2")
	var at := shelf.global_position + shelf.global_basis.z * 1.1
	at.y = B
	await _stand_and_look(at, shelf.global_position + Vector3(0, -0.05, 0) + shelf.global_basis.x * 0.2)
	_expect(_interactor.focused == shelf, "The shelf should be usable (focused %s)." % _interactor.focused)
	_expect(_hud.get_prompt_text().contains("Leave the glass bottle"), "Shelf prompt: %s." % _hud.get_prompt_text())
	await _press("interact")
	_expect(_inventory.count() == 2 and _inventory.get_item(1) == &"" and shelf.count() == 1 and shelf.contents[0] == ItemCatalog.BOTTLE,
		"E at the shelf leaves the selected bottle there (shelf %s, slots %s)." % [shelf.contents, _inventory.slots])
	_expect(_totals() == totals, "Leaving an item must not create or lose any (%s vs %s)." % [_totals(), totals])
	await _frames(3)
	# Take it back from the shelf.
	var stored: ItemPickup = shelf.get_node_or_null("Stored0")
	_expect(stored != null and stored.visible, "The bottle should lie on the shelf.")
	if stored:
		await _look_at(stored.global_position + Vector3(0, 0.1, 0))
		_expect(_interactor.focused == stored, "The stored bottle should be usable.")
		await _press("interact")
		await _frames(3)
	_expect(_inventory.count() == 3 and shelf.count() == 0 and _totals() == totals, "Taking it back: three carried, shelf empty, nothing duplicated.")
	# Swap: leave the tool kit, then with full hands swap the hardback for it.
	await _press("item_slot_1")
	await _look_at(shelf.global_position + Vector3(0, -0.05, 0) + shelf.global_basis.x * 0.2)
	await _press("interact")
	_expect(shelf.contents.has(ItemCatalog.TOOLKIT) and _inventory.count() == 2, "Tool kit left on the shelf.")
	var bottle2: ItemPickup = _item("BottleCableBay")
	_inventory.put_in_slot(0, ItemCatalog.BOTTLE)   # stands in for picking up the second bottle elsewhere
	bottle2.taken = true
	bottle2.visible = false
	await _press("item_slot_3")
	await _frames(3)
	var kit_place := shelf.contents.find(ItemCatalog.TOOLKIT)
	var kit: ItemPickup = shelf.get_node_or_null("Stored%d" % kit_place)
	await _stand_and_look(at, kit.global_position + Vector3(0, 0.1, 0))
	_expect(_interactor.focused == kit and _hud.get_prompt_text().contains("Swap the heavy hardback for the tool kit"),
		"With full hands, a stored item offers a swap (prompt %s)." % _hud.get_prompt_text())
	await _press("interact")
	await _frames(3)
	_expect(_inventory.get_item(2) == ItemCatalog.TOOLKIT and shelf.contents[kit_place] == ItemCatalog.HARDBACK and _inventory.count() == 3,
		"Swap: the hardback goes on the shelf, the tool kit into slot 3 (slots %s, shelf %s)." % [_inventory.slots, shelf.contents])
	_expect(_totals() == totals, "Swapping must not create or lose items (%s vs %s)." % [_totals(), totals])
	# Nowhere else to drop: no drop action, the use key keeps tools and cards.
	_expect(not InputMap.has_action("drop_item"), "There must be no drop-anywhere action.")
	await _press("item_slot_3")
	await _press("use_item")
	_expect(_inventory.get_item(2) == ItemCatalog.TOOLKIT, "The use key must not drop the tool kit.")
	print("  [expansion-mechanics] storage: leave, take back and swap at the maintenance shelf with E; item totals unchanged %s" % [totals])


# --- E. Card doors -----------------------------------------------------------------------------

func _check_card_doors() -> void:
	await _load(false)
	var card: AccessCard = _level.get_node("Gameplay/StaffAccessCard")
	var g4: AccessDoor = _level.get_node("Gameplay/LobbyStaffDoorG4")
	var g2: AccessDoor = _level.get_node("Gameplay/ArchiveFrontGateG2")
	var electrical: AccessDoor = _level.get_node("Expansion/Gameplay/ElectricalRoomDoor")
	_expect(card.grants_item == ItemCatalog.STAFF_CARD and g4.key_item == ItemCatalog.STAFF_CARD and g2.key_item == ItemCatalog.STAFF_CARD
		and electrical.key_item == ItemCatalog.STAFF_CARD, "The staff card and the three staff doors should use the carried card.")
	_objectives.complete(&"enter_library")
	_expect(card.interact(_player) and _inventory.has(ItemCatalog.STAFF_CARD) and _objectives.is_completed(&"take_card"),
		"Taking the card completes its objective and puts it in a slot.")
	# Reusable: three doors, still carried.
	for d in [g4, electrical, g2]:
		_expect(d.interact(_player) and d.is_open, "%s should open with the carried card." % d.door_name)
	_expect(_inventory.has(ItemCatalog.STAFF_CARD) and _inventory.count() == 1, "The card is not used up by doors.")
	# Objective done but the card not carried (left on a shelf): staff doors refuse.
	for d in [g4, electrical, g2]:
		d.restore_checkpoint_state({"open": false})
	var shelf: ItemStorage = _level.get_node("Expansion/Gameplay/Storage/ElectricalShelf")
	_expect(shelf.interact(_player) and not _inventory.has(ItemCatalog.STAFF_CARD) and shelf.contents.has(ItemCatalog.STAFF_CARD),
		"The card can be left on a shelf.")
	_expect(not g4.interact(_player) and not g4.is_open and g4.rejections == 1, "Without the carried card the staff door refuses (objective done).")
	_expect(g4.get_prompt(_player).contains("locked"), "The door's prompt says it is locked.")
	await _frames(3)
	var stored: ItemPickup = shelf.get_node("Stored0")
	_expect(stored.interact(_player) and _inventory.has(ItemCatalog.STAFF_CARD), "Taking the card back.")
	_expect(g4.interact(_player) and g4.is_open, "With the card back, the door opens.")
	print("  [expansion-mechanics] card doors: G4, electrical room and G2 opened with the carried card, card kept; card on a shelf → G4 refused")


# --- F. Checkpoints ----------------------------------------------------------------------------

func _check_checkpoints() -> void:
	await _load(false)
	var shelf: ItemStorage = _level.get_node("Expansion/Gameplay/Storage/MaintenanceShelf")
	var totals := _totals()
	await _take("ToolKit")
	await _take("BottleTunnel")
	await _take("HardbackTunnel")
	await _press("item_slot_3")
	_expect(shelf.interact(_player), "Hardback left on the shelf before the checkpoint.")
	var checkpoint: Checkpoint = _level.get_node("Gameplay/" + Layout.CHECKPOINTS[0].node)
	_checkpoints.activate(checkpoint)
	var saved_slots := _inventory.slots.duplicate()
	var saved_shelf := shelf.contents.duplicate()
	_expect(saved_slots == [ItemCatalog.TOOLKIT, ItemCatalog.BOTTLE, &""] and saved_shelf.has(ItemCatalog.HARDBACK), "Checkpoint state set up.")
	for round in 3:
		# Progress after the checkpoint: take the last bottle, throw one, swap at the shelf.
		await _take("BottleCableBay")
		await _press("item_slot_2")
		await _stand_and_look(Vector3(30.0, B, -25.0), Vector3(20.0, B, -25.0))
		await _press("use_item")
		_expect(_inventory.distractions_used == round + 1, "Round %d: a throw after the checkpoint." % round)
		_stamina.stamina = 5.0
		await _catch_and_respawn(Vector3(-30.0, B, -25.0), Vector3(-25.0, B, -25.0))
		_expect(_inventory.slots == saved_slots, "Round %d: caught → carried slots back to the checkpoint (%s, expected %s)." % [round, _inventory.slots, saved_slots])
		_expect(shelf.contents == saved_shelf, "Round %d: shelf back to the checkpoint (%s)." % [round, shelf.contents])
		_expect(_item("BottleCableBay").visible and not _item("BottleCableBay").taken and _item("ToolKit").taken,
			"Round %d: pickups back as at the checkpoint." % round)
		_expect(_totals() == totals, "Round %d: no item duplicated or lost after the restore (%s vs %s)." % [round, _totals(), totals])
		_expect(_host.get_tree().get_nodes_in_group("thrown_items").filter(func(n): return not n.is_queued_for_deletion()).is_empty(),
			"Round %d: a throw made after the checkpoint is undone." % round)
		_expect(_stamina.stamina == 100.0, "Round %d: stamina full after the respawn." % round)
		await _frames(5)
	# The card: taken after the checkpoint → back on the desk and out of the slots.
	# (Off the Study Rooms pad first: standing on a checkpoint saves continuously.)
	await _teleport(Vector3(-30.0, B, -25.0))
	_objectives.complete(&"enter_library")
	_checkpoints.activate(checkpoint)
	var card: AccessCard = _level.get_node("Gameplay/StaffAccessCard")
	_inventory.take_from_slot(1)   # make room
	_inventory.take_from_slot(0)
	_checkpoints.activate(checkpoint)
	_expect(card.interact(_player) and _inventory.has(ItemCatalog.STAFF_CARD), "Card taken after the checkpoint.")
	await _catch_and_respawn(Vector3(-30.0, B, -25.0), Vector3(-25.0, B, -25.0))
	_expect(card.visible and not _inventory.has(ItemCatalog.STAFF_CARD) and _objectives.current() == &"take_card",
		"Caught: the card is back on the desk and not carried (no duplicate).")
	await _teleport(Vector3(-30.0, B, -25.0))
	_expect(card.interact(_player) and _inventory.has(ItemCatalog.STAFF_CARD), "The card can be taken again.")
	_checkpoints.activate(checkpoint)
	await _catch_and_respawn(Vector3(-30.0, B, -25.0), Vector3(-25.0, B, -25.0))
	_expect(not card.visible and _inventory.slots.count(ItemCatalog.STAFF_CARD) == 1, "Card taken before the checkpoint: kept, exactly once.")
	print("  [expansion-mechanics] checkpoints: 3 catches restored slots %s and shelf %s exactly, no duplicates, throws undone, stamina full; card before/after the checkpoint consistent" % [saved_slots, saved_shelf])


## How many of each item exist: carried, on shelves, lying in the level (not taken), the card on its desk.
func _totals() -> Dictionary:
	var totals := {}
	var add := func(id: StringName): if id != &"": totals[id] = totals.get(id, 0) + 1
	for id in _inventory.slots:
		add.call(id)
	for shelf in _host.get_tree().get_nodes_in_group("item_storage"):
		for id in shelf.contents:
			add.call(id)
	for p in _host.get_tree().get_nodes_in_group("item_pickups"):
		if not p.taken:
			add.call(p.item_id)
	var card: AccessCard = _level.get_node("Gameplay/StaffAccessCard")
	if card.visible:
		add.call(card.grants_item)
	return totals


# --- G. Tutorial -------------------------------------------------------------------------------

func _check_tutorial_unchanged() -> void:
	await _unload()
	var level: Node3D = (load(TUTORIAL) as PackedScene).instantiate()
	for g in level.get_node("Guards").get_children():
		g.get_parent().remove_child(g)
		g.free()
	_host.add_child(level)
	await _frames(10)
	var player: FirstPersonPlayer = level.get_node("Player")
	var stamina: PlayerStamina = player.get_node("Stamina")
	var inventory: PlayerInventory = player.get_node("Inventory")
	var hud: ObjectiveHud = level.get_node_or_null("ObjectiveHud")
	var menus = level.get_node_or_null("GameMenus")
	_expect(not player.use_stamina and not player.use_inventory and not stamina.enabled and not inventory.enabled,
		"The tutorial must not use stamina or the inventory.")
	_expect(not inventory.is_in_group("checkpoint_state"), "The tutorial's checkpoint snapshots must not include an inventory.")
	_expect(hud == null or (hud.get_inventory() == null and hud.get_slot_texts().is_empty()), "The tutorial shows no item slots.")
	var stealth := level.get_node_or_null("StealthHud") as StealthHud
	_expect(stealth == null or stealth.get_stamina() == null, "The tutorial shows no stamina bar.")
	if menus:
		_expect(menus.get_controls_text() == GameMenus.CONTROLS, "The tutorial's pause menu controls are unchanged (%s)." % menus.get_controls_text())
	var card := level.get_node_or_null("Gameplay/AccessCard")
	if card == null:
		for n in level.find_children("*", "Area3D", true, false):
			if n is AccessCard:
				card = n
	_expect(card != null and card.grants_item == &"", "The tutorial's access card stays an objective pickup only.")
	for d in level.find_children("*", "Area3D", true, false):
		if d is AccessDoor:
			_expect(d.key_item == &"", "Tutorial door %s must keep its objective key." % d.name)
	# Unlimited sprint: 8 s of held sprint, in 1 s legs from the spawn (put back at
	# the start of each leg, keeping its velocity), at sprint speed throughout.
	var start := player.global_position
	player.rotation.y = 0.0
	player.head.rotation.x = 0.0
	await _frames(3)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var slow := 0
	var checked := 0
	for leg in 8:
		player.global_position = start
		for k in 60:
			await _host.get_tree().physics_frame
			if leg > 0 or k > 30:
				checked += 1
				if Vector2(player.velocity.x, player.velocity.z).length() < player.sprint_speed - 0.2:
					slow += 1
	_release_all()
	_expect(checked > 400 and slow == 0, "Tutorial: sprinting must stay unlimited (%d of %d frames below sprint speed in 8 s)." % [slow, checked])
	level.queue_free()
	await _frames(30)
	print("  [expansion-mechanics] tutorial: no stamina, inventory, item HUD or new controls; card and doors objective-keyed; 8 s unlimited sprint")


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
	_player = _level.get_node("Player")
	_inventory = _player.get_node("Inventory")
	_stamina = _player.get_node("Stamina")
	_interactor = _player.get_node("Interactor")
	_objectives = _level.get_node("Gameplay/ObjectiveManager")
	_checkpoints = _level.get_node("Gameplay/CheckpointManager")
	_director = _level.get_node("StealthDirector")
	_hud = _level.get_node("ObjectiveHud")
	_guard = null
	_route = null
	GameFlow.find(_level).change_scene = func(_path: String): pass
	await _frames(10)


func _unload() -> void:
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	_release_all()
	_clear_guard()
	if _level and is_instance_valid(_level):
		_level.queue_free()
		_level = null
		await _frames(30)


func _item(node_name: String) -> ItemPickup:
	return _level.get_node("Expansion/Gameplay/Items/" + node_name)


func _aim(node: Node3D) -> Vector3:
	return node.global_position + Vector3(0, 0.12, 0)


## Stands next to a provisional item and takes it with E. True if it ended up carried.
func _take(node_name: String) -> bool:
	var pickup := _item(node_name)
	var before := _inventory.count()
	await _stand_and_look(STAND[node_name], _aim(pickup))
	if _interactor.focused != pickup:
		_expect(false, "%s is not in reach from %s (focused %s)." % [node_name, STAND[node_name], _interactor.focused])
		return false
	await _press("interact")
	return pickup.taken and _inventory.count() == before + 1


func _teleport(at: Vector3) -> void:
	_player.global_position = at + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	await _frames(4)


func _stand_and_look(at: Vector3, target: Vector3) -> void:
	_player.global_position = at + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	await _frames(2)
	await _look_at(target)


func _look_at(target: Vector3) -> void:
	var at := _player.global_position
	_player.rotation.y = atan2(-(target.x - at.x), -(target.z - at.z))
	var eye := at.y + _player.stand_eye_height
	var flat := Vector2(target.x - at.x, target.z - at.z).length()
	_player.head.rotation.x = atan2(target.y - eye, flat)
	await _frames(4)


## Presses and releases an input action as real input events.
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


func _release_all() -> void:
	for a in ["move_forward", "move_backward", "move_left", "move_right", "sprint", "crouch"]:
		Input.action_release(a)


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
	_guard.name = "MechanicsTestGuard"
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


func _seconds(seconds: float) -> void:
	await _frames(int(round(seconds * Engine.physics_ticks_per_second)))


func _frames(count: int) -> void:
	for i in count:
		await _host.get_tree().physics_frame
