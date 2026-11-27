extends Node
## Garden checks for autotest.gd (`-- --autotest --fresh --garden`; scripts/garden.gd and its window
## ui/windows/garden_window.gd, H3 26 Nov 2026). Each check logs "EXPECT PASS <what>" or "EXPECT FAIL <what>" through
## autotest.gd's _expect. The window is used only through its card, the drag kit (ui/kit/drag_source.gd, drop_slot.gd)
## and the window API (opened / closed through the card), so this file does not depend on how the window draws itself.
## A pretend clock (a method of this node: a lambda would copy its locals and not see the test move the clock) stands in
## for the real one: base + offset, with base a whole second just past the real now and the save's seen. At the end the
## garden, its jobs, the Bag, the leaves, the flags, the garden level and the Gloom meter are put back, and
## Timers.use_real_clock() brings back the real clock and seen, so no future seen stays in the test save.
## Checks:
##   (a) the rules without the window: 3 open plots at level 1, the seeds (every unlocked crop, content order), plant's
##       refusals, the job, a plot with an unknown crop shows empty and planting replaces it, a plot with no job is ripe
##   (b) the window: 6 squares in 2 rows that fit without scrolling, one seed per crop, a seed you cannot pay for does
##       not drag, the bottom row locked at level 1 ("Garden N"), the top row is plots 3 2 1 (index 2, 1, 0)
##   (c) a real drag (touch, emulated as the mouse) of a seed onto plot 2: it pays on the drop
##   (d) the clock: sprout, growing, ripe at grow_s; a real tap on the window's Water shortens by
##       min(left x (1 - 1/speed), water_s x (speed - 1)), then Water is off; a plot planted later is dry; a long job's
##       water runs out and the 2 s check makes the ring pulse
##   (e) a real tap on a ripe square picks it into the Bag; with the Bag full it says "Bag full" and stays ripe
##   (f) one Gloom bump per visit; a wave blank (the card is blank, nothing works) and the rebuild after it are not a new
##       visit; closing and opening the card is
##   (g) the ring pulses when a crop ripens while playing (only the timer_finished handler refreshed the stations), and
##       the toast is the garden's own "Ripe in the garden: ..." line
##   (h) grows while closed: save, move the clock, reload, and it is ripe
##   (i) the Upgrade row: level 2 opens 5 plots, and the bottom row is plots 6 5 4 (index 5, 4, 3)
## Screenshots: garden_window_empty, garden_window_planted, garden_window_ripe, garden_bed_ripe, garden_window_level2.

const DropSlot := preload("res://ui/kit/drop_slot.gd")
const DragSource := preload("res://ui/kit/drag_source.gd")

var t                     # autotest.gd (its helpers: _wait, _shot, _expect, _until, _veteran, _at_ring, _press)
var main

var _base := 0.0
var _offset := 0.0
var _told: Array = []
var _snap := {}


## The pretend clock (Timers.clock while this test runs).
func _clock() -> float:
	return _base + _offset


func _on_finished(id: String) -> void:
	_told.append(id)


func _x(what: String, ok: bool, extra := {}) -> bool:
	return t._expect(what, ok, extra)


func run() -> bool:
	main.player.invincible = true
	t._veteran(1)                                       # mission 1 won: the garden (level 1) and its pot
	Save.leaves = 1000
	await t._wait(0.5)
	_take_snapshot()
	var real := Time.get_unix_time_from_system()
	_base = ceilf(maxf(real, float(Save.timers.get("seen", 0.0)))) + 1.0
	_offset = 0.0
	Timers.clock = _clock
	Events.timer_finished.connect(_on_finished)
	_clear_garden()
	var ok := _check_rules()
	ok = await _check_window() and ok
	ok = await _check_real_drag() and ok
	ok = await _check_growth() and ok
	ok = await _check_water_runs_out() and ok
	ok = await _check_pick() and ok
	ok = await _check_visits() and ok
	ok = await _check_ring_pulse() and ok
	ok = await _check_closed() and ok
	ok = await _check_upgrade() and ok
	_restore()
	var now_real := Time.get_unix_time_from_system()
	ok = _x("at the end the real clock is back, seen is not in the future and no test crop job is left",
		float(Save.timers["seen"]) <= now_real + 0.001 and absf(Timers.now() - now_real) < 2.0
		and Timers.ids("crop").size() == (_snap["jobs"] as Dictionary).size(), {"seen": Save.timers["seen"], "real": now_real}) and ok
	return ok


