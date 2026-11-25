extends Node
## A mission (balance.json "missions", run by the "mission" settings), wave by wave (Draft 7, Phase F):
##   waves      15 or 20, each a little stronger than the last (more enemies, then tougher kinds from its chapter)
##   squads     (Phase G1b) a wave is a list of squads, small teams with roles (balance.json `squads`, `enemy_roles`):
##              the chapter's `squads` by weight until the wave has its count (its first `first_waves` waves only its
##              first squad), with mission.squad_rules: mixed squad types, no pile of one kind, the tank share in whole
##              squads (plan_queue). A squad comes down one road together, set out in a formation (its tank in front,
##              light ones beside and behind, support further back), and only when the field has room for all of it
##              (_next_spawn, _spawn_squad); its members keep pace with their leader until near the camp (enemy.gd).
##              Old data without squads: the chapter's `pool`, one enemy at a time (_pool_queue).
##   chapters   of 5 waves. The last wave of a chapter is an elite wave (the mission's `elite` enemies, more each
##              chapter, or `elite_by_chapter`; each leads its own squad); the mission's last wave brings its `boss`
##              (with its `boss_escort` squads, and `boss_adds` of its ordinary enemies).
##   roads      (Phase F) every wave gets a pattern when it is planned (mission.roads): surround (all four roads taking
##              turns, the mission's own woods, `lanes[0]`, a little more), pincer (two roads far apart) or rush (its own
##              woods: faster, with a banner); since G1b the squads take turns, one road per squad. The elites come
##              down a flank road; the boss wave
##              surrounds and the boss comes out of the mission's own woods. Mission 1 opens its roads chapter by
##              chapter (one, then two, then all four). The next wave is planned when its breather starts, so the status
##              line says where it will come from. (Phase G1: a rush keeps its count, `roads.rush_count` 1.0.)
##   bursts     enemies come in groups a moment apart (mission.burst), then a gap that keeps the chapter's average rate.
##              Since G1b a squad is the group: all at once, then about `every` x its size until the next squad.
##   limits     (Phase G1, mission.wave_limits) many enemies in a wave, only a few on the field at once, few tanks: by
##              the mission's group, at most `max_alive` of the wave on the field (with a boss alive, at most
##              `boss_others_on_field` others) and at most `tanks_at_once` tank weight (`tank_weight`: elites count by
##              their kind, bosses never); the next queued enemy that would break it waits and the next non-tank comes
##              instead (_next_spawn). A whole wave has at most `tank_share` x its enemies in tank weight (plan_queue:
##              extra tank picks become the pool's other kinds; elites and bosses are never dropped).
##   no easy waves  an ordinary wave whose health is below `min_wave_ratio` of the wave before has its weakest enemies
##              swapped for stronger kinds of its pool (non-tanks first, tanks only within the tank share); it never
##              gets more enemies (not the first wave after a chapter break, not the boss wave).
##   extras     the Golden Grub (a bonus runner in the group "bonus": it never holds a wave up, see _wave_foes) and the
##              Gloom Totem (a foe on a road: the wave waits for it).
##   breather   unlimited time between every wave to shop. The signpost's "Start wave" starts exactly the next wave.
##              The camp's cards only work outside a wave. No automatic start or early-start timer payment.
##   break      after a chapter the camp rests until the player goes on from the signpost. The campfire is fed back to
##              full and a chest pays out. Every wave saves wave_done (Save.mission_run); restarting resumes the next
##              uncleared wave. Older chapter-only saves retain their original chapter checkpoint.
##   pay        kills drop leaves; a cleared wave pays a small bonus, more when it was quick and when nothing was broken
##              (mission.bonus), and (Phase G1) `timber_per_wave` timber; a chapter pays its chest; the win pays the
##              reward. Every mission won fades the Gloom over the woods a step (world.fade_gloom) and may give a
##              building (its `gift`: mission 1 the garden, mission 6 the fishing spot). The Market and the Mushroom
##              Cottage open at the Hearthtree's level 2 (Phase G2), not with a mission. Mission 1's first win also
##              pays its first barricades in leaves (barricade `free_pieces` x the old `piece` price): barricades are
##              built as rows at the road spots since G2, not from the bag.
##   gate       a mission starts only when Data.mission_unlocked says so (the Hearthtree's level; won missions are not
##              replayed).
## Enemies attack the camp's structures (enemy.gd): barricades, towers, buildings, the campfire. When the campfire is
## destroyed the cat is alone in the dark: the Last Stand. Once per chapter the cat can rebuild it (main.gd: stand on the
## ashes, pay rebuild_cost(): timber, or in a mission leaves when the timber is short); it comes back at 30%. The camp
## falls if the cat dies in the Last Stand or the fire is destroyed a second time (camp_falls): the Gloom takes a share
## of the leaves gained since that chapter began (chapter_gain; since 21 Nov 2026 never the leaves saved before it),
## ruined buildings and broken defences stay broken, the campfire stays ashes until it is rebuilt, and only the failed
## wave is retried. No completed wave or level is lost. Player-facing terminology is "raid"; internal keys are stable.
## Gloom Raids (Phase D) run here too, as mode "raid": raids.gd builds a mission-shaped spec and calls start_raid. Its
## warning is the breather before its first wave; it never reaches _win or _chapter_done, never writes the mission
## save fields, and a lost raid takes nothing (no leaves, no ashes): only the damage stays (raids.finish). Random Raids
## use one seeded roster, arriving in groups of 1–3 across all four trails with no intermediate waves. Their own live
## cap applies; the 50-enemy total includes leaders and summons. Defeated member IDs preserve progress across saves.

const EnemyScript := preload("res://scripts/enemy.gd")

var main
var active := false
var in_wave := false            # a wave is on (false in a breather and in a chapter break)
var on_break := false           # a chapter is done: the camp rests until the player goes on
var mission := -1               # index into balance.json missions
var wave := 0                   # the wave on now (or just held), 1-based
var lane := 0                   # the trail the last enemy came down
var last_stand := false         # the campfire is out
var rebuilt := false            # the campfire was rebuilt in this chapter
var gate_hp := 100.0            # the campfire's health
var gate_max := 100.0
var wave_t := 0.0               # seconds into this wave
var total_t := 0.0
var _breather := 0.0
var _spawn_t := 0.0
var _queue: Array = []          # enemies of this wave still to come: [kind, ...]
var _quiet_t := 0.0             # seconds since an enemy of this wave last came or fell
var _first := false             # the very first mission, first time: it opens the shop as it goes
var _ruined_at_start: Array = [] # a replay after the endgame mends only the ruins it made
var mode := "mission"            # "mission", or "raid" (a Gloom Raid: raids.gd builds the spec)
var raid: Dictionary = {}        # the raid's mission-shaped spec while mode == "raid"
var warning := false             # a raid's warning is running (the breather before its next wave)
var raid_losses := 0             # buildings knocked down in this raid (stations.ruin)
var fire_went_out := false       # the campfire went out in this raid: no perfect defence
var _rng := RandomNumberGenerator.new()   # raids: seeded, so a raid that comes back is the same raid
var _endgame_run := false        # raids were open when this mission started
# Phase F (missions only): the roads, the bursts, no easy waves, the extras and the pay for active play
var plan: Dictionary = {}        # this wave's roads: {"wave", "pattern", "roads", "fav", "flank", "speed", "count"}
var next_plan: Dictionary = {}   # the next wave's, made when its breather starts (status_text previews it)
var skip_gate := false           # tests only: start a mission the gate (Data.mission_unlocked) would refuse
var _qinfo: Array = []           # missions: [road, speed x, tag ("", "elite", "boss"), squad, spot, leads] of each enemy still to
                                 # come, side by side with _queue (plan_queue; the old pool's: the first three only)
var _squad_n := 0                # Phase G1b: squads spawned so far (each squad's members carry its number, the meta "squad")
var _burst_left := 0             # enemies still to come in this burst
var _burst_n := 0                # the size of this burst
var _prev_hp := 0.0              # the planned health of the wave before (no easy waves; 0 = none)
var _wave_n := 0                 # enemies in this wave (the quick clear)
var _ruined_snap: Array = []     # buildings already in ruins when the wave started (the intact bonus)
var _down_snap: Dictionary = {}  # defence pieces already down when the wave started: {piece id: true}
var _fire_out_wave := false      # the campfire went out during this wave
var _grub_at := -1.0             # seconds into the wave the Golden Grub comes (-1: not in this wave)
var _totem_at := -1.0            # seconds into the wave the Gloom Totem grows (-1: not in this wave)
var _totem_road := 0
var _say_t := -1.0               # a banner held back while the wave's own banner shows (seconds of wave time)
var _say: Array = []             # [title, colour, sub]
var _early_pay := 0              # leaves paid for going on early, shown when the wave starts
var last_pay: Dictionary = {}    # the last mission wave held: {"wave", "bonus", "quick", "intact", "timber"} (the tests read it)
var barricade_gift := 0          # leaves the last win paid for the first barricades (mission 1's first win; the tests read it)
var last_fall_lost := 0          # leaves the last camp fall took (camp_falls; the tests read it)


func info() -> Dictionary:
	return raid if mode == "raid" else Data.mission(mission)


func _cfg() -> Dictionary:
	return Data.b["mission"]


## A Phase F block of the "mission" settings ("roads", "burst", "bonus", "golden_grub", "totem"); {} when missing.
func _sub(key: String) -> Dictionary:
	var d = _cfg().get(key, {})
	return d if d is Dictionary else {}


func waves() -> int:
	return int(info()["waves"])


func chapter_waves() -> int:
	return int(_cfg()["chapter_waves"])


## The chapter a wave belongs to, 0-based.
func chapter_of(w: int) -> int:
	return (maxi(w, 1) - 1) / chapter_waves()


func chapter() -> int:
	return chapter_of(wave)


func chapters() -> int:
	return int(ceil(float(waves()) / float(chapter_waves())))


func chapter_name(c: int) -> String:
	var chs: Array = info()["chapters"]
	return String(chs[clampi(c, 0, chs.size() - 1)]["name"])


## Leaves and timber, scaled up for later missions.
func _pay_scale() -> float:
	if mode == "raid":
		return 1.0
	return 1.0 + float(_cfg()["pay_per_mission"]) * mission


## At most this many enemies on the field at once (raids: by graphics level; missions: the group's, wave_limits).
func _max_alive() -> int:
	return int(raid["max_alive"]) if mode == "raid" else int(wave_limits()["max_alive"])


## Phase G1: this mission's wave limits, from its group in mission.wave_limits.groups (the first whose `to_mission`,
## 1-based, reaches it; past the last group, the last): {"max_alive", "tanks_at_once", "tank_share"}. Old data without
## them: the old `max_alive` and no tank limits.
func wave_limits() -> Dictionary:
	var out := {"max_alive": int(_cfg().get("max_alive", 28)), "tanks_at_once": 999.0, "tank_share": 1.0}
	var groups = _sub("wave_limits").get("groups", [])
	if not (groups is Array) or (groups as Array).is_empty():
		return out
	var num := mission + 1
	var pick: Dictionary = {}
	var best := 1 << 30
	for g in groups:
		if g is Dictionary and int(g.get("to_mission", 0)) >= num and int(g.get("to_mission", 0)) < best:
			best = int(g.get("to_mission", 0))
			pick = g
	if pick.is_empty():
		for g in groups:                            # a mission past every group: the last group's limits
			if g is Dictionary and (pick.is_empty() or int(g.get("to_mission", 0)) > int(pick.get("to_mission", 0))):
				pick = g
	out["max_alive"] = int(pick.get("max_alive", out["max_alive"]))
	out["tanks_at_once"] = float(pick.get("tanks_at_once", out["tanks_at_once"]))
	out["tank_share"] = float(pick.get("tank_share", out["tank_share"]))
	return out


## Phase G1: how much of a tank kind counts (mission.wave_limits.tank_weight: the big ones 1, the boar a half; every
## other kind 0). A boss never counts.
func tank_weight(kind: String) -> float:
	var tw = _sub("wave_limits").get("tank_weight", {})
	if not (tw is Dictionary):
		return 0.0
	var e = (Data.b["enemies"] as Dictionary).get(kind, {})
	if e is Dictionary and bool(e.get("boss", false)):
		return 0.0
	return float(tw.get(kind, 0.0))


## A kind's planned health (its hp before the wave's strength).
func _kind_hp(kind: String) -> float:
	var e = (Data.b["enemies"] as Dictionary).get(kind, {})
	return float(e.get("hp", 0.0)) if e is Dictionary else 0.0


