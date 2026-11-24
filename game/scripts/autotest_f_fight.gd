extends Node
## Phase F, the missions (--fightf), run from autotest.gd (`-- --autotest --fresh --fightf`). Each check logs
## "EXPECT PASS <what>" or "EXPECT FAIL <what>" through autotest.gd's _expect. Light: most checks plan waves without
## spawning anything (fight.plan_wave, plan_queue, wave_roads); a few short live waves cover the rest. Phase G1 (wave
## limits, swaps, timber per wave, the rebuild for leaves) and Phase G1b (waves made of squads) are checked here too.
##   _patterns       mission 7 planned 40 times: the shares of surround, pincer and rush roughly right, every road gets
##                   enemies in a surround, a pincer's two roads far apart, a rush from the mission's own woods and
##                   faster with its count kept (roads.rush_count, 1.0 since G1), the elites and their squads down a
##                   flank road, the boss wave a surround
##   _teach_roads    mission 1: chapter 1 one road, chapter 2 its own and the one beside it, chapter 3 all four
##   _no_easy_waves  mission 2's waves each at least min_wave_ratio of the one before, each within its count (G1b: whole
##                   squads, count - 2 to count + 3); no swaps after a chapter break or for the boss wave; a forced dip
##                   in mission 14 swaps weak squads for stronger ones within the count, the tank share and the rules
##   _tank_share     (G1) mission 9 planned 30 times: no wave's tank weight over its share, its ordinary enemies within
##                   the mission's count for the wave (G1b: - 2 to + 3), its elites and boss all there
##   _squad_plans    (G1b) missions 2, 9 and 14 planned 30 times each: every enemy in a squad of its chapter's list (the
##                   elites' and the boss's squads: their leader and light ones of the chapter, or the mission's
##                   boss_escort), a squad's members side by side and down one road, at least min_types squad types
##                   from mission mixed_from (as many as the chapter lists), and from mission share_from no kind over
##                   max_kind_share: mission 14 mostly within it; mission 9 (Thornlings in every squad of its first
##                   chapters: the rule's fallback) never far over, and lower than the same waves without the rule
##   _elite_boss     (G1b) the elites lead their own squads (mission 1's Chief with his Chief's Band, mission 2's Boars
##                   with light ones); mission 6's boss wave: Mossback with a Brute Wall and a Boar Raid from its woods
##   _gate           a mission that is not unlocked does not start (only once Data.mission_unlocked exists)
##   _live_wave      mission 1 for real: wave 1 down one road, a Golden Grub alive does not hold the wave up, the quick
##                   and intact pay and the wave's timber, the breather's preview of the next wave, the pay for going
##                   on early
##   _live_limits    (G1) mission 9 for real (skip_gate), its queue swapped for tanks then Thornlings and spawned as fast
##                   as the field lets it: never more than the group's max_alive on the field nor tanks_at_once tank
##                   weight, Thornlings come while the tanks wait, a tank comes once one falls; the Last Stand with too
##                   little timber: rebuild_cost() is leaves (the banner says so) and the fire is rebuilt for them; the
##                   wave held pays its timber (x the pay scale)
##   _fall_gain      (21 Nov 2026) a camp fall takes raid.leaves_share of the leaves gained in that chapter only: 1000
##                   leaves saved before mission 1 are safe; the chapter's gain (a pickup, wave pay; a spend does not
##                   lower it) is kept through a save, a reload and the run resumed; the banner shows the real amount;
##                   the next try counts from 0; a chapter break's chest and the break's own leaves are not the next
##                   chapter's; never more than the cat holds
##   _live_squad     (G1b) mission 9 for real, its queue a Choir: it comes out all at once near one spawn point; on the
##                   march its light members keep within about 3 m of their spot by the leader and never run ahead of
##                   it, its support stays behind the leader; then the leader falls and the rest carry on alone
##   _first_win      (G1b fix) mission 1's first win pays its first barricades in leaves (free_pieces x piece), not
##                   pieces in the bag, and says so
##   _gloom          the Gloom over the woods fades a step per mission won

const EnemyScript := preload("res://scripts/enemy.gd")

var t                     # autotest.gd (its helpers: _wait, _shot, _expect, _until, _log, _reset_fight)
var main


func run() -> bool:
	main.player.invincible = true
	await t._wait(0.5)
	_patterns()
	_teach_roads()
	_no_easy_waves()
	_tank_share()
	_squad_plans()
	_elite_boss()
	main.fight.mission = -1
	await _gate()
	await _live_wave()
	await _manual_progress()
	await _live_limits()
	await _fall_gain()
	await _live_squad()
	await _first_win()
	await _gloom()
	return true


func _x(what: String, ok: bool, extra := {}) -> bool:
	return t._expect(what, ok, extra)


## The fight set up to plan mission i's waves, nothing started.
func _as_mission(i: int):
	var f = main.fight
	f.mode = "mission"
	f.raid = {}
	f.mission = i
	return f


## The foes that hold a wave up (the bonus runners left out).
func _wave_foes() -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("foes"):
		if not e.is_in_group("bonus") and not e.dead:
			out.append(e)
	return out


## Phase G1: the wave_limits group of mission number num (1-based), straight from the data ({} when none).
func _group(num: int) -> Dictionary:
	var wl: Dictionary = Data.b["mission"].get("wave_limits", {})
	var pick: Dictionary = {}
	for g in wl.get("groups", []):
		if int(g["to_mission"]) >= num and (pick.is_empty() or int(g["to_mission"]) < int(pick["to_mission"])):
			pick = g
	return pick


## Phase G1: a kind's tank weight, straight from the data (mission.wave_limits.tank_weight; 0 for the others).
func _tw(kind: String) -> float:
	var wl: Dictionary = Data.b["mission"].get("wave_limits", {})
	var tw: Dictionary = wl.get("tank_weight", {})
	return float(tw.get(kind, 0.0))


## The tank weight of the wave's foes on the field now (a wave's boss never counts).
func _field_tank() -> float:
	var s := 0.0
	for e in _wave_foes():
		if not e.has_meta("wave_boss"):
			s += _tw(String(e.id))
	return s


## How many tanks still wait in the fight's queue.
func _tanks_queued(f) -> int:
	var n := 0
	for k in f._queue:
		if _tw(String(k)) > 0.0:
			n += 1
	return n


## The ordinary enemies of a planned wave (plan_queue's info tag "").
func _ordinary(q: Dictionary) -> int:
	var n := 0
	for qi in q["info"]:
		if (qi as Array).size() < 3 or String(qi[2]) == "":
			n += 1
	return n


## The ordinary enemies wave w should have: the mission's `count` for it (the boss wave x boss_adds), x the plan's count.
func _planned_count(f, w: int, p: Dictionary) -> int:
	var cnt: Array = f.info()["count"]
	var tt := float(w - 1) / float(maxi(1, f.waves() - 1))
	var n := int(round(lerpf(float(cnt[0]), float(cnt[1]), tt)))
	if w == f.waves():
		n = int(round(n * float(f.info().get("boss_adds", Data.b["mission"].get("boss_adds", 0.6)))))
	return int(round(n * float(p.get("count", 1.0))))


## The elites (an elite wave) or the boss enemies (the last wave) wave w should have.
func _planned_specials(f, w: int) -> int:
	var n := 0
	if w == f.waves():
		for pair in f.info().get("boss", []):
			n += int(pair[1])
	elif w % f.chapter_waves() == 0:
		var c: int = f.chapter_of(w)
		var ebc: Array = f.info().get("elite_by_chapter", [])
		var times := int(ebc[c]) if c < ebc.size() else c + 1
		for pair in f.info().get("elite", []):
			n += int(pair[1]) * times
	return n


