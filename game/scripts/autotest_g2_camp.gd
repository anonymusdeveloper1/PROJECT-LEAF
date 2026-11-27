extends Node
## Phase G2: the camp (`-- --autotest --fresh --campg`), run from autotest.gd. Each check logs "EXPECT PASS <what>" or
## "EXPECT FAIL <what>" through autotest.gd's _expect. Light on purpose: the numbers come from balance.json and the
## content entries, no fight is played (the Well's mending is stepped by hand, with a breather or a wave faked for
## those few lines only). H5 (Stage 2, 27 Nov 2026): the Mushroom Cottage is gone and the Market has four bottom tabs.
##   (a) the Hearthtree's window (H4): its title is the Hearthtree (no "Shop"), the Hearthtree tab holds the goals and the
##       Settings section, the Cat tab holds Health as a list row, and the pinned footer holds "Level 1 of N" and Upgrade,
##       which asks in the confirm window
##   (b) the Market is locked at Hearthtree 1 and open at 2; the Cottage is nowhere (no entry, window, marker or menu
##       card); Hearthtree 3 asks for a built Market and pet level 2, Hearthtree 4 for pet level 3 (Q4 A), and before
##       the Market both goals Show the build menu at it; building the Market brings Thistle and Bramble, not the pet
##   (c) the Market's window (scripts/autotest_g2_market.gd, its own file): the four icon tabs, Sells and Buys with the
##       trade popup, Mounts and Pets (Sprig, training, Lumi, the pet goal's Go)
##   (d) the Well opens at Hearthtree 3, has no rows and an Upgrade footer, and mends standing structures to full at both
##       rates
##   (e) the Training Target and Bow Shop windows are made of list rows, each with its Upgrade in the footer (H4)
##   (f) a real v4 save (the Market and the Cottage at level 2, gifts of missions 2 and 3, Hearthtree 1) loads upgraded:
##       a built Market, the pet at level 2 with both pet looks, the mount at its old tier, the Market's old health
##   (g) (21 Nov 2026) a ruined Hearthtree during the missions costs the after-the-missions price (gloom_raids.repair
##       ruin_share, ruin_min, ruin_cap: at most 900 leaves and 30 timber); another building keeps raid.repair_share
## Screenshots: campg_hearthtree_card, campg_market_sells / _buys / _mounts / _pets, campg_market_popup,
## campg_market_pets_owned, campg_market_pet_detail, campg_target_card, campg_cottage_spot.

const MarketChecks := preload("res://scripts/autotest_g2_market.gd")   # (c): the Market's window
const SaveUpgrades := preload("res://core/save_upgrades.gd")
const V4_PATH := "user://leaf_save_test_campg_v4.json"   # (f): the scratch slot the v4 fixture is loaded from
const OLD_COTTAGE := Vector3(6.4, 0, 3.6)                # (f): where the Mushroom Cottage stood in H4 (a fixture literal)

var t                     # autotest.gd (its helpers: _wait, _shot, _expect, _until, _at_ring, _tap_at, _log)
var main


func run() -> bool:
	main.player.invincible = true
	_start_fresh()
	await t._wait(0.3)
	await _hearthtree_card()
	await _unlocks()
	var market := MarketChecks.new()
	market.t = t
	market.main = main
	await market.run()
	_well()
	await _tiles()
	await _old_save()
	_home_repair()
	main.hud.hide_card()
	return true


func _x(what: String, ok: bool, extra := {}) -> bool:
	return t._expect(what, ok, extra)


func _st():
	return main.stations


func _mw():
	return main.hud.windows["stall"]


## A camp with mission 1 won and nothing built or bought (H5: no pet, nothing owned, the default looks).
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
	Save.shards = 0
	Save.unlocks = []
	Save.mount_look = "thistle"
	Save.pet_look = "sprig"
	Save.mount_skin = "natural"
	Save.pet_skin = "natural"
	Save.attach["mount"] = ""
	Save.attach["pet"] = ""
	if "pet_level" in Save:
		Save.set("pet_level", 0)
	var owned: Variant = Save.get("owned")
	if owned is Dictionary:
		for k: String in ["mounts", "pets", "attachments"]:     # the outfits are the Tailor's (the original stays)
			(owned as Dictionary).erase(k)
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


## The row whose id (list_row's row_id) is rid, {} when there is none.
func _row_id(rows: Array, rid: String) -> Dictionary:
	for r in rows:
		if r is Dictionary and String((r as Dictionary).get("id", "")) == rid:
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


