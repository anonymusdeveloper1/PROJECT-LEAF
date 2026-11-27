extends Node
## Phase F: the home's goals and the mission gates (`-- --autotest --fresh --homegoals`), run from autotest.gd. Each
## check logs "EXPECT PASS <what>" or "EXPECT FAIL <what>" through autotest.gd's _expect. Light on purpose: the numbers
## come from the data and no fight is played. H4: every window is reached through main.hud.windows[<marker id>] (the
## Hearthtree's is "shop") or main.hud.confirm, never through the old card names on stations.gd.
##   (t) H4, the Hearthtree window's tabs (the owner's answers, 26 Nov 2026, Q8): one tab gives no tab bar; Cat shows
##       once flag "home" is set, Defences once the first defence opens; the Cat tab holds Health, Move speed and Leaf
##       magnet as list rows; a tab's "!" dot and the marker's "!" light for an affordable Cat row while the Hearthtree
##       tab is selected; the window opens on the Hearthtree tab, tabs at the top; screenshots homegoals_tabs and
##       homegoals_cat_tab
##   (a) a fresh save: home 2's goals not met; no mission needs a bigger Hearthtree (the owner, 21 Nov 2026), so with
##       missions 1-2 won mission 3 is open at home 1; Hearthtree 2-6 ask for missions 1, 5, 9, 12, 15 (one earlier
##       since 21 Nov 2026), and home 2's 'Win mission 1' is ticked once mission 1 is won
##   (b) home 2's list met (stations, stats, bow) -> the Defences tab shows; the pinned Upgrade is on even with the
##       price short and opens the confirm (price red, Confirm grey, Q2 (a)), Cancel comes back; with the price the
##       footer pulses and the marker shows its "!"; Upgrade -> the confirm lists what level 2 gives -> Confirm grows it,
##       takes the price, sends building_upgraded("home", 2) and comes back to the window (Q3 (a)) -> mission 3 still on
##       the signpost; screenshots homegoals_footer, homegoals_confirm_short, homegoals_confirm
##   (c) a won mission is not unlocked (no replays) and not on the signpost; a saved run of one stays playable
##   (d) caps: Training Target 1 -> damage 4, Target 2 at home 2 -> 6 (the Bench the same for bows); the Target window's
##       pinned Upgrade offers level 2 at home 2, says "Needs the Hearthtree at level 3" with Upgrade off, "Max level"
##       at its top; Target and Bench levels 3-5 / 4-5 reuse the top models
##   (e) the Hearthtree tab starts with the goals; no Grow tile and no building tiles (the level is the footer, on the
##       Hearthtree tab only); Go walks the cat to the signpost; a Target goal opens the Target; Show on a stat goal
##       opens the Cat tab, on a towers goal the Defences tab (the window stays open); Show on a "Build the X" goal opens
##       the build menu at X; screenshots homegoals_home_card, homegoals_defences_tab, homegoals_target_card,
##       homegoals_show, homegoals_show_defences, homegoals_build_show
##   (g) the confirm for Hearthtree levels 6-8 opens and lists what each gives (some tables are shorter than the
##       levels), and the footer says "Max level" at the top; screenshot homegoals_confirm_top
##   (f) the debug endgame start: Training Target and Bow Bench at 5; the pet (Data.pet_level 3), the one-level Market (1), the
##       mount (Data.mount_level 5) and no Cottage
##   (h) H5 (the owner's Q4 A): the pet-level goals (2 and 3) and the built Market; Show opens the build menu, Go the Market on its
##       Pets tab; the goal ticks from Data.pet_level()

var t                     # autotest.gd (its helpers: _wait, _shot, _expect, _until, _at_ring, _press, _log)
var main


func run() -> bool:
	main.player.invincible = true
	_station_goal_gates()
	_start_fresh()
	await t._wait(0.3)
	await _tabs()
	_fresh_save()
	await _grow_to_2()
	_replays()
	_caps()
	await _home_card()
	await _pet_goals()
	await _confirm_levels()
	_endgame()
	return true


func _x(what: String, ok: bool, extra := {}) -> bool:
	return t._expect(what, ok, extra)