# ---------------------------------------------------------------- the roads
func _patterns() -> void:
	var f = _as_mission(6)                                  # mission 7, the Moth Swarm
	var fav := int(Data.mission(6)["lanes"][0])
	var rc: Dictionary = Data.b["mission"]["roads"]
	var order: Array = f._road_order()
	var counts := {"surround": 0, "pincer": 0, "rush": 0}
	var bad: Array = []
	var n_plans := 40
	for k in n_plans:
		var w: int = 1 + k % (f.waves() - 1)                # every wave but the boss's
		var p: Dictionary = f.plan_wave(w)
		var pat := String(p["pattern"])
		counts[pat] = int(counts.get(pat, 0)) + 1
		var rs: Array = p["roads"]
		var flank := int(p["flank"])
		match pat:
			"surround":
				var seen := {}
				var per := {}
				for r in f.wave_roads(p, 12):
					seen[int(r)] = true
					per[int(r)] = int(per.get(int(r), 0)) + 1
				var fav_most := true
				for r in per:
					if int(per[r]) > int(per.get(fav, 0)):
						fav_most = false
				if seen.size() != 4 or not fav_most:
					bad.append([w, pat, "roads", per])
				if flank == fav:
					bad.append([w, pat, "flank on the favoured road"])
			"pincer":
				if rs.size() != 2 or absi(order.find(int(rs[0])) - order.find(int(rs[1]))) < 2:
					bad.append([w, pat, "not far apart", rs])
				if rs.has(flank):
					bad.append([w, pat, "flank in the pincer", flank])
			"rush":
				# Phase G1: faster, and its count is roads.rush_count (1.0: the same number of enemies)
				if rs != [fav] or float(p["speed"]) <= 1.0 or absf(float(p["count"]) - float(rc.get("rush_count", 1.0))) > 0.001:
					bad.append([w, pat, rs, p["speed"], p["count"]])
				if flank == fav:
					bad.append([w, pat, "flank on the rush road"])
			_:
				bad.append([w, "unknown pattern", pat])
	var sh := {}
	for k in counts:
		sh[k] = snappedf(float(counts[k]) / n_plans, 0.01)
	_x("raid 7: the patterns' shares roughly as set (surround %.2f, pincer %.2f, rush %.2f)" % [
		float(rc["surround"]), float(rc["pincer"]), float(rc["rush"])],
		float(sh["surround"]) >= 0.35 and float(sh["surround"]) <= 0.9 and int(counts["pincer"]) >= 1 and float(sh["pincer"]) <= 0.45
		and int(counts["rush"]) >= 1 and float(sh["rush"]) <= 0.4, {"shares": sh})
	_x("raid 7: surrounds use all four roads (the favoured one most), pincers two far apart, rushes its own woods (faster, the same count)",
		bad.is_empty(), {"bad": bad.slice(0, 8)})
	# an elite wave: the elites (G1b: and their squads) come down the flank road
	var pe: Dictionary = f.plan_wave(5)
	var qe: Dictionary = f.plan_queue(5, pe, 0.0)
	var elite_sq := {}                                      # the squads the elites lead
	var off_flank: Array = []
	var n_elite := 0
	for j in (qe["info"] as Array).size():
		var qi: Array = qe["info"][j]
		if String(qi[2]) == "elite":
			n_elite += 1
			if qi.size() > 3:
				elite_sq[int(qi[3])] = true
	for j in (qe["info"] as Array).size():
		var qi: Array = qe["info"][j]
		if (String(qi[2]) == "elite" or (qi.size() > 3 and elite_sq.has(int(qi[3])))) and int(qi[0]) != int(pe["flank"]):
			off_flank.append([j, qe["kinds"][j], qi[0]])
	_x("an elite wave's elites and their squads come down the flank road", n_elite > 0 and off_flank.is_empty(),
		{"pattern": pe["pattern"], "roads": pe["roads"], "flank": pe["flank"], "elites": n_elite, "off_flank": off_flank})
	var pb: Dictionary = f.plan_wave(f.waves())
	_x("the boss wave comes from every road", String(pb["pattern"]) == "surround" and (pb["roads"] as Array).size() == 4, {"plan": pb})
	t._log("fightf patterns", {"counts": counts})


func _teach_roads() -> void:
	var f = _as_mission(int(Data.b["mission"]["roads"].get("teach_mission", 0)))
	var fav := int(f.info()["lanes"][0])
	var order: Array = f._road_order()
	var cw: int = f.chapter_waves()
	var bad1: Array = []
	var bad2: Array = []
	var used2 := {}
	var bad3: Array = []
	for w in range(1, f.waves() + 1):
		var p: Dictionary = f.plan_wave(w)
		var q: Dictionary = f.plan_queue(w, p, 0.0)
		var rs: Array = p["roads"]
		var c: int = f.chapter_of(w)
		if c == 0:
			if rs != [fav]:
				bad1.append([w, rs])
			for qi in q["info"]:
				if int(qi[0]) != fav:
					bad1.append([w, int(qi[0])])
		elif c == 1:
			if rs.size() != 2 or not rs.has(fav) or absi(order.find(int(rs[0])) - order.find(int(rs[1]))) != 1:
				bad2.append([w, rs])
			for qi in q["info"]:
				used2[int(qi[0])] = true
				if not rs.has(int(qi[0])):
					bad2.append([w, int(qi[0])])
		elif rs.size() != 4:
			bad3.append([w, rs])
	_x("raid 1, chapter 1: every enemy comes down one road, its own woods", bad1.is_empty(), {"bad": bad1.slice(0, 8), "fav": fav})
	_x("raid 1, chapter 2: two roads side by side, both used", bad2.is_empty() and used2.size() == 2, {"bad": bad2.slice(0, 8), "used": used2.keys()})
	_x("raid 1, chapter 3: all four roads", bad3.is_empty(), {"bad": bad3.slice(0, 8)})


# ---------------------------------------------------------------- no easy waves
func _no_easy_waves() -> void:
	var f = _as_mission(1)                                  # mission 2, the Bramble Pack (pool_first, elite_by_chapter)
	var ratio := float(Data.b["mission"].get("min_wave_ratio", 0.85))
	var prev := 0.0
	var bad: Array = []
	var bad_n: Array = []
	var rows: Array = []
	for w in range(1, f.waves() + 1):
		var p: Dictionary = f.plan_wave(w)
		var q: Dictionary = f.plan_queue(w, p, prev)
		var hp := float(q["hp"])
		var n: int = (q["kinds"] as Array).size()
		var excused: bool = (w - 1) % f.chapter_waves() == 0 or w == f.waves()
		if not excused and hp < prev * ratio - 0.01:
			bad.append([w, snappedf(hp, 0.1), snappedf(prev, 0.1)])
		var want_n := _planned_count(f, w, p)
		if _ordinary(q) < want_n - 2 or _ordinary(q) > want_n + 3:
			bad_n.append([w, _ordinary(q), want_n])
		rows.append([w, String(p["pattern"]), n, int(round(hp)), int(q["swaps"]), bool(q.get("short", false))])
		prev = hp
	_x("raid 2: every wave at least %d%% of the one before (chapter starts and the boss wave aside)" % int(round(ratio * 100.0)),
		bad.is_empty(), {"bad": bad, "waves": rows})
	_x("raid 2: every wave within its count in whole squads (count - 2 to count + 3; swaps never add more)", bad_n.is_empty(), {"bad": bad_n})
	var q6: Dictionary = f.plan_queue(6, f.plan_wave(6), 1e6)
	var ql: Dictionary = f.plan_queue(f.waves(), f.plan_wave(f.waves()), 1e6)
	_x("no swaps for a chapter's first wave or the boss wave", int(q6["swaps"]) == 0 and int(ql["swaps"]) == 0,
		{"wave6": q6["swaps"], "boss": ql["swaps"]})
	# a forced dip (G1b): mission 14's wave 7 after a wave bigger than it can ever be, planned 8 times. Weak squads are
	# swapped for stronger ones of the chapter until no swap helps (at least one plan swaps); every plan keeps its count
	# (- 2 to + 3), its tank share and its squad types, and a swapped plan is stronger than before its swaps
	f = _as_mission(13)
	var p7: Dictionary = f.plan_wave(7)
	var want7 := _planned_count(f, 7, p7)
	var big: float = float(want7 + 6) * 300.0 * f.strength(7) * 1.25
	var swapped := 0
	var bad_d: Array = []
	for k in 8:
		var q7: Dictionary = f.plan_queue(7, p7, big)
		if int(q7["swaps"]) > 0:
			swapped += 1
			if float(q7["hp"]) <= float(q7["hp0"]) + 0.01:
				bad_d.append(["not stronger", q7["hp0"], q7["hp"]])
		if _ordinary(q7) < want7 - 2 or _ordinary(q7) > want7 + 3:
			bad_d.append(["count", _ordinary(q7), want7])
		if float(q7["tank"]) > float(q7["tank_cap"]) + 0.001:
			bad_d.append(["tank", q7["tank"], q7["tank_cap"]])
		if int(q7["types"]) < int(q7["need"]):
			bad_d.append(["types", q7["types"], q7["need"]])
	_x("a wave after one bigger than it can be: weak squads swapped for stronger ones, its count, tank share and types kept",
		swapped > 0 and bad_d.is_empty(), {"swapped": swapped, "bad": bad_d.slice(0, 6)})


