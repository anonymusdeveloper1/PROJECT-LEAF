extends Node
## Phase G2: the camp (`-- --autotest --fresh --campg`), run from autotest.gd. Each check logs "EXPECT PASS <what>" or
## "EXPECT FAIL <what>" through autotest.gd's _expect. Light on purpose: the numbers come from balance.json, no fight is
## played (the Well's mending is stepped by hand, with a breather or a wave faked for those few lines only).
##   (a) the Hearthtree's window (H4): its title is the Hearthtree (no "Shop"), the Hearthtree tab holds the goals and the
##       Settings section, the Cat tab holds Health as a list row, and the pinned footer holds "Level 1 of N" and Upgrade,
##       which asks in the confirm window (there is no Grow tile any more)
##   (b) at Hearthtree 1 the Market and the Mushroom Cottage are locked in the build menu; at 2 they are open; a goal for
##       one not built has the station "build" and its Show opens the build menu at it; building the Market brings
##       Thistle, who can be ridden
##   (c) the Market: buying timber and a food item changes the right stocks; (H1) after the missions Bramble buys amber
##       for leaves and a Gloom shard, and sells none
##   (d) the Well opens at Hearthtree 3, has no rows and an Upgrade footer, and mends standing structures to full at both
##       rates
##   (e) the Training Target and Bow Shop windows are made of list rows, each with its Upgrade in the footer (H4)
##   (f) an old save with the stall and cottage (gifts of missions 2 and 3) keeps them, with Thistle and Sprig
##   (g) (21 Nov 2026) a ruined Hearthtree during the missions costs the after-the-missions price (gloom_raids.repair
##       ruin_share, ruin_min, ruin_cap: at most 900 leaves and 30 timber); another building keeps raid.repair_share

var t                     # autotest.gd (its helpers: _wait, _shot, _expect, _until, _at_ring, _press, _log)
var main


func run() -> bool:
	main.player.invincible = true
	_start_fresh()
	await t._wait(0.3)
	await _hearthtree_card()
	await _unlocks()
	_market()
	_well()
	await _tiles()
	_old_save()
	_home_repair()
	main.hud.hide_card()
	return true


func _x(what: String, ok: bool, extra := {}) -> bool:
	return t._expect(what, ok, extra)


func _st():
	return main.stations


## A camp with mission 1 won and nothing built or bought.
func _start_fresh() -> void:
	Save.missions_done = [String(Data.mission(0)["id"])]
	Save.mission_run = {}
	Save.camp_level = 1
	for k in Save.stations:
		Save.stations[k] = 0
	for k in Save.stats:
		Save.stats[k] = 0
	Save.bows = {"twig": 1}
	Save.bow = "twig"
	Save.ruined = []
	Save.wear = {}
	Save.fire_ruined = false
	Save.leaves = 0
	Save.timber = 0
	for k in ["shop_open", "shop_target", "shop_bench", "home", "first_stage_done"]:
		Save.set_flag(k)
	_st().refresh()


func _kind(r: Dictionary) -> String:
	return String(r.get("kind", ""))


func _items(rows: Array) -> Array:
	return rows.filter(func(r): return _kind(r) == "item")


func _lists(rows: Array) -> Array:
	return rows.filter(func(r): return _kind(r) == "list")


## The list row (a window's {"kind": "list"} row) with this title, {} when there is none.
func _row_named(rows: Array, title: String) -> Dictionary:
	for r in rows:
		if _kind(r) == "list" and String(r.get("title", "")) == title:
			return r
	return {}


## The build menu's entry for building `id` ({} when it is not in the menu: built, or not shown yet).
func _entry(id: String) -> Dictionary:
	for e in (main.hud.windows["build"].entries() as Array):
		if String(e["id"]) == id:
			return e
	return {}


## The label of a spec's footer's first button ("" when it has none).
func _foot_label(spec: Dictionary) -> String:
	var bs: Array = (spec.get("footer", {}) as Dictionary).get("buttons", [])
	return "" if bs.is_empty() else String((bs[0] as Dictionary).get("label", ""))


## Every word on a card's rows (titles, lines, notes, buttons), for "is it there at all" checks.
func _words(rows: Array) -> String:
	var bits: Array = []
	for r in rows:
		for k in ["title", "text", "note", "label"]:
			bits.append(String(r.get(k, "")))
	return " | ".join(bits)


