extends Node
## The potions' checks (H3, 26 Nov 2026), run from autotest.gd (`-- --autotest --fresh --feed`) and at the end of `--bag`
## (autotest_bag.gd). Each check logs "EXPECT PASS <what>" or "EXPECT FAIL <what>" through autotest.gd's _expect.
## Every number comes from data (the content entries' effects, balance.json bag.use and potions.hud) and the potions are
## found by what they do, not by name. Time is moved on with the Effects holders' step(), synchronously, so nothing else
## moves meanwhile (the camp's rest, the mount's own mending) and no real 30 s go by.
## Checks:
##   - every effect type in content and bag.use is one the effects list knows (core/effects.gd); an unknown one is not
##   - the Health Potion: refused with none in the Bag and at full health; heals its share over its time (the right whole
##     points, evenly), "Already active" meanwhile, capped at max health
##   - the Mount Health Potion: refused for a standing mount; brings a knocked-out one back with its share (full) and the
##     cat rides it again; Feed and its 2 Sunberries are gone (the owner's Q1)
##   - raw fish and the Golden Carp mend a standing mount at once, ridden or not; Cooked Fish over its time; none of them
##     brings a knocked-out mount back; "The mount is at full health"
##   - with the stall in ruins the Mount Health Potion and fish still work (the mount comes to the cat; nobody rides)
##   - the Damage Potion: Data.arrow_damage() x (1 + mult) for its time, then back; the Speed Potion: Data.cat_speed();
##     both at once: when one ends, the other stays (the full-map rule)
##   - effects pause while the game is frozen; the cat knocked out clears them (Data's shares 0 again), and then a potion
##     is refused ("The cat is down")
##   - the HUD: the Health Potion button shows only while the cat is hurt and the Bag holds one, a real tap uses one, it
##     hides while placing; the Mount Health Potion button takes Ride's place while the mount is knocked out and the Bag
##     holds one, and a real tap brings it back; the running potions line under the currencies (the owner's Q22)
##   - in a mission a knocked-out mount stays out after the wave (no button without a potion), the potion brings it back,
##     and a chapter break still does, as before
## At the end it puts back what it changed: the Bag's counts, the stall, main.frozen, the effects, the cat (its invincible
## too) and the mount, and what the mission's chapter break changed (leaves, timber, the Gloom Raids state, the saved run,
## the tip flags), then saves so the test save matches.

const UsePotion := preload("res://commands/use_potion.gd")

var t                     # autotest.gd (its helpers: _wait, _shot, _expect, _until, _veteran, _tap_at, _reset_fight...)
var main

var _bag0 := {}           # every Bag id's count when the test started (put back at the end)
var _ruined0 := false     # the stall was in ruins when the test started
var _invincible0 := false # the cat's invincible when the test started
var _leaves0 := 0         # Save's leaves, timber, Gloom Raids state, mission run and flags after the set-up (the mission's
var _timber0 := 0         # chapter break pays a chest, may feed the Gloom meter, saves a run and sets tip flags)
var _raids0 := {}
var _run0 := {}
var _flags0 := {}
var _hp_id := ""          # the HUD's potions (balance.json potions.hud)
var _mp_id := ""


func run() -> bool:
	_invincible0 = main.player.invincible
	main.player.invincible = true
	if main.mount == null or int(Save.stations.get("fishing", 0)) < 1:
		t._veteran(6)                                   # the Market (the mount), the garden and the Fishing Spot
	await t._wait(0.6)
	_leaves0 = Save.leaves
	_timber0 = Save.timber
	_raids0 = Save.raids.duplicate(true)
	_run0 = Save.mission_run.duplicate(true)
	_flags0 = Save.flags.duplicate(true)
	main.hud.hide_card()
	main.set_riding(false, false)
	main.player.effects.clear()
	if main.mount != null:
		main.mount.effects.clear()
		main.mount.refill()
	for id in Bag.ids():
		_bag0[id] = Bag.count(id)
	_ruined0 = Save.ruined.has("stall")
	_hp_id = Effects.hud_potion("cat")
	_mp_id = Effects.hud_potion("mount")
	var ok: bool = t._expect("the potions test has a cat potion, a mount potion and a mount", _hp_id != "" and _mp_id != "" and main.mount != null,
		{"cat": _hp_id, "mount": _mp_id})
	if main.mount == null:
		_restore()
		return false
	ok = _check_known() and ok
	ok = _check_health() and ok
	ok = await _check_revive() and ok
	ok = _check_menders() and ok
	ok = _check_ruins() and ok
	ok = _check_stats() and ok
	ok = await _check_pause() and ok
	ok = await _check_knockout() and ok
	ok = await _check_hud() and ok
	ok = await _check_mission() and ok
	_restore()
	return ok


