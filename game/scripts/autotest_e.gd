extends Node
## The Burrows' tests (Phase E, and the dungeon as a path: docs/DUNGEON_SPEC.md), run from autotest.gd
## (`-- --autotest --fresh --<mode>`). Each check logs "EXPECT PASS <what>" or "EXPECT FAIL <what>" through autotest.gd's
## _expect. Modes:
##   --dungeon          the whole Gloomwood at level 1, walked and fought for real: every stop, the boss, the seal, home
##   --dungeonshots     every stop at the window's size (480x1040 is the S24's HUD shape), with --quality=low or high
##   --dungeonfall      a knock-out: half the satchel kept
##   --dungeonresume=1  a run saved at the Moonwell (then =2 on the same save: Go back in, then Leave it)
##   --boss             the arena only: the roots, the boss, adds, a dash into a standing stone, the fight's length
##   --dungeonperf      draw calls and fps in the Gloomwood beside the camp's (with --quality=low)
##   --dungeontreasure  a map that ends in a treasure clearing (data/dungeons/test_glade.json)
##   --dungeonlevels    what each level fills the fights with (pools, sizes, snappers, elites, the boss)
##   --dungeonstand     how hard (19 Nov 2026): the endgame cat walks level 1 and just stands and shoots (no dodging,
##                      lunches or mount): it must be knocked out before the end; =god gives it 1,000 extra health to
##                      measure the health each fight takes and Mossback's time to kill; =items: it also rides Thistle,
##                      feeds it and eats its lunches, but still never dodges
##   --dungeoncareful   the same cat played with care: it rides Thistle and feeds it, eats lunches, steps out of the
##                      telegraphs and dashes through them, backs away from melee: it must win, with effort
##   kept from Phase E: --burrowsave, --hollow, --dash, --traps, --burrowfoes, --topup, --burrowhooks

var t                     # autotest.gd (its helpers: _wait, _shot, _expect, _until, _veteran, _go_straight, _press, _log)
var main


func run() -> bool:
	var a := Data.args()
	if a.has("--burrowsave"):
		await _burrowsave()
	elif a.has("--hollow"):
		await _hollow()
	elif a.has("--dash"):
		await _dash()
	elif a.has("--traps"):
		await _traps()
	elif a.has("--burrowfoes"):
		await _burrowfoes()
	elif a.has("--topup"):
		await _topup()
	elif a.has("--burrowhooks"):
		await _burrowhooks()
	elif a.has("--dungeon"):
		await _dungeon()
	elif a.has("--dungeonshots"):
		await _dungeonshots()
	elif a.has("--dungeonfall"):
		await _dungeonfall()
	elif a.has("--boss"):
		await _boss()
	elif a.has("--dungeonperf"):
		await _dungeonperf()
	elif a.has("--dungeontreasure"):
		await _dungeontreasure()
	elif a.has("--dungeonlevels"):
		await _dungeonlevels()
	else:
		return await _run_more(a)
	return true


func _run_more(a: PackedStringArray) -> bool:
	for arg in a:
		if arg in ["--dungeonstand", "--dungeonstand=god", "--dungeonstand=items", "--dungeoncareful"]:
			await _dungeonstand("careful" if arg == "--dungeoncareful" else ("real" if arg == "--dungeonstand" else arg.substr(15)))
			return true
		if arg.begins_with("--boss="):
			await _boss()
			return true
		if arg.begins_with("--dungeonresume"):
			await _dungeonresume(2 if arg.ends_with("=2") else 1)
			return true
	return false


func _x(what: String, ok: bool, extra := {}) -> bool:
	return t._expect(what, ok, extra)


# ---------------------------------------------------------------- helpers
func _r():
	return main.burrows.runner


func _map():
	return main.burrows.runner.map


## The world point at arc length s along the path (negative: from the end), `off` metres to the right.
func _sp(s: float, off := 0.0) -> Vector3:
	var m = _map()
	var sm: Array = m.sample(m.s_of(s))
	return m.w2((sm[0] as Vector2) + m.right_of(sm[1]) * off)


func _cat_s() -> float:
	return _map().progress(_map().m2(main.player.global_position)).x


func _fight(id: String) -> Dictionary:
	for f in _r().fights:
		if String(f["id"]) == id:
			return f
	return {}


## A camp past the last mission with the Burrows open (no reveal wait), the raid meter kept empty.
func _endgame_camp() -> void:
	main.player.invincible = true
	t._veteran(15)
	Save.raids["meter"] = 0.0
	Save.raids["pending"] = false
	main.raids.refresh_open()
	main.burrows.open_hollow(false)
	Save.save_game()
	await t._wait(0.5)


## A cat just past mission 15 (as the debug endgame save has it): the stats the Gloomwood is tuned for.
func _strong_cat() -> void:
	for st in ["damage", "draw", "health"]:
		Save.stats[st] = 9
	Save.stats["speed"] = 8
	Save.stats["range"] = 6
	Save.bows["sunwood"] = 9
	Save.bow = "sunwood"
	main.player.apply_bow()
	main.player.hp = Data.cat_max_hp()


func _enter(lvl := 1) -> void:
	main.set_riding(false, false)
	await main.burrows.enter("old_hollow", lvl)
	await t._wait(0.6)


## Every monster of the run struck down (the safety valve when a test does not want to fight).
func _kill_all() -> void:
	for e in _r().foes():
		e.hit(Vector3.FORWARD, e.hp + 99999.0)


func _fighting(e) -> bool:
	return e.awake and e.global_position.distance_to(main.player.global_position) < 16.0 and not e.has_meta("boss_of_room") and String(e.id) != "amber_grub"


## Waits while monsters are awake near the cat (the cat shoots by itself; it is invincible in these tests). After
## `secs` the rest are struck down. Returns the seconds it took and whether the cat won it by itself.
func _fight_here(secs := 50.0) -> Array:
	var tt := 0.0
	var won := true
	while tt < secs:
		var live: Array = _r().foes().filter(_fighting)
		if live.is_empty():
			break
		# step toward the nearest so the cat's range finds it (as a player would)
		var nr = live[0]
		for e in live:
			if e.global_position.distance_to(main.player.global_position) < nr.global_position.distance_to(main.player.global_position):
				nr = e
		if nr.global_position.distance_to(main.player.global_position) > 4.5:
			main.joystick.force = true
			var dv: Vector3 = nr.global_position - main.player.global_position
			main.joystick.forced = Vector2(dv.x, dv.z).normalized() * 0.6
		else:
			main.joystick.forced = Vector2.ZERO
		await t._wait(0.25)
		tt += 0.25
	main.joystick.forced = Vector2.ZERO
	if tt >= secs:
		won = false
		for e in _r().foes():
			if e.awake and not e.has_meta("boss_of_room"):
				e.hit(Vector3.FORWARD, e.hp + 99999.0)
		await t._wait(0.4)
	await t._wait(0.3)
	return [tt, won]


## Walks along the path to arc length s in short straight hops (as a player would), stopping to fight whatever wakes.
## Returns the fights' times on the way: {fight id: [seconds, won by itself]}.
func _walk_to(s_to: float, fight := true, timeout := 90.0) -> Dictionary:
	var out := {}
	var hops := 0
	var s := _cat_s()
	while absf(s - s_to) > 0.9 and hops < int(timeout / 0.9):
		hops += 1
		var nxt := s + clampf(s_to - s, -2.4, 2.4)
		await t._go_straight(_sp(nxt), 0.5, 3.0)
		var s2 := _cat_s()
		if absf(s2 - s) < 0.15 and absf(s_to - s2) > 0.9:
			main.player.global_position = _sp(nxt)            # stuck behind something: step on, as a player would
			s2 = _cat_s()
		s = s2
		if fight:
			for f in _r().fights:
				if String(f["state"]) == "awake":
					var res: Array = await _fight_here()
					if not out.has(f["id"]):
						out[f["id"]] = res
					else:
						out[f["id"]] = [float(out[f["id"]][0]) + float(res[0]), bool(out[f["id"]][1]) and bool(res[1])]
	return out


