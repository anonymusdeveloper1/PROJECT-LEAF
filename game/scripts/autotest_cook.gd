## Cooking checks for autotest.gd (`-- --autotest --fresh --cook`; scripts/cooking.gd, and the pot's window
## ui/windows/cooking_window.gd through hud.cooking_window; H3 26 Nov 2026).
## A pretend clock (a method of this node: a lambda would copy its locals and not see the test move the clock) stands in
## for the real one: base + offset, held still between moves, with base a whole second just past the real now and the
## save's seen. At the end the pot's job is removed and Timers.use_real_clock() puts the real clock and seen back, so no
## future seen stays in the test save; the Gloom meter, the fire and the Bag are put back too.
## The window is used as a player would: a real drag of an ingredient into a slot, real taps on the ingredients (Q15)
## and its Cook and Collect buttons. Its slots are checked by what they do (Cook then makes a potion, or nothing), not
## by the window's own fields; the window only has to keep the stub API (map 3.10) and use the drag kit.
## Checks: Cooked Fish hidden until fishing; needed_ingredients in ingredients order; match_recipe is exact; Cook makes
## something only on an exact match; Cook takes the ingredients, starts "cook:pot" and gives Gloom +3 on the tap; a
## second Cook is refused; the job ends "while the game is closed" (save, clock, reload), is told once, gives no Gloom,
## and its handler alone makes the ring pulse; the handler ignores other "cook:" jobs; Collect puts the result in the
## Bag and the ring stops pulsing at once; a crop and the pot done in the same check give one toast that says both (the
## garden's first plot is emptied again after it); a full stack: "Bag full" and the result waits; Cook refused with no room;
## the fire out: the ring hides, the timer runs, Cook and Collect wait; a real tap on a filled slot empties just that
## slot; the card blank in a wave, and nothing cooked or
## collected then; the slots stay through a wave blank and the rebuild after it, and empty when the card closes; the
## window fits the card without scrolling.
extends Node

const AutotestScript := preload("res://scripts/autotest.gd")
const DragSourceScript := preload("res://ui/kit/drag_source.gd")
const DropSlotScript := preload("res://ui/kit/drop_slot.gd")

const JOB := "cook:pot"                         # the pot's job (cooking.gd acts on this id only)
const OTHER := "cook:autotest_other"            # a job of the same kind that the pot must ignore
const POTION := "health_potion"

var t: AutotestScript
var main

var _base := 0.0
var _offset := 0.0
var _told: Array = []


## The pretend clock (Timers.clock while this test runs).
func _clock() -> float:
	return _base + _offset


func _on_finished(id: String) -> void:
	_told.append(id)


