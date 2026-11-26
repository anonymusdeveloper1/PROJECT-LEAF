extends "res://ui/windows/building_window.gd"
## H4: the Hearthtree's window (building "home", marker "shop": the camp's shop counter at the tree home), with tabs at
## the top (the owner's answers, 26 Nov 2026, Q8 (a)): a tab shows once it has something, with one tab there is no tab
## bar, and the window always opens on the Hearthtree tab.
##   Hearthtree   Mend all (after a raid), Patch it up and "Nothing for sale yet" at the top (Q6), then the next level's
##                goals, ticked or not, one line each (once the first Raid Mission is won), and the Graphics row at the
##                bottom (Q6: nothing removed). Its level and Upgrade are the pinned footer: "Level 2 of 8", what is still
##                missing ("3 of 7 goals met", or a gate) and the price; Upgrade is on once every goal is met and opens
##                the confirm window, which lists everything the next level gives (gives) and grows it (Confirm).
##   Cat          once the cat's own upgrades are sold (flag "home", the first mission's last wave): Health, Move speed
##                and Leaf magnet (stat_list.gd), each with its level, what the next level gives and its Buy.
##   Defences     once the first defence opens (or a piece is broken): the whole old Defences shelf (defences_tab.gd).
## A tab gets the small "!" dot while its rows hold something that can be bought now (the owner's yes, 26 Nov 2026);
## the Hearthtree tab also while its Upgrade can be paid. The building tiles left for the build menu
## (build_menu_window.gd, the build icon next to the Bag).
## The goals: a goal sold elsewhere has "Go" (the cat walks to that marker and its card opens); a goal sold here has
## "Show" (the Cat or Defences tab opens and scrolls to its row); a goal for a building not built yet (or for the bows
## and the Training Target's stats before their building) has "Show", which opens the build menu at that building.
## While the Hearthtree is in ruins the whole window is its ruin card (no tabs, no footer).
## Used by: ui/windows/window_list.gd (hud.windows["shop"]), stations.gd (the marker's builder and "!"; its old names
##          _card_shop, _grow_rows, _goal_find and _defence_tiles hand on spec, _grow_rows, _goal_find and the
##          Defences rows until H4 Stage 3), the tests.
## Uses: Data (home_goals, home_goals_met, home_price, home_can_grow, building, buildings, menu_buildings,
##       building_levels, station_needs_home, unlock_missing, word, stat_info, defence_info), Save, stat_list.gd and
##       defences_tab.gd (their tabs' rows), the confirm window (hud.confirm), the build menu (hud.windows["build"]),
##       the rules in stations.gd (_grow_camp, goal_ring), main.raids (Mend all), Quality (the graphics row).

const StatList := preload("res://ui/windows/stat_list.gd")
const DefencesTab := preload("res://ui/windows/defences_tab.gd")

var tab := "hearthtree"                 # the tab showing: "hearthtree", "cat" or "defences"


func _init(owner_hud) -> void:
	super(owner_hud, "home", "shop")


func spec() -> Dictionary:
	return tab_spec(tab)


## A visit starts: the window always opens on the Hearthtree tab (Q8 (a)).
func card_opened() -> void:
	tab = "hearthtree"


## A tap on a tab: that tab shows, from its top.
func select(t: String) -> void:
	tab = t
	if hud != null and hud.card_ring() == ring() and ring() != null:
		if hud._card_scroll != null:
			hud._card_scroll.scroll_vertical = 0
		hud.refresh_card()


## The tabs that show now, in their order (see the top of this file).
func tab_ids() -> Array:
	var out: Array = ["hearthtree"]
	if Save.flag("home"):
		out.append("cat")
	if DefencesTab.shown(self):
		out.append("defences")
	return out


## The card as if tab `t` were selected (nothing changes): its title and line, the tab bar (only with two tabs or
## more), the tab's rows, and on the Hearthtree tab its pinned Upgrade. A tab that does not show now falls back to the
## Hearthtree tab.
func tab_spec(t: String) -> Dictionary:
	var title := Data.camp_name(true)
	var anchor := _anchor("home", 3.2)
	if Save.ruined.has("home"):
		return _ruin_card("home", title, anchor)
	var ids := tab_ids()
	var showing := t if ids.has(t) else "hearthtree"
	var foot := upgrade_footer()
	var rows: Array = []
	var tabs: Array = []
	for tid: String in ids:
		var tab_rows := _tab_rows(tid)
		if tid == showing:
			rows = tab_rows
		if ids.size() > 1:
			tabs.append({"id": tid, "text": _tab_text(tid), "selected": tid == showing, "enabled": true,
				"action": select.bind(tid), "dot": _any_lights(tab_rows) or (tid == "hearthtree" and bool(foot.get("pulse", false)))})
	var s := {"title": title, "sub": _sub(), "rows": rows, "anchor": anchor}
	if not tabs.is_empty():
		s["tabs"] = tabs
		s["tabs_at"] = "top"
	if showing == "hearthtree" and not foot.is_empty():
		s["footer"] = foot
	return s