# ---------------------------------------------------------------- the whole Gloomwood
func _dungeon() -> void:
	await _endgame_camp()
	_strong_cat()                                        # the endgame save's cat; invincible: the walk checks every stop
	var mf := {"run": Save.mission_run.duplicate(), "done": Save.missions_done.size()}
	var sun0: float = main.world.sun.light_energy
	var r = _r()
	await main.burrows.enter("old_hollow", 1)
	await t._wait(0.8)
	var m = _map()
	t._log("map built", {"ms": m.build_ms, "length": snappedf(m.length, 0.1), "fights": r.fights.size(), "shapes": m.shapes.size(), "lamps": m.lamps.size()})
	_x("in the Gloomwood: main.area is the run, the map far from the camp", main.area == r and r.active and main.player.global_position.x > 300.0)
	_x("the path is 130-150 m from the way in to the arena's south edge", m.length - m.arena_r - 3.0 > 128.0 and m.length - m.arena_r - 3.0 < 152.0,
		{"to_arena": snappedf(m.length - m.arena_r - 3.0, 0.1)})
	_x("the night: its own camera environment, the sun a dim blue moon", main.cam.environment != null and main.world.sun.light_energy < sun0 - 0.3)
	_x("the first run ever: six fights and a boss on the HUD", r.fight_pips().size() == 7 and main.hud._stage_l.text.contains("Gloomwood · Level 1"),
		{"pips": r.fight_pips().size(), "status": main.hud._stage_l.text})
	_x("H1: no Hollow keys: the run starts with no boon and no key flag", (r.run["boons"] as Array).is_empty() and not r.run.has("key"), {"run": r.run})
	var am: Dictionary = r.cfg()["amber"]
	_x("H1: amber_value: none or unknown sources pay 0, the five named sources read the block", r.amber_value("") == 0.0 and r.amber_value("unhurt") == 0.0
		and r.amber_value("boss") == float(am["boss"]) and r.amber_value("sealed") == float(am["sealed"]) and r.amber_value("elite") == float(am["elite"])
		and r.amber_value("grub") == float(am["grub"]) and r.amber_value("first_clear") == float(am["first_clear"]), {"amber": am})
	# H1: a first clear pays its amber straight into the satchel (burrow_run._record_clear). Made certain for one call:
	# first_clear forced to 2.0 (floor 2, no chance part: exactly 2 every run, and a hard-coded 1 fails too), the level's
	# record set to "not beaten". The value, the record and the satchel are put back before anything else runs, so the
	# boss's own first clear still pays at the end of this walk.
	var bst: Dictionary = Save.burrow_stats(r.bid())
	var bst0: Dictionary = bst.duplicate()
	var sat_keep: Dictionary = r.satchel().duplicate()
	var fc0: Variant = am["first_clear"]
	am["first_clear"] = 2.0
	bst["depth"] = r.level() - 1
	var a_fc0 := int(r.satchel().get("amber", 0))
	var fc_first: bool = r._record_clear()
	var fc_got := int(r.satchel().get("amber", 0)) - a_fc0
	am["first_clear"] = fc0
	bst.merge(bst0, true)
	r.satchel().clear()
	r.satchel().merge(sat_keep)
	_x("H1: a first clear puts its amber straight into the satchel (first_clear forced to 2.0: exactly 2)", fc_first and fc_got == 2
		and int(Save.burrow_stats(r.bid())["depth"]) == int(bst0["depth"]), {"first": fc_first, "got": fc_got, "stats": Save.burrow_stats(r.bid())})
	# H1 (the owner): Lucky Paw gives chests more leaves and timber (chest_mult), never more amber (no chest_plus any more)
	var lucky: Dictionary = r.cfg()["boons"]["lucky"]
	var mods0: Dictionary = Data.run_mods
	Data.run_mods = {}
	var plain: Dictionary = r.chest_amounts("chest", false, 1.0)
	Data.run_mods = {"chest_mult": float(lucky["chest_mult"])}
	var with_paw: Dictionary = r.chest_amounts("chest", false, 1.0)
	Data.run_mods = mods0
	var tbl: Dictionary = r.cfg()["drops"]["chest"]
	_x("H1: Lucky Paw: a chest's leaves and timber x chest_mult, and no extra amber", not lucky.has("chest_plus") and float(lucky["chest_mult"]) > 1.0
		and int(with_paw["leaves"]) == int(round(Data.depth_drop(tbl, "leaves", r.level()) * float(lucky["chest_mult"])))
		and int(with_paw["timber"]) == int(round(Data.depth_drop(tbl, "timber", r.level()) * float(lucky["chest_mult"])))
		and int(with_paw["leaves"]) > int(plain["leaves"]), {"plain": plain, "lucky": with_paw})
	_x("the way home is open at the way in", m.parts.has("home_ring") and m.parts["home_ring"].visible)
	var hiding := _camera_side_check(m)
	_x("nothing tall hides walkable ground from the camera (trees, bushes, big rocks, glow caps)", hiding["bad"] == 0, hiding)
	await t._shot("dungeon_01_wayin")
	# 2. the sleeping camp: 5 Thornlings and 2 Glowcaps round a dead campfire
	await _walk_to(9.0, false)
	var camp := _fight("camp")
	var kinds: Array = (camp["foes"] as Array).map(func(e): return String(e.id))
	kinds.sort()
	_x("the sleeping camp: 5 Thornlings and 2 Glowcaps, asleep", kinds == ["glowcap", "glowcap", "thornling", "thornling", "thornling", "thornling", "thornling"]
		and (camp["foes"] as Array).all(func(e): return not e.awake), {"kinds": kinds})
	await t._shot("dungeon_02_camp_asleep")
	var times := {}
	main.player.global_position = _sp(13.8)
	var woke: bool = await t._until(func(): return String(camp["state"]) == "awake", 3.0)
	_x("the camp wakes together as the cat comes near", woke and (camp["foes"] as Array).all(func(e): return not is_instance_valid(e) or e.awake))
	_x("the way home closes once something wakes", not m.parts["home_ring"].visible)
	await t._wait(0.6)
	await t._shot("dungeon_03_camp_fight")
	times["camp"] = await _fight_here()
	await t._wait(0.3)
	_x("the sleeping camp is won", String(camp["state"]) == "done", {"t": times["camp"]})
	# 3. the burrow holes, and the nook's Gloom-bound chest
	var holes := _fight("holes")
	await t._go_straight(_sp(30.0), 0.5, 6.0)
	await _walk_to(31.6, false)
	var burst: bool = await t._until(func(): return (holes["spawners"] as Array)[0]["fired"], 2.0)
	_x("passing the first hole: 3 Grublings burst out", burst and (holes["foes"] as Array).size() == 3, {"n": (holes["foes"] as Array).size()})
	_x("an ambush on the way: Thornlings leapt out of the ferns", bool((_fight("ambush_wood")["spawners"] as Array)[0]["fired"]))
	await t._wait(0.9)
	await t._shot("dungeon_04_holes")
	times["holes_1"] = await _fight_here()
	await _walk_to(36.6)
	# the nook: walk up the side path to the chest, break its seal
	var nook_ring = m.parts.get("chest_nook_ring")
	await t._go_straight(m.w2(m.branches["nook"][0]), 0.5, 6.0)
	await t._use(nook_ring, 0.25, 8.0)
	await t._wait(1.0)
	await t._shot("dungeon_05_nook_card")
	var sat0: Dictionary = r.satchel().duplicate()
	var timber0 := Save.timber
	var broke: bool = t._press("Break")
	await t._wait(0.6)
	_x("breaking the seal: a Gloomtouched guard and 2 friends", broke and r._nook_guard.size() == 3 and r._nook_guard[0].gloomtouched)
	await t._wait(0.5)
	await t._shot("dungeon_06_nook_guard")
	times["nook"] = await _fight_here()
	await t._wait(2.0)
	# Twice the loot (drops.sealed_mult), shown exactly by the timber: it is banked the moment the chest opens and no kill
	# gives any (an unbroken chest at level 1 gives 3, a broken one 5).
	var tb_got := Save.timber - timber0
	var tb_want := int(r.chest_amounts("chest", true, 1.0)["timber"])
	var tb_plain := int(r.chest_amounts("chest", false, 1.0)["timber"])
	_x("the guard beaten: the chest opens with twice the loot (its timber x sealed_mult)", String(r.chests["nook"]["state"]) == "done"
		and tb_got == tb_want and tb_want > tb_plain, {"timber": tb_got, "want": tb_want, "unbroken": tb_plain})
	# H1: the chest's amber (burrows.amber.sealed 0.5 x sealed_mult 2 = exactly 1). Only the guard is elite (its 0.1 roll
	# may add one); its two friends drop none. Bounds from the drop values: floor of each at least, ceil of each at most.
	var v_chest: float = r.amber_value("sealed") * r._chest_mult(true, 1.0)
	var v_guard: float = r.amber_value("elite") * float(Data.run_mods.get("loot_mult", 1.0))
	var a_lo := int(floor(v_chest)) + int(floor(v_guard))
	var a_hi := int(ceil(v_chest)) + int(ceil(v_guard))
	await t._until(func(): return int(r.satchel().get("amber", 0)) - int(sat0.get("amber", 0)) >= a_lo, 3.0)
	var got := int(r.satchel().get("amber", 0)) - int(sat0.get("amber", 0))
	_x("H1: the broken seal's amber is doubled too (sealed x sealed_mult; the guard's elite roll may add one)", got >= a_lo and got <= a_hi,
		{"satchel": r.satchel(), "got": got, "lo": a_lo, "hi": a_hi})
	await t._go_straight(m.w2(m.branches["nook"][0]), 0.5, 8.0)
	var wk1: Dictionary = await _walk_to(46.0)
	times.merge(wk1)
	_x("all three Grubling holes fired and the named fight is won",
		String(holes["name"]) == "The Grubling holes" and (holes["spawners"] as Array).all(func(sp): return sp["fired"])
		and String(holes["state"]) == "done", {"name": holes["name"], "state": holes["state"]})
	# 4. the Glowcap clearing
	await _walk_to(51.0, false)
	await t._wait(0.5)
	await t._shot("dungeon_07_glade_asleep")
	var wk2: Dictionary = await _walk_to(60.0)
	times.merge(wk2)
	_x("the Glowcap clearing: a pack of 8 and a Gloomtouched Boar, won", (_fight("glade")["foes"] as Array).size() == 9 and String(_fight("glade")["state"]) == "done")
	_x("the pull: the bramble bend woke with the clearing (it is within link_r)", String(_fight("bend")["state"]) != "asleep")
	# 5. the bramble bend
	var wk3: Dictionary = await _walk_to(74.0)
	times.merge(wk3)
	_x("the bramble bend is won", String(_fight("bend")["state"]) == "done")
	# 6. the rolling logs: crossed unhurt, the chest at the end opens
	main.player.hp = Data.cat_max_hp()
	await _walk_to(78.5, false)
	await t._wait(1.4)
	await t._shot("dungeon_08_logs")
	await _walk_to(90.5, false)
	await t._go_straight(r.chests["logs"]["at"] + Vector3(0, 0, 0.95), 0.25, 4.0)
	await t._wait(1.2)
	_x("the logs: crossed unhurt, the chest at the end opens", String(r.chests["logs"]["state"]) == "done" and not r._zone_hurt and r._zone_in,
		{"hurt": r._zone_hurt, "in": r._zone_in})
	# 7. the Moonwell: checkpoint, the spring, a boon, the lift
	main.player.hp = 2
	await _walk_to(97.5, false)
	await t._wait(0.6)
	_x("the Moonwell is a checkpoint (saved)", String(Save.burrow_run.get("checkpoint", "")) == "moonwell", {"cp": Save.burrow_run.get("checkpoint", "")})
	await t._shot("dungeon_09_moonwell")
	await t._go_straight(m.parts["spring"].global_position, 0.2, 6.0)
	await t._wait(2.2)
	var want_hp := mini(2 + int(ceil(Data.cat_max_hp() * float(Data.burrow_cfg()["spring"]["heal"]))), Data.cat_max_hp())
	_x("the spring heals 40% of the cat's health, once", main.player.hp == want_hp and bool(r.run["spring_used"]), {"hp": main.player.hp, "want": want_hp})
	var nb: int = (r.run["boons"] as Array).size()
	await t._use(m.parts["shrine_0_ring"], 0.2, 6.0)
	await t._wait(1.0)
	await t._shot("dungeon_10_shrine")
	t._press("Take")
	await t._wait(0.6)
	_x("a boon taken, the other shrine fades", (r.run["boons"] as Array).size() == nb + 1 and not m.parts["shrine_1_ring"].visible)
	await t._use(m.parts["lift_ring"], 0.2, 8.0)
	await t._wait(1.0)
	_x("the Moonwell's root lift offers the way home", main.hud._card != null and _card_has("Climb"))
	await t._shot("dungeon_11_lift_card")
	main.hud.hide_card()
	# 8. the bridge: moths fly in as the cat steps on, a Gloomtouched elite and 2 guards hold the far end
	var br := _fight("bridge")
	await _walk_to(110.0, false)
	await _walk_to(113.0, false)
	var moths: bool = await t._until(func(): return (br["spawners"] as Array)[0]["fired"], 2.0)
	await t._wait(1.4)
	_x("stepping onto the bridge: moths fly in from the dark", moths and (br["foes"] as Array).filter(func(e): return is_instance_valid(e) and String(e.id) == "moth").size() >= 2)
	await t._shot("dungeon_12_bridge")
	var elites: Array = (br["foes"] as Array).filter(func(e): return is_instance_valid(e) and e.gloomtouched)
	_x("the far end: a Gloomtouched elite", elites.size() == 1, {"n": elites.size()})
	times["bridge_moths"] = await _fight_here()
	var wk4: Dictionary = await _walk_to(125.0)
	times.merge(wk4)
	_x("the bridge is won", String(br["state"]) == "done")
	# 9. the old oak, then the gate (checkpoint)
	var wk5: Dictionary = await _walk_to(m.length - 13.0)
	times.merge(wk5)
	_x("the old oak is won", String(_fight("oak")["state"]) == "done")
	await t._wait(0.5)
	_x("the arena gate is a checkpoint", String(Save.burrow_run.get("checkpoint", "")) == "gate")
	await t._shot("dungeon_13_gate")
	var all_won: bool = r.fights.all(func(f): return String(f["state"]) == "done")
	_x("every fight on the way woke and was won", all_won, {"times": times})
	t._log("fights", {"times": times})
	# 10. the arena: in, the roots close, Mossback wakes; the fight for real
	var amber_arena := int(r.satchel().get("amber", 0))     # the first clear's amber comes on top of this when the boss falls
	await _walk_to(m.length - 8.0, false)
	var sealed: bool = await t._until(func(): return m.sealed and r._boss != null and r._boss.awake, 3.0)
	_x("into the arena: the roots close, Mossback wakes with its bar", sealed and main.hud.boss == r._boss)
	await t._go_straight(m.w2(m.arena_c) + Vector3(0, 0, 1.0), 0.5, 4.0)
	_x("the arena camera is further out", absf(main._cam_dist - float(Data.burrow_cfg()["cam"]["arena"])) < 1.5 or r.cam_dist() == float(Data.burrow_cfg()["cam"]["arena"]))
	await t._wait(1.2)
	await t._shot("dungeon_14_arena_boss")
	var bt := 0.0
	var boss = r._boss
	var hp_was: float = boss.max_hp
	var gate_held := true
	while r._boss != null and is_instance_valid(r._boss) and not r._boss.dead and bt < 200.0:
		await t._wait(0.5)
		bt += 0.5
		if not m.in_arena(main.player.global_position, -0.1):
			gate_held = false
		if fmod(bt, 20.0) < 0.5:
			t._log("boss", {"t": bt, "hp": snappedf(boss.hp if is_instance_valid(boss) else 0.0, 1.0), "adds": r.foes().filter(func(e): return e.summoned).size()})
		if int(bt * 2.0) % 30 == 15:
			await t._shot("dungeon_15_boss_fight")
	var fell: bool = r._boss_down
	if not fell:
		r._boss.hit(Vector3.FORWARD, r._boss.hp + 1.0)
		await t._wait(1.0)
	_x("the boss (about %d health) falls in a long but sane time (40-160 s): %.1f s" % [int(hp_was), bt], fell and bt >= 40.0 and bt <= 160.0, {"secs": bt, "hp": hp_was})
	_x("the cat stayed in the arena while the roots were closed", gate_held)
	await t._wait(1.0)
	_x("the boss down: the roots open, level 1 beaten, the Warden sealed behind it", not m.sealed and Data.burrow_depth("old_hollow") == 1 and r._seal_due,
		{"sealed": m.sealed, "level": Data.burrow_depth("old_hollow"), "seal": r._seal_due})
	_x("the lift waits for the seal", not m.parts["end_lift_ring"].visible)
	# The satchel before the boss chest: taken here, because the walk to the seal passes the chest and opens it.
	var chest_shut := String(r.chests["end"]["state"]) == "shut"
	var amber0 := int(r.satchel().get("amber", 0))
	await t._go_straight(m.parts["seal_ring"].global_position, 0.2, 10.0)
	await t._wait(1.0)
	_x("standing by the seal does not break it (a tap does)", r._seal_due and main.hud._card == null)
	await t._tap(m.parts["seal_ring"])
	await t._wait(0.5)
	await t._shot("dungeon_16_seal")
	var freed: bool = await t._until(func(): return not r._seal_due, 6.0)
	_x("a tap on the seal frees the Moss Warden", freed and main.guardian != null and Data.guardian_awake())
	await t._go_straight(r.chests["end"]["at"] + Vector3(0, 0, 0.95), 0.25, 10.0)
	await t._wait(1.6)
	_x("the boss chest opened", String(r.chests["end"]["state"]) == "done")
	await t._shot("dungeon_17_chest")
	var want_amber := int(r.amber_value("boss"))
	var amber_in: bool = await t._until(func(): return int(r.satchel().get("amber", 0)) - amber0 >= want_amber, 4.0)
	# the first clear's amber went straight into the satchel when the boss fell (amber0 - amber_arena; anything picked up
	# in the arena can only add to it), and the boss chest's came on top of that
	_x("H1: the first clear's amber came in when the boss fell, the boss chest's on top of it", chest_shut and amber_in
		and amber0 - amber_arena >= int(r.amber_value("first_clear")), {"satchel": r.satchel(), "arena": amber_arena, "before": amber0, "want": want_amber,
		"chest_shut_before": chest_shut})
	var mats0: Dictionary = Save.mats.duplicate()
	var sat1: Dictionary = r.satchel().duplicate()
	await t._use(m.parts["end_lift_ring"], 0.2, 10.0)
	await t._wait(0.8)
	t._press("Climb")
	await t._until(func(): return main.area == null and not r.leaving, 6.0)
	await t._wait(0.6)
	var grew := true
	for k in sat1:
		if int(Save.mats.get(k, 0)) < int(mats0.get(k, 0)) + int(sat1[k]):
			grew = false
	_x("the lift home banks the whole satchel", grew and not sat1.is_empty(), {"satchel": sat1, "mats": Save.mats})
	# H1: no key field: the file on disk after a save (the old _loaded_fields test was true whatever was written)
	Save.save_game(true)
	var sf: Variant = JSON.parse_string(FileAccess.get_file_as_string(Save.path))
	var no_key: bool = sf is Dictionary and not (sf as Dictionary).has("burrow_keys") and not "burrow_keys" in Save
	_x("H1: only amber in the Bag, no key field in the saved file", Save.mats.keys() == ["amber"] and no_key, {"mats": Save.mats})
	_x("no run saved, the raids untouched", Save.burrow_run.is_empty() and not main.fight.active and Save.mission_run == mf["run"]
		and Save.missions_done.size() == int(mf["done"]))
	_x("back in the camp at the return spot, the camp's light again", main.area == null and main.player.global_position.distance_to(Vector3(0, 0, 15.5)) < 0.6
		and main.cam.environment == null and absf(main.world.sun.light_energy - sun0) < 0.01)
	_x("the run counted as won", int(Save.burrow_stats("old_hollow")["won"]) == 1)
	var card: Dictionary = main.burrows.card("old_hollow")
	_x("the Hollow card now opens level 2", String(card["rows"][0]["text"]).contains("Level 2"), {"row": card["rows"][0]["text"]})
	await t._wait(1.0)
	await t._shot("dungeon_18_back")


