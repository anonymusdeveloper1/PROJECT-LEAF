extends "res://ui/windows/building_window.gd"
## H4: the Hearthtree's window (building "home", marker "shop": the camp's shop counter at the tree home). Moved from
## stations.gd (_card_shop and its helpers) in H4 Stage 1, looking exactly as before: its goal list first (compact
## lines), then shop tiles in sections: Grow, The cat, Buildings, Defences, and Settings (the graphics row stays a
## plain row). Stage 2 (P2a) gives it tabs (Hearthtree, Cat, Defences) and the pinned Upgrade.
## The goals: each goal of the next level on one line, a tick when met, else its progress and a button to where it is
## bought: "Go" walks the cat to that marker and opens its card; "Show" scrolls this card to the tile (a goal sold here).
## Used by: ui/windows/window_list.gd (hud.windows["shop"]), stations.gd (the marker's builder; the old names
##          _card_shop, _grow_rows, _goal_find, _defence_tiles the tests call in Stage 1).
## Uses: Data (home_goals, home_goals_met, building, building_levels, build_price, building_desc, station_open,
##       station_needs_home),
##       Save, stat_list.gd and defences_tab.gd (their shelves), the rules in stations.gd (_grow_camp, _build_station,
##       _level_cost, goal_ring), main.raids (Mend all), Quality (the graphics row).

const StatList := preload("res://ui/windows/stat_list.gd")
const DefencesTab := preload("res://ui/windows/defences_tab.gd")


func _init(owner_hud) -> void:
	super(owner_hud, "home", "shop")


func spec() -> Dictionary:
	return _card_shop()


## The Hearthtree's card (ring "shop"): its goal list first (compact lines), then shop tiles in sections: Grow, The
## cat, Buildings, Defences, and Settings (the graphics row stays a plain row).
func _card_shop() -> Dictionary:
	var title := Data.camp_name(true)
	if Save.ruined.has("home"):
		return _ruin_card("home", title, _anchor("home", 3.2))
	var lv := Save.camp_level
	var rows: Array = []
	if Data.raids_open():
		var cc: Dictionary = main.raids.camp_check()
		if not (cc["items"] as Array).is_empty():
			rows.append(main.raids.camp_row(cc))          # anything broken after a raid: Mend all at the very top
	rows.append_array(_grow_rows())                    # Phase F: its goals, then (G2) the Grow section and its tile
	rows.append_array(_wear_row("home"))
	if not Save.flag("shop_open"):
		rows.append({"text": "Nothing for sale yet", "note": "Defend the camp first: enemies drop golden leaves", "cost": {}, "label": "", "enabled": false, "action": Callable()})
	# the cat
	if Save.flag("home"):
		_add_section(rows, "The cat", StatList.rows(self, ["health", "speed", "magnet"]))
	_add_section(rows, "Buildings", _building_tiles())
	_add_section(rows, "Defences", DefencesTab.rows(self))
	# graphics: Auto, Low, Medium, High (kept apart from the save; see quality.gd)
	rows.append(_section("Settings"))
	rows.append(_cost_row("Graphics: %s" % Quality.label(), "Lower it if the game stutters · Auto picks for this phone",
		{}, "Change", true, Quality.cycle))
	var names: Array = Data.b["home_names"]
	var sub := "Level %d: %s" % [lv, String(names[clampi(lv - 1, 0, names.size() - 1)])]
	if _grow_shown():
		var goals := Data.home_goals(lv + 1)
		var met := goals.filter(func(g): return bool(g["done"])).size()
		sub += " · level %d: %d of %d goals" % [lv + 1, met, goals.size()]
	return {"title": title, "sub": sub, "rows": rows, "anchor": _anchor("home", 3.2)}


## The Buildings shelf: the Training Target and the Bow Shop (once the first mission shows them), then the Wishing
## Well (Hearthtree 3), the Mushroom Cottage and the Market (Hearthtree 2), the Saddlery (8 missions and
## Hearthtree 2). Once the first mission is won, a building that is not open yet shows as a locked tile with what it
## needs. A tile's line is its entry's desc (Data.building_desc: the pet's and the mount's names filled in).
func _building_tiles() -> Array:
	var out: Array = []
	for sid in ["target", "bench"]:
		if Save.flag("shop_" + sid) and int(Save.stations[sid]) == 0:
			var info: Dictionary = Data.building(sid)
			out.append(_tile(_station_icon(sid), String(info["name"]), Data.building_desc(sid), Data.build_price(sid), "Build", true,
				st._build_station.bind(sid), "New"))
	if not Save.flag("shop_open"):
		return out
	# G4: the Saddlery once mission 8 is won (and Hearthtree 2); 23 Nov 2026: the Tailor's Nook at Hearthtree 3
	for sid in ["well", "cottage", "stall", "saddlery", "tailor"]:
		if int(Save.stations.get(sid, 0)) > 0:
			continue
		var vi: Dictionary = Data.building(sid)
		if Data.station_open(sid):
			out.append(_tile(_station_icon(sid), String(vi["name"]), Data.building_desc(sid), Data.build_price(sid), "Build", true,
				st._build_station.bind(sid), "New"))
		elif Data.progress() >= 1:
			out.append(_tile(_station_icon(sid), String(vi["name"]), _station_needs(sid), Data.build_price(sid), "Build", false, Callable(), "Locked"))
	return out