## A wave foe on the field that is its boss: a boss kind, or one of the last wave's `boss` enemies (_spawn_next marks
## them "wave_boss").
func _is_boss_foe(e) -> bool:
	if e.has_meta("wave_boss"):
		return true
	var d = (Data.b["enemies"] as Dictionary).get(String(e.get("id")), {})
	return d is Dictionary and bool(d.get("boss", false))


## Phase G1: the wave's foes on the field now (the bonus runners left out): {"n": how many, "tank": their summed tank
## weight (bosses never count), "bosses": bosses alive, "others": the rest}.
func field_state() -> Dictionary:
	var n := 0
	var tank := 0.0
	var bosses := 0
	for e in get_tree().get_nodes_in_group("foes"):
		if e.is_in_group("bonus"):
			continue
		n += 1
		if _is_boss_foe(e):
			bosses += 1
		else:
			tank += tank_weight(String(e.get("id")))
	return {"n": n, "tank": tank, "bosses": bosses, "others": n - bosses}


## Raids are seeded (the same raid comes back after a restart); missions stay random.
func _rand() -> float:
	return _rng.randf() if mode == "raid" else randf()


# ---------------------------------------------------------------- starting
## Starts mission i. If the save holds a run of it (Save.mission_run), it goes on from the start of that chapter.
## Unfinished missions stay sequential. Completed ones can be replayed; a different saved run must be resumed or given up.
func start_mission(i: int) -> void:
	if active or Save.fire_ruined or bool(Save.raids.get("pending", false)) or main.area != null:
		return                                      # a raid at the gate is met first: it cannot be dodged (nor while below ground)
	var idx := clampi(i, 0, Data.mission_count() - 1)
	if Save.mission_run.has("mission") and int(Save.mission_run["mission"]) != idx:
		return                                      # keep the saved mission until the player resumes or explicitly gives it up
	if not skip_gate and Data.has_method("mission_unlocked") and not bool(Data.call("mission_unlocked", idx)):
		return                                      # the safety net: the signpost does not offer it either
	mode = "mission"
	raid = {}
	warning = false
	mission = idx
	var held_wave := 0
	var gain := 0
	if int(Save.mission_run.get("mission", -1)) == mission:
		held_wave = clampi(int(Save.mission_run.get("wave_done", int(Save.mission_run.get("chapter", 0)) * chapter_waves())), 0, waves() - 1)
		gain = maxi(0, int(Save.mission_run.get("gain", 0)))   # a run resumed: what that chapter had gained stays counted
	elif not Save.mission_run.is_empty():
		Save.mission_run = {}                       # another mission was picked: the old run is given up
	active = true
	on_break = false
	last_stand = false
	rebuilt = false
	total_t = 0.0
	_endgame_run = Data.raids_open()
	_ruined_at_start = Save.ruined.duplicate()
	Data.set_meal(Save.meal_on)                       # a wave checkpoint retains the dish already being eaten
	gate_max = float(Data.fire_hp())
	gate_hp = gate_max
	_first = mission == 0 and not Save.missions_done.has(String(info()["id"]))
	plan = {}
	next_plan = {}
	_prev_hp = 0.0                                  # the chapter's first wave is never made stronger (no easy waves)
	_early_pay = 0
	_say = []
	_say_t = -1.0
	wave = held_wave
	_save_run(chapter_of(wave + 1), gain, wave)
	main.stations.reset_hp()
	main.on_stage_start()
	_start_wave(wave + 1)


## Older callers (the signpost, the tests) still say "stage".
func start_stage(i: int) -> void:
	start_mission(i)


## The run saved at the start of chapter c. `gain`: the leaves that chapter has gained so far (0 for a new chapter;
## Save's leaves setter adds to it while the chapter is played, see chapter_gain).
func _save_run(c: int, gain := 0, held_wave := -1) -> void:
	Save.mission_run = {"mission": mission, "chapter": c, "gain": gain,
		"wave_done": c * chapter_waves() if held_wave < 0 else held_wave}
	Save.save_game()


## The leaves gained since this chapter began (Save.mission_run "gain"): every leaf that came in while the chapter was
## played (Save.count_gain: kill drops, wave pay, bonuses, sales, anything), kept across an app restart with the run.
## A held chapter's chest is safe (the next chapter starts at 0, _chapter_done); nothing is counted in a chapter break,
## outside a mission, or in a Gloom Raid. A camp fall takes raid.leaves_share of it (camp_falls), so the leaves saved
## before the chapter are safe.
func chapter_gain() -> int:
	return maxi(0, int(Save.mission_run.get("gain", 0)))


## The saved run is dropped: the mission starts from wave 1 next time.
func give_up_run() -> void:
	if active:
		return
	Save.mission_run = {}
	Save.save_game()


## Enemy strength for wave w: the mission's base (times its `strength_mult`), then a little more every wave.
func strength(w := -1) -> float:
	var m := _cfg()
	var ww := wave if w < 0 else w
	if mode == "raid":
		return float(raid["strength"]) * (1.0 + float(raid["wave_ramp"]) * (maxi(ww, 1) - 1))
	var base := (float(m["base_strength"]) + float(m["strength_per_mission"]) * mission) * float(info().get("strength_mult", 1.0))
	return base * (1.0 + float(m["wave_ramp"]) * (maxi(ww, 1) - 1))


# ---------------------------------------------------------------- a wave
func _start_wave(w: int) -> void:
	if mode == "raid":
		_rng.seed = hash([int(raid["seed"]), w])
		warning = false
	wave = w
	wave_t = 0.0
	_breather = 0.0
	on_break = false
	in_wave = true
	Save.count_gain = mode != "raid"                # a mission chapter is played: its leaves count (chapter_gain)
	var last := w == waves()
	var elite := not last and w % chapter_waves() == 0 and mode != "raid"
	if mode == "raid":
		_raid_queue(w, last)
	else:
		_mission_queue(w, elite, last)
	_spawn_t = float(raid["assault"]["opening_delay"]) if mode == "raid" else 1.0
	_quiet_t = 0.0
	Sfx.play("horn", -8.0)
	main.on_wave_start(w, elite, last)
	if mode != "raid":
		_wave_news(elite, last)


## One seeded raid roster. Groups use different shuffled trails; they overlap in time, without round breaks.
## Member IDs stay stable so a resumed assault never recreates enemies already defeated.
func _raid_queue(_w: int, _last: bool) -> void:
	plan = {}
	_queue.clear()
	_qinfo.clear()
	var assault: Dictionary = raid["assault"]
	var sizes: Array = assault["group_size"]
	var gaps: Array = assault["group_gap"]
	var total := int(raid["enemy_count"])
	var defeated: Array = Save.raids.get("run", {}).get("defeated", [])
	var roads: Array = []
	var previous_road := -1
	var group := 0
	var member := 0
	while member < total:
		if roads.is_empty():
			roads = (raid["lanes"] as Array).duplicate()
			for i in range(roads.size() - 1, 0, -1):
				var j := _rng.randi_range(0, i)
				var swap: int = roads[i]
				roads[i] = roads[j]
				roads[j] = swap
			if roads.size() > 1 and int(roads.back()) == previous_road:
				var swap: int = roads[0]
				roads[0] = roads.back()
				roads[roads.size() - 1] = swap
		var road := int(roads.pop_back())
		previous_road = road
		var size := mini(total - member, _rng.randi_range(int(sizes[0]), int(sizes[1])))
		var gap := _rng.randf_range(float(gaps[0]), float(gaps[1]))
		for i in size:
			var kind := _pick_kind(raid["chapters"][0]["pool"])
			## The leader joins last in the scheduled roster.
			if member == total - 1 and String(raid["leader"]) != "":
				kind = String(raid["leader"])
			if not defeated.has(member):
				_queue.append(kind)
				_qinfo.append([road, group, gap if i == size - 1 else float(assault["member_gap"]), member])
			member += 1
		group += 1
	_wave_n = _queue.size()
	var summons: Array = Save.raids.get("run", {}).get("summons", [])
	for i in summons.size():
		var id := total + i
		if not defeated.has(id):
			_queue.append(String(summons[i]["kind"]))
			_qinfo.append([int(summons[i]["lane"]), group + i, float(assault["member_gap"]), id])


## A mission's wave: its roads (planned in the breather, or now), its enemies and their roads, and the extras.
func _mission_queue(w: int, elite: bool, last: bool) -> void:
	plan = next_plan if int(next_plan.get("wave", -1)) == w else plan_wave(w)
	next_plan = {}
	var q := plan_queue(w, plan, _prev_hp)
	_prev_hp = float(q["hp"])
	_queue = q["kinds"]
	_qinfo = q["info"]
	_wave_n = _queue.size()
	_burst_left = 0
	_say = []
	_say_t = -1.0
	# the extras: the Golden Grub and the Gloom Totem come in ordinary waves only (not elite, not the boss)
	var ordinary := not elite and not last
	_grub_at = -1.0
	var gg := _sub("golden_grub")
	if ordinary and mission >= int(gg.get("from_mission", 999)) and randf() < float(gg.get("chance", 0.0)):
		var ga: Array = gg.get("at_s", [8.0, 25.0])
		_grub_at = randf_range(float(ga[0]), float(ga[1]))
	_totem_at = -1.0
	var tt := _sub("totem")
	if ordinary and mission >= int(tt.get("from_mission", 999)) and randf() < float(tt.get("chance", 0.0)):
		var ta: Array = tt.get("at_s", [3.0, 10.0])
		_totem_at = randf_range(float(ta[0]), float(ta[1]))
		_totem_road = int((plan["roads"] as Array).pick_random())
	# the intact bonus: what is already down does not count against this wave
	_ruined_snap = Save.ruined.duplicate()
	_down_snap = _defences_down()
	_fire_out_wave = false