## Every tall woods instance on the map (from the meshes' own sizes): does any stand where it would hide walkable
## ground from the camera (the camera looks north, 50 degrees down)? {"checked", "bad", "first"}.
func _camera_side_check(m) -> Dictionary:
	var kinds := ["tree_jungle_1", "tree_jungle_2", "tree_round", "bush_1", "bush_2", "rock_2", "glow_mushroom_big"]
	var meshes := {}
	for k in kinds:
		meshes[Props.mesh(k)] = k
	var n := 0
	var bad: Array = []
	for c in m.get_children():
		if not (c is MultiMeshInstance3D) or not meshes.has((c as MultiMeshInstance3D).multimesh.mesh):
			continue
		var mm: MultiMesh = (c as MultiMeshInstance3D).multimesh
		var ab: AABB = mm.mesh.get_aabb()
		for i in mm.instance_count:
			var xf: Transform3D = mm.get_instance_transform(i)
			var sc: float = xf.basis.get_scale().x
			var q := Vector2(xf.origin.x, xf.origin.z)
			n += 1
			# the trunk/body may stand at the edge of the verge: the test allows the shrink the build used (0.85 for jungle trees)
			if m.hides(q, ab.size.y * sc * 0.97, maxf(ab.size.x, ab.size.z) * 0.5 * sc * 0.97):
				bad.append([meshes[mm.mesh], snappedf(q.x, 0.1), snappedf(q.y, 0.1)])
	return {"checked": n, "bad": bad.size(), "first": bad.slice(0, 6)}


func _card_has(label: String) -> bool:
	for bt in main.hud.card_buttons():
		if String(bt.get_meta("label", "")) == label:
			return true
	return false


# ---------------------------------------------------------------- screenshots of every stop
func _dungeonshots() -> void:
	await _endgame_camp()
	_strong_cat()
	await _enter(1)
	var r = _r()
	var m = _map()
	var q: String = ["low", "medium", "high"][Quality.level]
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	t._log("shots", {"quality": q, "view": vp, "build_ms": m.build_ms})
	var stops := [["01_wayin", 1.0, ""], ["02_camp", 12.5, ""], ["03_camp_fight", 14.0, "camp"], ["04_holes", 31.0, "holes"],
		["05_nook", -1.0, ""], ["06_glade", 52.0, ""], ["07_glade_fight", 54.5, "glade"], ["08_bend", 67.0, ""], ["09_logs", 79.0, ""],
		["10_moonwell", 98.0, ""], ["11_bridge", 112.6, "bridge"], ["12_farbank", 119.5, ""], ["13_oak", 131.0, ""], ["14_gate", m.length - 13.2, ""],
		["15_arena", m.length - 8.5, "boss"]]
	for st in stops:
		var to: Vector3 = m.parts["chest_nook_ring"].global_position if float(st[1]) < 0.0 else _sp(float(st[1]))
		for e in r.foes():
			if not e.has_meta("boss_of_room") and e.awake:
				e.hit(Vector3.FORWARD, e.hp + 99999.0)          # the last stop's fight is over
		main.player.hp = Data.cat_max_hp()
		main.player.global_position = to
		await t._wait(0.4)
		var fid := String(st[2])
		if fid != "" and fid != "boss":
			var f := _fight(fid)
			for sp in f["spawners"]:
				if not bool(sp["fired"]):
					r._fire_spawner(f, sp)
					break
			r._wake_fight(f)
		await t._wait(1.6 if fid != "" else 1.2)
		await t._shot("dshot_%s_%s" % [q, st[0]])
		main.hud.hide_card()
	# the boss down: the seal at the north edge
	if r._boss != null and is_instance_valid(r._boss):
		r._boss.hit(Vector3.FORWARD, r._boss.hp + 1.0)
		await t._wait(1.2)
	if m.parts.has("seal_ring"):
		main.player.global_position = m.parts["seal_ring"].global_position + Vector3(0, 0, 1.6)
		await t._wait(1.4)
		await t._shot("dshot_%s_16_seal" % q)
	# the cat and a monster close up at night (do they read?), and the map from above
	var th = r.spawn("thornling", _sp(40.0, 0.8), {})
	main.player.global_position = _sp(38.5)
	await t._wait(1.0)
	main.closeup_at = main.player
	main.closeup = Vector3(1.6, 3.2, 4.6)
	await t._wait(0.6)
	await t._shot("dshot_%s_17_closeup" % q)
	# a torch's pool of light close up (the camp's east torch): the road, the props and the woods lit warm
	var lamp: Vector3 = m.lamps[0]
	var cs: Vector3 = _map().wpt({"in": "camp"})
	for l in m.lamps:
		if (l as Vector3).distance_to(cs) < lamp.distance_to(cs):
			lamp = l
	main.player.global_position = m.constrain(Vector3(lamp.x, 0, lamp.z) + (cs - Vector3(lamp.x, 0, lamp.z)).normalized() * 1.6, 0.3, false)
	await t._wait(0.8)
	await t._shot("dshot_%s_18_lantern" % q)
	main.closeup = Vector3.ZERO
	main.closeup_at = null
	if th != null:
		th.queue_free()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = m._bounds.size.y + 8.0
	cam.far = 200.0
	main.add_child(cam)
	cam.global_position = m.w2(m._bounds.get_center()) + Vector3(0, 80.0, 0)
	cam.rotation = Vector3(-PI / 2.0, 0, 0)
	cam.current = true
	await t._wait(0.6)
	await t._shot("dshot_%s_00_map_top" % q)
	cam.current = false
	main.cam.current = true
	cam.queue_free()
	await r._leave("back")


# ---------------------------------------------------------------- a knock-out
func _dungeonfall() -> void:
	await _endgame_camp()
	var r = _r()
	await _enter(1)
	r.run["satchel"] = {"amber": 5}
	var mats0: Dictionary = Save.mats.duplicate()
	main.player.invincible = false
	main.player.hp = 1
	var leaves0 := Save.leaves
	var th = r.spawn("thornling", main.player.global_position + Vector3(0, 0, -0.9), {})
	_x("a thornling next to the cat", th != null)
	var down: bool = await t._until(func(): return main.area == null and not r.leaving, 12.0)
	await t._wait(0.5)
	_x("knocked out: the run ends, back at camp", down and Save.burrow_run.is_empty())
	_x("full health at the return spot", main.player.hp == Data.cat_max_hp() and main.player.global_position.distance_to(Vector3(0, 0, 15.5)) < 0.6, {"hp": main.player.hp})
	_x("half the satchel banked (2 of 5 amber, rounded down)", int(Save.mats["amber"]) - int(mats0["amber"]) == 2, {"mats": Save.mats})
	_x("leaves never taken", Save.leaves >= leaves0)
	_x("a fall is counted", int(Save.burrow_stats("old_hollow")["falls"]) == 1)
	_x("the map is hidden and nothing of the run is left", not _map().visible and get_tree().get_nodes_in_group("foes").is_empty() and main.cam.environment == null)
	await t._shot("dungeonfall_back")


# ---------------------------------------------------------------- saved at a checkpoint, and back in
## Phase 1 (with --fresh): win the fights up to the Moonwell, reach it (a checkpoint), win the bridge after it, get
## hurt, quit. Phase 2 (same save): the cat starts in the camp; Go back in: at the Moonwell with its health, boons and
## satchel; the fights before it stay won, the bridge is full again; then Leave it on another saved run banks half.
func _dungeonresume(phase: int) -> void:
	var r = _r()
	if phase == 1:
		await _endgame_camp()
		_strong_cat()
		await main.burrows.enter("old_hollow", 1)
		await t._wait(0.6)
		var hops := 0
		for f in r.fights:
			if float(f["s"]) < 101.0:
				# straight to each fight: wake it, strike it down
				main.player.global_position = _map().constrain(f["c"], 0.3, false)
				await t._wait(0.4)
				for sp in f["spawners"]:
					r._fire_spawner(f, sp)
				r._wake_fight(f)
				await t._wait(0.3)
				_kill_all()
				await t._wait(0.6)
				hops += 1
		await t._wait(0.5)
		var won: Array = r.run["cleared"].duplicate()
		main.player.global_position = _sp(96.0)
		await _walk_to(98.0, false)
		await t._wait(0.6)
		_x("phase 1: the fights before the Moonwell won (%d), the Moonwell reached (a checkpoint)" % hops, won.size() == hops and hops >= 4
			and String(Save.burrow_run["checkpoint"]) == "moonwell", {"won": won, "cp": Save.burrow_run["checkpoint"]})
		# the bridge, after the checkpoint
		var br := _fight("bridge")
		main.player.global_position = _map().constrain(br["c"], 0.3, false)
		await t._wait(0.5)
		for sp in br["spawners"]:
			r._fire_spawner(br, sp)
		r._wake_fight(br)
		await t._wait(0.3)
		_kill_all()
		await t._wait(0.8)
		_x("phase 1: the bridge won after the checkpoint", String(br["state"]) == "done")
		main.player.invincible = false
		main.player.hp = Data.cat_max_hp() - 2
		r.run["satchel"] = {"amber": 3}
		main.burrows.persist()
		var f := FileAccess.open("user://resume_d.json", FileAccess.WRITE)
		f.store_string(JSON.stringify({"hp": main.player.hp, "boons": r.run["boons"], "won": won}))
		f.close()
		_x("phase 1: the run saved with its health", int(Save.burrow_run["hp"]) == main.player.hp and (Save.burrow_run["cleared"] as Array).has("bridge"))
		await t._shot("dresume_1_bridge")
		return
	var want = JSON.parse_string(FileAccess.get_file_as_string("user://resume_d.json"))
	await t._wait(1.0)
	_x("phase 2: the cat starts in the camp", main.area == null and main.player.global_position.x < 100.0)
	main.player.invincible = true
	await t._at_ring(main.burrows.ring())
	await t._wait(1.3)
	await t._shot("dresume_2_card")
	_x("the card: Go back in at the Moonwell", _card_has("Go back in"))
	t._press("Go back in")
	await t._until(func(): return r.active and not r.leaving, 6.0)
	await t._wait(0.6)
	var m = _map()
	var mw: Vector3 = r._checkpoint("moonwell")["at"]
	_x("back in at the Moonwell", main.player.global_position.distance_to(mw) < 1.5, {"at": main.player.global_position, "cp": mw})
	_x("the saved health and boons", main.player.hp == int(want["hp"]) and r.run["boons"] == want["boons"], {"hp": main.player.hp, "want": want})
	_x("the satchel kept", int(r.satchel().get("amber", 0)) == 3)
	var cl: Array = r.run["cleared"]
	_x("the fights before the checkpoint stay won, the bridge is full again", cl.size() == (want["won"] as Array).size() and not cl.has("bridge")
		and String(_fight("bridge")["state"]) != "done" and String(_fight("camp")["state"]) == "done", {"cleared": cl})
	main.player.global_position = _sp(110.0)
	await t._wait(0.8)
	_x("the bridge's pack is back, asleep", (_fight("bridge")["foes"] as Array).size() >= 3 and String(_fight("bridge")["state"]) == "asleep")
	await t._shot("dresume_3_back_in")
	await r._leave("out")
	await t._wait(0.5)
	_x("climbed out: the satchel banked", int(Save.mats["amber"]) >= 3)
	# "Leave it" on a saved run: half the satchel
	Save.burrow_run = {"v": 2, "map": "old_hollow", "map_v": int(Data.dungeon("old_hollow")["version"]), "burrow": "old_hollow", "level": 1, "seed": 7,
		"checkpoint": "moonwell", "cleared": [], "chests": [], "hp": 5, "boons": [], "satchel": {"amber": 5}, "first_run": false}
	var m0: Dictionary = Save.mats.duplicate()
	main.player.global_position = Vector3(0, 0, 14.0)
	await t._wait(0.5)
	await t._at_ring(main.burrows.ring())
	await t._wait(1.3)
	t._press("Leave")
	await t._wait(0.5)
	_x("Leave it: half the satchel banked, the run gone", Save.burrow_run.is_empty() and int(Save.mats["amber"]) - int(m0["amber"]) == 2,
		{"mats": Save.mats, "before": m0})


