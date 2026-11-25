extends Node
## H1: the object pools and the event board (`-- --autotest --fresh --pools`), run from autotest.gd. Each check logs
## "EXPECT PASS <what>" or "EXPECT FAIL <what>" through autotest.gd's _expect.
## Uses: Pools (stats), Events (enemy_died, damage_dealt, wave_started, wave_ended), the cat's own shooting, enemies
## from fight.spawn, their leaves, Fx. Writes only the test save, like every autotest.
## What it plays and checks:
##   (a) the camp opens with each pool made ahead (balance.json "pools" at this graphics level)
##   (b) a live mission wave: wave_started(1), then its enemies beaten: wave_ended(1, held)
##   (c) two short fights played the same way: a few Thornlings stood near the cat, which shoots them by itself; their
##       leaves fly to it. Arrows, damage numbers, hit bursts and pickups appear on the field; afterwards every pooled
##       object is back in its pool; the second fight made nothing new; nothing pooled was freed; an arrow flying again
##       with the same bow kept its model and trail; enemy_died came once per enemy and damage_dealt for every hit
##   (d) a pooled arrow shot with another bow wears that bow's arrow and trail
##   (e) arrows still in flight when the fight ends (its foes cleared) go back to the pool too

const ArrowScript := preload("res://scripts/arrow.gd")
const FOES := 5                          # Thornlings per fight
const SPOT := Vector3(-1.5, 0, 12.0)     # where the cat stands for the fights (outside the camp, as the bow tests do)

var t: Variant                           # autotest.gd (its helpers: _wait, _until, _expect, _log, _reset_fight)
var main: Variant

var _died: Array = []                    # [kind, at, enemy] of every enemy_died this test heard
var _dealt := 0                          # damage_dealt heard
var _dealt_bad := 0                      # damage_dealt with a target that is not an enemy, or no damage
var _waves: Array = []                   # ["start", n] / ["end", n, held]
var _flights := {}                       # arrow instance id -> {its take count: its model's instance id}, as seen flying
var _drops := {}                         # "<pickup id>:<its trip>" -> the leaves it was worth, as seen on the field (a fight)


func run() -> bool:
	main.player.invincible = true
	main.hud.hide_card()
	Events.enemy_died.connect(_on_died)
	Events.damage_dealt.connect(_on_dealt)
	Events.wave_started.connect(_on_wave_started)
	Events.wave_ended.connect(_on_wave_ended)
	await t._wait(0.3)
	var ok := _made_ahead()
	ok = await _live_wave() and ok
	ok = await _two_fights() and ok
	ok = await _bow_swap() and ok
	ok = await _mid_flight() and ok
	Events.enemy_died.disconnect(_on_died)
	Events.damage_dealt.disconnect(_on_dealt)
	Events.wave_started.disconnect(_on_wave_started)
	Events.wave_ended.disconnect(_on_wave_ended)
	Engine.time_scale = 1.0
	t._log("pools done", {"pools": Pools.stats()})
	return ok


func _on_died(kind: String, at: Vector3) -> void:
	_died.append([kind, at])


func _on_dealt(target: Node, amount: float) -> void:
	_dealt += 1
	if target == null or not target.is_in_group("enemies") or amount <= 0.0:
		_dealt_bad += 1


func _on_wave_started(n: int) -> void:
	_waves.append(["start", n])


func _on_wave_ended(n: int, held: bool) -> void:
	_waves.append(["end", n, held])


# ---------------------------------------------------------------- (a) made ahead
func _made_ahead() -> bool:
	var s := Pools.stats()
	var want := {"arrow": Pools.size_for("arrows"), "fx_label": Pools.size_for("numbers"),
		"pickup": Pools.size_for("pickups"), String(Fx._burst_key(Quality.particles(Fx.HIT_N))): Pools.size_for("hit_fx")}
	var ok := true
	var got := {}
	for k: String in want:
		var made := int(s.get(k, {}).get("made", 0))
		got[k] = made
		ok = ok and made >= int(want[k]) and int(want[k]) > 0
	return t._expect("each pool is made ahead when the camp opens (balance.json pools, %s graphics)" % Quality.NAMES[Quality.level],
		ok, {"want": want, "made": got})