## Wave w's enemies for a mission, nothing spawned: {"kinds": [kind, ...] in the order they come, "info": [[road,
## speed x, tag, squad, spot, leads], ...] side by side (tag "" for the ordinary ones, "elite", "boss"; squad: the
## squad's number in the wave, its members side by side in the queue; spot: the member's place in the formation,
## squad_offsets; leads: true for the squad's leader), "squads": the squads in the order they come ({"id", "kinds",
## "tag", "lead", "road", ...}), "hp": the planned health (the kinds' hp x strength; "hp0" before the swaps), "tank":
## the wave's tank weight (bosses never count), "tank_cap": the most it may have, "swaps": squads swapped for stronger
## ones so it is no easy wave ("short": still weaker than allowed when no swap was left), "count": the wave's count of
## ordinary enemies and "ord" how many it has, "types" (squad types) and "need" (how many it should have), "share" (the
## biggest share of one kind) and "share_ok", "filler" (the Scouts filled in for the tank share)}. `p` is the wave's road
## plan (plan_wave); `prev_hp` the planned health of the wave before (0: none). Phase G1b:
##   squads     the chapter's squads (by weight; its first `first_waves` waves only its first) are added until the
##              wave's ordinary enemies reach its count (the mission's `count` for the wave, x the boss wave's
##              `boss_adds`, x the plan's `count`): a squad may take it over by at most 3, it stops at most 2 short.
##   rules      (mission.squad_rules) from mission `mixed_from` at least `min_types` squad types (when the chapter
##              lists that many); from mission `share_from` no kind over `max_kind_share` of the wave (a few tries, the
##              best kept; when none manages it, the best is accepted). The G1 tank share holds in whole squads: a
##              squad that would break it is not picked (when no squad of the chapter fits, `filler`, the Scouts).
##   elites     each elite leads its own squad: a squad marked "elite" with its kind (the Chief's Band), else the elite
##              and `elite_escort` light ones of the chapter's squads (their escorts count in the wave's count).
##   the boss   with the mission's `boss_escort` squads each `boss` enemy comes alone and the escort squads beside it;
##              without them each leads `boss_escort_light` (2) light ones. The chapter's squads fill the rest.
##   no easy waves  the weakest squad is swapped for a stronger one of the chapter (its biggest roll, or another
##              squad) within the count, the tank share, the squad types and the share rule (_swap_up); never for a
##              chapter's first wave or the boss wave.
##   roads      the chapter's squads take turns on the plan's roads (wave_roads: one road per squad); the elites'
##              squads flank; the boss and its escorts come out of the mission's own woods. Those walk in after the
##              first squad (`leader_at` enemies).
## Old data without squads: _pool_queue (Phase F/G1).
func plan_queue(w: int, p: Dictionary, prev_hp: float) -> Dictionary:
	var c := chapter_of(w)
	var chs: Array = info()["chapters"]
	var ch: Dictionary = chs[mini(c, chs.size() - 1)]
	var list := _squad_list(ch, w)
	if list.is_empty():
		return _pool_queue(w, p, prev_hp)
	var r := squad_rules()
	var last := w == waves()
	var elite := not last and w % chapter_waves() == 0
	var n := _wave_count(w, p)
	var lights := _light_kinds(_squad_list(ch, w, false))
	# the elites' or the boss's squads first: they are never dropped
	var fixed: Array = []
	var room := n                                   # ordinary enemies still free in the wave's count
	if last:
		var esc: Array = info().get("boss_escort", [])
		var own := int(r.get("boss_escort_light", 2))
		for pair in info().get("boss", []):
			for k in int(pair[1]):
				var bs: Dictionary
				if esc.is_empty():
					bs = _led_squad(String(pair[0]), "boss", lights, [own, own], room)
				else:
					bs = _squad_of("boss:" + String(pair[0]), [String(pair[0])], "boss", 0)
				room -= (bs["kinds"] as Array).size() - 1
				fixed.append(bs)
		for id in esc:
			if not squad_def(String(id)).is_empty():
				var es := _roll_squad(String(id))
				room -= (es["kinds"] as Array).size()
				fixed.append(es)
	elif elite:
		var ebc: Array = info().get("elite_by_chapter", [])
		var times := int(ebc[c]) if c < ebc.size() else c + 1
		var ee: Array = r.get("elite_escort", [2, 3])
		for pair in info().get("elite", []):
			for k in int(pair[1]) * times:
				var ls := _led_squad(String(pair[0]), "elite", lights, ee, room)
				room -= (ls["kinds"] as Array).size() - 1
				fixed.append(ls)
	for s in fixed:
		s["fixed"] = true
	var need := 0
	if mission + 1 >= int(r.get("mixed_from", 1 << 30)):
		need = mini(int(r.get("min_types", 2)), list.size())
	var fill := _fill_squads(list, n, fixed, need)
	var st := strength(w)
	var hp := float(_squads_stats(fixed + fill)["hp"]) * st
	var hp0 := hp
	# no easy waves: at least min_wave_ratio of the wave before (not after a chapter break, not the boss wave): the
	# weakest squad is swapped for a stronger one, within the wave's rules; when no swap helps, it stops
	var swaps := 0
	var short := false
	if not last and prev_hp > 0.0 and (w - 1) % chapter_waves() != 0:
		var want := prev_hp * float(_cfg().get("min_wave_ratio", 0.85))
		var guard := 4 * fill.size() + 4
		while hp < want and guard > 0:
			guard -= 1
			if not _swap_up(list, n, fixed, fill, need):
				break
			swaps += 1
			hp = float(_squads_stats(fixed + fill)["hp"]) * st
		short = hp < want - 0.01
	# the roads: the chapter's squads take turns on the plan's roads (a rush's are faster); the elites' squads flank;
	# the boss and its escorts come out of the mission's own woods
	var order: Array = fill.duplicate()
	order.shuffle()                                 # the picks that made the types come first: mix them
	var roads := wave_roads(p, order.size())
	for j in order.size():
		order[j]["road"] = int(roads[j])
	var sp_road := int(p.get("fav", 0)) if last else int(p.get("flank", p.get("fav", 0)))
	# the elites' or the boss's squads walk in near the front, after the first `leader_at` ordinary enemies
	var at := 0
	var cum := 0
	while at < order.size() and cum < int(info().get("leader_at", 2)):
		cum += (order[at]["kinds"] as Array).size()
		at += 1
	for j in fixed.size():
		fixed[j]["road"] = sp_road
		order.insert(at + j, fixed[j])
	var fast := float(p.get("speed", 1.0))
	var kinds: Array = []
	var qi: Array = []
	for si in order.size():
		var s: Dictionary = order[si]
		var ks: Array = s["kinds"]
		var lead := int(s["lead"])
		var offs := squad_offsets(ks, lead)
		var spd := 1.0 if s.has("fixed") else fast
		for j in ks.size():
			kinds.append(String(ks[j]))
			qi.append([int(s["road"]), spd, String(s["tag"]) if j == lead else "", si, offs[j], j == lead])
	var all := _squads_stats(order)
	var lim := float(r.get("max_kind_share", 1.0))
	var share_on := mission + 1 >= int(r.get("share_from", 1 << 30))
	var tank_cap := maxf(float(wave_limits()["tank_share"]) * float(kinds.size()), float(_squads_stats(fixed)["tank"]))
	var filler := false
	for s in fill:
		filler = filler or s.has("filler")
	return {"kinds": kinds, "info": qi, "squads": order, "hp": hp, "hp0": hp0, "tank": float(all["tank"]), "tank_cap": tank_cap,
		"swaps": swaps, "short": short, "count": n, "ord": int(all["ord"]), "types": (all["types"] as Dictionary).size(),
		"need": need, "share": float(all["share"]), "share_ok": not share_on or float(all["share"]) <= lim + 0.001,
		"filler": filler}


## The ordinary enemies wave w should have: the mission's `count` for it (the boss wave x `boss_adds`: the boss brings
## fewer friends), x the plan's `count` (roads.rush_count: 1.0 since Phase G1, a rush is faster, not bigger).
func _wave_count(w: int, p: Dictionary) -> int:
	var cnt: Array = info()["count"]
	var t := float(w - 1) / float(maxi(1, waves() - 1))
	var n := int(round(lerpf(float(cnt[0]), float(cnt[1]), t)))
	if w == waves():
		n = int(round(n * float(info().get("boss_adds", _cfg().get("boss_adds", 0.6)))))
	return int(round(n * float(p.get("count", 1.0))))


# ---------------------------------------------------------------- squads (Phase G1b, missions)
## The squad rules (mission.squad_rules; {} when missing).
func squad_rules() -> Dictionary:
	return _sub("squad_rules")


## A kind's role in a squad (balance.json enemy_roles: "light", "fighter", "tank", "support", "leader"; "" when none).
func role_of(kind: String) -> String:
	var roles = Data.b.get("enemy_roles", {})
	var r = roles.get(kind, "") if roles is Dictionary else ""
	return String(r) if r is String else ""


## Squad id's data (balance.json squads: "members" [{"kind", "n": [min, max]}], "from_mission", "elite"); {} when none.
func squad_def(id: String) -> Dictionary:
	var sq = Data.b.get("squads", {})
	var d = sq.get(id, {}) if sq is Dictionary else {}
	return d if d is Dictionary else {}


## The chapter's squads for wave w, [[id, weight], ...] (only the ones balance.json defines). `first`: the chapter's
## first `first_waves` waves use only its first entry. [] when the chapter lists none (old data: its pool is used).
func _squad_list(ch: Dictionary, w: int, first := true) -> Array:
	var out: Array = []
	for pair in ch.get("squads", []):
		if pair is Array and (pair as Array).size() >= 2 and float(pair[1]) > 0.0 and not squad_def(String(pair[0])).is_empty():
			out.append([String(pair[0]), float(pair[1])])
	if first and not out.is_empty() and (w - 1) % chapter_waves() < int(ch.get("first_waves", 0)):
		out = [out[0]]
	return out


## The light kinds in a list of squads, weighted by the squads' weights ([[kind, weight], ...]; none: the Thornling).
func _light_kinds(list: Array) -> Array:
	var wts := {}
	for pair in list:
		for m in squad_def(String(pair[0])).get("members", []):
			var k := String((m as Dictionary).get("kind", "")) if m is Dictionary else ""
			if role_of(k) == "light":
				wts[k] = float(wts.get(k, 0.0)) + float(pair[1])
	var out: Array = []
	for k in wts:
		out.append([k, wts[k]])
	return out if not out.is_empty() else [["thornling", 1.0]]


## A squad's members, each member's n rolled in [min, max] ("max" or "min": that end), in the data's order.
func _roll_kinds(id: String, how := "") -> Array:
	var kinds: Array = []
	for m in squad_def(id).get("members", []):
		if not (m is Dictionary) or not (Data.b["enemies"] as Dictionary).has(String(m.get("kind", ""))):
			continue
		var nn: Array = m.get("n", [1, 1])
		var lo := int(nn[0]) if not nn.is_empty() else 1
		var hi := maxi(lo, int(nn[nn.size() - 1]) if not nn.is_empty() else 1)
		var k := hi if how == "max" else (lo if how == "min" else randi_range(lo, hi))
		for j in k:
			kinds.append(String(m["kind"]))
	return kinds


## One squad of id, its members rolled (_roll_kinds).
func _roll_squad(id: String, how := "") -> Dictionary:
	return _squad_of(id, _roll_kinds(id, how))


## A squad of these kinds: {"id", "kinds", "tag" (its leader's: "", "elite", "boss"), "lead" (its leader's index; -1:
## squad_leader_index), "tank" (its tank weight: a boss leader never counts), "hp" (its kinds' hp), "road"}.
func _squad_of(id: String, kinds: Array, tag := "", lead := -1) -> Dictionary:
	var ld := lead if lead >= 0 and lead < kinds.size() else squad_leader_index(kinds)
	var tw := 0.0
	var hp := 0.0
	for j in kinds.size():
		hp += _kind_hp(String(kinds[j]))
		if not (tag == "boss" and j == ld):
			tw += tank_weight(String(kinds[j]))
	return {"id": id, "kinds": kinds, "tag": tag, "lead": ld, "tank": tw, "hp": hp, "road": -1}


## A squad id's range: {"min", "max": its smallest and biggest size, "tank": its tank weight at its biggest, "kinds":
## {kind: how many at most}}.
func _squad_span(id: String) -> Dictionary:
	var lo := _roll_kinds(id, "min").size()
	var big := _roll_kinds(id, "max")
	var tw := 0.0
	var ks := {}
	for k in big:
		tw += tank_weight(String(k))
		ks[String(k)] = int(ks.get(String(k), 0)) + 1
	return {"min": lo, "max": big.size(), "tank": tw, "kinds": ks}


## The member that leads a squad of these kinds (its index): its leader kind (the Thornling Chief), else its tank, else
## its fighter, else its first member that is not support, else the first.
func squad_leader_index(kinds: Array) -> int:
	for want in ["leader", "tank", "fighter"]:
		for j in kinds.size():
			if role_of(String(kinds[j])) == want:
				return j
	for j in kinds.size():
		if role_of(String(kinds[j])) != "support":
			return j
	return 0


## A kind's body radius (balance.json enemies).
func _kind_radius(kind: String) -> float:
	var e = (Data.b["enemies"] as Dictionary).get(kind, {})
	return float(e.get("radius", 0.4)) if e is Dictionary else 0.4


## Each member's spot in its squad's formation, in its leader's frame (x: to the side, z: forward; the leader's is
## zero), side by side with kinds: the first two beside the leader, the rest in rows of three behind it, `spacing` m
## between bodies (mission.squad_rules); support members `support_behind` m further back than the last row.
func squad_offsets(kinds: Array, lead: int) -> Array:
	var r := squad_rules()
	var gap := float(r.get("spacing", 0.6))
	var back := float(r.get("support_behind", 2.5))
	var out: Array = []
	out.resize(kinds.size())
	if kinds.is_empty():
		return out
	var li := clampi(lead, 0, kinds.size() - 1)
	var rl := _kind_radius(String(kinds[li]))
	var front: Array = []
	var rear: Array = []
	for j in kinds.size():
		out[j] = Vector3.ZERO
		if j == li:
			continue
		if role_of(String(kinds[j])) == "support":
			rear.append(j)
		else:
			front.append(j)
	var depth := 0.0
	var cols := [0.0, 1.0, -1.0]                    # a row behind: straight behind, then to either side
	for k in front.size():
		var j: int = front[k]
		var rm := _kind_radius(String(kinds[j]))
		var o: Vector3
		if k < 2:
			o = Vector3((rl + rm + gap) * (1.0 if k == 0 else -1.0), 0.0, -rl * 0.5)     # beside the leader
		else:
			var row := (k - 2) / 3
			var col := float(cols[(k - 2) % 3])
			o = Vector3(col * (2.0 * rm + gap), 0.0, -(rl + rm + gap) - float(row) * (2.0 * rm + gap))
		depth = minf(depth, o.z)
		out[j] = o
	for k in rear.size():
		var j: int = rear[k]
		var rm := _kind_radius(String(kinds[j]))
		var x := (float(k) - float(rear.size() - 1) * 0.5) * (2.0 * rm + gap)
		out[j] = Vector3(x, 0.0, depth - back)
	return out