# ---------------------------------------------------------------- the arena
## The arena only: the roots close behind the cat and Mossback wakes with its bar; the cat cannot leave; its adds stay
## in the arena, at most 4; a Gloom Dash into a standing stone dazes it (x1.5 for about 2.5 s); then the fight for
## real, timed; the roots open, the chest, the seal, the lift.
func _boss() -> void:
	await _endgame_camp()
	_strong_cat()
	var r = _r()
	await _enter(1)
	var m = _map()
	r.run["checkpoint"] = "gate"
	main.player.global_position = _sp(m.length - 13.0)
	await t._wait(1.0)
	_x("Mossback asleep at the north side, no boss bar yet", r._boss != null and not r._boss.awake and main.hud.boss == null and not m.sealed)
	await t._shot("boss_01_gate")
	await _walk_to(m.length - 8.5, false)
	var on: bool = await t._until(func(): return m.sealed and r._boss.awake, 3.0)
	_x("in: the roots close, the boss wakes with its bar", on and main.hud.boss == r._boss and r.fight_pips()[-1][0] == 1)
	var bo = r._boss
	bo.max_hp = 1e6
	bo.hp = 1e6
	await t._wait(1.0)
	await t._shot("boss_02_awake")
	# the way out is shut
	await t._go_straight(_sp(m.length - 16.0), 0.3, 4.0)
	_x("the roots hold the cat in the arena", m.in_arena(main.player.global_position, 0.0), {"s": _cat_s()})
	# adds: through the arena, at most 4 (the cat and Sprig hold their fire meanwhile)
	main.player.frozen = true
	if main.pet != null:
		main.pet.process_mode = Node.PROCESS_MODE_DISABLED
	for k in 4:
		bo._start_action("roar", null)
		await t._wait(1.6)
	var mins: Array = r.foes().filter(func(e): return e.summoned)
	main.player.frozen = false
	if main.pet != null:
		main.pet.process_mode = Node.PROCESS_MODE_INHERIT
	var cap := int(Data.burrow_cfg()["boss_minions_max"])
	_x("its adds are in the arena, at most %d" % cap, mins.size() <= cap and mins.size() >= 3 and mins.all(func(e): return m.in_arena(e.global_position, -0.5)), {"adds": mins.size()})
	await t._shot("boss_03_adds")
	for e in mins:
		e.hit(Vector3.FORWARD, e.hp + 1.0)
	await t._wait(0.4)
	# the Gloom Dash into a standing stone
	var st: Array = Data.dungeon("old_hollow")["stones"][1]
	var stone: Vector3 = m.w2(m.arena_c + Vector2(float(st[0]), float(st[1])))
	bo.global_position = stone + Vector3(-3.0, 0, 0)
	main.player.global_position = stone + Vector3(2.4, 0, 0)
	bo.state = "walk"
	await t._wait(0.1)
	bo._start_dash()
	var dazed: bool = await t._until(func(): return bo.state == "daze" and bo._vuln_t > 0.0, 3.0)
	_x("a Gloom Dash into a standing stone: dazed, a weak spot", dazed, {"state": bo.state})
	await t._shot("boss_04_bonk")
	var hp0: float = bo.hp
	bo.hit(Vector3.FORWARD, 100.0)
	_x("the next hit does x1.5", absf((hp0 - bo.hp) - 150.0) < 1.0, {"lost": hp0 - bo.hp})
	var t0 := 0.0
	while bo.state == "daze" and t0 < 4.0:
		await t._wait(0.1)
		t0 += 0.1
	_x("the daze lasts about 2.5 s", t0 > 1.8 and t0 < 3.2, {"secs": t0})
	# the fight for real at its level's health
	var full: float = 1500.0 * Data.depth_strength(1) * float(Data.dungeon("old_hollow")["end"]["hp_mult"])
	bo.max_hp = full
	bo.hp = full
	main.player.global_position = m.w2(m.arena_c) + Vector3(0, 0, 3.0)
	var bt := 0.0
	var enraged := false
	while not r._boss_down and bt < 200.0:
		await t._wait(0.5)
		bt += 0.5
		if is_instance_valid(bo) and bo.enraged:
			enraged = true
	if not r._boss_down:
		bo.hit(Vector3.FORWARD, bo.hp + 1.0)
		await t._wait(0.8)
	t._log("boss_time", {"secs": bt, "hp": full, "arrow": Data.arrow_damage()})
	_x("Mossback (%d health at level 1) falls in 40-160 s: %.1f s" % [int(full), bt], bt >= 40.0 and bt <= 160.0, {"secs": bt})
	_x("below 35%% health it was enraged (faster, a second slam ring)", enraged)
	await t._wait(1.0)
	_x("down: the roots open, its chest, the seal (first clear), the lift waits", not m.sealed and r.chests.has("end") and r._seal_due
		and not m.parts["end_lift_ring"].visible and r.fight_pips()[-1][0] == 2)
	await t._shot("boss_05_down")
	await t._use(m.parts["seal_ring"], 0.2, 10.0)
	var freed: bool = await t._until(func(): return not r._seal_due, 6.0)
	_x("the seal broken: the Warden is free, the lift shows", freed and Data.guardian_awake() and m.parts["end_lift_ring"].visible)
	await t._use(m.parts["end_lift_ring"], 0.2, 10.0)
	await t._wait(0.8)
	t._press("Climb")
	await t._until(func(): return main.area == null and not r.leaving, 6.0)
	_x("home by the lift", main.area == null and Save.burrow_run.is_empty())


# ---------------------------------------------------------------- draw calls and fps
## The camp, then the Gloomwood at the way in, in a pack fight (the Glowcap clearing awake, at the cap), and in the
## arena with the boss and its adds, at the level given with --quality= (dungeonperf.json beside the shots).
func _dungeonperf() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _endgame_camp()
	var out := {"quality": Quality.level}
	main.player.global_position = Vector3(0.0, 0, 2.6)
	await t._wait(2.0)
	out["camp"] = await t._measure("camp", 6.0)
	var r = _r()
	var t_in := Time.get_ticks_msec()
	await _enter(1)
	out["enter_ms"] = Time.get_ticks_msec() - t_in
	out["build_ms"] = _map().build_ms
	main.player.global_position = _sp(1.0)
	await t._wait(2.0)
	out["wayin"] = await t._measure("wayin", 6.0, func(_t: float): main.player.global_position = _sp(1.6 + sin(_t) * 1.2))
	await t._shot("dperf_wayin")
	var gl := _fight("glade")
	main.player.global_position = _sp(51.0)
	await t._wait(0.6)
	r._wake_fight(gl)
	var cap: int = int(Data.burrow_cfg()["max_alive_by_quality"][clampi(Quality.level, 0, 2)])
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	while r.foes().filter(func(f): return f.awake).size() < cap:
		var e = r.spawn(r._pool_kind(rng, r.tier()["pool"]), _sp(57.0, rng.randf_range(-3.0, 3.0)), {})
		if e == null:
			break
	for e in r.foes():
		e.max_hp = 1e6
		e.hp = 1e6
	await t._wait(2.0)
	out["fight"] = await t._measure("fight", 10.0, func(_t: float): main.player.global_position = _sp(52.0, sin(_t) * 1.2))
	await t._shot("dperf_fight")
	for e in r.foes():
		if not e.has_meta("boss_of_room"):
			e.queue_free()
	main.player.global_position = _sp(_map().length - 13.0)
	await t._wait(1.0)
	await _walk_to(_map().length - 8.0, false)
	await t._wait(0.6)
	if r._boss != null:
		r._boss.max_hp = 1e6
		r._boss.hp = 1e6
		for k in 2:
			r._boss._start_action("roar", null)
			await t._wait(1.5)
	await t._wait(1.0)
	out["arena"] = await t._measure("arena", 10.0)
	await t._shot("dperf_arena")
	var pf := FileAccess.open(t.shots.path_join("dungeonperf.json"), FileAccess.WRITE)
	if pf:
		pf.store_string(JSON.stringify(out, "  "))
	t._log("dungeonperf", out)
	var worst := maxf(float(out["wayin"]["draws"]), maxf(float(out["fight"]["draws"]), float(out["arena"]["draws"])))
	_x("the Gloomwood's busiest spot draws no more than 1.25x the camp's draw calls", worst <= float(out["camp"]["draws"]) * 1.25,
		{"camp": out["camp"]["draws"], "worst": worst})


# ---------------------------------------------------------------- a dungeon that ends in a treasure
func _dungeontreasure() -> void:
	await _endgame_camp()
	_strong_cat()
	var r = _r()
	main.burrows.map_override = "test_glade"
	await _enter(1)
	main.burrows.map_override = ""
	var m = _map()
	_x("the test map: no arena, a treasure at the end", r.end_type() == "treasure" and m.arena_r == 0.0 and r.chests.has("end"))
	_x("the banner and pips: 1 fight and a treasure", r._plan_text() == "1 fight and a treasure" and r.fight_pips().size() == 2, {"plan": r._plan_text()})
	await t._shot("treasure_01_in")
	var times := await _walk_to(m.length - 3.0)
	_x("its one fight is won on the way", String(_fight("camp")["state"]) == "done", {"times": times})
	await t._go_straight(r.chests["end"]["at"] + Vector3(0, 0, 0.95), 0.25, 6.0)
	await t._wait(1.6)
	_x("the treasure opens, the level counts as beaten, the lift shows", String(r.chests["end"]["state"]) == "done" and Data.burrow_depth("old_hollow") == 1
		and m.parts["end_lift_ring"].visible and r.fight_pips()[-1][0] == 2 and not r._seal_due)
	await t._shot("treasure_02_chest")
	await t._use(m.parts["end_lift_ring"], 0.2, 8.0)
	await t._wait(0.8)
	t._press("Climb")
	await t._until(func(): return main.area == null and not r.leaving, 6.0)
	_x("home, the run won, the Warden still sealed (it waits behind a boss)", main.area == null and int(Save.burrow_stats("old_hollow")["won"]) == 1 and not Data.guardian_awake())


# ---------------------------------------------------------------- what each level brings
func _dungeonlevels() -> void:
	await _endgame_camp()
	var r = _r()
	var sizes := {}
	var info := {}
	for lv in [1, 2, 3, 4, 5]:
		await _enter(lv)
		var n := 0
		var snap := 0
		var eli := 0
		var kinds := {}
		for f in r.fights:
			for p in r.pack_plan(f):
				n += 1
				kinds[String(p[0])] = true
				if String(p[0]) == "snapper":
					snap += 1
				if bool((p[2] as Dictionary).get("gloomtouched", false)):
					eli += 1
			for sp in f["spawners"]:
				n += r.spawner_count(sp["def"])
		sizes[lv] = n
		var pool: Array = (r.tier()["pool"] as Array).map(func(e): return String(e[0]))
		var in_pool := true
		for k in kinds:
			if not (k in pool or k == "snapper" or k in (r.tier()["elites"] as Array)):
				in_pool = false
		r._spawn_boss()
		await t._wait(0.2)
		var bo = r._boss
		info[lv] = {"monsters": n, "snappers": snap, "elites": eli, "kinds": kinds.keys(), "boss_hp": int(bo.max_hp) if bo != null else 0,
			"boss_gloom": bo.gloomtouched if bo != null else false, "tier": r.tier()["name"]}
		_x("level %d: the packs come from its pool (%s)" % [lv, r.tier()["id"]], in_pool, info[lv])
		if lv == 1:
			_x("level 1 (the first run's packs): no Root Snappers, three elites (the clearing's, the bridge's, the oak's)", snap == 0 and eli == 3, info[lv])
		else:
			_x("level %d: Root Snappers or extra Gloomtouched elites join the packs" % lv, snap + eli > 1, info[lv])
		_x("level %d: the boss is Mossback, Gloomtouched from level 4" % lv, bo != null and String(bo.id) == "bear" and bo.gloomtouched == (lv >= 4), info[lv])
		await r._leave("back")
		await t._wait(0.3)
	_x("packs grow with the level", sizes[5] > sizes[3] and sizes[3] > sizes[1], {"sizes": sizes})
	t._log("levels", info)


