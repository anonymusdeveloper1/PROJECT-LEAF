extends Node
## Gloom Raids (Phase D): after every mission is won, the Gloom keeps coming.
##   meter    Save.raids.meter 0..100. It fills only while the game is open and the player is playing (no fight, no
##            raid pending, the fire burns, the cat is up, a touch within idle_after). Never fed from the clock: each
##            frame adds at most max_delta seconds, so a resume or a stall never adds time.
##   plan     made at stir_at: kind, trails, level, leader, seed. What was announced is what comes.
##   pending  full: the raid is announced and fight.gd runs it (start_raid): the warning, then its waves. It stays
##            pending across restarts and comes back at its warning. Nothing is ever worked out while closed.
##   end      held: shards, leaves, timber, keys. Lost: a few shards. The damage stays either way, nothing is taken.
## Everything the player sees of it is on the signpost (the Watch card), the HUD's top right, banners and toasts.

signal raid_started(spec: Dictionary)      # Phase C (dish boosts, the guardian) and Phase E listen
signal raid_ended(won: bool, perfect: bool)

var main
var idle_t := 1000.0                        # seconds since the player last touched the screen (live play only); the
                                            # game opens idle: nothing fills until the first touch
var open := false                           # cache of Data.raids_open(), refreshed by refresh_open()
var test_awake := false                     # tests: the player never goes idle (unless a test is about idling)
var manual := false                         # tests: main's frames do not tick the meter; the test calls step()
var _alerts := {}                           # building id -> seconds until the next "under attack" toast
var _told_ten := false
var _restored := false                      # the pending raid came back with the save: "A Gloom Raid is waiting!"
var _rout_at = null                         # where the leader fell (the shard shower bursts from there)
var _warn_total := 45.0                     # the warning's length when it started (the HUD bar)
var last_ready := false                     # the last raid's ready bonus (tests)
var _watch_share := -1.0                    # what the Watch's crystal shows now (it is updated only when this moves)
# debug args (tests): --raid-type=, --raid-small, --raid-warn=, --raid-meter=
var forced_type := ""
var small := false
var warn_override := -1.0


func _ready() -> void:
	for a in Data.args():
		if a.begins_with("--raid-type="):
			forced_type = a.substr(12)
		elif a == "--raid-small":
			small = true
		elif a.begins_with("--raid-warn="):
			warn_override = float(a.substr(12))


func cfg() -> Dictionary:
	return Data.gr()


func refresh_open() -> void:
	open = Data.raids_open()


func has_unlock(id: String) -> bool:
	return Save.unlocks.has(id)


## A sound, or its stand-in while the file does not exist yet.
func sfx(name: String, fallback: String, db := 0.0) -> void:
	if ResourceLoader.exists("res://assets/sfx/%s.wav" % name):
		Sfx.play(name, db)
	else:
		Sfx.play(fallback, db)


# ---------------------------------------------------------------- every frame (main._process)
func tick(delta: float) -> void:
	if manual:
		return
	step(delta)


func step(delta: float) -> void:
	if not open or main.frozen:
		return
	var d := minf(delta, float(cfg()["meter"]["max_delta"]))   # a resume or a stall never adds time
	idle_t = 0.0 if test_awake else idle_t + d
	for id in _alerts.keys():
		_alerts[id] = float(_alerts[id]) - d
		if float(_alerts[id]) <= 0.0:
			_alerts.erase(id)
	if main.fight.active:
		return
	if bool(Save.raids["pending"]):
		try_warning()
		return
	if can_fill():
		var m: Dictionary = cfg()["meter"]
		_add(float(m["per_minute"]) / 60.0 * d, float(m["full"]))


## The player touched the screen (main._input).
func touch() -> void:
	idle_t = 0.0


func can_fill() -> bool:
	return open and not main.fight.active and not bool(Save.raids["pending"]) and not Save.fire_ruined \
		and not idle() and main.player.hp > 0 and not main.frozen \
		and main.get("area") == null


func idle() -> bool:
	return not test_awake and idle_t >= float(cfg()["meter"]["idle_after"])


## The countdown waits while nobody is playing (the warning and the breathers between raid waves).
func holding() -> bool:
	return not test_awake and idle_t >= float(cfg()["warning"]["idle_hold"])


## Action points (a harvest, a dish, a fish, a Burrows run; "replay_chapter" and "replay_won" are kept but no longer
## come, Phase F has no replays): never past bump_cap, never while a raid is pending, so the horn always sounds while
## the player is there playing.
func add_gloom(action: String) -> void:
	if not open or bool(Save.raids["pending"]):
		return
	var m: Dictionary = cfg()["meter"]
	_add(float(m["actions"].get(action, 0.0)), float(m["bump_cap"]))


func _add(points: float, cap: float) -> void:
	var m: Dictionary = cfg()["meter"]
	var r: Dictionary = Save.raids
	var before := float(r["meter"])
	var after := minf(maxf(before, minf(before + points, cap)), float(m["full"]))
	if after <= before:
		return
	r["meter"] = after
	if before < float(m["stir_at"]) and after >= float(m["stir_at"]) and (r["plan"] as Dictionary).is_empty():
		r["plan"] = _plan()
		_stir_message()
		Save.save_game(true)
	if after >= float(m["full"]):
		_go_pending(false)
	elif int(before / float(m["save_step"])) != int(after / float(m["save_step"])):
		Save.save_game(true)
	_update_watch_model()


func meter() -> float:
	return float(Save.raids["meter"])


func _stir_message() -> void:
	var plan: Dictionary = Save.raids["plan"]
	if has_unlock("watch:tracker") and not plan.is_empty():
		main.hud.toast("The Watch hears a %s on %s" % [type_name(plan), trail_names(plan["lanes"])])
		for ln in plan["lanes"]:
			main.world.gloom_returns(int(ln))         # the trail's mist eyes flicker for a moment
		get_tree().create_timer(2.0).timeout.connect(func():
			if not main.fight.active and not bool(Save.raids["pending"]):
				main.world.settle_gloom())
	else:
		main.hud.toast("The Gloom stirs in the woods...")