# ---------------------------------------------------------------- the effects list
func _check_known() -> bool:
	var types := {}
	for id in Bag.ids():
		for e: Variant in Bag.effects(id):
			if e is Dictionary:
				types[String((e as Dictionary).get("type", ""))] = true
	var all_known: bool = (types.keys() as Array).all(func(k): return Effects.known(String(k)))
	return t._expect("every effect type in content and bag.use is one the effects list knows", not types.is_empty() and all_known
		and not Effects.known("no_such_effect"), {"types": types.keys()})


# ---------------------------------------------------------------- the Health Potion
func _check_health() -> bool:
	var p = main.player
	var id := _hp_id
	var cmd = UsePotion.new(id)
	var mx := Data.cat_max_hp()
	var e := _eff(id, "heal_over_time")
	var share := float(e.get("share", 0.0))
	var secs := float(e.get("seconds", 0.0))
	var total := maxi(1, roundi(float(mx) * share))
	_bag_to(id, 0)
	p.hp = 1
	var ok: bool = t._expect("a Health Potion: none in the Bag is refused", cmd.can_run(main) == "None in the Bag" and not cmd.run(main))
	_bag_to(id, 2)
	p.hp = mx
	ok = t._expect("a Health Potion is refused at full health, and none is used", cmd.can_run(main) == "Full health" and not cmd.run(main)
		and Bag.count(id) == 2) and ok
	p.hp = 1
	var ran: bool = cmd.run(main)
	var again: String = cmd.can_run(main)
	p.effects.step(secs * 0.5)
	var half: int = p.hp
	p.effects.step(secs * 0.5)
	var whole: int = p.hp
	p.effects.step(1.0)
	ok = t._expect("a Health Potion heals %.0f%% of %d (%d points) evenly over %.0f s, one used, \"Already active\" meanwhile" % [share * 100.0, mx, total, secs],
		ran and again == "Already active" and half == mini(1 + floori(float(total) * 0.5 + 0.0001), mx) and whole == mini(1 + total, mx)
		and p.hp == whole and not p.effects.has_source(id) and Bag.count(id) == 1,
		{"half": half, "whole": whole, "total": total, "again": again, "left": Bag.count(id)}) and ok
	p.hp = mx - 1
	ran = cmd.run(main)
	p.effects.step(secs + 1.0)
	ok = t._expect("a Health Potion never heals past max health", ran and p.hp == mx and Bag.count(id) == 0, {"hp": p.hp, "max": mx}) and ok
	return ok


# ---------------------------------------------------------------- the Mount Health Potion (the owner's Q1: it replaces Feed)
func _check_revive() -> bool:
	var m = main.mount
	var id := _mp_id
	var cmd = UsePotion.new(id)
	m.refill()
	main.set_riding(false, false)
	_bag_to(id, 1)
	_bag_to("berries", 4)
	var ok: bool = t._expect("a Mount Health Potion is refused for a standing mount", cmd.can_run(main) == "Only for a knocked-out mount"
		and not cmd.run(main) and Bag.count(id) == 1)
	m.hurt(99999, m.global_position)
	var out: bool = m.resting > 0.0
	var share := float(_eff(id, "revive").get("share", 0.0))
	var want := clampi(roundi(float(m.max_hp()) * share), 1, maxi(1, m.max_hp()))
	var ran: bool = cmd.run(main)
	await t._wait(0.5)
	ok = t._expect("a Mount Health Potion brings a knocked-out mount back with %.0f%% of its health (%d of %d) and the cat rides it" % [share * 100.0, want, m.max_hp()],
		out and ran and m.resting <= 0.0 and m.hp == want and main.player.riding and Bag.count(id) == 0,
		{"hp": m.hp, "want": want, "riding": main.player.riding, "left": Bag.count(id)}) and ok
	ok = t._expect("Feed is gone: no Feed on main, the Sunberries stay in the Bag", not main.has_method("feed_mount") and not main.has_method("can_feed")
		and not main.has_method("feed_text") and Bag.count("berries") == 4) and ok
	main.set_riding(false, false)
	return ok