# ---------------------------------------------------------------- Phase E modes, on the dungeon map
## Phase D: a pending raid blocks the Hollow; the meter never moves during a run; a finished run adds 15 points (never
## past 95); a raid held pays its leaves (H1: no Hollow key any more). Phase C: a dish in the pot goes
## down with the cat (its boost applies), is used up when the run ends, and is back in the pot after a quit mid-run.
func _burrowhooks() -> void:
	await _endgame_camp()
	main.raids.test_awake = true
	main.set_riding(false, false)
	var b = main.burrows
	var r = b.runner
	main.raids.manual = true                               # the test steps the meter itself: the raid stays at the gate
	Save.raids["pending"] = true
	await b.enter("old_hollow", 1)
	await t._wait(0.3)
	_x("a pending raid blocks the Hollow", main.area == null and b.blocker().contains("Raid"), {"why": b.blocker()})
	Save.raids["pending"] = false
	main.raids.manual = false
	Save.raids["meter"] = 40.0
	Save.pantry["berries"] = 6
	Save.meal_ready = String(Data.b["cooking"]["recipes"][0]["id"])
	var dish := Save.meal_ready
	await b.enter("old_hollow", 1)
	await t._wait(0.5)
	_x("the dish went down with the cat and is eaten", Save.meal_on == dish and Save.meal_ready == "" and String(r.run["meal"]) == dish, {"on": Save.meal_on})
	var m0 := float(Save.raids["meter"])
	await t._wait(3.0)
	_x("the meter does not fill during a run", absf(float(Save.raids["meter"]) - m0) < 0.01, {"meter": Save.raids["meter"]})
	b.persist()
	Save.load_game()
	_x("after a quit mid-run the dish is back in the pot", Save.meal_ready == dish and Save.meal_on == "")
	Data.set_meal("")
	Save.meal_on = dish
	Save.meal_ready = ""
	Data.set_meal(dish)
	await r._leave("back")
	await t._wait(0.4)
	_x("the run's end uses the dish up", Save.meal_on == "" and Save.meal_ready == "")
	_x("a finished run adds 15 to the meter", absf(float(Save.raids["meter"]) - (m0 + 15.0)) < 0.5, {"meter": Save.raids["meter"], "was": m0})
	Save.raids["meter"] = 90.0
	main.raids.add_gloom("burrow_run")
	_x("never past 95", float(Save.raids["meter"]) <= 95.0 + 0.01, {"meter": Save.raids["meter"]})
	Save.raids["plan"] = {"type": "siege", "lanes": [0], "level": 3, "leader": "", "first": false, "seed": 9, "called": false}
	Save.raids["run"] = {"wave_done": 3, "ready": false}
	var l0 := Save.leaves
	main.raids.finish(true, false, 3)
	await t._wait(0.3)
	var pay: Dictionary = Data.gr()["pay"]
	var raid_leaves := int(pay["leaves"]) + int(pay["leaves_per_level"]) * 3
	Save.save_game(true)                                   # H1: no key: the raid pay names none, the saved file has no key field
	var sf: Variant = JSON.parse_string(FileAccess.get_file_as_string(Save.path))
	var no_key: bool = sf is Dictionary and not (sf as Dictionary).has("burrow_keys") and not "burrow_keys" in Save and not pay.has("keys")
	_x("H1: a raid held pays its leaves, and no Hollow key", Save.leaves - l0 == raid_leaves and no_key, {"got": Save.leaves - l0, "raid": raid_leaves, "pay": pay})
	Save.pantry = {"berries": 4, "herbs": 0, "honey": 0, "fish": 1, "goldfish": 0}
	await b.enter("old_hollow", 1)
	await t._wait(0.5)
	var mt = main.mount
	mt.hurt(99999, mt.global_position)
	await t._wait(2.0)
	var feed_btn := false
	for bt in main.hud.build_buttons():
		if String(bt.get_meta("label", "")).begins_with("Feed"):
			feed_btn = true
	_x("in a Burrow a knocked-out mount stays out, and the Feed button shows", mt.resting > 0.0 and feed_btn, {"resting": mt.resting})
	main.feed_mount()
	await t._wait(0.3)
	_x("fed (2 Sunberries): it is up and whole", mt.resting <= 0.0 and mt.hp == mt.max_hp() and int(Save.pantry["berries"]) == 2)
	main.player.hp = 2
	main.eat_snack()
	_x("a snack (the fish first) heals the cat", main.player.hp == mini(6, Data.cat_max_hp()) and int(Save.pantry["fish"]) == 0, {"hp": main.player.hp})
	await r._leave("back")


# ---------------------------------------------------------------- rewards and the top upgrades
func _row_texts(card: Dictionary) -> String:
	# a plain row has "text"; an item tile (Phase G2) has "title", "text" and maybe a "badge": all of them are read
	return " | ".join((card.get("rows", []) as Array).map(func(rw):
		var bits: Array = []
		for k in ["title", "badge", "text"]:
			if String(rw.get(k, "")) != "":
				bits.append(String(rw[k]))
		return " · ".join(bits)))


func _topup() -> void:
	main.player.invincible = true
	t._veteran(15)
	Save.raids["meter"] = 0.0
	Save.camp_level = 5
	main.on_camp_grown()
	for s in ["damage", "draw", "health", "speed"]:
		Save.stats[s] = 10
	Save.bows["sunwood"] = 10
	Save.bow = "sunwood"
	# Phase F: the Training Target and the Bow Shop have 5 levels each, capping stats and bows at 4/6/8/9/10
	# (stat_cap_by_station_level, bow_cap_by_bench_level); only at level 5 (10) do the Burrows add mastery (11-12). This
	# test was written when level 3 allowed 10, so both are at their top level here.
	Save.stations["bench"] = (Data.b["stations"]["bench"]["levels"] as Array).size()
	Save.stations["target"] = (Data.b["stations"]["target"]["levels"] as Array).size()
	Save.def_levels = {"barricade": 4, "tower": 4, "spikes": 4}
	main.stations.free_guardian()
	Save.stations["stone"] = 3
	Save.leaves = 60000
	Save.timber = 500
	await t._wait(0.5)
	var st = main.stations
	_x("before the Burrows: stats capped at 10", Data.stat_cap("damage") == 10 and Data.stat_cap("health") == 10)
	_x("before the Burrows: no level-5 row, no Foxfire Bow", not _row_texts(st._card_shop()).contains("Amber") and not _row_texts(st._card_bench()).contains("Foxfire"),
		{"shop": _row_texts(st._card_shop())})
	_x("before the Burrows: the stone's level 4 shows max", _row_texts(st._card_stone()).contains("max level"), {"stone": _row_texts(st._card_stone())})
	st._upgrade_defence("tower")
	_x("level 5 refused before the Burrows open", main.defences.level("tower") == 4)
	main.burrows.open_hollow(false)
	Save.mats = {"amber": 400}
	Save.leaves += 400 * 60 + 250 * 120 + 40 * 400       # H1: the glowstone and heartwood (and amber) this test gave, as leaves
	await t._wait(0.3)
	var m0: Dictionary = Save.mats.duplicate()
	var lm0 := Save.leaves
	_x("the Burrows open: stats capped at 12", Data.stat_cap("damage") == 12 and Data.stat_cap("health") == 12 and Data.stat_cap("range") <= 10)
	st._buy_stat("damage")
	st._buy_stat("damage")
	st._buy_stat("damage")
	st._buy_stat("health")
	st._buy_stat("health")
	_x("damage and health to 12, no further", int(Save.stats["damage"]) == 12 and int(Save.stats["health"]) == 12, {"stats": Save.stats})
	var mastery := 0
	for sid in ["damage", "health"]:
		for c in Data.b["stats"][sid]["mastery"]:
			mastery += int(c["leaves"])
	_x("H1: mastery paid in leaves only, no amber taken", int(Save.mats["amber"]) == int(m0["amber"]) and lm0 - Save.leaves == mastery,
		{"mats": Save.mats, "paid": lm0 - Save.leaves, "want": mastery})
	_x("the Training Target card shows mastery done", _row_texts(st._card_target()).contains("Damage · Max"), {"rows": _row_texts(st._card_target())})
	st._upgrade_bow()
	st._upgrade_bow()
	_x("the bow to 12", int(Save.bows["sunwood"]) == 12, {"bows": Save.bows})
	st._craft("foxfire")
	_x("the Foxfire Bow is hidden from the Bow Shop for now (22 Nov 2026): not on the card, not sold", not Save.bows.has("foxfire") and Save.bow == "sunwood"
		and not _row_texts(st._card_bench()).contains("Foxfire"))
	Save.camp_level = 4
	st._upgrade_defence("tower")
	_x("tower level 5 refused at home level 4", main.defences.level("tower") == 4)
	Save.camp_level = 5
	var shop := _row_texts(st._card_shop())
	_x("the shop offers the Amber Tower", shop.contains("Towers: Amber"), {"shop": shop})
	st._upgrade_defence("tower")
	st._upgrade_defence("barricade")
	_x("tower and barricade at level 5 with their models", main.defences.level("tower") == 5 and main.defences.model("tower", 5) == "acorn_tower_5"
		and main.defences.model("barricade", 5) == "barricade_heartwood")
	var l0 := Save.leaves
	st._upgrade_station("stone")
	_x("the Warden to level 4 (paid in leaves and timber)", int(Save.stations["stone"]) == 4 and l0 - Save.leaves == 2500 and absf(Data.guardian_max_hp() - 1800.0 * Data.guardian_power()) < 1.0,
		{"stone": Save.stations["stone"], "hp": Data.guardian_max_hp()})
	Save.camp_level = 6
	main.on_camp_grown()
	await t._wait(0.3)
	st._grow_camp()
	_x("home level 7 waits for level 2 of the Gloomwood", Save.camp_level == 6)
	Save.burrow_stats("old_hollow")["depth"] = 3
	var a0 := int(Save.mats["amber"])
	var p7 := Data.home_price(7)
	var l7 := Save.leaves
	st._grow_camp()
	await t._wait(0.5)
	_x("H1: home level 7 paid in leaves and timber, no amber", Save.camp_level == 7 and int(Save.mats["amber"]) == a0 and not p7.has("amber")
		and l7 - Save.leaves == int(p7.get("leaves", 0)), {"level": Save.camp_level, "price": p7})
	st._grow_camp()
	await t._wait(0.5)
	_x("home level 8: its tables extended (fire, light, towers, home)", Save.camp_level == 8 and Data.fire_hp() == 3000 and main.defences.tower_cap() == 9
		and absf(Data.light_radius() - 7.7) < 0.01 and Data.building_hp("home", 8) == 4000.0 and main.stations.foot("home") > 1.0,
		{"fire": Data.fire_hp(), "towers": main.defences.tower_cap()})
	_x("the level-8 home and fire fall back to level 6's models", main.stations.model_name("home") == "home_tree_6" and main.stations.model_name("campfire") == "campfire_brazier")
	main.player.global_position = Vector3(0.0, 0, 2.6)
	await t._wait(1.2)
	await t._shot("topup_home8")
	var stall := _row_texts(st._card_stall())
	_x("the Stable sells attachments (G4: the Thunder Shoes; the saddle and bags moved to the Saddlery)", stall.contains("Thunder Shoes") and not stall.contains("Saddle"), {"rows": stall})
	st._buy_attach("mount_shoes")
	st._buy_attach("pet_bell")
	_x("bought and worn", Save.attach["mount"] == "mount_shoes" and Save.attach["pet"] == "pet_bell")
	# G4: the Mossweave Saddle is a Saddlery attachment (+15% a level) and works everywhere, camp and runs alike.
	# 22 Nov 2026 (the owner's rule): the mount wears one attachment at a time and only the worn one acts, so it is worn here.
	var mmax: int = main.mount.max_hp()
	var cmax: int = Data.cat_max_hp()
	var worn0: Variant = Save.saddlery.get("worn", "")
	Save.saddlery["attach"]["saddle"] = 2
	Save.saddlery["worn"] = "saddle"
	var hm := 1.0 + float(Data.saddle_info("attach", "saddle")["hp_per_level"]) * 2.0
	var msaddle: int = main.mount.max_hp()
	_x("the Saddlery's saddle (level 2, worn) gives the mount +30% health at camp", msaddle == roundi(mmax * hm) and msaddle > mmax
		and is_equal_approx(Data.mount_hp_mult(), hm), {"mount": msaddle, "was": mmax, "mult": Data.mount_hp_mult(), "want": hm})
	var r = _r()
	await _enter(1)
	_x("in a run: the saddle's mount health still there, and the bell's cat health", main.mount.max_hp() == msaddle and Data.cat_max_hp() == cmax + 2,
		{"mount": main.mount.max_hp(), "was": msaddle, "cat": Data.cat_max_hp()})
	await r._leave("back")
	await t._wait(0.4)
	_x("back at camp: no Burrows help (the saddle stays: it is the Saddlery's)", main.mount.max_hp() == msaddle and Data.cat_max_hp() == cmax)
	Save.saddlery["attach"].erase("saddle")
	Save.saddlery["worn"] = worn0
	await t._shot("topup_stall_card")


## A frozen test monster that cannot die (it only takes the hits).
func _dummy_foe(at: Vector3):
	var e = _r().spawn("thornling", at, {})
	e.max_hp = 1e6
	e.hp = 1e6
	e.set_physics_process(false)
	return e


## A run with nothing awake near `s` (the test builds what it needs there).
func _quiet_run(lvl: int, s: float) -> void:
	await _endgame_camp()
	await _enter(lvl)
	main.player.global_position = _sp(s)
	await t._wait(0.5)
	for e in _r().foes():
		e.dead = true
		e.remove_from_group("foes")
		e.queue_free()
	for f in _r().fights:
		f["state"] = "done"
	await t._wait(0.2)