# ---------------------------------------------------------------- how big: the camp grows the raids
func camp_score() -> int:
	var cs: Dictionary = cfg()["camp_score"]
	var s := float(cs["per_home_level"]) * (Save.camp_level - 1)
	for id in ["target", "bench", "well", "cottage", "stall"]:
		s += float(cs["per_station_level"]) * int(Save.stations.get(id, 0))
	for p in main.defences.pieces:
		if p["type"] == "tower":
			s += float(cs["per_tower"])
	for t in ["barricade", "tower", "spikes"]:
		s += float(cs["per_defence_level"]) * (main.defences.level(t) - 1)
	s += float(cs["per_guardian_level"]) * Data.guardian_level()
	return int(round(s))


func raid_level(first := false) -> int:
	var lv: Dictionary = cfg()["level"]
	var renown := int(Save.raids["renown"])
	var l := 1 + int(floor(maxf(0.0, camp_score() - float(lv["camp_free"])) / float(lv["camp_step"]))) + int(floor(renown / float(lv["renown_step"])))
	l = clampi(l, 1, int(lv["max"]))
	if first:
		l = maxi(1, l - int(lv["first_raid_minus"]))
	return l


func strength_for(level: int) -> float:
	var s: Dictionary = cfg()["strength"]
	return float(s["base"]) + float(s["per_level"]) * level


# ---------------------------------------------------------------- the plan (made at stir)
func _plan() -> Dictionary:
	var r: Dictionary = Save.raids
	var types: Dictionary = cfg()["types"]
	var num := int(r["held"]) + int(r["lost"]) + 1
	var first := not bool(r["first_done"])
	var kind := ""
	if forced_type != "" and types.has(forced_type):
		kind = forced_type
	elif first:
		kind = String(cfg()["first_raid"])
	else:
		kind = _pick_kind(num)
	var t: Dictionary = types[kind]
	var level := raid_level(first)
	var leader := String(t.get("leader", ""))
	if t.has("leaders"):
		var ls: Array = t["leaders"]
		leader = String(ls[int(r["elite_turn"]) % ls.size()])
	return {"type": kind, "lanes": _pick_lanes(t, level), "level": level, "leader": leader, "first": first,
		"seed": randi() % 1000000000, "called": false}


## A weighted pick among the kinds whose turn has come; never the same kind 3 times in a row; elite needs its gap.
func _pick_kind(num: int) -> String:
	var r: Dictionary = Save.raids
	var types: Dictionary = cfg()["types"]
	var last: Array = r["last_types"]
	var same := int(cfg()["max_same_in_a_row"])
	var cands: Array = []
	var total := 0.0
	for k in types:
		var t: Dictionary = types[k]
		if num < int(t.get("from_raid", 1)):
			continue
		if t.has("gap") and int(r["since_elite"]) < int(t["gap"]):
			continue
		if last.size() >= same:
			var all_same := true
			for i in same:
				if String(last[last.size() - 1 - i]) != String(k):
					all_same = false
			if all_same:
				continue
		cands.append([String(k), float(t.get("weight", 1))])
		total += float(t.get("weight", 1))
	if cands.is_empty():
		return String(cfg()["first_raid"])
	var x := randf() * total
	for c in cands:
		x -= float(c[1])
		if x <= 0.0:
			return String(c[0])
	return String(cands[cands.size() - 1][0])


## Sneak raids take the least-guarded trail; the others pick at random, avoiding the last raid's trails if they can.
func _pick_lanes(t: Dictionary, level: int) -> Array:
	var n := int(t.get("lanes", 1))
	if t.has("lanes_more_from_level") and level >= int(t["lanes_more_from_level"]):
		n += 1
	var all: Array = []
	for i in Data.lane_count():
		all.append(i)
	n = clampi(n, 1, all.size())
	if String(t.get("pick", "")) == "weakest":
		var best := 1e12
		var ties: Array = []
		for ln in all:
			var g: float = main.defences.lane_guard(int(ln))
			if g < best - 0.5:
				best = g
				ties = [ln]
			elif absf(g - best) <= 0.5:
				ties.append(ln)
		return [int(ties[randi() % ties.size()])]
	var last: Array = Save.raids["last_lanes"]
	var fresh: Array = all.filter(func(ln): return not last.has(ln))
	fresh.shuffle()
	var rest: Array = all.filter(func(ln): return last.has(ln))
	rest.shuffle()
	var pool: Array = fresh + rest
	var out: Array = []
	for i in n:
		out.append(int(pool[i]))
	out.sort()
	return out


## The raid as fight.gd runs it: a mission-shaped Dictionary (spec section 8). Kinds missing from `enemies` are left out.
func spec_for(plan: Dictionary) -> Dictionary:
	var t: Dictionary = cfg()["types"][String(plan["type"])]
	var lv := int(plan["level"])
	var enemies: Dictionary = Data.b["enemies"]
	var pool: Array = []
	for pair in t["pool"]:
		if enemies.has(String(pair[0])):
			pool.append([String(pair[0]), int(pair[1])])
	if pool.is_empty():
		pool = [["thornling", 1]]
	var leader := String(plan.get("leader", ""))
	if not enemies.has(leader):
		leader = ""                                 # no leader model yet: no rout, the last wave just ends the raid
	var c: Array = cfg()["count"]
	var per := lv / int(cfg()["count_per_level"])
	var count: Array = [int(c[0]) + per, int(c[1]) + per]
	var waves := int(cfg()["waves"])
	var breather := float(cfg()["breather"])
	if small:
		count = [2, 3]
		waves = 2
		breather = 1.0
	var st: Dictionary = cfg()["strength"]
	var mq: Array = cfg()["max_alive_by_quality"]
	var lanes: Array = []
	for ln in plan["lanes"]:
		lanes.append(int(ln))
	return {"id": "raid_" + String(plan["type"]), "name": String(t["name"]), "type": String(plan["type"]), "level": lv,
		"seed": int(plan["seed"]), "waves": waves, "count": count, "lanes": lanes,
		"chapters": [{"name": String(t["name"]), "pool": pool, "every": t["every"]}],
		"elite": [], "boss": [[leader, 1]] if leader != "" else [], "leader": leader, "leader_at": int(cfg()["leader_at"]),
		"leader_mult": float(st["herald_mult"]) if leader == "herald" else float(st["boss_mult"]),
		"strength": strength_for(lv), "wave_ramp": float(st["wave_ramp"]), "breather": breather,
		"max_alive": int(mq[clampi(Quality.level, 0, mq.size() - 1)]), "hidden": hidden_kind(plan), "tell": String(t.get("tell", ""))}


