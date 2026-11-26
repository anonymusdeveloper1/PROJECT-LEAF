extends Node
## Phase F: the home's goals and the mission gates (`-- --autotest --fresh --homegoals`), run from autotest.gd. Each
## check logs "EXPECT PASS <what>" or "EXPECT FAIL <what>" through autotest.gd's _expect. Light on purpose: the numbers
## come from balance.json and no fight is played.
##   (a) a fresh save: home 2's goals not met; no mission needs a bigger Hearthtree (the owner, 21 Nov 2026), so with
##       missions 1-2 won mission 3 is open at home 1; Hearthtree 2-6 ask for missions 1, 5, 9, 12, 15 (one earlier
##       since 21 Nov 2026), and home 2's 'Win mission 1' is ticked once mission 1 is won
##   (b) home 2's list met (stations, stats, bow) -> its Grow row lights up, growing works and takes the price ->
##       mission 3 still on the signpost
##   (c) a won mission is not unlocked (no replays) and not on the signpost; a saved run of one stays playable
##   (d) caps: Training Target 1 -> damage 4, Target 2 at home 2 -> 6 (the Bench the same for bows); Target and Bench
##       offer levels up to 5, never above the home; their levels 3-5 / 4-5 reuse the top models
##   (e) the home's card starts with the goals, then Grow; a goal's Go walks the cat to the card that sells it
##   (f) the debug endgame start: Training Target and Bow Bench at 5

var t                     # autotest.gd (its helpers: _wait, _shot, _expect, _until, _at_ring, _press, _log)
var main


func run() -> bool:
	main.player.invincible = true
	_station_goal_gates()
	_start_fresh()
	await t._wait(0.3)
	_fresh_save()
	await _grow_to_2()
	_replays()
	_caps()
	await _home_card()
	_endgame()
	return true


func _x(what: String, ok: bool, extra := {}) -> bool:
	return t._expect(what, ok, extra)


## Every station goal must be reachable before the Hearthtree grows to the level that asks for it.
func _station_goal_gates() -> void:
	var menu := Data.menu_buildings()
	var levels: Array = Data.building_levels("home")
	var wins: int = 0
	for previous_home: int in levels.size():
		# Raid Missions open in order, so a locked mission also blocks those after it.
		while wins < Data.mission_count() and Data.mission_needs_home(wins) <= previous_home:
			wins += 1
		var burrows_open: bool = wins == Data.mission_count()
		for goal: Variant in (levels[previous_home] as Dictionary).get("goals", []):
			if not goal is Dictionary or String(goal.get("type", "")) != "station":
				continue
			var id: String = String(goal.get("id", ""))
			var need: int = int(goal.get("level", 1))
			var station: Dictionary = Data.building(id)
			var upgrades := Data.building_levels(id)
			var gift: int = Data.gift_mission(id)
			# The Buildings shelf is open by the first win. The Guardian Stone is found in the Gloomwood.
			var can_build: bool = menu.has(station) and Data.station_needs_home(id) <= previous_home \
				and wins >= maxi(1, int((station.get("unlock", {}) as Dictionary).get("missions_won", 0)))
			var can_get: bool = can_build or (gift >= 0 and gift < wins) or (id == "stone" and burrows_open)
			var can_level: bool = need >= 1 and need <= mini(previous_home, upgrades.size())
			for upgrade: int in range(1, mini(need, upgrades.size())):
				if bool((upgrades[upgrade] as Dictionary).get("needs_burrows", false)) and not burrows_open:
					can_level = false
			_x("Hearthtree %d station goal %s level %d is reachable at Hearthtree %d" % [previous_home + 1, id, need, previous_home],
				not station.is_empty() and can_get and can_level)


func _caps_of(key: String, lv: int) -> int:
	var c: Array = Data.b[key]
	return int(c[clampi(lv, 0, c.size() - 1)])