# ---------------------------------------------------------------- (a) the rules
func _check_rules() -> bool:
	var g = main.garden
	var ok := _x("level 1: plots 1-3 are open and empty, 4-6 locked", g.plots() == 3
		and _stages() == ["empty", "empty", "empty", "locked", "locked", "locked"], {"stages": _stages()})
	var want: Array = []
	for e: Variant in Data.catalog("crops"):
		var rule: Variant = (e as Dictionary).get("unlock", {})
		if rule is Dictionary and Data.unlocked(rule) and not bool((e as Dictionary).get("hidden", false)):
			want.append(String((e as Dictionary)["id"]))
	var got: Array = []
	for e: Variant in g.seeds():
		got.append(String((e as Dictionary)["id"]))
	ok = _x("the seeds: every unlocked crop in the content order, the Emberpepper and Swiftroot too", got == want
		and got.has("emberpepper") and got.has("swiftroot"), {"seeds": got}) and ok
	ok = _x("a locked plot refuses a seed", g.plant("sunberry", 3) == "Locked plot" and g.plant("sunberry", 6) == "Locked plot"
		and g.plant("sunberry", -1) == "Locked plot") and ok
	ok = _x("an unknown seed is refused", g.plant("no_such_crop", 0) == "Unknown seed" and g.stage(0) == "empty") and ok
	Save.leaves = 0
	var r: String = g.plant("sunberry", 0)
	ok = _x("no leaves: \"Not enough leaves\", nothing planted or paid", r == "Not enough leaves" and g.stage(0) == "empty"
		and not Timers.has("crop:0") and Save.leaves == 0, {"reason": r}) and ok
	Save.leaves = 1000
	var grow := _grow_s("sunberry")
	r = g.plant("sunberry", 0)
	ok = _x("plant pays the seed and starts the job crop:0 (grow_s long, data crop)", r == "" and Save.leaves == 1000 - _price("sunberry")
		and String(Save.garden[0].get("crop", "")) == "sunberry" and Timers.has("crop:0") and _near(Timers.left("crop:0"), grow)
		and String(Timers.job_data("crop:0").get("crop", "")) == "sunberry", {"reason": r, "leaves": Save.leaves, "left": Timers.left("crop:0")}) and ok
	ok = _x("a planted plot refuses another seed", g.plant("fernmint", 0) == "Plot in use") and ok
	ok = _x("a growing plot cannot be picked", g.pick(0) == "Not ripe" and g.stage(0) == "sprout") and ok
	ok = _x("a new plot is dry: Water is offered and the ring wants to pulse", not g.is_wet(0) and g.can_water() and g.wants_pulse()) and ok
	Save.garden[2] = {"crop": "old_crop_from_a_save", "grow": 3}
	ok = _x("a plot with an unknown crop id shows as empty", g.stage(2) == "empty" and g.crop_of(2).is_empty()) and ok
	r = g.plant("fernmint", 2)
	ok = _x("planting there replaces it", r == "" and Save.garden[2] == {"crop": "fernmint"}, {"plot": Save.garden[2]}) and ok
	Timers.remove("crop:2")
	ok = _x("a planted plot with no job counts as ripe (nothing is lost)", g.stage(2) == "ripe" and g.is_ripe(2)) and ok
	_clear_garden()
	return ok