## A sneak raid hides its trail (unless the Watch has the Tracker).
func hidden_kind(plan: Dictionary) -> bool:
	if plan.is_empty():
		return false
	var t: Dictionary = cfg()["types"].get(String(plan["type"]), {})
	return bool(t.get("hidden", false)) and not has_unlock("watch:tracker")


## The raid's trail is still hidden now (a sneak raid before its reveal).
func hidden_now() -> bool:
	var r: Dictionary = Save.raids
	return hidden_kind(r["plan"]) and not bool((r["run"] as Dictionary).get("revealed", false))


## The trails of the raid coming or under way, as far as the player knows them ([] while a sneak raid hides).
func known_lanes() -> Array:
	var plan: Dictionary = Save.raids["plan"]
	if plan.is_empty() or hidden_now():
		return []
	return (plan["lanes"] as Array).duplicate()


func trail_names(lanes: Array) -> String:
	var names: Array = []
	for ln in lanes:
		names.append(String(Data.patch(int(ln))["name"]))
	return " and ".join(names)


## "Fernwood", "Fernwood and Bandit Thicket", or "trail unknown" (a hidden sneak raid).
func trail_text() -> String:
	var plan: Dictionary = Save.raids["plan"]
	if plan.is_empty():
		return ""
	if hidden_now():
		return "trail unknown"
	return trail_names(plan["lanes"])


func type_name(plan: Dictionary) -> String:
	return String(cfg()["types"].get(String(plan.get("type", "")), {}).get("name", "Gloom Raid"))


func leader_name(id: String) -> String:
	if id == "" or not Data.b["enemies"].has(id):
		return "the Gloom"
	var n := String(Data.enemy(id)["name"])
	return "The " + n if id == "herald" else n


## The warning's length: always warning.min..warning.max (45 s; 60 for the first and elite raids; 30 when called).
func warn_seconds(plan: Dictionary, called: bool) -> float:
	var w: Dictionary = cfg()["warning"]
	var s := float(w["normal"])
	if bool(plan.get("first", false)):
		s = float(w["first"])
	elif String(cfg()["types"].get(String(plan.get("type", "")), {}).get("warning", "")) == "elite":
		s = float(w["elite"])
	elif called:
		s = float(w["called"])
	if has_unlock("watch:lookout"):
		s += float(w["lookout_bonus"])
	if warn_override > 0.0:
		s = warn_override
	return clampf(s, float(w["min"]), float(w["max"]))


# ---------------------------------------------------------------- the horn
## "Sound the horn" on the Watch: from call_from, the raid comes now (a 30 s warning).
func call_now() -> void:
	if not open or bool(Save.raids["pending"]) or main.fight.active or meter() < float(cfg()["meter"]["call_from"]):
		return
	_go_pending(true)


func _go_pending(called: bool) -> void:
	var r: Dictionary = Save.raids
	if (r["plan"] as Dictionary).is_empty():
		r["plan"] = _plan()
	r["plan"]["called"] = called
	r["pending"] = true
	r["warn_left"] = warn_seconds(r["plan"], called)
	r["meter"] = float(cfg()["meter"]["full"])
	r["run"] = {}
	_restored = false
	Save.save_game(true)
	_update_watch_model(true)
	try_warning()
	if main.hud:
		main.hud.refresh_card()


## Why a full meter waits ("" when the warning can start): a fight, the ashes, the cat down, the Burrows, a mini-game.
func blocked_reason() -> String:
	if main.fight.active:
		return "fight"
	if Save.fire_ruined:
		return "fire"
	if main.player.hp <= 0:
		return "down"
	if main.get("area") != null:
		return "away"
	if main.get("busy_minigame") == true or (main.fishing != null and main.fishing.busy()):
		return "busy"
	return ""


func try_warning() -> void:
	if blocked_reason() != "":
		return
	var r: Dictionary = Save.raids
	if (r["plan"] as Dictionary).is_empty():
		r["plan"] = _plan()
	var spec := spec_for(r["plan"])
	var warn := clampf(float(r["warn_left"]), 1.0, float(cfg()["warning"]["max"]))
	if not main.fight.start_raid(spec, warn):
		return
	if (r["run"] as Dictionary).is_empty():
		r["run"] = {"wave_done": 0, "losses": 0, "fire": 1.0, "fire_went_out": false, "rebuilt": false, "last_stand": false,
			"ready": false, "revealed": false, "started": false}
	_warn_total = warn
	present_warning()
	raid_started.emit(main.fight.raid)
	var g = main.get("guardian")
	if g != null:
		if g.has_method("on_raid_start"):
			g.on_raid_start()
		else:
			g.on_mission_start()                      # up, whole, and to its post on the raid's trails
	Save.save_game(true)


func present_warning() -> void:
	var r: Dictionary = Save.raids
	var plan: Dictionary = r["plan"]
	var w: Dictionary = cfg()["warning"]
	var left := float(r["warn_left"])
	_told_ten = left <= float(w["ten_left"])
	if ResourceLoader.exists("res://assets/sfx/raid_horn.wav"):
		Sfx.play("raid_horn", 0.0)
	else:
		Sfx.play("horn", 4.0, 0.0)
		get_tree().create_timer(0.6).timeout.connect(func(): Sfx.play("horn", 4.0, 0.0))
	var s = main.world.get("sign_node")
	if s != null and is_instance_valid(s):
		var horn: Node3D = Props.find_part(s, "horn")
		Fx.boing(horn if horn != null else s, 0.35)
	Fx.shockwave(main, main.world.station_pos("sign") + Vector3(0, 0.3, 0), 2.0, Color(0.75, 0.45, 1.0))
	var where := "trail unknown" if hidden_now() else "from %s" % trail_names(plan["lanes"])
	if _restored:
		_restored = false
		main.hud.banner_later(1.0, "A Gloom Raid is waiting!", Color(0.8, 0.55, 1.0),
			"It comes in %d s · nothing happened while you were away" % int(ceil(left)))
	else:
		main.hud.banner("A Gloom Raid is coming!", Color(0.8, 0.55, 1.0), "%s · level %d · %s · %d s to get ready" % [
			type_name(plan), int(plan["level"]), where, int(ceil(left))])
	if not hidden_now():
		_show_trails(float(w["point_s"]))
	if bool(plan.get("first", false)) and not Save.flag("told_raid_warn"):
		Save.set_flag("told_raid_warn")
		main.hud.tip_after("Repair and mend, then tap Meet them now at the signpost. Or wait for the horn.", main.stations.rings.get("sign"))
	main.shake(0.15)