# ---------------------------------------------------------------- raw fish, the Golden Carp, Cooked Fish (Q26 a)
func _check_menders() -> bool:
	var m = main.mount
	var ok := true
	var menders := _all_with("heal", "mount")
	ok = t._expect("there are things that mend the mount at once (raw fish, the Golden Carp)", menders.size() >= 2, {"ids": menders}) and ok
	var first := true
	for id in menders:
		var cmd = UsePotion.new(id)
		var share := float(_eff(id, "heal").get("share", 0.0))
		m.refill()
		main.set_riding(first, false)                       # the first one while ridden, the rest not
		_bag_to(id, 1)
		var full_why: String = cmd.can_run(main)
		m.hp = 1
		var pts := maxi(1, roundi(float(m.max_hp()) * share))
		var used: bool = cmd.run(main)
		ok = t._expect("%s mends the mount by %.0f%% at once (%d points)%s; refused at full health" % [Bag.name_of(id, 1), share * 100.0, pts,
			" while ridden" if first else ""], full_why == "The mount is at full health" and used and m.hp == mini(1 + pts, m.max_hp())
			and Bag.count(id) == 0, {"hp": m.hp, "why": full_why}) and ok
		main.set_riding(false, false)
		_bag_to(id, 1)
		m.hurt(99999, m.global_position)
		var why: String = cmd.can_run(main)
		ok = t._expect("%s does not bring a knocked-out mount back" % Bag.name_of(id, 1), why.begins_with("Knocked out") and not cmd.run(main)
			and m.resting > 0.0 and Bag.count(id) == 1, {"why": why}) and ok
		_bag_to(id, 0)
		first = false
	# Cooked Fish: to full over its time
	var cf := _with("heal_over_time", "mount")
	m.refill()
	var e := _eff(cf, "heal_over_time")
	var secs := float(e.get("seconds", 0.0))
	var total := maxi(1, roundi(float(m.max_hp()) * float(e.get("share", 0.0))))
	var ccmd = UsePotion.new(cf)
	_bag_to(cf, 2)
	m.hp = 1
	var ran: bool = ccmd.run(main)
	var again: String = ccmd.can_run(main)
	m.effects.step(secs * 0.5)
	var half: int = m.hp
	m.effects.step(secs * 0.5 + 0.5)
	ok = t._expect("%s mends the mount over %.0f s (%d points, to full), \"Already active\" meanwhile" % [Bag.name_of(cf, 1), secs, total], cf != ""
		and ran and again == "Already active" and half == mini(1 + floori(float(total) * 0.5 + 0.0001), m.max_hp())
		and m.hp == mini(1 + total, m.max_hp()) and Bag.count(cf) == 1, {"half": half, "hp": m.hp, "total": total, "again": again}) and ok
	m.hurt(99999, m.global_position)
	var cwhy: String = ccmd.can_run(main)
	ok = t._expect("%s does not bring a knocked-out mount back either" % Bag.name_of(cf, 1), cwhy.begins_with("Knocked out")
		and not ccmd.run(main) and Bag.count(cf) == 1, {"why": cwhy}) and ok
	_bag_to(cf, 0)
	m.refill()
	return ok