func run() -> bool:
	var ck = main.cooking
	var rd = main.raids
	main.player.invincible = true
	var fishing_was := int(Save.stations.get("fishing", 0))
	t._veteran(5)                                    # the garden and its pot; no Fishing Spot yet
	Save.stations["fishing"] = 0
	var bag_was: Dictionary = Save.bag.duplicate(true)
	var manual_was: bool = rd.manual
	var meter_was := float(Save.raids.get("meter", 0.0))
	var pending_was := bool(Save.raids.get("pending", false))
	_empty_bag()
	Timers.remove(JOB)
	var real := Time.get_unix_time_from_system()
	_base = ceilf(maxf(real, float(Save.timers.get("seen", 0.0)))) + 1.0
	_offset = 0.0
	Timers.clock = _clock
	Events.timer_finished.connect(_on_finished)
	rd.open = true                                   # the meter takes action points (add_gloom) ...
	rd.manual = true                                 # ... and nothing else: main's frames do not tick it
	Save.raids["pending"] = false
	Save.raids["meter"] = 0.0
	await t._wait(0.4)

	var ok := _check_recipes(ck)
	ok = await _check_window_cook(ck) and ok
	ok = await _check_finish(ck) and ok
	ok = await _check_joined_toast(ck) and ok
	ok = _check_full_bag(ck) and ok
	ok = _check_fire_out(ck) and ok
	ok = await _check_wave_and_slots(ck) and ok

	# put everything back: no pot job, the real clock and seen, the meter, the fire, the Bag
	main.hud.hide_card()
	Timers.remove(JOB)
	Timers.remove(OTHER)
	Events.timer_finished.disconnect(_on_finished)
	Timers.use_real_clock()
	main.fight.active = false
	main.fight.in_wave = false
	main.fight.set_physics_process(true)
	Save.fire_ruined = false
	main.stations.set_fire_out(false)
	rd.manual = manual_was
	rd.refresh_open()
	Save.raids["meter"] = meter_was
	Save.raids["pending"] = pending_was
	Save.stations["fishing"] = fishing_was
	_empty_bag()
	for k: Variant in bag_was:
		if Bag.kind_of(String(k)) != "":
			Bag.add(String(k), int(bag_was[k]), true)
	main.stations.refresh()
	Save.save_game(true)
	var now_real := Time.get_unix_time_from_system()
	ok = t._expect("at the end the real clock is back, seen is not in the future and the pot is empty",
		float(Save.timers["seen"]) <= now_real + 0.001 and absf(Timers.now() - now_real) < 2.0 and not Timers.has(JOB),
		{"seen": Save.timers["seen"], "real": now_real}) and ok
	return ok


# ---------------------------------------------------------------- the recipes (no window)
func _check_recipes(ck) -> bool:
	var ids := _ids(ck.known())
	var need: Array[String] = ck.needed_ingredients()
	var fish: Array[String] = ["fish"]
	var ok := t._expect("Cooked Fish is hidden until fishing (not known, no fish ingredient, fish matches nothing)",
		not ids.has("cooked_fish") and ids.has(POTION) and not need.has("fish") and ck.match_recipe(fish).is_empty(),
		{"known": ids, "needed": need})
	Save.stations["fishing"] = 1
	ids = _ids(ck.known())
	need = ck.needed_ingredients()
	ok = t._expect("with the Fishing Spot Cooked Fish is known, fish is needed and one fish matches it",
		ids.has("cooked_fish") and need.has("fish") and String(ck.match_recipe(fish).get("id", "")) == "cooked_fish",
		{"known": ids, "needed": need}) and ok
	var want := {}
	for r: Variant in ck.known():
		for k: Variant in (r as Dictionary).get("needs", {}):
			want[String(k)] = true
	var order: Array[String] = []
	for k: Variant in Data.b["ingredients"]:
		if want.has(String(k)):
			order.append(String(k))
	ok = t._expect("needed_ingredients: every ingredient a known recipe needs, once, in balance.json ingredients order",
		need == order, {"needed": need, "expected": order}) and ok
	Save.stations["fishing"] = 0
	var hp: Array[String] = ["herbs", "herbs", "honey"]
	var hp_mixed: Array[String] = ["honey", "herbs", "herbs"]
	var hp_gaps: Array[String] = ["herbs", "", "honey", "herbs"]
	var fewer: Array[String] = ["herbs", "honey"]
	var more: Array[String] = ["herbs", "herbs", "honey", "honey"]
	var none: Array[String] = []
	var blanks: Array[String] = ["", "", ""]
	var mp: Array[String] = ["berries", "honey", "berries"]
	ok = t._expect("match_recipe: the exact pieces in any order (empty slots ignored); nothing for fewer, more or none",
		String(ck.match_recipe(hp).get("id", "")) == POTION and String(ck.match_recipe(hp_mixed).get("id", "")) == POTION
		and String(ck.match_recipe(hp_gaps).get("id", "")) == POTION and ck.match_recipe(fewer).is_empty()
		and ck.match_recipe(more).is_empty() and ck.match_recipe(none).is_empty() and ck.match_recipe(blanks).is_empty()
		and String(ck.match_recipe(mp).get("id", "")) == "mount_potion") and ok
	ok = t._expect("an empty pot with no ingredients: nothing to cook, no pulse", ck.cooking_id() == "" and not ck.is_ready()
		and is_zero_approx(ck.left_s()) and not ck.wants_pulse() and ck.collect() == "The pot is empty"
		and ck.cook("nope") == "Not known yet" and String(ck.can_cook(Data.recipe(POTION))).begins_with("Need ")) and ok
	return ok