## The Gloom rolls back onto the raid's trails, and an arrow points at the first one.
func _show_trails(point_s: float) -> void:
	var plan: Dictionary = Save.raids["plan"]
	for ln in plan["lanes"]:
		main.world.gloom_returns(int(ln))
	_point(point_s)


func _point(secs: float) -> void:
	var plan: Dictionary = Save.raids["plan"]
	if plan.is_empty() or (plan["lanes"] as Array).is_empty():
		return
	var ln := int(plan["lanes"][0])
	main.hud.point_at(main.world.trail_point(ln, 0.55 * main.world.trail_length(ln)), secs)


## fight.gd calls this every frame of the warning: the seconds left, the sneak reveal, the "10 seconds!" toast.
func warning_tick(left: float) -> void:
	var r: Dictionary = Save.raids
	r["warn_left"] = left
	var w: Dictionary = cfg()["warning"]
	if hidden_now() and left <= float(w["sneak_reveal"]):
		_reveal()
	if not _told_ten and left <= float(w["ten_left"]) and left > 1.0:     # (not when the player met them early)
		_told_ten = true
		main.hud.toast("10 seconds!")
		if not hidden_now():
			_point(3.0)


## A sneak raid shows its trail (15 s before it comes, or as wave 1 starts if the player met it early).
func _reveal() -> void:
	var run: Dictionary = Save.raids["run"]
	if bool(run.get("revealed", false)):
		return
	run["revealed"] = true
	main.hud.toast("There! They're coming down %s!" % trail_names(Save.raids["plan"]["lanes"]))
	_show_trails(float(cfg()["warning"]["point_s"]))
	if main.guardian:
		main.guardian.on_wave_start()                 # its post can follow the trail now
	main.hud.refresh_card()


# ---------------------------------------------------------------- the waves (fight.gd and main.gd call these)
func on_wave_begins(w: int, last: bool) -> void:
	var r: Dictionary = Save.raids
	var run: Dictionary = r["run"]
	if not bool(run.get("started", false)):
		run["started"] = true
		run["ready"] = (camp_check()["items"] as Array).is_empty()   # the camp was whole when the raid began
	if hidden_now():
		_reveal()
	var spec: Dictionary = main.fight.raid
	if last:
		main.hud.banner("Final push!", Color(1.0, 0.6, 0.45), "%s leads it" % leader_name(String(spec.get("leader", ""))) if String(spec.get("leader", "")) != "" else "The last wave of the raid")
	elif w == 1:
		main.hud.banner("They're here!", Color(1.0, 0.7, 0.45), String(spec.get("tell", "")))
	else:
		main.hud.toast("Raid wave %d of %d" % [w, main.fight.waves()])
	Save.save_game(true)


func on_leader(e) -> void:
	main.hud.boss = e
	var id := String(e.id)
	main.hud.banner("%s!" % leader_name(id), Color(0.85, 0.55, 1.0), "Topple it and the raid breaks")


## fight._rout: the leader fell here, and the rest of the raid fled.
func on_rout(at: Vector3, _fled: int) -> void:
	_rout_at = at


## A building was hit in a raid: a toast, at most once per building every alert_every_s.
func on_building_hit(id: String) -> void:
	if main.fight.mode != "raid" or _alerts.has(id):
		return
	_alerts[id] = float(cfg()["alert_every_s"])
	main.hud.toast("%s is under attack!" % (Data.camp_name(true) if id == "home" else "The %s" % String(Data.b["stations"][id]["name"])))


## A raid wave was held: the damage so far is saved now (wear, wrecks, the fire), not only at the end.
func on_wave_held(w: int) -> void:
	var run: Dictionary = Save.raids["run"]
	run["wave_done"] = w
	_save_run_state()
	main.stations.save_wear()
	main.defences.keep_damage(true)
	Save.save_game(true)


func _save_run_state() -> void:
	var f = main.fight
	var run: Dictionary = Save.raids["run"]
	run["losses"] = int(f.raid_losses)
	run["fire"] = clampf(float(f.gate_hp) / maxf(float(f.gate_max), 1.0), 0.0, 1.0)
	run["fire_went_out"] = bool(f.fire_went_out)
	run["rebuilt"] = bool(f.rebuilt)
	run["last_stand"] = bool(f.last_stand)