# ---------------------------------------------------------------- the stall in ruins: every mount effect still works
func _check_ruins() -> bool:
	var m = main.mount
	var p = main.player
	if not Save.ruined.has("stall"):
		Save.ruined.append("stall")
	main.set_riding(false, false)
	p.global_position = _out()
	m.refill()
	m.hurt(99999, m.global_position)
	_bag_to(_mp_id, 1)
	var ran: bool = UsePotion.new(_mp_id).run(main)
	var near: float = Vector2(m.global_position.x - p.global_position.x, m.global_position.z - p.global_position.z).length()
	var ok: bool = t._expect("with the stall in ruins a Mount Health Potion still works: up, at the cat, nobody rides", ran and m.resting <= 0.0
		and near < 0.5 and not p.riding and Bag.count(_mp_id) == 0, {"near": near, "riding": p.riding})
	var fish := _with("heal", "mount")
	_bag_to(fish, 1)
	m.hp = 1
	ran = UsePotion.new(fish).run(main)
	ok = t._expect("with the stall in ruins %s still mends the mount" % Bag.name_of(fish, 1), ran and m.hp > 1 and Bag.count(fish) == 0,
		{"hp": m.hp}) and ok
	if not _ruined0:
		Save.ruined.erase("stall")
	m.refill()
	return ok


# ---------------------------------------------------------------- the Damage and Speed Potions
func _check_stats() -> bool:
	var p = main.player
	var dmg := _with("stat_mult", "cat", "damage")
	var spd := _with("stat_mult", "cat", "speed")
	var ed := _eff(dmg, "stat_mult")
	var es := _eff(spd, "stat_mult")
	var md := float(ed.get("mult", 0.0))
	var ms := float(es.get("mult", 0.0))
	var sd := float(ed.get("seconds", 0.0))
	var ss := float(es.get("seconds", 0.0))
	var base_d := Data.arrow_damage()
	var base_s := Data.cat_speed()
	var ok: bool = t._expect("there is a Damage Potion and a Speed Potion", dmg != "" and spd != "" and md > 0.0 and ms > 0.0, {"damage": dmg, "speed": spd})
	# the Damage Potion
	_bag_to(dmg, 2)
	var ran: bool = UsePotion.new(dmg).run(main)
	var again: String = UsePotion.new(dmg).can_run(main)
	var on := Data.arrow_damage()
	p.effects.step(sd - 0.5)
	var still := Data.arrow_damage()
	p.effects.step(1.0)
	ok = t._expect("the Damage Potion: arrows x%.2f for %.0f s, then back; \"Already active\" meanwhile" % [1.0 + md, sd], ran and again == "Already active"
		and is_equal_approx(on, base_d * (1.0 + md)) and is_equal_approx(still, on) and is_equal_approx(Data.arrow_damage(), base_d),
		{"base": base_d, "on": on, "still": still, "after": Data.arrow_damage()}) and ok
	# the Speed Potion
	_bag_to(spd, 2)
	ran = UsePotion.new(spd).run(main)
	var s_on := Data.cat_speed()
	p.effects.step(ss - 0.5)
	var s_still := Data.cat_speed()
	p.effects.step(1.0)
	ok = t._expect("the Speed Potion: the cat x%.2f for %.0f s, then back" % [1.0 + ms, ss], ran and is_equal_approx(s_on, base_s * (1.0 + ms))
		and is_equal_approx(s_still, s_on) and is_equal_approx(Data.cat_speed(), base_s), {"base": base_s, "on": s_on, "after": Data.cat_speed()}) and ok
	# both at once: the shorter ends, the longer stays (the holder hands Data the full map)
	_bag_to(dmg, 1)
	_bag_to(spd, 1)
	var both: bool = UsePotion.new(dmg).run(main) and UsePotion.new(spd).run(main)
	var both_on: bool = is_equal_approx(Data.effect_mult("damage"), md) and is_equal_approx(Data.effect_mult("speed"), ms)
	p.effects.step(minf(sd, ss) + 0.1)
	var short_stat := "damage" if sd < ss else "speed"
	var long_stat := "speed" if sd < ss else "damage"
	var long_mult := ms if sd < ss else md
	var kept: bool = sd == ss or (is_zero_approx(Data.effect_mult(short_stat)) and is_equal_approx(Data.effect_mult(long_stat), long_mult))
	p.effects.step(absf(sd - ss) + 0.5)
	ok = t._expect("both at once: when the %s ends, the %s stays, then it ends too" % [short_stat, long_stat], both and both_on and kept
		and is_zero_approx(Data.effect_mult("damage")) and is_zero_approx(Data.effect_mult("speed")) and p.effects.active().is_empty(),
		{"both_on": both_on, "kept": kept}) and ok
	_bag_to(dmg, 0)
	_bag_to(spd, 0)
	return ok