## The elite squad (balance.json squads with "elite": true) that has kind among its members; "" when none.
func _elite_band(kind: String) -> String:
	var sq = Data.b.get("squads", {})
	if not (sq is Dictionary):
		return ""
	for id in sq:
		var d = sq[id]
		if d is Dictionary and bool(d.get("elite", false)) and _roll_kinds(String(id), "min").has(kind):
			return String(id)
	return ""


## A squad led by kind (tag "elite" or "boss"): an elite's own squad marked "elite" when the data has one with its kind
## (the Chief's Band), else the leader and esc[0]..esc[1] light ones (`lights`, by weight). `room`: the ordinary enemies
## still free in the wave's count (an escort is cut to it).
func _led_squad(kind: String, tag: String, lights: Array, esc: Array, room: int) -> Dictionary:
	if tag == "elite":
		var band := _elite_band(kind)
		if band != "":
			var bk := _roll_kinds(band)
			var li := bk.find(kind)
			if li >= 0 and bk.size() - 1 <= room:
				return _squad_of(band, bk, tag, li)
	var kinds: Array = [kind]
	var lo := int(esc[0]) if not esc.is_empty() else 2
	var hi := maxi(lo, int(esc[esc.size() - 1]) if not esc.is_empty() else lo)
	for j in mini(randi_range(lo, hi), maxi(room, 0)):
		kinds.append(_pick_kind(lights))
	return _squad_of(tag + ":" + kind, kinds, tag, 0)


## A list of squads in numbers: {"n": its enemies, "ord": its ordinary ones (the leaders tagged "elite" or "boss" left
## out), "tank": its tank weight, "hp": its kinds' hp, "kinds": {kind: count}, "types": {squad id: true}, "share": the
## biggest share of one kind}.
func _squads_stats(squads: Array) -> Dictionary:
	var n := 0
	var ord := 0
	var tank := 0.0
	var hp := 0.0
	var kinds := {}
	var types := {}
	for s in squads:
		var ks: Array = s["kinds"]
		n += ks.size()
		ord += ks.size() - (0 if String(s["tag"]) == "" or ks.is_empty() else 1)
		tank += float(s["tank"])
		hp += float(s["hp"])
		types[String(s["id"])] = true
		for k in ks:
			kinds[String(k)] = int(kinds.get(String(k), 0)) + 1
	var top := 0
	for k in kinds:
		top = maxi(top, int(kinds[k]))
	return {"n": n, "ord": ord, "tank": tank, "hp": hp, "kinds": kinds, "types": types, "share": float(top) / float(maxi(n, 1))}


## The chapter's squads that bring a wave's ordinary enemies (with `fixed`: its elites' or boss's squads) to `want`:
## squad_rules.tries tries (8), the best kept (all the squad types it needs, then the smallest share of one kind, then
## no filler, then nearest its count).
func _fill_squads(list: Array, want: int, fixed: Array, need: int) -> Array:
	var r := squad_rules()
	var share_on := mission + 1 >= int(r.get("share_from", 1 << 30))
	var lim := float(r.get("max_kind_share", 1.0))
	var best: Array = []
	var best_sc := INF
	for t in maxi(1, int(r.get("tries", 8))):
		var out := _fill_once(list, want, fixed, need, share_on, lim)
		var st := _squads_stats(fixed + out)
		var bad := float(maxi(0, need - (st["types"] as Dictionary).size())) * 100.0
		if share_on:
			bad += maxf(0.0, float(st["share"]) - lim) * 10.0
		for s in out:
			if s.has("filler"):
				bad += 1.0
				break
		var sc := bad + absf(float(int(st["ord"]) - want)) * 0.01
		if sc < best_sc:
			best_sc = sc
			best = out
		if bad <= 0.0 and int(st["ord"]) == want:
			break
	return best


## One try at _fill_squads: squads by the chapter's weights, among the ones whose tank weight fits the wave's tank share
## at its smallest end, and leaves room to fill the rest with the chapter's lightest squads in tank weight (when none
## leaves that room, any that fits; none fits: the filler). Among those: a squad type the wave still needs first, else
## the ones that keep every kind within the share (none does: the ones that keep the biggest share lowest). A squad may
## take the wave over its count by at most 3; within 2 of it, only one that ends nearer it (or brings a type it needs)
## comes, else the wave stops there.
func _fill_once(list: Array, want: int, fixed: Array, need: int, share_on: bool, lim: float) -> Array:
	var tshare := float(wave_limits()["tank_share"])
	var fixed_w := float(_squads_stats(fixed)["tank"])
	var spans := {}
	var rate := INF                                 # the least tank weight per enemy of the chapter's squads
	for pair in list:
		var sp0 := _squad_span(String(pair[0]))
		spans[String(pair[0])] = sp0
		rate = minf(rate, float(sp0["tank"]) / float(maxi(1, int(sp0["max"]))))
	var out: Array = []
	for guard in want + 8:
		var st := _squads_stats(fixed + out)
		var ord := int(st["ord"])
		var gap := want - ord
		if gap <= 0:
			break
		var types: Dictionary = st["types"]
		var others := int(st["n"]) - ord
		var fit: Array = []
		var roomy: Array = []
		for pair in list:
			var sp: Dictionary = spans[String(pair[0])]
			var low := others + maxi(ord + int(sp["min"]), want - 2)    # the wave's enemies at the least
			var cap := maxf(tshare * low, fixed_w) + 0.001
			var tw := float(st["tank"]) + float(sp["tank"])
			if tw <= cap:
				fit.append(pair)
				if tw + rate * maxi(0, want - 2 - ord - int(sp["min"])) <= cap:
					roomy.append(pair)              # the rest can still come within the tank share
		if not roomy.is_empty():
			fit = roomy
		var sq: Dictionary
		var adds_type := false
		var id := ""
		if fit.is_empty():
			sq = _filler_squad()                    # no squad of the chapter fits the tank share
		else:
			var pick_from := fit
			if types.size() < need:
				var fresh := fit.filter(func(pr): return not types.has(String(pr[0])))
				if not fresh.is_empty():
					pick_from = fresh
			elif share_on:
				var keep := fit.filter(func(pr): return _keeps_share(String(pr[0]), st, want, lim))
				if not keep.is_empty():
					pick_from = keep
				else:
					var low_sh := INF               # none keeps it: the ones that keep the biggest share lowest
					var shs := {}
					for pr in fit:
						shs[String(pr[0])] = _share_after(String(pr[0]), st, want)
						low_sh = minf(low_sh, float(shs[String(pr[0])]))
					pick_from = fit.filter(func(pr): return float(shs[String(pr[0])]) <= low_sh + 0.02)
			id = _pick_kind(pick_from)
			adds_type = types.size() < need and not types.has(id)
			sq = _roll_squad(id)
		if not _size_ok((sq["kinds"] as Array).size(), gap, adds_type):
			var small: Dictionary = _roll_squad(id, "min") if id != "" else sq
			if _size_ok((small["kinds"] as Array).size(), gap, adds_type):
				sq = small
			elif gap <= 2:
				break                               # near enough its count
		if (sq["kinds"] as Array).is_empty():
			break
		out.append(sq)
	return out


## A squad of sz enemies fits what is left of a wave's count (gap): never more than 3 over; within 2 of the count only
## when it ends nearer it (or brings a squad type the wave still needs).
func _size_ok(sz: int, gap: int, adds_type: bool) -> bool:
	if sz - gap > 3:
		return false
	return gap > 2 or adds_type or sz - gap <= gap


## Squad id keeps every kind of the wave (its numbers `st`, see _squads_stats) within lim of the wave's enemies, at its
## biggest roll (the wave counted at its planned size, `want` ordinary enemies, or more).
func _keeps_share(id: String, st: Dictionary, want: int, lim: float) -> bool:
	var sp := _squad_span(id)
	var kinds: Dictionary = st["kinds"]
	var total := float(int(st["n"]) - int(st["ord"]) + maxi(want, int(st["ord"]) + int(sp["max"])))
	var add: Dictionary = sp["kinds"]
	for k in add:
		if float(int(kinds.get(k, 0)) + int(add[k])) > lim * total + 0.001:
			return false
	return true


## The biggest share of one kind in the wave (its numbers `st`) with squad id added at its biggest roll (the wave
## counted as in _keeps_share).
func _share_after(id: String, st: Dictionary, want: int) -> float:
	var sp := _squad_span(id)
	var kinds: Dictionary = (st["kinds"] as Dictionary).duplicate()
	var add: Dictionary = sp["kinds"]
	for k in add:
		kinds[k] = int(kinds.get(k, 0)) + int(add[k])
	var top := 0
	for k in kinds:
		top = maxi(top, int(kinds[k]))
	var total := float(int(st["n"]) - int(st["ord"]) + maxi(want, int(st["ord"]) + int(sp["max"])))
	return float(top) / maxf(total, 1.0)


## The squad that fills in when no squad of the chapter fits the wave's tank share: squad_rules.filler (the Scouts; it
## must have no tank), else three Thornlings. Marked "filler".
func _filler_squad() -> Dictionary:
	var id := String(squad_rules().get("filler", "scouts"))
	var sq: Dictionary = _roll_squad(id) if not squad_def(id).is_empty() else {}
	if sq.is_empty() or float(sq["tank"]) > 0.0 or (sq["kinds"] as Array).is_empty():
		sq = _squad_of("filler", ["thornling", "thornling", "thornling"])
	sq["filler"] = true
	return sq


## No easy waves (Phase G1b): the weakest squad of `fill` that a stronger one of the chapter (its biggest roll, another
## roll, or another squad) can replace, keeping the wave's ordinary enemies within n - 2 .. n + 3, its tank share, its
## squad types (as many as it needs) and the share rule (no worse than now), is swapped (by the chapter's weights among
## the ones that help). `fill` changes in place. False when no swap helps.
func _swap_up(list: Array, n: int, fixed: Array, fill: Array, need: int) -> bool:
	var r := squad_rules()
	var share_on := mission + 1 >= int(r.get("share_from", 1 << 30))
	var tshare := float(wave_limits()["tank_share"])
	var before := _squads_stats(fixed + fill)
	var fixed_w := float(_squads_stats(fixed)["tank"])
	var types_min := mini(need, (before["types"] as Dictionary).size())
	var share_max := maxf(float(r.get("max_kind_share", 1.0)), float(before["share"]))
	var lo := mini(n - 2, int(before["ord"]))
	var hi := maxi(n + 3, int(before["ord"]))
	var order: Array = range(fill.size())
	order.sort_custom(func(a, b): return float(fill[a]["hp"]) < float(fill[b]["hp"]))
	for i in order:
		var old: Dictionary = fill[i]
		var opts: Array = []                        # [squad, weight]
		for pair in list:
			for how in ["max", "", "min"]:
				var sq := _roll_squad(String(pair[0]), how)
				if float(sq["hp"]) <= float(old["hp"]) + 0.001:
					continue
				var trial := fill.duplicate()
				trial[i] = sq
				var tst := _squads_stats(fixed + trial)
				if int(tst["ord"]) < lo or int(tst["ord"]) > hi:
					continue
				if float(tst["tank"]) > maxf(tshare * float(tst["n"]), fixed_w) + 0.001:
					continue
				if (tst["types"] as Dictionary).size() < types_min:
					continue
				if share_on and float(tst["share"]) > share_max + 0.001:
					continue
				opts.append([sq, float(pair[1])])
				break                               # one option per squad: its biggest roll that fits
		if opts.is_empty():
			continue
		var total := 0.0
		for o in opts:
			total += float(o[1])
		var pick := randf() * total
		for o in opts:
			pick -= float(o[1])
			if pick <= 0.0:
				fill[i] = o[0]
				return true
		fill[i] = opts.back()[0]
		return true
	return false