## A camp with nothing won, built or bought (a --fresh save already is; this makes sure).
func _start_fresh() -> void:
	Save.missions_done = []
	Save.mission_run = {}
	Save.camp_level = 1
	for k in Save.stations:
		Save.stations[k] = 0
	for k in Save.stats:
		Save.stats[k] = 0
	Save.bows = {"twig": 1}
	Save.bow = "twig"
	Save.placed = []
	Save.def_levels = {"barricade": 1, "tower": 1, "spikes": 1}
	Save.leaves = 0
	Save.timber = 0
	for k in ["shop_open", "shop_target", "shop_bench", "home", "first_stage_done"]:
		Save.set_flag(k)
	main.stations.refresh()


## Missions 1..n won (their gifts too, as a player would have them).
func _win_upto(n: int) -> void:
	for i in mini(n, Data.mission_count()):
		var id := String(Data.mission(i)["id"])
		if not Save.missions_done.has(id):
			Save.missions_done.append(id)
	main.stations.catch_up_gifts()


## The save set so every goal on home `level`'s list is met (never lowering anything).
func _meet(level: int) -> void:
	var levels: Array = Data.building_levels("home")
	for g in (levels[level - 1] as Dictionary).get("goals", []):
		var lv := int(g.get("level", 1))
		var id := String(g.get("id", ""))
		match String(g.get("type", "")):
			"mission":
				_win_upto(int(g.get("n", 1)))
			"station":
				Save.stations[id] = maxi(int(Save.stations.get(id, 0)), lv)
			"stat":
				Save.stats[id] = maxi(int(Save.stats.get(id, 0)), lv)
			"bow":
				Save.bows[id] = maxi(int(Save.bows.get(id, 0)), lv)
			"bow_any":
				Save.bows[Save.bow] = maxi(int(Save.bows.get(Save.bow, 1)), lv)
			"bow_owned":
				Save.bows[id] = maxi(int(Save.bows.get(id, 0)), 1)
			"towers":
				Save.def_levels["tower"] = maxi(int(Save.def_levels.get("tower", 1)), lv)
				var have := 0
				for sp in Save.placed:
					if String(sp.get("type", "")) == "tower":
						have += 1
				for k in maxi(0, int(g.get("count", 1)) - have):
					Save.placed.append({"type": "tower", "x": 6.0 + k, "z": -6.0, "rot": 0.0})   # data only (no piece is spawned)
			"defence":
				Save.def_levels[id] = maxi(int(Save.def_levels.get(id, 1)), lv)
			"all_stats":
				for k in Save.stats:
					Save.stats[k] = maxi(int(Save.stats[k]), lv)
			"depth":
				var bs: Dictionary = Save.burrow_stats(String(Data.burrow_list()[0]["id"]))
				bs["depth"] = maxi(int(bs["depth"]), int(g.get("n", 1)))


func _sign_rows() -> Array:
	var rows: Array = main.stations._card_sign().get("rows", [])
	return rows.filter(func(r): return String(r.get("label", "")) in ["Start", "Start wave", "Give up"])


func _texts(rows: Array) -> String:
	return " | ".join(rows.map(func(r): return (String(r["title"]) + " " if r.has("title") else "") + String(r.get("text", ""))))