## The marker's "!": a row of any tab that can be bought now (whichever tab is selected), or the Hearthtree's Upgrade
## when it can be paid. In ruins: the ruin card's Repair, as on every building.
func pulse() -> bool:
	if Save.ruined.has("home"):
		return super.pulse()
	for tid: String in tab_ids():
		if _any_lights(_tab_rows(tid)):
			return true
	return bool(upgrade_footer().get("pulse", false))


## A tab's rows (no tab bar, no footer).
func _tab_rows(t: String) -> Array:
	match t:
		"cat":
			return StatList.rows(self, _home_stats())
		"defences":
			return DefencesTab.rows(self)
	return _home_rows()


## The Hearthtree tab's rows: Mend all, Patch it up and "Nothing for sale yet" at the top (Q6), the goals, then the
## Graphics row at the bottom (the same setting as the gear's Settings window; kept, Q6).
func _home_rows() -> Array:
	var rows: Array = []
	if Data.raids_open():
		var cc: Dictionary = main.raids.camp_check()
		if not (cc["items"] as Array).is_empty():
			rows.append(main.raids.camp_row(cc))          # anything broken after a raid: Mend all at the very top
	rows.append_array(as_list(_wear_row("home")))
	if not Save.flag("shop_open"):
		rows.append({"text": "Nothing for sale yet", "note": "Defend the camp first: enemies drop golden leaves", "cost": {}, "label": "", "enabled": false, "action": Callable()})
	rows.append_array(_grow_rows())                    # Phase F: the next level's goals
	# graphics: Auto, Low, Medium, High (kept apart from the save; see quality.gd)
	rows.append(_section("Settings"))
	rows.append(_cost_row("Graphics: %s" % Quality.label(), "Lower it if the game stutters · Auto picks for this phone",
		{}, "Change", true, Quality.cycle))
	return rows


## The stats bought at the Hearthtree (their station is "home": Health, Move speed and Leaf magnet), in data order.
func _home_stats() -> Array:
	var out: Array = []
	for sid: String in Data.b["stats"]:
		var where := String(Data.stat_info(sid).get("station", ""))
		if where == "home" or where == "camp":
			out.append(sid)
	return out


func _tab_text(t: String) -> String:
	match t:
		"cat":
			return _w("tab_cat")
		"defences":
			return _w("tab_defences")
	return _camp_word()


## Some row lights the "!" (building_window.gd _lights: on, not quiet, new or priced).
func _any_lights(rows: Array) -> bool:
	for r in rows:
		if _lights(r):
			return true
	return false


## The header line: "Level 2: Hut · level 3: 4 of 13 goals" (the goals' part once they show).
func _sub() -> String:
	var lv := Save.camp_level
	var names: Array = Data.b["home_names"]
	var sub := "Level %d: %s" % [lv, String(names[clampi(lv - 1, 0, names.size() - 1)])]
	if _grow_shown():
		var goals := Data.home_goals(lv + 1)
		var met := goals.filter(func(g): return bool(g["done"])).size()
		sub += " · level %d: %d of %d goals" % [lv + 1, met, goals.size()]
	return sub


# ---------------------------------------------------------------- the pinned Upgrade and the confirm
## The Hearthtree tab's footer (the shared pinned Upgrade, its own rule): "Level 2 of 8", the price of the next level
## and Upgrade, on once every goal of the next level is met (the price can be short: the confirm then shows it red and
## keeps Confirm grey, Q2 (a)); its note says what is still missing ("3 of 7 goals met", a gate) and is empty when it
## can grow. Its pulse (the marker's "!") only when it can grow and be paid. At the top: "Max level", no button. Before
## the first Raid Mission is won the goals and the footer do not show ({}).
func upgrade_footer() -> Dictionary:
	var lv := Save.camp_level
	var n: int = Data.building_levels("home").size()
	var text := _w("level_of") % [lv, n]
	if lv >= n:
		return {"text": text, "note": _w("max"), "cost": {}, "buttons": [], "pulse": false}
	if not _grow_shown():
		return {}
	var why := _upgrade_reason()
	return {"text": text, "note": why, "cost": Data.home_price(lv + 1),
		"buttons": [{"label": _w("upgrade"), "tone": "green", "enabled": why == "", "action": ask_upgrade}],
		"pulse": Data.home_can_grow()}