## The old way (Phase F/G1, a chapter without `squads`): wave w's enemies one by one from the chapter's pool. The same
## shape as plan_queue's (its info [road, speed x, tag] only: no squads); its count is exactly _wave_count's, plus the
## elites or the boss; nothing here adds or drops an enemy.
func _pool_queue(w: int, p: Dictionary, prev_hp: float) -> Dictionary:
	var c := chapter_of(w)
	var chs: Array = info()["chapters"]
	var ch: Dictionary = chs[mini(c, chs.size() - 1)]
	var n := _wave_count(w, p)
	var last := w == waves()
	var elite := not last and w % chapter_waves() == 0
	var pool: Array = ch["pool"]
	if ch.has("pool_first") and (w - 1) % chapter_waves() < int(ch.get("first_waves", 0)):
		pool = ch["pool_first"]                     # the chapter's first waves: an easier mix
	var kinds: Array = []
	for k in n:
		kinds.append(_pick_kind(pool))
	var special: Array = []                         # [kind, tag]
	if last:
		for pair in info().get("boss", []):
			for k in int(pair[1]):
				special.append([String(pair[0]), "boss"])
	elif elite:
		var ebc: Array = info().get("elite_by_chapter", [])
		var times := int(ebc[c]) if c < ebc.size() else c + 1
		for pair in info().get("elite", []):
			for k in int(pair[1]) * times:
				special.append([String(pair[0]), "elite"])
	# Phase G1, tanks in a whole wave: at most tank_share x its enemies in tank weight (never less than its elites' own
	# weight: an elite or a boss is never dropped); an extra tank pick becomes one of the pool's other kinds
	var elite_w := 0.0
	for s in special:
		if String(s[1]) == "elite":
			elite_w += tank_weight(String(s[0]))
	var tank_cap := maxf(float(wave_limits()["tank_share"]) * float(kinds.size() + special.size()), elite_w)
	var tank := elite_w
	for k in kinds.size():
		var tw := tank_weight(String(kinds[k]))
		if tw <= 0.0:
			continue
		if tank + tw > tank_cap + 0.001:
			kinds[k] = _pick_non_tank(pool)
		else:
			tank += tw
	var st := strength(w)
	var hp := 0.0
	for k in kinds:
		hp += _kind_hp(String(k)) * st
	for s in special:
		hp += _kind_hp(String(s[0])) * st
	# no easy waves: at least min_wave_ratio of the wave before (not after a chapter break, not the boss wave). Phase
	# G1: the weakest ordinary enemy is swapped for a stronger kind of the pool (non-tanks first; a tank only within the
	# tank share), never more enemies; when no swap helps, it stops
	var swaps := 0
	if not last and prev_hp > 0.0 and (w - 1) % chapter_waves() != 0:
		var want := prev_hp * float(_cfg().get("min_wave_ratio", 0.85))
		var guard := kinds.size() * maxi(1, pool.size()) + 1
		while hp < want and guard > 0:
			guard -= 1
			var weak := _weakest(kinds)
			if weak < 0:
				break
			var old := String(kinds[weak])
			var nk := _stronger_kind(pool, old, tank_cap - (tank - tank_weight(old)))
			if nk == "":
				break
			tank += tank_weight(nk) - tank_weight(old)
			hp += (_kind_hp(nk) - _kind_hp(old)) * st
			kinds[weak] = nk
			swaps += 1
	# the roads: the ordinary ones take turns on the plan's roads (a rush's are faster); the elites flank; the boss
	# comes out of the mission's own woods
	var roads := wave_roads(p, kinds.size())
	var fast := float(p.get("speed", 1.0))
	var qi: Array = []
	for k in kinds.size():
		qi.append([int(roads[k]), fast, ""])
	var sp_road := int(p.get("fav", 0)) if last else int(p.get("flank", p.get("fav", 0)))
	# the elite or the boss walk in near the front, after a few of the ordinary ones
	var at := mini(kinds.size(), int(info().get("leader_at", 2)))
	for s in special:
		kinds.insert(at, String(s[0]))
		qi.insert(at, [sp_road, 1.0, String(s[1])])
	return {"kinds": kinds, "info": qi, "hp": hp, "tank": tank, "tank_cap": tank_cap, "swaps": swaps}


## A non-tank kind of the pool, by its weight (the pool has none: a Thornling).
func _pick_non_tank(pool: Array) -> String:
	var soft: Array = []
	for pair in pool:
		if tank_weight(String(pair[0])) <= 0.0:
			soft.append(pair)
	return _pick_kind(soft) if not soft.is_empty() else "thornling"


## The index of the weakest kind in `kinds` (the first of the weakest; -1 when empty).
func _weakest(kinds: Array) -> int:
	var best := -1
	var low := INF
	for k in kinds.size():
		var h := _kind_hp(String(kinds[k]))
		if h < low:
			low = h
			best = k
	return best


## A kind of the pool stronger than `than`, by its weight: a non-tank if there is one, else a tank whose weight fits in
## `room`; "" when none.
func _stronger_kind(pool: Array, than: String, room: float) -> String:
	var base := _kind_hp(than)
	var soft: Array = []
	var hard: Array = []
	for pair in pool:
		var k := String(pair[0])
		if _kind_hp(k) <= base:
			continue
		var tw := tank_weight(k)
		if tw <= 0.0:
			soft.append(pair)
		elif tw <= room + 0.001:
			hard.append(pair)
	if not soft.is_empty():
		return _pick_kind(soft)
	if not hard.is_empty():
		return _pick_kind(hard)
	return ""


# ---------------------------------------------------------------- the roads (Phase F, missions)
## How wave w comes down the roads: {"wave", "pattern" ("surround", "pincer", "rush"; mission 1 also "one" and "two"),
## "roads", "fav" (the mission's own woods, lanes[0]), "flank" (the elites' road), "speed" and "count" (a rush: x the
## enemies' speed and x their number; the number is 1.0 since Phase G1)}. Shares from mission.roads; the boss wave
## surrounds.
func plan_wave(w: int) -> Dictionary:
	var rc := _sub("roads")
	var all := _road_order()
	var lanes: Array = info().get("lanes", [0])
	var fav := int(lanes[0]) if not lanes.is_empty() else 0
	var p := {"wave": w, "pattern": "surround", "roads": all.duplicate(), "fav": fav, "speed": 1.0, "count": 1.0}
	if mission == int(rc.get("teach_mission", 0)):
		# mission 1 teaches the roads: its own woods, then a neighbour too, then all four (no pincers or rushes)
		var by: Array = rc.get("teach_roads_by_chapter", [])
		var n := int(by[mini(chapter_of(w), by.size() - 1)]) if not by.is_empty() else all.size()
		if n <= 1:
			p["pattern"] = "one"
			p["roads"] = [fav]
		elif n < all.size():
			p["pattern"] = "two"
			p["roads"] = [fav, _neighbour(fav)]
		p["flank"] = _flank(all, fav, all) if String(p["pattern"]) == "surround" else int((p["roads"] as Array).back())
		return p
	if w != waves():
		var sur := float(rc.get("surround", 0.65))
		var pin := float(rc.get("pincer", 0.2))
		var r := randf() * (sur + pin + float(rc.get("rush", 0.15)))
		if r >= sur and r < sur + pin:
			p["pattern"] = "pincer"
			p["roads"] = _far_pair()
		elif r >= sur + pin:
			p["pattern"] = "rush"
			p["roads"] = [fav]
			p["speed"] = float(rc.get("rush_speed", 1.15))
			p["count"] = float(rc.get("rush_count", 1.0))   # Phase G1: 1.0, the same count (faster, not bigger)
	p["flank"] = _flank(p["roads"], fav, all)
	return p


## The road of each of n enemies: the plan's roads take turns (a smooth weighted round from a random start, so no road
## is skipped by chance); in a surround the mission's own woods count `favoured_weight`.
func wave_roads(p: Dictionary, n: int) -> Array:
	var roads: Array = (p.get("roads", [0]) as Array).duplicate()
	if roads.is_empty():
		roads = [int(p.get("fav", 0))]
	roads.shuffle()
	var fw := float(_sub("roads").get("favoured_weight", 1.0))
	var wts: Array = []
	var cur: Array = []
	var total := 0.0
	for r in roads:
		var wt := fw if String(p.get("pattern", "")) == "surround" and int(r) == int(p.get("fav", -1)) else 1.0
		wts.append(wt)
		cur.append(randf() * wt)
		total += wt
	var out: Array = []
	for k in n:
		var best := 0
		for j in roads.size():
			cur[j] = float(cur[j]) + float(wts[j])
			if float(cur[j]) > float(cur[best]):
				best = j
		cur[best] = float(cur[best]) - total
		out.append(int(roads[best]))
	return out


## The roads in their order round the camp (west to east, by the patches' angles): 3, 1, 0, 2 today.
func _road_order() -> Array:
	var order: Array = []
	for i in Data.patch_count():
		order.append(i)
	order.sort_custom(func(a, b): return float(Data.patch(a)["angle_deg"]) < float(Data.patch(b)["angle_deg"]))
	return order


## The road beside road r: of its two, the one nearer the middle of the woods (both can be watched at once).
func _neighbour(r: int) -> int:
	var o := _road_order()
	var k := o.find(r)
	var best := r
	if k < 0:
		return r
	for j in [k - 1, k + 1]:
		if j < 0 or j >= o.size():
			continue
		if best == r or absf(float(Data.patch(int(o[j]))["angle_deg"])) < absf(float(Data.patch(best)["angle_deg"])):
			best = int(o[j])
	return best


## Two roads far apart (never side by side): 0 and 3, 1 and 2, or the two outer ones; at random.
func _far_pair() -> Array:
	var o := _road_order()
	var pairs: Array = []
	for a in o.size():
		for b in range(a + 2, o.size()):
			pairs.append([int(o[a]), int(o[b])])
	if pairs.is_empty():
		return o.duplicate()
	return (pairs.pick_random() as Array).duplicate()


## The elites' road: one most of the wave does not come down (in a surround, any but the mission's own woods).
func _flank(roads: Array, fav: int, all: Array) -> int:
	var off: Array = []
	for r in all:
		if not roads.has(int(r)):
			off.append(int(r))
	if off.is_empty():
		for r in roads:
			if int(r) != fav:
				off.append(int(r))
	return int(off.pick_random()) if not off.is_empty() else fav


func _road_name(i: int) -> String:
	return String(Data.patch(clampi(i, 0, Data.patch_count() - 1))["name"])


## Where a planned wave comes from, in a few words: "every road", "Fernwood and Mossback's Den", "a rush from
## Fernwood!".
func roads_text(p: Dictionary) -> String:
	var rs: Array = p.get("roads", [])
	match String(p.get("pattern", "")):
		"surround":
			return "every road"
		"rush":
			return "a rush from %s!" % _road_name(int(rs[0]))
	var names: Array = []
	for r in rs:
		names.append(_road_name(int(r)))
	return " and ".join(names)


## The preview of the next wave in a breather or a chapter break ("Next: every road"), or "" when none is planned (a
## raid, a wave on). status_text shows it in a breather; the signpost's card may show it too.
func preview_text() -> String:
	if mode == "raid" or not active or in_wave or int(next_plan.get("wave", -1)) != wave + 1:
		return ""
	return "Next: " + roads_text(next_plan)


## The wave's own news after main.on_wave_start's banner or toast: a rush's warning, the pay for going on early.
func _wave_news(elite: bool, last: bool) -> void:
	var bannered := elite or last or (wave - 1) % chapter_waves() == 0   # main showed a banner (or the mission's title)
	if String(plan.get("pattern", "")) == "rush":
		var title_txt := "A rush from %s!" % _road_name(int(plan["roads"][0]))
		# Phase G1: a rush keeps its count (rush_count 1.0), so the line only says "more" when the data makes it bigger
		var sub := "More of them, and faster" if float(plan.get("count", 1.0)) > 1.001 else "All down one road, and faster"
		if bannered:
			_say = [title_txt, Color(1.0, 0.6, 0.4), sub]
			_say_t = 2.2                            # after the wave's own banner
		else:
			main.hud.banner(title_txt, Color(1.0, 0.6, 0.4), sub)
	if _early_pay > 0:
		if bannered:
			main.hud.toast("Early start: +%d leaves" % _early_pay)
		else:
			main.hud.toast("Wave %d of %d · early start +%d leaves" % [wave, waves(), _early_pay])
		_early_pay = 0


func _pick_lane() -> int:
	var lanes: Array = info()["lanes"]
	lane = int(lanes[mini(int(_rand() * lanes.size()), lanes.size() - 1)])
	return lane


func _pick_kind(pool: Array) -> String:
	var total := 0.0
	for pair in pool:
		total += float(pair[1])
	var r := _rand() * total
	for pair in pool:
		r -= float(pair[1])
		if r <= 0.0:
			return String(pair[0])
	return String(pool[0][0])