# ---------------------------------------------------------------- the end of a raid
func finish(won: bool, perfect: bool, held: int) -> void:
	var r: Dictionary = Save.raids
	var plan: Dictionary = r["plan"]
	var kind := String(plan.get("type", "siege"))
	var t: Dictionary = cfg()["types"].get(kind, cfg()["types"]["siege"])
	var lv := int(plan.get("level", 1))
	var run: Dictionary = r["run"]
	# 1. the damage stays: wear and wrecks saved
	main.stations.save_wear()
	main.defences.keep_damage(true)
	# 2. pay (or the consolation)
	var pay: Dictionary = cfg()["pay"]
	var ready := bool(run.get("ready", false))
	last_ready = ready
	var shards := 0
	var leaves := 0
	var timber := 0
	var keys := 0
	if won:
		var mult := 1.0 + (float(pay["perfect"]) if perfect else 0.0) + (float(pay["ready"]) if ready else 0.0)
		shards = int(round((float(pay["shards"]) + float(pay["shards_per_level"]) * lv) * float(t.get("shards", 1.0)) * mult))
		leaves = int(pay["leaves"]) + int(pay["leaves_per_level"]) * lv
		timber = int(pay["timber"]) + lv / int(pay["timber_per_levels"])
		keys = int(pay["keys"]["held"]) + (int(pay["keys"]["elite_extra"]) if kind == "elite" else 0)
	else:
		shards = int(pay["lost_per_wave_held"]) * maxi(0, held)
	var first_shards := Save.shards == 0 and shards > 0 and not Save.flag("told_shards")
	Save.shards += shards                             # banked at once: a crash can never lose them
	Save.leaves += leaves
	Save.timber += timber
	if keys > 0 and main.get("burrows") != null:
		main.burrows.grant_key("raid", keys)            # Phase E: a full key ring turns the extra key into leaves
	else:
		Save.burrow_keys = mini(int(pay["keys"]["max"]), Save.burrow_keys + keys)
	# 3. counters
	var lvc: Dictionary = cfg()["level"]
	if won:
		r["held"] = int(r["held"]) + 1
		r["renown"] = mini(int(lvc["renown_cap"]), int(r["renown"]) + int(lvc["won_renown"]))
		if perfect:
			r["perfect"] = int(r["perfect"]) + 1
			r["streak"] = int(r["streak"]) + 1
			r["best_streak"] = maxi(int(r["best_streak"]), int(r["streak"]))
		else:
			r["streak"] = 0
		if kind == "elite":
			r["since_elite"] = 0
			r["elite_turn"] = int(r["elite_turn"]) + 1
		else:
			r["since_elite"] = int(r["since_elite"]) + 1
	else:
		r["lost"] = int(r["lost"]) + 1
		r["renown"] = maxi(0, int(r["renown"]) - int(lvc["loss_renown"]))
		r["streak"] = 0
		if kind != "elite":
			r["since_elite"] = int(r["since_elite"]) + 1
	var lt: Array = r["last_types"]
	lt.append(kind)
	while lt.size() > int(cfg()["max_same_in_a_row"]):
		lt.pop_front()
	r["last_lanes"] = (plan.get("lanes", []) as Array).duplicate()
	r["first_done"] = true
	r["last_lost"] = not won
	# 4. clear
	r["plan"] = {}
	r["pending"] = false
	r["warn_left"] = 0.0
	r["run"] = {}
	r["meter"] = 0.0
	# 5. the world
	if won:
		for ln in plan.get("lanes", []):
			main.world.lift_gloom(int(ln))
		Fx.flower_ring(main, Vector3.ZERO, 2.0)
	else:
		main.world.settle_gloom()
	# 6. the banner, the shard shower, the guardian, the signal
	if won:
		var bits: Array = ["+%d shards" % shards, "+%d leaves" % leaves, "+%d timber" % timber]
		var sub := " · ".join(bits)
		if int(r["streak"]) >= 2:
			sub += "\nPerfect streak %d" % int(r["streak"])
		elif ready:
			sub += "\nThe camp was ready: +%d%% shards" % int(round(float(pay["ready"]) * 100.0))
		main.hud.banner("Perfect defence!" if perfect else "Raid repelled!", Color(1.0, 0.95, 0.45) if perfect else Color(1.0, 0.85, 0.4), sub, true)
	else:
		var nr := Save.ruined.size()
		var nw: int = main.defences.wrecked_count()
		var sub2 := "%d building%s in ruins · %d defence%s wrecked · nothing else was lost" % [nr, "" if nr == 1 else "s", nw, "" if nw == 1 else "s"]
		if shards > 0:
			sub2 += "\n+%d shards for the waves you held" % shards
		main.hud.banner("The Gloom broke through", Color(0.8, 0.6, 1.0), sub2, true)
		main.hud.tip_after_delay(3.5, "Repair and mend from the signpost. The next raid will be a little gentler.", main.stations.rings.get("sign"))
	var at: Vector3 = _rout_at if _rout_at != null else Vector3(0, 0.6, 0)
	_rout_at = null
	main.drop_shards_fx(shards, at)
	var g = main.get("guardian")
	if g != null and g.has_method("on_raid_end"):
		g.on_raid_end(won)
	raid_ended.emit(won, perfect)
	_update_watch_model(true)
	# 7. saved; a sound
	Save.save_game()
	Sfx.play("win" if won else "lose", -4.0)
	# 8. the tips
	if won and not (camp_check()["items"] as Array).is_empty() and not Save.flag("told_raid_after"):
		Save.set_flag("told_raid_after")
		main.hud.tip_after("Mend the camp before the next raid.", main.stations.rings.get("sign"))
	if first_shards:
		Save.set_flag("told_shards")
		main.hud.tip_after("Gloom shards! Spend them on Shardstone defences at %s, or on the Watch's Lookout and Tracker." % Data.camp_name(), main.stations.rings.get("shop"))


# ---------------------------------------------------------------- nothing happens while the game is closed
## The app pauses, loses focus or closes: the meter, and during a raid its damage so far and the warning's seconds
## left, are saved (quietly). Never a time.
func persist() -> void:
	if not open:
		return
	var f = main.fight
	if f.active and f.mode == "raid" and bool(Save.raids["pending"]):
		_save_run_state()
		main.stations.save_wear()
		main.defences.keep_damage(true)
		if not f.in_wave:
			Save.raids["warn_left"] = f.breather_left()
	Save.save_game(true)


## At the end of main._ready (deferred): an old save is brought up to date, and a pending raid comes back at its
## warning (at least warning.min seconds). Nothing is worked out for the time the game was closed.
func restore_on_load() -> void:
	refresh_open()
	var r: Dictionary = Save.raids
	if Save.save_v < 2:
		Save.save_v = 2
		if open:
			r["meter"] = maxf(float(r["meter"]), float(cfg()["meter"]["first_fill"]))
			_intro()
		Save.save_game(true)
	if not open:
		return
	for a in Data.args():
		if a.begins_with("--raid-meter="):
			r["meter"] = clampf(float(a.substr(13)), 0.0, float(cfg()["meter"]["full"]))
	main.world.swap_sign()
	if bool(r["pending"]):
		var w: Dictionary = cfg()["warning"]
		r["warn_left"] = clampf(float(r["warn_left"]), float(w["min"]), float(w["max"]))
		var run: Dictionary = r["run"]
		if bool(run.get("last_stand", false)):
			# the Last Stand was on at the quit: the fire comes back at 30% and that was the raid's one rebuild
			run["last_stand"] = false
			run["fire"] = float(Data.b["mission"]["rebuild_hp"])
			run["rebuilt"] = true
			run["fire_went_out"] = true
		_restored = true
		Save.save_game(true)
	elif float(r["meter"]) >= float(cfg()["meter"]["full"]):
		_go_pending(false)
	_update_watch_model(true)


## The last mission is won for the first time: the Watch wakes, and the first raid comes about 3 minutes later.
func on_all_missions_won() -> void:
	refresh_open()
	if not open:
		return
	var r: Dictionary = Save.raids
	r["meter"] = maxf(float(r["meter"]), float(cfg()["meter"]["first_fill"]))
	Save.save_v = 2
	main.world.swap_sign()
	_update_watch_model(true)
	Save.save_game(true)
	_intro()


func _intro() -> void:
	if Save.flag("told_raids"):
		return
	Save.set_flag("told_raids")
	main.hud.banner_later(3.5, "Every mission is won!", Color(1.0, 0.9, 0.4), "But the Gloom will be back. The Watch by the signpost shows it gathering.")
	main.hud.tip_after_delay(7.5, "When the horn's crystal is full, a raid comes. You'll always get time to prepare.", main.stations.rings.get("sign"))