func _titles(rows: Array) -> Array:
	return rows.map(func(r): return "%s:%s" % [_kind(r), String(r.get("title", r.get("text", "")))])


# ---------------------------------------------------------------- (a) the Hearthtree's window
func _hearthtree_card() -> void:
	var w = main.hud.windows["shop"]
	var spec: Dictionary = w.tab_spec("hearthtree")
	var rows: Array = spec["rows"]
	var ht := Data.camp_name(true)
	_x("camp_name: 'the Hearthtree' / 'The Hearthtree'", Data.camp_name() == String(Data.b.get("camp_name", "the Hearthtree"))
		and Data.camp_name(true).begins_with("The "), {"name": Data.camp_name(), "cap": Data.camp_name(true)})
	_x("the Hearthtree's window is called the Hearthtree", String(spec["title"]) == ht, {"title": spec["title"]})
	var goals: Array = Data.home_goals(2)
	var goal_rows: Array = rows.filter(func(r): return r.has("goal"))
	_x("its Hearthtree tab holds level 2's goals and the Settings section, and no tile (the buildings are in the build menu)",
		not goals.is_empty() and goal_rows.size() == goals.size() and rows.any(func(r): return _kind(r) == "section" and String(r.get("text", "")) == "Settings")
		and _items(rows).is_empty(), {"rows": _titles(rows)})
	_x("no 'Shop' (other than the Bow Shop) in the window, and no 'your home'", not _words(rows).replace("Bow Shop", "").contains("Shop") and not _words(rows).to_lower().contains("your home")
		and not String(spec["sub"]).to_lower().contains("home"), {"sub": spec["sub"]})
	# the Grow tile is gone: growing is the footer's Upgrade
	var want := "%s level 2" % ht.trim_prefix("The ")
	var foot: Dictionary = spec.get("footer", {})
	var n: int = Data.building_levels("home").size()
	var goals_left: String = String(Data.word("goals_met")) % [goals.filter(func(g): return bool(g["done"])).size(), goals.size()]
	_x("no Grow tile: the goals' last row is a goal, and no row is titled '%s'" % want, (w._grow_rows() as Array).size() == goals.size()
		and not (w._grow_rows() as Array).any(func(r): return String(r.get("title", "")) == want) and not rows.any(func(r): return String(r.get("title", "")) == want),
		{"rows": _titles(rows)})
	_x("the pinned footer: 'Level 1 of %d', Upgrade (off while the goals are open) and what is missing" % n,
		String(foot.get("text", "")) == String(Data.word("level_of")) % [1, n] and _foot_label(spec) == "Upgrade"
		and not bool((foot["buttons"][0] as Dictionary).get("enabled", true)) and String(foot.get("note", "")) == goals_left, {"footer": foot})
	var tabs: Array = spec.get("tabs", [])
	_x("two tabs (Hearthtree, Cat) once the cat's upgrades are sold; the footer is only on the Hearthtree tab",
		(w.tab_ids() as Array).slice(0, 2) == ["hearthtree", "cat"], {"tabs": w.tab_ids()})
	_x("the tab bar lists them, the Hearthtree tab selected, and the Cat tab has no footer", tabs.size() == (w.tab_ids() as Array).size()
		and bool((tabs[0] as Dictionary)["selected"]) and not (w.tab_spec("cat") as Dictionary).has("footer"), {"tabs": tabs.map(func(x): return x["id"])})
	var cat: Dictionary = _row_named(w.tab_spec("cat")["rows"], String(Data.stat_info("health")["name"]))
	_x("the cat's Health is a list row on the Cat tab, with a level badge and Buy", not cat.is_empty() and String(cat["id"]) == "health"
		and String(cat.get("badge", "")).begins_with("Level") and String(cat["label"]) == "Buy", {"row": cat})
	await t._at_ring(w.ring())
	await t._wait(0.5)
	_x("the window opens with the Hearthtree's name", main.hud.card_ring() == w.ring() and main.hud.card_title() == ht,
		{"title": main.hud.card_title()})
	var up: Button = main.hud.p_card.footer_button("Upgrade")
	_x("the pinned Upgrade is on screen under the rows and is off (the goals are not met)", up != null and up.disabled
		and not main.hud._card_scroll.is_ancestor_of(up))
	await t._shot("campg_hearthtree_card")
	# Upgrade asks first: the confirm lists what the level gives, and Confirm stays grey while the goals are open
	w.ask_upgrade()
	await t._wait(0.4)
	var ok_btn: Button = main.hud.p_card.footer_button("Confirm")
	var cancel: Button = main.hud.p_card.footer_button("Cancel")
	_x("Upgrade opens the confirm window (hud.confirm) with Confirm grey while the goals are open",
		main.hud.card_ring() == main.hud.confirm and ok_btn != null and ok_btn.disabled and cancel != null and Save.camp_level == 1,
		{"title": main.hud.card_title()})
	if cancel != null:
		cancel.pressed.emit()
	await t._wait(0.4)
	_x("Cancel comes back to the Hearthtree's window and nothing grew", main.hud.card_ring() == w.ring() and Save.camp_level == 1)
	main.hud.hide_card()
	await t._wait(0.2)