func _physics_process(delta: float) -> void:
	if not active or main.frozen:
		return
	var dt := minf(delta, 0.1)
	if not in_wave:
		# A Gloom warning may reveal its trails, but reaching zero never starts a wave.
		if mode == "raid" and warning and _breather > 0.0 and not main.raids.holding():
			_breather = maxf(0.0, _breather - dt)
			main.raids.warning_tick(_breather)
		return
	total_t += dt
	wave_t += dt
	_quiet_t += dt
	if mode != "raid":
		_wave_extras(dt)
	var foes := _wave_foe_count()
	## After a quiet spell, the last Random Raid stragglers head to the fire, and Raid Mission stragglers flee.
	if _queue.is_empty() and foes > 0 and foes <= int(_cfg().get("flee_left", 3)) and _quiet_t > float(_cfg().get("flee_after", 45.0)):
		if mode != "raid":
			_stragglers_flee()
			return
		for enemy: EnemyScript in _wave_foes():
			if enemy.head_to_campfire():
				_quiet_t = 0.0
	if not _queue.is_empty():
		_spawn_t -= dt
		if _spawn_t <= 0.0 and foes < _max_alive():  # the field is full: spawning waits (missions: the group's cap)
			var k := _next_spawn()
			if k >= 0:
				_spawn_next(k)
	elif foes == 0:
		_wave_cleared()


## Phase G1: which queued enemy comes next (its index in _queue), or -1 to wait. The caller has checked the field's
## size (_max_alive). Raids: always the next one, as before. Missions: the next in queue order that keeps the field
## within the group's limits: with a boss alive, at most `boss_others_on_field` others (a boss itself may still come);
## the field's tank weight at most `tanks_at_once` (a tank never waits while no tank is on the field, so a wave can
## always go on). A tank that would break it waits and the next non-tank comes instead; only tanks left: they wait for
## one to fall. A safety net: after `flee_after` s with nothing happening, the next one comes anyway.
## Phase G1b: the queue is squads (members side by side, _squad_end), and k is a squad's first member. A squad comes
## only when the field has room for all of it (an empty field takes any), its tank weight fits the tank limit (a squad
## whose weight alone is over it still comes while no other tank is on the field) and, with a boss alive, the others
## stay within `boss_others_on_field`; else it waits and the next squad that fits comes instead. A squad with a boss in
## it is held back only by the field's room.
func _next_spawn() -> int:
	if _queue.is_empty():
		return -1
	if mode == "raid":
		return 0
	var fs := field_state()
	var room := _max_alive() - int(fs["n"])
	var tanks_cap := float(wave_limits()["tanks_at_once"])
	var lim_others := int(_sub("wave_limits").get("boss_others_on_field", 1 << 30))
	var boss_on := int(fs["bosses"]) > 0
	var tank_now := float(fs["tank"])
	var k := 0
	while k < _queue.size():
		var end := _squad_end(k)
		var size := end - k
		var tw := 0.0
		var has_boss := false
		for j in range(k, end):
			var kind := String(_queue[j])
			if _queued_tag(j) == "boss" or bool(((Data.b["enemies"] as Dictionary).get(kind, {}) as Dictionary).get("boss", false)):
				has_boss = true
			else:
				tw += tank_weight(kind)
		var fits := size <= room or int(fs["n"]) == 0
		if has_boss:
			if fits:
				return k                            # the boss is never held back (only by the field's room)
		elif fits and not (boss_on and int(fs["others"]) > 0 and int(fs["others"]) + size > lim_others) \
				and not (tw > 0.0 and tank_now > 0.0 and tank_now + tw > tanks_cap + 0.001):
			return k                                # too many tanks out, or no room: the next squad that fits comes first
		k = end
	if _quiet_t > float(_cfg().get("flee_after", 45.0)):
		return 0                                    # nothing has happened for a long while: never hang the wave
	return -1


## Phase G1b: the squad number of queued enemy k (-1: none, or _qinfo is out of step with _queue).
func _queued_squad(k: int) -> int:
	if _qinfo.size() != _queue.size() or k < 0 or k >= _qinfo.size():
		return -1
	var q: Array = _qinfo[k]
	return int(q[3]) if q.size() > 3 else -1


## Phase G1b: the end (exclusive) of the squad that starts at queued enemy k: its members are side by side in the queue
## (an enemy without a squad is a squad of one).
func _squad_end(k: int) -> int:
	var sq := _queued_squad(k)
	var e := k + 1
	if sq < 0:
		return e
	while e < _queue.size() and _queued_squad(e) == sq:
		e += 1
	return e


## The tag of queued enemy k ("", "elite", "boss"), while _qinfo is side by side with _queue.
func _queued_tag(k: int) -> String:
	if _qinfo.size() != _queue.size() or k < 0 or k >= _qinfo.size():
		return ""
	var q: Array = _qinfo[k]
	return String(q[2]) if q.size() > 2 else ""


## The next enemy of the wave comes out of the woods (queued enemy k, see _next_spawn). Missions: down its planned
## road, in bursts (a few a moment apart, then a gap that keeps the chapter's average rate); one of the last wave's
## `boss` enemies is marked "wave_boss". Raids: one at a time down the raid's lanes, as before Phase F. Phase G1b: a
## queued squad comes all at once (_spawn_squad); an enemy without a squad (the old pool, a queue changed from outside)
## comes in bursts as before.
func _spawn_next(k := 0) -> void:
	k = clampi(k, 0, _queue.size() - 1)
	if mode == "raid":
		_spawn_raid_member(k)
		return
	var in_step := _qinfo.size() == _queue.size()
	if mode != "raid" and _queued_squad(k) >= 0:
		_spawn_squad(k)
		return
	var kind := String(_queue[k])
	_queue.remove_at(k)
	_quiet_t = 0.0
	var ch: Dictionary = info()["chapters"][mini(chapter(), info()["chapters"].size() - 1)]
	var e: Array = ch["every"]
	var into := float((wave - 1) % chapter_waves()) / float(maxi(1, chapter_waves() - 1))
	var q: Array = [-1, 1.0, ""]
	if in_step:
		q = _qinfo[k]
		_qinfo.remove_at(k)
	else:
		_qinfo.clear()                              # the queue was changed from outside: the plan's roads, at random
	var ln := int(q[0])
	if ln < 0:
		var rs: Array = plan.get("roads", info()["lanes"])
		ln = int(rs.pick_random()) if not rs.is_empty() else 0
	lane = ln
	var foe = spawn(kind, main.world.spawn_point(ln, randf_range(-0.12, 0.12)), ln)
	if q.size() > 2 and String(q[2]) == "boss" and foe != null and is_instance_valid(foe):
		foe.set_meta("wave_boss", true)             # the wave's boss: it never counts as a tank, and holds the others back
	if float(q[1]) != 1.0 and foe != null and is_instance_valid(foe) and foe.get("speed") != null:
		foe.speed = float(foe.speed) * float(q[1])  # a rush comes faster
	var bc := _sub("burst")
	var bs: Array = bc.get("size", [1, 1])
	var gap := float(bc.get("spacing", 0.4))
	if _burst_left <= 0:
		_burst_n = randi_range(int(bs[0]), maxi(int(bs[0]), int(bs[1])))
		_burst_left = _burst_n
	_burst_left -= 1
	if _burst_left > 0 and not _queue.is_empty():
		_spawn_t = gap
	else:
		var made := _burst_n - _burst_left          # this burst's enemies (fewer when the wave ran out)
		_spawn_t = maxf(gap, made * lerpf(float(e[0]), float(e[1]), into) - (made - 1) * gap) * randf_range(0.85, 1.15)
		_burst_left = 0


func _spawn_raid_member(k: int) -> void:
	var kind := String(_queue[k])
	var row: Array = _qinfo[k]
	_queue.remove_at(k)
	_qinfo.remove_at(k)
	lane = int(row[0])
	_quiet_t = 0.0
	_spawn_t = float(row[2])
	var enemy = spawn(kind, main.world.spawn_point(lane, _rng.randf_range(-0.12, 0.12)), lane, int(row[3]))
	if is_instance_valid(enemy):
		enemy.set_meta("raid_member", int(row[3]))
		enemy.set_meta("raid_group", int(row[1]))


## Phase G1b: the squad that starts at queued enemy k comes out of its road's woods all at once, set out in its
## formation facing along its road (each member at EnemyScript.squad_spot of its spot): its leader first, then each member
## with the metas "squad_leader" (the leader) and "squad_offset" (its spot); all of them carry "squad" (the squad's
## number). Then the next squad waits about `every` x this one's size (the chapter's average rate; the burst's
## `spacing` at the least).
func _spawn_squad(k: int) -> void:
	var end := _squad_end(k)
	var rows: Array = []                            # [kind, its _qinfo]
	for j in range(k, end):
		rows.append([String(_queue[j]), _qinfo[j]])
	for j in range(end - 1, k - 1, -1):
		_queue.remove_at(j)
		_qinfo.remove_at(j)
	_quiet_t = 0.0
	_squad_n += 1
	var ln := int(rows[0][1][0])
	if ln < 0:
		var rs: Array = plan.get("roads", info()["lanes"])
		ln = int(rs.pick_random()) if not rs.is_empty() else 0
	lane = ln
	var at: Vector3 = main.world.spawn_point(ln, randf_range(-0.12, 0.12))
	var fwd := -Vector3(at.x, 0.0, at.z).normalized()          # facing the camp
	if ln < main.world.trails.size():
		# facing where its leader walks first (enemy.gd: its trail 1.4 m on), so it sets out without a turn
		var first: Vector3 = main.world.trail_point(ln, main.world.trail_progress(ln, at) + 1.4) - at
		first.y = 0.0
		if first.length() > 0.1:
			fwd = first.normalized()
	var rot := atan2(fwd.x, fwd.z)
	var li := 0
	for j in rows.size():
		var q: Array = rows[j][1]
		if q.size() > 5 and bool(q[5]):
			li = j
			break
	var leader = _spawn_member(rows[li], at, ln, rot, null, Vector3.ZERO)
	for j in rows.size():
		if j == li:
			continue
		var q: Array = rows[j][1]
		var off: Vector3 = q[4] if q.size() > 4 and q[4] is Vector3 else Vector3.ZERO
		_spawn_member(rows[j], EnemyScript.squad_spot(at, rot, off), ln, rot, leader, off)
	var ch: Dictionary = info()["chapters"][mini(chapter(), info()["chapters"].size() - 1)]
	var e: Array = ch["every"]
	var into := float((wave - 1) % chapter_waves()) / float(maxi(1, chapter_waves() - 1))
	var gap := float(_sub("burst").get("spacing", 0.4))
	_spawn_t = maxf(gap, rows.size() * lerpf(float(e[0]), float(e[1]), into)) * randf_range(0.85, 1.15)


## One member of a squad coming out at `at` (_spawn_squad): its road, its facing, a boss marked "wave_boss", a rush's
## speed; with a leader (not the leader itself) its metas "squad_leader" and "squad_offset". Returns it (null when it
## did not come).
func _spawn_member(row: Array, at: Vector3, ln: int, rot: float, leader, off: Vector3):
	var q: Array = row[1]
	var foe = spawn(String(row[0]), at, ln)
	if foe == null or not is_instance_valid(foe):
		return null
	foe.rotation.y = rot
	foe.set_meta("squad", _squad_n)
	if q.size() > 2 and String(q[2]) == "boss":
		foe.set_meta("wave_boss", true)             # the wave's boss: it never counts as a tank, and holds the others back
	if q.size() > 1 and float(q[1]) != 1.0 and foe.get("speed") != null:
		foe.speed = float(foe.speed) * float(q[1])  # a rush comes faster
	if leader != null and is_instance_valid(leader) and leader != foe:
		foe.set_meta("squad_leader", leader)
		foe.set_meta("squad_offset", off)
	return foe


## The Golden Grub and the Gloom Totem come at their time in the wave; a banner held back shows.
func _wave_extras(dt: float) -> void:
	if _say_t >= 0.0:
		_say_t -= dt
		if _say_t < 0.0 and _say.size() == 3:
			main.hud.banner(String(_say[0]), _say[1], String(_say[2]))
			_say = []
	if _grub_at >= 0.0 and wave_t >= _grub_at:
		_grub_at = -1.0
		spawn_grub()
	if _totem_at >= 0.0 and wave_t >= _totem_at:
		_totem_at = -1.0
		spawn_totem(_totem_road)


## A Golden Grub runs out of a random road's woods: a bonus, never part of the wave (the group "bonus"; enemy.gd makes
## it run off after its time). Returns it (null if the kind is missing).
func spawn_grub():
	var kind := String(_sub("golden_grub").get("kind", "golden_grub"))
	if not (Data.b["enemies"] as Dictionary).has(kind):
		return null
	var ln := randi() % maxi(1, Data.patch_count())
	var e = spawn(kind, main.world.spawn_point(ln, randf_range(-0.12, 0.12)), ln)
	if e != null and is_instance_valid(e):
		e.add_to_group("bonus")                     # enemy.gd does it too: a wave never waits for it
	return e