## A window word (balance.json "windows").
func _w(key: String) -> String:
	return String(Data.word(key))


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
	Save.defence_reserves = {}
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
				# H6: the goal reads the placed records' own levels (data only: no piece is spawned)
				var have := 0
				for sp: Dictionary in Save.placed:
					if String(sp.get("type", "")) == "tower":
						have += 1
						sp["level"] = maxi(int(sp.get("level", 1)), lv)
				for k in maxi(0, int(g.get("count", 1)) - have):
					Save.placed.append({"type": "tower", "x": 6.0 + k, "z": -6.0, "rot": 0.0, "level": lv})
			"defence":
				var found := false
				for sp: Dictionary in Save.placed:
					if String(sp.get("type", "")) == id:
						sp["level"] = maxi(int(sp.get("level", 1)), lv)
						found = true
						break
				if not found:
					if id == "barricade":
						Save.placed.append({"type": id, "slot": [0, 0], "row": 1, "level": lv})
					else:
						Save.placed.append({"type": id, "x": 9.0, "z": -6.0, "rot": 0.0, "level": lv})
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


# ---------------------------------------------------------------- H4 helpers: the Hearthtree window and the open card
## The Hearthtree tab's name ("Hearthtree"): its tab's words, and the confirm's title starts with it.
func _home_word() -> String:
	return Data.camp_name(true).trim_prefix("The ")


## A footer's first button ({} when it has none).
func _first_button(f: Dictionary) -> Dictionary:
	var bs: Array = f.get("buttons", [])
	return bs[0] if not bs.is_empty() and bs[0] is Dictionary else {}


## A footer in words, for the log.
func _footer_words(f: Dictionary) -> String:
	var bs: Array = (f.get("buttons", []) as Array).map(func(b): return "%s%s" % [String(b.get("label", "")), "" if bool(b.get("enabled", false)) else " (off)"])
	return "%s | %s | %s | %s" % [String(f.get("text", "")), String(f.get("note", "")), JSON.stringify(f.get("cost", {})), ", ".join(bs)]


## Two prices hold the same of every currency.
func _same_price(a: Dictionary, b: Dictionary) -> bool:
	for k in Data.CURRENCIES:
		if int(a.get(k, 0)) != int(b.get(k, 0)):
			return false
	return true


## The confirm's lines: the first letter made a capital (the confirm does that).
func _capitalised(lines: Array) -> Array:
	return lines.map(func(s): return String(s).substr(0, 1).to_upper() + String(s).substr(1))


## A spec's tabs hold a "!" dot.
func _any_dot(s: Dictionary) -> bool:
	return (s.get("tabs", []) as Array).any(func(tb): return bool(tb.get("dot", false)))


## The open card's tab buttons now (not the old ones going after a refresh).
func _tab_buttons() -> Array:
	var out: Array = []
	if main.hud._card == null or main.hud._card_tabs == null or not is_instance_valid(main.hud._card_tabs):
		return out
	for c in main.hud._card_tabs.get_children():
		if (c as Control).visible and not c.is_queued_for_deletion() and c.has_meta("card_tab"):
			out.append(c)
	return out


## A tab button carries the small "!" dot (card_parts.gd tab_dot).
func _has_dot(b: Node) -> bool:
	for c in b.get_children():
		if c.has_meta("tab_dot"):
			return true
	return false


## The open card's list rows now (ui/kit/list_row.gd: meta list_row, title, id).
func _list_rows() -> Array:
	var out: Array = []
	if main.hud._card == null or main.hud._card_list == null or not is_instance_valid(main.hud._card_list):
		return out
	for c in main.hud._card_list.get_children():
		if (c as Control).visible and not c.is_queued_for_deletion() and c.has_meta("list_row"):
			out.append(c)
	return out


func _list_ids() -> Array:
	return _list_rows().map(func(r): return String(r.get_meta("id", "")))


func _list_titles() -> Array:
	return _list_rows().map(func(r): return String(r.get_meta("title", "")))


## The open card shows its pinned footer.
func _foot_shows() -> bool:
	var f = main.hud.p_card.foot
	return f != null and is_instance_valid(f) and (f as Control).visible


## The index in `rows` of the k-th goal line (-1 when there are fewer).
func _goal_index(rows: Array, k: int) -> int:
	var n := 0
	for i in rows.size():
		if rows[i] is Dictionary and (rows[i] as Dictionary).has("goal"):
			if n == k:
				return i
			n += 1
	return -1


## How many enabled "Show" buttons come before row i (autotest._press counts them in the card's order).
func _show_count(rows: Array, i: int) -> int:
	var n := 0
	for j in mini(i, rows.size()):
		var r: Dictionary = rows[j]
		if String(r.get("label", "")) == "Show" and bool(r.get("enabled", false)):
			n += 1
	return n


