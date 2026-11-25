extends Node
## Phase G2: the camp (`-- --autotest --fresh --campg`), run from autotest.gd. Each check logs "EXPECT PASS <what>" or
## "EXPECT FAIL <what>" through autotest.gd's _expect. Light on purpose: the numbers come from balance.json, no fight is
## played (the Well's mending is stepped by hand, with a breather or a wave faked for those few lines only).
##   (a) the Hearthtree's card: its title is the Hearthtree (no "Shop"), its rows hold sections and item tiles, the
##       Grow tile "Hearthtree level 2" last after the goals
##   (b) at Hearthtree 1 the Market and the Mushroom Cottage are not offered; at 2 they are; a goal for one not built
##       points to the Hearthtree's card; building the Market brings Thistle, who can be ridden
##   (c) the Market: buying timber, a food item and (after the missions) amber changes the right stocks; selling amber
##   (d) the Well opens at Hearthtree 3, has one Upgrade row, and mends standing structures to full at both rates
##   (e) the Training Target and Bow Bench cards are made of item tiles (and section headings)
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


func _tile_named(rows: Array, title: String) -> Dictionary:
	for r in rows:
		if _kind(r) == "item" and String(r.get("title", "")) == title:
			return r
	return {}


## Every word on a card's rows (titles, lines, notes, buttons), for "is it there at all" checks.
func _words(rows: Array) -> String:
	var bits: Array = []
	for r in rows:
		for k in ["title", "text", "note", "label"]:
			bits.append(String(r.get(k, "")))
	return " | ".join(bits)


func _titles(rows: Array) -> Array:
	return rows.map(func(r): return "%s:%s" % [_kind(r), String(r.get("title", r.get("text", "")))])


# ---------------------------------------------------------------- (a) the Hearthtree's card
func _hearthtree_card() -> void:
	var st = _st()
	var spec: Dictionary = st._card_shop()
	var rows: Array = spec["rows"]
	var ht := Data.camp_name(true)
	_x("camp_name: 'the Hearthtree' / 'The Hearthtree'", Data.camp_name() == String(Data.b.get("camp_name", "the Hearthtree"))
		and Data.camp_name(true).begins_with("The "), {"name": Data.camp_name(), "cap": Data.camp_name(true)})
	_x("the Hearthtree's card is called the Hearthtree", String(spec["title"]) == ht, {"title": spec["title"]})
	_x("its rows hold item tiles and section headings", _items(rows).size() >= 3 and rows.any(func(r): return _kind(r) == "section"),
		{"rows": _titles(rows)})
	_x("no 'Shop' (other than the Bow Shop) on the card, and no 'your home'", not _words(rows).replace("Bow Shop", "").contains("Shop") and not _words(rows).to_lower().contains("your home")
		and not String(spec["sub"]).to_lower().contains("home"), {"sub": spec["sub"]})
	var want := "%s level 2" % ht.trim_prefix("The ")
	var grow: Array = rows.filter(func(r): return String(r.get("title", "")) == want)
	_x("the Grow tile: '%s' with Grow, the last of the goals' shelf" % want, grow.size() == 1 and String(grow[0]["label"]) == "Grow"
		and String((st._grow_rows().back() as Dictionary).get("title", "")) == want and (grow[0].get("stats", []) as Array).size() == 1,
		{"rows": _titles(rows)})
	var cat: Dictionary = _tile_named(rows, String(Data.stat_info("health")["name"]))
	_x("the cat's Health is a tile with a level badge and a bar", not cat.is_empty() and String(cat.get("badge", "")).begins_with("Level")
		and (cat.get("stats", []) as Array).size() == 1 and String(cat["label"]) == "Buy", {"tile": cat})
	await t._at_ring(st.rings["shop"])
	await t._wait(0.5)
	_x("the card opens with the Hearthtree's name", main.hud.card_ring() == st.rings["shop"] and main.hud.card_title() == ht,
		{"title": main.hud.card_title()})
	await t._shot("campg_hearthtree_card")
	main.hud.hide_card()
	await t._wait(0.2)