# ---------------------------------------------------------------- (b) the window
func _check_window() -> bool:
	var g = main.garden
	var ring = main.stations.rings["garden"]
	await t._at_ring(ring)                              # a real tap on the garden's marker
	await t._wait(0.6)
	var ok := _x("the garden's card shows its window (a new visit)", main.hud.card_ring() == ring
		and main.hud._card_window == main.hud.garden_window and main.hud._card_window_open == main.hud.garden_window,
		{"title": main.hud.card_title()})
	await t._shot("garden_window_empty")
	var slots := _rows(_nodes(DropSlot))
	var srcs := _seed_sources()
	ok = _x("6 plot squares in 2 rows of 3", slots.size() == 6 and _two_rows(slots), {"slots": slots.size()}) and ok
	ok = _x("one seed to drag per seed", srcs.size() == g.seeds().size(), {"sources": srcs.size(), "seeds": g.seeds().size()}) and ok
	var body: Rect2 = (main.hud._card_scroll as Control).get_global_rect().grow(1.0)
	var inside := true
	for c: Variant in slots + srcs:
		inside = inside and body.encloses((c as Control).get_global_rect())
	ok = _x("the plots and the seeds fit in the card without scrolling", inside and int(main.hud._card_scroll.scroll_vertical) == 0,
		{"body": str(body)}) and ok
	# a seed you cannot pay for does not drag
	var prices: Array = []
	for e: Variant in g.seeds():
		prices.append(_price(String((e as Dictionary)["id"])))
	prices.sort()
	Save.leaves = int(prices[floori(prices.size() * 0.5)])
	await t._wait(0.7)                                  # the window checks the prices on its tick
	var right := true
	var yes := 0
	var no := 0
	for s: Variant in _seed_sources():
		var id := String((s.payload as Dictionary).get("id", ""))
		var can := Data.can_afford(Data.crop(id).get("price", {}))
		right = right and bool(s.can_drag) == can
		yes += 1 if can else 0
		no += 0 if can else 1
	ok = _x("a seed the cat cannot pay for does not drag; the others do", right and yes > 0 and no > 0,
		{"leaves": Save.leaves, "can": yes, "cannot": no}) and ok
	Save.leaves = 1000
	await t._wait(0.7)
	slots = _rows(_nodes(DropSlot))
	if slots.size() != 6:
		return _x("the window has its 6 plot squares for the order checks", false, {"slots": slots.size()})
	var locked_ok := true
	var texts: Array = []
	for k in range(3, 6):
		locked_ok = locked_ok and not slots[k]._can_drop_data(Vector2.ZERO, _seed("sunberry"))
		var txt := _text_in(slots[k])
		texts.append(txt)
		locked_ok = locked_ok and txt.contains("Garden")
	ok = _x("level 1: the bottom row is locked and each square says \"Garden N\"", locked_ok, {"texts": texts}) and ok
	ok = _x("an empty open plot takes a seed, not food", slots[0]._can_drop_data(Vector2.ZERO, _seed("sunberry"))
		and not slots[0]._can_drop_data(Vector2.ZERO, {"kind": "food", "id": "berries"})) and ok
	var got: Array = []
	for k in 3:                                         # the same frame: the squares stay valid while the window redraws
		got.append(_drop_on(slots[k], "sunberry"))
	ok = _x("the top row is plots 3 2 1 (index 2, 1, 0), as the bed shows them", got == [2, 1, 0], {"got": got}) and ok
	_clear_garden()
	return ok


# ---------------------------------------------------------------- (c) a real drag
func _check_real_drag() -> bool:
	_clear_garden()
	Save.leaves = 1000
	await t._wait(0.7)                                  # the window draws the plots empty again on its tick
	var slots := _rows(_nodes(DropSlot))
	var src = _source("sunberry")
	if slots.size() != 6 or src == null:
		return _x("a real drag needs the plot squares and the Sunberry seed", false, {"slots": slots.size(), "seed": src != null})
	var l0 := Save.leaves
	var res: Dictionary = await _drag((src as Control).get_global_rect().get_center(), (slots[1] as Control).get_global_rect().get_center(), 0.4)
	await t._wait(0.2)
	var ok := _x("a real drag started (a finger, emulated as the mouse, inside the card)", bool(res["dragging"]), res)
	ok = _x("nothing is paid while the seed is dragged", int(res["leaves"]) == l0, res) and ok
	ok = _x("a real drag of the Sunberry seed onto plot 2 plants it and pays on the drop",
		String(Save.garden[1].get("crop", "")) == "sunberry" and Timers.has("crop:1") and Save.leaves == l0 - _price("sunberry"),
		{"garden": Save.garden, "leaves": Save.leaves}) and ok
	ok = _x("the plots beside it stay empty", main.garden.stage(0) == "empty" and main.garden.stage(2) == "empty") and ok
	await t._wait(0.7)
	await t._shot("garden_window_planted")
	return ok