## Phase G1: mission 9 planned 30 times (waves 1-20, then 1-10 again; each after the one before, so the swaps run too).
## No wave's tank weight (its ordinary enemies and elites; never the boss) goes over tank_share x its enemies (or its
## elites' own weight); its ordinary enemies are exactly the mission's count for the wave (inside the `count` range
## outside the boss wave); its elites or boss enemies are all there.
func _tank_share() -> void:
	var f = _as_mission(8)                                  # mission 9, the Croaking Choir
	var g := _group(9)
	var share := float(g.get("tank_share", 1.0))
	var cnt: Array = f.info()["count"]
	var bad_t: Array = []
	var bad_n: Array = []
	var rows: Array = []
	var prev := 0.0
	for k in 30:
		var w: int = 1 + k % f.waves()
		if w == 1:
			prev = 0.0
		var p: Dictionary = f.plan_wave(w)
		var q: Dictionary = f.plan_queue(w, p, prev)
		prev = float(q["hp"])
		var kinds: Array = q["kinds"]
		var tw := 0.0
		var elite_w := 0.0
		var ordinary := 0
		var specials := 0
		for j in kinds.size():
			var tag := String(q["info"][j][2])
			if tag == "boss":
				specials += 1
				continue
			var wt := _tw(String(kinds[j]))
			tw += wt
			if tag == "elite":
				specials += 1
				elite_w += wt
			else:
				ordinary += 1
		var cap := maxf(share * kinds.size(), elite_w)
		if tw > cap + 0.001:
			bad_t.append([w, snappedf(tw, 0.1), snappedf(cap, 0.1), kinds])
		var want_n := _planned_count(f, w, p)
		# G1b: whole squads, so the count may be 2 under or 3 over the mission's count for the wave
		var in_range: bool = w == f.waves() or (ordinary >= int(cnt[0]) - 2 and ordinary <= int(cnt[1]) + 3)
		if ordinary < want_n - 2 or ordinary > want_n + 3 or not in_range or specials != _planned_specials(f, w):
			bad_n.append([w, String(p["pattern"]), ordinary, want_n, specials, _planned_specials(f, w)])
		rows.append([w, String(p["pattern"]), kinds.size(), snappedf(tw, 0.1), snappedf(cap, 0.1), int(q["swaps"])])
	_x("raid 9: no wave's tank weight goes over %d%% of its enemies (30 waves planned)" % int(round(share * 100.0)),
		not g.is_empty() and bad_t.is_empty(), {"group": g, "bad": bad_t.slice(0, 6)})
	_x("raid 9: every wave has the raid's count (%d to %d, in whole squads) and all its elites and boss" % [int(cnt[0]), int(cnt[1])],
		bad_n.is_empty(), {"bad": bad_n.slice(0, 8)})
	t._log("fightf tank share", {"waves": rows})


# ---------------------------------------------------------------- squads (Phase G1b)
## A kind's role in a squad, straight from the data (enemy_roles; "" when none).
func _role(kind: String) -> String:
	var r = (Data.b.get("enemy_roles", {}) as Dictionary).get(kind, "")
	return String(r) if r is String else ""


## Wave w's chapter's squad ids, straight from the data (its first `first_waves` waves: only its first one; `first`
## false: all of them).
func _chapter_ids(f, w: int, first := true) -> Array:
	var chs: Array = f.info()["chapters"]
	var ch: Dictionary = chs[mini(f.chapter_of(w), chs.size() - 1)]
	var ids: Array = []
	for pair in ch.get("squads", []):
		ids.append(String(pair[0]))
	if first and not ids.is_empty() and (w - 1) % f.chapter_waves() < int(ch.get("first_waves", 0)):
		ids = [ids[0]]
	return ids


## The light kinds in a list of squad ids, straight from the data ({kind: true}; none: the Thornling).
func _lights_of(ids: Array) -> Dictionary:
	var out := {}
	for id in ids:
		for m in (Data.b["squads"][id] as Dictionary).get("members", []):
			if _role(String(m["kind"])) == "light":
				out[String(m["kind"])] = true
	return out if not out.is_empty() else {"thornling": true}


## What is wrong with one planned squad of wave w ("" when nothing): an ordinary squad is one of its chapter's list (or a
## boss_escort squad in the boss wave) with the data's members; an elite's or a boss's squad has its leader first in
## its tag and light ones of the chapter beside it (or is an "elite" squad of the data with the elite in it).
func _squad_wrong(f, w: int, s: Dictionary) -> String:
	var ks: Array = s["kinds"]
	var tag := String(s["tag"])
	var id := String(s["id"])
	var sqs: Dictionary = Data.b["squads"]
	if tag == "":
		var ok_ids := _chapter_ids(f, w)
		if w == f.waves():
			ok_ids = ok_ids + (f.info().get("boss_escort", []) as Array)
		if not ok_ids.has(id):
			return "%s is not in the chapter's list %s" % [id, ok_ids]
		var want := {}
		for m in (sqs[id] as Dictionary)["members"]:
			want[String(m["kind"])] = [int(m["n"][0]), int(m["n"][1])]
		var got := {}
		for k in ks:
			got[String(k)] = int(got.get(String(k), 0)) + 1
		for k in got:
			if not want.has(k) or int(got[k]) < int(want[k][0]) or int(got[k]) > int(want[k][1]):
				return "%s has %s, not its members %s" % [id, got, want]
		return ""
	var lead := int(s["lead"])
	var leader := String(ks[lead]) if lead >= 0 and lead < ks.size() else ""
	var kinds_ok := {}
	for pair in f.info().get("boss" if tag == "boss" else "elite", []):
		kinds_ok[String(pair[0])] = true
	if not kinds_ok.has(leader):
		return "%s squad led by %s" % [tag, leader]
	if tag == "elite" and sqs.has(id) and bool((sqs[id] as Dictionary).get("elite", false)):
		return ""                                           # the Chief's Band
	var lights := _lights_of(_chapter_ids(f, w, false))
	for j in ks.size():
		if j != lead and not lights.has(String(ks[j])):
			return "%s's escort %s is not a light one of the chapter %s" % [leader, ks[j], lights.keys()]
	return ""