# ---------------------------------------------------------------- keeping the camp up
## Everything a raid left broken, in the order "Mend all" fixes it: the home's ruin, other ruins (cheapest first),
## wrecked defences (most broken first), wear (highest first). condition is the camp's health as a share (0..1).
func camp_check() -> Dictionary:
	var st = main.stations
	var items: Array = []
	var ruins: Array = []
	var others: Array = []
	for id in Save.ruined:
		if not st.shown(String(id)):
			continue
		ruins.append(String(id))
		var c: Dictionary = st.repair_cost(String(id))
		if String(id) == "home":
			items.append({"kind": "ruin", "id": "home", "cost": c})
		else:
			others.append({"kind": "ruin", "id": String(id), "cost": c})
	others.sort_custom(func(a, b): return int(a["cost"].get("leaves", 0)) < int(b["cost"].get("leaves", 0)))
	items.append_array(others)
	var wrecks: Array = []
	for p in main.defences.pieces:
		if p["wrecked"]:
			wrecks.append(p)
	wrecks.sort_custom(func(a, b): return float(a["hp"]) / float(a["max_hp"]) < float(b["hp"]) / float(b["max_hp"]))
	for p in wrecks:
		items.append({"kind": "wreck", "piece": p, "cost": {"leaves": main.defences.piece_mend_cost(p)}})
	var worn: Array = []
	for id in Save.wear:
		if st.shown(String(id)) and not Save.ruined.has(id) and float(Save.wear[id]) >= 0.05 - 0.0001:
			worn.append(String(id))
	worn.sort_custom(func(a, b): return float(Save.wear[a]) > float(Save.wear[b]))
	var wear := {}
	for id in worn:
		wear[id] = float(Save.wear[id])
		items.append({"kind": "wear", "id": id, "cost": st.patch_cost(id)})
	var cost := {"leaves": 0, "timber": 0}
	for it in items:
		cost["leaves"] += int(it["cost"].get("leaves", 0))
		cost["timber"] += int(it["cost"].get("timber", 0))
	# the camp's condition: the home weighs 2, every other building 1, each barricade and tower 0.5
	var sum := 0.0
	var weight := 0.0
	for id in st.BUILDINGS:
		if not st.shown(id):
			continue
		var wgt := 2.0 if id == "home" else 1.0
		weight += wgt
		sum += wgt * (0.0 if Save.ruined.has(id) else 1.0 - float(Save.wear.get(id, 0.0)))
	for p in main.defences.pieces:
		if p["type"] == "spikes":
			continue
		weight += 0.5
		sum += 0.5 * (clampf(float(p["hp"]) / maxf(float(p["max_hp"]), 1.0), 0.0, 1.0) if p["wrecked"] else 1.0)
	return {"ruins": ruins, "wrecks": wrecks, "wear": wear, "cost": cost, "items": items,
		"condition": sum / weight if weight > 0.0 else 1.0}


# ---------------------------------------------------------------- the Watch on the signpost
func _update_watch_model(force := false) -> void:
	var s = main.world.get("sign_node")
	if s == null or not is_instance_valid(s):
		return
	var share := 1.0 if bool(Save.raids["pending"]) else meter() / float(cfg()["meter"]["full"])
	if not force and absf(share - _watch_share) < 0.004:
		return
	_watch_share = share
	main.world.update_watch()


# ---------------------------------------------------------------- the HUD's top right
func meter_shown() -> bool:
	return open


## "meter", "idle", "blocked" (full, waiting), "warning", or "" (a fight shows its own text).
func hud_state() -> String:
	if not open:
		return ""
	var f = main.fight
	if f.active:
		return "warning" if f.mode == "raid" and f.warning else ""
	if bool(Save.raids["pending"]):
		return "blocked"
	if idle():
		return "idle"
	return "meter"


func hud_text() -> String:
	var pct := int(floor(meter()))
	match hud_state():
		"warning":
			return main.fight.status_text()
		"blocked":
			return "Raid waiting · %s" % _blocked_short(blocked_reason())
		"idle":
			return "Gloom %d%% · waits for you" % pct
		"meter":
			var plan: Dictionary = Save.raids["plan"]
			if has_unlock("watch:tracker") and not plan.is_empty() and meter() >= float(cfg()["meter"]["stir_at"]):
				return "Next: %s · %s" % [type_name(plan), trail_names(plan["lanes"])]
			return "Gloom %d%%" % pct
	return ""


func hud_frac() -> float:
	if hud_state() == "warning":
		return clampf(main.fight.breather_left() / maxf(_warn_total, 1.0), 0.0, 1.0)
	if bool(Save.raids["pending"]):
		return 1.0
	return clampf(meter() / float(cfg()["meter"]["full"]), 0.0, 1.0)


## What the HUD bar shows, coarsely: it redraws only when this changes ("pulse..." redraws every frame).
func bar_key() -> String:
	var st := hud_state()
	match st:
		"warning":
			return "w%d%s" % [int(ceil(main.fight.breather_left())), "h" if holding() else ""]
		"blocked":
			return "pulse"
	return "m%d%s" % [int(meter() * 2.0), st]


func _blocked_short(why: String) -> String:
	match why:
		"fire": return "rebuild the fire"
		"down": return "get up"
		"away": return "back to camp"
		"busy": return "finish fishing"
		"fight": return "after this fight"
	return "coming"


func _blocked_note(why: String) -> String:
	match why:
		"fire": return "Rebuild the campfire first: the Gloom waits"
		"down": return "Get back on your paws first: the Gloom waits"
		"away": return "Come back to the camp: the Gloom waits"
		"busy": return "Finish what you are doing: the Gloom waits"
		"fight": return "After this fight: the Gloom waits"
	return "It is on its way"


# ---------------------------------------------------------------- the Watch card (the signpost once raids are open)
func _row(text: String, note: String, label := "", action := Callable(), enabled := false, cost := {}) -> Dictionary:
	return {"text": text, "note": note, "cost": cost, "label": label, "enabled": enabled and Data.can_afford(cost), "action": action}


## "The Gloom Herald" -> "the Gloom Herald" (inside a sentence).
func _the(name: String) -> String:
	return "the " + name.substr(4) if name.begins_with("The ") else name