# ---------------------------------------------------------------- (d) the clock and Water
func _check_growth() -> bool:
	var g = main.garden
	_clear_garden()
	Save.leaves = 1000
	var grow := _grow_s("sunberry")
	g.plant("sunberry", 1)
	_offset += grow * 0.25
	var ok := _x("a quarter of the way: a sprout with 3/4 of its time left", g.stage(1) == "sprout" and _near(g.left_s(1), grow * 0.75),
		{"stage": g.stage(1), "left": g.left_s(1)})
	_offset += grow * 0.35
	ok = _x("past half: growing", g.stage(1) == "growing" and _near(g.left_s(1), grow * 0.4), {"stage": g.stage(1), "left": g.left_s(1)}) and ok
	ok = _x("dry: Water is offered", not g.is_wet(1) and g.can_water()) and ok
	var speed := float(Data.b["garden"]["water_speed"])
	var ws := Data.pick("garden", "water_s_by_level", Data.garden_level())
	var left0: float = g.left_s(1)
	var saved := minf(left0 * (1.0 - 1.0 / speed), ws * (speed - 1.0))
	var now0 := Timers.now()
	await t._wait(0.7)                                  # the open window draws Water enabled on its tick (the clock holds still)
	var wb := _water_button()
	var has_wb := wb != null                            # noted before the tap: the tap's redraw frees the button
	if has_wb:
		await t._tap_at(wb.get_global_rect().get_center())  # a real tap on the window's Water button, as a player waters
	await t._wait(0.3)
	ok = _x("a real tap on the window's Water shortens the time left by min(left x (1 - 1/speed), water_s x (speed - 1))", has_wb
		and _near(g.left_s(1), left0 - saved), {"button": has_wb, "left": g.left_s(1), "want": left0 - saved, "speed": speed, "water_s": ws}) and ok
	ok = _x("a watered plot is wet until wet_until, and there is nothing more to water", g.is_wet(1) and not g.can_water()
		and _near(float(Timers.job_data("crop:1").get("wet_until", 0.0)), now0 + saved / (speed - 1.0))) and ok
	await t._wait(0.7)
	ok = _x("then the window's Water button is off", _water_button() == null and _water_button(true) != null) and ok
	ok = _x("a second Water waters nothing", g.water() == 0 and _near(g.left_s(1), left0 - saved)) and ok
	g.plant("sunberry", 0)
	var t0 := Timers.now()
	ok = _x("a plot planted later is dry", not g.is_wet(0) and g.can_water()) and ok
	_offset = t0 - _base + grow - 1.0
	ok = _x("a second before grow_s it is not ripe", g.stage(0) != "ripe" and _near(g.left_s(0), 1.0), {"left": g.left_s(0)}) and ok
	_offset += 1.0
	ok = _x("the clock ripens it at grow_s", g.stage(0) == "ripe" and g.is_ripe(0) and is_zero_approx(g.left_s(0)) and not g.is_wet(0)) and ok
	ok = _x("the watered plot ripened sooner", g.stage(1) == "ripe") and ok
	ok = _x("ripe plots are not watered", not g.can_water() and g.water() == 0) and ok
	return ok


## A job longer than water_s x speed: watering saves only water_s x (speed - 1), the soil dries before it is ripe, and
## then the 2 s check refreshes the ring (it pulses: a dry growing plot).
func _check_water_runs_out() -> bool:
	var g = main.garden
	var ring = main.stations.rings["garden"]
	_clear_garden()
	Save.leaves = 0                                     # no seed to pay for: only the dry plot can make the ring pulse
	var speed := float(Data.b["garden"]["water_speed"])
	var ws := Data.pick("garden", "water_s_by_level", Data.garden_level())
	var long := ws * speed + 120.0
	Save.garden[2] = {"crop": "sunberry"}
	Timers.start("crop:2", long, {"crop": "sunberry"})
	var n: int = g.water()
	var ok := _x("a long job: watering saves at most water_s x (speed - 1)", n == 1 and _near(g.left_s(2), long - ws * (speed - 1.0))
		and g.is_wet(2), {"left": g.left_s(2), "want": long - ws * (speed - 1.0)})
	main.stations.refresh()
	ok = _x("watered, nothing ripe, no seed to pay for: the ring is still", bool(ring.visible) and not bool(ring.pulse) and not g.wants_pulse()) and ok
	_offset += ws - 1.0                                 # wet_until = now + saved / (speed - 1) = now + water_s
	ok = _x("still wet a second before its water runs out", g.is_wet(2)) and ok
	_offset += 2.0
	ok = _x("then it is dry and can be watered again", not g.is_wet(2) and g.can_water() and g.wants_pulse() and g.stage(2) != "ripe") and ok
	var pulsed: bool = await t._until(func() -> bool: return bool(ring.pulse), 3.0)
	ok = _x("the 2 s check refreshes the ring when the water runs out (it pulses)", pulsed) and ok
	_clear_garden()
	Save.leaves = 1000
	return ok