# ---------------------------------------------------------------- (b) the pet and the Market at Hearthtree 2
func _unlocks() -> void:
	var st = _st()
	var w = main.hud.windows["shop"]
	var market := String(Data.building("stall")["name"])
	var cottage := String(Data.building("cottage")["name"])
	Save.leaves = 99999
	Save.timber = 9999
	Save.camp_level = 1
	st.refresh()
	var m1: Dictionary = _entry("stall")
	var c1: Dictionary = _entry("cottage")
	var needs2: String = String(Data.word("needs_home")) % [Data.camp_name(), 2]
	_x("Hearthtree 1: the Market and the Cottage are not open (needs_home 2)", not Data.station_open("stall") and not Data.station_open("cottage")
		and Data.station_needs_home("stall") == 2 and Data.station_needs_home("cottage") == 2)
	_x("Hearthtree 1: neither is offered (the build menu shows both locked, with what they need and no way to build)",
		String(m1.get("state", "")) == "locked" and String(c1.get("state", "")) == "locked" and String(m1["needs"]).contains(needs2)
		and String(c1["needs"]).contains(needs2), {"market": m1.get("needs", ""), "cottage": c1.get("needs", "")})
	_x("Hearthtree 1: the Hearthtree's window sells no building (no tile for either)", not (w.tab_spec("hearthtree")["rows"] as Array).any(
		func(r): return String(r.get("title", "")) in [market, cottage]))
	st._build_station("stall")
	st._build_station("cottage")
	_x("Hearthtree 1: building them is refused", int(Save.stations["stall"]) == 0 and int(Save.stations["cottage"]) == 0 and Save.leaves == 99999)
	_x("no raid gives them any more", Data.gift_mission("stall") < 0 and Data.gift_mission("cottage") < 0)
	Save.camp_level = 2
	st.refresh()
	var m2: Dictionary = _entry("stall")
	var c2: Dictionary = _entry("cottage")
	_x("Hearthtree 2: the Market and the Cottage are open in the build menu, each with its price",
		String(m2.get("state", "")) == "open" and String(c2.get("state", "")) == "open" and String(m2["needs"]) == "" and String(c2["needs"]) == ""
		and not (m2["price"] as Dictionary).is_empty() and not (c2["price"] as Dictionary).is_empty(),
		{"market": m2, "cottage": c2})
	# a goal for one not built yet has the station "build" (the build menu is where it is bought now); its Show opens the menu there
	var g3: Array = Data.home_goals(3).filter(func(g): return String(g["type"]) == "station" and String(g["id"]) in ["stall", "cottage"])
	var goal_rows: Array = w._grow_rows()
	var to_menu := not g3.is_empty()
	for g in g3:
		var gr: Array = goal_rows.filter(func(r): return r.has("goal") and String(r["goal"].get("id", "")) == String(g["id"]) and String(r["goal"].get("type", "")) == "station")
		to_menu = to_menu and String(g["station"]) == "build" and st.goal_ring(String(g["station"])) == null and gr.size() == 1 \
			and String(gr[0]["label"]) == "Show" and bool(gr[0]["enabled"]) and w._goal_find(g) == String(Data.building(String(g["id"]))["name"]) \
			and not _entry(String(g["id"])).is_empty()
	_x("Hearthtree 3's goals for the Cottage and the Market have the station 'build' and a Show", to_menu,
		{"goals": g3.map(func(g): return "%s [%s]" % [g["progress"], g["station"]])})
	if not g3.is_empty():
		var gid := String(g3[0]["id"])
		var show: Array = goal_rows.filter(func(r): return r.has("goal") and String(r["goal"].get("id", "")) == gid and String(r["goal"].get("type", "")) == "station")
		if not show.is_empty():
			(show[0]["action"] as Callable).call()
		await t._wait(0.4)
		_x("Show opens the build menu at that building's detail", main.hud.card_ring() == main.hud.windows["build"] and main.hud.windows["build"]._detail == gid,
			{"card": main.hud.card_title(), "detail": main.hud.windows["build"]._detail})
		main.hud.hide_card()
		await t._wait(0.2)
	st._build_station("stall")
	await t._wait(0.3)
	_x("the Market is built and Thistle comes with it", int(Save.stations["stall"]) == 1 and Data.mount_level() == 1 and main.mount != null,
		{"stall": Save.stations["stall"], "mount": main.mount != null})
	var mw = main.hud.windows["stall"]
	var ride: Dictionary = mw.spec()["rows"].filter(func(r): return String(r.get("label", "")) == "Ride")[0] if main.mount != null else {}
	_x("the Market window has an enabled Ride row", bool(ride.get("enabled", false)), {"ride": ride.get("text", "")})
	main.set_riding(true, false)
	_x("Thistle can be ridden", main.player.riding)
	main.set_riding(false, false)
	st._build_station("cottage")
	await t._wait(0.3)
	_x("the Cottage is built and Sprig moves in", int(Save.stations["cottage"]) == 1 and main.pet != null)
	await t._at_ring(mw.ring())
	await t._wait(0.5)
	_x("the Market's card opens as 'Market'", main.hud.card_title() == market, {"title": main.hud.card_title()})
	await t._shot("campg_market_card")
	main.hud.hide_card()
	await t._wait(0.2)


