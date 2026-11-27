## H6 Stage 2 checks, part 3 of 3: the three specialisations, armour, and the save (v5 in, v6 out, held stock, wear,
## credit, two loads). Moved out of autotest_workshop.gd on 27 Nov 2026 (house rule 1: one job a file, under about 800
## lines); the checks, their words and their order did not change. autotest_workshop.gd runs it last in its live run
## and frees it after.
extends Node

const AutotestScript := preload("res://scripts/autotest.gd")
const MainScript := preload("res://scripts/main.gd")
const Home := preload("res://scripts/autotest_workshop.gd")
const Enemy := preload("res://scripts/enemy.gd")
const ExplosiveAcorns := preload("res://abilities/explosive_acorns.gd")
const Buy := preload("res://commands/buy.gd")
const StatusPart := preload("res://parts/status.gd")
const SPEC_PRICES: Array = Home.SPEC_PRICES
const SPEC_IDS: Array = Home.SPEC_IDS
const ARMOUR: Dictionary = Home.ARMOUR
const NO_SLOT := Vector2i(-1, -1)
const RAW: float = 10.0

var t: AutotestScript
var main: MainScript
var g                     # autotest_workshop.gd: the helpers all halves use (_x, _rich, _bare_camp, _put and the rest)


## The checks, in the order they always ran.
func run() -> bool:
	var ok: bool = await _check_specs()
	ok = await _check_armour() and ok
	return await _check_save() and ok


# ---------------------------------------------------------------- helpers kept in autotest_workshop.gd (the other halves use them too)
func _x(what: String, cond: bool, extra: Dictionary = {}) -> bool:
	return g._x(what, cond, extra)


func _dict(value: Variant) -> Dictionary:
	return Home._dict(value)


func _same(a: Variant, b: Variant) -> bool:
	return Home._same(a, b)


func _rich() -> void:
	g._rich()


func _bare_camp() -> void:
	g._bare_camp()


func _drain(kind: String) -> void:
	g._drain(kind)


func _put(kind: String, at: Vector3, level: int = 1, wear: float = -1.0) -> Dictionary:
	return g._put(kind, at, level, wear)


func _spot(kind: String, n: int = 0) -> Vector3:
	return g._spot(kind, n)


func _cost_eq(a: Variant, b: Dictionary) -> bool:
	return g._cost_eq(a, b)


func _spent(before_leaves: int, before_timber: int) -> Dictionary:
	return g._spent(before_leaves, before_timber)



func _spawn(kind: String, at: Vector3, strength: float = 1.0, armoured: bool = false) -> Enemy:
	return g._spawn(kind, at, strength, armoured)


func _tank_entry(kind: String) -> Dictionary:
	return g._tank_entry(kind)