## A Gloom Totem grows on road ln, `totem.s` of the way from the woods: a foe (the wave waits for it, though the
## stragglers' rule may still send it off). enemy.gd gives it its buff. Returns it (null if the kind is missing).
func spawn_totem(ln: int):
	var tt := _sub("totem")
	var kind := String(tt.get("kind", "gloom_totem"))
	if not (Data.b["enemies"] as Dictionary).has(kind) or ln < 0 or ln >= main.world.trails.size():
		return null
	var at: Vector3 = main.world.trail_point(ln, float(main.world.trail_length(ln)) * float(tt.get("s", 0.35)))
	var e = spawn(kind, at, ln)
	if e == null or not is_instance_valid(e):
		return null
	_quiet_t = 0.0
	_wave_n += 1
	if not Save.flag("told_totem"):
		Save.set_flag("told_totem")
		main.hud.banner("A Gloom Totem!", Color(0.8, 0.55, 1.0), "Break it: it makes them stronger")
	else:
		main.hud.toast("A Gloom Totem on %s!" % _road_name(ln))
	return e


func spawn(kind: String, at: Vector3, p: int, raid_member := -1) -> Node3D:
	if main.area != null and main.area.owns(at):
		return main.area.spawn(kind, at, {"summon": true})   # Phase E: a summon below ground (the room's strength, the cap)
	if mode == "raid" and active and raid_member < 0:
		# Boss summons share the same total and live limits; they cannot create an endless extra wave.
		if raid_total() >= int(raid["assault"]["max_enemies"]) or _wave_foe_count() >= _max_alive():
			return null
		var run: Dictionary = Save.raids["run"]
		var summons: Array = run.get("summons", [])
		raid_member = int(raid["enemy_count"]) + summons.size()
		summons.append({"kind": kind, "lane": p})
		run["summons"] = summons
	var e := Node3D.new()
	e.set_script(EnemyScript)
	e.main = main
	e.position = at
	if mode == "raid" and raid_member >= 0:
		e.set_meta("raid_member", raid_member)
	main.add_child(e)
	var st := strength()
	var leader: bool = mode == "raid" and String(raid.get("leader", "")) != "" and kind == String(raid.get("leader", ""))
	if leader:
		st *= float(raid.get("leader_mult", 1.0))
	e.setup(kind, p, st)
	if leader:
		e.set_meta("leader", true)
		main.raids.on_leader(e)                     # its own banner and the boss bar
	elif bool(Data.enemy(kind).get("boss", false)):
		main.hud.banner("%s is coming!" % Data.enemy(kind)["name"], Color(0.85, 0.55, 1.0))
		main.hud.boss = e
	return e


func on_enemy_died(e: Node3D) -> void:
	_quiet_t = 0.0
	_record_raid_member(e)


func _record_raid_member(enemy) -> void:
	if mode != "raid" or not active or not is_instance_valid(enemy) or not enemy.has_meta("raid_member"):
		return
	var run: Dictionary = Save.raids["run"]
	var defeated: Array = run.get("defeated", [])
	var member := int(enemy.get_meta("raid_member"))
	if not defeated.has(member):
		defeated.append(member)
	run["assault_format"] = 1
	run["defeated"] = defeated


## Something is happening in the wave (an enemy hit a building, a defence, the campfire or the cat): no fleeing yet.
func busy() -> void:
	_quiet_t = 0.0


## The foes that hold a wave up: the "foes" group without the bonus runners (the group "bonus": the Golden Grub). Every
## count that decides a wave's end, left_in_wave and the stragglers' rule go through this.
func _wave_foes() -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("foes"):
		if not e.is_in_group("bonus"):
			out.append(e)
	return out


## How many _wave_foes (cheap: the bonus runners are few).
func _wave_foe_count() -> int:
	var n := get_tree().get_nodes_in_group("foes").size()
	for b in get_tree().get_nodes_in_group("bonus"):
		if b.is_in_group("foes"):
			n -= 1
	return n


## The last few enemies of a wave have been out of reach for a long while (stuck, or far off at a barricade): they
## flee into the woods so the wave can end. No pay for them. A safety net for Raid Missions only (H1: in a Random
## Raid every raider stays until killed). A bonus runner is
## left alone (it runs off by itself).
func _stragglers_flee() -> void:
	var left := _wave_foes()
	for e in left:
		if bool(Data.enemy(String(e.id)).get("boss", false)):
			return                                  # never a boss: it has to be beaten
	for e in left:
		e.dead = true
		e.remove_from_group("foes")
		e.remove_from_group("enemies")
		Fx.petals(main, e.global_position + Vector3(0, 0.5, 0))
		e.queue_free()
	main.hud.toast("The last %d fled into the woods" % left.size())


func on_escaped(e) -> void:
	_record_raid_member(e)
	main.hud.toast("A Bandit got away with leaves!")


## Enemies of this wave still to beat (on the field and still to come; never a bonus runner).
func left_in_wave() -> int:
	return _queue.size() + _wave_foe_count()


func raid_total() -> int:
	return int(raid["enemy_count"]) + (Save.raids.get("run", {}).get("summons", []) as Array).size()


# ---------------------------------------------------------------- between waves
func _wave_cleared() -> void:
	if not active or not in_wave:
		return                                      # a cleared wave pays and advances its checkpoint only once
	in_wave = false
	if mode == "raid":
		_raid_wave_cleared()                    # a raid never reaches _win or _chapter_done
		return
	_grub_at = -1.0                             # a living grub is left alone: it runs off by itself
	_totem_at = -1.0                            # a totem not grown yet is dropped
	_say = []
	_say_t = -1.0
	main.on_wave_held()                         # the garden grows a step for every wave held
	var bonus := wave_leaves()
	var extra := _active_pay(bonus)             # [quick, intact]
	var more := int(extra[0]) + int(extra[1])
	var note := _pay_note(extra)
	var tim := wave_timber()                    # Phase G1: timber for every wave held
	last_pay = {"wave": wave, "bonus": bonus, "quick": int(extra[0]), "intact": int(extra[1]), "timber": tim}
	if wave >= waves():
		var c := chapter()
		var cl: Array = _cfg()["chest_leaves"]
		var ct: Array = _cfg()["chest_timber"]
		_win(bonus + more + int(round(float(cl[mini(c, cl.size() - 1)]) * _pay_scale())),
			int(round(float(ct[mini(c, ct.size() - 1)]) * _pay_scale())) + tim)
		if note != "":
			main.hud.toast("Last wave: " + note)
		return
	Save.timber += tim
	Save.add_leaves(bonus + more)
	if _first:
		_first_mission_unlocks()
	next_plan = plan_wave(wave + 1)             # where the next wave comes from: the status line previews it
	if wave % chapter_waves() == 0:
		_chapter_done(bonus + more, tim)
		if note != "":
			main.hud.toast("Wave bonus: " + note)
	else:
		_breather = 0.0
		_save_run(chapter(), chapter_gain(), wave)
		var tim_txt := (" · +%d timber" % tim) if tim > 0 else ""
		main.hud.toast("Wave %d held!  +%d golden leaves%s%s" % [wave, bonus, tim_txt, (" · " + note) if note != "" else ""])
		main.on_wave_cleared()


## Every held wave's guaranteed leaves, scaled for later campaign raids.
func wave_leaves() -> int:
	return roundi((float(_cfg()["wave_bonus"]) + float(_cfg()["wave_bonus_step"]) * wave) * _pay_scale())


## Every held wave's timber, scaled for later campaign raids (Gloom Raids use the base amount).
func wave_timber() -> int:
	var per := float(_cfg().get("timber_per_wave", 0.0))
	if per <= 0.0:
		return 0
	return maxi(1, int(round(per * _pay_scale())))


## Pay for active play when a mission wave is cleared (mission.bonus): [quick, intact] leaves, 0 when not earned.
## Quick: cleared within quick_base_s + quick_per_foe_s per enemy. Intact: nothing broken in the wave (_intact).
func _active_pay(bonus: int) -> Array:
	var bc := _sub("bonus")
	var quick := 0
	var intact := 0
	if wave_t <= float(bc.get("quick_base_s", 0.0)) + float(bc.get("quick_per_foe_s", 0.0)) * _wave_n:
		quick = int(round(bonus * float(bc.get("quick_share", 0.0))))
	if _intact():
		intact = int(round(bonus * float(bc.get("intact_share", 0.0))))
	return [quick, intact]


func _pay_note(extra: Array) -> String:
	var bits: Array = []
	if int(extra[0]) > 0:
		bits.append("quick +%d" % int(extra[0]))
	if int(extra[1]) > 0:
		bits.append("intact +%d" % int(extra[1]))
	return " · ".join(bits)


## Nothing was broken in this wave: no building ruined, no barricade, tower or spikes knocked down, and the campfire
## never went out (what was already down when the wave started does not count).
func _intact() -> bool:
	if _fire_out_wave:
		return false
	for id in Save.ruined:
		if not _ruined_snap.has(id):
			return false
	for k in _defences_down():
		if not _down_snap.has(k):
			return false
	return true


## The defence pieces down now: {piece id: true}.
func _defences_down() -> Dictionary:
	var out := {}
	if main == null or main.get("defences") == null:
		return out
	for p in main.defences.pieces:
		if bool(p.get("broken", false)) or float(p.get("hp", 1.0)) <= 0.0:
			out[int(p["id"])] = true
	return out


## A chapter is done: its chest, the campfire fed back to full, and the game saved at the start of the next one.
## `bonus` and `wave_tim` were paid already (the wave's leaves and timber): the banner shows them with the chest.
func _chapter_done(bonus: int, wave_tim := 0) -> void:
	var c := chapter()
	var cl: Array = _cfg()["chest_leaves"]
	var ct: Array = _cfg()["chest_timber"]
	var leaves := int(round(float(cl[mini(c, cl.size() - 1)]) * _pay_scale())) + bonus
	var timber := int(round(float(ct[mini(c, ct.size() - 1)]) * _pay_scale())) + wave_tim
	Save.add_leaves(leaves - bonus)
	Save.timber += timber - wave_tim
	main.raids.add_gloom("replay_chapter")      # once raids are open, a replay chapter feeds the Gloom meter
	on_break = true
	Save.count_gain = false                     # the break's leaves are safe; the next chapter counts from 0 (_save_run)
	rebuilt = false
	if last_stand:
		last_stand = false
		main.world.set_fire_out(false)
		main.stations.set_fire_out(false)
	if main.cooking:
		main.cooking.finish(true)                 # the chapter's dish is used up
	gate_hp = gate_max
	_save_run(c + 1)
	Fx.flower_ring(main, Vector3.ZERO, 1.6)
	Sfx.play("win", -8.0)
	main.hud.banner("Wave %d of %d held!" % [wave, waves()], Color(1.0, 0.9, 0.5),
		"Supply chest · +%d golden leaves · +%d timber · saved\nStart wave %d at the signpost when ready" % [leaves, timber, wave + 1])
	main.on_chapter_done()
	# the boss comes in the last chapter: a nudge to cook for it
	if c + 2 == chapters() and not (info().get("boss", []) as Array).is_empty() and Save.meal_ready == "" and Data.garden_level() > 0:
		main.hud.tip_after("The boss comes in the last chapter: cook a dish at the pot first!", main.stations.rings.get("pot"))


## Every next wave starts only from the player's action. Waiting and repeated taps never pay extra leaves.
func next_phase_now() -> void:
	if not active or in_wave:
		return
	if mode == "raid":
		main.hud.hide_card()
	_start_wave(wave + 1)


func title() -> String:
	if mode == "raid":
		return String(raid.get("name", "Gloom Raid"))
	return String(info()["name"]) if mission >= 0 else ""


## m:ss
static func mmss(t: float) -> String:
	var s := int(ceil(maxf(t, 0.0)))
	return "%d:%02d" % [s / 60, s % 60]


func status_text() -> String:
	if not active:
		return ""
	if mode == "raid":
		var nm := title()
		if not in_wave:
			return "%s ready · Defend Camp at the signpost" % nm
		return "%s · %d raiders left" % [nm, left_in_wave()]
	if not in_wave:
		var pv := preview_text()
		if pv != "":                                # one slim line: the title gives way to where they come from
			return "Wave %d of %d ready · %s" % [wave + 1, waves(), pv]
		return "%s · wave %d of %d ready · start at the signpost" % [title(), wave + 1, waves()]
	return "%s · wave %d of %d · %d left" % [title(), wave, waves(), left_in_wave()]