# ---------------------------------------------------------------- (c) the Market: Bramble sells and buys
func _index_of(list_key: String, id: String) -> int:
	var list: Array = Data.b.get("market", {}).get(list_key, [])
	for i in list.size():
		if String(list[i]["id"]) == id:
			return i
	return -1


func _market() -> void:
	var st = _st()
	var mw = main.hud.windows["stall"]
	var tb: Dictionary = Data.b["trade"]["buy"]
	Save.leaves = 1000
	Save.timber = 0
	st._trade(true)
	_x("buying timber: +%d timber for %d leaves" % [int(tb["timber"]), int(tb["leaves"])],
		Save.timber == int(tb["timber"]) and Save.leaves == 1000 - int(tb["leaves"]), {"timber": Save.timber, "leaves": Save.leaves})
	var bi := _index_of("sells", "berries")
	var be: Dictionary = Data.b["market"]["sells"][bi] if bi >= 0 else {}
	if Bag.count("berries") > 0:                    # H3: food lives in the Bag
		Bag.take("berries", Bag.count("berries"))
	var l0 := Save.leaves
	st._market_buy(bi)
	_x("buying Sunberries: they go into the Bag, the leaves are paid", bi >= 0 and Bag.count("berries") == int(be.get("amount", 0))
		and Save.leaves == l0 - int(be.get("leaves", 0)), {"berries": Bag.count("berries"), "leaves": Save.leaves})
	# a full Bag: berries fill every stack and slot the rest of the Bag leaves free
	Bag.add("berries", Bag.room_for("berries"))
	var held := Bag.count("berries")
	var full: Dictionary = mw._market_sells().filter(func(r): return String(r.get("icon", "")) == "berries")[0]
	l0 = Save.leaves
	st._market_buy(bi)
	_x("a full Bag: the berries tile is off with Bag full and nothing is bought", Bag.room_for("berries") == 0 and not bool(full["enabled"])
		and String(full.get("text", "")).begins_with("Bag full") and Bag.count("berries") == held and Save.leaves == l0,
		{"tile": full.get("text", ""), "berries": Bag.count("berries"), "slots": Bag.used_slots()})
	if Bag.count("berries") > 2:
		Bag.take("berries", Bag.count("berries") - 2)   # back to a few, as before
	# H1: Bramble sells no amber; he buys it (after the missions) for leaves and a Gloom shard
	var shown_sells: bool = mw._market_sells().any(func(r): return String(r.get("icon", "")) == "amber")
	_x("H1: Bramble sells no amber, glowstone or heartwood", _index_of("sells", "amber") < 0 and _index_of("sells", "glowstone") < 0
		and _index_of("sells", "heartwood") < 0 and not shown_sells)
	_x("H1: he buys only amber of the materials", _index_of("buys", "glowstone") < 0 and _index_of("buys", "heartwood") < 0)
	var si := _index_of("buys", "amber")
	var se: Dictionary = Data.b["market"]["buys"][si] if si >= 0 else {}
	_x("H1: amber sells for 1,000 leaves and 1 shard each", si >= 0 and int(se.get("amount", 0)) == 1 and int(se.get("leaves", 0)) == 1000
		and int(se.get("shards", 0)) == 1, {"entry": se})
	Data.give("amber", 2)
	var a0 := int(Save.mats.get("amber", 0))
	l0 = Save.leaves
	var sh0 := Save.shards
	var buys_before: bool = mw._market_buys().any(func(r): return String(r.get("icon", "")) == "amber")
	st._market_sell(si)
	_x("before the raids are won: amber is not bought", not buys_before and int(Save.mats["amber"]) == a0 and Save.leaves == l0 and Save.shards == sh0)
	var keep: Array = Save.missions_done.duplicate()
	Save.missions_done = []
	for i in Data.mission_count():
		Save.missions_done.append(String(Data.mission(i)["id"]))
	var amber_note := "Bramble pays 1,000 leaves and 1 Gloom shard · you have %d" % a0
	var sell_tile: Array = mw._market_buys().filter(func(r): return String(r.get("icon", "")) == "amber")
	_x("after the raids: the amber tile says what Bramble pays", sell_tile.size() == 1 and String(sell_tile[0].get("text", "")) == amber_note
		and bool(sell_tile[0].get("enabled", false)), {"tiles": sell_tile})
	st._market_sell(si)
	_x("Bramble buys amber for leaves and a shard", int(Save.mats["amber"]) == a0 - int(se.get("amount", 0)) and Save.leaves == l0 + int(se.get("leaves", 0))
		and Save.shards == sh0 + int(se.get("shards", 0)), {"amber": Save.mats["amber"], "leaves": Save.leaves, "shards": Save.shards})
	Save.mats["amber"] = 0
	l0 = Save.leaves
	st._market_sell(si)
	_x("with no amber nothing is sold", int(Save.mats["amber"]) == 0 and Save.leaves == l0)
	var mspec: Dictionary = mw.spec()
	var heads: Array = (mspec["rows"] as Array).filter(func(r): return _kind(r) == "section").map(func(r): return String(r["text"]))
	_x("the Market's window: Bramble sells, Bramble buys and the Stable; its Upgrade is the pinned footer, not a section",
		heads.has("Bramble sells") and heads.has("Bramble buys") and heads.has("Stable") and not heads.has("Upgrade") and _foot_label(mspec) == "Upgrade",
		{"sections": heads, "footer": mspec.get("footer", {})})
	Save.missions_done = keep