## Every trap type on the map: its warning comes at least 0.8 s before it strikes, it hurts the cat once per firing and
## hurts a monster too; spores slow and never hurt; the tide's pace; the logs' chest stays shut for a hurt cat.
func _traps() -> void:
	await _quiet_run(3, 60.0)
	var r = _r()
	var p = main.player
	p.invincible = false
	var out := {}
	var TrapScript := load("res://scripts/trap.gd")
	var mk := func(spec: Dictionary, s: float):
		var sm: Array = _map().sample(s)
		var dir: Vector2 = sm[1]
		spec["at"] = _sp(s)
		spec["yaw"] = atan2(-dir.x, -dir.y)
		var tr = TrapScript.new()
		r.add_child(tr)
		tr.setup(main, spec, 3, r.strength())
		return tr
	# a rolling log across the path: the cat and a test monster in its lane
	var lg = mk.call({"type": "log", "every": 2.8, "half": 3.0}, 58.0)
	var dm = _dummy_foe(_sp(58.0, 1.6))
	for k in 40:
		p.hp = 99
		p.global_position = _sp(58.0)
		await t._wait(0.2)
		if k == 6:
			await t._shot("traps_01_log")
	out["log"] = _trap_report(lg.events)
	_x("log: the warning at least 0.8 s before it rolls", float(out["log"]["min_warn"]) >= 0.75, out["log"])
	_x("log: it hurts the cat once a roll, and the monster", int(out["log"]["cat"]) >= 1 and int(out["log"]["cat"]) <= int(out["log"]["fire"]) and int(out["log"]["foe"]) >= 1, out["log"])
	lg.queue_free()
	dm.queue_free()
	var th = mk.call({"type": "thorns", "half": 2.5}, 58.0)
	var pl0: Vector3 = th._plates[2][1].global_position
	var dm2 = _dummy_foe(pl0)
	var pl1: Vector3 = th._plates[1][1].global_position
	for k in 30:
		p.hp = 99
		p.global_position = pl1
		await t._wait(0.2)
		if k == 9:
			await t._shot("traps_02_thorns")
	out["thorns"] = _trap_report(th.events)
	_x("thorns: warned 0.8 s ahead, hurts the cat and a monster", float(out["thorns"]["min_warn"]) >= 0.75 and int(out["thorns"]["cat"]) >= 1 and int(out["thorns"]["foe"]) >= 1, out["thorns"])
	th.queue_free()
	dm2.queue_free()
	var cr = mk.call({"type": "crystal", "half": 2.5}, 58.0)
	for k in 40:
		p.hp = 99
		p.global_position = _sp(54.0)
		await t._wait(0.2)
		if k == 8:
			await t._shot("traps_03_crystal")
	out["crystal"] = _trap_report(cr.events)
	_x("crystal: warned at least 0.8 s ahead, falls near the cat", float(out["crystal"]["min_warn"]) >= 0.85 and int(out["crystal"]["fire"]) >= 4, out["crystal"])
	cr.queue_free()
	var sv = mk.call({"type": "spores", "phase": 0.2}, 56.0)
	var hp0 := 99
	p.hp = hp0
	var slowed := false
	for k in 25:
		p.global_position = _sp(56.0)
		await t._wait(0.2)
		if p.slow_t > 0.0:
			slowed = true
	_x("spores: the cat is slowed and not hurt", slowed and p.hp == hp0, {"hp": p.hp, "events": sv.events.size()})
	sv.queue_free()
	var td = mk.call({"type": "tide", "half": 2.5, "span": 12.0}, 60.0)
	p.global_position = _sp(67.0)
	await t._wait(6.0)
	var dep: float = td.tide_depth()
	_x("tide: about 1.65 m after 6 s (3 s wait, then 0.55 m/s)", absf(dep - 1.65) < 0.35, {"depth": dep})
	p.hp = 99
	p.global_position = _sp(60.5)
	await t._wait(2.2)
	_x("tide: it hurts the cat inside it", p.hp < 99, {"hp": p.hp})
	await t._shot("traps_04_tide")
	td.queue_free()
	# the logs' stretch: hit by a log, the chest at its end stays shut
	p.hp = 99
	var ch: Dictionary = r.chests["logs"]
	main.player.global_position = _sp(78.0)
	await t._wait(0.5)
	var hit := false
	for k in 60:
		p.global_position = _sp(83.5)
		await t._wait(0.15)
		if r._zone_hurt:
			hit = true
			break
	await t._go_straight(ch["at"] + Vector3(0, 0, 0.95), 0.25, 6.0)
	await t._wait(1.0)
	_x("the logs: hit in the stretch, the chest at the end stays shut", hit and String(ch["state"]) == "done" and (ch["node"] as Node3D).scale.x < 0.5,
		{"hit": hit, "state": ch["state"]})
	p.hp = Data.cat_max_hp()
	p.invincible = true
	t._log("traps", out)


func _trap_report(ev: Array) -> Dictionary:
	var min_warn := 99.0
	var last_warn := -1.0
	var n := {"fire": 0, "cat": 0, "foe": 0, "warn": 0}
	for e in ev:
		match String(e[0]):
			"warn":
				last_warn = float(e[1])
				n["warn"] += 1
			"fire":
				n["fire"] += 1
				if last_warn >= 0.0:
					min_warn = minf(min_warn, float(e[1]) - last_warn)
					last_warn = -1.0
			"cat": n["cat"] += 1
			"foe": n["foe"] += 1
	n["min_warn"] = snappedf(min_warn, 0.01)
	return n


## The Burrows' own monsters on their stand-ins, in the Glowcap clearing: the Grubling bursts out of the ground, the
## Glowcap lobs spore bombs at the cat, the Root Snapper bites along a line, the Amber Grub runs to a hole.
func _burrowfoes() -> void:
	await _quiet_run(2, 56.0)
	var r = _r()
	var m = _map()
	var c: Vector3 = m.wpt({"in": "glade"})
	var p = main.player
	p.invincible = false
	p.hp = 99
	p.global_position = c + Vector3(0, 0, 2.0)
	var g = r.spawn("grub", c + Vector3(1.5, 0, 1.0), {"emerge": true})
	_x("a Grubling bursts out of the ground (hidden first)", g != null and g.state == "emerge" and not g._body.visible)
	var gc = r.spawn("glowcap", c + Vector3(0, 0, -3.0), {})
	var sn = r.spawn("snapper", c + Vector3(-2.6, 0, 2.0), {})
	var ag = r.spawn("amber_grub", c + Vector3(2.0, 0, -1.0), {})
	for e in [g, gc, sn, ag]:
		if e != null:
			e.max_hp = 1e6
			e.hp = 1e6
	if main.pet != null:
		main.pet.process_mode = Node.PROCESS_MODE_DISABLED
	var s0: int = r.strikes
	var bit := false
	var tt := 0.0
	var ag0: Vector3 = ag.global_position
	while tt < 9.0:
		p.global_position = c + Vector3(-1.2, 0, 2.0)
		await t._wait(0.2)
		tt += 0.2
		if sn != null and sn.state == "bite":
			bit = true
		if absf(tt - 2.0) < 0.1:
			await t._shot("foes_01")
	_x("the Grubling is up and hunting", g != null and is_instance_valid(g) and g._body.visible and g.state != "emerge")
	_x("the Glowcap lobbed spore bombs at the cat", r.strikes > s0, {"strikes": r.strikes - s0})
	_x("the Root Snapper bit along its line", bit and sn.global_position.distance_to(c + Vector3(-2.6, 0, 2.0)) < 0.3)
	var hole: Vector3 = m.flee_point(p.global_position)
	_x("the Amber Grub runs for the far hole", ag != null and is_instance_valid(ag) and ag.global_position.distance_to(hole) < ag0.distance_to(hole),
		{"at": ag.global_position if ag != null else Vector3.ZERO, "hole": hole})
	_x("the cat was hurt by them (not invincible)", p.hp < 99, {"hp": p.hp})
	if main.pet != null:
		main.pet.process_mode = Node.PROCESS_MODE_INHERIT
	p.hp = Data.cat_max_hp()
	p.invincible = true
	# H1: the grub pays amber only 1 time in 2 (balance.json burrows.amber.grub). The data is checked as it is; for the
	# catch the roll is made certain: grub forced to 2.0 (floor 2, no chance part: exactly 2 every run, so a lost call,
	# a wrong source key or a hard-coded 1 all fail), put back the moment the catch has paid (the roll is made inside
	# the kill, before r._grub is cleared), before any check
	var av: float = r.amber_value("grub")
	_x("the Amber Grub's amber is a 1 in 2 chance (burrows.amber.grub 0.5)", is_equal_approx(av, 0.5), {"grub": av})
	var am: Dictionary = r.cfg()["amber"]
	var g0: Variant = am["grub"]
	am["grub"] = 2.0
	var a0 := int(r.satchel().get("amber", 0))
	var lv0: int = Save.leaves
	ag.hp = 1.0
	ag.hit(Vector3.FORWARD, 5.0)
	if r._grub != null:
		await t._until(func(): return r._grub == null, 5.0)
	am["grub"] = g0
	await t._until(func(): return r._grub == null and Save.leaves > lv0, 5.0)
	await t._until(func(): return int(r.satchel().get("amber", 0)) - a0 >= 2, 3.0)
	var got := int(r.satchel().get("amber", 0)) - a0
	_x("caught: the Amber Grub is gone and its leaves came home", r._grub == null and Save.leaves > lv0, {"leaves": Save.leaves - lv0})
	_x("caught: the Amber Grub pays its amber into the satchel (grub forced to 2.0: exactly 2)", got == 2 and is_equal_approx(r.amber_value("grub"), av),
		{"got": got, "satchel": r.satchel()})


# ---------------------------------------------------------------- the Leaf Dash
func _swipe(p0: Vector2, pts: Array, dt: float) -> bool:
	var j = main.joystick
	var got := [false]
	var cb := func(_d): got[0] = true
	j.flicked.connect(cb)
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = true
	ev.position = p0
	j._input(ev)
	for pp in pts:
		j._clock += dt
		var dr := InputEventScreenDrag.new()
		dr.index = 0
		dr.position = pp
		j._input(dr)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = pts[pts.size() - 1] if not pts.is_empty() else p0
	j._input(up)
	j.flicked.disconnect(cb)
	return got[0]


func _dash() -> void:
	await _endgame_camp()
	var p = main.player
	var c0: Vector3 = p.global_position
	main._on_flick(Vector2(1, 0))
	await t._wait(0.5)
	_x("no dash in the camp", p.global_position.distance_to(c0) < 0.2 and p.dashes == 0)
	var r = _r()
	await _enter(1)
	var m = _map()
	for e in r.foes():
		e.queue_free()
	await t._wait(0.2)
	var wc: Vector3 = m.wpt({"in": "wayin"})
	p.global_position = wc + Vector3(1.0, 0, -1.0)
	await t._wait(0.3)
	var a: Vector3 = p.global_position
	main.joystick.force_flick(Vector2(-1, 0))
	await t._wait(0.5)
	var moved: float = p.global_position.distance_to(a)
	_x("a flick dashes about 3 m", absf(moved - 3.0) <= 0.25, {"moved": moved})
	await t._shot("dash_01_moved")
	var b0: Vector3 = p.global_position
	main.joystick.force_flick(Vector2(-1, 0))
	await t._wait(0.4)
	_x("a second flick within the cooldown does nothing", p.global_position.distance_to(b0) < 0.05)
	await t._wait(1.4)
	p.global_position = wc + Vector3(-3.0, 0, -1.0)
	await t._wait(0.1)
	main.joystick.force_flick(Vector2(-1, 0))
	await t._wait(0.5)
	var edge: float = m.sd(m.m2(p.global_position))
	_x("a dash into the trees stops at the edge of the walkable ground", edge < -0.2 and edge > -0.6, {"sd": edge})
	await t._wait(1.5)
	p.invincible = false
	var hp0: int = p.hp
	main.joystick.force_flick(Vector2(1, 0))
	await t._wait(0.05)
	p.hurt(p.global_position + Vector3(1, 0, 0), 2)
	_x("a hit mid-dash is ignored: a close call", p.hp == hp0 and p.close_calls == 1 and main.empowered_t > 0.0, {"hp": p.hp, "was": hp0})
	p.invincible = true
	var e = r.spawn("thornling", p.global_position + Vector3(0, 0, -2.5), {})
	e.max_hp = 1e6
	e.hp = 1e6
	if main.pet != null:
		main.pet.process_mode = Node.PROCESS_MODE_DISABLED
	var hits: Array = []
	var last: float = e.hp
	var tt := 0.0
	while hits.size() < 2 and tt < 4.0:
		await t._wait(0.05)
		tt += 0.05
		if e.hp < last - 0.01:
			hits.append(last - e.hp)
			last = e.hp
	if main.pet != null:
		main.pet.process_mode = Node.PROCESS_MODE_INHERIT
	var ad := Data.arrow_damage()
	_x("the next arrow hits double, then normal again", hits.size() == 2 and absf(float(hits[0]) - ad * 2.0) < 1.0 and absf(float(hits[1]) - ad) < 1.0,
		{"hits": hits, "arrow": ad})
	var fast := await _swipe(Vector2(300, 600), [Vector2(330, 600), Vector2(380, 600), Vector2(420, 600)], 0.02)
	var slow := await _swipe(Vector2(300, 600), [Vector2(310, 600), Vector2(320, 600), Vector2(330, 600), Vector2(340, 600)], 0.05)
	var tap := await _swipe(Vector2(300, 600), [Vector2(302, 601)], 0.03)
	_x("a fast swipe and let go flicks; a slow lift and a tap do not", fast and not slow and not tap, {"fast": fast, "slow": slow, "tap": tap})
	await t._wait(1.6)
	await t._shot("dash_02_arc")