# ---------------------------------------------------------------- (e) pick
func _check_pick() -> bool:
	var g = main.garden
	_clear_garden()
	Save.leaves = 1000
	g.plant("sunberry", 0)
	g.plant("fernmint", 1)
	_offset += maxf(_grow_s("sunberry"), _grow_s("fernmint")) + 1.0
	var ok := _x("both are ripe", g.stage(0) == "ripe" and g.stage(1) == "ripe", {"stages": _stages()})
	await t._wait(0.7)                                  # the open window draws them ripe on its tick
	await t._shot("garden_window_ripe")
	main.hud.hide_card()
	main.closeup_at = main.stations.nodes.get("garden")
	main.closeup = Vector3(0.0, 4.6, 4.2)               # from the south, as the game's camera looks (plot 3 2 1 at the back)
	main.player.visible = false                         # the cat stands at the ring, in front of the bed: out of the picture
	await t._wait(0.4)
	await t._shot("garden_bed_ripe")
	main.player.visible = true
	main.closeup = Vector3.ZERO
	main.closeup_at = null
	main.hud.show_card(main.stations.rings["garden"])  # the card again: a player picks with a tap on the ripe square
	await t._wait(0.6)
	var bag0: Dictionary = Save.bag.duplicate(true)
	Save.bag.clear()
	Bag.add("fish", Bag.stack_size("fish") * Bag.slots(), true)   # every slot holds a full stack of fish
	Events.bag_changed.emit()
	main.hud._toast.text = ""
	var sq := _plot_slot(0)
	var has_sq := sq != null                            # noted before each tap: a redraw inside the tap frees the square
	if has_sq:
		await t._tap_at(sq.get_global_rect().get_center())
	await t._wait(0.2)
	var toast := String(main.hud._toast.text)
	ok = _x("a real tap on a ripe plot with the Bag full: \"Bag full\", and the plot stays ripe", has_sq and toast == "Bag full"
		and g.is_ripe(0) and String(Save.garden[0].get("crop", "")) == "sunberry" and Timers.has("crop:0"),
		{"square": has_sq, "toast": toast, "free": Bag.free_slots()}) and ok
	Save.bag = bag0
	Events.bag_changed.emit()
	main.hud._toast.text = ""
	await t._wait(0.7)
	var c := Data.crop("sunberry")
	var gives := String(c["gives"])
	var n := int(c["yield"]) + int(Data.pick("garden", "extra_by_level", Data.garden_level()))
	var b0 := Bag.count(gives)
	sq = _plot_slot(0)                                  # fetched again: the window may have redrawn
	has_sq = sq != null
	if has_sq:
		await t._tap_at(sq.get_global_rect().get_center())  # the square is freed by the redraw inside its own tap
	await t._wait(0.3)
	ok = _x("a real tap on the ripe plot picks it: the harvest goes in the Bag and the plot is empty", has_sq
		and Bag.count(gives) == b0 + n and g.stage(0) == "empty" and not Timers.has("crop:0") and String(Save.garden[0].get("crop", "x")) == "",
		{"square": has_sq, "had": b0, "has": Bag.count(gives), "stage": g.stage(0), "toast": main.hud._toast.text}) and ok
	ok = _x("picking one plot leaves the others ripe", g.stage(1) == "ripe") and ok
	await t._wait(0.7)
	ok = _x("the window draws the picked plot empty again (\"Drop a seed\")", _text_in(_plot_slot(0)).contains("Drop a seed"),
		{"text": _text_in(_plot_slot(0))}) and ok
	ok = _x("an empty plot cannot be picked", g.pick(0) == "Not ripe") and ok
	_clear_garden()
	return ok