# ---------------------------------------------------------------- paused with the game; cleared when the cat is knocked out
func _check_pause() -> bool:
	var p = main.player
	var dmg := _with("stat_mult", "cat", "damage")
	_bag_to(dmg, 1)
	var ran: bool = UsePotion.new(dmg).run(main)
	main.frozen = true
	var l0: float = p.effects.left(dmg)
	await t._wait(0.5)
	var l1: float = p.effects.left(dmg)
	main.frozen = false
	await t._wait(0.5)
	var l2: float = p.effects.left(dmg)
	p.effects.clear()
	return t._expect("a running potion pauses while the game is frozen, and runs on after", ran and is_equal_approx(l0, l1) and l2 < l1 - 0.2,
		{"left": [l0, l1, l2]})


func _check_knockout() -> bool:
	var p = main.player
	var dmg := _with("stat_mult", "cat", "damage")
	var spd := _with("stat_mult", "cat", "speed")
	var base_d := Data.arrow_damage()
	main.set_riding(false, false)
	_bag_to(dmg, 1)
	_bag_to(spd, 1)
	var both: bool = UsePotion.new(dmg).run(main) and UsePotion.new(spd).run(main)
	var at := _out()
	p.global_position = at
	p.invincible = false
	p._invuln = 0.0
	p.hurt(at + Vector3(1, 0, 0), 99999)
	var down: bool = p.hp <= 0
	_bag_to(_hp_id, 1)
	var why: String = UsePotion.new(_hp_id).can_run(main)
	var ok: bool = t._expect("the cat knocked out: its potions end and Data's Damage and Speed are back to 0; then a potion is refused",
		both and down and p.effects.active().is_empty() and is_zero_approx(Data.effect_mult("damage")) and is_zero_approx(Data.effect_mult("speed"))
		and is_equal_approx(Data.arrow_damage(), base_d) and why == "The cat is down", {"hp": p.hp, "why": why})
	p.invincible = true
	main._respawn_t = 0.0
	p.revive(at)
	_bag_to(_hp_id, 0)
	await t._wait(0.3)
	return ok