## Missions 2, 9 and 14, 30 waves each (1 to 20, then again; each after the one before): every squad belongs (_squad_wrong),
## the queue is the squads side by side, a squad's members down one road, enough squad types, and the share of one
## kind (missions 9 and 14, from share_from).
func _squad_plans() -> void:
	var r: Dictionary = Data.b["mission"].get("squad_rules", {})
	var lim := float(r.get("max_kind_share", 0.4))
	var shares := {}
	for mi in [1, 8, 13]:
		var f = _as_mission(mi)
		var bad_sq: Array = []
		var bad_road: Array = []
		var bad_types: Array = []
		var sh: Array = []
		var prev := 0.0
		for k in 30:
			var w: int = 1 + k % f.waves()
			if w == 1:
				prev = 0.0
			var p: Dictionary = f.plan_wave(w)
			var q: Dictionary = f.plan_queue(w, p, prev)
			prev = float(q["hp"])
			var sqs: Array = q.get("squads", [])
			var ids := {}
			var flat: Array = []
			for s in sqs:
				var why := _squad_wrong(f, w, s)
				if why != "":
					bad_sq.append([w, why])
				ids[String(s["id"])] = true
				flat.append_array(s["kinds"])
			if flat != q["kinds"]:
				bad_sq.append([w, "the queue is not its squads side by side"])
			# a squad's members side by side in the queue, all down one road (its squad's)
			var road_of := {}
			var last_sq := -1
			var seen := {}
			for j in (q["info"] as Array).size():
				var qi: Array = q["info"][j]
				var sn := int(qi[3]) if qi.size() > 3 else -1
				if sn < 0:
					bad_road.append([w, j, "no squad"])
					continue
				if sn != last_sq and seen.has(sn):
					bad_road.append([w, j, "squad %d split in the queue" % sn])
				seen[sn] = true
				last_sq = sn
				if road_of.has(sn) and int(road_of[sn]) != int(qi[0]):
					bad_road.append([w, j, "squad %d on two roads" % sn])
				road_of[sn] = int(qi[0])
				if sn < sqs.size() and int(sqs[sn]["road"]) != int(qi[0]):
					bad_road.append([w, j, "squad %d off its road" % sn])
			# squad types: from mission mixed_from, at least min_types (when the chapter lists that many)
			if mi + 1 >= int(r.get("mixed_from", 99)):
				var need := mini(int(r.get("min_types", 2)), _chapter_ids(f, w).size())
				if ids.size() < need:
					bad_types.append([w, ids.keys(), need])
			var cnt := {}
			for kd in q["kinds"]:
				cnt[String(kd)] = int(cnt.get(String(kd), 0)) + 1
			var top := 0
			for kd in cnt:
				top = maxi(top, int(cnt[kd]))
			sh.append(float(top) / float(maxi(1, (q["kinds"] as Array).size())))
		var nm := String(Data.mission(mi)["name"])
		_x("raid %d (%s): every enemy is in a squad of its chapter's list (or the elites' and the boss's own squads)" % [mi + 1, nm],
			bad_sq.is_empty(), {"bad": bad_sq.slice(0, 6)})
		_x("raid %d: a squad's members come side by side, all down one road" % (mi + 1), bad_road.is_empty(), {"bad": bad_road.slice(0, 6)})
		if mi + 1 >= int(r.get("mixed_from", 99)):
			_x("raid %d: every wave has at least %d squad types (as many as its chapter lists)" % [mi + 1, int(r.get("min_types", 2))],
				bad_types.is_empty(), {"bad": bad_types.slice(0, 6)})
		shares[mi] = sh
	# the share of one kind, from mission share_from: mission 14 can keep it, mission 9 mostly cannot (a Thornling is in
	# every squad of its first chapters): there the planner keeps the lowest share it finds (the rule's fallback)
	if 14 >= int(r.get("share_from", 99)):
		var sh14: Array = shares[13]
		var within := 0
		for v in sh14:
			if float(v) <= lim + 0.001:
				within += 1
		_x("raid 14: most waves keep every kind within %d%% (at least 70%% of 30 waves)" % int(round(lim * 100.0)),
			float(within) / float(sh14.size()) >= 0.7, {"within": within, "of": sh14.size(), "worst": snappedf(_max_of(sh14), 0.01)})
		# mission 9 with the rule and without it (the data changed here only, and put back)
		var sh9: Array = shares[8]
		var off := _no_share_rule_shares(8)
		_x("raid 9: the share rule's fallback: no kind over 65% of a wave, and less of one kind than without the rule",
			_max_of(sh9) <= 0.65 and _mean_of(sh9) < _mean_of(off),
			{"worst": snappedf(_max_of(sh9), 0.01), "mean": snappedf(_mean_of(sh9), 0.01), "mean_without": snappedf(_mean_of(off), 0.01)})


## Mission mi's 30 waves planned as in _squad_plans with the share rule off (squad_rules.share_from set past every
## mission in memory, then put back): the biggest share of one kind in each.
func _no_share_rule_shares(mi: int) -> Array:
	var r: Dictionary = Data.b["mission"]["squad_rules"]
	var old = r.get("share_from", 3)
	r["share_from"] = 99
	var f = _as_mission(mi)
	var out: Array = []
	var prev := 0.0
	for k in 30:
		var w: int = 1 + k % f.waves()
		if w == 1:
			prev = 0.0
		var q: Dictionary = f.plan_queue(w, f.plan_wave(w), prev)
		prev = float(q["hp"])
		var cnt := {}
		for kd in q["kinds"]:
			cnt[String(kd)] = int(cnt.get(String(kd), 0)) + 1
		var top := 0
		for kd in cnt:
			top = maxi(top, int(cnt[kd]))
		out.append(float(top) / float(maxi(1, (q["kinds"] as Array).size())))
	r["share_from"] = old
	return out


func _max_of(a: Array) -> float:
	var m := 0.0
	for v in a:
		m = maxf(m, float(v))
	return m