# ---------------------------------------------------------------- (a) a fresh save
func _fresh_save() -> void:
	var g2 := Data.home_goals(2)
	var want: Array = Data.building_levels("home")[1].get("goals", [])
	var shaped := true
	for g in g2:
		if String(g["text"]) == "" or String(g["progress"]) == "" or not g.has("station") or not g.has("have") or not g.has("need") or not g.has("done"):
			shaped = false
	_x("home 2's goals come from balance.json, each with text, progress and a station", g2.size() == want.size() and g2.size() > 0 and shaped,
		{"goals": g2.map(func(g): return "%s [%s]" % [g["progress"], g["station"]])})
	_x("a fresh save: home 2's goals are not met", not Data.home_goals_met(2) and not Data.home_can_grow())
	_x("a fresh save: raid 1 is unlocked, raid 2 not yet", Data.mission_unlocked(0) and not Data.mission_unlocked(1))
	var needs: Array = range(Data.mission_count()).map(func(i): return Data.mission_needs_home(i))
	_x("no raid needs a bigger Hearthtree (balance.json needs_home all 1)", needs.all(func(n): return n == 1), {"needs_home": needs})
	# 21 Nov 2026: each Hearthtree level asks for one mission earlier (2 -> 1, 3 -> 5, 4 -> 9, 5 -> 12; 6-8 kept)
	var asks: Array = []
	for lv in range(2, 7):
		var ms: Array = Data.home_goals(lv).filter(func(g): return String(g["type"]) == "mission")
		asks.append(int(ms[0]["need"]) if ms.size() == 1 else -1)
	_x("Hearthtree 2-6 ask for raids 1, 5, 9, 12 and 15", asks == [1, 5, 9, 12, 15], {"asks": asks})
	# 22 Nov 2026: Thorn Volley is hidden from the Bow Shop, and the Frost Bow needs Bow Shop 5, so Hearthtree 6 asks for it; no goal needs a hidden bow
	var bow5: Array = Data.home_goals(6).filter(func(g): return String(g["type"]) == "bow_owned")
	var hidden_goals: Array = []
	for lvd in Data.building_levels("home"):
		for g in (lvd as Dictionary).get("goals", []):
			if String(g.get("type", "")) in ["bow", "bow_owned"] and Data.bow_hidden(String(g.get("id", ""))):
				hidden_goals.append(g)
	var frost_ok := Data.home_goals(5).filter(func(g): return String(g["type"]) == "bow_owned").is_empty()
	_x("Hearthtree 6 (not 5) asks for 'Frost Bow owned', and no Hearthtree goal asks for a hidden bow", bow5.size() == 1 and String(bow5[0]["text"]) == "Frost Bow owned"
		and frost_ok and hidden_goals.is_empty(), {"bow6": bow5.map(func(g): return g["text"]), "hidden": hidden_goals})
	# no goal asks for a bow (or a Bow Shop level) the Hearthtree level before it cannot give (the Shop is capped by station_max_level)
	var reach_bad: Array = []
	var levels_all: Array = Data.building_levels("home")
	var prices_up := true
	for lv in range(2, levels_all.size() + 1):
		var prev_cap_home := lv - 1
		var shop_max := mini(Data.building_levels("bench").size(), prev_cap_home)
		for g in (levels_all[lv - 1] as Dictionary).get("goals", []):
			if String(g.get("type", "")) == "bow_owned" and Data.bow_shop_level(String(g["id"])) > shop_max:
				reach_bad.append("%s at home %d" % [g["id"], lv])
		if lv > 2:
			prices_up = prices_up and int((levels_all[lv - 1] as Dictionary).get("leaves", 0)) > int((levels_all[lv - 2] as Dictionary).get("leaves", 0)) \
				and int((levels_all[lv - 1] as Dictionary).get("timber", 0)) > int((levels_all[lv - 2] as Dictionary).get("timber", 0))
	_x("no Hearthtree goal asks for a bow the Bow Shop cannot sell by then; each Hearthtree level costs more leaves and timber than the one before", reach_bad.is_empty() and prices_up,
		{"bad": reach_bad})
	var mg := Data.home_goals(2).filter(func(g): return String(g["text"]) == "Finish Raid Mission 1")
	_x("a fresh save: the 'Win raid 1' goal is not ticked yet", mg.size() == 1 and not bool(mg[0]["done"]), {"goals": Data.home_goals(2).map(func(g): return g["progress"])})
	_win_upto(1)
	mg = Data.home_goals(2).filter(func(g): return String(g["text"]) == "Finish Raid Mission 1")
	_x("raid 1 won: the 'Win raid 1' goal is ticked, the list still not met", mg.size() == 1 and bool(mg[0]["done"]) and not Data.home_goals_met(2))
	_win_upto(2)
	_x("raids 1-2 won: raid 3 is next and open at home 1", Data.next_mission() == 2 and Data.mission_unlocked(2),
		{"next": Data.next_mission(), "home": Save.camp_level})
	var rows := _sign_rows()
	_x("the signpost offers raid mission 3 to fight at home 1", rows.size() == 1 and String(rows[0]["text"]).begins_with("Raid Mission 3 ·")
		and String(rows[0]["label"]) == "Start" and bool(rows[0]["enabled"]), {"rows": _texts(rows)})
	main.stations.refresh()
	_x("the signpost shows its '!' (the next raid is open)", main.stations.rings["sign"].pulse)
	Save.leaves = 99999
	Save.timber = 9999
	main.stations._grow_camp()
	_x("the home does not grow while its goals are not met (even with the leaves)", Save.camp_level == 1)
	Save.leaves = 0
	Save.timber = 0