## A row of the Hearthtree's card before H4 Stage 2: the Grow tile, a Build tile, or one of their shelf headings.
func _is_old_row(r: Variant) -> bool:
	if not (r is Dictionary):
		return false
	var d: Dictionary = r
	if String(d.get("label", "")) in ["Grow", "Build"]:
		return true
	return String(d.get("kind", "")) == "section" and String(d.get("text", "")) in ["Grow", "Buildings", "The cat", "Defences"]


## The first goal in `goals` that `pick` likes and that is not met yet (-1 when none).
func _find_goal(goals: Array, pick: Callable) -> int:
	for i in goals.size():
		if not bool(goals[i]["done"]) and bool(pick.call(goals[i])):
			return i
	return -1


# ---------------------------------------------------------------- (t) H4: the Hearthtree window's tabs
func _tabs() -> void:
	var win = main.hud.windows["shop"]
	var ring = main.stations.rings["shop"]
	Save.leaves = 0
	Save.flags.erase("home")
	main.stations.refresh()
	var s: Dictionary = win.spec()
	_x("H4: with one tab (before the first mission's last wave) the Hearthtree window has no tab bar", win.tab_ids() == ["hearthtree"] and not s.has("tabs"),
		{"tabs": win.tab_ids()})
	Save.set_flag("home")
	main.stations.refresh()
	s = win.spec()
	var tabs: Array = s.get("tabs", [])
	var words: Array = tabs.map(func(tb): return String(tb.get("text", "")))
	_x("the Cat tab shows once the cat's own upgrades are sold (flag home), no Defences tab before the first defence opens; tabs at the top, the Hearthtree tab selected",
		win.tab_ids() == ["hearthtree", "cat"] and tabs.size() == 2 and String(s.get("tabs_at", "")) == "top" and bool(tabs[0].get("selected", false))
		and words == [_home_word(), _w("tab_cat")], {"tabs": words})
	var rows: Array = s.get("rows", [])
	var last: Dictionary = rows.back() if not rows.is_empty() else {}
	_x("before the first win: no goals and no footer; the Graphics row stays at the bottom of the Hearthtree tab",
		not s.has("footer") and String(last.get("label", "")) == "Change" and String(last.get("text", "")).begins_with("Graphics")
		and not rows.any(func(r): return (r as Dictionary).has("goal")), {"rows": _texts(rows)})
	var cat: Dictionary = win.tab_spec("cat")
	var cat_rows: Array = cat.get("rows", [])
	var ids: Array = cat_rows.map(func(r): return String(r.get("id", "")))
	_x("tab_spec('cat'): Health, Move speed and Leaf magnet as list rows, no footer", ids == ["health", "speed", "magnet"]
		and cat_rows.all(func(r): return String(r.get("kind", "")) == "list") and not cat.has("footer"), {"ids": ids})
	# the tab "!" and the marker's "!": none with 0 leaves; enough for Health lights the Cat tab's dot and the marker,
	# whichever tab is selected
	_x("0 leaves: no tab '!' and no marker '!'", not _any_dot(s) and not bool(ring.pulse))
	Save.leaves = int(Data.stat_cost("health", int(Save.stats["health"])).get("leaves", 0))
	main.stations.refresh()
	s = win.spec()
	tabs = s.get("tabs", [])
	_x("an affordable Cat row: the Cat tab gets the '!' dot (the Hearthtree tab not), and the marker shows its '!' while the Hearthtree tab is selected",
		win.tab == "hearthtree" and tabs.size() == 2 and bool(tabs[1].get("dot", false)) and not bool(tabs[0].get("dot", false)) and bool(ring.pulse),
		{"leaves": Save.leaves})
	await t._at_ring(ring)
	await t._wait(0.4)
	var bs := _tab_buttons()
	var on_top: bool = main.hud._card_nav != null and (main.hud._card_nav as Control).visible and main.hud._card_body != null \
		and (main.hud._card_nav as Control).get_global_rect().position.y < (main.hud._card_body as Control).get_global_rect().position.y
	_x("the window opens on the Hearthtree tab: two tab buttons at the top, the Cat one with its '!' dot",
		main.hud.card_ring() == ring and win.tab == "hearthtree" and bs.size() == 2 and on_top
		and String(bs[0].get_meta("tab_id", "")) == "hearthtree" and not _has_dot(bs[0]) and _has_dot(bs[1]),
		{"buttons": bs.map(func(b): return String(b.get_meta("tab_id", ""))), "on_top": on_top})
	await t._shot("homegoals_tabs")
	var pressed: bool = t._press(_w("tab_cat"))
	await t._wait(0.4)
	_x("a tap on the Cat tab shows its three stat rows", pressed and win.tab == "cat" and _list_ids() == ["health", "speed", "magnet"],
		{"ids": _list_ids()})
	await t._shot("homegoals_cat_tab")
	main.hud.hide_card()
	await t._wait(0.3)
	await t._at_ring(ring)
	await t._wait(0.3)
	_x("opened again, the window is back on the Hearthtree tab", main.hud.card_ring() == ring and win.tab == "hearthtree", {"tab": win.tab})
	main.hud.hide_card()
	await t._wait(0.3)
	Save.leaves = 0
	main.stations.refresh()


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