## Why the Hearthtree can't grow now, leaving the price aside (the confirm checks that itself): "" when every goal of
## the next level is met, else what is left: the goals ("3 of 7 goals met"), or once they are all met, the older gates
## of levels 6-8 (the Gloomwood must be open, a Gloomwood level beaten). "Max level" at the top.
func _upgrade_reason() -> String:
	var lv := Save.camp_level
	var levels: Array = Data.building_levels("home")
	if lv >= levels.size():
		return _w("max")
	if Data.home_goals_met(lv + 1):
		return ""
	var goals := Data.home_goals(lv + 1)
	var met := goals.filter(func(g): return bool(g["done"])).size()
	if met < goals.size():
		return _w("goals_met") % [met, goals.size()]
	var next: Dictionary = levels[lv]
	if bool(next.get("needs_burrows", false)) and not Data.burrows_open():
		return "After the raids: the Gloomwood must open first"
	var depth := int(next.get("needs_depth", 0))
	var bd: Dictionary = Data.burrow_list()[0]
	if Data.burrow_depth(String(bd["id"])) < depth:
		return "Beat level %d of %s first" % [depth, String(bd["name"])]
	return _w("needs_missions") % int(next.get("needs_missions", 0))


## Upgrade's tap: the confirm window lists what the next level gives and its price; Confirm grows the Hearthtree
## (stations._grow_camp), and Confirm or Cancel come back to this window (Q3 (a)).
func ask_upgrade() -> void:
	var lv := Save.camp_level
	if lv >= Data.building_levels("home").size():
		return
	hud.confirm.ask({"title": "%s level %d" % [_camp_word(), lv + 1], "lines": gives(lv + 1),
		"cost": Data.home_price(lv + 1), "on_confirm": st._grow_camp, "back": reopen, "reason": _upgrade_reason})


## Everything Hearthtree `level` gives, one line each, worked out from the data (each line only when it applies):
## its new look's name, the campfire's health, a bigger firelight, how many Acorn Towers, the buildings' level cap, the
## cat's upgrade cap, the defences' level cap, and the buildings it opens. Every per-level table is read clamped (some
## have fewer entries than the Hearthtree has levels, so their line stops when the table does).
func gives(level: int) -> Array:
	var out: Array = []
	out.append(_w("home_look") % String(_at(Data.b["home_names"], level - 1)))
	out.append(_w("home_fire") % int(_at(Data.b["fire_hp_by_camp_level"], level)))
	var light: Array = Data.b["light_radius_by_camp_level"]
	if float(_at(light, level)) > float(_at(light, level - 1)):
		out.append(_w("home_light"))
	var tower := Data.defence_info("tower")
	var towers: Array = tower.get("max_by_camp_level", [])
	if int(_at(towers, level)) > int(_at(towers, level - 1)):
		out.append(_w("home_towers") % [int(_at(towers, level)), String(tower["name"]) + "s"])
	for e: Dictionary in Data.buildings():
		if String(e.get("id", "")) != id and (e.get("levels", []) as Array).size() >= level:
			out.append(_w("home_buildings") % level)
			break
	var caps: Array = Data.b["stat_cap_by_station_level"]
	if int(_at(caps, level)) > int(_at(caps, level - 1)):
		out.append(_w("home_stats") % int(_at(caps, level)))
	if level <= DefencesTab.top_shown():
		out.append(_w("home_defences") % level)
	var opens: Array = []
	for e: Dictionary in Data.menu_buildings():
		var bid := String(e.get("id", ""))
		if Data.station_needs_home(bid) == level and _waits_only_for_home(e.get("unlock", {})):
			opens.append(String(e.get("name", bid)))
	if not opens.is_empty():
		out.append(_w("home_opens") % ", ".join(opens))
	return out


## A building's unlock rule waits for nothing but the Hearthtree's level (its other parts, such as Raid Missions won,
## already hold), so growing to that level really opens it: the Saddlery is not named while its 8 missions are not won.
func _waits_only_for_home(rule: Variant) -> bool:
	if not (rule is Dictionary):
		return false
	for m in Data.unlock_missing(rule):
		var part: Dictionary = m
		if String(part.get("type", "")) != "building" or String(part.get("id", "")) != id:
			return false
	return true