# ---------------------------------------------------------------- (f) the Gloom bump, once per visit
func _check_visits() -> bool:
	var g = main.garden
	var rd = main.raids
	var r: Dictionary = Save.raids
	var was_open: bool = rd.open
	var was_manual: bool = rd.manual
	var m_was := float(r["meter"])
	var p_was := bool(r["pending"])
	rd.manual = true                                    # main's frames do not fill the meter; only add_gloom moves it
	rd.open = true
	r["pending"] = false
	r["meter"] = 0.0
	var bump := float(Data.gr()["meter"]["actions"]["harvest"])
	var grow := _grow_s("sunberry")
	var ring = main.stations.rings["garden"]
	_clear_garden()
	Save.leaves = 1000
	for i in 3:
		g.plant("sunberry", i)
	_offset += grow + 1.0
	main.hud.hide_card()
	await get_tree().process_frame
	main.hud.show_card(ring)
	await t._wait(0.3)
	var m0 := float(r["meter"])
	var res: String = g.pick(0)
	var ok := _x("a visit's first pick adds the harvest's Gloom", res == "" and _near(float(r["meter"]), m0 + bump),
		{"reason": res, "meter": r["meter"], "bump": bump})
	var m1 := float(r["meter"])
	ok = _x("a second pick in the same visit adds none", g.pick(1) == "" and _near(float(r["meter"]), m1), {"meter": r["meter"]}) and ok
	# a wave blanks the card; the rebuild after it is the same visit
	main.fight.set_physics_process(false)               # a wave "on" for the check, with nothing running it
	main.fight.active = true
	main.fight.in_wave = true
	main.hud.refresh_card()
	await get_tree().process_frame
	await get_tree().process_frame
	ok = _x("the card is blank in a wave: no buttons, no plots", main.hud.card_open() and main.hud.card_buttons().size() == 0
		and _nodes(DropSlot).is_empty(), {"buttons": main.hud.card_buttons().size()}) and ok
	var l1 := Save.leaves
	ok = _x("in a wave nothing works: plant, water and pick refuse", g.plant("sunberry", 0) == "A wave is on" and g.water() == 0
		and g.pick(2) == "A wave is on" and g.is_ripe(2) and g.stage(0) == "empty" and Save.leaves == l1) and ok
	main.fight.active = false
	main.fight.in_wave = false
	main.fight.set_physics_process(true)
	main.hud.refresh_card()
	await t._wait(0.3)
	ok = _x("after the wave the window is back in the same visit", _nodes(DropSlot).size() == 6
		and main.hud._card_window_open == main.hud.garden_window) and ok
	ok = _x("a pick after a wave blank and its rebuild adds no Gloom (not a new visit)", g.pick(2) == "" and _near(float(r["meter"]), m1),
		{"meter": r["meter"]}) and ok
	main.hud.hide_card()
	await get_tree().process_frame
	g.plant("sunberry", 0)
	_offset += grow + 1.0
	main.hud.show_card(ring)
	await t._wait(0.3)
	ok = _x("closing and opening the card is a new visit: its first pick adds Gloom again", g.pick(0) == ""
		and _near(float(r["meter"]), m1 + bump), {"meter": r["meter"]}) and ok
	r["meter"] = m_was
	r["pending"] = p_was
	rd.open = was_open
	rd.manual = was_manual
	main.hud.hide_card()
	_clear_garden()
	return ok


# ---------------------------------------------------------------- (g) the ring when a crop ripens while playing
func _check_ring_pulse() -> bool:
	var g = main.garden
	var ring = main.stations.rings["garden"]
	_clear_garden()
	Save.leaves = 1000
	g.plant("sunberry", 0)
	g.water()                                           # wet until it is ripe: the plot alone does not pulse
	Save.leaves = 0                                     # and no seed to pay for
	main.stations.refresh()
	var ok := _x("before: watered and growing, no seed to pay for: the ring is still", bool(ring.visible) and not bool(ring.pulse)
		and not g.wants_pulse(), {"wet": g.is_wet(0), "stage": g.stage(0)})
	var look: Timer = g.get_node("LookCheck")
	look.paused = true                                  # only the timer_finished handler may refresh the stations now
	_told.clear()
	_offset += g.left_s(0) + 1.0
	Timers.check()
	await get_tree().process_frame
	await get_tree().process_frame
	ok = _x("the crop ripened while playing: timer_finished(crop:0) was sent", _told.has("crop:0"), {"told": _told}) and ok
	ok = _x("the ring pulses after the timer_finished handler (nothing else refreshed the stations)", bool(ring.pulse) and g.is_ripe(0)) and ok
	var ripe_toast := "Ripe in the garden: %s" % String(Data.crop("sunberry")["name"])
	ok = _x("a crop alone keeps its own toast", String(main.hud._toast.text) == ripe_toast,
		{"toast": main.hud._toast.text, "want": ripe_toast}) and ok
	look.paused = false
	Save.leaves = 1000
	_clear_garden()
	return ok