# ---------------------------------------------------------------- (b) home 2's list met -> Upgrade, the confirm, Confirm
func _grow_to_2() -> void:
	_meet(2)
	_x("home 2's list met (stations, stats, bow)", Data.home_goals_met(2),
		{"left": Data.home_goals(2).filter(func(g): return not g["done"]).map(func(g): return g["progress"])})
	var price := Data.home_price(2)
	_x("home 2 has a price", int(price.get("leaves", 0)) > 0, {"price": price})
	var win = main.hud.windows["shop"]
	var ring = main.stations.rings["shop"]
	var n: int = Data.building_levels("home").size()
	Save.leaves = 0
	Save.timber = 0
	main.stations.refresh()
	_x("H6: no Defences tab any more (the Workshop sells and upgrades the defences)", win.tab_ids() == ["hearthtree", "cat"] and not (win.tab_ids() as Array).has("defences"),
		{"tabs": win.tab_ids()})
	var f: Dictionary = win.tab_spec("hearthtree").get("footer", {})
	var up := _first_button(f)
	_x("goals met, the price short: the footer says 'Level 1 of %d' with the price; Upgrade is on (it opens the confirm); no '!'" % n,
		String(f.get("text", "")) == _w("level_of") % [1, n] and String(f.get("note", "x")) == "" and _same_price(f.get("cost", {}), price)
		and String(up.get("label", "")) == _w("upgrade") and bool(up.get("enabled", false)) and not bool(f.get("pulse", true)) and not bool(ring.pulse),
		{"footer": _footer_words(f)})
	var gv: Array = win.gives(2)
	var names: Array = Data.b["home_names"]
	var fires: Array = Data.b["fire_hp_by_camp_level"]
	_x("what level 2 gives starts with its new look and the campfire's health", gv.size() >= 2 and String(gv[0]) == _w("home_look") % String(names[1])
		and gv.has(_w("home_fire") % int(fires[2])), {"gives": gv})
	await t._at_ring(ring)
	await t._wait(0.4)
	var btn: Button = main.hud.p_card.footer_button(_w("upgrade"))
	_x("the pinned Upgrade shows under the rows (not in the scroll) and is on", btn != null and not btn.disabled and not main.hud._card_scroll.is_ancestor_of(btn))
	await t._shot("homegoals_footer")
	if btn != null:
		btn.pressed.emit()
	await t._wait(0.4)
	var cf = main.hud.confirm
	var title := "%s level 2" % _home_word()
	var lines: Array = (cf.spec().get("rows", []) as Array).map(func(r): return String(r.get("text", "")))
	var ok_btn: Button = main.hud.p_card.footer_button(_w("confirm"))
	_x("Upgrade with the price short opens the confirm (Q2 a): it lists what level 2 gives; Confirm is grey",
		main.hud.card_ring() == cf and main.hud.card_title() == title and lines == _capitalised(gv) and ok_btn != null and ok_btn.disabled,
		{"title": main.hud.card_title(), "lines": lines})
	await t._shot("homegoals_confirm_short")
	var cancel: Button = main.hud.p_card.footer_button(_w("cancel"))
	if cancel != null:
		cancel.pressed.emit()
	await t._wait(0.4)
	_x("Cancel comes back to the Hearthtree window and nothing grew", main.hud.card_ring() == ring and Save.camp_level == 1, {"title": main.hud.card_title()})
	Save.leaves = int(price.get("leaves", 0)) + 37
	Save.timber = int(price.get("timber", 0)) + 3
	main.stations.refresh()
	main.hud.refresh_card()
	f = win.tab_spec("hearthtree").get("footer", {})
	var tabs: Array = win.spec().get("tabs", [])
	_x("goals met and affordable: the footer pulses and the Hearthtree tab has its '!' dot", bool(f.get("pulse", false)) and Data.home_can_grow()
		and not tabs.is_empty() and bool(tabs[0].get("dot", false)), {"footer": _footer_words(f)})
	_x("the home's marker shows its '!'", bool(ring.pulse))
	var got: Array = []
	var hear := func(bid: String, lv: int) -> void: got.append("%s %d" % [bid, lv])
	Events.building_upgraded.connect(hear)
	btn = main.hud.p_card.footer_button(_w("upgrade"))
	if btn != null:
		btn.pressed.emit()
	await t._wait(0.4)
	ok_btn = main.hud.p_card.footer_button(_w("confirm"))
	var could: bool = main.hud.card_ring() == cf and ok_btn != null and not ok_btn.disabled
	await t._shot("homegoals_confirm")
	if could:
		ok_btn.pressed.emit()
	await t._wait(0.6)
	Events.building_upgraded.disconnect(hear)
	_x("Confirm grows the Hearthtree: level 2, the price taken, building_upgraded('home', 2) sent", could and Save.camp_level == 2 and Save.leaves == 37
		and Save.timber == 3 and got.has("home 2"), {"home": Save.camp_level, "leaves": Save.leaves, "timber": Save.timber, "events": got})
	f = win.tab_spec("hearthtree").get("footer", {})
	_x("then the Hearthtree window is back, at its new level", main.hud.card_ring() == ring and main.hud.card_title() == Data.camp_name(true)
		and String(f.get("text", "")) == _w("level_of") % [2, n], {"title": main.hud.card_title(), "footer": _footer_words(f)})
	main.hud.hide_card()
	await t._wait(0.3)
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
	var win = main.hud.windows["target"]
	var tn: int = Data.building_levels("target").size()
	var f: Dictionary = win.spec().get("footer", {})
	var up := _first_button(f)
	_x("the Target window's pinned Upgrade offers level 2 at home 2", String(f.get("text", "")) == _w("level_of") % [1, tn]
		and not (f.get("cost", {}) as Dictionary).is_empty() and String(up.get("label", "")) == _w("upgrade") and bool(up.get("enabled", false)),
		{"footer": _footer_words(f)})
	Save.leaves = 99999
	Save.timber = 9999
	main.stations._upgrade_station("target")
	main.stations._upgrade_station("bench")
	_x("Target 2 at home 2: damage capped at 6", int(Save.stations["target"]) == 2 and Data.stat_cap("damage") == 6, {"cap": Data.stat_cap("damage")})
	_x("Bench 2 at home 2: bows capped at 6", int(Save.stations["bench"]) == 2 and Data.bow_cap() == 6, {"cap": Data.bow_cap()})
	_x("Health uses the home level: capped at 6 at home 2", Data.stat_cap("health") == _caps_of("stat_cap_by_station_level", 2))
	main.stations._upgrade_station("target")
	f = win.spec().get("footer", {})
	up = _first_button(f)
	_x("never above the home: Target level 3 refused at home 2; its footer says so and its Upgrade is off", int(Save.stations["target"]) == 2
		and String(f.get("note", "")) == _w("needs_home") % [Data.camp_name(), 3] and not up.is_empty() and not bool(up.get("enabled", true)),
		{"footer": _footer_words(f)})
	Save.camp_level = 5
	_x("at home 5 the Target and the Bench go to 5, the Well stays at 3", Data.station_max_level("target") == 5 and Data.station_max_level("bench") == 5
		and Data.station_max_level("well") == 3)
	Save.stations["target"] = 4
	Save.stations["bench"] = 5
	_x("Target 4 and Bench 5: caps 9 and 10, the top models reused", Data.stat_cap("damage") == _caps_of("stat_cap_by_station_level", 4)
		and Data.bow_cap() == _caps_of("bow_cap_by_bench_level", 5) and main.stations.model_name("target") == "target_2"
		and main.stations.model_name("bench") == "bow_bench_3", {"target": main.stations.model_name("target"), "bench": main.stations.model_name("bench")})
	Save.stations["target"] = 5
	f = win.spec().get("footer", {})
	_x("the Target at its top: its footer says Max level, no Upgrade", String(f.get("note", "")) == _w("max") and (f.get("buttons", []) as Array).is_empty(),
		{"footer": _footer_words(f)})
	Save.camp_level = 2
	Save.stations["target"] = 1
	Save.stations["bench"] = 1
	Save.leaves = 300
	Save.timber = 0
	main.stations.refresh("all")