## What a building still waits for: "Needs the Hearthtree at level 2", "Finish 8 Raid Missions first" (its unlock rule's
## home level and missions won).
func _station_needs(sid: String) -> String:
	var bits: Array = []
	var home: int = Data.station_needs_home(sid)
	if Save.camp_level < home:
		bits.append("Needs %s at level %d" % [Data.camp_name(), home])
	var need := int((Data.building(sid).get("unlock", {}) as Dictionary).get("missions_won", 0))
	if Data.progress() < need:
		bits.append("Finish %d Raid Missions first" % need)
	return " · ".join(bits)


# ---------------------------------------------------------------- Phase F: growing the Hearthtree (its goals)
## The Hearthtree's card shows the next level's goals once the first mission is won (the first mission's shop stays
## simple).
func _grow_shown() -> bool:
	var levels: Array = Data.building_levels("home")
	return Save.camp_level < levels.size() and (Data.progress() >= 1 or Save.camp_level > 1)


## The top of the Hearthtree's card: each goal of its next level on one line (a tick when met, else its progress and a
## button to where it is bought), then (G2) the Grow section with its tile: the price and Grow (on only when every goal
## is met and the price affordable: then the Hearthtree's badge shows its "!"). The tile is the last row.
func _grow_rows() -> Array:
	var rows: Array = []
	if not _grow_shown():
		return rows
	var lv := Save.camp_level
	var levels: Array = Data.building_levels("home")
	var goals := Data.home_goals(lv + 1)
	for g in goals:
		rows.append(_goal_row(g))
	var next: Dictionary = levels[lv]
	var cost: Dictionary = st._level_cost(next)
	var met := Data.home_goals_met(lv + 1)
	var fires: Array = Data.b["fire_hp_by_camp_level"]
	var fire_hp := int(fires[mini(lv + 1, fires.size() - 1)])
	var towers: Array = Data.defence_info("tower")["max_by_camp_level"]
	var names: Array = Data.b["home_names"]
	var says := "%s · campfire %d · %d towers" % [String(names[mini(lv, names.size() - 1)]), fire_hp,
		int(towers[mini(lv + 1, towers.size() - 1)])]
	if lv + 1 <= 5:                                     # the Training Target and the Bow Shop stop at 5
		says += " · buildings lv %d" % (lv + 1)
	var left := goals.filter(func(g): return not bool(g["done"])).size()
	var note := says + Data.mats_line(cost)
	if not met:
		if left > 0:
			note = says                                 # the tile's Goals bar shows how many are met
		elif bool(next.get("needs_burrows", false)) and not Data.burrows_open():
			note = "After the raids: the Gloomwood must open first"
		else:
			note = "Beat level %d of %s first" % [int(next.get("needs_depth", 0)), String(Data.burrow_list()[0]["name"])]
	rows.append(_section("Grow"))
	var row := _tile("grow", "%s level %d" % [_camp_word(), lv + 1], note, cost, "Grow", met, st._grow_camp,
		"Level %d/%d" % [lv, levels.size()], [["Goals", float(goals.size() - left) / float(maxi(goals.size(), 1)),
		"%d/%d" % [goals.size() - left, goals.size()]]])
	row["pulse"] = bool(row["enabled"])
	rows.append(row)
	return rows


## One goal on the Hearthtree's card: "Damage 4" with a tick when met, else "Damage 3/4" and Go (the cat walks to the
## card that sells it) or Show (it is sold further down this card). `small`/`done` make it a compact line (hud.gd).
func _goal_row(g: Dictionary) -> Dictionary:
	var done := bool(g["done"])
	var row := {"text": String(g["text"]) if done else String(g["progress"]), "note": "", "cost": {}, "label": "",
		"enabled": false, "action": Callable(), "small": true, "done": done, "goal": g}
	if not done:
		var r = st.goal_ring(String(g["station"]))
		if r != null:
			row["label"] = "Show" if r == st.rings["shop"] else "Go"
			row["enabled"] = true
			row["action"] = _goal_go.bind(g)
	return row


## A tap on a goal: its card opens, and the cat walks there first if it is out of reach (as a tap on its marker does).
## A goal sold on the card already open (the Hearthtree's own stats, buildings, towers, defences) scrolls the card to
## its tile.
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


## The title of the tile on the Hearthtree's card that sells a goal (hud.scroll_card_to finds the first row or tile
## holding these words).
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