func _mean_of(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += float(v)
	return s / float(maxi(1, a.size()))


## The elites lead their own squads; mission 6's boss wave brings Mossback with its escort squads.
func _elite_boss() -> void:
	var r: Dictionary = Data.b["mission"].get("squad_rules", {})
	var esc: Array = r.get("elite_escort", [2, 3])
	# mission 1, wave 5: the Thornling Chief leads his Chief's Band
	var f = _as_mission(0)
	var q1: Dictionary = f.plan_queue(5, f.plan_wave(5), 0.0)
	var band := {}
	for s in q1["squads"]:
		if String(s["tag"]) == "elite":
			band = s
	_x("raid 1's elite wave: the Thornling Chief leads his Chief's Band", String(band.get("id", "")) == "chief_band"
		and String(band["kinds"][int(band["lead"])]) == "chief", {"band": band})
	# mission 2, wave 5: each Boar elite leads elite_escort light ones of the chapter, and leads them in the queue
	f = _as_mission(1)
	var q2: Dictionary = f.plan_queue(5, f.plan_wave(5), 0.0)
	var bad: Array = []
	var n_el := 0
	for s in q2["squads"]:
		if String(s["tag"]) != "elite":
			continue
		n_el += 1
		var ks: Array = s["kinds"]
		var why := _squad_wrong(f, 5, s)
		if why != "":
			bad.append(why)
		if ks.size() - 1 < int(esc[0]) or ks.size() - 1 > int(esc[esc.size() - 1]):
			bad.append("escort of %d" % (ks.size() - 1))
	for j in (q2["info"] as Array).size():
		var qi: Array = q2["info"][j]
		if String(qi[2]) == "elite" and not (qi.size() > 5 and bool(qi[5])):
			bad.append("an elite that does not lead its squad")
	_x("raid 2's elite wave: each elite leads its own squad of %d-%d light ones" % [int(esc[0]), int(esc[esc.size() - 1])],
		n_el == _planned_specials(f, 5) and bad.is_empty(), {"elites": n_el, "bad": bad, "squads": q2["squads"]})
	# mission 6, the boss wave: Mossback (alone at its squad's head) with a Brute Wall and a Boar Raid, all from its woods
	f = _as_mission(5)
	var pb: Dictionary = f.plan_wave(f.waves())
	var qb: Dictionary = f.plan_queue(f.waves(), pb, 0.0)
	var boss_sq := {}
	var esc_ids: Array = []
	var esc_roads: Array = []
	for s in qb["squads"]:
		if String(s["tag"]) == "boss":
			boss_sq = s
		elif s.has("fixed"):
			esc_ids.append(String(s["id"]))
			esc_roads.append(int(s["road"]))
	var fav := int(pb["fav"])
	_x("raid 6's boss wave: Mossback with a Brute Wall and a Boar Raid, all out of its own woods",
		not boss_sq.is_empty() and String(boss_sq["kinds"][int(boss_sq["lead"])]) == "bear" and esc_ids.has("brute_wall")
		and esc_ids.has("boar_raid") and int(boss_sq["road"]) == fav and esc_roads.count(fav) == esc_roads.size(),
		{"boss": boss_sq, "escorts": esc_ids, "roads": esc_roads, "fav": fav})


# ---------------------------------------------------------------- the gate
func _gate() -> void:
	if not Data.has_method("mission_unlocked"):
		t._log("fightf gate skipped: Data.mission_unlocked is not there yet")
		return
	var f = main.fight
	Save.missions_done = []
	Save.mission_run = {}
	f.skip_gate = false
	f.start_mission(5)                                      # mission 6: not the next one (no mission waits for the home since 21 Nov 2026)
	var started: bool = f.active
	if started:
		t._reset_fight()
	_x("the gate: a raid that is not unlocked does not start", not started, {"home": Save.camp_level})
	Save.mission_run = {}
	await t._wait(0.2)


# ---------------------------------------------------------------- a live wave
func _live_wave() -> void:
	var f = main.fight
	Save.missions_done = []
	Save.mission_run = {}
	Save.fire_ruined = false
	Save.raids["pending"] = false
	f.mission = -1
	f.start_mission(0)
	if not _x("raid 1 starts (the next raid is let through)", f.active and f.in_wave and f.mission == 0, {"active": f.active}):
		return
	var fav := int(Data.mission(0)["lanes"][0])
	await t._until(func(): return _wave_foes().size() >= 3 or f._queue.is_empty(), 15.0)
	var roads := {}
	for e in _wave_foes():
		roads[int(e.patch)] = true
	_x("raid 1, wave 1: the enemies come down one road", roads.keys() == [fav], {"roads": roads.keys(), "fav": fav, "plan": f.plan})
	# a Golden Grub alive does not hold the wave up
	var grub = f.spawn_grub()
	_x("a Golden Grub runs in, in the groups foes and bonus", grub != null and grub.is_in_group("foes") and grub.is_in_group("bonus"))
	f._queue.clear()
	f._qinfo.clear()
	var tim0: int = Save.timber
	for e in _wave_foes():
		e.hit(Vector3.FORWARD, e.hp + 1.0)
	_x("left_in_wave leaves the grub out", f.left_in_wave() == 0, {"left": f.left_in_wave()})
	var cleared: bool = await t._until(func(): return not f.in_wave, 5.0)
	var alive: bool = grub != null and is_instance_valid(grub) and not grub.dead
	_x("the wave is held while the grub is still alive", cleared and alive, {"cleared": cleared, "grub_alive": alive})
	var lp: Dictionary = f.last_pay
	_x("a quick wave with nothing broken pays both bonuses", int(lp.get("wave", 0)) == 1 and int(lp.get("quick", 0)) > 0 and int(lp.get("intact", 0)) > 0,
		{"pay": lp, "toast": String(main.hud._toast.text)})
	# Phase G1: every wave held pays timber_per_wave x the pay scale (mission 1: the pay scale is 1), at least 1
	var want_t := maxi(1, int(round(float(Data.b["mission"].get("timber_per_wave", 1)))))
	_x("raid 1: the wave held pays %d timber" % want_t, Save.timber == tim0 + want_t and int(lp.get("timber", 0)) == want_t,
		{"timber": [tim0, Save.timber], "pay": lp})
	# the breather: where the next wave comes from is on the status line
	var st: String = f.status_text()
	_x("the breather's status line previews the next wave", f.preview_text() != "" and st.contains("Next: "), {"status": st})
	# The player starts the next wave; no timer or early-start leaf payment remains.
	var l0: int = Save.leaves
	f.next_phase_now()
	_x("starting a wave charges and pays no leaves", Save.leaves == l0, {"paid": Save.leaves - l0})
	await t._until(func(): return f.in_wave, 2.0)
	_x("the next wave starts", f.in_wave and f.wave == 2, {"wave": f.wave, "status": f.status_text()})
	t._reset_fight()
	Save.mission_run = {}
	Save.save_game()
	await t._wait(0.3)


# ---------------------------------------------------------------- manual wave control and durable progress (23 Nov 2026)
func _manual_progress() -> void:
	var f = main.fight
	f.set_physics_process(false)
	Save.missions_done = []
	Save.mission_run = {}
	Save.fire_ruined = false
	Save.raids["pending"] = false
	Save.leaves = 1000
	Save.timber = 100
	var sign: Dictionary = main.stations._card_sign()
	var first_rows: Array = (sign["rows"] as Array).filter(func(r): return int(r.get("mission_index", -1)) == 0)
	_x("the signpost offers the first Raid Mission and locks Random Raids", first_rows.size() == 1 and String(first_rows[0]["label"]) == "Start" and not bool(sign["tabs"][1]["enabled"]))
	f.start_mission(0)
	_x("first raid starts at wave 1 of 15 from the player's action", f.in_wave and f.wave == 1 and f.waves() == 15)
	# Real kill drops gain 50%, while returned stolen leaves keep their original amount.
	for p in get_tree().get_nodes_in_group("pickups"):
		p.queue_free()
		p.remove_from_group("pickups")
	var foe = f.spawn("thornling", Vector3(25, 0, 12), 0)
	var base_drop := Data.saddlebag_leaves(int(foe.info["leaves"]))
	foe.carried = 7
	foe.hit(Vector3.FORWARD, float(foe.hp) + 1.0)
	var dropped := 0
	for p in get_tree().get_nodes_in_group("pickups"):
		dropped += int(p.value)
		p.remove_from_group("pickups")
		p.queue_free()
	_x("real enemy drops gain 50% without multiplying stolen leaves", dropped == roundi(base_drop * 1.5) + 7, {"base": base_drop, "drop": dropped})
	f._clear_foes()
	var before_leaves: int = Save.leaves
	var before_timber: int = Save.timber
	f._wave_cleared()
	var paid: Dictionary = f.last_pay
	_x("wave 1 pays doubled base leaves and timber", int(paid["bonus"]) == 7 and int(paid["timber"]) == 2 and Save.timber == before_timber + 2 and Save.leaves == before_leaves + int(paid["bonus"]) + int(paid["quick"]) + int(paid["intact"]), {"pay": paid})
	_x("every ordinary wave saves its completed number", int(Save.mission_run.get("wave_done", -1)) == 1 and not f.in_wave)
	var banked: int = Save.leaves
	var timber_banked: int = Save.timber
	for tick in 400:
		f._physics_process(0.1)
	_x("40 seconds of waiting never starts wave 2 or pays again", not f.in_wave and f.wave == 1 and Save.leaves == banked and Save.timber == timber_banked)
	f._wave_cleared()
	_x("a repeated wave-clear callback cannot duplicate rewards", Save.leaves == banked and Save.timber == timber_banked and int(Save.mission_run["wave_done"]) == 1)
	sign = main.stations._card_sign()
	_x("waiting signpost offers exactly the next wave without a countdown", String(sign["rows"][0]["label"]) == "Start wave" and String(sign["rows"][0]["text"]) == "Wave 2 of 15" and not String(sign["sub"]).contains("in 15"))
	(sign["rows"][0]["action"] as Callable).call()
	f.next_phase_now()
	_x("Start wave begins wave 2 immediately and a second tap cannot skip it", f.in_wave and f.wave == 2 and Save.leaves == banked)
	f._clear_foes()
	f._wave_cleared()
	Save.meal_on = String(Data.b["cooking"]["recipes"][0]["id"])
	var meal: String = Save.meal_on
	Save.save_game()
	t._reset_fight()
	Save.load_game()
	main.defences.relink_saved()
	_x("save/load retains wave 2 and the active dish", int(Save.mission_run.get("wave_done", -1)) == 2 and Save.meal_on == meal)
	Save.meal_on = ""
	Data.set_meal("")
	banked = Save.leaves
	f.start_mission(0)
	_x("restart resumes at wave 3 without repeating completed rewards", f.wave == 3 and f.in_wave and Save.leaves == banked)
	f.camp_falls()
	_x("a loss keeps waves 1-2 cleared and offers retry of wave 3", int(Save.mission_run.get("wave_done", -1)) == 2 and String(main.hud._banner_s.text).contains("retry wave 3"))
	Save.fire_ruined = false
	main.world.set_fire_out(false)
	main.stations.set_fire_out(false)
	f.start_mission(0)
	_x("the retry starts only the failed wave", f.wave == 3 and f.in_wave)
	f._clear_foes()
	f._start_wave(5)
	f._clear_foes()
	f._wave_cleared()
	_x("wave 5 keeps its supply chest and saves five cleared waves", f.on_break and f.wave == 5 and int(Save.mission_run.get("wave_done", -1)) == 5)
	for tick in 400:
		f._physics_process(0.1)
	_x("the fifth-wave checkpoint also waits indefinitely", not f.in_wave and f.wave == 5)
	f.next_phase_now()
	_x("the next group continues at wave 6, never resets to wave 1", f.in_wave and f.wave == 6)
	f._clear_foes()
	f._wave_cleared()
	main.hud.show_card(main.stations.rings["sign"])
	await t._wait(0.4)
	await t._shot("manual_raid_wave_7")
	main.hud.hide_card()
	Save.save_game()
	t._reset_fight()
	Save.load_game()
	main.defences.relink_saved()
	f.start_mission(0)
	_x("a restart after wave 6 resumes at wave 7, beyond the old checkpoint", f.in_wave and f.wave == 7)
	t._reset_fight()
	Save.mission_run = {"mission": 0, "chapter": 1, "gain": 0}
	Save.save_game()
	Save.load_game()
	main.defences.relink_saved()
	f.start_mission(0)
	_x("an older chapter-only save still resumes at wave 6", f.in_wave and f.wave == 6)
	t._reset_fight()
	Save.missions_done = []
	Save.mission_run = {"mission": 13, "chapter": 3, "wave_done": 19, "gain": 0}
	Save.save_game()
	Save.load_game()
	main.defences.relink_saved()
	f.skip_gate = true
	f.start_mission(13)
	f.skip_gate = false
	_x("a 20-wave raid resumes at wave 20 instead of resetting to 16", f.in_wave and f.wave == 20 and f.waves() == 20)
	f._clear_foes()
	f._wave_cleared()
	_x("the final wave completes the raid and clears its checkpoint", not f.active and Save.mission_run.is_empty() and Save.missions_done.has(String(Data.mission(13)["id"])))
	t._reset_fight()
	Save.missions_done = []
	Save.mission_run = {}
	# Random Raids wait for one player action, then continue without intermediate wave starts.
	var old_raids: Dictionary = Save.raids.duplicate(true)
	for m in Data.b["missions"]:
		Save.missions_done.append(String(m["id"]))
	main.raids.refresh_open()
	var plan: Dictionary = main.raids._plan()
	Save.raids["plan"] = plan
	Save.raids["pending"] = true
	Save.raids["run"] = {}
	var spec: Dictionary = main.raids.spec_for(plan)
	f.start_raid(spec, 0.1)
	for tick in 400:
		f._physics_process(0.1)
	_x("a Random Raid cannot start its assault automatically", f.active and not f.in_wave and f.wave == 0)
	f.next_phase_now()
	_x("the player starts one continuous Random Raid", f.in_wave and f.wave == 1 and f.waves() == 1)
	banked = Save.leaves
	Save.raids["run"] = {"assault_format": 1, "defeated": [0, 1]}
	t._reset_fight()
	f.start_raid(spec, 0.1)
	_x("Random Raid restarts preserve banked rewards and wait for the player", f.wave == 0 and not f.in_wave and Save.leaves == banked)
	f.next_phase_now()
	_x("the resumed assault omits already defeated members", f.wave == 1 and f.in_wave and f._queue.size() == int(spec["enemy_count"]) - 2 and f._qinfo.all(func(row): return int(row[3]) > 1))
	f._clear_foes()
	before_leaves = Save.leaves
	before_timber = Save.timber
	var held_before: int = Save.raids["held"]
	f._wave_cleared()
	_x("the whole assault pays once and ends without another wave", not f.active and int(Save.raids["held"]) == held_before + 1 and Save.leaves >= before_leaves + 7 and Save.timber >= before_timber + 2)
	banked = Save.leaves
	f._wave_cleared()
	_x("a duplicate assault clear cannot repeat rewards", Save.leaves == banked and not f.active)
	t._reset_fight()
	Save.raids = old_raids
	Save.raids["pending"] = false
	Save.missions_done = []
	Save.mission_run = {}
	Save.fire_ruined = false
	main.raids.refresh_open()
	f.set_physics_process(true)
	Save.save_game()
	await t._wait(0.3)


# ---------------------------------------------------------------- the wave limits, live (Phase G1)
func _live_limits() -> void:
	var f = main.fight
	var m: Dictionary = Data.b["mission"]
	Save.missions_done = []
	Save.mission_run = {}
	Save.fire_ruined = false
	Save.raids["pending"] = false
	f.mission = -1
	f.skip_gate = true
	f.start_mission(8)                                      # mission 9, the Croaking Choir: missions 6-10's limits
	f.skip_gate = false
	if not _x("raid 9 starts (skip_gate)", f.active and f.in_wave and f.mission == 8, {"active": f.active}):
		return
	var g := _group(9)
	var lim: Dictionary = f.wave_limits()
	var cap_n := int(g.get("max_alive", 12))
	var cap_t := float(g.get("tanks_at_once", 2.0))
	_x("raid 9 has its group's limits (at most %d on the field, %.1f tanks)" % [cap_n, cap_t],
		int(lim["max_alive"]) == cap_n and absf(float(lim["tanks_at_once"]) - cap_t) < 0.001
		and absf(float(lim["tank_share"]) - float(g.get("tank_share", -1.0))) < 0.001 and f._max_alive() == cap_n,
		{"limits": lim, "group": g})
	# the wave's queue swapped for 6 tanks first, then 16 Thornlings, spawned as fast as the field lets them
	f._grub_at = -1.0
	f._totem_at = -1.0
	var q: Array = ["stump", "brute", "stump", "boar", "brute", "stump"]
	for k in 16:
		q.append("thornling")
	f._queue = q
	f._qinfo.clear()
	var max_n := 0
	var max_t := 0.0
	var held_back := false                                  # Thornlings on the field while tanks still wait in the queue
	var tq_before := -1
	for k in 150:
		if k == 75:
			tq_before = _tanks_queued(f)
			for e in _wave_foes():                          # a big tank falls: room for the next one
				if _tw(String(e.id)) >= 1.0:
					e.hit(Vector3.FORWARD, e.hp * 10.0 + 100.0)
					break
		f._spawn_t = 0.0
		await get_tree().physics_frame
		var foes := _wave_foes()
		max_n = maxi(max_n, foes.size())
		max_t = maxf(max_t, _field_tank())
		if not held_back and _tanks_queued(f) > 0:
			for e in foes:
				if String(e.id) == "thornling":
					held_back = true
					break
	var tq_after := _tanks_queued(f)
	_x("a live wave fills the field to %d and never past it" % cap_n, max_n == cap_n, {"max_on_field": max_n, "queue": f._queue.size()})
	_x("a live wave never has more than %.1f tank weight on the field" % cap_t, max_t <= cap_t + 0.001, {"max_tank": max_t})
	_x("the tanks wait and Thornlings come instead; a tank comes once one falls", held_back and tq_before > 0 and tq_after < tq_before,
		{"held_back": held_back, "tanks_queued": [tq_before, tq_after]})
	# the Last Stand with too little timber: the rebuild costs leaves, the banner says so
	var rt := int(m.get("rebuild_timber", 10))
	var rl := int(m.get("rebuild_leaves", 60))
	Save.timber = rt - 1
	Save.leaves = 500
	var rc: Dictionary = f.rebuild_cost()
	f.damage_fire(int(f.gate_hp) + 1, Vector3(0, 0, -5))
	var sub := String(main.hud._banner_s.text)
	var out: bool = f.last_stand
	var rebuilt: bool = f.rebuild_fire()
	_x("too little timber: rebuild_cost() is %d leaves, the banner says so, and the fire is rebuilt for them" % rl,
		int(rc.get("leaves", -1)) == rl and not rc.has("timber") and sub.contains("%d leaves" % rl) and out and rebuilt
		and Save.leaves == 500 - rl and Save.timber == rt - 1,
		{"cost": rc, "banner": sub, "last_stand": out, "rebuilt": rebuilt, "leaves": Save.leaves, "timber": Save.timber})
	Save.timber = rt
	var rc2: Dictionary = f.rebuild_cost()
	_x("with %d timber: rebuild_cost() is the timber" % rt, int(rc2.get("timber", -1)) == rt and not rc2.has("leaves"), {"cost": rc2})
	# the wave held pays its timber, x the pay scale (mission 9)
	var tim0: int = Save.timber
	var want_t := maxi(1, int(round(float(m.get("timber_per_wave", 1)) * (1.0 + float(m["pay_per_mission"]) * 8))))
	f._queue.clear()
	f._qinfo.clear()
	for e in _wave_foes():
		e.hit(Vector3.FORWARD, e.hp * 10.0 + 100.0)
	var cleared: bool = await t._until(func(): return not f.in_wave, 5.0)
	var toast := String(main.hud._toast.text)
	_x("raid 9: the wave held pays %d timber and the toast says so" % want_t,
		cleared and Save.timber == tim0 + want_t and int(f.last_pay.get("timber", 0)) == want_t and toast.contains("+%d timber" % want_t),
		{"cleared": cleared, "timber": [tim0, Save.timber], "pay": f.last_pay, "toast": toast})
	t._reset_fight()
	Save.mission_run = {}
	Save.save_game()
	await t._wait(0.3)


# ---------------------------------------------------------------- a camp fall takes only the chapter's gain
## Mission 1 for real, nothing spawning (the fight's physics off: only what the test does). See the header (_fall_gain).
func _fall_gain() -> void:
	var f = main.fight
	var share := float(Data.b["raid"]["leaves_share"])
	Save.missions_done = []
	Save.mission_run = {}
	Save.fire_ruined = false
	Save.raids["pending"] = false
	for p in get_tree().get_nodes_in_group("pickups"):     # leaves left on the ground by the tests before: a fall
		p.remove_from_group("pickups")                      # sweeps them home, which would muddy the sums
		p.queue_free()
	Save.leaves = 1000
	f.mission = -1
	f.start_mission(0)
	f.set_physics_process(false)
	if not _x("fall: raid 1 starts with 1000 leaves saved and nothing gained yet", f.active and f.chapter_gain() == 0 and Save.leaves == 1000,
			{"run": Save.mission_run, "leaves": Save.leaves}):
		f.set_physics_process(true)
		t._reset_fight()
		return
	main.collect_leaves(120, Vector3(0, 0, 2))               # a pickup
	Save.add_leaves(80)                                     # wave pay
	Data.pay({"leaves": 150})                               # spent in the chapter: it was still gained
	_x("fall: the chapter's gain counts what came in (200), a spend does not lower it", f.chapter_gain() == 200 and Save.leaves == 1050,
		{"gain": f.chapter_gain(), "leaves": Save.leaves})
	# a save, the app closed and opened again, the run resumed from the signpost
	Save.save_game()
	t._reset_fight()
	Save.load_game()
	main.defences.relink_saved()
	_x("fall: the gain is in the run's save (read back: 200)", int(Save.mission_run.get("gain", -1)) == 200 and Save.leaves == 1050 and not Save.count_gain,
		{"run": Save.mission_run, "leaves": Save.leaves})
	f.start_mission(0)
	f.set_physics_process(false)
	_x("fall: the run resumed at its chapter keeps it", f.active and f.chapter() == 0 and f.chapter_gain() == 200, {"gain": f.chapter_gain(), "run": Save.mission_run})
	Save.add_leaves(100)
	var before := Save.leaves
	var want := mini(before, int(floor(300 * share)))
	f.camp_falls()
	var sub := String(main.hud._banner_s.text)
	_x("fall: the Gloom takes %d%% of the chapter's 300 leaves (%d), never the 1000 saved before; the banner says so" % [int(round(share * 100.0)), want],
		Save.leaves == before - want and int(f.last_fall_lost) == want and sub.contains("-%d leaves" % want),
		{"leaves": [before, Save.leaves], "lost": f.last_fall_lost, "banner": sub})
	_x("fall: the chapter's next try counts from 0", int(Save.mission_run.get("gain", -1)) == 0 and int(Save.mission_run.get("chapter", -1)) == 0
		and not Save.count_gain, {"run": Save.mission_run})
	# the next try, then a chapter break: its chest and the break's own leaves are not the next chapter's
	Save.fire_ruined = false
	main.world.set_fire_out(false)
	main.stations.set_fire_out(false)
	f.start_mission(0)
	f.set_physics_process(false)
	Save.add_leaves(50)
	f.wave = f.chapter_waves()
	f.in_wave = false
	f._chapter_done(0)
	var g_break: int = f.chapter_gain()
	Save.add_leaves(40)                                     # a sale in the break
	_x("fall: a chapter break saves the next chapter with nothing gained, and the break's leaves are not counted",
		f.on_break and g_break == 0 and f.chapter_gain() == 0 and int(Save.mission_run.get("chapter", -1)) == 1, {"gain": [g_break, f.chapter_gain()], "run": Save.mission_run})
	f.next_phase_now()
	Save.add_leaves(60)
	_x("fall: chapter 2 counts from its first wave (60)", f.in_wave and f.chapter() == 1 and f.chapter_gain() == 60, {"gain": f.chapter_gain(), "wave": f.wave})
	Data.pay({"leaves": Save.leaves - 10})                  # spent down to 10 leaves
	var want2 := mini(10, int(floor(60 * share)))
	f.camp_falls()
	_x("fall: never more than the cat holds (%d of the %d due)" % [want2, int(floor(60 * share))], Save.leaves == 10 - want2 and int(f.last_fall_lost) == want2,
		{"leaves": Save.leaves, "lost": f.last_fall_lost})
	Save.fire_ruined = false
	main.world.set_fire_out(false)
	main.stations.set_fire_out(false)
	f.set_physics_process(true)
	t._reset_fight()
	Save.mission_run = {}
	Save.save_game()
	await t._wait(0.3)


# ---------------------------------------------------------------- a squad on the field (Phase G1b)
## A point on the ground (y = 0).
func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)