# ---------------------------------------------------------------- (d) the Wishing Well mends by itself
func _well() -> void:
	var st = _st()
	var f = main.fight
	var home_before := Save.camp_level
	var missions_before: Array = Save.missions_done.duplicate()
	Save.camp_level = 2
	Save.missions_done.clear()
	for i in 4:
		Save.missions_done.append(String(Data.mission(i)["id"]))
	_x("four wins at Hearthtree 2 leave the Well locked", not Data.station_open("well"))
	Save.camp_level = 3
	Save.missions_done = missions_before
	_x("Hearthtree 3 opens the Well before four wins", Data.progress() < 4 and Data.station_open("well"))
	Save.camp_level = home_before
	Save.stations["well"] = 1
	Save.leaves = 0
	Save.wear["well"] = float(Data.gr()["repair"]["wear_step"])
	st.refresh()
	var ww = main.hud.windows["well"]
	var card: Dictionary = ww.spec()
	var wr: Array = card["rows"]
	_x("an existing Well below its build gate still works", st.shown("well") and st.well_level() == 1)
	_x("the Well has no rows even when worn: its Upgrade is the pinned footer (the first button)", wr.is_empty() and _foot_label(card) == "Upgrade"
		and String((card["footer"] as Dictionary).get("text", "")) == String(Data.word("level_of")) % [1, Data.building_levels("well").size()], {"rows": _words(wr), "footer": card.get("footer", {})})
	Save.wear.erase("well")
	_x("the Well's marker shows no '!' for wishing (no leaves: its footer does not pulse either)", not ww.ring().pulse and not bool((card["footer"] as Dictionary).get("pulse", true)))
	var bet1: float = st.well_between(1)
	var reg1: float = st.well_regen(1)
	_x("Well numbers: between waves 3/6/10% a second, in waves 1/1.5/2.5%", absf(bet1 - 0.03) < 1e-6 and absf(st.well_between(2) - 0.06) < 1e-6
		and absf(st.well_between(3) - 0.10) < 1e-6 and absf(reg1 - 0.01) < 1e-6 and absf(st.well_regen(2) - 0.015) < 1e-6 and absf(st.well_regen(3) - 0.025) < 1e-6)
	var sub := String(card["sub"])
	_x("the Well's card shows its current mending rates", sub.contains("Mends to full") and sub.contains("3%/s between waves, 1%/s in waves"))
	# a breather of a mission, faked for these lines only (no frame passes while it is on)
	var keep := {"active": f.active, "in_wave": f.in_wave, "on_break": f.on_break, "last_stand": f.last_stand, "gate_hp": f.gate_hp, "gate_max": f.gate_max}
	var keep_hp: Dictionary = st.hp.duplicate()
	st.reset_hp()
	f.active = true
	f.in_wave = false
	f.on_break = true
	f.last_stand = false
	f.gate_max = 600.0
	f.gate_hp = 600.0 * 0.2
	var full: float = st.full_hp("home")
	st.hp["home"] = full * 0.2
	var saved_warden: Node3D = main.guardian
	var warden := Node3D.new()
	warden.set_script(preload("res://scripts/guardian.gd"))
	warden.main = main
	warden.state = "idle"
	var warden_max: float = warden.max_hp()
	warden.hp = warden_max * 0.2
	main.guardian = warden
	for k in 30:
		st.well_tick(0.1)
	var g3s: float = f.gate_hp / f.gate_max
	var h3s: float = float(st.hp["home"]) / full
	_x("between waves: a hurt campfire and building mend by %s a second (3 s)" % ww._pct(bet1), absf(g3s - (0.2 + bet1 * 3.0)) < 0.002 and absf(h3s - (0.2 + bet1 * 3.0)) < 0.002,
		{"fire": snappedf(g3s, 0.001), "home": snappedf(h3s, 0.001)})
	_x("between waves: the standing Warden mends at the same rate", is_equal_approx(warden.hp / warden_max, 0.2 + bet1 * 3.0))
	for k in 600:
		st.well_tick(0.1)
	var g60: float = f.gate_hp / f.gate_max
	var h60: float = float(st.hp["home"]) / full
	_x("between waves: all the way to FULL at level 1, never above", absf(g60 - 1.0) < 0.0005 and absf(h60 - 1.0) < 0.0005 and g60 <= 1.0001 and h60 <= 1.0001,
		{"fire": snappedf(g60, 0.001), "home": snappedf(h60, 0.001)})
	Save.stations["well"] = 3
	f.gate_hp = 600.0 * 0.5
	for k in 10:
		st.well_tick(0.1)
	_x("Well level 3: 10% a second between waves", absf(f.gate_hp / 600.0 - 0.6) < 0.002, {"fire": f.gate_hp / 600.0})
	for k in 300:
		st.well_tick(0.1)
	_x("Well level 3 also ends at full", absf(f.gate_hp - 600.0) < 0.01)
	Save.stations["well"] = 1
	# a wave: a little every second, up to full
	f.on_break = false
	f.in_wave = true
	f.gate_hp = 600.0 * 0.3
	st.hp["home"] = full * 0.3
	warden.hp = warden_max * 0.3
	for k in 10:
		st.well_tick(0.1)
	var gain: float = f.gate_hp / f.gate_max - 0.3
	var hgain: float = float(st.hp["home"]) / full - 0.3
	_x("in a wave: +%s a second" % ww._pct(reg1), gain > 0.0 and absf(gain - reg1) < 0.0005 and absf(hgain - reg1) < 0.0005 and gain < bet1,
		{"gain": snappedf(gain, 0.0001), "home": snappedf(hgain, 0.0001), "regen": reg1})
	_x("in a wave: the standing Warden mends at the same rate", is_equal_approx(warden.hp / warden_max, 0.3 + reg1))
	f.gate_hp = 600.0 * 0.999
	for k in 100:
		st.well_tick(0.1)
	_x("in a wave: never above full", f.gate_hp <= 600.0 + 0.0001 and f.gate_hp > 600.0 * 0.999, {"fire": f.gate_hp})
	# never a broken thing, a ruin or the ashes
	st.hp["home"] = 0.0
	f.last_stand = true
	f.gate_hp = 0.0
	warden.state = "down"
	warden.hp = 0.0
	var recovery := Data.guardian_revive_s()
	warden._down_t = recovery
	for k in 50:
		st.well_tick(0.1)
	_x("never a broken building or the ashes", float(st.hp["home"]) == 0.0 and f.gate_hp == 0.0)
	_x("the Well leaves the downed Warden's health and recovery timer alone", warden.state == "down" and warden.hp == 0.0 and warden._down_t == recovery)
	main.guardian = saved_warden
	warden.free()
	f.last_stand = false
	f.gate_hp = 300.0
	Save.ruined.append("well")
	for k in 50:
		st.well_tick(0.1)
	_x("a ruined Well mends nothing", st.well_level() == 0 and f.gate_hp == 300.0)
	Save.ruined.erase("well")
	main.frozen = true
	var hp_before: float = f.gate_hp
	st._physics_process(0.5)
	main.frozen = false
	_x("nothing while the game is frozen", f.gate_hp == hp_before)
	for k in keep:
		f.set(k, keep[k])
	st.hp = keep_hp
	st.refresh()