# ---------------------------------------------------------------- (b) a live mission wave
func _live_wave() -> bool:
	var f = main.fight
	Save.missions_done = []
	Save.mission_run = {}
	Save.fire_ruined = false
	Save.raids["pending"] = false
	f.mission = -1
	_waves.clear()
	f.start_mission(0)
	var ok: bool = t._expect("a mission's first wave announces wave_started(1)", f.active and f.in_wave and _waves.has(["start", 1]),
		{"waves": _waves, "active": f.active})
	await t._until(func(): return _foes().size() >= 2 or f._queue.is_empty(), 15.0)
	f._queue.clear()
	f._qinfo.clear()
	for e in _foes():
		e.hit(Vector3.FORWARD, e.hp + 1.0)
	var cleared: bool = await t._until(func(): return not f.in_wave, 5.0)
	ok = t._expect("its enemies beaten, the wave announces wave_ended(1, held)", cleared and _waves.has(["end", 1, true]),
		{"waves": _waves}) and ok
	t._reset_fight()
	Save.mission_run = {}
	Save.save_game()
	await _settle()
	return ok


# ---------------------------------------------------------------- (c) two fights, played the same way
func _two_fights() -> bool:
	var r1: Dictionary = await _fight(1)
	var s1 := Pools.stats()
	var r2: Dictionary = await _fight(2)
	var s2 := Pools.stats()
	t._log("pools after two fights", {"first": r1, "second": r2, "after_first": s1, "after_second": s2})
	var ok := true
	for r: Dictionary in [r1, r2]:
		ok = t._expect("fight %d: all %d Thornlings fall to the cat's arrows" % [r["n"], FOES], bool(r["all_down"]), r) and ok
		ok = t._expect("fight %d: arrows fly, numbers pop, hit bursts play and leaves drop" % r["n"],
			int(r["seen"]["arrows"]) > 0 and int(r["seen"]["numbers"]) > 0 and int(r["seen"]["bursts"]) > 0
			and int(r["seen"]["pickups"]) > 0 and int(r["took"]["arrow"]) > 0 and int(r["took"]["fx_label"]) > 0
			and int(r["took"]["bursts"]) > 0 and int(r["took"]["pickup"]) > 0, {"seen": r["seen"], "took": r["took"]}) and ok
		ok = t._expect("fight %d: enemy_died came once for each Thornling" % r["n"], int(r["died"]) == FOES and int(r["died_kind"]) == FOES,
			{"died": r["died"], "thornlings": r["died_kind"]}) and ok
		ok = t._expect("fight %d: damage_dealt came for the hits, each with an enemy and its damage" % r["n"],
			int(r["dealt"]) >= FOES and int(r["dealt_bad"]) == 0, {"dealt": r["dealt"], "bad": r["dealt_bad"]}) and ok
		ok = t._expect("fight %d: the leaves collected are exactly the leaves dropped (no pickup paid twice)" % r["n"],
			int(r["leaves"]) > 0 and int(r["leaves"]) == int(r["dropped"]),
			{"leaves": r["leaves"], "dropped": r["dropped"], "drops": r["drops"]}) and ok
	# every pooled object is back
	var out := {}
	for k: String in s2:
		if int(s2[k]["out"]) > 0:
			out[k] = s2[k]["out"]
	ok = t._expect("after the fights every pooled object is back in its pool", out.is_empty(), {"still_out": out}) and ok
	# nothing pooled was freed
	var lost := {}
	for k: String in s2:
		if int(s2[k]["lost"]) > 0:
			lost[k] = s2[k]["lost"]
	ok = t._expect("no pooled object was freed", lost.is_empty(), {"lost": lost}) and ok
	# the second fight made nothing new
	var grew := {}
	for k: String in s2:
		var before := int(s1.get(k, {}).get("made", 0))
		if int(s2[k]["made"]) > before:
			grew[k] = [before, int(s2[k]["made"])]
	ok = t._expect("the second fight reused the first one's objects (no pool made more)", grew.is_empty(),
		{"grew": grew, "took_second": r2["took"]}) and ok
	var reused := int(s2.get("arrow", {}).get("taken", 0)) > int(s2.get("arrow", {}).get("made", 0)) \
		and int(s2.get("fx_label", {}).get("taken", 0)) > int(s2.get("fx_label", {}).get("made", 0))
	ok = t._expect("arrows and numbers were taken more often than made (reused)", reused,
		{"arrow": s2.get("arrow", {}), "fx_label": s2.get("fx_label", {})}) and ok
	# an arrow that flew again with the same bow kept its model (and so its trail: both are swapped together)
	var again := 0
	var swapped := 0
	for id: int in _flights:
		var by_take: Dictionary = _flights[id]
		if by_take.size() > 1:
			again += 1
			var models := {}
			for g: int in by_take:
				models[by_take[g]] = true
			if models.size() > 1:
				swapped += 1
	ok = t._expect("an arrow flying again with the same bow keeps its model and trail", again > 0 and swapped == 0,
		{"arrows_seen_again": again, "with_a_new_model": swapped}) and ok
	return ok