func _first_mission_unlocks() -> void:
	var st = main.stations
	if wave == 1 and not Save.flag("shop_target"):
		Save.set_flag("shop_open")
		Save.set_flag("shop_target")
		main.hud.tip("%s's shop is open! Build a Training Target to hit harder." % Data.camp_name(true), st.rings["shop"])
	elif wave == chapter_waves() and not Save.flag("home"):
		Save.set_flag("home")
		main.hud.tip("%s's shop now sells upgrades for the cat itself." % Data.camp_name(true), st.rings["shop"])
	else:
		return
	Save.save_game()
	st.refresh()


# ---------------------------------------------------------------- the campfire
func damage_fire(amount: int, from: Vector3) -> void:
	if not active or amount <= 0 or last_stand:
		return
	busy()
	gate_hp -= amount
	Sfx.play("gate", -6.0, 0.15)
	Fx.hit(main, Vector3(0, 0.6, 0) + (from - Vector3.ZERO).normalized() * 0.5, Color(1.0, 0.55, 0.25))
	Fx.number(main, Vector3(0, 1.8, 0), amount, Color(1.0, 0.45, 0.35))
	var fire = main.stations.nodes.get("campfire")
	if fire:
		Fx.boing(fire, 0.1)
	main.hud.gate_hit()
	if gate_hp <= 0.0:
		if rebuilt:
			camp_falls()                                # the second time in a chapter: the camp falls
		else:
			_start_last_stand()


## The campfire is destroyed: the Last Stand.
func _start_last_stand() -> void:
	last_stand = true
	fire_went_out = true
	_fire_out_wave = true                           # no intact bonus for this wave
	gate_hp = 0.0
	Sfx.play("lose", -6.0)
	main.world.set_fire_out(true)
	main.stations.set_fire_out(true)
	main.shake(0.4)
	main.hud.banner("The campfire is out!", Color(1.0, 0.45, 0.4), "Rebuild it: stand on the ashes (%s). Don't fall now!" % cost_words(rebuild_cost()))
	if not Save.flag("told_last_stand"):
		Save.set_flag("told_last_stand")
		main.hud.tip("You're alone in the dark. Stand on the campfire's ashes to rebuild it. If the cat falls first, the camp falls.", null)
	main.hud.refresh()


## What rebuilding the campfire in the Last Stand costs now (main.gd checks it and shows it): `rebuild_timber` timber;
## in a mission (Phase G1) `rebuild_leaves` leaves instead when the cat has less timber than that. A Gloom Raid keeps
## its timber price.
func rebuild_cost() -> Dictionary:
	var tim := int(_cfg().get("rebuild_timber", 10))
	if Save.timber >= tim:                          # missions and raids alike: short of timber, leaves do (never stuck)
		return {"timber": tim}
	return {"leaves": int(_cfg().get("rebuild_leaves", 60))}


## A cost in words: {"timber": 10} -> "10 timber", {"leaves": 60} -> "60 leaves".
static func cost_words(cost: Dictionary) -> String:
	var parts: Array = []
	for k in cost:
		parts.append("%d %s" % [int(cost[k]), String(k)])
	return ", ".join(parts)


## The cat stood on the ashes long enough (main.gd): the fire burns again, once per chapter. It pays rebuild_cost().
func rebuild_fire() -> bool:
	if not active or not last_stand or rebuilt:
		return false
	if not Data.pay(rebuild_cost()):
		return false
	rebuilt = true
	last_stand = false
	gate_hp = gate_max * float(_cfg()["rebuild_hp"])
	main.world.set_fire_out(false)
	main.stations.set_fire_out(false)
	Fx.flower_ring(main, Vector3.ZERO, 1.6)
	Sfx.play("win", -8.0)
	main.hud.banner("The campfire burns again!", Color(1.0, 0.85, 0.45), "If it goes out again this %s, the camp falls" % ("raid" if mode == "raid" else "chapter"))
	main.hud.refresh()
	return true


## The cat fell during the Last Stand.
func cat_fell() -> void:
	if active and last_stand:
		camp_falls()


## The camp falls: a setback, not a reset. The run stays saved at the start of this chapter. The Gloom takes
## raid.leaves_share of the leaves gained in this chapter (chapter_gain), never more than the cat holds: the leaves
## saved before it are safe. The chapter's next try counts from 0 again.
func camp_falls() -> void:
	if not active:
		return
	if mode == "raid":
		_raid_over(false)                       # a lost Gloom Raid: only the damage stays (no leaves, no ashes)
		return
	Save.count_gain = false
	var r: Dictionary = Data.b["raid"]
	var bits: Array = []
	var lost := mini(Save.leaves, int(floor(chapter_gain() * float(r["leaves_share"]))))
	last_fall_lost = maxi(0, lost)
	if lost > 0:
		Save.leaves -= lost
		bits.append("-%d leaves" % lost)
	if not Save.ruined.is_empty():
		bits.append("%d building%s in ruins" % [Save.ruined.size(), "s" if Save.ruined.size() > 1 else ""])
	if main.defences.keep_damage() > 0:
		bits.append("defences broken")
	bits.append("the campfire is ashes")
	bits.append("retry wave %d of %d" % [wave, waves()])
	Save.fire_ruined = true
	main.world.set_fire_out(true)
	main.stations.set_fire_out(true)
	Save.stages_lost += 1
	Save.mission_run = {"mission": mission, "chapter": chapter(), "gain": 0, "wave_done": maxi(0, wave - 1 if in_wave else wave)}
	main.set_riding(false)
	Save.save_game()
	Sfx.play("lose", -3.0)
	_clear_foes()
	main.hud.banner("The camp has fallen!", Color(0.85, 0.5, 1.0), " · ".join(bits), true)
	_end(false)


func _clear_foes() -> void:
	_queue.clear()
	_qinfo.clear()
	for e in get_tree().get_nodes_in_group("foes"):
		e.dead = true
		e.remove_from_group("foes")
		e.remove_from_group("enemies")
		Fx.kill(main, e.global_position + Vector3(0, 0.4, 0), Color(0.6, 0.4, 0.9))
		e.queue_free()


# ---------------------------------------------------------------- the end
## The last wave is beaten: its wave bonus and the last chapter's chest (`extra_*`), plus the mission's reward.
func _win(extra_leaves := 0, extra_timber := 0) -> void:
	var m := info()
	var id := String(m["id"])
	var first_win := not Save.missions_done.has(id)
	var share := 1.0 if first_win else float(_cfg()["replay_reward"])
	var leaves := int(round(float(m["reward"]["leaves"]) * share)) + extra_leaves
	var timber := int(round(float(m["reward"]["timber"]) * share)) + extra_timber
	barricade_gift = 0
	Save.leaves += leaves
	Save.timber += timber
	Save.stages_won += 1
	Save.mission_run = {}
	Save.set_flag("first_stage_done")
	if first_win:
		Save.missions_done.append(id)
		for ln in m["lanes"]:
			if not Save.claimed.has(int(ln)):
				Save.claimed.append(int(ln))       # still kept (other code reads it); the look is the step below
		main.world.fade_gloom()                    # Phase F: the Gloom over all four woods fades a step per mission won
		if id == "embers":
			Save.set_flag("shop_bench")
			# Phase G2 builds barricades as rows at the road spots, not from the bag: the first barricades' pieces
			# (free_pieces) come as their worth in leaves (x the old `piece` price)
			var di := Data.defence_info("barricade")
			barricade_gift = int(di.get("free_pieces", 2)) * int(di.get("piece", 30))
			if barricade_gift > 0:
				Save.add_leaves(barricade_gift)
	if not first_win:                              # repeat completion rewards; first-clear gifts and unlocks remain one-time
		main.raids.add_gloom("replay_won")
		if Data.burrows_open() and main.get("burrows") != null:
			main.burrows.grant_key("replay", int(Data.burrow_cfg()["keys"]["replay"]))   # a bonus key (Phase E)
	Save.save_game()
	Sfx.play("win", -3.0)
	var title_txt := "Held without fire!" if rebuilt else "%s won!" % String(m["name"])
	main.hud.banner(title_txt, Color(1.0, 0.9, 0.4), "+%d leaves  ·  +%d timber" % [leaves, timber], true)
	if barricade_gift > 0:
		main.hud.toast("+%d leaves for your first barricades" % barricade_gift)
	_end(true)
	if first_win and String(m.get("gift", "")) != "":
		main.stations.gift(String(m["gift"]))
	if first_win and Data.raids_open():
		main.raids.on_all_missions_won()          # the last mission's first win: the Watch wakes


func _end(won: bool) -> void:
	if main.cooking:
		main.cooking.finish(won)                  # won: the dish is used up; the camp fell: it goes back into the pot
	active = false
	in_wave = false
	on_break = false
	Save.count_gain = false
	_breather = 0.0
	_queue.clear()
	_qinfo.clear()
	next_plan = {}
	_grub_at = -1.0
	_totem_at = -1.0
	_say = []
	_say_t = -1.0
	_early_pay = 0
	if last_stand and not Save.fire_ruined:
		main.world.set_fire_out(false)
		main.stations.set_fire_out(false)
	last_stand = false
	main.hud.boss = null
	main.on_stage_end(won)


# ---------------------------------------------------------------- Gloom Raids (Phase D)
## Random Raid preparation, followed by one continuous assault. Defeated members and the one rebuild survive saves.
func start_raid(spec: Dictionary, warn_s: float) -> bool:
	if active or Save.fire_ruined:
		return false
	var run: Dictionary = Save.raids.get("run", {})
	mode = "raid"
	raid = spec
	active = true
	in_wave = false
	on_break = false
	Save.count_gain = false                         # a raid never counts a chapter gain (a lost raid takes nothing)
	last_stand = false
	warning = true
	rebuilt = bool(run.get("rebuilt", false))            # one rebuild per raid, kept across a restart
	fire_went_out = bool(run.get("fire_went_out", false))
	raid_losses = int(run.get("losses", 0))
	total_t = 0.0
	_first = false
	_endgame_run = true
	_ruined_at_start = Save.ruined.duplicate()
	_queue.clear()
	_qinfo.clear()
	plan = {}
	next_plan = {}
	_early_pay = 0
	gate_max = float(Data.fire_hp())
	gate_hp = gate_max * clampf(float(run.get("fire", 1.0)), 0.3, 1.0)
	wave = 0                                            # one assault; defeated member IDs preserve its progress
	_breather = maxf(warn_s, 0.05)
	main.stations.reset_hp()                             # hp{} is stale outside fights; wear applies here
	main.on_raid_start(spec)
	return true


## Seconds left in the raid's warning or breather (raids.persist saves it).
func breather_left() -> float:
	return _breather


func _raid_wave_cleared() -> void:
	if not active or mode != "raid":
		return
	if int(Save.raids["run"].get("wave_done", 0)) == 0:
		var leaves := wave_leaves()
		var timber := wave_timber()
		Save.add_leaves(leaves)
		Save.timber += timber
		last_pay = {"wave": wave, "bonus": leaves, "quick": 0, "intact": 0, "timber": timber}
		main.on_wave_held()
		main.raids.on_wave_held(wave)
	_raid_over(true)                                     # no intermediate wave or rest state


## A Gloom Raid ends: held, or the Gloom got through. Either way the damage stays; nothing else is lost.
func _raid_over(won: bool) -> void:
	if mode != "raid" or not active:
		return
	var perfect := won and raid_losses == 0 and not fire_went_out
	var held := wave if won else maxi(0, wave - 1 if in_wave else wave)
	if not won:
		var run: Dictionary = Save.raids["run"]
		var legacy := int(main.raids.cfg()["assault"]["legacy_waves"])
		var credit := clampi(int(run.get("legacy_held", 0)), 0, legacy)
		var fraction := float((run.get("defeated", []) as Array).size()) / maxf(float(raid_total()), 1.0)
		held = credit + floori(fraction * (legacy - credit)) # preserve partial-defence consolation without round breaks
		main.set_riding(false)
	_clear_foes()
	main.raids.finish(won, perfect, held)
	_end(won)                 # relights the fire if the Last Stand was on (a raid never sets fire_ruined)
	mode = "mission"          # after _end: main.on_stage_end still sees mode == "raid"
	raid = {}
	warning = false