# ---------------------------------------------------------------- the Hollow in the camp
## Every woods instance (trees, undergrowth, meadow flowers) inside the Hollow's clearing: [kind, x, z].
func _woods_in_clear() -> Array:
	var bad: Array = []
	var w = main.world
	for sc in w._scatter:
		var mm: MultiMesh = (sc[1] as MultiMeshInstance3D).multimesh
		for i in mm.instance_count:
			var o: Vector3 = (sc[1] as MultiMeshInstance3D).global_transform * mm.get_instance_transform(i).origin
			if w.in_hollow_clear(o):
				bad.append([sc[0], snappedf(o.x, 0.1), snappedf(o.z, 0.1)])
	return bad


func _hollow() -> void:
	main.player.invincible = true
	t._veteran(1)
	await t._wait(0.6)
	var b = main.burrows
	var rg = b.ring()
	var e: Dictionary = b.entrances["old_hollow"]
	_x("sealed: the ring shows from the first raid won", rg.visible and not Data.burrows_open())
	_x("sealed: the seal is on, the glow off", e["seal"] != null and (e["seal"] as Node3D).visible and e["glow"] != null and not (e["glow"] as Node3D).visible)
	var spec: Dictionary = b.card("old_hollow")
	_x("the sealed card", String(spec["sub"]) == "Sealed by the Gloom" and (spec["rows"] as Array).size() == 1 and not bool(spec["rows"][0]["enabled"]), {"spec": spec})
	await t._at_ring(rg)
	await t._wait(1.5)
	var cam: Camera3D = main.cam
	var vp: Rect2 = main.get_viewport().get_visible_rect()
	var hs: Vector2 = cam.unproject_position(e["pos"] + Vector3(0, 0.5, 0))
	var cs: Vector2 = cam.unproject_position(main.player.global_position + Vector3(0, 0.6, 0))
	_x("the hollow and the cat on screen with the cat on the ring", vp.has_point(hs) and vp.has_point(cs), {"hollow": hs, "cat": cs, "vp": vp.size})
	await t._shot("hollow_01_sealed_ring")
	main.hud.hide_card()
	var w = main.world
	var bad_woods := _woods_in_clear()
	_x("no tree, undergrowth or meadow plant in the clearing", bad_woods.is_empty(), {"bad": bad_woods.slice(0, 12), "n": bad_woods.size()})
	var bad_hide: Array = []
	for h in w.hide_spots:
		if w.in_hollow_clear(h[0]) or w.near_hollow(h[0], 3.0 + float(h[1])):
			bad_hide.append([snappedf(h[0].x, 0.1), snappedf(h[0].z, 0.1), h[2]])
	_x("no hide spot in the clearing", bad_hide.is_empty(), {"bad": bad_hide})
	var bad_grass := 0
	for mmi in w.grass._chunks:
		var mm: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
		for i in mm.instance_count:
			var o: Vector3 = (mmi as MultiMeshInstance3D).global_transform * mm.get_instance_transform(i).origin
			if w.near_hollow(o, 2.3, 1.0):
				bad_grass += 1
	_x("no grass tuft on the hollow or its ring", bad_grass == 0, {"n": bad_grass})
	main.defences.placing = "tower"
	var ok_in := false
	for q in [Vector3(0, 0, 18.0), Vector3(1.5, 0, 22.0), Vector3(-2.2, 0, 11.0)]:
		ok_in = ok_in or main.defences._valid(q)
	main.defences.placing = ""
	_x("a tower cannot be placed in the clearing or on the path", not ok_in)
	var pts: PackedVector3Array = PackedVector3Array()
	for q in Data.burrow_list()[0]["entrance"]["path"]:
		pts.append(Vector3(float(q[0]), 0, float(q[2])))
	var line: PackedVector3Array = w._smooth(pts, 7)
	var min_ring := 99.0
	var min_bed := 99.0
	var in_res := false
	for pp in line:
		min_ring = minf(min_ring, Vector2(pp.x - 0.5, pp.z - 7.2).length())
		min_bed = minf(min_bed, Vector2(pp.x - 0.5, pp.z - 8.4).length())
		if w.in_reserved(pp, 0.0):
			in_res = true
	_x("the path keeps 1.5 m off the garden ring and clear of the bed and the reserved ground", min_ring >= 1.5 and min_bed >= 1.1 + 0.55 and not in_res,
		{"ring": snappedf(min_ring, 0.01), "bed": snappedf(min_bed, 0.01), "reserved": in_res})
	t._veteran(15)
	main.hud.banner("A banner on screen", Color(1, 1, 1), "the reveal waits for it")
	b.check_open()
	await t._wait(2.0)
	_x("not open while the reveal waits", not Data.burrows_open())
	main.player.global_position = Vector3(0, 0, 14.0)
	var opened: bool = await t._until(func(): return Data.burrows_open(), 16.0)
	await t._wait(0.4)
	await t._shot("hollow_02_reveal")
	_x("the reveal: the flag (H1: no Hollow keys to fill)", opened and Save.flag("hollow_open") and not "burrow_keys" in Save)
	await t._wait(1.5)
	_x("open: the seal gone, the glow on, the ring gold", not (e["seal"] as Node3D).visible and (e["glow"] as Node3D).visible and rg.visible)
	var l0 := Save.leaves
	b.check_open()
	await t._wait(0.2)
	_x("checked again: still open, nothing given", Data.burrows_open() and Save.leaves == l0)
	_x("H1: no key ring any more", not b.has_method("grant_key"))
	await t._at_ring(rg)
	await t._wait(1.2)
	spec = b.card("old_hollow")
	var texts: Array = (spec["rows"] as Array).map(func(rw): return String(rw["text"]))
	_x("the open card: the Gloomwood at level 1, no key row (H1)", texts.size() >= 2 and String(texts[0]).contains("Gloomwood · Level 1")
		and not " ".join(texts).to_lower().contains("key") and not String(spec["sub"]).to_lower().contains("key"), {"rows": texts, "sub": spec["sub"]})
	# a lower level once higher ones are open
	Save.burrow_stats("old_hollow")["depth"] = 2
	spec = b.card("old_hollow")
	_x("level 3 open: the card offers it, and a way to pick a lower one", String(spec["rows"][0]["text"]).contains("Level 3") and String(spec["rows"][1]["label"]) == "Lower")
	b._cycle_level(3)
	spec = b.card("old_hollow")
	_x("Lower picks level 2", String(spec["rows"][0]["text"]).contains("Level 2"), {"row": spec["rows"][0]["text"]})
	b.pick_level = 0
	Save.burrow_stats("old_hollow")["depth"] = 0
	main.hud.refresh_card()
	await t._wait(0.3)
	await t._shot("hollow_03_open_card")
	main.hud.hide_card()
	main.player.global_position = Vector3(-1.5, 0, 9.5)
	await t._wait(1.2)
	await t._shot("hollow_04_path")
	main.player.global_position = Vector3(0.0, 0, 16.0)
	await t._wait(1.2)
	await t._shot("hollow_05_notch")
	Save.raids["pending"] = true
	_x("blocked while a raid is pending", b.blocker() != "")
	Save.raids["pending"] = false
	_x("free to enter otherwise", b.blocker() == "")