# ---------------------------------------------------------------- the three specialisations
func _check_specs() -> bool:
	var d = main.defences
	var st = main.stations
	_bare_camp()
	t._veteran(3)
	_rich()
	Save.camp_level = 3
	Save.stations["workshop"] = 3
	st.refresh("all")
	var win = main.hud.windows["workshop"]
	var ok: bool = true
	# learning each once, then to level 3, prices and stale buys
	for sid: String in SPEC_IDS:
		var wrong_stale: bool = st.buy_specialisation(sid, 2)
		var price_ok: bool = true
		for lv: int in [1, 2, 3]:
			var buy := Buy.new("specialisations", sid, 1, lv)
			price_ok = price_ok and buy.next_level() == lv and _cost_eq(buy.price(), SPEC_PRICES[lv - 1]) and buy.can_run(main) == ""
			var l0: int = Save.leaves
			var t0: int = Save.timber
			var bought: bool = st.buy_specialisation(sid, lv)
			price_ok = price_ok and bought and Data.specialisation_level(sid) == lv and _cost_eq(_spent(l0, t0), SPEC_PRICES[lv - 1])
			var l1: int = Save.leaves
			var again: bool = st.buy_specialisation(sid, lv)
			price_ok = price_ok and not again and Save.leaves == l1
		ok = _x("%s: a stale Learn buys nothing; learned then raised to 3 at 250/10, 550/20, 1,100/35; a repeat buy spends nothing; there is no level 4" % sid,
			not wrong_stale and price_ok and Data.specialisation_level(sid) == 3 and not st.buy_specialisation(sid, 4)) and ok
	await t._shot("workshop_specialisations_learned")
	# explosive acorns: each other foe in the blast once, the primary skipped, no chain
	var tun: Dictionary = _dict(Data.b["specialisations"]["explosive_acorns"])
	var shares: Array = tun["share"]
	var radius: float = float(tun["radius_m"])
	var blast_ok: bool = true
	for lv: int in [1, 2, 3]:
		var at: Vector3 = Vector3(0, 0, -20)
		var primary: Enemy = _spawn("thornling", at, 1.0)
		var near_a: Enemy = _spawn("thornling", at + Vector3.RIGHT * radius * 0.6, 1.0)
		var near_b: Enemy = _spawn("thornling", at + Vector3.LEFT * radius * 0.4, 1.0)
		var far: Enemy = _spawn("thornling", at + Vector3.RIGHT * (radius * 1.6), 1.0)
		for e: Enemy in [primary, near_a, near_b, far]:
			e.hp = 1000.0
			e.max_hp = 1000.0
		var hits: Array[Node] = []
		var on_damage: Callable = func(target: Node, _amount: float) -> void: hits.append(target)
		Events.damage_dealt.connect(on_damage)
		ExplosiveAcorns.burst(main, at + Vector3.UP * primary.aim_height, primary, 100.0, lv)
		Events.damage_dealt.disconnect(on_damage)
		var share: float = float(shares[lv - 1])
		blast_ok = blast_ok and hits.size() == 2 and hits.has(near_a) and hits.has(near_b) and not hits.has(primary) and not hits.has(far) \
			and is_equal_approx(1000.0 - near_a.hp, 100.0 * share) and is_equal_approx(1000.0 - near_b.hp, 100.0 * share) \
			and is_equal_approx(primary.hp, 1000.0) and is_equal_approx(far.hp, 1000.0)
		for e: Enemy in [primary, near_a, near_b, far]:
			e.free()
	ok = _x("Explosive acorns at levels 1 to 3: a 1.2 m blast of 30, 45 and 60% of the hit reaches every other foe once, skips the primary and the foe outside, and never chains", blast_ok) and ok
	# a real tower shot: the blast shows only when it is learned
	var tw: Dictionary = _put("tower", Vector3(0, 0, 12), 1)
	var tnode = tw["node"]
	var primary2: Enemy = main.fight.spawn("thornling", Vector3(0, 0, 12) + Vector3(0, 0, 3.0), 0) as Enemy
	var neighbour: Enemy = main.fight.spawn("thornling", Vector3(0.6, 0, 15.0), 0) as Enemy
	for e: Enemy in [primary2, neighbour]:
		e.set_physics_process(false)
		e.hp = 100000.0
		e.max_hp = 100000.0
	var shot: bool = await t._until(func() -> bool: return neighbour.hp < 100000.0 or primary2.hp < 100000.0 and tnode.shots > 1, 3.0)
	var spent_neighbour: bool = neighbour.hp < 100000.0
	ok = _x("a real tower's acorn with Explosive acorns learned also hurts the foe beside the one it hit", shot and primary2.hp < 100000.0 and spent_neighbour,
		{"primary": primary2.hp, "neighbour": neighbour.hp}) and ok
	primary2.queue_free()
	neighbour.queue_free()
	d.remove_placement(int(tw["id"]))
	Save.placed = []
	# reinforced barricades: health, crack threshold, the model's rows
	var pad: Vector2i = t.build_any_row()
	var row: Dictionary = d.row_at(pad.x, pad.y)
	var base_hp: float = float(Data.defence_level_info("barricade", 1)["hp"])
	var bonus: Array = Data.b["specialisations"]["reinforced_barricades"]["hp_bonus"]
	var crack: float = float(Data.b["specialisations"]["reinforced_barricades"]["crack_at"])
	var sec: Dictionary = (row["pieces"] as Array)[0]
	ok = _x("Reinforced barricades at level 3 gives every section +55% health", is_equal_approx(float(sec["max_hp"]), base_hp * (1.0 + float(bonus[2]))), {"max": sec["max_hp"], "base": base_hp}) and ok
	sec["hp"] = float(sec["max_hp"]) * (crack + 0.05)
	var whole_above: bool = d.piece_stage(sec) == "whole"
	sec["hp"] = float(sec["max_hp"]) * (crack - 0.05)
	var cracked_below: bool = d.piece_stage(sec) == "cracked"
	sec["hp"] = 0.0
	var broken_at_zero: bool = d.piece_stage(sec) == "broken"
	ok = _x("a section cracks at 35% (not 50%) and still breaks at 0", whole_above and cracked_below and broken_at_zero) and ok
	sec["hp"] = float(sec["max_hp"])
	# deep thorns: the strongest overlapping patch, +50% slow, and the linger of one second
	var spot: Vector3 = _spot("spikes", 5)
	var low: Dictionary = _put("spikes", spot, 1)
	var high: Dictionary = _put("spikes", spot + Vector3(0.5, 0, 0), 3)
	var mult: float = float(Data.b["specialisations"]["deep_thorns"]["slow_mult"][2])
	var slow3: float = float(Data.defence_level_info("spikes", 3)["slow"])
	var at_both: float = float(d.slow_at(spot + Vector3(0.25, 0, 0)))
	ok = _x("Deep thorns at level 3: where two patches overlap the strongest one counts, and its slow is 50% stronger", not low.is_empty() and not high.is_empty()
		and is_equal_approx(at_both, slow3 * mult) and is_equal_approx(float(d.level_stats("spikes", 3)["slow"]), slow3 * mult), {"slow": at_both, "want": slow3 * mult}) and ok
	var part = StatusPart.new()
	var linger: float = float(Data.b["specialisations"]["deep_thorns"]["linger_s"])
	var carry: float = part.step_thorn_slow(0.4, 0.1, linger)
	var half: float = part.step_thorn_slow(0.0, 0.5, linger)
	var paused: float = part.step_thorn_slow(0.0, 0.0, linger)
	var gone: float = part.step_thorn_slow(0.0, 0.6, linger)
	ok = _x("the slow lasts one second after the foe steps off, holds while the game is paused (no time passes) and then ends", is_equal_approx(carry, 0.4) and is_equal_approx(half, 0.4)
		and is_equal_approx(paused, 0.4) and is_equal_approx(gone, 0.0), {"half": half, "paused": paused, "gone": gone}) and ok
	var no_linger: float = part.step_thorn_slow(0.0, 0.1, 0.0)
	ok = _x("with no linger (not learned) it is H5's: the slow ends the moment the foe leaves the patch", is_equal_approx(no_linger, 0.0)) and ok
	part.free()
	var foe: Enemy = _spawn("thornling", Vector3(0, 0, -25), 1.0)
	ok = _x("a foe's own linger follows what is learned (1 s)", is_equal_approx(float(foe._thorn_linger()), linger)) and ok
	foe.free()
	return ok