# ---------------------------------------------------------------- the window: drag, taps, Cook
func _check_window_cook(ck) -> bool:
	var ring = main.stations.rings["pot"]
	var hud = main.hud
	Bag.add("herbs", 3, true)
	Bag.add("honey", 1, true)
	await t._at_ring(ring)
	await t._wait(0.6)
	var ok := t._expect("the pot's card opens with its window", hud.card_ring() == ring and hud._card_window == hud.cooking_window,
		{"title": hud.card_title()})
	var slots := _pot_slots()
	ok = t._expect("the window has the pot's slots and the ingredient tiles (no fish tile before fishing)",
		slots.size() == int(Data.b["cooking"]["pot_slots"]) and _source("herbs") != null and _source("honey") != null
		and _source("fish") == null, {"slots": slots.size()}) and ok
	ok = t._expect("the pot's window fits the card without scrolling (empty pot)", _fits(), _fit_info()) and ok
	await t._shot("cook_window")
	var m0 := float(Save.raids["meter"])
	var src := _source("herbs")
	if src != null and not slots.is_empty():
		await _drag(src.get_global_rect().get_center(), (slots[0] as Control).get_global_rect().get_center(), 0.45)
	await t._wait(0.7)
	ok = t._expect("a real drag puts a Fernmint in the first slot (it shows its picture; nothing leaves the Bag)",
		_slot_shows(_slot_at(0), "herbs") and Bag.count("herbs") == 3) and ok
	await _press("Cook")
	ok = t._expect("one Fernmint in the pot: Cook makes nothing", not Timers.has(JOB) and Bag.count("herbs") == 3
		and Bag.count("honey") == 1) and ok
	await _tap_ingredient("herbs")
	ok = t._expect("a real tap on the Fernmint tile fills the next slot", _slot_shows(_slot_at(1), "herbs")) and ok
	await _press("Cook")
	ok = t._expect("two Fernmint in the pot (not a recipe): Cook makes nothing", not Timers.has(JOB) and Bag.count("herbs") == 3) and ok
	await _tap_ingredient("honey")
	var pieces: Array[String] = ["herbs", "herbs", "honey"]
	var m: Dictionary = ck.match_recipe(pieces)
	ok = t._expect("Fernmint, Fernmint and honey make the Health Potion, and it can be cooked",
		String(m.get("id", "")) == POTION and ck.can_cook(m) == "" and _slot_shows(_slot_at(2), "honey"), {"why": ck.can_cook(m)}) and ok
	await t._shot("cook_window_full")
	var pressed: bool = await _press("Cook")
	var cook_s := float(Data.recipe(POTION)["cook_s"])
	var gloom := float(Data.gr()["meter"]["actions"]["dish"])
	ok = t._expect("Cook takes the ingredients and starts the pot's job", pressed and Timers.has(JOB)
		and String(Timers.job_data(JOB).get("recipe", "")) == POTION and Bag.count("herbs") == 1 and Bag.count("honey") == 0
		and ck.cooking_id() == POTION and not ck.is_ready() and is_equal_approx(ck.left_s(), cook_s),
		{"herbs": Bag.count("herbs"), "honey": Bag.count("honey"), "left": ck.left_s()}) and ok
	ok = t._expect("Gloom +%d on the Cook tap" % int(gloom), is_equal_approx(float(Save.raids["meter"]) - m0, gloom),
		{"meter": Save.raids["meter"], "before": m0}) and ok
	await t._wait(0.7)
	ok = t._expect("the pot's window fits the card without scrolling (cooking)", _fits(), _fit_info()) and ok
	await t._shot("cook_cooking")
	Bag.add("herbs", 1, true)                        # enough for a second one: the busy pot must be the reason
	Bag.add("honey", 1, true)
	var why: String = ck.cook(POTION)
	ok = t._expect("a second Cook is refused while it cooks", why == "Cooking already" and Bag.count("herbs") == 2
		and Bag.count("honey") == 1 and String(Timers.job_data(JOB).get("recipe", "")) == POTION
		and is_equal_approx(float(Save.raids["meter"]) - m0, gloom), {"why": why}) and ok
	Bag.take("herbs", 1)
	Bag.take("honey", 1)                             # herbs 1, honey 0: nothing else can be cooked now
	return ok


