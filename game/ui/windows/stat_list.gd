extends RefCounted
## H4: the cat's stat rows, shared by two windows: the Training Target (Damage, Draw speed, Range) and the Hearthtree's
## Cat tab (Health, Move speed, Leaf magnet). Static functions only; the window is passed in (`w`, a
## ui/windows/building_window.gd), because a row is made by its list_row() (so its "enabled" already holds the price,
## the rule the marker's "!" reads) and runs its rule (w.st._buy_stat).
## Each stat is one list row (ui/kit/list_row.gd): its icon, its name, a badge, two short lines and one Buy. The
## plan: "each row with its picture, its level, what the next level gives and one button".
##   line 1   what the stat does (balance.json stats.<id>.says)
##   line 2   what the next level gives, in the same form as the total now: "Next: +12% · now +36%" ("Next: +12%" at
##            level 0); on mastery "Mastery 1/2 · Next: +12%"; at the cap "Now +48% · Upgrade the Training Target for
##            more" (the Hearthtree's stats: "Grow the Hearthtree for more"); at the top "Now +144%"; locked "Upgrade
##            the Training Target to unlock"
##   badge    "Level 3/6" ("Mastery 1/2", "Max", "Locked"); Buy only while it can level now. Buy never asks first (the
##            owner's answer, 26 Nov 2026, Q4 a).
## Moved from stations.gd (_stat_rows) in H4 Stage 1; list rows with what the next level gives since Stage 2 (P2b).
## Used by: ui/windows/target_window.gd and ui/windows/hearthtree_window.gd (rows), ui/windows/bow_inspect.gd (now_text).
## Uses: Data (stat_info, stat_cap, stat_top, stat_cost, camp_name, word; balance.json stats), Save.stats, the window's
##       list_row and its rules (w.st._buy_stat, w.st._name).


## The stat rows for `ids`, in that order (see the top of this file). row id = the stat's id.
static func rows(w, ids: Array) -> Array:
	var out: Array = []
	for v in ids:
		var sid := String(v)
		var info := Data.stat_info(sid)
		var lv := int(Save.stats[sid])
		var cap := Data.stat_cap(sid)
		var top := Data.stat_top(sid)
		var costs: Array = info["cost"]
		var nm := String(info["name"])
		var icon := String(info.get("icon", sid))
		var says := String(info.get("says", ""))
		var now := now_text(sid)
		var next := next_text(sid)
		var station := String(info["station"])
		var at_home := station == "home" or station == "camp"
		if cap == 0:
			var why: String = ("Grow %s to unlock" % Data.camp_name()) if at_home else ("Upgrade the %s to unlock" % w.st._name(station))
			out.append(w.list_row(icon, nm, _lines(says, why), {}, "", false, Callable(), "Locked", sid))
		elif lv >= top:
			out.append(w.list_row(icon, nm, _lines(says, "Now %s" % now), {}, "", false, Callable(), "Max", sid))
		elif lv >= cap:
			var more: String = ("Grow %s for more" % Data.camp_name()) if at_home else ("Upgrade the %s for more" % w.st._name(station))
			out.append(w.list_row(icon, nm, _lines(says, "Now %s · %s" % [now, more]), {}, "", false, Callable(),
				"Level %d/%d" % [lv, maxi(cap, lv)], sid))
		elif lv >= costs.size():
			var mastery := "Mastery %d/%d" % [lv - costs.size() + 1, top - costs.size()]   # Phase E: past level 10
			out.append(w.list_row(icon, nm, _lines(says, "%s · %s" % [mastery, _w("stat_next_first") % next]),
				Data.stat_cost(sid, lv), "Buy", true, w.st._buy_stat.bind(sid), mastery, sid))
		else:
			var line := (_w("stat_next_first") % next) if lv == 0 else (_w("stat_next") % [next, now])
			out.append(w.list_row(icon, nm, _lines(says, line), Data.stat_cost(sid, lv), "Buy", true,
				w.st._buy_stat.bind(sid), "Level %d/%d" % [lv, cap], sid))
	return out


## The stats a station trains, in balance.json's order (the Training Target: Damage, Draw speed, Range), so no window
## names its stats in code (house rule 3).
static func ids_at(station: String) -> Array:
	var out: Array = []
	var all: Dictionary = Data.b["stats"]
	for sid in all:
		if String((all[sid] as Dictionary).get("station", "")) == station:
			out.append(String(sid))
	return out


## What the stat's levels give in all now, as today's rows said it: "+36%", "+0.6m", "+3".
static func now_text(sid: String) -> String:
	var info := Data.stat_info(sid)
	return _amount(String(info["unit"]), float(info["per_level"]) * int(Save.stats.get(sid, 0)))


## What one more level gives, in the same form: "+12%", "+0.2m", "+1".
static func next_text(sid: String) -> String:
	var info := Data.stat_info(sid)
	return _amount(String(info["unit"]), float(info["per_level"]))


## An amount of a stat by its unit (balance.json stats.<id>.unit): "x" a share ("+12%"), "m" metres ("+0.2m"), "hp"
## points ("+1").
static func _amount(unit: String, x: float) -> String:
	match unit:
		"x":
			return "+%d%%" % roundi(x * 100.0)
		"m":
			return "+%.1fm" % x
		"hp":
			return "+%d" % int(x)
	return ""


## Line 1 and line 2 of a row (line 2 alone when the stat says nothing).
static func _lines(first: String, second: String) -> String:
	return second if first == "" else first + "\n" + second


static func _w(key: String) -> String:
	return Data.word(key)