# ---------------------------------------------------------------- (e) the Training Target and the Bow Shop as list rows
func _tiles() -> void:
	var st = _st()
	Save.stations["target"] = 1
	Save.stations["bench"] = 1
	Save.leaves = 5000
	st.refresh()
	var tw = main.hud.windows["target"]
	var tspec: Dictionary = tw.spec()
	var tr: Array = tspec["rows"]
	var dmg: Dictionary = _row_named(tr, String(Data.stat_info("damage")["name"]))
	_x("the Training Target's window is made of list rows (a stat each)", tr.all(func(r): return _kind(r) == "list") and _lists(tr).size() >= 3 and not dmg.is_empty()
		and String(dmg.get("badge", "")) == "Level %d/%d" % [int(Save.stats["damage"]), Data.stat_cap("damage")] and String(dmg["id"]) == "damage",
		{"rows": _titles(tr), "damage": dmg.get("badge", "")})
	_x("the Target's own upgrade is its pinned footer, not a row", _foot_label(tspec) == "Upgrade"
		and not tr.any(func(r): return String(r.get("title", "")) == "%s level 2" % String(Data.building("target")["name"])), {"footer": tspec.get("footer", {})})
	var bw = main.hud.windows["bench"]
	var bspec: Dictionary = bw.spec()
	var br: Array = bspec["rows"]
	var twig: Dictionary = _row_named(br, String(Data.bow_info(Save.bow)["name"]))
	_x("the Bow Shop's window is made of list rows, the bow in the paw 'Equipped' with Upgrade; its own Upgrade is the footer",
		br.all(func(r): return _kind(r) == "list") and _lists(br).size() >= 3 and String(twig.get("badge", "")) == "Equipped"
		and String(twig.get("label", "")) == "Upgrade" and _foot_label(bspec) == "Upgrade", {"rows": _titles(br)})
	var others: Array = _lists(br).filter(func(r): return String(r.get("icon", "")) == "bow" and r != twig)
	_x("every other bow is an Equip or Buy row (a Locked one has no button)", not others.is_empty() and others.all(func(r):
		return String(r["label"]) == "" if String(r.get("badge", "")) == "Locked" else String(r["label"]) in ["Equip", "Buy"]),
		{"bows": others.map(func(r): return "%s %s %s" % [r["title"], r.get("badge", ""), r["label"]])})
	await t._at_ring(tw.ring())
	await t._wait(0.5)
	await t._shot("campg_target_card")
	main.hud.hide_card()
	await t._wait(0.2)