# ---------------------------------------------------------------- (b) home 2's list met -> grow -> mission 3
func _grow_to_2() -> void:
	_meet(2)
	_x("home 2's list met (stations, stats, bow)", Data.home_goals_met(2),
		{"left": Data.home_goals(2).filter(func(g): return not g["done"]).map(func(g): return g["progress"])})
	var price := Data.home_price(2)
	_x("home 2 has a price", int(price.get("leaves", 0)) > 0, {"price": price})
	var grow_row: Dictionary = main.stations._grow_rows().back()
	_x("not affordable yet: Grow is off", String(grow_row["title"]).begins_with("Hearthtree level 2") and not bool(grow_row["enabled"]))
	Save.leaves = int(price.get("leaves", 0)) + 37
	Save.timber = int(price.get("timber", 0)) + 3
	grow_row = main.stations._grow_rows().back()
	_x("goals met and affordable: Grow is on and pulses (the home's '!')", bool(grow_row["enabled"]) and bool(grow_row.get("pulse", false)) and Data.home_can_grow())
	main.stations.refresh()
	_x("the home's marker shows its '!'", main.stations.rings["shop"].pulse)
	main.stations._grow_camp()
	await t._wait(0.4)
	_x("growing the home works: level 2, the price taken", Save.camp_level == 2 and Save.leaves == 37 and Save.timber == 3,
		{"home": Save.camp_level, "leaves": Save.leaves, "timber": Save.timber})
	_x("raid 3 still open at home 2", Data.mission_unlocked(2))
	var rows := _sign_rows()
	_x("the signpost offers raid mission 3 to fight", rows.size() == 1 and String(rows[0]["text"]).begins_with("Raid Mission 3 ·") and String(rows[0]["label"]) == "Start"
		and bool(rows[0]["enabled"]), {"rows": _texts(rows)})
	_x("no hidden strength on the signpost any more", not String(rows[0]["note"]).contains("strength") if rows.size() > 0 else false)


# ---------------------------------------------------------------- (c) no replays
func _replays() -> void:
	_x("completed raid missions remain unlocked for replay", Data.mission_unlocked(0) and Data.mission_unlocked(1))
	_x("a later raid is not unlocked either", not Data.mission_unlocked(3) and not Data.mission_unlocked(Data.mission_count() - 1))
	var catalog: Array = main.stations._card_sign()["rows"]
	var finished: Array = catalog.filter(func(r): return bool(r.get("completed", false)))
	_x("the signpost lists completed raid missions with Replay", finished.size() == 2 and finished.all(func(r): return String(r["label"]) == "Replay" and bool(r["enabled"])))
	Save.mission_run = {"mission": 1, "chapter": 1}
	_x("a saved run of a raid stays playable (an old save's run)", Data.mission_unlocked(1))
	var rr := _sign_rows()
	_x("the signpost offers the saved run: Start wave / Give up", _texts(rr).contains("Raid Mission 2 ·") and rr.any(func(r): return String(r["label"]) == "Start wave")
		and rr.any(func(r): return String(r["label"]) == "Give up"), {"rows": _texts(rr)})
	Save.mission_run = {}