# ---------------------------------------------------------------- (h) grows while closed
func _check_closed() -> bool:
	var g = main.garden
	_clear_garden()
	Save.leaves = 1000
	g.plant("sunberry", 0)
	var ok := _x("planted and growing when the game closes", g.stage(0) == "sprout")
	Save.save_game()
	_offset += _grow_s("sunberry") + 5.0                # the game was "closed" past the crop's time
	Save.load_game()
	await get_tree().process_frame
	ok = _x("grows while closed: after a reload with the clock moved on, it is ripe", g.stage(0) == "ripe"
		and String(Save.garden[0].get("crop", "")) == "sunberry" and Timers.has("crop:0"), {"garden": Save.garden}) and ok
	_clear_garden()
	return ok


# ---------------------------------------------------------------- (i) the Upgrade row: 5 plots, the bottom row
func _check_upgrade() -> bool:
	var g = main.garden
	var ring = main.stations.rings["garden"]
	Save.camp_level = maxi(Save.camp_level, 2)
	main.on_camp_grown()
	Save.leaves = 5000
	_clear_garden()
	main.hud.hide_card()
	await get_tree().process_frame
	main.hud.show_card(ring)
	await t._wait(0.6)
	var up: bool = t._press("Upgrade")
	await t._wait(0.8)
	var ok := _x("the Upgrade row is there, and garden level 2 opens 5 plots", up and int(Save.stations["garden"]) == 2 and g.plots() == 5
		and _stages() == ["empty", "empty", "empty", "empty", "empty", "locked"], {"pressed": up, "stages": _stages()})
	var slots := _rows(_nodes(DropSlot))
	if slots.size() == 6:
		var first: int = _drop_on(slots[3], "sunberry") if slots[3]._can_drop_data(Vector2.ZERO, _seed("sunberry")) else -1
		var bottom: Array = [first, _drop_on(slots[4], "sunberry"), _drop_on(slots[5], "sunberry")]
		ok = _x("the bottom row is plots 6 5 4 (index 5 still locked at level 2, then 4 and 3)", bottom == [-1, 4, 3], {"got": bottom}) and ok
	else:
		ok = _x("the window has its 6 plot squares at level 2", false, {"slots": slots.size()}) and ok
	await t._wait(0.7)
	await t._shot("garden_window_level2")
	main.hud.hide_card()
	_clear_garden()
	return ok


# ---------------------------------------------------------------- helpers
func _take_snapshot() -> void:
	var jobs := {}
	for id: String in Timers.ids("crop"):
		jobs[id] = (Save.timers["jobs"][id] as Dictionary).duplicate(true)
	_snap = {"garden": Save.garden.duplicate(true), "jobs": jobs, "bag": Save.bag.duplicate(true), "leaves": Save.leaves,
		"flags": Save.flags.duplicate(true), "garden_level": int(Save.stations.get("garden", 0)), "camp_level": Save.camp_level}


func _restore() -> void:
	main.hud.hide_card()
	main.fight.active = false
	main.fight.in_wave = false
	for id: String in Timers.ids("crop"):
		Timers.remove(id)
	var jobs: Dictionary = Save.timers["jobs"]
	for id: Variant in _snap["jobs"]:
		jobs[id] = (_snap["jobs"][id] as Dictionary).duplicate(true)
	Save.garden = (_snap["garden"] as Array).duplicate(true)
	Save.bag = (_snap["bag"] as Dictionary).duplicate(true)
	Save.leaves = int(_snap["leaves"])
	Save.flags = (_snap["flags"] as Dictionary).duplicate(true)
	Save.stations["garden"] = int(_snap["garden_level"])
	Save.camp_level = int(_snap["camp_level"])
	Events.timer_finished.disconnect(_on_finished)
	Timers.use_real_clock()
	Events.bag_changed.emit()
	main.garden.refresh_look()
	main.stations.refresh()
	Save.save_game(true)


func _clear_garden() -> void:
	for i in Save.garden.size():
		Timers.remove("crop:%d" % i)
		Save.garden[i] = {"crop": ""}
	main.garden.refresh_look()


func _stages() -> Array:
	var out: Array = []
	for i in 6:
		out.append(main.garden.stage(i))
	return out