# ---------------------------------------------------------------- (d) another bow: the pooled arrow changes its look
func _bow_swap() -> bool:
	var pl = main.player
	pl.global_position = SPOT
	var e = main.fight.spawn("thornling", SPOT + Vector3(0, 0, 4.0), 0)
	main.hud.hide_card()
	e.hp = 1e6
	e.max_hp = 1e6
	e.set_physics_process(false)
	var keep: String = Save.bow
	var ok := true
	for bid: String in ["frost", "twig"]:
		Save.bow = bid
		pl.target = e
		pl._fire()
		var a = null
		for c in main.get_children():
			if c.get_script() == ArrowScript and c._flying:
				a = c                                         # the newest arrow (added last)
		var fx: Dictionary = Data.bow_fx(bid)
		var want_trail := 0 if fx.is_empty() else 1 + (1 if String(fx.get("trail", "")) == "glint" else (2 if String(fx.get("trail", "")) in ["flame", "frost"] else 0))
		var own: bool = ResourceLoader.exists(ArrowScript.arrow_path(bid))
		var model_ok: bool = a != null and (not own or String((a._model as Node).scene_file_path) == ArrowScript.arrow_path(bid))
		ok = t._expect("a pooled arrow shot with the %s bow wears that bow's arrow and trail" % bid,
			a != null and String(a._dressed) == "%s@%d" % [bid, Quality.level] and model_ok and (a._trail as Array).size() == want_trail
			and Pools.is_pooled(a),
			{"dressed": a._dressed if a != null else "", "trail": (a._trail as Array).size() if a != null else -1, "want": want_trail,
			"model": (a._model as Node).scene_file_path if a != null else ""}) and ok
		await t._wait(0.4)
	Save.bow = keep
	pl.target = null
	main.fight._clear_foes()
	await t._wait(2.0)
	return ok


## One short fight: FOES Thornlings stood in front of the cat, shot by the cat by itself; their leaves are called home.
## Returns what was seen on the field and taken from the pools.
func _fight(n: int) -> Dictionary:
	var pl = main.player
	pl.global_position = SPOT
	pl.target = null
	var before := Pools.stats()
	var died0 := _died.size()
	var dealt0 := _dealt
	var bad0 := _dealt_bad
	var leaves0: int = Save.leaves
	var foes: Array = []
	for i in FOES:
		var at := SPOT + Vector3((i - (FOES - 1) * 0.5) * 1.1, 0, 3.6 + 0.25 * (i % 2))
		var e = main.fight.spawn("thornling", at, 0)
		main.hud.hide_card()
		e.hp = Data.arrow_damage() * 2.5                     # three arrows each: two fights shoot more than are made ahead
		e.max_hp = e.hp
		e.set_physics_process(false)                          # stood still: the same fight every time
		foes.append(e)
	var seen := {"arrows": 0, "numbers": 0, "bursts": 0, "pickups": 0}
	_drops.clear()
	Engine.time_scale = 2.0
	var waited := 0.0
	while waited < 25.0 and not foes.all(func(e): return not is_instance_valid(e) or e.dead):
		_look(seen)
		await t._wait(0.05)
		waited += 0.05
	var all_down: bool = foes.all(func(e): return not is_instance_valid(e) or e.dead)
	for k in 10:                                              # the last hits' numbers and bursts, the leaves popping out
		_look(seen)
		await t._wait(0.05)
	for p in get_tree().get_nodes_in_group("pickups"):
		p.call_home()                                         # as the end of a wave does
	await t._until(func(): return get_tree().get_nodes_in_group("pickups").is_empty(), 6.0)
	Engine.time_scale = 1.0
	await _settle()
	var after := Pools.stats()
	var took := {"arrow": _took(before, after, "arrow"), "fx_label": _took(before, after, "fx_label"),
		"pickup": _took(before, after, "pickup"), "bursts": 0}
	for k: String in after:
		if k.begins_with("fx_burst_"):
			took["bursts"] = int(took["bursts"]) + _took(before, after, k)
	var kinds := 0
	for d: Array in _died.slice(died0):
		if String(d[0]) == "thornling":
			kinds += 1
	var dropped := 0
	for k: String in _drops:
		dropped += int(_drops[k])
	return {"n": n, "all_down": all_down, "seen": seen, "took": took, "died": _died.size() - died0, "died_kind": kinds,
		"dealt": _dealt - dealt0, "dealt_bad": _dealt_bad - bad0, "leaves": Save.leaves - leaves0, "dropped": dropped,
		"drops": _drops.size()}