# ---------------------------------------------------------------- (d) caps and the Target / Bench levels
func _caps() -> void:
	Save.stations["target"] = 1
	Save.stations["bench"] = 1
	_x("Training Target 1: damage capped at %d" % _caps_of("stat_cap_by_station_level", 1),
		Data.stat_cap("damage") == _caps_of("stat_cap_by_station_level", 1) and Data.stat_cap("damage") == 4, {"cap": Data.stat_cap("damage")})
	_x("Bow Bench 1: bows capped at 4", Data.bow_cap() == _caps_of("bow_cap_by_bench_level", 1) and Data.bow_cap() == 4, {"cap": Data.bow_cap()})
	var up: Dictionary = main.stations._station_upgrade_row("target")
	_x("the Target card offers level 2 at home 2", String(up["title"]).contains("level 2") and not (up["cost"] as Dictionary).is_empty())
	Save.leaves = 99999
	Save.timber = 9999
	main.stations._upgrade_station("target")
	main.stations._upgrade_station("bench")
	_x("Target 2 at home 2: damage capped at 6", int(Save.stations["target"]) == 2 and Data.stat_cap("damage") == 6, {"cap": Data.stat_cap("damage")})
	_x("Bench 2 at home 2: bows capped at 6", int(Save.stations["bench"]) == 2 and Data.bow_cap() == 6, {"cap": Data.bow_cap()})
	_x("Health uses the home level: capped at 6 at home 2", Data.stat_cap("health") == _caps_of("stat_cap_by_station_level", 2))
	main.stations._upgrade_station("target")
	up = main.stations._station_upgrade_row("target")
	_x("never above the home: Target level 3 refused at home 2", int(Save.stations["target"]) == 2 and not bool(up["enabled"]) and String(up.get("text", "")).contains("Hearthtree at level 3"),
		{"row": up.get("text", "")})
	Save.camp_level = 5
	_x("at home 5 the Target and the Bench go to 5, the Well stays at 3", Data.station_max_level("target") == 5 and Data.station_max_level("bench") == 5
		and Data.station_max_level("well") == 3)
	Save.stations["target"] = 4
	Save.stations["bench"] = 5
	_x("Target 4 and Bench 5: caps 9 and 10, the top models reused", Data.stat_cap("damage") == _caps_of("stat_cap_by_station_level", 4)
		and Data.bow_cap() == _caps_of("bow_cap_by_bench_level", 5) and main.stations.model_name("target") == "target_2"
		and main.stations.model_name("bench") == "bow_bench_3", {"target": main.stations.model_name("target"), "bench": main.stations.model_name("bench")})
	Save.stations["target"] = 5
	_x("the Target at its top shows max", String(main.stations._station_upgrade_row("target")["text"]).contains("max"))
	Save.camp_level = 2
	Save.stations["target"] = 1
	Save.stations["bench"] = 1
	Save.leaves = 300
	Save.timber = 0
	main.stations.refresh("all")


