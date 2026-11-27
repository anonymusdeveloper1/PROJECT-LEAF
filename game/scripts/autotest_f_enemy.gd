extends Node
## Phase F's enemy tests (docs/PHASE_F_PLAN.md 2.2 and 2.4), run from autotest.gd (`-- --autotest --fresh --enemyf`).
## Each check logs "EXPECT PASS <what>" or "EXPECT FAIL <what>" through autotest.gd's _expect. One mission camp (a
## veteran of 4 missions, mission 2 started, its waves stopped, the towers quiet, the cat and Sprig holding their fire),
## then, one after another:
##   boar   a boar charges at the cat, the cat steps aside: "Bonk!", dazed for about miss_daze s, a hit then does
##          daze_hurt x damage, and the tip's flag is set
##   siege  a Pitcher Spitter, then a Frog Shaman, just outside a building's siege ring: each stops about siege_range m
##          from it and shoots it from there (its health goes down), beyond a cat-at-the-fire's reach
##   grub   a Golden Grub runs (a foe the cat's auto-aim takes, and a bonus), never into the firelight, hurts nothing and
##          gets away when nobody hits it (its life cut short here); a caught one drops its leaves
##   totem  a Thornling near a Gloom Totem is faster and takes less damage than one far off; the totem never moves;
##          breaking it ends both at once

var t                     # autotest.gd (its helpers: _wait, _shot, _expect, _until, _veteran, _log)
var main


func run() -> bool:
	await _camp()
	await _boar()
	await _clear()
	await _siege()
	await _clear()
	await _grub()
	await _clear()
	await _totem()
	await _clear()
	_hold(false)
	main.fight.set_physics_process(true)
	t._log("enemyf done")
	return true


func _x(what: String, ok: bool, extra := {}) -> bool:
	return t._expect(what, ok, extra)


# ---------------------------------------------------------------- helpers
## A camp four missions in, mission 2 on but no enemies of its own, the towers quiet (they would shoot the test foes).
func _camp() -> void:
	main.player.invincible = true
	t._veteran(4)
	await t._wait(0.3)
	main.fight.skip_gate = true                         # mission 2 is won here: no replays, so the test opens the gate
	main.start_stage(1)
	await t._wait(0.5)
	main.fight.set_physics_process(false)
	await _clear()
	for pc in main.defences.pieces:
		if String(pc["type"]) == "tower":
			pc["hp"] = 0.0
	_hold(true)
	t._log("enemyf camp", {"mission_on": main.fight.active, "in_wave": main.fight.in_wave, "camp_r": main.world.camp_r})


## The cat and Sprig hold their fire (the cat can still be moved by hand).
func _hold(on: bool) -> void:
	main.player.frozen = on
	if main.pet != null:
		main.pet.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


func _clear() -> void:
	for e in get_tree().get_nodes_in_group("foes"):
		e.dead = true
		e.remove_from_group("foes")
		e.remove_from_group("enemies")
		e.queue_free()
	for pk in get_tree().get_nodes_in_group("pickups"):
		pk.queue_free()
	main.closeup = Vector3.ZERO
	main.closeup_at = null
	await t._wait(0.2)


## The campfire's and every building's health together.
func _structures_hp() -> float:
	var s: float = main.fight.gate_hp
	for id in main.stations.hp:
		s += float(main.stations.hp[id])
	return s


## The leaves lying on the field.
func _leaves_lying() -> int:
	var n := 0
	for p in get_tree().get_nodes_in_group("pickups"):
		if not p.taken and String(p.kind) == "leaf":
			n += int(p.value)
	return n


## How far a structure handle (a building, the campfire, a tower) reaches out from its centre.
func _foot_of(tg) -> float:
	if String(tg.get("kind")) == "fire":
		return 0.75
	for b in main.stations.building_targets():
		if String(b[0]) == String(tg.get("id")):
			return float(b[2])
	return 0.6