# ---------------------------------------------------------------- (b) the Market at Hearthtree 2, the Cottage gone
func _unlocks() -> void:
	var st = _st()
	var w = main.hud.windows["shop"]
	var market := String(Data.building("stall")["name"])
	Save.leaves = 99999
	Save.timber = 9999
	Save.camp_level = 1
	st.refresh()
	var m1: Dictionary = _entry("stall")
	var needs2: String = String(Data.word("needs_home")) % [Data.camp_name(), 2]
	_x("Hearthtree 1: the Market is not open (needs_home 2)", not Data.station_open("stall") and Data.station_needs_home("stall") == 2)
	_x("Hearthtree 1: the build menu shows the Market locked, with what it needs and no way to build",
		String(m1.get("state", "")) == "locked" and String(m1.get("needs", "")).contains(needs2), {"market": m1.get("needs", "")})
	_x("H5: the Mushroom Cottage is gone: no building entry, no window, no marker, not in the build menu",
		Data.building("cottage").is_empty() and not main.hud.windows.has("cottage") and not st.rings.has("cottage")
		and _entry("cottage").is_empty() and not Data.buildings().any(func(e): return String(e.get("id", "")) == "cottage"))
	_x("Hearthtree 1: the Hearthtree's window sells no building", not (w.tab_spec("hearthtree")["rows"] as Array).any(
		func(r): return String(r.get("title", "")) == market))
	st._build_station("stall")
	_x("Hearthtree 1: building the Market is refused", int(Save.stations["stall"]) == 0 and Save.leaves == 99999)
	_x("no raid gives the Market any more", Data.gift_mission("stall") < 0)
	Save.camp_level = 2
	st.refresh()
	var m2: Dictionary = _entry("stall")
	_x("Hearthtree 2: the Market is open in the build menu, with its price", String(m2.get("state", "")) == "open"
		and String(m2["needs"]) == "" and not (m2["price"] as Dictionary).is_empty(), {"market": m2})
	# Q4 A: Hearthtree 3 asks for a built Market and the pet at level 2, Hearthtree 4 for the pet at level 3
	var g3: Array = Data.home_goals(3)
	var g4: Array = Data.home_goals(4)
	var built: Array = g3.filter(func(g): return String(g["type"]) == "station" and String(g["id"]) == "stall")
	var pet2: Array = g3.filter(func(g): return String(g["type"]) == "pet_level" and int(g["need"]) == 2)
	var pet3: Array = g4.filter(func(g): return String(g["type"]) == "pet_level" and int(g["need"]) == 3)
	var odd: Array = (g3 + g4).filter(func(g): return String(g["id"]) == "cottage" or (String(g["type"]) == "station"
		and String(g["id"]) == "stall" and int(g["need"]) > 1))
	_x("Q4: Hearthtree 3 asks for a built Market and pet level 2, Hearthtree 4 for pet level 3; no Cottage or Market level goal",
		built.size() == 1 and int(built[0]["need"]) == 1 and pet2.size() == 1 and pet3.size() == 1 and odd.is_empty(),
		{"g3": g3.map(func(g): return g["progress"]), "g4": g4.map(func(g): return g["progress"])})
	# before the Market both goals Show the build menu at it
	var goal_rows: Array = w._grow_rows()
	var shows: Array = goal_rows.filter(func(r): return r.has("goal") and String(r["goal"].get("id", "")) == "stall")
	_x("before the Market: its goal and the pet goal have the station 'build' and a Show", shows.size() == 2
		and shows.all(func(r): return String(r["goal"]["station"]) == "build" and String(r["label"]) == "Show" and bool(r["enabled"])),
		{"rows": shows.map(func(r): return "%s [%s] %s" % [r["text"], r["goal"]["station"], r["label"]])})
	var pet_show: Array = shows.filter(func(r): return String(r["goal"]["type"]) == "pet_level")
	if not pet_show.is_empty():
		(pet_show[0]["action"] as Callable).call()
	await t._wait(0.4)
	_x("the pet goal's Show opens the build menu at the Market", main.hud.card_ring() == main.hud.windows["build"]
		and main.hud.windows["build"]._detail == "stall", {"card": main.hud.card_title(), "detail": main.hud.windows["build"]._detail})
	main.hud.hide_card()
	await t._wait(0.2)
	st._build_station("stall")
	await t._wait(0.3)
	_x("the Market is built (one level) and Thistle and Bramble come with it, the pet does not", int(Save.stations["stall"]) == 1
		and Data.building_levels("stall").size() == 1 and Data.mount_level() == 1 and main.mount != null and main.trader != null
		and main.pet == null and Data.pet_level() == 0, {"stall": Save.stations["stall"], "pet_level": Data.pet_level()})
	main.set_riding(true, false)
	_x("Thistle can be ridden", main.player.riding)
	main.set_riding(false, false)


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