# ---------------------------------------------------------------- armour on the four tanks
func _check_armour() -> bool:
	var ok: bool = true
	var deaths: Array[String] = []
	var on_death: Callable = func(kind: String, _at: Vector3) -> void: deaths.append(kind)
	Events.enemy_died.connect(on_death)
	for kind: String in ARMOUR:
		var share: float = float(ARMOUR[kind])
		var plain: Enemy = _spawn(kind, Vector3(0, 0, -30), 1.0, false)
		var tough: Enemy = _spawn(kind, Vector3(4, 0, -30), 1.0, true)
		var health_ok: bool = is_equal_approx(tough.max_hp, plain.max_hp * (1.0 - share))
		# one ordinary hit from behind (outside every shield): raw is kept, dealt is after armour, kill time is H5's
		plain.rotation.y = 0.0
		tough.rotation.y = 0.0
		plain.hit(Vector3.BACK, RAW)
		tough.hit(Vector3.BACK, RAW)
		var hit_ok: bool = is_equal_approx(tough.last_raw, RAW) and is_equal_approx(tough.last_dealt, RAW * (1.0 - share)) and is_equal_approx(plain.last_dealt, RAW) \
			and is_equal_approx(tough.max_hp / tough.last_dealt, plain.max_hp / plain.last_dealt)
		# a burn tick, a spike tick, a heal
		var h0: float = tough.hp
		tough._burn_hurt(RAW)
		var burn_ok: bool = is_equal_approx(h0 - tough.hp, RAW * (1.0 - share))
		h0 = tough.hp
		tough.hurt_spikes(RAW)
		var spike_ok: bool = is_equal_approx(h0 - tough.hp, RAW * (1.0 - share))
		h0 = tough.hp
		tough.heal_raw(RAW)
		var heal_ok: bool = is_equal_approx(tough.hp - h0, RAW * (1.0 - share))
		var side_ok: bool = true
		if kind == "beetle":
			var block: float = float(_tank_entry("beetle")["parts"]["status"]["shield_block"])
			tough.rotation.y = 0.0
			tough.hit(Vector3.FORWARD, RAW)
			var front_dealt: float = tough.last_dealt
			tough.hit(Vector3.RIGHT, RAW)
			side_ok = is_equal_approx(front_dealt, RAW * (1.0 - block) * (1.0 - share)) and is_equal_approx(tough.last_dealt, RAW * (1.0 - share)) and is_equal_approx(tough.last_raw, RAW)
		# one death and one reward, through the real spawn path
		var real = main.fight.spawn(kind, Vector3(8, 0, -30), 0)
		var one_death: bool = false
		if real != null and is_instance_valid(real):
			(real as Node3D).set_physics_process(false)
			var armoured_ok: bool = is_equal_approx((real as Enemy).max_hp, plain.max_hp * float(main.fight.strength()) * (1.0 - share))
			var count0: int = deaths.size()
			(real as Enemy).hit(Vector3.BACK, (real as Enemy).hp * 10.0 + 100.0)
			await t._wait(0.15)
			one_death = armoured_ok and deaths.size() - count0 == 1 and deaths.back() == kind
		ok = _x("%s: %d%% armour: health and hits scale together (same kill time), raw and dealt are kept apart, burn, spikes and heals follow, and it dies once" % [kind, int(share * 100.0)],
			health_ok and hit_ok and burn_ok and spike_ok and heal_ok and side_ok and one_death,
			{"health": health_ok, "hit": hit_ok, "burn": burn_ok, "spikes": spike_ok, "heal": heal_ok, "side": side_ok, "death": one_death, "real": real != null, "deaths": deaths}) and ok
		plain.free()
		tough.free()
	Events.enemy_died.disconnect(on_death)
	# a Gloomtouched (stronger) tank keeps the same share of its scaled health
	var strong: Enemy = _spawn("stump", Vector3(0, 0, -30), 1.5, true)
	var strong_plain: Enemy = _spawn("stump", Vector3(4, 0, -30), 1.5, false)
	ok = _x("a stronger (Gloomtouched) tank is scaled first and armoured after: its health is the unarmoured scaled health times the armour factor",
		is_equal_approx(strong.max_hp, strong_plain.max_hp * (1.0 - float(ARMOUR["stump"])))) and ok
	strong.free()
	strong_plain.free()
	# a mission boss, and a tank made a raid leader or an expedition room's boss, keep H5's health and damage
	var boss = main.fight.spawn("stump", Vector3(0, 0, -30), 0, -1, true)
	var plain_stump: Enemy = _spawn("stump", Vector3(4, 0, -30), 1.0, false)
	var boss_ok: bool = boss != null and is_instance_valid(boss)
	if boss_ok:
		(boss as Node3D).set_physics_process(false)
		var h0: float = (boss as Enemy).hp
		(boss as Enemy).hit(Vector3.BACK, RAW)
		boss_ok = is_equal_approx(h0 - (boss as Enemy).hp, RAW) and is_equal_approx((boss as Enemy).last_dealt, RAW)
	ok = _x("a tank spawned as a mission boss has no armour: a hit does its full damage", boss_ok) and ok
	if boss != null and is_instance_valid(boss):
		boss.queue_free()
	var leader: Enemy = _spawn("beetle", Vector3(8, 0, -30), 1.0, false)
	var leader_h: float = leader.hp
	leader.hit(Vector3.BACK, RAW)
	ok = _x("a tank set up unarmoured (a raid leader or an expedition room's boss) keeps its H5 health and takes the full hit", is_equal_approx(leader.max_hp, float(Data.enemy("beetle")["hp"]))
		and is_equal_approx(leader_h - leader.hp, RAW)) and ok
	leader.free()
	plain_stump.free()
	return ok