# ---------------------------------------------------------------- plumbing
func _burrowsave() -> void:
	Save.mats = {"amber": 5}
	Save.leaves = 100
	_x("can afford leaves + amber", Data.can_afford({"leaves": 50, "amber": 5, "needs_burrows": true, "mats": {"x": 9}}))
	_x("H1: Data knows no glowstone, heartwood or keys", not Data.CURRENCIES.has("glowstone") and not Data.CURRENCIES.has("heartwood")
		and not Data.CURRENCIES.has("keys") and Data.MATS == ["amber"] and Data.have("heartwood") == 0 and Data.have("keys") == 0, {"currencies": Data.CURRENCIES})
	_x("pay leaves and amber", Data.pay({"leaves": 50, "amber": 3}) and Save.leaves == 50 and int(Save.mats["amber"]) == 2,
		{"leaves": Save.leaves, "mats": Save.mats})
	_x("a failed pay takes nothing", not Data.pay({"leaves": 10, "amber": 3}) and Save.leaves == 50 and int(Save.mats["amber"]) == 2)
	# the first Damage level costs its balance.json price (stats.damage.cost[0]), in leaves only (it was 15 when this was
	# written; the number is read from the data now)
	var c0 := int((Data.b["stats"]["damage"]["cost"] as Array)[0])
	_x("costs: stat, bow and craft", c0 > 0 and Data.stat_cost("damage", 0) == {"leaves": c0} and Data.craft_cost("sunwood").has("leaves") and Data.bow_cost("twig", 1).has("leaves"),
		{"stat": Data.stat_cost("damage", 0), "want": c0, "craft": Data.craft_cost("sunwood")})
	# the map as Data loads it holds every fight its file defines (9 today: 6 named and 3 ambushes; it was 6 when this
	# was written), each with an id and its monsters (a pack or spawners)
	var map_id := Data.burrow_map_id("old_hollow")
	var dm := Data.dungeon(map_id)
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dungeons/%s.json" % map_id))
	var n_file: int = ((raw as Dictionary).get("fights", []) as Array).size() if raw is Dictionary else -1
	var dfights: Array = dm.get("fights", [])
	var fights_ok: bool = n_file > 0 and dfights.size() == n_file
	for f in dfights:
		if not (f is Dictionary and String((f as Dictionary).get("id", "")) != "" and ((f as Dictionary).has("pack") or (f as Dictionary).has("spawners"))):
			fights_ok = false
	_x("the Gloomwood's map loads: its path, every fight its file defines, a boss", (dm.get("spine", []) as Array).size() > 10 and fights_ok
		and String(dm.get("end", {}).get("type", "")) == "boss" and String(dm.get("name", "")) == "The Gloomwood", {"fights": dfights.size(), "in_file": n_file})
	_x("one Burrow in the list, its id old_hollow, named the Gloomwood", Data.burrow_list().size() >= 1 and String(Data.burrow_list()[0]["id"]) == "old_hollow"
		and String(Data.burrow_list()[0]["name"]) == "The Gloomwood")
	Save.mats = {"amber": 7}
	Save.burrow_stats("old_hollow")["depth"] = 2
	Save.burrow_stats("old_hollow")["runs"] = 5
	Save.attach = {"owned": ["mount_saddle"], "mount": "mount_saddle", "pet": ""}
	Save.burrow_run = {"v": 2, "burrow": "old_hollow", "level": 2, "checkpoint": "moonwell"}
	Save.save_game()
	Save.mats = {}
	Save.burrows = {}
	Save.attach = {}
	Save.burrow_run = {}
	Save.load_game()
	_x("fields kept through save and load", int(Save.mats["amber"]) == 7 and Data.burrow_depth("old_hollow") == 2 and int(Save.burrow_stats("old_hollow")["runs"]) == 5
		and Save.attach["mount"] == "mount_saddle" and String(Save.burrow_run.get("checkpoint", "")) == "moonwell",
		{"mats": Save.mats, "burrows": Save.burrows, "attach": Save.attach, "run": Save.burrow_run})
	var d = JSON.parse_string(FileAccess.get_file_as_string(Save.path))
	for k in ["mats", "burrows", "burrow_run", "attach"]:
		d.erase(k)
	var f := FileAccess.open(Save.path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	Save.load_game()
	_x("an old save loads with the defaults", int(Save.mats["amber"]) == 0 and Data.burrow_depth("old_hollow") == 0 and Save.burrow_run.is_empty()
		and (Save.attach["owned"] as Array).is_empty(), {"mats": Save.mats})
	Save.save_game()
	await _burrowsave_open()


## The reveal for an old save that won every mission (once), a Phase E room run closed kindly, and nothing moving by
## time.
func _burrowsave_open() -> void:
	var b = main.burrows
	t._veteran(15)
	Save.flags.erase("hollow_open")
	Save.save_game()
	Save.load_game()
	b.check_open(true)
	_x("not open at once (the reveal waits for the banners)", not Data.burrows_open())
	var opened: bool = await t._until(func(): return Data.burrows_open(), 14.0)
	_x("an old save that won every raid: the Hollow opens", opened)
	var l1 := Save.leaves
	Save.save_game()
	Save.load_game()
	b.check_open(true)
	await t._wait(1.0)
	_x("only once: a second load gives nothing", Data.burrows_open() and Save.leaves == l1)
	# a run saved in Phase E's room format: closed kindly, the whole satchel banked
	var a0 := int(Save.mats.get("amber", 0))
	Save.burrow_run = {"v": 1, "rooms_v": 1, "burrow": "old_hollow", "depth": 1, "seed": 3, "step": 1, "picked": ["den", "treasure"], "hp": 4,
		"satchel": {"amber": 4}, "chain": 0}
	Save.save_game()
	Save.load_game()
	b.check_saved_run()
	_x("a Phase E room run is closed kindly (satchel banked)", Save.burrow_run.is_empty() and int(Save.mats["amber"]) == a0 + 4,
		{"mats": Save.mats})
	# a run on an older map version: the same
	Save.burrow_run = {"v": 2, "map": "old_hollow", "map_v": 999, "burrow": "old_hollow", "level": 1, "seed": 3, "checkpoint": "moonwell", "cleared": [], "chests": [],
		"hp": 4, "satchel": {"amber": 2}}
	b.check_saved_run()
	_x("a run on another version of the map is closed kindly", Save.burrow_run.is_empty() and int(Save.mats["amber"]) == a0 + 6)
	# a good run stays
	Save.burrow_run = {"v": 2, "map": "old_hollow", "map_v": int(Data.dungeon("old_hollow")["version"]), "burrow": "old_hollow", "level": 1, "seed": 3,
		"checkpoint": "moonwell", "cleared": [], "chests": [], "hp": 4, "satchel": {"amber": 2}}
	b.check_saved_run()
	_x("a run of this format stays for Go back in", not Save.burrow_run.is_empty())
	Save.burrow_run = {}
	var m0: Dictionary = Save.mats.duplicate()
	Save.save_game()
	Save.load_game()
	Save.load_game()
	await t._wait(5.0)
	_x("nothing changes with time (materials)", Save.mats == m0)


# ---------------------------------------------------------------- how hard (19 Nov 2026): the standing and the careful cat
## The cat the debug endgame save gives (Save._endgame_seed): mission-15 stats, the Sunwood Longbow at 9, Sprig and
## Thistle at level 3 (the Mushroom Cottage and the Market Stall at 3), its pantry. No key, no dish.
func _endgame_cat() -> void:
	_strong_cat()
	Save.stations["stall"] = 3
	Save.stations["cottage"] = 3
	Save.pantry = {"berries": 8, "herbs": 4, "honey": 2, "fish": 3, "goldfish": 0}
	Save.meal_ready = ""
	main.player.hp = Data.cat_max_hp()


var _seg := "walk"                   # where the health went: a fight's id, "logs", "boss", "walk"
var _rep := {}
var _last_hp := 0
var _careful := false
var _items := false                  # rides, feeds and snacks (the careful cat, and --dungeonstand=items)
var _mount_last := 0
var _strike_seen := 0


## Health in and out every tick, by segment.
func _track() -> void:
	var hp: int = main.player.hp
	if hp < _last_hp:
		var lost: Dictionary = _rep["lost"]
		lost[_seg] = int(lost.get(_seg, 0)) + (_last_hp - hp)
	elif hp > _last_hp:
		_rep["healed"] = int(_rep["healed"]) + (hp - _last_hp)
	_last_hp = hp
	if main.mount != null:
		var mh: int = main.mount.hp
		if mh < _mount_last:
			_rep["mount_lost"] = int(_rep.get("mount_lost", 0)) + (_mount_last - mh)
		_mount_last = mh


func _alive() -> bool:
	return _r().active and not _r().leaving and main.player.hp > 0


## The careful cat, every tenth of a second: lunches and the mount, then the telegraphs (dash out of a slam ring, a
## charge's line or a spore bomb), then backing away from what is about to bite.
func _careful_tick() -> void:
	var p = main.player
	var r = _r()
	if p.hp <= int(Data.cat_max_hp() * 0.5) and not main.snack_pick().is_empty():
		var before: int = p.hp
		main.eat_snack()
		if p.hp > before:
			_rep["snacks"] = int(_rep.get("snacks", 0)) + 1
	if main.mount != null and main.mount.resting > 0.0 and Data.has_items(Data.b["mount"].get("revive_food", {"berries": 2})):
		main.feed_mount()
		_rep["feeds"] = int(_rep.get("feeds", 0)) + 1
	elif main.mount != null and main.mount.resting <= 0.0 and not p.riding:
		main.set_riding(true, false)
	if not _careful:
		return
	var cat: Vector3 = p.global_position
	var away := Vector3.ZERO
	var danger := false
	for e in r.foes():
		if not e.awake:
			continue
		var to_cat: Vector3 = cat - e.global_position
		to_cat.y = 0.0
		var d := to_cat.length()
		var st := String(e.state)
		if st == "slam" and d < float(e.info["slam_range"]) * (1.9 if e.enraged else 1.0) + 0.8:
			danger = true
			away += to_cat.normalized() * 2.0
		elif st in ["windup", "dash_windup", "bite"]:
			var dir: Vector3 = e._charge_dir if st != "bite" else Vector3(sin(e.rotation.y), 0, cos(e.rotation.y))
			var along := to_cat.dot(dir)
			var side := to_cat - dir * along
			if along > -0.5 and along < 10.0 and side.length() < 1.6:
				danger = true
				var sv := side.normalized() if side.length() > 0.05 else Vector3(-dir.z, 0, dir.x)
				away += sv * 2.0
		elif d < float(e.radius) + 1.4 and not bool(e.info.get("flyer", false)) and String(e.id) != "amber_grub" and d > 0.01:
			away += to_cat.normalized()
	if r.strikes != _strike_seen and not r.strike_at.is_empty():
		_strike_seen = r.strikes
		var sa: Vector3 = r.strike_at[0]
		var sv2 := cat - sa
		sv2.y = 0.0
		if sv2.length() < float(r.strike_at[1]) + 0.4:
			danger = true
			away += (sv2.normalized() if sv2.length() > 0.05 else Vector3.RIGHT) * 2.0
	if danger and p.dash_ready_frac() >= 1.0 and away.length() > 0.01:
		p.dash(Vector2(away.x, away.z).normalized())
		_rep["dashes"] = int(_rep.get("dashes", 0)) + 1
	if away.length() > 0.01:
		main.joystick.force = true
		var want: Vector3 = p.global_position + away.normalized() * 1.5
		var ok: Vector3 = r.constrain(want, 0.3, false)
		var mv: Vector3 = ok - p.global_position
		main.joystick.forced = Vector2(mv.x, mv.z).normalized() if mv.length() > 0.2 else Vector2(away.x, away.z).normalized()
	else:
		main.joystick.forced = Vector2.ZERO


## Stands (or plays carefully) while monsters are awake near the cat; steps toward the nearest when it is out of reach.
func _bot_fight(secs: float) -> void:
	var tt := 0.0
	while tt < secs and _alive():
		var live: Array = _r().foes().filter(_fighting)
		if live.is_empty():
			break
		var nr = live[0]
		for e in live:
			if e.global_position.distance_to(main.player.global_position) < nr.global_position.distance_to(main.player.global_position):
				nr = e
		if _items:
			_careful_tick()
		if nr.global_position.distance_to(main.player.global_position) > 5.5 and main.joystick.forced == Vector2.ZERO:
			main.joystick.force = true
			var dv: Vector3 = nr.global_position - main.player.global_position
			main.joystick.forced = Vector2(dv.x, dv.z).normalized() * 0.6
		elif not _careful:
			main.joystick.forced = Vector2.ZERO
		await t._wait(0.1)
		tt += 0.1
		_track()
	main.joystick.forced = Vector2.ZERO


## Walks on to arc length s_to in short hops; whatever wakes is fought where it is (the segment is its fight's id).
func _bot_walk(s_to: float) -> void:
	var s := _cat_s()
	var hops := 0
	while absf(s - s_to) > 0.9 and hops < 120 and _alive():
		hops += 1
		var nxt := s + clampf(s_to - s, -2.4, 2.4)
		_seg = "logs" if s > 76.0 and s < 91.0 else "walk"
		await t._go_straight(_sp(nxt), 0.5, 3.0)
		_track()
		var s2 := _cat_s()
		if absf(s2 - s) < 0.15 and absf(s_to - s2) > 0.9:
			main.player.global_position = _sp(nxt)
			s2 = _cat_s()
		s = s2
		for f in _r().fights:
			if String(f["state"]) == "awake" and _alive():
				_seg = String(f["id"])
				await _bot_fight(150.0)
				# a dew bud where it was won: a player takes it
				for bud in _r()._buds.duplicate():
					if is_instance_valid(bud) and bud.global_position.distance_to(main.player.global_position) < 9.0 and _alive():
						await t._go_straight(bud.global_position, 0.3, 4.0)
						_track()
				_seg = "walk"
		main.hud.hide_card()


func _dungeonstand(mode: String) -> void:
	await _endgame_camp()
	_endgame_cat()
	var r = _r()
	_careful = mode == "careful"
	_items = mode in ["careful", "items"]
	main.set_riding(false, false)
	await main.burrows.enter("old_hollow", 1)
	await t._wait(0.8)
	var m = _map()
	main.player.invincible = false
	if mode == "god":
		Data.run_mods["hp"] = 1000.0
	main.player.hp = Data.cat_max_hp()
	if _items:
		main.set_riding(true, false)
	_last_hp = main.player.hp
	_mount_last = main.mount.hp if main.mount != null else 0
	_rep = {"mode": mode, "max_hp": Data.cat_max_hp() - (1000 if mode == "god" else 0), "lost": {}, "healed": 0,
		"arrow": snappedf(Data.arrow_damage(), 0.1), "out_at": ""}
	t._log("stand_start", {"mode": mode, "hp": main.player.hp, "arrow": Data.arrow_damage(), "draw": Data.cat_draw(),
		"mount_hp": main.mount.max_hp() if main.mount != null else 0})
	for s in [12.0, 26.0, 36.0, 46.0, 52.0, 64.0, 76.0, 91.0, 97.5]:
		await _bot_walk(s)
		if not _alive():
			break
	# the Moonwell: the spring, a boon
	if _alive():
		_seg = "moonwell"
		await t._go_straight(m.parts["spring"].global_position, 0.2, 6.0)
		await t._wait(2.2)
		_track()
		if m.parts.has("shrine_0_ring"):
			await t._go_straight(m.parts["shrine_0_ring"].global_position, 0.2, 6.0)
			await t._wait(0.8)
			t._press("Take")
			await t._wait(0.4)
			if mode == "god":
				Data.run_mods["hp"] = float(Data.run_mods.get("hp", 0.0)) + 1000.0
			main.hud.hide_card()
			_track()
	for s in [108.0, 113.0, 119.0, 125.0, 133.0, 139.0, m.length - 13.0]:
		if not _alive():
			break
		await _bot_walk(s)
	var hp_at_boss: int = main.player.hp
	var boss_t := 0.0
	var boss_hp0 := 0.0
	var enraged_at := -1.0
	if _alive():
		await _bot_walk(m.length - 8.0)
		_seg = "boss"
		await t._until(func(): return m.sealed and r._boss != null and r._boss.awake, 3.0)
		var bo = r._boss
		boss_hp0 = bo.max_hp if bo != null else 0.0
		await t._go_straight(m.w2(m.arena_c) + Vector3(0, 0, 3.0), 0.5, 4.0)
		while _alive() and not r._boss_down and boss_t < 300.0:
			if _items:
				_careful_tick()
			else:
				main.joystick.forced = Vector2.ZERO
			await t._wait(0.1)
			boss_t += 0.1
			_track()
			if bo != null and is_instance_valid(bo) and bo.enraged and enraged_at < 0.0:
				enraged_at = boss_t
			if fmod(boss_t, 15.0) < 0.1:
				t._log("boss", {"t": snappedf(boss_t, 0.1), "boss_hp": snappedf(bo.hp if is_instance_valid(bo) else 0.0, 1.0), "cat_hp": main.player.hp,
					"adds": r.foes().filter(func(e): return e.summoned).size()})
			if int(boss_t * 10.0) == 150:
				await t._shot("stand_%s_boss" % mode)
		main.joystick.forced = Vector2.ZERO
	var boss_down: bool = r._boss_down or bool(r.run.get("boss_down", false))
	var out: bool = not boss_down and (main.area == null or not r.active or main.player.hp <= 0)
	_rep["out"] = out
	_rep["out_at"] = _seg if out else ""
	_rep["boss_secs"] = snappedf(boss_t, 0.1)
	_rep["boss_hp"] = int(boss_hp0)
	_rep["boss_down"] = boss_down
	_rep["boss_enraged_at_s"] = snappedf(enraged_at, 0.1)
	_rep["hp_at_boss"] = hp_at_boss - (1000 if mode == "god" else 0)
	_rep["pantry_left"] = Save.pantry.duplicate()
	var total := 0
	for k in _rep["lost"]:
		total += int(_rep["lost"][k])
	_rep["lost_total"] = total
	t._log("stand", _rep)
	var f := FileAccess.open(t.shots.path_join("stand_%s.json" % mode), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_rep, "  "))
	match mode:
		"real":
			_x("the standing cat (no dodging, lunches or mount) is knocked out before the end of level 1", out and not boss_down,
				{"out_at": _rep["out_at"], "lost": _rep["lost"]})
		"god":
			_x("standing, it takes more health than the cat has (%d) before the boss is down" % int(_rep["max_hp"]),
				total > int(_rep["max_hp"]) + int(_rep["healed"]), {"lost_total": total, "healed": _rep["healed"]})
			_x("Mossback takes 55-150 s to fall to a standing endgame cat: %.1f s" % boss_t, boss_down and boss_t >= 55.0 and boss_t <= 150.0,
				{"secs": boss_t, "hp": boss_hp0})
		"careful":
			_x("the careful cat (mount, lunches, dodging) beats level 1", boss_down and not out, {"out_at": _rep["out_at"], "lost": _rep["lost"]})
			_x("... with effort: Thistle was knocked out and fed, or lunches were eaten", int(_rep.get("feeds", 0)) + int(_rep.get("snacks", 0)) > 0,
				{"feeds": _rep.get("feeds", 0), "snacks": _rep.get("snacks", 0), "mount_lost": _rep.get("mount_lost", 0)})
		"items":
			_x("standing on Thistle with its lunches but never dodging, it still falls before the end", out and not boss_down,
				{"out_at": _rep["out_at"], "lost": _rep["lost"], "mount_lost": _rep.get("mount_lost", 0)})
	await t._wait(0.5)
	if r.active:
		await r._leave("back")