## Mission 9 for real (skip_gate), its queue one Choir down its own road (the Boar leads, two Thornlings beside it, the
## Frog Shaman and the Crow Drummer behind). The cat holds its fire at the camp. It comes out all at once near the
## road's spawn point; on the march (more than break_off m from the firelight) its light members keep within 3 m of
## their spot by the leader (EnemyScript.squad_spot) and never more than 1 m ahead of it or of the leader, its support
## stays behind the leader; then the leader falls: the rest leave the squad and carry on alone.
func _live_squad() -> void:
	var f = main.fight
	var r: Dictionary = Data.b["mission"].get("squad_rules", {})
	Save.missions_done = []
	Save.mission_run = {}
	Save.fire_ruined = false
	Save.raids["pending"] = false
	f.mission = -1
	f.skip_gate = true
	f.start_mission(8)                                      # mission 9, the Croaking Choir
	f.skip_gate = false
	if not _x("raid 9 starts for the squad test (skip_gate)", f.active and f.in_wave and f.mission == 8, {"active": f.active}):
		return
	f._grub_at = -1.0
	f._totem_at = -1.0
	main.player.frozen = true                               # the cat holds its fire, at the camp
	main.player.global_position = Vector3(0.0, 0.0, 1.5)
	if main.pet != null:
		main.pet.process_mode = Node.PROCESS_MODE_DISABLED
	var kinds: Array = f._roll_kinds("choir", "max")
	var lead: int = f.squad_leader_index(kinds)
	var offs: Array = f.squad_offsets(kinds, lead)
	var road := int(f.info()["lanes"][0])
	var qi: Array = []
	for j in kinds.size():
		qi.append([road, 1.0, "", 0, offs[j], j == lead])
	f._queue = kinds.duplicate()
	f._qinfo = qi
	f._spawn_t = 0.0
	var came: bool = await t._until(func(): return not _wave_foes().is_empty(), 3.0)
	var foes := _wave_foes()
	var leader = null
	for e in foes:
		if e.has_meta("squad") and not e.has_meta("squad_leader"):
			leader = e
	var together: bool = came and foes.size() == kinds.size() and leader != null
	var spread := 0.0
	var members: Array = []
	for e in foes:
		if e == leader:
			continue
		members.append(e)
		if leader != null:
			spread = maxf(spread, _flat(e.global_position).distance_to(_flat(leader.global_position)))
			together = together and e.has_meta("squad_leader") and e.get_meta("squad_leader") == leader \
				and int(e.get_meta("squad", -1)) == int(leader.get_meta("squad", -2))
	var from_spawn: float = _flat(leader.global_position).distance_to(_flat(main.world.spawn_point(road, 0.0))) if leader != null else INF
	_x("a squad comes out all at once near one spawn point, led by its %s" % String(kinds[lead]),
		together and spread <= 3.5 and from_spawn <= 3.5 and String(leader.id) == String(kinds[lead]),
		{"came": foes.size(), "of": kinds.size(), "spread": snappedf(spread, 0.01), "from_spawn": snappedf(from_spawn, 0.01)})
	if not together:
		await _squad_cleanup()
		return
	# on the march, far from the camp
	var brk := float(r.get("break_off", 6.0))
	var camp_r := float(main.world.camp_r)
	var far := 0.0                                          # light ones: the most from their spot
	var ahead_spot := -INF                                  # ... the most ahead of their spot
	var ahead_lead := -INF                                  # ... the most ahead of the leader
	var sup_rel := -INF                                     # support: the most ahead of the leader (behind it: < 0)
	var samples := 0
	var kept := 0
	for k in 70:
		await t._wait(0.1)
		if not is_instance_valid(leader) or leader.dead:
			break
		var lp := _flat(leader.global_position)
		if lp.length() - camp_r < brk + 1.0:
			break                                           # near the camp: they break off there
		var ry := float(leader.rotation.y)
		var fwd := Vector3(sin(ry), 0.0, cos(ry))
		samples += 1
		for e in members:
			if not is_instance_valid(e) or e.dead or not e.has_meta("squad_leader"):
				continue
			kept += 1
			var me := _flat(e.global_position)
			var rel := (me - lp).dot(fwd)
			var role: String = f.role_of(String(e.id))
			if role == "support":
				sup_rel = maxf(sup_rel, rel)
			elif role == "light":
				var spot: Vector3 = EnemyScript.squad_spot(lp, ry, e.get_meta("squad_offset", Vector3.ZERO))
				far = maxf(far, me.distance_to(spot))
				ahead_spot = maxf(ahead_spot, (me - spot).dot(fwd))
				ahead_lead = maxf(ahead_lead, rel)
	_x("on the march its light members keep within 3 m of their spot by the leader and never run ahead of it",
		samples >= 15 and kept >= samples * 3 and far <= 3.0 and ahead_spot <= 1.0 and ahead_lead <= 1.0,
		{"samples": samples, "kept": kept, "far": snappedf(far, 0.01), "ahead_of_spot": snappedf(ahead_spot, 0.01),
		"ahead_of_leader": snappedf(ahead_lead, 0.01)})
	_x("on the march its support members stay behind the leader", samples >= 15 and sup_rel < 0.0 and sup_rel > -INF,
		{"most_forward": snappedf(sup_rel, 0.01)})
	# the leader falls: the rest leave the squad and carry on alone
	var alive: Array = []
	for e in members:
		if is_instance_valid(e) and not e.dead:
			alive.append(e)
	if is_instance_valid(leader) and not leader.dead:
		leader.hit(Vector3.FORWARD, leader.hp * 10.0 + 100.0)
	await t._wait(0.6)
	var r0 := {}
	var still: Array = []
	for e in alive:
		if is_instance_valid(e) and not e.dead:
			r0[e] = _flat(e.global_position).length()
			if e.has_meta("squad_leader"):
				still.append(String(e.id))
	await t._wait(2.0)
	var moved := 0
	var lights := 0
	for e in r0:
		if not is_instance_valid(e) or e.dead or f.role_of(String(e.id)) != "light":
			continue
		lights += 1
		if _flat(e.global_position).length() < float(r0[e]) - 0.5:
			moved += 1
	_x("its leader falls: the rest leave the squad and carry on alone toward the camp",
		not r0.is_empty() and still.is_empty() and lights > 0 and moved == lights,
		{"alive": r0.size(), "still_in_squad": still, "light_ones_on": [moved, lights]})
	await _squad_cleanup()