# ---------------------------------------------------------------- the end of the job, the handler, Collect
func _check_finish(ck) -> bool:
	var ring = main.stations.rings["pot"]
	var cook_s := float(Data.recipe(POTION)["cook_s"])
	var m0 := float(Save.raids["meter"])
	_offset = cook_s * 0.5
	var ok := t._expect("the job follows the clock (half way)", is_equal_approx(ck.left_s(), cook_s * 0.5)
		and is_equal_approx(Timers.progress(JOB), 0.5) and not ck.is_ready(), {"left": ck.left_s()})
	main.stations.refresh()
	ok = t._expect("while it cooks the ring does not pulse (nothing else can be cooked)", not ring.pulse and not ck.wants_pulse()) and ok
	# the game "closes": saved, the clock goes past the end, loaded again
	Save.save_game(true)
	_offset = cook_s + 5.0
	_told.clear()
	Save.load_game()
	# no await from here to the checks: neither Timers' own check nor anything else can run in between
	var ready_after_load: bool = ck.is_ready() and ck.cooking_id() == POTION and _told.is_empty()
	var pulse_before: bool = ring.pulse
	Timers.check()
	ok = t._expect("it finished while the game was closed: after the reload the result is ready", ready_after_load) and ok
	ok = t._expect("the end is told once, with the pot's id", _told.count(JOB) == 1, {"told": _told}) and ok
	ok = t._expect("the handler alone makes the pot's ring pulse (nothing else refreshed the stations)",
		not pulse_before and ring.pulse and ck.wants_pulse()) and ok
	await get_tree().process_frame                   # H3 stage 3: the pot's toast waits for the end of the frame (cooking.gd)
	await get_tree().process_frame
	var toast := String(main.hud._toast.text)
	ok = t._expect("the handler says it is ready at the pot", toast.contains(Data.item_name(POTION, 1)) and toast.contains("ready"),
		{"toast": toast}) and ok
	Timers.check()
	ok = t._expect("a second check tells nothing", _told.count(JOB) == 1, {"told": _told}) and ok
	ok = t._expect("the timer's end gives no Gloom", is_equal_approx(float(Save.raids["meter"]), m0), {"meter": Save.raids["meter"]}) and ok
	# another job of the same kind is not the pot's
	main.hud.toast("-")
	Timers.start(OTHER, 1.0)
	_offset += 2.0
	Timers.check()
	ok = t._expect("the handler ignores another cook job", String(main.hud._toast.text) == "-" and ck.cooking_id() == POTION,
		{"toast": main.hud._toast.text}) and ok
	Timers.remove(OTHER)
	main.hud._toast.text = ""                        # the test's own "-" marker stays out of the picture
	await t._wait(0.7)                               # the window's tick swaps the bar for Collect
	await t._shot("cook_ready")
	var b := _button("Collect")
	ok = t._expect("the window shows Collect when the job ends", b != null) and ok
	if b != null:
		b.pressed.emit()
	else:
		ck.collect()
	ok = t._expect("Collect puts the Health Potion in the Bag and empties the pot", Bag.count(POTION) == 1 and not Timers.has(JOB)
		and ck.cooking_id() == "" and not ck.is_ready(), {"potions": Bag.count(POTION)}) and ok
	ok = t._expect("after Collect the pot's ring stops pulsing at once", not ring.pulse and not ck.wants_pulse()) and ok
	return ok