func _grow_s(id: String) -> float:
	return float(Data.crop(id).get("grow_s", 0.0))


func _price(id: String) -> int:
	var p: Variant = Data.crop(id).get("price", {})
	return int((p as Dictionary).get("leaves", 0)) if p is Dictionary else 0


func _seed(id: String) -> Dictionary:
	return {"kind": "seed", "id": id}


## Two times or lengths in seconds are the same (to 0.01 s).
static func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.01


## The open card's controls made by one of the drag kit's scripts (shown, not being freed), in tree order.
func _nodes(script: Script) -> Array:
	var out: Array = []
	var card: Control = main.hud._card
	if card == null:
		return out
	for n: Node in card.find_children("*", "Control", true, false):
		if n.get_script() == script and not n.is_queued_for_deletion() and (n as Control).is_visible_in_tree():
			out.append(n)
	return out


func _seed_sources() -> Array:
	var out: Array = []
	for s: Variant in _nodes(DragSource):
		if String((s.payload as Dictionary).get("kind", "")) == "seed":
			out.append(s)
	return out


func _source(id: String) -> Variant:
	for s: Variant in _seed_sources():
		if String((s.payload as Dictionary).get("id", "")) == id:
			return s
	return null


## Sorted as the screen shows them: by row (top first), then left to right.
func _rows(list: Array) -> Array:
	var s := list.duplicate()
	s.sort_custom(func(a: Variant, b: Variant) -> bool:
		var pa: Vector2 = (a as Control).get_global_rect().get_center()
		var pb: Vector2 = (b as Control).get_global_rect().get_center()
		if absf(pa.y - pb.y) > 8.0:
			return pa.y < pb.y
		return pa.x < pb.x)
	return s


func _two_rows(s: Array) -> bool:
	if s.size() != 6:
		return false
	var y := func(k: int) -> float: return (s[k] as Control).get_global_rect().get_center().y
	return absf(y.call(1) - y.call(0)) < 8.0 and absf(y.call(2) - y.call(0)) < 8.0 and absf(y.call(4) - y.call(3)) < 8.0 \
		and absf(y.call(5) - y.call(3)) < 8.0 and y.call(3) > y.call(0) + 8.0


## The square of plot i in the open window (the top row shows plots 3 2 1, the bottom 6 5 4), or null.
func _plot_slot(i: int) -> Control:
	var slots := _rows(_nodes(DropSlot))
	if slots.size() != 6 or i < 0 or i > 5:
		return null
	return slots[2 - i if i < 3 else 8 - i] as Control


## The open window's Water button (an enabled one; or, with off, a disabled one), or null.
func _water_button(off := false) -> Button:
	for b: Variant in main.hud.card_buttons():
		var btn := b as Button
		if btn != null and not btn.is_queued_for_deletion() and btn.is_visible_in_tree() and String(btn.get_meta("label", "")) == "Water" \
				and btn.disabled == off:
			return btn
	return null


func _text_in(n: Node) -> String:
	if n == null:
		return ""
	var bits := PackedStringArray()
	for l: Node in n.find_children("*", "Label", true, false):
		bits.append((l as Label).text)
	return " ".join(bits)


## Drops a seed on a plot square (its drop_slot) the way Godot does at the end of a drag; returns the plot index that
## got the crop, or -1.
func _drop_on(slot, id: String) -> int:
	var before: Array = []
	for i in Save.garden.size():
		before.append(String(Save.garden[i].get("crop", "")))
	slot._drop_data(Vector2.ZERO, _seed(id))
	for i in Save.garden.size():
		if before[i] != id and String(Save.garden[i].get("crop", "")) == id:
			return i
	return -1


## A real finger drag from `from` to `to` (HUD pixels) through Input, as on the phone (copied from autotest_layout.gd
## _drag). Returns what was true just before the finger lifted: {"dragging": a GUI drag is on, "leaves": Save.leaves}.
func _drag(from: Vector2, to: Vector2, secs: float) -> Dictionary:
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
	await get_tree().process_frame
	var out := {"dragging": get_viewport().gui_is_dragging(), "leaves": Save.leaves}
	var u := InputEventScreenTouch.new()
	u.index = 0
	u.position = xf * to
	u.pressed = false
	Input.parse_input_event(u)
	await get_tree().process_frame
	await get_tree().process_frame
	return out