## t[i], with i clamped to the table (a table shorter than the Hearthtree's levels repeats its last entry); 0 when empty.
static func _at(t: Array, i: int) -> Variant:
	if t.is_empty():
		return 0
	return t[clampi(i, 0, t.size() - 1)]


# ---------------------------------------------------------------- Phase F: growing the Hearthtree (its goals)
## The Hearthtree tab shows the next level's goals once the first mission is won (the first mission's shop stays
## simple).
func _grow_shown() -> bool:
	var levels: Array = Data.building_levels("home")
	return Save.camp_level < levels.size() and (Data.progress() >= 1 or Save.camp_level > 1)


## The goals of the next level, one line each (a tick when met, else its progress and a button to where it is bought).
## The old name: before H4 Stage 2 the Grow section and tile followed them; the level and Upgrade are the footer now.
func _grow_rows() -> Array:
	var rows: Array = []
	if not _grow_shown():
		return rows
	for g in Data.home_goals(Save.camp_level + 1):
		rows.append(_goal_row(g))
	return rows


## One goal: "Damage 4" with a tick when met, else "Damage 3/4" and its button: "Show" opens the build menu at the
## building (a goal whose station is "build", data.gd _goal) or this window's tab that sells it (station "home"); "Go"
## walks the cat to the marker that sells it. `small`/`done` make it a compact line (card.gd).
func _goal_row(g: Dictionary) -> Dictionary:
	var done := bool(g["done"])
	var row := {"text": String(g["text"]) if done else String(g["progress"]), "note": "", "cost": {}, "label": "",
		"enabled": false, "action": Callable(), "small": true, "done": done, "goal": g}
	if done:
		return row
	var station := String(g["station"])
	if station == "build":
		var bid := _menu_id(g)
		if bid != "" and hud != null and hud.windows.has("build"):
			row["label"] = "Show"
			row["enabled"] = true
			row["action"] = Callable(hud.windows["build"], "open_at").bind(bid)
		return row
	var r = st.goal_ring(station)
	if r == null:
		return row
	row["label"] = "Show" if r == ring() else "Go"
	row["enabled"] = true
	row["action"] = show_goal.bind(g) if r == ring() else _goal_go.bind(g)
	return row


## The building a "build" goal shows in the build menu: the goal's own building, the Bow Shop for a bow goal, the
## stat's building for a stat goal (the Training Target).
func _menu_id(g: Dictionary) -> String:
	var gid := String(g.get("id", ""))
	match String(g.get("type", "")):
		"station":
			return gid
		"bow", "bow_any", "bow_owned":
			return "bench"                                # the bows are sold at the Bow Shop
		"stat", "all_stats":
			if Data.b["stats"].has(gid):
				return String(Data.stat_info(gid).get("station", ""))
	return ""


## Show on a goal sold here: its tab opens (the Cat tab for a stat, the Defences tab for towers and defence levels) and
## scrolls to its row, which glows a moment; the window stays open.
func show_goal(g: Dictionary) -> void:
	match String(g.get("type", "")):
		"stat", "all_stats":
			select("cat")
		"towers", "defence":
			select("defences")
	hud.scroll_card_to(_goal_find(g))


## A tap on a goal's Go: its card opens, and the cat walks there first if it is out of reach (as a tap on its marker
## does). A goal sold on the card already open scrolls the card to its row.
func _goal_go(g: Dictionary) -> void:
	var r = st.goal_ring(String(g.get("station", "")))
	if r == null:
		return
	if r == main.hud.card_ring():
		main.hud.scroll_card_to(_goal_find(g))
		return
	main.hud.hide_card()
	if main.interact != null:
		main.interact.use(r)
	else:
		main.open_ring(r)


## The title of the row that sells a goal (hud.scroll_card_to finds the first row or tile holding these words): a
## stat's name (the Cat tab), a tower or defence row's title (the Defences tab), a building's name.
func _goal_find(g: Dictionary) -> String:
	var gid := String(g.get("id", ""))
	match String(g.get("type", "")):
		"stat", "all_stats":
			return String(Data.stat_info(gid)["name"]) if Data.b["stats"].has(gid) else ""
		"towers":
			var tl: int = main.defences.level("tower")
			if tl < int(g.get("level", 1)):
				return DefencesTab._def_level_title("tower", tl + 1)
			return String(Data.defence_info("tower")["name"])
		"defence":
			if not Data.b["defences"].has(gid):
				return ""
			return DefencesTab._def_level_title(gid, main.defences.level(gid) + 1)
		"station":
			return String(Data.building(gid).get("name", gid))
	return ""