# ---------------------------------------------------------------- a boar that misses
func _boar() -> void:
	var info: Dictionary = Data.enemy("boar")
	var miss := float(info.get("miss_daze", 1.0))
	var hurt := float(info.get("daze_hurt", 1.5))
	var cat := Vector3(-1.5, 0, 12.0)                     # open ground south of the camp
	main.player.global_position = cat
	var b = main.fight.spawn("boar", cat + Vector3(-4.5, 0, 0), 0)
	b.hp = 1e6
	b.max_hp = 1e6
	await t._wait(0.2)
	var h0: float = b.hp
	b.hit(Vector3.FORWARD, 10.0)
	_x("a boar on its feet takes plain damage", absf((h0 - b.hp) - 10.0) < 0.05, {"lost": h0 - b.hp})
	b.global_position = cat + Vector3(-4.5, 0, 0)
	b._knock = Vector3.ZERO
	b._cd2 = 0.0
	b._think_t = 0.0
	var wound: bool = await t._until(func(): return b.state == "windup", 2.0)
	if not wound:                                        # the cat was not seen (hidden in grass): wind it up by hand
		b._charge_dir = Vector3(1, 0, 0)
		b.state = "windup"
		b._act_t = 0.0
	main.player.global_position = cat + Vector3(0, 0, 3.0)   # the cat steps aside
	var dazed: bool = await t._until(func(): return b.state == "daze" and b._vuln_t > 0.0, 3.0)
	_x("a boar that misses its charge is dazed (\"Bonk!\")", dazed, {"state": b.state, "wound_up_itself": wound})
	await t._shot("enemyf_boar_bonk")
	h0 = b.hp
	b.hit(Vector3.FORWARD, 10.0)
	_x("a hit on the dazed boar does x%.1f" % hurt, absf((h0 - b.hp) - 10.0 * hurt) < 0.05, {"lost": h0 - b.hp})
	var secs := 0.0
	while b.state == "daze" and secs < 4.0:
		await t._wait(0.1)
		secs += 0.1
	_x("the daze lasts about %.1f s" % miss, secs > miss * 0.5 and secs < miss + 0.5, {"secs": secs})
	_x("the boar tip is shown once (its flag is set)", Save.flag("told_boar_daze"))


# ---------------------------------------------------------------- ranged sieges from afar
func _siege() -> void:
	var bt: Array = main.stations.building_targets()
	if bt.is_empty():
		_x("the camp has buildings to siege", false)
		return
	var pick: Array = bt[0]
	for b in bt:
		if (b[1] as Vector3).length() > (pick[1] as Vector3).length():
			pick = b                                       # the outermost building: nothing else near its far side
	var bpos: Vector3 = pick[1]
	bpos.y = 0.0
	var u := bpos.normalized() if bpos.length() > 0.1 else Vector3.BACK
	for kind in ["pitcher", "frog"]:
		var sr := float(Data.enemy(kind).get("siege_range", 8.0))
		main.player.global_position = -u * 14.0            # far across the camp
		var e = main.fight.spawn(kind, bpos + u * (float(pick[2]) + sr + 1.0), 0)
		e.hp = 1e6
		e.max_hp = 1e6
		var hp0 := _structures_hp()
		var tgt = null
		var stood := -1.0
		var tt := 0.0
		while tt < 10.0:
			await t._wait(0.1)
			tt += 0.1
			if tgt == null and (e.state == "spit" or e.state == "cast") and e._act_target != null and e._act_target != main.player:
				tgt = e._act_target
				var tp: Vector3 = tgt.global_position
				stood = Vector2(e.global_position.x - tp.x, e.global_position.z - tp.z).length() - _foot_of(tgt)
			if tgt != null and _structures_hp() < hp0 - 0.5:
				break
		var from_fire := Vector2(e.global_position.x, e.global_position.z).length()
		var what: String = String(tgt.get("id")) if tgt != null else ""
		_x("a %s stops about %.1f m from a building and shoots it from there" % [kind, sr], tgt != null and stood > sr - 1.0 and stood < sr + 0.3,
			{"stood": stood, "target": what, "building": pick[0]})
		_x("... the building's health goes down", _structures_hp() < hp0 - 0.5, {"before": hp0, "after": _structures_hp(), "secs": tt})
		_x("... out of reach of a cat at the fire", from_fire > Data.cat_range() + 0.5, {"from_fire": from_fire, "cat_range": Data.cat_range()})
		main.closeup_at = e
		main.closeup = Vector3(3.0, 5.0, 7.0)
		await t._wait(0.1)
		await t._shot("enemyf_siege_" + kind)
		await _clear()