func card_watch(anchor: Vector3) -> Dictionary:
	var r: Dictionary = Save.raids
	var plan: Dictionary = r["plan"]
	var cc := camp_check()
	var pct := int(floor(meter()))
	var first := not bool(r["first_done"])
	var lv := int(plan["level"]) if not plan.is_empty() else raid_level(first)
	var sub := "Gloom %d%% · raid level %d · camp %d%%" % [pct, lv, int(round(float(cc["condition"]) * 100.0))]
	var rows: Array = []
	var pending := bool(r["pending"])
	if pending:
		rows.append(_row("A raid is waiting", _blocked_note(blocked_reason())))
	elif meter() < float(cfg()["meter"]["call_from"]):
		rows.append(_row("The Gloom is gathering", "It fills while you play, never while the game is closed · %d%%" % pct))
	else:
		var p2: Dictionary = plan if not plan.is_empty() else {"first": first, "type": String(cfg()["first_raid"]) if first else ""}
		var note := "Call the raid now: %d s to get ready" % int(warn_seconds(p2, true))
		if has_unlock("watch:tracker") and not plan.is_empty():
			note = "Next: %s from %s" % [type_name(plan), trail_names(plan["lanes"])]
		rows.append(_row("Sound the horn", note, "Sound", call_now, true))
	rows.append(camp_row(cc))
	rows.append_array(shop_rows())
	var stats := "Perfect streak %d · best %d" % [int(r["streak"]), int(r["best_streak"])]
	if bool(r.get("last_lost", false)):
		stats = "The next raid will be a little gentler"
	elif int(r["held"]) + int(r["lost"]) == 0:
		stats = "No raid has come yet"
	rows.append(_row("Raids held %d · perfect %d" % [int(r["held"]), int(r["perfect"])], stats))
	var g = main.get("guardian")
	if g != null and g.has_method("status_text"):
		rows.append(_row(Data.guardian_name(), String(g.status_text())))
	var why := "A raid is at the gate: meet it first" if pending else ""
	rows.append_array(main.stations._run_rows(why))    # a saved mission run only: won missions are not replayed (Phase F)
	return {"title": "The Watch", "sub": sub, "rows": rows, "anchor": anchor}


## The signpost while a raid is on: its warning, its waves and the breathers between them.
func card_raid(anchor: Vector3) -> Dictionary:
	var f = main.fight
	var spec: Dictionary = f.raid
	var nm: String = f.title()
	var leader := String(spec.get("leader", ""))
	if f.in_wave:
		var how := "topple %s to break it" % _the(leader_name(leader)) if leader != "" else "hold every wave"
		return {"title": nm, "sub": "Wave %d of %d · %s" % [f.wave, f.waves(), how], "rows": [], "anchor": anchor}
	var rows: Array = []
	if f.warning:
		var left: String = f.mmss(f.breather_left())
		var sub := ("Trail unknown · %s to get ready" % left) if hidden_now() else ("From %s · %s to get ready" % [trail_text(), left])
		rows.append(_row("Meet them now", "Start the raid", "Go", f.next_phase_now, true))
		rows.append(camp_row(camp_check()))
		rows.append(_row("What's coming", coming_text()))
		return {"title": nm + "!", "sub": sub, "rows": rows, "anchor": anchor}
	rows.append(_row("Next wave now", "Skip the rest of the breather", "Go", f.next_phase_now, true))
	rows.append(camp_row(camp_check()))
	return {"title": nm, "sub": f.status_text(), "rows": rows, "anchor": anchor}


## "Stump Golems, Toadstool Brutes, Bramble Boars · led by the Gloom Herald · level 8"
func coming_text() -> String:
	var plan: Dictionary = Save.raids["plan"]
	if plan.is_empty():
		return ""
	var t: Dictionary = cfg()["types"][String(plan["type"])]
	var pool: Array = (t["pool"] as Array).duplicate()
	pool.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	var names: Array = []
	for pair in pool:
		if names.size() >= 3:
			break
		if Data.b["enemies"].has(String(pair[0])):
			names.append(String(Data.enemy(String(pair[0]))["name"]) + "s")
	var leader := String(plan.get("leader", ""))
	var bits: Array = [", ".join(names)]
	if Data.b["enemies"].has(leader):
		bits.append("led by %s" % _the(leader_name(leader)))
	bits.append("level %d" % int(plan["level"]))
	return " · ".join(bits)


## The items Mend some can afford now, in priority order (it skips what it cannot pay and goes on), and their cost.
func _mend_plan(cc: Dictionary) -> Dictionary:
	var leaves := Save.leaves
	var timber := Save.timber
	var fix: Array = []
	var cost := {"leaves": 0, "timber": 0}
	for it in cc["items"]:
		var l := int(it["cost"].get("leaves", 0))
		var t := int(it["cost"].get("timber", 0))
		if l <= leaves and t <= timber:
			leaves -= l
			timber -= t
			cost["leaves"] += l
			cost["timber"] += t
			fix.append(it)
	return {"items": fix, "cost": cost}


## "1 ruin · 3 defences wrecked · the Hearthtree worn 20%"
func damage_text(cc: Dictionary) -> String:
	var bits: Array = []
	var nr := (cc["ruins"] as Array).size()
	if nr > 0:
		bits.append("%d ruin%s" % [nr, "" if nr == 1 else "s"])
	var nw := (cc["wrecks"] as Array).size()
	if nw > 0:
		bits.append("%d defence%s wrecked" % [nw, "" if nw == 1 else "s"])
	var k := 0
	for id in cc["wear"]:
		if k >= 2:
			bits.append("more worn")
			break
		var nm := Data.camp_name() if id == "home" else String(Data.b["stations"][id]["name"]).to_lower()
		bits.append("%s worn %d%%" % [nm, int(round(float(cc["wear"][id]) * 100.0))])
		k += 1
	return " · ".join(bits)


## The camp check row (the Watch, the warning and breather cards, the top of the shop): Mend all, or Mend some.
func camp_row(cc: Dictionary) -> Dictionary:
	if (cc["items"] as Array).is_empty():
		return _row("The camp is in good shape", "Nothing to mend · camp %d%%" % int(round(float(cc["condition"]) * 100.0)))
	var wave_on: bool = main.fight.active and main.fight.in_wave
	var note := damage_text(cc)
	var all: Dictionary = cc["cost"]
	if Data.can_afford(all):
		return {"text": "Mend all", "note": note, "cost": _clean(all), "label": "Mend all", "enabled": not wave_on, "action": mend_all}
	var mp := _mend_plan(cc)
	var left := (cc["items"] as Array).size() - (mp["items"] as Array).size()
	if (mp["items"] as Array).is_empty():
		return {"text": "Mend the camp", "note": note + " · not enough to mend any of it yet", "cost": _clean(all), "label": "Mend all", "enabled": false, "action": mend_all}
	return {"text": "Mend some", "note": note + " · %d thing%s left after" % [left, "" if left == 1 else "s"], "cost": _clean(mp["cost"]),
		"label": "Mend some", "enabled": not wave_on, "action": mend_all}