# ---------------------------------------------------------------- the HUD's potion buttons and line
func _check_hud() -> bool:
	var p = main.player
	var m = main.mount
	var hud = main.hud
	var acts = hud.p_actions
	var pot: Button = acts.potion_button
	var mpot: Button = acts.mount_potion_button
	var mx := Data.cat_max_hp()
	main.set_riding(false, false)
	m.refill()
	p.global_position = _out()                              # out of the camp: the cat does not rest back to full there
	_bag_to(_hp_id, 0)
	p.hp = 1
	await t._wait(0.4)
	var ok: bool = t._expect("hurt with no Health Potion in the Bag: no potion button", not _shown(pot))
	_bag_to(_hp_id, 1)
	p.hp = mx
	await t._wait(0.4)
	ok = t._expect("a Health Potion in the Bag at full health: no potion button", not _shown(pot)) and ok
	p.hp = 1
	await t._wait(0.4)
	ok = t._expect("hurt with one in the Bag: the Health Potion button shows at the bottom right, its count", _shown(pot) and not pot.disabled
		and pot.get_global_rect().position.x > _view().x * 0.6 and pot.get_global_rect().position.y > _view().y * 0.8
		and String(pot.get_meta("label", "")) == "%s ×1" % Data.item_name(_hp_id, 1) and pot.text == "×1",
		{"label": pot.get_meta("label", ""), "rect": pot.get_global_rect()}) and ok
	await t._shot("potions_cat_button")
	await t._tap_at(pot.get_global_rect().get_center())
	await t._wait(0.3)
	ok = t._expect("a real tap on it uses one: the potion runs, the Bag is empty, the button goes", Bag.count(_hp_id) == 0
		and p.effects.has_source(_hp_id) and not _shown(pot), {"left": Bag.count(_hp_id)}) and ok
	p.effects.clear()
	# placing hides it (Done reaches into its slot)
	var tower0 := Bag.count("tower")
	_bag_to("tower", 1)
	_bag_to(_hp_id, 1)
	p.hp = 1
	await t._wait(0.3)
	main.defences.start_placing("tower")
	await t._wait(0.4)
	var hidden_placing := not _shown(pot)
	main.defences.stop_placing()
	await t._wait(0.4)
	ok = t._expect("the Health Potion button hides while placing and comes back after", main.defences.placing == "" and hidden_placing and _shown(pot)) and ok
	_bag_to("tower", tower0)
	_bag_to(_hp_id, 0)
	p.hp = mx
	# the Mount Health Potion in Ride's place
	_bag_to(_mp_id, 0)
	m.hurt(99999, m.global_position)
	await t._wait(0.4)
	var feed := false
	for b in hud.build_buttons():
		if String(b.get_meta("label", "")).begins_with("Feed"):
			feed = true
	ok = t._expect("the mount knocked out with no potion: no button in row 2 (no Feed, no Ride)", not _shown(mpot) and not _shown(acts.ride_button)
		and not feed) and ok
	_bag_to(_mp_id, 1)
	await t._wait(0.4)
	ok = t._expect("with a Mount Health Potion in the Bag its button takes Ride's place", _shown(mpot) and not mpot.disabled and not _shown(acts.ride_button)
		and mpot.get_global_rect().position.x > _view().x * 0.6 and String(mpot.get_meta("label", "")) == "%s ×1" % Data.item_name(_mp_id, 1),
		{"label": mpot.get_meta("label", ""), "rect": mpot.get_global_rect()}) and ok
	await t._shot("potions_mount_button")
	var want := clampi(roundi(float(m.max_hp()) * float(_eff(_mp_id, "revive").get("share", 0.0))), 1, maxi(1, m.max_hp()))
	await t._tap_at(mpot.get_global_rect().get_center())
	await t._wait(0.5)
	ok = t._expect("a real tap on it brings the mount back and the cat rides; Ride is back in its place", m.resting <= 0.0 and m.hp == want
		and p.riding and Bag.count(_mp_id) == 0 and not _shown(mpot) and _shown(acts.ride_button), {"hp": m.hp, "want": want, "riding": p.riding}) and ok
	main.set_riding(false, false)
	# the running potions line (the owner's Q22)
	var dmg := _with("stat_mult", "cat", "damage")
	var ed := _eff(dmg, "stat_mult")
	var stat_name := String((Data.b["stats"] as Dictionary).get(String(ed.get("stat", "")), {}).get("name", ""))
	_bag_to(dmg, 1)
	var ran: bool = UsePotion.new(dmg).run(main)
	await t._wait(0.3)
	var line: String = hud._meal_l.text
	ok = t._expect("a running Damage Potion shows under the currencies (\"%s +%d%% · N s\")" % [stat_name, roundi(float(ed.get("mult", 0.0)) * 100.0)],
		ran and hud._meal_l.is_visible_in_tree() and line.begins_with("%s +%d%% · " % [stat_name, roundi(float(ed.get("mult", 0.0)) * 100.0)])
		and line.ends_with(" s"), {"line": line}) and ok
	await t._shot("potions_line")
	p.effects.clear()
	await t._wait(0.2)
	ok = t._expect("the potions line hides when none runs", not hud._meal_l.visible) and ok
	return ok


