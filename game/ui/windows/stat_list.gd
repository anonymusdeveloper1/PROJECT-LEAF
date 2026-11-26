extends RefCounted
## H4: the cat's stat rows, shared by two windows: the Training Target (Damage, Draw speed, Range) and the Hearthtree's
## cat shelf (Health, Move speed, Leaf magnet). Static functions only; the window is passed in (`w`, a
## ui/windows/building_window.gd), because a row needs its tile helper (w._tile) and its rule (w.st._buy_stat).
## Moved from stations.gd (_stat_rows) in H4 Stage 1 with today's looks: a tile per stat with its level bar. What each
## stat does in one short line and its tile's icon (hud.gd draws the icons) are the stat's own "says" and "icon"
## (balance.json stats; before H4 the lists STAT_SAYS and STAT_ICONS here). Stage 2 (P2b) turns them into list rows
## with what the next level gives.
## Used by: ui/windows/target_window.gd, ui/windows/hearthtree_window.gd.
## Uses: Data (stat_info, stat_cap, stat_top, stat_cost), Save.stats, the window's _tile and st._buy_stat / st._name.


## The stat tiles (the Training Target's Damage, Draw speed and Range; the Hearthtree's Health, Move speed and Leaf
## magnet): a bar for the level out of what the station allows now, "Level 3/6", and Buy.
static func rows(w, ids: Array) -> Array:
	var out: Array = []
	for sid in ids:
		var info := Data.stat_info(sid)
		var lv := int(Save.stats[sid])
		var cap := Data.stat_cap(sid)
		var costs: Array = info["cost"]
		var top := Data.stat_top(sid)
		var unit := String(info["unit"])
		var per := float(info["per_level"])
		var now := ""
		match unit:
			"x": now = "+%d%%" % int(round(per * lv * 100.0))
			"m": now = "+%.1fm" % (per * lv)
			"hp": now = "+%d" % int(per * lv)
		var nm := String(info["name"])
		var icon := String(info.get("icon", sid))
		var says := String(info.get("says", ""))
		var bar := [["Level", float(lv) / float(maxi(maxi(cap, lv), 1))]]
		var at_home := String(info["station"]) == "home" or String(info["station"]) == "camp"
		if cap == 0:
			out.append(w._tile(icon, nm, "Upgrade the %s to unlock" % w.st._name(String(info["station"])) if not at_home else "Grow %s to unlock" % Data.camp_name(),
				{}, "", false, Callable(), "Locked"))
		elif lv >= top:
			out.append(w._tile(icon, nm, "%s · now %s" % [says, now], {}, "", false, Callable(), "Max", [["Level", 1.0]]))
		elif lv >= cap:
			var more: String = ("Grow %s for more" % Data.camp_name()) if at_home else ("Upgrade the %s for more" % w.st._name(String(info["station"])))
			out.append(w._tile(icon, nm, "Now %s · %s" % [now, more], {}, "", false, Callable(), "Level %d/%d" % [lv, maxi(cap, lv)], bar))
		elif lv >= costs.size():
			var mc := Data.stat_cost(sid, lv)          # Phase E: mastery, past level 10
			out.append(w._tile(icon, nm, "Mastery: now %s%s" % [now, Data.mats_line(mc)], mc, "Buy", true, w.st._buy_stat.bind(sid),
				"Mastery %d/%d" % [lv - costs.size() + 1, top - costs.size()], bar))
		else:
			out.append(w._tile(icon, nm, ("%s · now %s" % [says, now]) if lv > 0 else says, Data.stat_cost(sid, lv), "Buy", true,
				w.st._buy_stat.bind(sid), "Level %d/%d" % [lv, cap], bar))
	return out