# ---------------------------------------------------------------- (f) an old save keeps its stall and cottage
func _old_save() -> void:
	var st = _st()
	Save.missions_done = []
	for i in 3:
		Save.missions_done.append(String(Data.mission(i)["id"]))
	Save.camp_level = 1
	Save.stations["stall"] = 2
	Save.stations["cottage"] = 2
	Save.save_game()
	Save.load_game()
	st.catch_up_gifts()
	main.refresh_companions()
	st.refresh()
	_x("an old save keeps its Market and Cottage (gifts of raids 2 and 3) at their levels", int(Save.stations["stall"]) == 2
		and int(Save.stations["cottage"]) == 2 and Save.camp_level == 1, {"stations": Save.stations})
	_x("... and Thistle and Sprig", main.mount != null and main.pet != null and Data.mount_level() == 2 and Data.pet_level() == 2)
	var rows: Array = main.hud.windows["shop"].tab_spec("hearthtree")["rows"]
	var market := String(Data.building("stall")["name"])
	var cottage := String(Data.building("cottage")["name"])
	_x("neither the Hearthtree's window nor the build menu sells them again", _row_named(rows, market).is_empty() and _row_named(rows, cottage).is_empty()
		and _entry("stall").is_empty() and _entry("cottage").is_empty())
	var ride: Array = main.hud.windows["stall"].spec()["rows"].filter(func(r): return String(r.get("label", "")) == "Ride")
	_x("the Market works at Hearthtree 1 (Ride is on)", ride.size() == 1 and bool(ride[0]["enabled"]))