# ---------------------------------------------------------------- a crop and the pot done in the same check
## One Timers.check ends a crop's job and the pot's: one toast says both (garden.gd _flush_ripe takes the pot's line).
func _check_joined_toast(ck) -> bool:
	var g = main.garden
	var leaves_was: int = Save.leaves
	Timers.remove("crop:0")
	Save.garden[0] = {"crop": ""}
	Save.leaves = 1000
	Bag.add("herbs", 2, true)
	Bag.add("honey", 1, true)
	var planted: String = g.plant("sunberry", 0)
	var cooked: String = ck.cook(POTION)
	var ok := t._expect("a crop and the pot both started", planted == "" and cooked == "" and Timers.has("crop:0")
		and Timers.has(JOB), {"plant": planted, "cook": cooked})
	main.hud.toast("-")
	_offset += maxf(float(Data.crop("sunberry")["grow_s"]), float(Data.recipe(POTION)["cook_s"])) + 5.0
	Timers.check()
	await get_tree().process_frame                   # both toasts wait for the end of the frame
	await get_tree().process_frame
	var want := "Ripe in the garden: %s · %s is ready at the pot" % [String(Data.crop("sunberry")["name"]),
		Data.item_name(POTION, 1)]
	var toast := String(main.hud._toast.text)
	ok = t._expect("a crop and the pot done in the same check: one toast says both", toast == want,
		{"toast": toast, "want": want}) and ok
	ck.collect()                                     # the potion into the Bag (herbs 1, honey 0 as before)
	Timers.remove("crop:0")
	Save.garden[0] = {"crop": ""}
	g.refresh_look()
	Save.leaves = leaves_was
	main.hud._toast.text = ""
	main.stations.refresh()
	return ok


# ---------------------------------------------------------------- a full Bag
func _check_full_bag(ck) -> bool:
	var cook_s := float(Data.recipe(POTION)["cook_s"])
	var lim := Bag.limit(POTION)
	Bag.add("herbs", 2, true)
	Bag.add("honey", 1, true)
	Bag.add(POTION, lim - 1 - Bag.count(POTION), true)            # one short of the limit
	var why: String = ck.cook(POTION)
	var ok := t._expect("with room for one more, Cook starts", why == "" and Timers.has(JOB), {"why": why})
	var put := Bag.add(POTION, 1)                                 # the stack fills while it cooks
	_offset += cook_s + 1.0
	Timers.check()
	why = ck.collect()
	ok = t._expect("a full stack at Collect: \"Bag full\" and the result waits in the pot", why == "Bag full" and put == 1
		and Bag.count(POTION) == lim and Timers.has(JOB) and ck.is_ready() and ck.wants_pulse(), {"why": why}) and ok
	Bag.take(POTION, 1)
	why = ck.collect()
	ok = t._expect("with room again, Collect works", why == "" and Bag.count(POTION) == lim and not Timers.has(JOB), {"why": why}) and ok
	# Cook is refused when the result would not fit now (Q16)
	Bag.add("herbs", 2, true)
	Bag.add("honey", 1, true)
	why = ck.can_cook(Data.recipe(POTION))
	var cooked: String = ck.cook(POTION)
	ok = t._expect("Cook is refused when the result would not fit now (the potion at its limit)", why == "No room in the Bag"
		and cooked == why and not Timers.has(JOB) and Bag.count("herbs") == 3 and Bag.count("honey") == 1, {"why": why}) and ok
	Bag.add("berries", 2, true)
	Bag.add("berries", Bag.room_for("berries"), true)            # every slot full
	why = ck.can_cook(Data.recipe("mount_potion"))
	ok = t._expect("Cook is refused for a potion the Bag has none of when every slot is full", Bag.free_slots() == 0
		and Bag.count("mount_potion") == 0 and why == "No room in the Bag", {"why": why, "free": Bag.free_slots()}) and ok
	Bag.take("berries", Bag.count("berries"))
	why = ck.can_cook(Data.recipe("mount_potion"))
	ok = t._expect("short of an ingredient: \"Need ...\"", why.begins_with("Need ") and why.contains(Data.item_name("berries", 2)),
		{"why": why}) and ok
	return ok