func _clean(c: Dictionary) -> Dictionary:
	var out := {}
	for k in c:
		if int(c[k]) > 0:
			out[k] = int(c[k])
	return out


## Mend all (or some): everything it can pay for, in priority order; each mended thing springs back with a flower ring,
## one after another across the camp. Blocked during a wave.
func mend_all() -> void:
	if main.fight.active and main.fight.in_wave:
		return
	var cc := camp_check()
	var mp := _mend_plan(cc)
	var done: Array = mp["items"]
	if done.is_empty():
		return
	if not Data.pay(mp["cost"]):
		return
	var spots: Array = []
	var st = main.stations
	for it in done:
		match String(it["kind"]):
			"ruin":
				st.mend_ruin(String(it["id"]))
				spots.append([st.nodes.get(String(it["id"])), main.world.station_pos(String(it["id"])), 1.4])
			"wreck":
				main.defences.mend_piece(it["piece"], true, false)
				spots.append([it["piece"]["node"], it["piece"]["pos"], 0.9])
			"wear":
				st.mend_wear(String(it["id"]))
				spots.append([st.nodes.get(String(it["id"])), main.world.station_pos(String(it["id"])), 1.2])
	Save.save_game()
	st.refresh()
	main.refresh_companions()
	var stagger := float(cfg()["repair"]["mend_stagger_s"])
	for k in spots.size():
		var sp: Array = spots[k]
		get_tree().create_timer(stagger * k + 0.01).timeout.connect(func():
			if sp[0] != null and is_instance_valid(sp[0]):
				Fx.boing(sp[0], 0.3)
			Fx.flower_ring(main, sp[1], float(sp[2])))
	var left := (cc["items"] as Array).size() - done.size()
	if left == 0:
		main.hud.banner("The camp is mended!", Color(1.0, 0.9, 0.5), "Ready for the next raid")
	else:
		main.hud.banner("Mended %d of %d" % [done.size(), (cc["items"] as Array).size()], Color(1.0, 0.9, 0.5), "Gather more leaves for the rest")
	main.on_purchase()


# ---------------------------------------------------------------- what Gloom shards buy at the Watch
## Lookout and Tracker (until owned), and the campfire's look.
func shop_rows() -> Array:
	var rows: Array = []
	var w: Dictionary = cfg()["watch"]
	for id in ["lookout", "tracker"]:
		if has_unlock("watch:" + id):
			continue
		var it: Dictionary = w[id]
		rows.append(_row(String(it["name"]), String(it["note"]), "Buy", buy_watch.bind(id), true, {"shards": int(it["shards"])}))
	var looks: Array = cfg()["fire_looks"]
	var cur := ""
	for fl in looks:
		if String(fl["id"]) == Save.fire_look:
			cur = String(fl["name"])
	for fl in looks:
		var id2 := String(fl["id"])
		if id2 == "" or has_unlock("fire:" + id2):
			continue
		rows.append(_row("Campfire look: %s" % cur, "%s burns blue-violet · earned with Gloom shards" % String(fl["name"]), "Unlock",
			unlock_fire.bind(id2), true, {"shards": int(fl.get("shards", 0))}))
		return rows
	var owned: Array = looks.filter(func(fl): return String(fl["id"]) == "" or has_unlock("fire:" + String(fl["id"])))
	if owned.size() > 1:
		rows.append(_row("Campfire look: %s" % cur, "Change how the campfire burns", "Change", next_fire_look, true))
	return rows


func buy_watch(id: String) -> void:
	var it: Dictionary = cfg()["watch"].get(id, {})
	if it.is_empty() or has_unlock("watch:" + id) or not Data.pay({"shards": int(it["shards"])}):
		return
	Save.unlocks.append("watch:" + id)
	_update_watch_model(true)
	main.world.update_watch()
	var s = main.world.get("sign_node")
	if s != null and is_instance_valid(s):
		var part := Props.find_part(s, "lookout_flag" if id == "lookout" else "tracker_bell")
		Fx.boing(part if part != null else s, 0.35)
	Fx.flower_ring(main, main.world.station_pos("sign"), 1.2)
	Save.save_game()
	main.hud.banner("%s!" % String(it["name"]), Color(0.8, 0.6, 1.0), String(it["note"]))
	main.on_purchase()


func unlock_fire(id: String) -> void:
	for fl in cfg()["fire_looks"]:
		if String(fl["id"]) == id and not has_unlock("fire:" + id) and Data.pay({"shards": int(fl.get("shards", 0))}):
			Save.unlocks.append("fire:" + id)
			set_fire_look(id)
			return


func next_fire_look() -> void:
	var owned: Array = (cfg()["fire_looks"] as Array).filter(func(fl): return String(fl["id"]) == "" or has_unlock("fire:" + String(fl["id"])))
	var i := 0
	for k in owned.size():
		if String(owned[k]["id"]) == Save.fire_look:
			i = k
	set_fire_look(String(owned[(i + 1) % owned.size()]["id"]))


func set_fire_look(id: String) -> void:
	Save.fire_look = id
	main.stations.apply_fire_look()
	Save.save_game()
	var nm := "Campfire"
	for fl in cfg()["fire_looks"]:
		if String(fl["id"]) == id:
			nm = String(fl["name"])
	main.hud.banner(nm, Color(0.8, 0.6, 1.0) if id != "" else Color(1.0, 0.8, 0.45), "The campfire burns anew")
	main.on_purchase()


## Bramble buys Gloom shards (so they are never useless): 5 for 100 leaves.
func trade_shards() -> void:
	var st: Dictionary = cfg()["shard_trade"]
	if not Data.pay({"shards": int(st["shards"])}):
		return
	Save.add_leaves(int(st["leaves"]))
	Save.save_game()
	Fx.sparkle(main, main.world.station_pos("stall") + Vector3(0, 1.2, 0))
	main.on_purchase()