# ---------------------------------------------------------------- (e) the home's card and a goal's Go
func _home_card() -> void:
	var goals := Data.home_goals(3)
	await t._at_ring(main.stations.rings["shop"])
	await t._wait(0.5)
	await t._shot("homegoals_home_card")
	_x("the home's card is open", main.hud.card_ring() == main.stations.rings["shop"] and main.hud.card_title() == Data.camp_name(true), {"title": main.hud.card_title()})
	var rows: Array = main.stations._card_shop()["rows"]
	var first_ok := rows.size() > goals.size()
	for i in mini(goals.size(), rows.size()):
		var g: Dictionary = goals[i]
		var want := String(g["text"]) if bool(g["done"]) else String(g["progress"])
		if String(rows[i]["text"]) != want or not bool(rows[i].get("small", false)):
			first_ok = false
	_x("the home's card starts with home 3's goals, one line each", first_ok, {"rows": _texts(rows.slice(0, goals.size() + 1))})
	var grow_i := -1
	for i in rows.size():
		if String(rows[i].get("kind", "")) == "item" and String(rows[i].get("title", "")).begins_with("Hearthtree level 3"):
			grow_i = i
			break
	_x("then a Grow heading, and the Grow tile (off: goals left)", grow_i == goals.size() + 1 and String(rows[goals.size()].get("kind", "")) == "section"
		and String(rows[grow_i]["label"]) == "Grow" and not bool(rows[grow_i]["enabled"]), {"grow_i": grow_i})
	var marks_ok := true
	var n_go := 0
	for i in mini(goals.size(), rows.size()):
		var r: Dictionary = rows[i]
		if bool(r.get("done", false)):
			marks_ok = marks_ok and String(r["label"]) == ""
		else:
			marks_ok = marks_ok and r.has("done") and String(r["label"]) in ["Go", "Show", ""]
			if String(r["label"]) != "":
				n_go += 1
	_x("a met goal has a tick and no button, a missing one its progress and Go / Show", marks_ok and n_go > 0, {"buttons": n_go})
	# the first goal with Go: the signpost ("Win mission 5"), the cat walks there and its card opens
	var go_i := -1
	for i in goals.size():
		if String(rows[i]["label"]) == "Go":
			go_i = i
			break
	var want_ring = main.stations.goal_ring(String(goals[go_i]["station"])) if go_i >= 0 else null
	var want_title := String(want_ring.builder.call().get("title", "")) if want_ring != null else ""
	t._press("Go")
	var ok: bool = await t._until(func(): return want_ring != null and main.hud.card_ring() == want_ring, 12.0)
	_x("a goal's Go walks the cat to its card (%s)" % String(goals[go_i]["progress"] if go_i >= 0 else "none"), ok and main.hud.card_title() == want_title,
		{"want": want_title, "got": main.hud.card_title()})
	main.hud.hide_card()
	await t._wait(0.3)
	# a Training Target goal: Go opens the Target's card
	var tg := -1
	for i in goals.size():
		if String(goals[i]["station"]) == "target" and not bool(goals[i]["done"]):
			tg = i
			break
	if tg >= 0:
		var row: Dictionary = main.stations._card_shop()["rows"][tg]
		(row["action"] as Callable).call()
		var ok2: bool = await t._until(func(): return main.hud.card_ring() == main.stations.rings["target"], 12.0)
		_x("the Training Target goal opens the Training Target's card", ok2 and main.hud.card_title() == "Training Target", {"got": main.hud.card_title()})
		await t._shot("homegoals_target_card")
	else:
		_x("home 3's list has a Training Target goal", false)
	main.hud.hide_card()
	await t._wait(0.3)
	# a goal sold on the home's own card: Show keeps the card open (it scrolls to the row)
	var hg := -1
	for i in goals.size():
		if String(goals[i]["station"]) == "home" and not bool(goals[i]["done"]):
			hg = i
			break
	if hg >= 0:
		await t._at_ring(main.stations.rings["shop"])
		var row2: Dictionary = main.stations._card_shop()["rows"][hg]
		_x("a goal sold at the home says Show", String(row2["label"]) == "Show", {"row": row2["text"]})
		(row2["action"] as Callable).call()
		main.hud.refresh_card()
		await t._wait(0.5)
		_x("Show keeps the home's card open", main.hud.card_ring() == main.stations.rings["shop"])
		await t._shot("homegoals_show")
	main.hud.hide_card()


# ---------------------------------------------------------------- (f) the debug endgame start
func _endgame() -> void:
	Save._endgame_seed()
	_x("the endgame start: home 5, Training Target and Bow Bench at 5", Save.camp_level == 5 and int(Save.stations["target"]) == 5
		and int(Save.stations["bench"]) == 5, {"stations": Save.stations})
	_x("the endgame start: the other buildings at their top for home 5", int(Save.stations["well"]) == 3 and int(Save.stations["cottage"]) == 3
		and int(Save.stations["stall"]) == 3 and int(Save.stations["garden"]) == 3)
	_x("the endgame cat can reach 10 in every stat and bow", Data.stat_cap("damage") >= 10 and Data.stat_cap("range") >= 10 and Data.bow_cap() >= 10,
		{"damage": Data.stat_cap("damage"), "bow": Data.bow_cap()})