# ---------------------------------------------------------------- the Golden Grub
func _grub() -> void:
	var w = main.world
	var base := int(Data.enemy("golden_grub")["leaves"])
	var prior_drop := roundi(base * float(Data.b["mission"]["enemy_leaf_mult"]))
	var leaves := roundi(prior_drop * float(Data.b["kill_leaf_bonus"]))
	main.player.global_position = Vector3(0, 0, 2.5)        # by the fire (it holds its fire)
	var g = main.fight.spawn("golden_grub", w.spawn_point(0, 0.0), 0)
	_x("a Golden Grub is a foe (the cat's auto-aim takes it) and a bonus (no wave waits for it)",
		g.is_in_group("foes") and g.is_in_group("bonus") and main.nearest_enemy(g.global_position, 1.0) == g)
	var start: Vector3 = g.global_position
	var hp0 := _structures_hp()
	var min_r := 99.0
	var tt := 0.0
	while tt < 3.0 and is_instance_valid(g) and not g.dead:
		await t._wait(0.1)
		tt += 0.1
		min_r = minf(min_r, Vector2(g.global_position.x, g.global_position.z).length())
	var ran: float = g.global_position.distance_to(start) if is_instance_valid(g) else 0.0
	_x("it runs out of the woods (%.1f m in 3 s)" % ran, ran > 4.0, {"ran": ran})
	main.closeup_at = g
	main.closeup = Vector3(2.0, 2.6, 4.2)
	await t._wait(0.1)
	await t._shot("enemyf_grub")
	main.closeup_at = null
	main.closeup = Vector3.ZERO
	if is_instance_valid(g) and not g.dead:
		g.life_t = minf(g.life_t, 1.0)                    # its life cut short to keep the test quick
	var gone := false
	tt = 0.0
	while tt < 20.0:
		await t._wait(0.1)
		tt += 0.1
		if not is_instance_valid(g) or g.dead:
			gone = true
			break
		min_r = minf(min_r, Vector2(g.global_position.x, g.global_position.z).length())
	_x("left alone, it gets away into the woods", gone, {"secs": tt})
	_x("it never steps into the firelight", min_r > float(w.camp_r), {"closest": min_r, "camp_r": w.camp_r})
	_x("it hurts nothing", _structures_hp() >= hp0 - 0.01, {"before": hp0, "after": _structures_hp()})
	# caught: its leaves the normal way
	var g2 = main.fight.spawn("golden_grub", w.spawn_point(1, 0.0), 1)
	await t._wait(0.3)
	var before := _leaves_lying()
	g2.hit(Vector3.FORWARD, g2.hp * 10.0 + 100.0)
	await t._wait(0.2)
	_x("caught, it drops its %d leaves" % leaves, _leaves_lying() - before == leaves, {"dropped": _leaves_lying() - before})


# ---------------------------------------------------------------- the Gloom Totem
func _totem() -> void:
	var cfg: Dictionary = Data.b["mission"].get("totem", {})
	var r := float(cfg.get("radius", 4.0))
	var sb := float(cfg.get("speed_buff", 0.25))
	var ar := float(cfg.get("armor", 0.25))
	var w = main.world
	var at: Vector3 = w.trail_point(0, w.trail_length(0) * float(cfg.get("s", 0.35)))
	at.y = 0.0
	main.player.global_position = Vector3(0, 0, 3.0)
	var tot = main.fight.spawn(String(cfg.get("kind", "gloom_totem")), at, 0)
	_x("a Gloom Totem is a foe and a totem (not a bonus)", tot.is_in_group("foes") and tot.is_in_group("totems") and not tot.is_in_group("bonus"))
	var side := Vector3(-at.z, 0, at.x).normalized()
	var near = main.fight.spawn("thornling", at + side * 1.6, 0)
	var far = main.fight.spawn("thornling", at + side * (r + 6.0), 0)
	for e in [near, far]:
		e.set_physics_process(false)                       # they stand still: only the totem's touch changes them
		e.hp = 1000.0
		e.max_hp = 1000.0
	await t._wait(1.2)
	main.closeup_at = tot
	main.closeup = Vector3(3.0, 4.0, 7.5)
	await t._wait(0.1)
	await t._shot("enemyf_totem")
	var kn: float = near._speed_now() / near.speed
	var kf: float = far._speed_now() / far.speed
	_x("a Thornling near the totem is %d%% faster than one far off" % int(round(sb * 100.0)),
		near.totem_t > 0.0 and far.totem_t <= 0.0 and absf(kn - (1.0 + sb)) < 0.01 and absf(kf - 1.0) < 0.01, {"near": kn, "far": kf})
	var h0: float = near.hp
	near.hit(Vector3.FORWARD, 10.0)
	var ln: float = h0 - near.hp
	h0 = far.hp
	far.hit(Vector3.FORWARD, 10.0)
	var lf: float = h0 - far.hp
	_x("... and takes %d%% less damage" % int(round(ar * 100.0)), absf(ln - 10.0 * (1.0 - ar)) < 0.05 and absf(lf - 10.0) < 0.05, {"near": ln, "far": lf})
	_x("the totem never moves", Vector2(tot.global_position.x - at.x, tot.global_position.z - at.z).length() < 0.05,
		{"moved": Vector2(tot.global_position.x - at.x, tot.global_position.z - at.z).length()})
	tot.hit(Vector3.FORWARD, tot.hp * 10.0 + 100.0)
	h0 = near.hp
	near.hit(Vector3.FORWARD, 10.0)
	_x("breaking the totem ends it at once", tot.dead and near.totem_t <= 0.0 and absf(near._speed_now() / near.speed - 1.0) < 0.01
		and absf((h0 - near.hp) - 10.0) < 0.05, {"dead": tot.dead, "totem_t": near.totem_t, "lost": h0 - near.hp})
	main.closeup_at = null
	main.closeup = Vector3.ZERO