# ---------------------------------------------------------------- (f) a real v4 save with the Market and the Cottage
## A v4 save as H4 wrote it (the frozen v4 form: stations with "cottage", cat_skins_owned, attach.owned, saddlery.attach),
## loaded from its own scratch slot so the v4 -> v5 step runs on it; the test slot is used again afterwards.
func _old_save() -> void:
	var st = _st()
	var missions: Array = []
	for i in 3:
		missions.append(String(Data.mission(i)["id"]))
	var stations := {}
	for k in Save.stations:
		stations[k] = 0
	stations["stall"] = 2
	stations["cottage"] = 2
	var v4 := {"save_v": 4, "leaves": 500, "timber": 20, "shards": 0, "camp_level": 1, "stations": stations,
		"stats": {"damage": 0, "draw": 0, "range": 0, "health": 0, "speed": 0, "magnet": 0}, "bows": {"twig": 1}, "bow": "twig",
		"missions_done": missions, "flags": {"shop_open": true, "shop_target": true, "shop_bench": true, "home": true, "first_stage_done": true},
		"ruined": [], "wear": {}, "mount_look": "thistle", "pet_look": "sprig", "mount_skin": "natural", "pet_skin": "natural",
		"unlocks": [], "bag": {}, "mats": {"amber": 0}, "attach": {"owned": [], "mount": "", "pet": ""},
		"saddlery": {"skills": {}, "attach": {}, "worn": ""}, "cat_skin": "original", "cat_skins_owned": ["original"]}
	var f := FileAccess.open(V4_PATH, FileAccess.WRITE)
	var written := f != null and f.store_string(JSON.stringify(v4, "  ") + "\n")
	if f != null:
		f.close()
	var slot: String = Save.path
	Save.path = V4_PATH
	Save.load_game()
	Save.path = slot                                   # every later write goes to the test slot again
	for p: String in [V4_PATH, V4_PATH.get_basename() + ".bak.json", V4_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	st.catch_up_gifts()
	main.refresh_companions()
	st.refresh()
	var hp_table: Array = (Data.b.get("save_upgrades", {}) as Dictionary).get("to_v5", {}).get("old_market_hp", [])
	_x("an H4 (v4) save loads and is upgraded through v5 to v6 (no Workshop yet, no held levels, nothing owed)", written and Save.loaded_v == 4
		and SaveUpgrades.CURRENT_VERSION == 6 and Save.save_v == 6 and int(Save.stations.get("workshop", -1)) == 0
		and Save.defence_reserves.is_empty() and Save.defence_legacy_credit.is_empty(), {"loaded_v": Save.loaded_v, "save_v": Save.save_v})
	_x("... its Market is built (one level) and the Cottage is gone, at Hearthtree 1", int(Save.stations["stall"]) == 1
		and int(Save.stations.get("cottage", 0)) == 0 and Save.camp_level == 1, {"stations": Save.stations})
	_x("... the pet at the Cottage's level 2, with Sprig and Lumi both owned (Q1)", Data.pet_level() == 2
		and Data.owned_level("pets", "sprig") == 1 and Data.owned_level("pets", "lumi") == 1, {"pet": Data.pet_level()})
	_x("... the mount keeps the Market's tier 2 with no Saddlery (Q2 A), both mounts owned", Data.mount_level() == 2 and Data.saddlery_level() == 0
		and Data.owned_level("mounts", "thistle") == 1 and Data.owned_level("mounts", "bramblewool") == 1, {"mount": Data.mount_level()})
	_x("... the Market keeps the health it earned at level 2 (Q5 A)", hp_table.size() > 2 and int(Save.get("market_hp_floor")) == int(hp_table[2])
		and is_equal_approx(st.full_hp("stall"), float(hp_table[2])), {"floor": Save.get("market_hp_floor"), "full": st.full_hp("stall")})
	_x("... and Thistle and Sprig are in the camp", main.mount != null and main.pet != null)
	var rows: Array = main.hud.windows["shop"].tab_spec("hearthtree")["rows"]
	var market := String(Data.building("stall")["name"])
	_x("neither the Hearthtree's window nor the build menu sells the Market again", _row_named(rows, market).is_empty() and _entry("stall").is_empty())
	var mw = _mw()
	mw.select("mounts")
	var ride: Dictionary = _row_id(mw.tab_spec("mounts")["rows"], "ride")
	mw.select("pets")
	var train: Dictionary = _row_id(mw.tab_spec("pets")["rows"], "pet_training")
	_x("the Market works at Hearthtree 1: Ride is on; the pet's row shows level 2 and Train waits for the Hearthtree",
		bool(ride.get("enabled", false)) and not train.is_empty() and String(train.get("badge", "")) == String(Data.word("level_badge")) % [2, Data.pet_top()]
		and not bool(train.get("enabled", true)), {"train": train.get("text", "")})
	mw.select("sells")
	# the camp where the Cottage stood (its old spot, a fixture literal): open ground, nothing kept for a building there
	main.hud.hide_card()
	await t._wait(0.2)
	await t._go_to(OLD_COTTAGE, 0.4)
	await t._wait(0.4)
	var near: Array = []                              # any building's model on the old spot
	for k in st.nodes:
		var n = st.nodes[k]
		if is_instance_valid(n) and n is Node3D and ((n as Node3D).global_position * Vector3(1, 0, 1)).distance_to(OLD_COTTAGE) < 1.3:
			near.append(k)
	_x("... the Cottage's old spot is open ground: no building, marker or kept ground there", not main.world.in_village(OLD_COTTAGE, 0.0)
		and near.is_empty() and main.world.station_pos("cottage") == Vector3.ZERO, {"near": near})
	await t._shot("campg_cottage_spot")


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
	Save.stations["stall"] = 1                          # H5: the Market has one level
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