## What is showing on the field now, kept as the most seen at once.
func _look(seen: Dictionary) -> void:
	var arrows := 0
	var numbers := 0
	var bursts := 0
	for c in main.get_children():
		if c.get_script() == ArrowScript and c._flying and c.visible:
			arrows += 1
			var id: int = c.get_instance_id()
			if not _flights.has(id):
				_flights[id] = {}
			(_flights[id] as Dictionary)[int(c.get_meta(&"pool_gen", 0))] = (c._model as Node).get_instance_id()   # Pools.GEN
		elif c is Label3D and (c as Label3D).visible:
			numbers += 1
		elif c is CPUParticles3D and (c as CPUParticles3D).visible and (c as CPUParticles3D).emitting:
			bursts += 1
	seen["arrows"] = maxi(int(seen["arrows"]), arrows)
	seen["numbers"] = maxi(int(seen["numbers"]), numbers)
	seen["bursts"] = maxi(int(seen["bursts"]), bursts)
	seen["pickups"] = maxi(int(seen["pickups"]), get_tree().get_nodes_in_group("pickups").size())
	for p in get_tree().get_nodes_in_group("pickups"):
		if String(p.kind) == "leaf" and not p.taken:
			_drops["%d:%d" % [p.get_instance_id(), int(p.trip)]] = int(p.value)   # one entry per drop of a pooled pickup


func _took(before: Dictionary, after: Dictionary, key: String) -> int:
	return int(after.get(key, {}).get("taken", 0)) - int(before.get(key, {}).get("taken", 0))


# ---------------------------------------------------------------- (e) arrows in flight when the fight ends
func _mid_flight() -> bool:
	var pl = main.player
	pl.global_position = SPOT
	pl.target = null
	var e = main.fight.spawn("thornling", SPOT + Vector3(0, 0, 4.8), 0)
	main.hud.hide_card()
	e.hp = 1e6
	e.max_hp = 1e6
	e.set_physics_process(false)
	var flying := func() -> int:                              # arrows really in the air now (not a fading trail)
		var n := 0
		for c in main.get_children():
			if c.get_script() == ArrowScript and c._flying:
				n += 1
		return n
	var shot: bool = await t._until(func(): return flying.call() > 0, 6.0)
	var out_then: int = flying.call()
	main.fight._clear_foes()                                  # the fight ends with the arrow in the air (as a camp fall does)
	await t._wait(2.5)
	var s: Dictionary = Pools.stats().get("arrow", {})
	return t._expect("arrows in flight when the fight ends go back to the pool", shot and out_then > 0 and int(s.get("out", -1)) == 0
		and int(s.get("lost", -1)) == 0, {"in_flight": out_then, "arrow_pool": s})


# ---------------------------------------------------------------- helpers
func _foes() -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("foes"):
		if not e.is_in_group("bonus"):
			out.append(e)
	return out


## Long enough for every pop-up, burst and arrow trail to play out and go back.
func _settle() -> void:
	await t._wait(2.0)