# ---------------------------------------------------------------- (e) the Hearthtree tab, Go and Show
func _home_card() -> void:
	var win = main.hud.windows["shop"]
	var ring = main.stations.rings["shop"]
	var goals := Data.home_goals(3)
	var n: int = Data.building_levels("home").size()
	await t._at_ring(ring)
	await t._wait(0.5)
	await t._shot("homegoals_home_card")
	_x("the home's card is open", main.hud.card_ring() == ring and main.hud.card_title() == Data.camp_name(true), {"title": main.hud.card_title()})
	var s: Dictionary = win.spec()
	var rows: Array = s.get("rows", [])
	var first_ok := rows.size() > goals.size()
	for i in mini(goals.size(), rows.size()):
		var g: Dictionary = goals[i]
		var want := String(g["text"]) if bool(g["done"]) else String(g["progress"])
		if String(rows[i].get("text", "")) != want or not bool(rows[i].get("small", false)):
			first_ok = false
	_x("the Hearthtree tab starts with home 3's goals, one line each", first_ok, {"rows": _texts(rows.slice(0, goals.size() + 1))})
	var f: Dictionary = s.get("footer", {})
	var up := _first_button(f)
	var met := goals.filter(func(g): return bool(g["done"])).size()
	var old_rows := rows.filter(_is_old_row)
	_x("no Grow tile and no building tiles: the level is the pinned footer ('Level 2 of %d', 'x of y goals met', Upgrade off while goals are left)" % n,
		old_rows.is_empty() and String(f.get("text", "")) == _w("level_of") % [2, n] and String(f.get("note", "")) == _w("goals_met") % [met, goals.size()]
		and String(up.get("label", "")) == _w("upgrade") and not bool(up.get("enabled", true)), {"footer": _footer_words(f), "old": _texts(old_rows)})
	_x("two tabs now (Hearthtree, Cat); the footer is on the Hearthtree tab only", win.tab_ids() == ["hearthtree", "cat"]
		and _tab_buttons().size() == 2 and _foot_shows() and not win.tab_spec("cat").has("footer"), {"tabs": win.tab_ids()})
	var pressed: bool = t._press(_w("tab_cat"))
	await t._wait(0.4)
	_x("a tap on the Cat tab shows its rows, without the footer", pressed and win.tab == "cat" and not _list_ids().is_empty() and not _foot_shows(), {"ids": _list_ids()})
	pressed = t._press(_home_word())
	await t._wait(0.4)
	_x("back on the Hearthtree tab the footer shows again", pressed and win.tab == "hearthtree" and _foot_shows())
	rows = win.spec().get("rows", [])
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
	for i in mini(goals.size(), rows.size()):
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
	# a Training Target goal: Go opens the Target's window
	var tg := _find_goal(goals, func(g): return String(g["station"]) == "target")
	var grows: Array = win.spec().get("rows", [])
	var gi := _goal_index(grows, tg) if tg >= 0 else -1
	if gi >= 0:
		var act: Callable = grows[gi].get("action", Callable())
		_x("the Training Target goal says Go", String(grows[gi].get("label", "")) == "Go" and act.is_valid(), {"row": grows[gi].get("text", "")})
		act.call()
		var ok2: bool = await t._until(func(): return main.hud.card_ring() == main.stations.rings["target"], 12.0)
		_x("the Training Target goal opens the Training Target's window", ok2 and main.hud.card_title() == "Training Target", {"got": main.hud.card_title()})
		await t._shot("homegoals_target_card")
	else:
		_x("home 3's list has a Training Target goal", false)
	main.hud.hide_card()
	await t._wait(0.3)
	# a stat goal sold here: Show opens the Cat tab at its row; the window stays open
	var hs := _find_goal(goals, func(g): return String(g["station"]) == "home" and String(g["type"]) in ["stat", "all_stats"])
	if hs >= 0:
		await t._at_ring(ring)
		await t._wait(0.3)
		var srows: Array = win.spec().get("rows", [])
		var si := _goal_index(srows, hs)
		var srow: Dictionary = srows[si] if si >= 0 else {}
		_x("a stat goal sold at the Hearthtree says Show", String(srow.get("label", "")) == "Show", {"row": srow.get("text", "")})
		pressed = t._press("Show", _show_count(srows, si))
		await t._wait(0.6)
		var stat_name := String(Data.stat_info(String(goals[hs]["id"]))["name"])
		_x("Show on a stat goal opens the Cat tab with its row and keeps the window open", pressed and main.hud.card_ring() == ring and win.tab == "cat"
			and _list_titles().has(stat_name), {"tab": win.tab, "titles": _list_titles(), "want": stat_name})
		await t._shot("homegoals_show")
	else:
		_x("home 3's list has a stat goal sold at the Hearthtree", false)
	# a towers or defence goal: H6, Go or Show leads to the Workshop, the Bag, a road pad or a placed piece
	var hd := _find_goal(goals, func(g): return String(g["station"]) == "home" and String(g["type"]) in ["towers", "defence"])
	if hd >= 0 and main.hud.card_ring() == ring:
		t._press(_home_word())
		await t._wait(0.4)
		var drows: Array = win.spec().get("rows", [])
		var di := _goal_index(drows, hd)
		var dkind: String = win._goal_defence_kind(goals[hd])
		var target: Dictionary = win._defence_goal_target(dkind, goals[hd])
		var act: Callable = drows[di].get("action", Callable()) if di >= 0 else Callable()
		var label := String(drows[di].get("label", "")) if di >= 0 else ""
		_x("a towers or defence goal has Go (a marker) or Show (build menu or Bag) and a live action",
			act.is_valid() and (label == "Go") == target.has("ring") and label in ["Go", "Show"], {"label": label, "target": target.keys()})
		if act.is_valid():
			act.call()
			await t._wait(0.6)
			if target.has("build"):
				var bmenu = main.hud.windows["build"]
				_x("the goal's Show opens the build menu at %s" % String(target["build"]), main.hud.card_ring() == bmenu and String(bmenu._detail) == String(target["build"]),
					{"detail": String(bmenu._detail)})
			elif target.has("ring"):
				var reached: bool = await t._until(func(): return main.hud.card_ring() == target["ring"], 12.0)
				_x("the goal's Go walks to its marker and opens its card", reached, {"title": main.hud.card_title()})
		await t._shot("homegoals_show_defences")
	else:
		_x("home 3's list has a towers or defence goal sold at the Hearthtree (and the window is open)", false)
	if main.hud.card_ring() != ring:
		await t._at_ring(ring)
		await t._wait(0.4)
		# a building not built yet: Show opens the build menu at that building
	var hb := _find_goal(goals, func(g): return String(g["station"]) == "build")
	if hb >= 0 and main.hud.card_ring() == ring:
		t._press(_home_word())
		await t._wait(0.4)
		var brows: Array = win.spec().get("rows", [])
		var bi := _goal_index(brows, hb)
		pressed = t._press("Show", _show_count(brows, bi))
		await t._wait(0.6)
		var menu = main.hud.windows["build"]
		var bid := String(goals[hb]["id"])
		_x("Show on a 'Build the %s' goal opens the build menu at its detail" % String(Data.building(bid).get("name", bid)),
			pressed and main.hud.card_ring() == menu and String(menu._detail) == bid, {"detail": String(menu._detail), "want": bid})
		await t._shot("homegoals_build_show")
	else:
		_x("home 3's list has a goal for a building not built yet (and the window is open)", false)
	main.hud.hide_card()
	await t._wait(0.3)