# ---------------------------------------------------------------- the fire out (Q13)
func _check_fire_out(ck) -> bool:
	var ring = main.stations.rings["pot"]
	var cook_s := float(Data.recipe(POTION)["cook_s"])
	Bag.take(POTION, Bag.count(POTION))
	var why: String = ck.cook(POTION)
	var ok := t._expect("cooking again", why == "", {"why": why})
	main.stations.set_fire_out(true)
	main.stations.refresh()
	var left0: float = ck.left_s()
	why = ck.can_cook(Data.recipe("mount_potion"))
	ok = t._expect("the fire out: the pot's ring hides and nothing is cooked", not ring.visible and why == "The fire is out"
		and ck.cook("mount_potion") == "The fire is out", {"why": why}) and ok
	_offset += 10.0
	ok = t._expect("the fire out: the timer still runs", is_equal_approx(ck.left_s(), left0 - 10.0), {"left": ck.left_s(), "before": left0}) and ok
	_offset += cook_s
	Timers.check()
	main.stations.refresh()
	why = ck.collect()
	ok = t._expect("the fire out: done, but Collect waits for the fire (and the hidden ring does not pulse)", ck.is_ready()
		and why == "The fire is out" and Timers.has(JOB) and not ring.pulse, {"why": why}) and ok
	main.stations.set_fire_out(false)
	main.stations.refresh()
	why = ck.collect()
	ok = t._expect("the fire back: the ring shows and Collect works", ring.visible and why == "" and Bag.count(POTION) == 1,
		{"why": why}) and ok
	Save.fire_ruined = true
	why = ck.can_cook(Data.recipe(POTION))
	Save.fire_ruined = false
	ok = t._expect("on the ashes (the camp fell) nothing is cooked either", why == "The fire is out", {"why": why}) and ok
	return ok