# ---------------------------------------------------------------- (b) the pet and the Market at Hearthtree 2
func _unlocks() -> void:
	var st = _st()
	var market := String(Data.b["stations"]["stall"]["name"])
	var cottage := String(Data.b["stations"]["cottage"]["name"])
	Save.leaves = 99999
	Save.timber = 9999
	Save.camp_level = 1
	st.refresh()
	var rows: Array = st._card_shop()["rows"]
	var m1: Dictionary = _tile_named(rows, market)
	var c1: Dictionary = _tile_named(rows, cottage)
	_x("Hearthtree 1: the Market and the Cottage are not open (needs_home 2)", not Data.station_open("stall") and not Data.station_open("cottage")
		and Data.station_needs_home("stall") == 2 and Data.station_needs_home("cottage") == 2)
	_x("Hearthtree 1: neither is offered (at most a locked tile, no Build)", not bool(m1.get("enabled", false)) and not bool(c1.get("enabled", false))
		and (m1.is_empty() or String(m1.get("badge", "")) == "Locked"), {"market": m1.get("text", ""), "cottage": c1.get("text", "")})
	st._build_station("stall")
	st._build_station("cottage")
	_x("Hearthtree 1: building them is refused", int(Save.stations["stall"]) == 0 and int(Save.stations["cottage"]) == 0 and Save.leaves == 99999)
	_x("no raid gives them any more", Data.gift_mission("stall") < 0 and Data.gift_mission("cottage") < 0)
	Save.camp_level = 2
	st.refresh()
	rows = st._card_shop()["rows"]
	var m2: Dictionary = _tile_named(rows, market)
	var c2: Dictionary = _tile_named(rows, cottage)
	_x("Hearthtree 2: the Market and the Cottage are Build tiles", bool(m2.get("enabled", false)) and String(m2.get("label", "")) == "Build"
		and bool(c2.get("enabled", false)) and String(c2.get("label", "")) == "Build", {"market": m2, "cottage": c2})
	# a goal for one not built yet points to the Hearthtree's card (where it is bought now)
	var g3: Array = Data.home_goals(3).filter(func(g): return String(g["type"]) == "station" and String(g["id"]) in ["stall", "cottage"])
	var to_home := not g3.is_empty()
	for g in g3:
		to_home = to_home and String(g["station"]) == "home" and st.goal_ring(String(g["station"])) == st.rings["shop"] \
			and not _tile_named(rows, st._goal_find(g)).is_empty()
	_x("Hearthtree 3's goals for the Cottage and the Market point to the Hearthtree's card", to_home,
		{"goals": g3.map(func(g): return "%s [%s]" % [g["progress"], g["station"]])})
	st._build_station("stall")
	await t._wait(0.3)
	_x("the Market is built and Thistle comes with it", int(Save.stations["stall"]) == 1 and Data.mount_level() == 1 and main.mount != null,
		{"stall": Save.stations["stall"], "mount": main.mount != null})
	var ride: Dictionary = st._card_stall()["rows"].filter(func(r): return String(r.get("label", "")) == "Ride")[0] if main.mount != null else {}
	_x("the Market's card has an enabled Ride row", bool(ride.get("enabled", false)), {"ride": ride.get("text", "")})
	main.set_riding(true, false)
	_x("Thistle can be ridden", main.player.riding)
	main.set_riding(false, false)
	st._build_station("cottage")
	await t._wait(0.3)
	_x("the Cottage is built and Sprig moves in", int(Save.stations["cottage"]) == 1 and main.pet != null)
	await t._at_ring(st.rings["stall"])
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
	var tb: Dictionary = Data.b["trade"]["buy"]
	Save.leaves = 1000
	Save.timber = 0
	st._trade(true)
	_x("buying timber: +%d timber for %d leaves" % [int(tb["timber"]), int(tb["leaves"])],
		Save.timber == int(tb["timber"]) and Save.leaves == 1000 - int(tb["leaves"]), {"timber": Save.timber, "leaves": Save.leaves})
	var bi := _index_of("sells", "berries")
	var be: Dictionary = Data.b["market"]["sells"][bi] if bi >= 0 else {}
	Save.pantry["berries"] = 0
	var l0 := Save.leaves
	st._market_buy(bi)
	_x("buying Sunberries: they go to the pantry, the leaves are paid", bi >= 0 and int(Save.pantry["berries"]) == int(be.get("amount", 0))
		and Save.leaves == l0 - int(be.get("leaves", 0)), {"pantry": Save.pantry, "leaves": Save.leaves})
	var cap := int(Data.b["cooking"]["pantry_cap"])
	Save.pantry["berries"] = cap - 1
	var full: Dictionary = st._market_sells().filter(func(r): return String(r.get("icon", "")) == "berries")[0]
	l0 = Save.leaves
	st._market_buy(bi)
	_x("a full pantry: the berries tile is off and nothing is bought", not bool(full["enabled"]) and int(Save.pantry["berries"]) == cap - 1
		and Save.leaves == l0, {"tile": full.get("text", "")})
	Save.pantry["berries"] = 2
	# Burrow materials: only once every mission is won
	var ai := _index_of("sells", "amber")
	var ae: Dictionary = Data.b["market"]["sells"][ai] if ai >= 0 else {}
	var a0 := int(Save.mats.get("amber", 0))
	l0 = Save.leaves
	var shown_before: bool = st._market_sells().any(func(r): return String(r.get("icon", "")) == "amber")
	st._market_buy(ai)
	_x("before the raids are won: no amber for sale, and none bought", ai >= 0 and not shown_before and int(Save.mats["amber"]) == a0 and Save.leaves == l0)
	var keep: Array = Save.missions_done.duplicate()
	Save.missions_done = []
	for i in Data.mission_count():
		Save.missions_done.append(String(Data.mission(i)["id"]))
	var amber_text := "An expedition material · you have %d" % a0
	var shown_after: bool = st._market_sells().any(func(r): return String(r.get("icon", "")) == "amber" and String(r.get("text", "")) == amber_text)
	st._market_buy(ai)
	_x("after the raids: amber shows its expedition note and can be bought", shown_after and int(Save.mats["amber"]) == a0 + int(ae.get("amount", 0))
		and Save.leaves == l0 - int(ae.get("leaves", 0)), {"amber": Save.mats["amber"], "leaves": Save.leaves})
	var si := _index_of("buys", "amber")
	var se: Dictionary = Data.b["market"]["buys"][si] if si >= 0 else {}
	l0 = Save.leaves
	var a1 := int(Save.mats["amber"])
	st._market_sell(si)
	_x("Bramble buys amber back for leaves", si >= 0 and int(Save.mats["amber"]) == a1 - int(se.get("amount", 0)) and Save.leaves == l0 + int(se.get("leaves", 0)),
		{"amber": Save.mats["amber"], "leaves": Save.leaves})
	var rows: Array = st._card_stall()["rows"]
	var heads: Array = rows.filter(func(r): return _kind(r) == "section").map(func(r): return String(r["text"]))
	_x("the Market's card: Bramble sells, Bramble buys, the Stable and the upgrade", heads.has("Bramble sells") and heads.has("Bramble buys")
		and heads.has("Stable") and heads.has("Upgrade"), {"sections": heads})
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
	var card: Dictionary = st._card_well()
	var wr: Array = card["rows"]
	_x("an existing Well below its build gate still works", st.shown("well") and st.well_level() == 1)
	_x("the Well has only its Upgrade row even when worn", wr.size() == 1 and String(wr[0]["label"]) == "Upgrade", {"rows": _words(wr)})
	Save.wear.erase("well")
	_x("the Well's marker shows no '!' for wishing", not st.rings["well"].pulse)
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
	_x("between waves: a hurt campfire and building mend by %s a second (3 s)" % st._pct(bet1), absf(g3s - (0.2 + bet1 * 3.0)) < 0.002 and absf(h3s - (0.2 + bet1 * 3.0)) < 0.002,
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
	_x("in a wave: +%s a second" % st._pct(reg1), gain > 0.0 and absf(gain - reg1) < 0.0005 and absf(hgain - reg1) < 0.0005 and gain < bet1,
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


# ---------------------------------------------------------------- (e) the Training Target and the Bow Bench as tiles
func _tiles() -> void:
	var st = _st()
	Save.stations["target"] = 1
	Save.stations["bench"] = 1
	Save.leaves = 5000
	st.refresh()
	var tr: Array = st._card_target()["rows"]
	var only_t := tr.all(func(r): return _kind(r) in ["item", "section"])
	var dmg: Dictionary = _tile_named(tr, String(Data.stat_info("damage")["name"]))
	_x("the Training Target's card is made of item tiles", only_t and _items(tr).size() >= 4 and not dmg.is_empty()
		and String(dmg.get("badge", "")) == "Level %d/%d" % [int(Save.stats["damage"]), Data.stat_cap("damage")] and (dmg.get("stats", []) as Array).size() == 1,
		{"rows": _titles(tr), "damage": dmg.get("badge", "")})
	var up: Dictionary = _tile_named(tr, "%s level 2" % String(Data.b["stations"]["target"]["name"]))
	_x("the Target's own upgrade is a tile", not up.is_empty() and String(up["label"]) == "Upgrade", {"rows": _titles(tr)})
	var br: Array = st._card_bench()["rows"]
	var only_b := br.all(func(r): return _kind(r) in ["item", "section"])
	var twig: Dictionary = _tile_named(br, String(Data.bow_info(Save.bow)["name"]))
	_x("the Bow Shop's card is made of item tiles, the bow in the paw 'Equipped'", only_b and _items(br).size() >= 3
		and String(twig.get("badge", "")) == "Equipped" and String(twig.get("label", "")) == "Upgrade", {"rows": _titles(br)})
	var bench_name := String(Data.b["stations"]["bench"]["name"])
	# the Bench's own upgrade tile shares the bow icon: leave it out
	var others: Array = _items(br).filter(func(r): return String(r.get("icon", "")) == "bow" and r != twig and not String(r.get("title", "")).begins_with(bench_name))
	_x("every other bow is a Buy or Equip tile", not others.is_empty() and others.all(func(r): return String(r["label"]) in ["Equip", "Buy"]),
		{"bows": others.map(func(r): return "%s %s" % [r["title"], r["label"]])})
	await t._at_ring(st.rings["target"])
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
	var rows: Array = st._card_shop()["rows"]
	var market := String(Data.b["stations"]["stall"]["name"])
	var cottage := String(Data.b["stations"]["cottage"]["name"])
	_x("the Hearthtree's card does not sell them again", _tile_named(rows, market).is_empty() and _tile_named(rows, cottage).is_empty())
	var ride: Array = st._card_stall()["rows"].filter(func(r): return String(r.get("label", "")) == "Ride")
	_x("the Market works at Hearthtree 1 (Ride is on)", ride.size() == 1 and bool(ride[0]["enabled"]))


# ---------------------------------------------------------------- (g) the Hearthtree's repair during the missions
## What a ruin of `id` has cost so far (the sum repair_cost takes its share of), from balance.json.
func _spent(id: String) -> Dictionary:
	var out := {"leaves": 0.0, "timber": 0.0}
	if id == "home":
		var levels: Array = Data.b["stations"]["camp"]["levels"]
		out["leaves"] = 100.0
		for k in range(1, mini(Save.camp_level, levels.size())):
			out["leaves"] += float(levels[k].get("leaves", 0))
			out["timber"] += float(levels[k].get("timber", 0))
		return out
	var s: Dictionary = Data.b["stations"][id]
	out["leaves"] = float(s.get("build", {}).get("leaves", 0))
	out["timber"] = float(s.get("build", {}).get("timber", 0))
	var lv2: Array = s.get("levels", [])
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