# ---------------------------------------------------------------- the save: v5 in, v6 out, held stock, wear, credit, two loads
func _write_scratch(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	var ok: bool = f.store_string(text)
	f.close()
	return ok


func _read_scratch(path: String) -> Dictionary:
	return _dict(JSON.parse_string(FileAccess.get_file_as_string(path)))


func _check_save() -> bool:
	var d = main.defences
	var st = main.stations
	var w = main.world
	_bare_camp()
	t._veteran(3)
	_rich()
	Save.camp_level = 3
	Save.stations["workshop"] = 0
	Save.ruined = []
	st.refresh("all")
	# the fixture's places, found in the live camp before the old file replaces it
	var wp: Vector3 = w.station_pos("workshop")
	var stall: Vector3 = w.station_pos("stall")
	var clear: Vector3 = Vector3(1.0e9, 0, 0)
	for n: int in range(6, 30):
		var cand: Vector3 = _spot("tower", n)
		if cand.x > 1.0e8:
			break
		if not w.on_station_ground("workshop", cand, 1.5) and not w.on_station_ground("stall", cand, 1.5):
			clear = cand
			break
	var slot: Vector2i = NO_SLOT
	for sl: Array in w.barricade_slots():
		if d.pad_open(int(sl[2]), int(sl[3])):
			slot = Vector2i(int(sl[2]), int(sl[3]))
			break
	var ok: bool = _x("the save fixture's places exist (a clear spot and an open road pad)", clear.x < 1.0e8 and slot != NO_SLOT)
	if not ok:
		return false
	var missions: Array = []
	for i: int in 3:
		missions.append(String(Data.mission(i)["id"]))
	var v5: Dictionary = {
		"save_v": 5, "leaves": 5000, "timber": 100, "shards": 12, "camp_level": 3, "missions_done": missions,
		"stations": {"target": 1, "bench": 1, "stall": 1, "well": 1}, "pet_level": 1, "claimed": [0, 1],
		"flags": {"shop_open": true, "shop_target": true, "shop_bench": true, "home": true, "first_stage_done": true},
		"owned": {"pets": {"sprig": {"level": 1}}}, "future_field": {"keep": [true, "note"]},
		"def_levels": {"barricade": 3, "tower": 4, "spikes": 5}, "items": {"tower": 1, "spikes": 0},
		"placed": [
			{"type": "tower", "x": wp.x + 0.6, "z": wp.z - 0.4, "rot": 0.0, "wreck": 0.4},
			{"type": "tower", "x": stall.x + 0.3, "z": stall.z, "rot": 0.0},
			{"type": "tower", "x": clear.x, "z": clear.z, "rot": 0.0},
			{"type": "barricade", "slot": [slot.x, slot.y], "row": 3, "wrecks": [-1.0, 0.0, 0.65], "wreck": 0.0},
		],
	}
	var text: String = JSON.stringify(v5, "  ") + "\n"
	var original: String = Save.path
	Save.save_game(true)
	var was_frozen: bool = main.frozen
	main.frozen = true
	var scratch: String = "user://leaf_save_test_workshop.json"
	var backup: String = scratch.get_basename() + ".bak.json"
	for p: String in [scratch, backup, scratch + ".tmp", backup + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	Save.path = scratch
	ok = _x("the mixed-level v5 file is written", _write_scratch(scratch, text)) and ok
	Save.load_game()
	await get_tree().process_frame
	ok = _x("the v5 file loads as v5, becomes v6 and is backed up byte for byte", Save.loaded_v == 5 and Save.save_v == 6 and FileAccess.file_exists(backup)
		and FileAccess.get_file_as_string(backup) == text, {"loaded": Save.loaded_v, "save_v": Save.save_v}) and ok
	ok = _x("old ownership, currencies and unrelated fields survive the step", Save.shards == 12 and Save.leaves == 5000 and Data.owned_level("pets", "sprig") == 1
		and Save.camp_level == 3 and Save.missions_done == missions) and ok
	var lv_ok: bool = Save.placed.size() == 4 and int(Save.placed[0].get("level", 0)) == 4 and is_equal_approx(float(Save.placed[0].get("wreck", 0.0)), 0.4) \
		and int(Save.placed[3].get("level", 0)) == 3 and _same(Save.placed[3].get("wrecks"), [-1.0, 0.0, 0.65])
	ok = _x("every placed piece carries its kind's old level and its own wear, the row keeps its uneven section wear", lv_ok, {"placed": Save.placed}) and ok
	ok = _x("the held tower keeps level 4 and the paid-for patch level 5 waits as one credit", _same(Save.defence_reserves, {"tower": [{"level": 4}]})
		and _same(Save.defence_legacy_credit, {"spikes": 5}) and Bag.best_held_level("tower") == 4, {"reserves": Save.defence_reserves, "credit": Save.defence_legacy_credit}) and ok
	# a full Bag when the older obstruction goes back
	Bag.add("berries", Bag.room_for("berries"))
	d.load_saved()
	await get_tree().process_frame
	ok = _x("the towers on the Market's and the Workshop's ground go back into a full Bag at their level and wear (forced): the Workshop's ground counts as camp even before it is built",
		Bag.count("tower") == 3 and Bag.used_slots() >= Bag.slots() and Bag.best_held_level("tower") == 4 and Save.placed.size() == 2
		and _reserve_has("tower", 4, 0.4), {"held": Bag.count("tower"), "placed": Save.placed.size(), "slots": [Bag.used_slots(), Bag.slots()], "best": Bag.best_held_level("tower"), "res": Save.defence_reserves}) and ok
	Save.bag = {}
	st.refresh("all")
	# the Workshop is built over the worn tower: it goes back with its level and wear, once
	_put("tower", wp + Vector3(0.6, 0.0, -0.4), 4, 0.3)
	var held0: int = Bag.count("tower")
	st._build_station("workshop")
	await t._wait(0.4)
	var back_wear: bool = false
	for rec: Variant in (Save.defence_reserves.get("tower", []) as Array):
		if rec is Dictionary and is_equal_approx(float((rec as Dictionary).get("wreck", -1.0)), 0.3) and int((rec as Dictionary).get("level", 0)) == 4:
			back_wear = true
	ok = _x("building the Workshop sends the tower standing on its ground back to the Bag at level 4 with its wear (0.3), once", int(Save.stations["workshop"]) == 1
		and Bag.count("tower") == held0 + 1 and back_wear and not _on_ground(wp), {"held": Bag.count("tower"), "reserves": Save.defence_reserves}) and ok
	# placing each again keeps the paid level, and the wear comes with the piece that had it
	var made: Array[int] = []
	var seen_wear: int = 0
	for n: int in Bag.count("tower"):
		var at: Vector3 = _spot("tower", 2 + 3 * n)
		if at.x > 1.0e8:
			continue
		d.start_placing("tower")
		var id: int = int(d.commit_placement("tower", at, 0.0))
		d.stop_placing()
		if id >= 0:
			made.append(id)
			var p: Dictionary = d.piece_at(id)
			var src: Dictionary = _dict(p.get("src"))
			if d.piece_level(p) == 4 and int(src.get("level", 0)) == 4:
				if is_equal_approx(float(src.get("wreck", 0.0)), 0.4) or is_equal_approx(float(src.get("wreck", 0.0)), 0.3):
					seen_wear += 1
				elif not src.has("wreck"):
					seen_wear += 0
	ok = _x("placed again, all four held towers keep level 4 and exactly two carry their wear (0.4 and 0.3), and the Bag is empty of towers", made.size() == 4 and seen_wear == 2 and Bag.count("tower") == 0
		and Save.defence_reserves.get("tower", []).is_empty(), {"made": made, "wear": seen_wear}) and ok
	# the credit is redeemed once
	var l0: int = Save.leaves
	st._buy_piece("spikes")
	st._buy_piece("spikes")
	var first_best: int = int(Bag.peek_defence("spikes").get("level", 0))
	var s1: int = int(d.commit_placement("spikes", _spot("spikes", 12), 0.0)) if Bag.count("spikes") > 0 else -1
	var s2: int = int(d.commit_placement("spikes", _spot("spikes", 14), 0.0)) if Bag.count("spikes") > 0 else -1
	var lv1: int = d.piece_level(d.piece_at(s1)) if s1 >= 0 else 0
	var lv2: int = d.piece_level(d.piece_at(s2)) if s2 >= 0 else 0
	ok = _x("the old Thorn Spikes level 5 comes back once: the first patch is level 5, the second level 1, the credit is gone", first_best == 5 and maxi(lv1, lv2) == 5 and mini(lv1, lv2) == 1
		and not Save.defence_legacy_credit.has("spikes") and l0 > Save.leaves, {"levels": [lv1, lv2], "credit": Save.defence_legacy_credit}) and ok
	d.stop_placing()
	# resave and reload twice
	Save.save_game(true)
	var one: Dictionary = _read_scratch(scratch)
	Save.load_game()
	await get_tree().process_frame
	Save.save_game(true)
	var two: Dictionary = _read_scratch(scratch)
	Save.load_game()
	await get_tree().process_frame
	Save.save_game(true)
	var three: Dictionary = _read_scratch(scratch)
	ok = _x("loading and saving v6 twice changes nothing (reserves, credit and wear are not used up or repeated); no def_levels is ever written; the unknown field stays",
		_same(_no_clock(one), _no_clock(two)) and _same(_no_clock(two), _no_clock(three)) and not one.has("def_levels") and int(one.get("save_v", 0)) == 6 and one.has("defence_reserves") and one.has("defence_legacy_credit")
		and _same(one.get("future_field"), v5["future_field"]), {"diff12": _diff(one, two), "diff23": _diff(two, three), "one_placed": (one.get("placed", []) as Array).size(), "one": one.get("placed"), "two": two.get("placed"), "r1": one.get("defence_reserves"), "r2": two.get("defence_reserves")}) and ok
	# a second, bare save in the same process keeps nothing of the first
	ok = _x("a bare v6 file is written", _write_scratch(scratch, JSON.stringify({"save_v": 6, "leaves": 3}) + "\n")) and ok
	Save.load_game()
	await get_tree().process_frame
	ok = _x("a second fresh save keeps no piece, stock, credit, Workshop, pet or shards of the first", Save.leaves == 3 and Save.placed.is_empty() and Save.defence_reserves.is_empty()
		and Save.defence_legacy_credit.is_empty() and int(Save.stations.get("workshop", -1)) == 0 and Save.shards == 0 and Data.owned_level("pets", "sprig") == 0
		and Bag.count("tower") == 0, {"placed": Save.placed, "stations": Save.stations}) and ok
	# back to the test slot
	Save.path = original
	Save.load_game()
	main.frozen = was_frozen
	for p: String in [scratch, backup, scratch + ".tmp", backup + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	st.refresh("all")
	d.load_saved()
	await t._wait(0.3)
	return ok


func _on_ground(_at: Vector3) -> bool:
	for p: Dictionary in main.defences.pieces:
		if main.world.on_station_ground("workshop", p["pos"], 0.6):
			return true
	return false


## Does the Bag's reserve list for this kind hold a record of this level and this wear?
func _reserve_has(kind: String, level: int, wear: float) -> bool:
	for rec: Variant in (Save.defence_reserves.get(kind, []) as Array):
		if rec is Dictionary and int((rec as Dictionary).get("level", 0)) == level and is_equal_approx(float((rec as Dictionary).get("wreck", -1.0)), wear):
			return true
	return false


func _diff(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for k: Variant in a:
		if not b.has(k) or not _same(a[k], b[k]):
			out.append(k)
	for k: Variant in b:
		if not a.has(k):
			out.append(k)
	return out


## A save without its clock fields (timers.seen moves with the real time between two saves).
func _no_clock(d: Dictionary) -> Dictionary:
	var c: Dictionary = d.duplicate(true)
	c.erase("timers")
	return c