# ---------------------------------------------------------------- a wave, and the slots through a visit
func _check_wave_and_slots(ck) -> bool:
	var ring = main.stations.rings["pot"]
	var cook_s := float(Data.recipe(POTION)["cook_s"])
	if main.hud.card_ring() != ring:
		await t._at_ring(ring)
	Bag.add("herbs", 2 - Bag.count("herbs"), true)
	Bag.add("honey", 1 - Bag.count("honey"), true)
	await t._wait(0.7)                               # the window redraws with the new counts
	# a real tap on a filled slot empties it (and only it)
	await _tap_ingredient("herbs")
	await _tap_ingredient("herbs")
	var both: bool = _slot_shows(_slot_at(0), "herbs") and _slot_shows(_slot_at(1), "herbs")
	var s0 := _slot_at(0)
	var has_s0 := s0 != null                         # noted before the tap: the window's redraw frees the slot
	if has_s0:
		await t._tap_at(s0.get_global_rect().get_center())
	await t._wait(0.4)
	var ok := t._expect("a real tap on a filled slot empties it: slot 1 is empty, slot 2 still holds its Fernmint", has_s0 and both
		and not _slot_shows(_slot_at(0), "herbs") and _slot_shows(_slot_at(1), "herbs"), {"slot": has_s0, "both": both})
	await _press("Cook")
	ok = t._expect("then one Fernmint is left in the pot: Cook makes nothing", not Timers.has(JOB) and Bag.count("herbs") == 2
		and Bag.count("honey") == 1) and ok
	var s1 := _slot_at(1)
	var has_s1 := s1 != null
	if has_s1:
		await t._tap_at(s1.get_global_rect().get_center())
	await t._wait(0.4)
	ok = t._expect("a real tap on the other slot empties the pot", has_s1 and not _slot_shows(_slot_at(0), "herbs")
		and not _slot_shows(_slot_at(1), "herbs")) and ok
	await _tap_ingredient("herbs")
	await _tap_ingredient("herbs")
	await _tap_ingredient("honey")
	_wave(true)
	main.hud.refresh_card()
	await t._wait(0.3)
	ok = t._expect("in a wave the pot's card is blank (no Cook, no ingredients)", main.hud.card_open() and _button("Cook") == null
		and _source("herbs") == null and main.hud.card_buttons().is_empty(), {"buttons": main.hud.card_buttons().size()}) and ok
	var why: String = ck.cook(POTION)
	ok = t._expect("in a wave nothing is cooked", why == "A wave is on" and Bag.count("herbs") == 2 and not Timers.has(JOB), {"why": why}) and ok
	await t._shot("cook_wave_blank")
	_wave(false)
	main.hud.refresh_card()
	await t._wait(0.5)
	await _press("Cook")
	ok = t._expect("the slots stay through a wave blank and the rebuild after it (Cook then makes the Health Potion)",
		Timers.has(JOB) and ck.cooking_id() == POTION and Bag.count("herbs") == 0 and Bag.count("honey") == 0) and ok
	_offset += cook_s + 1.0
	Timers.check()
	_wave(true)
	why = ck.collect()
	_wave(false)
	ok = t._expect("in a wave nothing is collected: the result waits", why == "A wave is on" and Timers.has(JOB) and ck.is_ready(),
		{"why": why}) and ok
	main.hud.refresh_card()
	await t._wait(0.7)
	var b := _button("Collect")
	if b != null:
		b.pressed.emit()
	else:
		ck.collect()
	ok = t._expect("collected after the wave", not Timers.has(JOB) and Bag.count(POTION) == 2, {"potions": Bag.count(POTION)}) and ok
	# the slots empty when the card closes (closed())
	Bag.add("herbs", 2, true)
	Bag.add("honey", 1, true)
	await t._wait(0.7)
	await _tap_ingredient("herbs")
	await _tap_ingredient("herbs")
	await _tap_ingredient("honey")
	await t._tap_close()
	await t._wait(0.3)
	ok = t._expect("the card closed", not main.hud.card_open()) and ok
	await t._at_ring(ring)
	await t._wait(0.6)
	await _press("Cook")
	ok = t._expect("closing the card empties the slots (opened again, Cook makes nothing; the Bag is untouched)",
		main.hud.card_ring() == ring and not Timers.has(JOB) and Bag.count("herbs") == 2 and Bag.count("honey") == 1) and ok
	Save.stations["fishing"] = 1
	Bag.add("fish", 1, true)
	await t._wait(0.7)
	ok = t._expect("with the Fishing Spot the window shows a fish tile", _source("fish") != null) and ok
	await t._shot("cook_window_fishing")
	return ok


# ---------------------------------------------------------------- helpers
## Takes every food and potion out of the Bag (through Bag, which owns the counts).
func _empty_bag() -> void:
	for id in Bag.ids():
		var kind := Bag.kind_of(id)
		if (kind == "food" or kind == "potion") and Bag.count(id) > 0:
			Bag.take(id, Bag.count(id))


func _ids(entries: Array) -> Array:
	var out: Array = []
	for e: Variant in entries:
		out.append(String((e as Dictionary).get("id", "")))
	return out


## A wave "on" for the check, with nothing running it (as the old garden test did).
func _wave(on: bool) -> void:
	main.fight.set_physics_process(not on)
	main.fight.active = on
	main.fight.in_wave = on


## The open card's controls made from one of the drag kit's scripts, in tree order (shown ones only).
func _window_nodes(script: Script) -> Array:
	var out: Array = []
	var list = main.hud._card_list
	if main.hud._card == null or list == null or not is_instance_valid(list):
		return out
	for n: Node in (list as Node).find_children("*", "Control", true, false):
		if n.get_script() == script and not n.is_queued_for_deletion() and (n as Control).is_visible_in_tree():
			out.append(n)
	return out