func _squad_cleanup() -> void:
	main.player.frozen = false
	if main.pet != null:
		main.pet.process_mode = Node.PROCESS_MODE_INHERIT
	t._reset_fight()
	Save.mission_run = {}
	Save.save_game()
	await t._wait(0.3)


# ---------------------------------------------------------------- mission 1's first win (Phase G1b fix)
## Barricades are rows at the road spots since G2 (not from the bag): mission 1's first win pays its first barricades
## in leaves (barricade free_pieces x piece) and says so with a toast; no pieces go into the bag.
func _first_win() -> void:
	var f = main.fight
	var di: Dictionary = Data.defence_info("barricade")
	var want := int(di.get("free_pieces", 2)) * int(di.get("piece", 30))
	Save.missions_done = []
	Save.mission_run = {}
	Save.fire_ruined = false
	Save.raids["pending"] = false
	f.mission = -1
	f.start_mission(0)
	if not _x("raid 1 starts for its first win", f.active and f.mission == 0, {"active": f.active}):
		return
	f._queue.clear()
	f._qinfo.clear()
	var bag0 := int(Save.items.get("barricade", 0))
	var l0: int = Save.leaves
	var reward := int(Data.mission(0)["reward"]["leaves"])
	f._win()
	var toast := String(main.hud._toast.text)
	var told: bool = toast.contains("+%d leaves for your first barricades" % want) or toast.begins_with("Every goal met")
	_x("raid 1's first win: +%d leaves for the first barricades, no pieces in the bag" % want,
		int(f.barricade_gift) == want and int(Save.items.get("barricade", 0)) == bag0 and Save.leaves - l0 >= reward + want and told,
		{"gift": f.barricade_gift, "bag": [bag0, int(Save.items.get("barricade", 0))], "leaves": Save.leaves - l0, "reward": reward,
		"toast": toast})
	Save.missions_done = []
	Save.mission_run = {}
	t._reset_fight()
	Save.save_game()
	await t._wait(0.3)


# ---------------------------------------------------------------- the Gloom over the woods
func _gloom() -> void:
	var w = main.world
	Save.missions_done = []
	for i in 3:
		Save.missions_done.append(String(Data.mission(i)["id"]))
	w.fade_gloom()
	await t._wait(3.2)
	var want := 1.0 - 3.0 / float(Data.mission_count())
	var g: Array = []
	var ok := true
	for i in 4:
		g.append(snappedf(float(w.gloom[i]), 0.01))
		ok = ok and absf(float(w.gloom[i]) - want) < 0.02
	_x("the Gloom over all four woods fades a step per raid won (3 won: %.2f)" % want, ok, {"gloom": g})
	Save.missions_done = []
	w.settle_gloom()
	await t._wait(1.9)
	g = []
	ok = true
	for i in 4:
		g.append(snappedf(float(w.gloom[i]), 0.01))
		ok = ok and absf(float(w.gloom[i]) - 1.0) < 0.02
	_x("none won: the Gloom is back over all four woods", ok, {"gloom": g})
	Save.save_game()