# ---------------------------------------------------------------- in a mission (the old --feed checks, per Q1)
func _check_mission() -> bool:
	var m = main.mount
	var p = main.player
	var hud = main.hud
	var acts = hud.p_actions
	var mpot: Button = acts.mount_potion_button
	_bag_to(_mp_id, 0)
	main.set_riding(false, false)
	m.refill()
	main.player.global_position = Vector3(0, 0, 1.6)
	main.start_stage(1)
	await t._wait(0.5)
	if not t._expect("a mission starts (a replay of raid 2)", main.fight.active, {"active": main.fight.active}):
		return false
	main.fight.set_physics_process(false)
	await t._clear_test_foes()
	p.global_position = Vector3(0, 0, 8.0)
	main.set_riding(true, false)
	await t._wait(0.5)
	m.hurt(999, p.global_position)
	await t._wait(0.3)
	var ok: bool = t._expect("in a mission: knocked out, the cat is off the mount", m.resting > 0.0 and not p.riding, {"resting": m.resting})
	main.fight._queue.clear()
	main.fight.set_physics_process(true)
	var cleared: bool = await t._until(func(): return not main.fight.in_wave, 3.0)
	await t._wait(1.0)
	ok = t._expect("the wave cleared and the mount is still out; with no potion there is no button", cleared and m.resting > 0.0 and not _shown(mpot),
		{"resting": m.resting, "in_wave": main.fight.in_wave}) and ok
	_bag_to(_mp_id, 1)
	await t._wait(0.3)
	ok = t._expect("a Mount Health Potion in the Bag: its button shows", _shown(mpot) and not mpot.disabled) and ok
	mpot.pressed.emit()
	await t._wait(0.6)
	ok = t._expect("its button brings it back and the cat rides again", m.resting <= 0.0 and p.riding and Bag.count(_mp_id) == 0,
		{"resting": m.resting, "riding": p.riding}) and ok
	m.hurt(999, p.global_position)
	await t._wait(0.3)
	main.fight._chapter_done(0)
	await t._wait(0.5)
	ok = t._expect("out again with no potion: a chapter break still brings it back whole", m.resting <= 0.0 and m.hp == m.max_hp()
		and _shown(acts.ride_button), {"resting": m.resting}) and ok
	await t._shot("potions_chapter_break")
	t._reset_fight()
	return ok


# ---------------------------------------------------------------- helpers
## Puts back what the test changed.
func _restore() -> void:
	main.frozen = false
	main.player.effects.clear()
	Data.set_effect_mults({})
	if main.mount != null:
		main.mount.effects.clear()
		main.mount.refill()
	if not _ruined0:
		Save.ruined.erase("stall")
	for id: String in _bag0:
		_bag_to(id, int(_bag0[id]))
	# the mission's chapter break: its chest, the Gloom meter, the saved run (none stays in the test save) and the tips
	Save.leaves = _leaves0
	Save.timber = _timber0
	Save.raids.clear()
	Save.raids.merge(_raids0.duplicate(true))
	Save.mission_run = _run0.duplicate(true)
	Save.flags.clear()
	Save.flags.merge(_flags0.duplicate(true))
	main.player.invincible = _invincible0
	main.player.hp = Data.cat_max_hp()
	main.set_riding(false, false)
	main.player.global_position = Vector3(0, 0, 1.6)        # back in the camp
	main.hud.refresh_build()
	Save.save_game()                                        # the file matches what was put back


## The Bag holds exactly n of id (taken out or put in by force).
func _bag_to(id: String, n: int) -> void:
	if id == "":
		return
	var have := Bag.count(id)
	if have > n:
		Bag.take(id, have - n)
	elif have < n:
		Bag.add(id, n - have, true)


## id's first effect of this type (its content entry, or balance.json bag.use), {} when none.
func _eff(id: String, type: String) -> Dictionary:
	for e: Variant in Bag.effects(id):
		if e is Dictionary and String((e as Dictionary).get("type", "")) == type:
			return e as Dictionary
	return {}


## Every Bag id with an effect of this type on this target (and this stat), in the Bag's order.
func _all_with(type: String, target: String, stat := "") -> Array[String]:
	var out: Array[String] = []
	for id in Bag.ids():
		for e: Variant in Bag.effects(id):
			if not e is Dictionary:
				continue
			var d := e as Dictionary
			if String(d.get("type", "")) == type and String(d.get("target", "cat")) == target and (stat == "" or String(d.get("stat", "")) == stat):
				out.append(id)
				break
	return out


## The first of them, "" when none.
func _with(type: String, target: String, stat := "") -> String:
	var all := _all_with(type, target, stat)
	return all[0] if not all.is_empty() else ""


## A spot on the first trail just outside the camp (the camp's rest does not heal the cat there, and it can be hurt).
func _out() -> Vector3:
	return main.world.patch_dir(0) * (main.world.camp_r + 2.5)


## The button is in, or sliding in, at the bottom (the HUD's own list).
func _shown(b: Button) -> bool:
	return main.hud.build_buttons().has(b)


## The view in HUD pixels.
func _view() -> Vector2:
	return main.hud.get_viewport().get_visible_rect().size