## The pot's slots (the window's drop slots).
func _pot_slots() -> Array:
	return _window_nodes(DropSlotScript)


func _slot_at(i: int) -> Control:
	var slots := _pot_slots()
	return slots[i] as Control if i >= 0 and i < slots.size() else null


## The ingredient tile that drags `id` (payload {"kind": "food", "id": id}), or null.
func _source(id: String) -> Control:
	for n: Variant in _window_nodes(DragSourceScript):
		var p: Variant = n.get("payload")
		if p is Dictionary and String((p as Dictionary).get("kind", "")) == "food" and String((p as Dictionary).get("id", "")) == id:
			return n as Control
	return null


## A slot shows the ingredient: a picture under it is that ingredient's icon.
func _slot_shows(slot: Control, id: String) -> bool:
	if slot == null:
		return false
	var tex: Texture2D = main.hud.icon(id)
	for r: Node in slot.find_children("*", "TextureRect", true, false):
		if (r as TextureRect).texture == tex:
			return true
	return false


## A button of the open card by its label (its "label" meta or its text), or null.
func _button(text: String) -> Button:
	for b: Variant in main.hud.card_buttons():
		var btn := b as Button
		if btn == null or btn.disabled or btn.is_queued_for_deletion():
			continue
		if String(btn.get_meta("label", "")) == text or btn.text == text:
			return btn
	return null


## Presses a button of the window (as the old tests' _press does), then lets the window redraw.
func _press(text: String) -> bool:
	var b := _button(text)
	if b == null:
		t._log("no button " + text)
		return false
	b.pressed.emit()
	await t._wait(0.3)
	return true


## A real tap on an ingredient's tile (Q15: it fills the next empty slot), then the window's redraw.
func _tap_ingredient(id: String) -> bool:
	var src := _source(id)
	if src == null:
		t._log("no ingredient tile " + id)
		return false
	await t._tap_at(src.get_global_rect().get_center())
	await t._wait(0.4)
	return true


## The window needs no scrolling: the card's list is no taller than its scrolling body (card.gd _place_card caps the
## body at the room left on the screen).
func _fits() -> bool:
	var hud = main.hud
	if hud._card == null or hud._card_scroll == null or hud._card_list == null:
		return false
	return float(hud._card_list.get_combined_minimum_size().y) <= float(hud._card_scroll.custom_minimum_size.y) + 1.0


func _fit_info() -> Dictionary:
	var hud = main.hud
	if hud._card == null or hud._card_scroll == null or hud._card_list == null:
		return {"card": "closed"}
	return {"list_h": hud._card_list.get_combined_minimum_size().y, "body_h": hud._card_scroll.custom_minimum_size.y}


## A real finger drag from `from` to `to` (HUD pixels) over `secs` (autotest_layout.gd's _drag): touch is emulated as
## the mouse, so Godot's own drag-and-drop starts as on the phone.
func _drag(from: Vector2, to: Vector2, secs: float) -> void:
	var xf: Transform2D = get_viewport().get_final_transform()
	var d := InputEventScreenTouch.new()
	d.index = 0
	d.position = xf * from
	d.pressed = true
	Input.parse_input_event(d)
	var n := maxi(3, int(secs / 0.05))
	for k in n:
		await t._wait(secs / n)
		var m := InputEventScreenDrag.new()
		m.index = 0
		m.position = xf * from.lerp(to, float(k + 1) / n)
		m.relative = xf.basis_xform((to - from) / n)
		Input.parse_input_event(m)
	var u := InputEventScreenTouch.new()
	u.index = 0
	u.position = xf * to
	u.pressed = false
	Input.parse_input_event(u)
	await get_tree().process_frame
	await get_tree().process_frame