# ---------------------------------------------------------------- (g) the Hearthtree's repair during the missions
## What a ruin of `id` has cost so far (the sum repair_cost takes its share of), from balance.json.
func _spent(id: String) -> Dictionary:
	var out := {"leaves": 0.0, "timber": 0.0}
	if id == "home":
		var levels: Array = Data.building_levels("home")
		out["leaves"] = 100.0
		for k in range(1, mini(Save.camp_level, levels.size())):
			out["leaves"] += float(levels[k].get("leaves", 0))
			out["timber"] += float(levels[k].get("timber", 0))
		return out
	var price := Data.build_price(id)
	out["leaves"] = float(price.get("leaves", 0))
	out["timber"] = float(price.get("timber", 0))
	var lv2 := Data.building_levels(id)
	for k in range(1, mini(int(Save.stations.get(id, 1)), lv2.size())):
		out["leaves"] += float(lv2[k].get("leaves", 0))
		out["timber"] += float(lv2[k].get("timber", 0))
	return out


func _home_repair() -> void:
	var st = _st()
	Save.missions_done = [String(Data.mission(0)["id"])]
	var r: Dictionary = Data.gr()["repair"]
	var cap: Dictionary = r["ruin_cap"]
	var share := float(r["ruin_share"])
	var cl0 := Save.camp_level
	var ok := true
	var seen := {}
	var capped := false
	for lv in [2, 4, 6]:
		Save.camp_level = lv
		var sp := _spent("home")
		var want := {"leaves": clampi(int(ceil(sp["leaves"] * share)), int(r["ruin_min"]), int(cap["leaves"]))}
		if sp["timber"] > 0.0:
			want["timber"] = mini(int(ceil(sp["timber"] * share)), int(cap["timber"]))
		var got: Dictionary = st.repair_cost("home")
		seen[lv] = [got, want]
		ok = ok and JSON.stringify(got) == JSON.stringify(want) and int(got["leaves"]) <= int(cap["leaves"]) and int(got.get("timber", 0)) <= int(cap["timber"])
		capped = capped or int(got["leaves"]) == int(cap["leaves"])
	_x("in the raids a ruined Hearthtree costs %d%% of what it cost, at most %d leaves and %d timber" % [int(round(share * 100.0)), int(cap["leaves"]), int(cap["timber"])],
		not Data.raids_open() and ok and capped, {"by_level": seen})
	Save.stations["stall"] = 2
	var sp2 := _spent("stall")
	var rs := float(Data.b["raid"]["repair_share"])
	var want2 := {"leaves": maxi(10, int(ceil(sp2["leaves"] * rs)))}
	if sp2["timber"] > 0.0:
		want2["timber"] = int(ceil(sp2["timber"] * rs))
	var got2: Dictionary = st.repair_cost("stall")
	_x("another building (the Market) keeps the raid price (%d%% of what it cost)" % int(round(rs * 100.0)),
		JSON.stringify(got2) == JSON.stringify(want2), {"got": got2, "want": want2})
	Save.camp_level = cl0
	st.refresh()