# ---------------------------------------------------------------- (g) the confirm at the top levels
## Hearthtree levels 6-8: the per-level tables (the stat caps, the buildings' levels) are shorter than the Hearthtree's,
## so what those levels give must still be worked out cleanly; the confirm opens with its lines (Confirm grey: the goals
## are not met). At the top the footer says "Max level" with no Upgrade.
func _confirm_levels() -> void:
	var win = main.hud.windows["shop"]
	var cf = main.hud.confirm
	var n: int = Data.building_levels("home").size()
	var keep := Save.camp_level
	var bad: Array = []
	var seen: Dictionary = {}
	for lv in range(maxi(n - 3, 1), n):
		Save.camp_level = lv
		var gv: Array = win.gives(lv + 1)
		win.ask_upgrade()
		await t._wait(0.25)
		var cs: Dictionary = cf.spec()
		var lines: Array = (cs.get("rows", []) as Array).slice(0, gv.size()).map(func(r): return String(r.get("text", "")))
		seen[lv + 1] = lines
		if main.hud.card_ring() != cf or gv.is_empty() or lines != _capitalised(gv) or main.hud.card_title() != "%s level %d" % [_home_word(), lv + 1]:
			bad.append(lv + 1)
	_x("the confirm for Hearthtree levels %d-%d opens and lists what each gives" % [maxi(n - 2, 2), n], bad.is_empty(), {"bad": bad, "lines": seen})
	await t._shot("homegoals_confirm_top")
	main.hud.hide_card()
	await t._wait(0.3)
	Save.camp_level = n
	var f: Dictionary = win.upgrade_footer()
	_x("at the top the Hearthtree's footer says Max level, with no Upgrade", String(f.get("text", "")) == _w("level_of") % [n, n]
		and String(f.get("note", "")) == _w("max") and (f.get("buttons", []) as Array).is_empty(), {"footer": _footer_words(f)})
	Save.camp_level = keep


# ---------------------------------------------------------------- (f) the debug endgame start
func _endgame() -> void:
	Save._endgame_seed()
	_x("the endgame start: home 5, Training Target and Bow Bench at 5", Save.camp_level == 5 and int(Save.stations["target"]) == 5
		and int(Save.stations["bench"]) == 5, {"stations": Save.stations})
	_x("the endgame start: the other buildings at their top for home 5", int(Save.stations["well"]) == 3 and int(Save.stations["garden"]) == 3)
	_x("H5: the endgame start: the one-level Market, the pet at 3, the mount at 5, and no Cottage", int(Save.stations["stall"]) == 1 and Data.pet_level() == 3
		and Data.mount_level() == 5 and not Save.stations.has("cottage"), {"stations": Save.stations, "pet": Data.pet_level(), "mount": Data.mount_level()})
	_x("the endgame cat can reach 10 in every stat and bow", Data.stat_cap("damage") >= 10 and Data.stat_cap("range") >= 10 and Data.bow_cap() >= 10,
		{"damage": Data.stat_cap("damage"), "bow": Data.bow_cap()})


# ---------------------------------------------------------------- (h) H5, the owner's Q4 A: the pet goals and the Market
## The Cottage left the camp: Hearthtree levels ask for a built Market and the pet trained (pet_level goals at 2 and 3).
## Unbuilt, the pet goal's Show opens the build menu at the Market; built, its Go walks to the Market, which opens on its
## Pets tab; the goal reads Data.pet_level() and ticks when Train gets there.
func _pet_goals() -> void:
	var keep_stall := int(Save.stations.get("stall", 0))
	var keep_pet := Save.pet_level
	var want_levels: Array = []
	var stall_goals := 0
	var cottage_goals := 0
	var pet_goal: Dictionary = {}
	for lv in range(2, Data.building_levels("home").size() + 1):
		for g: Dictionary in Data.home_goals(lv):
			if String(g["type"]) == "pet_level":
				want_levels.append(int(g.get("level", 0)))
				if pet_goal.is_empty() and int(g.get("level", 0)) == 2:
					pet_goal = g
			if String(g["type"]) == "station" and String(g.get("id", "")) == "stall":
				stall_goals += 1
			if String(g.get("id", "")) == "cottage":
				cottage_goals += 1
	_x("the goals: the pet trained to 2 and to 3, a built Market, and no goal names the Cottage", 2 in want_levels and 3 in want_levels
		and stall_goals >= 1 and cottage_goals == 0, {"pet": want_levels, "stall": stall_goals, "cottage": cottage_goals})
	if pet_goal.is_empty():
		return
	Save.stations["stall"] = 0
	Save.pet_level = 0
	main.stations.refresh()
	var unbuilt: Dictionary = _goal_of("pet_level", 2)
	_x("the Market not built: the pet goal's Show leads to the build menu", String(unbuilt.get("station", "")) == "build", {"goal": unbuilt.get("station", "")})
	Save.stations["stall"] = 1
	main.stations.refresh()
	var built: Dictionary = _goal_of("pet_level", 2)
	_x("the Market built: the pet goal's Go leads to the Market", String(built.get("station", "")) == "stall" and int(built.get("have", Data.pet_level())) == Data.pet_level(),
		{"goal": built.get("station", "")})
	await t._at_ring(main.stations.rings["shop"])
	await t._wait(0.3)
	main.hud.hide_card()
	await t._wait(0.2)
	var win = main.hud.windows["shop"]
	win._goal_go(built)
	var market = main.hud.windows["stall"]
	var ok: bool = await t._until(func(): return main.hud.card_ring() == market.ring() and market.tab == "pets", 12.0)
	_x("the pet goal's Go opens the Market on its Pets tab", ok, {"ring": main.hud.card_ring() == market.ring(), "tab": market.tab})
	main.hud.hide_card()
	Save.pet_level = 2
	_x("trained to level 2, the pet goal ticks (it reads Data.pet_level)", bool(_goal_of("pet_level", 2).get("done", false)) and not bool(_goal_of("pet_level", 3).get("done", true)))
	Save.stations["stall"] = keep_stall
	Save.pet_level = keep_pet
	main.stations.refresh()
	await t._wait(0.2)


## The goal of `type` and `level` from any Hearthtree level's list, {} when none.
func _goal_of(type: String, level: int) -> Dictionary:
	for lv in range(2, Data.building_levels("home").size() + 1):
		for g: Dictionary in Data.home_goals(lv):
			if String(g["type"]) == type and int(g.get("level", 0)) == level:
				return g
	return {}
