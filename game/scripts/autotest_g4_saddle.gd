extends Node
## Phase G4: the Saddlery, the mount's skills and attachments (`-- --autotest --fresh --saddlery`), run from autotest.gd.
## Each check logs "EXPECT PASS <what>" or "EXPECT FAIL <what>" through autotest.gd's _expect. Light on purpose: every
## number comes from balance.json; a fight being on is faked by hand (fight.active, in_wave and on_break, so no wave
## runs); the foes stand still; the cat's own _process is stopped while the moves are tried (no arrows muddy the hits).
##   (a) the building: Locked ("Finish 8 Raid Missions first") before raid 8; after it, Locked at Hearthtree 1 ("Needs the
##       Hearthtree at level 2", since 21 Nov 2026); then Build pays its price
##   (w) H5: its window, through real taps (autotest_saddle_window.gd): the two bottom tabs, the attachments' pictures and
##       the turning detail (Buy, Wear, Upgrade), the skill circles (a real drag, replace, move, clear, refusals), a
##       skill's detail (Learn), the Upgrade confirm (the next cap, the mount's speed and health; back on Skills)
##   (b) Buy Stomp, Upgrade, the Saddlery's level as the cap, level 4 only after the Raid Missions (H1: its price is leaves and timber), Max
##   (c) no built-in move: riding with nothing learned does nothing in a fight; H5: a learned skill outside the three
##       circles never goes (neither by itself nor through try_move), and the circles stay through a look change and a reload
##   (d) each skill by try_move (each put in a circle first, H5): Stomp, Ram, Pounce, Bellow; never two moves in the same moment
##   (e) attachments: Mossweave Saddle health, Saddlebags leaves, Fire-spitter burns; their models on the saddle bone
##       only when the files exist (none yet: nothing attached, nothing errors), the flames from the nozzle if any
##   (f) an old save (no "saddlery" key) is brought over once
## H5 (27 Nov 2026): the Saddlery's attachments a player owns are Save.owned["attachments"][id] = {"level": n} (the v5
## save); the skills stay Save.saddlery "skills", the circles are Save.saddlery "skill_slots".

var t                     # autotest.gd (its helpers: _wait, _expect, _until, _log)
var main

const BASE := Vector3(-1.5, 0, 12.0)                # open ground south of the camp
const SKILLS := ["stomp", "ram", "pounce", "bellow"]
const GEAR := ["fire_spitter", "saddle", "saddlebags"]
const LINES := {
	"stomp": "Shockwave every 4 s: 20 damage",
	"ram": "Charges ahead every 7 s: 35 damage",
	"pounce": "Leaps on a group every 9 s: 40 damage, 1 s stun",
	"bellow": "4+ enemies near: 1.5 s stun, +20% damage taken",
	"fire_spitter": "Cat's firing pace: 8 splash damage in 1.3 m, +8 burn/s for 2 s",
	"saddle": "has +15% health",
	"saddlebags": "When worn: kills drop +5% leaves",
}


func run() -> bool:
	main.player.invincible = true
	_start_fresh(7)
	await t._wait(0.3)
	if Data.args().has("--rideshots") or Data.args().has("--rideclear"):   # only the riding pictures (g) or the sweep (h)
		_start_fresh(8)
		Save.stations["saddlery"] = 1
		main.refresh_companions()
		await t._wait(0.5)
		if Data.args().has("--rideclear"):
			await _clear_sweep(true)
		else:
			await _ride_shots()
		_start_fresh(1)
		t._log("ride shots done")
		return true
	_building()
	await _window()
	_start_fresh(8)
	Save.stations["saddlery"] = 1
	_st().refresh()
	_buy()
	await _ride()
	await _no_builtin()
	await _unslotted()
	await _stomp()
	await _ram()
	await _pounce()
	await _bellow()
	await _gap()
	await _attach()
	await _fireballs()
	await _ground_fire()
	await _fire_tracking()
	_clear()
	_fight(false)
	main.player.set_process(true)
	main.set_riding(false, false)
	await _migrate()
	main.hud.hide_card()
	_start_fresh(1)
	t._log("saddlery done")
	return true


func _x(what: String, ok: bool, extra := {}) -> bool:
	return t._expect(what, ok, extra)


func _st():
	return main.stations


## A camp with `won` missions won, the Market (Thistle) but no Saddlery yet, nothing learned, no leaves.
func _start_fresh(won: int) -> void:
	Save.missions_done = []
	for i in won:
		Save.missions_done.append(String(Data.mission(i)["id"]))
	Save.mission_run = {}
	Save.camp_level = 5
	for k in Save.stations:
		Save.stations[k] = 0
	Save.stations["bench"] = 1
	Save.stations["stall"] = 1
	Save.saddlery = {"skills": {}, "skill_slots": ["", "", ""], "worn": "", "mount_credit": 0}   # H5: the v5 shape
	_no_gear()
	Save.attach = {"owned": [], "mount": "", "pet": ""}
	Save.ruined = []
	Save.wear = {}
	Save.fire_ruined = false
	Save.leaves = 0
	Save.timber = 0
	Save.flags.erase("hollow_open")
	for k in ["shop_open", "shop_target", "shop_bench", "home", "first_stage_done"]:
		Save.set_flag(k)
	_st().refresh()


## H5: what the Saddlery's window says of one skill or attachment now (saddlery_window.gd entry: its level, state, the
## one action and its word, why it can't go further).
func _tile(part: String, id: String) -> Dictionary:
	return main.hud.windows["saddlery"].entry(part, id)


func _build_entry(id: String) -> Dictionary:
	for e: Dictionary in main.hud.windows["build"].entries():
		if String(e["id"]) == id:
			return e
	return {}


# ---------------------------------------------------------------- H5: the v5 save's owned attachments and the circles
## Save.owned (the v5 save; read through get so this file never names a field the save does not have).
func _owned() -> Dictionary:
	var o: Variant = Save.get("owned")
	return o if o is Dictionary else {}


## The Saddlery attachment id owned at level lv (0: not owned): Save.owned["attachments"][id] = {"level": lv}.
func _gear(id: String, lv: int) -> void:
	var o := _owned()
	if not o.get("attachments") is Dictionary:
		o["attachments"] = {}
	var shelf: Dictionary = o["attachments"]
	if lv <= 0:
		shelf.erase(id)
	else:
		shelf[id] = {"level": lv}


## No attachment owned at all (the expedition gear's records too: this file never buys them).
func _no_gear() -> void:
	_owned()["attachments"] = {}


## The mount's three circles hold these skills (in order; the rest empty).
func _slots(ids: Array) -> void:
	var out: Array = []
	for i in 3:
		out.append(String(ids[i]) if i < ids.size() else "")
	Save.saddlery["skill_slots"] = out


## Skill id learned at level lv and put in the first circle (the combat checks below use one skill at a time).
func _learn(id: String, lv: int) -> void:
	Save.saddlery["skills"][id] = lv
	_slots([id])


## The skill forgotten and the circles emptied.
func _forget(id: String) -> void:
	Save.saddlery["skills"].erase(id)
	_slots([])


func _fight(on: bool) -> void:
	var f = main.fight
	f.active = on
	f.in_wave = on
	f.on_break = on
	f.set_physics_process(not on)                     # these tests fake combat; do not run or pay an actual wave


# ---------------------------------------------------------------- (a) the building
func _building() -> void:
	var st = _st()
	var entry := _build_entry("saddlery")
	_x("before raid 8: the Saddlery is locked in the build menu ('Finish 8 Raid Missions first')",
		String(entry.get("state", "")) == "locked" and String(entry.get("needs", "")) == "Finish 8 Raid Missions first", {"entry": entry})
	var build: Dictionary = Data.build_price("saddlery")
	Save.leaves = 100000
	Save.timber = 1000
	st._build_station("saddlery")
	_x("before raid 8 it cannot be built", int(Save.stations["saddlery"]) == 0 and Save.leaves == 100000)
	_start_fresh(8)
	# 21 Nov 2026: it needs the Hearthtree at level 2 too (stations.saddlery.needs_home)
	var nh := Data.station_needs_home("saddlery")
	Save.camp_level = 1
	Save.leaves = 100000
	Save.timber = 1000
	entry = _build_entry("saddlery")
	var need_txt := "Needs %s at level %d" % [Data.camp_name(), nh]
	_x("8 raids won at Hearthtree 1: the Saddlery is locked ('%s')" % need_txt,
		nh == 2 and String(entry.get("state", "")) == "locked" and String(entry.get("needs", "")) == need_txt, {"entry": entry})
	st._build_station("saddlery")
	_x("at Hearthtree 1 it cannot be built", int(Save.stations["saddlery"]) == 0 and Save.leaves == 100000)
	Save.camp_level = 5
	Save.leaves = int(build["leaves"]) + 123
	Save.timber = int(build["timber"]) + 7
	entry = _build_entry("saddlery")
	_x("after 8 raids the Saddlery is open in the build menu with its price",
		String(entry.get("state", "")) == "open" and entry.get("price", {}) == build, {"entry": entry})
	st._build_station("saddlery")
	_x("Build pays its price and the Saddlery is level 1", int(Save.stations["saddlery"]) == 1 and Save.leaves == 123 and Save.timber == 7,
		{"leaves": Save.leaves, "timber": Save.timber})
	_x("its ring is in the camp", st.rings.has("saddlery") and st.rings["saddlery"] != null)
	# H5: the window's own checks (tabs, pictures, details, circles, the confirm) are in autotest_saddle_window.gd (_window)
	var w = main.hud.windows["saddlery"]
	var names: Array = []
	for tab in ["attachments", "skills"]:
		for e: Dictionary in w.entries(tab):
			names.append(String(e["name"]))
	_x("its two tabs list the attachments, then the skills, in order: Fire-spitter, Mossweave Saddle, Saddlebags, Stomp, Ram, Pounce, Bellow",
		names == ["Fire-spitter", "Mossweave Saddle", "Saddlebags", "Stomp", "Ram", "Pounce", "Bellow"], {"names": names})
	var ok := true
	var seen := {}
	for id in SKILLS:
		var r := _tile("skills", id)
		var note: String = st._saddle_note("skills", id, 1)
		seen[id] = [r.get("label", ""), r.get("state", ""), note]
		ok = ok and String(r.get("label", "")) == "Learn" and String(r.get("state", "")) == "new" and note.begins_with(String(LINES[id]))
	for id in GEAR:
		var r := _tile("attach", id)
		var note: String = st._saddle_note("attach", id, 1)
		seen[id] = [r.get("label", ""), r.get("state", ""), note]
		ok = ok and String(r.get("label", "")) == "Buy" and String(r.get("state", "")) == "new" and note.contains(String(LINES[id]))
	_x("every skill new with Learn, every attachment new with Buy, and each its level-1 line", ok, seen)


# ---------------------------------------------------------------- (w) H5: the window, through real taps
## The Saddlery's window (autotest_saddle_window.gd: its own file, so this one does not grow): its tabs, details, circles
## and confirm, with screenshots. It starts from the camp _building() left (the Saddlery built at level 1).
func _window() -> void:
	var path := "res://scripts/autotest_saddle_window.gd"
	if not ResourceLoader.exists(path):
		_x("the window checks' file %s is there" % path, false)
		return
	var w = load(path).new()
	w.t = t
	w.main = main
	w.g4 = self
	add_child(w)
	await w.run()
	w.queue_free()


# ---------------------------------------------------------------- (b) Buy, Upgrade, the caps
func _buy() -> void:
	var st = _st()
	var p1 := Data.saddle_price("skills", "stomp", 1)
	Save.leaves = int(p1["leaves"]) + 77
	Save.timber = int(p1["timber"]) + 3
	st._saddle_buy("skills", "stomp")
	_x("Buy Stomp: level 1, exactly its leaves and timber taken", Data.skill_level("stomp") == 1 and Save.leaves == 77 and Save.timber == 3,
		{"level": Data.skill_level("stomp"), "leaves": Save.leaves, "timber": Save.timber})
	var tl := _tile("skills", "stomp")
	_x("Stomp is now level 1 of 5, learned (not in a circle: a new skill goes into the grid), its button Upgrade",
		int(tl.get("level", 0)) == 1 and int(tl.get("top", 0)) == 5 and String(tl.get("state", "")) == "learned"
		and String(tl.get("label", "")) == "Upgrade" and not Data.skill_is_slotted("stomp"), tl)
	# capped by the Saddlery (level 1)
	Save.leaves = 1000000
	Save.timber = 100000
	_x("at Saddlery level 1: Stomp level 2 is blocked 'cap'", Data.saddle_block("skills", "stomp") == "cap")
	st._saddle_buy("skills", "stomp")
	tl = _tile("skills", "stomp")
	_x("Upgrade past the Saddlery's level does nothing; its detail says 'Upgrade the Saddlery for more'", Data.skill_level("stomp") == 1 and Save.leaves == 1000000
		and not bool(tl.get("can", true)) and String(tl.get("why", "")) == "Upgrade the Saddlery for more", {"why": tl.get("why", "")})
	Save.stations["saddlery"] = 2
	var p2 := Data.saddle_price("skills", "stomp", 2)
	st._saddle_buy("skills", "stomp")
	_x("Saddlery level 2: Upgrade Stomp to 2 takes its price", Data.skill_level("stomp") == 2 and Save.leaves == 1000000 - int(p2["leaves"]) and Save.timber == 100000 - int(p2["timber"]),
		{"level": Data.skill_level("stomp"), "leaves": Save.leaves})
	_x("Stomp at 2 under a level-2 Saddlery is blocked 'cap' again", Data.saddle_block("skills", "stomp") == "cap")
	Save.stations["saddlery"] = 5
	Save.saddlery["skills"]["stomp"] = 3
	tl = _tile("skills", "stomp")
	_x("level 4 is blocked 'burrows' before the raids end, with its note", Data.saddle_block("skills", "stomp") == "burrows" and not bool(tl.get("can", true))
		and String(tl.get("why", "")) == "Level 4 opens after the Raid Missions", {"why": tl.get("why", ""), "block": Data.saddle_block("skills", "stomp")})
	st._saddle_buy("skills", "stomp")
	_x("and it cannot be bought", Data.skill_level("stomp") == 3)
	Save.set_flag("hollow_open")
	_x("once the Burrows are open level 4 is no longer blocked by that", Data.saddle_block("skills", "stomp") == "")
	var p4 := Data.saddle_price("skills", "stomp", 4)
	_x("H1: level 4's price is leaves and timber only", p4.keys() == ["leaves", "timber"] and int(p4["leaves"]) > int(p2["leaves"]), {"price": p4})
	Save.flags.erase("hollow_open")
	Save.saddlery["skills"]["stomp"] = 5
	tl = _tile("skills", "stomp")
	_x("at level 5: Max level and nothing to do", Data.saddle_block("skills", "stomp") == "max" and String(tl.get("action", "x")) == ""
		and String(tl.get("label", "")) == Data.word("max") and String(tl.get("why", "")) == Data.word("max"), tl)
	Save.saddlery["skills"] = {}
	Save.leaves = 0
	Save.timber = 0


# ---------------------------------------------------------------- the mount, riding in a fight
func _foe(at: Vector3) -> Node3D:
	var e = main.fight.spawn("thornling", at, 0)
	e.hp = 1e6
	e.max_hp = 1e6
	e.set_physics_process(false)
	return e


func _clear() -> void:
	for ball in get_tree().get_nodes_in_group("mount_fireballs"):
		ball.queue_free()
	for patch in get_tree().get_nodes_in_group("mount_ground_fire"):
		patch.retire()
	for e in get_tree().get_nodes_in_group("foes"):
		e.dead = true
		e.remove_from_group("foes")
		e.remove_from_group("enemies")
		e.queue_free()


func _ride() -> void:
	main.refresh_companions()
	await t._wait(0.5)
	main.set_riding(true, false)
	main.player.set_process(false)                      # no arrows, no walking: only the mount's own moves
	_fight(true)
	_x("the cat rides Thistle in a fight", main.mount != null and main.player.riding and main.fight.active)


## The cat stood at BASE, the mount under it facing +Z, timers fresh, no foes. Returns the mount's middle.
func _reset() -> Vector3:
	_clear()
	var m = main.mount
	m._stop_move()
	main.player.global_position = BASE
	await t._wait(0.3)
	m.rotation.y = 0.0
	m.cooldowns.clear()
	m.gap = 0.0
	m.moves_made.clear()
	m.last_move = ""
	return m.global_position


func _no_builtin() -> void:
	var m = main.mount
	var at: Vector3 = await _reset()
	var f1 = _foe(at + Vector3(0, 0, 1.0))
	var f2 = _foe(at + Vector3(0.5, 0, 0.8))
	await t._wait(2.2)
	_x("nothing learned: no move in 2 s with foes next to the mount", m.moves_made.is_empty() and m.last_move == "" and f1.hp == 1e6 and f2.hp == 1e6,
		{"moves": m.moves_made, "hp": f1.hp})
	_x("try_move gives false for a skill it has not learned", not m.try_move("stomp") and not m.try_move("ram") and not m.try_move("pounce") and not m.try_move("bellow"))


## H5 (the owner's Q3): all four learned, three in the circles: the fourth never goes, neither by itself in a fight
## (_try_moves) nor through try_move, and keeps its level; the circles' order does not change the priority; the circles
## stay through a change of mount and a save and reload.
func _unslotted() -> void:
	var m = main.mount
	for id in SKILLS:
		Save.saddlery["skills"][id] = 1
	_slots(["stomp", "ram", "pounce"])
	var at: Vector3 = await _reset()
	var ring: Array = []
	for k in 4:                                         # four foes round it: Bellow's moment, and Stomp's too
		ring.append(_foe(at + Vector3(0, 0, 1.2).rotated(Vector3.UP, k * PI * 0.5)))
	m.cooldowns["stomp"] = 99.0                         # Stomp (in a circle) waits: only Bellow could go now
	m.cooldowns["ram"] = 99.0
	m.cooldowns["pounce"] = 99.0
	await t._wait(1.5)
	_x("Bellow learned but in no circle: it never goes by itself, with four foes round the mount",
		int(m.moves_made.get("bellow", 0)) == 0 and ring.all(func(f): return f.bellow_t <= 0.0) and Data.skill_level("bellow") == 1
		and Data.active_skill_level("bellow") == 0, {"moves": m.moves_made})
	_x("and try_move refuses it too", not m.try_move("bellow"))
	_slots(["bellow", "ram", "pounce"])
	m.cooldowns.clear()
	m.gap = 0.0
	_x("in a circle (where Stomp was) Bellow goes; Stomp, out of the circles, keeps its level 1 and is refused",
		m.try_move("bellow") and not m.try_move("stomp") and Data.skill_level("stomp") == 1)
	# the priority stays mount_skills.priority (Bellow first), whatever circle each sits in
	at = await _reset()
	for k in 4:
		_foe(at + Vector3(0, 0, 1.2).rotated(Vector3.UP, k * PI * 0.5))
	_slots(["pounce", "ram", "bellow"])
	await t._wait(0.45)
	_x("with Bellow in the last circle it still goes first (the priority, not the circles' order)", m.last_move == "bellow",
		{"last": m.last_move, "moves": m.moves_made})
	# a change of mount and a reload keep the circles (one list for every mount)
	var want: Array = Data.skill_slots()
	var keep_look := Save.mount_look
	Save.mount_look = "bramblewool" if keep_look != "bramblewool" else "thistle"
	m.set_look()
	await t._wait(0.3)
	var after_look: Array = Data.skill_slots()
	Save.mount_look = keep_look
	m.set_look()
	await t._wait(0.3)
	Save.save_game(true)
	Save.load_game()
	var after_load: Array = Data.skill_slots()
	_x("the circles are the same on the other mount and after a save and a reload", after_look == want and after_load == want
		and Data.skill_level("bellow") == 1 and Data.skill_level("stomp") == 1, {"want": want, "look": after_look, "load": after_load})
	_clear()
	Save.saddlery["skills"] = {}
	_slots([])


func _stomp() -> void:
	var m = main.mount
	_learn("stomp", 1)
	var at: Vector3 = await _reset()
	var near = _foe(at + Vector3(0, 0, 1.0))
	var far = _foe(at + Vector3(0, 0, -4.5))
	var h0: float = near.hp
	near._knock = Vector3.ZERO
	var went: bool = m.try_move("stomp")
	await t._wait(0.1)
	var dmg := Data.skill_damage("stomp", 1)
	_x("Stomp hurts a foe within 2 m (its damage) and pushes it, a foe 4.5 m off is left alone", went and absf((h0 - float(near.hp)) - dmg) < 0.5 and near._knock.length() > 0.1 and far.hp == 1e6,
		{"went": went, "dealt": h0 - float(near.hp), "want": dmg, "knock": near._knock, "far": far.hp})
	_x("Stomp's timer and the gap start", float(m.cooldowns.get("stomp", 0.0)) > 3.0 and m.gap > 0.0 and m.last_move == "stomp" and int(m.moves_made.get("stomp", 0)) == 1,
		{"cd": m.cooldowns, "gap": m.gap})
	await _reset()
	_x("Stomp with no foe near does not go", not m.try_move("stomp"))
	_forget("stomp")


func _ram() -> void:
	var m = main.mount
	_learn("ram", 1)
	var at: Vector3 = await _reset()
	var ahead = _foe(at + Vector3(0, 0, 2.5))
	var behind = _foe(at + Vector3(0, 0, -2.0))
	var h0: float = ahead.hp
	var went: bool = m.try_move("ram")
	_x("Ram goes when a foe is ahead, and it is charging", went and m.moving() == "ram")
	await t._wait(0.8)
	var dmg := Data.skill_damage("ram", 1)
	_x("Ram hurts the foe ahead (its damage) and shoves it aside; the foe behind is left alone", absf((h0 - float(ahead.hp)) - dmg) < 0.5 and behind.hp == 1e6 and ahead._knock.length() > 0.1,
		{"dealt": h0 - float(ahead.hp), "want": dmg, "behind": behind.hp})
	_x("Ram carried the mount forward and is over", m.global_position.z > at.z + 2.0 and m.moving() == "", {"z0": at.z, "z": m.global_position.z})
	at = await _reset()
	var only_behind = _foe(at + Vector3(0, 0, -2.0))
	_x("Ram does not go for a foe behind it", not m.try_move("ram") and only_behind.hp == 1e6)
	_forget("ram")


func _pounce() -> void:
	var m = main.mount
	_learn("pounce", 1)
	var at: Vector3 = await _reset()
	var g: Array = [_foe(at + Vector3(0, 0, 4.0)), _foe(at + Vector3(1.0, 0, 4.6)), _foe(at + Vector3(-1.0, 0, 4.3))]
	var h0: Array = g.map(func(f): return f.hp)
	var went: bool = m.try_move("pounce")
	_x("Pounce goes for a group within 6 m and is leaping", went and m.moving() == "pounce")
	await t._wait(1.0)
	var dmg := Data.skill_damage("pounce", 1)
	var all_hurt := true
	var all_stunned := true
	for i in 3:
		all_hurt = all_hurt and absf((float(h0[i]) - float(g[i].hp)) - dmg) < 0.5
		all_stunned = all_stunned and String(g[i].state) == "daze"
	_x("Pounce moved the mount toward the group", m.global_position.z > at.z + 2.5 and m.moving() == "", {"z0": at.z, "z": m.global_position.z})
	_x("Pounce damaged all three (its damage) and stunned them (dazed)", all_hurt and all_stunned, {"hp": g.map(func(f): return f.hp), "state": g.map(func(f): return f.state)})
	await _reset()
	_forget("pounce")


func _bellow() -> void:
	var m = main.mount
	_learn("bellow", 1)
	var at: Vector3 = await _reset()
	var three: Array = [_foe(at + Vector3(2.0, 0, 0)), _foe(at + Vector3(-2.0, 0, 0)), _foe(at + Vector3(0, 0, 2.5))]
	_x("Bellow does not go for only three foes", not m.try_move("bellow") and three.all(func(f): return f.bellow_t <= 0.0))
	var all4: Array = three + [_foe(at + Vector3(0, 0, -2.5))]
	var went: bool = m.try_move("bellow")
	var k := Data.skill_taken("bellow", 1)
	var shaken: bool = all4.all(func(f): return f.bellow_t > 0.0 and absf(f.bellow_k - k) < 0.001)
	var dazed: bool = all4.all(func(f): return String(f.state) == "daze")
	_x("Bellow with 4 foes near: all stunned and shaken (bellow_t, bellow_k)", went and shaken and dazed, {"went": went, "t": all4.map(func(f): return f.bellow_t), "state": all4.map(func(f): return f.state)})
	var foe = all4[0]
	foe.hit(Vector3.FORWARD, 10.0)
	_x("a shaken foe takes %d%% more damage" % roundi(k * 100.0), absf(float(foe.last_dealt) - 10.0 * (1.0 + k)) < 0.01, {"dealt": foe.last_dealt})
	_forget("bellow")


# ---------------------------------------------------------------- never two moves in the same moment
func _gap() -> void:
	var m = main.mount
	var gap_s := Data.saddle_gap()
	Save.saddlery["skills"]["stomp"] = 1
	Save.saddlery["skills"]["ram"] = 1
	_slots(["stomp", "ram"])                            # H5: both in a circle (Stomp's circle first: the priority still wins)
	var at: Vector3 = await _reset()
	_foe(at + Vector3(0, 0, 1.2))                       # ahead and inside Stomp's reach: both could go
	await t._wait(0.45)
	var total := 0
	for k in m.moves_made:
		total += int(m.moves_made[k])
	_x("Stomp and Ram both ready and a foe for both: only one goes inside the gap, Ram first (the priority)", total == 1 and m.last_move == "ram" and m.gap > 0.0,
		{"moves": m.moves_made, "gap": m.gap})
	at = await _reset()
	_foe(at + Vector3(0, 0, 1.0))
	m.try_move("stomp")
	_x("after a move the gap is saddlery.gap_s (%s s) and its own timer runs" % gap_s, absf(m.gap - gap_s) < 0.05 and float(m.cooldowns.get("stomp", 0.0)) > 3.0, {"gap": m.gap})
	Save.saddlery["skills"] = {}
	_slots([])


# ---------------------------------------------------------------- (e) attachments
func _attach() -> void:
	var m = main.mount
	var base_hp: int = m.max_hp()
	var per: float = float(Data.saddle_info("attach", "saddle")["hp_per_level"])
	_gear("saddle", 1)
	Save.saddlery["worn"] = "saddle"                       # one attachment worn at a time (the owner, 22 Nov 2026)
	var hp1: int = m.max_hp()
	_gear("saddle", 2)
	var hp2: int = m.max_hp()
	_x("Mossweave Saddle: +%d%% mount health a level" % roundi(per * 100.0), hp1 == roundi(base_hp * (1.0 + per)) and hp2 == roundi(base_hp * (1.0 + 2.0 * per)),
		{"base": base_hp, "l1": hp1, "l2": hp2})
	_gear("saddle", 0)
	Save.saddlery["worn"] = ""
	_x("without it the health is back", m.max_hp() == base_hp)
	var bags := float(Data.saddle_info("attach", "saddlebags")["leaves_per_level"])
	Data._bag_acc = 0.0
	var none := Data.saddlebag_leaves(100)
	_gear("saddlebags", 1)
	Save.saddlery["worn"] = "saddlebags"
	var l1 := Data.saddlebag_leaves(100)
	_gear("saddlebags", 3)
	var l3 := Data.saddlebag_leaves(100)
	_x("Saddlebags: kills drop +%d%% leaves a level (none without them)" % roundi(bags * 100.0), none == 100 and l1 == 100 + roundi(100.0 * bags) and l3 == 100 + roundi(300.0 * bags),
		{"none": none, "l1": l1, "l3": l3})
	_gear("saddlebags", 0)
	Save.saddlery["worn"] = ""
	Data._bag_acc = 0.0
	_gear("fire_spitter", 1)
	Save.saddlery["worn"] = "fire_spitter"
	var at: Vector3 = await _reset()
	var close = _foe(at + Vector3(0, 0, 1.6))
	var behind = _foe(at + Vector3(0, 0, -1.6))
	var went: bool = m.try_move("fire_spitter")
	_x("Fire-spitter launches a real ball before applying damage", went and close.hp == 1e6 and close.burn_t <= 0.0 and get_tree().get_nodes_in_group("mount_fireballs").size() == 1)
	await t._wait(0.4)
	_x("Fire-spitter's ball impacts and burns the foe ahead, not one behind", went and close.burn_t > 0.0 and absf(float(close.burn_per_s) - Data.fire_burn_per_s(1)) < 0.01 and behind.burn_t <= 0.0,
		{"went": went, "burn_t": close.burn_t, "per_s": close.burn_per_s, "want": Data.fire_burn_per_s(1)})
	# 22 Nov 2026: only the WORN attachment shows its model on the saddle bone (one at a time, the owner), when its file
	# exists; the others owned stay off
	for id in GEAR:
		_gear(id, 1)
	var shown_ok := true
	var info := {}
	for id in GEAR:
		Save.saddlery["worn"] = id
		m.refresh_gear()
		var p: String = m.gear_path(id, Save.mount_look)
		var has: bool = ResourceLoader.exists(p)
		info[id] = "%s: file %s, shown %s, others %s" % [p.get_file(), has, m.gear.has(id), m.gear.keys()]
		shown_ok = shown_ok and m.gear.has(id) == has and m.gear.keys().all(func(k): return k == id)
		if has and m.gear.has(id):
			var hold = m.gear[id].get_parent()
			shown_ok = shown_ok and hold is BoneAttachment3D and String(hold.bone_name) == "saddle" and (m.gear[id] as Node3D).transform.is_equal_approx(Transform3D.IDENTITY)
	Save.saddlery["worn"] = "fire_spitter"
	m.refresh_gear()
	_x("attachment models: only the worn one shows, on the saddle bone, no offset, when its file exists", shown_ok, info)
	var from: Array = m._fire_from()
	var plain: Vector3 = m.global_position + m._fwd() * 0.45 + Vector3(0, 0.75, 0)
	_x("the Fire-spitter's flames start at its marker_nozzle when its model has one, else in front of the mount as before",
		(m._nozzle != null and (from[0] as Vector3).is_equal_approx(m._nozzle.global_position)) or (m._nozzle == null and (from[0] as Vector3).distance_to(plain) < 0.01),
		{"nozzle": m._nozzle != null, "from": from[0]})
	# a stand-in Fire-spitter file (made here, as the real one will be: a mesh and a marker_nozzle in the saddle bone's frame)
	var root := Node3D.new()
	root.name = "fire_spitter_standin"
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	(box.mesh as BoxMesh).size = Vector3(0.12, 0.12, 0.25)
	root.add_child(box)
	box.owner = root
	var nz := Node3D.new()
	nz.name = "marker_nozzle"
	nz.position = Vector3(0.0, 0.05, 0.2)
	root.add_child(nz)
	nz.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	root.free()
	var hung: Node3D = m._hang_gear("fire_spitter", ps)
	await t._wait(0.1)
	var hold2 = hung.get_parent() if hung != null else null
	var from2: Array = m._fire_from()
	_x("a Fire-spitter model (stand-in) hangs on the saddle bone with no offset, and the flames start at its marker_nozzle, going ahead",
		hung != null and hold2 is BoneAttachment3D and String(hold2.bone_name) == "saddle" and hung.transform.is_equal_approx(Transform3D.IDENTITY)
		and m._nozzle != null and (from2[0] as Vector3).is_equal_approx(m._nozzle.global_position) and m._flat(from2[1]).normalized().dot(m._fwd()) > 0.3,
		{"from": from2, "fwd": m._fwd()})
	m.refresh_gear()
	_x("refresh_gear swaps the stand-in back to the real worn model (or nothing without its file)", m.gear.keys() == ([String(Save.saddlery["worn"])] if ResourceLoader.exists(m.gear_path(String(Save.saddlery["worn"]), Save.mount_look)) else [])
		, {"gear": m.gear.keys(), "worn": Save.saddlery["worn"]})
	var at2: Vector3 = await _reset()
	var close2 = _foe(at2 + Vector3(0, 0, 1.6))
	var went2: bool = m.try_move("fire_spitter")
	m.set_look()                                        # a look change: the models follow the new model
	await t._wait(0.3)
	var after := true
	for id in GEAR:
		after = after and m.gear.has(id) == (id == String(Save.saddlery["worn"]) and ResourceLoader.exists(m.gear_path(id, Save.mount_look)))   # only the worn one shows
	_x("with all three owned the Fire-spitter still spits, and after a look change the models follow (nothing errors)", went2 and close2.burn_t > 0.0 and after,
		{"went": went2, "gear": m.gear.keys()})
	_no_gear()
	m.refresh_gear()
	_x("without attachments no model is shown", m.gear.is_empty())


## Real projectiles, splash, upgrade damage and automatic cadence. Other combat is held still to isolate these hits.
func _fireballs() -> void:
	var m = main.mount
	var old_draw: int = Save.stats.get("draw", 0)
	var old_bow: String = Save.bow
	Save.bow = "twig"
	Save.saddlery["skills"] = {}
	_no_gear()
	_gear("fire_spitter", 1)
	Save.saddlery["worn"] = "fire_spitter"
	m.set_process(false)
	for look in ["thistle", "bramblewool"]:
		Save.mount_look = look
		m.set_look()
		for level in [1, 2, 5]:
			_gear("fire_spitter", level)
			var at: Vector3 = await _reset()
			var primary = _foe(at + Vector3(0, 0, 2.0))
			var splash = _foe(at + Vector3(1.0, 0, 2.1))
			var outside = _foe(at + Vector3(-2.2, 0, 2.0))
			var went: bool = m.try_move("fire_spitter")
			if level == 1:
				var balls := get_tree().get_nodes_in_group("mount_fireballs")
				var from: Array = m._fire_from()
				_x("%s flame ball starts at the attachment nozzle" % look, went and balls.size() == 1 and balls[0].global_position.distance_to(from[0]) < 0.001)
				main.closeup = Vector3(-3.8, 6.2, 5.5)
				await t._wait(0.02)
				await t._shot("flame_ball_" + look)
				await t._wait(0.2)
				await t._shot("flame_splash_" + look)
				await t._wait(0.25)
			else:
				await t._wait(0.45)
			var want := Data.fire_damage(level)
			_x("%s level %d impact damages primary and nearby foe once, leaving an outside foe alone" % [look, level], went and absf(1e6 - float(primary.hp) - want) < 0.01 and absf(1e6 - float(splash.hp) - want) < 0.01 and outside.hp == 1e6,
				{"primary": 1e6 - float(primary.hp), "splash": 1e6 - float(splash.hp), "expected": want})
			_x("%s level %d splash retains the upgraded burn" % [look, level], absf(float(splash.burn_per_s) - Data.fire_burn_per_s(level)) < 0.001 and splash.burn_t > 0.0)
			if level == 1:
				main.closeup = Vector3.ZERO
	# Upgrades must actually add damage at every level, including fractional damage at levels 2 and 5.
	var rising := true
	for level in range(2, 6):
		rising = rising and Data.fire_damage(level) > Data.fire_damage(level - 1) and Data.fire_burn_per_s(level) > Data.fire_burn_per_s(level - 1)
	_x("each Fire-spitter upgrade increases impact and burn damage", rising)
	_gear("fire_spitter", 1)
	var at: Vector3 = await _reset()
	_foe(main.player.global_position + Vector3(0, 0, Data.cat_range() + 0.5))
	_x("Fire-spitter does not shoot beyond the cat's arrow range", not m.try_move("fire_spitter"))
	at = await _reset()
	var foe = _foe(at + Vector3(0, 0, 2.0))
	m.try_move("fire_spitter")
	var ball = get_tree().get_first_node_in_group("mount_fireballs")
	var start: Vector3 = ball.global_position
	main.frozen = true
	await t._wait(0.2)
	_x("a frozen game stops flame-ball movement and damage", is_instance_valid(ball) and ball.global_position.is_equal_approx(start) and foe.hp == 1e6)
	main.frozen = false
	await t._wait(0.45)
	_x("a paused flame ball resumes and impacts once", absf(1e6 - float(foe.hp) - Data.fire_damage(1)) < 0.01)
	at = await _reset()
	foe = _foe(at + Vector3(0, 0, 2.0))
	m.try_move("fire_spitter")
	foe.global_position.x += 8.0
	await t._wait(float(Data.saddle_info("attach", "fire_spitter")["projectile_life_s"]) + 0.2)
	_x("a missed flame ball expires without damaging a distant foe", get_tree().get_nodes_in_group("mount_fireballs").is_empty() and foe.hp == 1e6)
	# The automatic attachment clock must follow draw upgrades and bypass the slower shared skill gap.
	var counts: Array[int] = []
	for draw_level in [0, 9]:
		Save.stats["draw"] = draw_level
		at = await _reset()
		_foe(at + Vector3(0, 0, 2.0))
		m.gap = 10.0
		m.set_process(true)
		await t._wait(2.1)
		m.set_process(false)
		counts.append(int(m.moves_made.get("fire_spitter", 0)))
		var expected := floori(2.1 / main.player.attack_interval())
		_x("draw level %d: automatic Fire-spitter keeps the cat's pace during the skill gap" % draw_level, counts.back() >= expected and m.gap > 0.0, {"shots": counts.back(), "expected_min": expected, "interval": main.player.attack_interval()})
	_x("a faster cat causes more automatic flame balls", counts[1] > counts[0], {"slow": counts[0], "fast": counts[1]})
	Save.saddlery["worn"] = ""
	var before: int = m.moves_made.get("fire_spitter", 0)
	m.set_process(true)
	await t._wait(0.8)
	_x("taking off the Fire-spitter stops new flame balls", int(m.moves_made.get("fire_spitter", 0)) == before)
	m.set_process(false)
	_clear()
	Save.stats["draw"] = old_draw
	Save.bow = old_bow
	Save.mount_look = "thistle"
	_no_gear()
	Save.saddlery["worn"] = ""
	m.set_look()
	m.set_process(true)


## Arrow-range parity, a rotating firing unit, target changes and steering while shooting sideways/behind.
## Living flames on the projectile and enemies, and a short-lived, bounded visual ground burn.
func _ground_fire() -> void:
	var m = main.mount
	var info := Data.saddle_info("attach", "fire_spitter")
	var old_quality: int = Quality.level
	Save.mount_look = "thistle"
	Save.saddlery["skills"] = {}
	_no_gear()
	_gear("fire_spitter", 1)
	Save.saddlery["worn"] = "fire_spitter"
	m.set_look()
	m.set_process(false)
	_fight(true)
	var at: Vector3 = await _reset()
	var foe = _foe(at + Vector3(0, 0, 3.0))
	main.closeup = Vector3(-3.2, 4.2, 4.8)
	m.try_move("fire_spitter")
	await t._wait(0.12)
	var ball = get_tree().get_first_node_in_group("mount_fireballs")
	_x("the redesigned ball has a hot core, flame shell and animated trail", ball != null and ball.has_node("HotCore") and ball.has_node("FlameShell") and ball.has_node("FlameTrail") and ball.get_node("FlameTrail").mesh is QuadMesh)
	await t._shot("fireball_flames_in_flight")
	await t._wait(0.5)
	var patches := get_tree().get_nodes_in_group("mount_ground_fire")
	_x("a real fireball impact leaves one ground fire", patches.size() == 1)
	if patches.is_empty():
		main.closeup = Vector3.ZERO
		m.set_process(true)
		return
	var patch = patches[0]
	_x("ground fire sits on the floor at the impact, not up at the enemy's chest", absf(float(patch.global_position.y) - 0.045) < 0.001 and Vector2(patch.global_position.x - foe.global_position.x, patch.global_position.z - foe.global_position.z).length() < 0.05)
	_x("the ground effect lasts three seconds with a final fade", is_equal_approx(float(patch.life), 3.0) and float(info["ground_fire_fade_s"]) > 0.0 and float(info["ground_fire_fade_s"]) < float(patch.life))
	_x("burning enemies use animated flame silhouettes too", foe._burn_fx != null and foe._burn_fx.mesh is QuadMesh and foe.burn_t > 0.0)
	main.closeup_at = foe
	main.closeup = Vector3(-2.8, 3.5, 4.2)
	await t._wait(0.15)
	await t._shot("fire_ground_burning")
	var before_hp: float = foe.hp
	var before_age: float = patch.age
	main.frozen = true
	await t._wait(0.2)
	_x("freezing gameplay also stops the ground fire clock and particles", is_equal_approx(float(patch.age), before_age) and float(patch._flames.speed_scale) == 0.0)
	main.frozen = false
	await t._wait(0.1)
	_x("ground fire resumes after gameplay unfreezes", float(patch.age) > before_age and float(patch._flames.speed_scale) == 1.0)
	var until_fade: float = maxf(0.0, float(patch.life) - float(info["ground_fire_fade_s"]) + 0.25 - float(patch.age))
	await t._wait(until_fade)
	var opacity: float = patch._ground_mat.get_shader_parameter("opacity")
	_x("flames stop spawning and the embers fade before extinguishing", not patch._flames.emitting and opacity > 0.0 and opacity < 1.0, {"age": patch.age, "opacity": opacity})
	await t._shot("fire_ground_fading")
	await t._wait(0.8)
	_x("fire extinguishes and removes its ground mark after three seconds", get_tree().get_nodes_in_group("mount_ground_fire").is_empty())
	_x("ground visuals do not add extra hits or extend the existing enemy burn", foe.hp == before_hp and absf(float(foe.burn_per_s) - Data.fire_burn_per_s(1)) < 0.01)
	main.closeup_at = null
	var fresh = Fx.fire_ground(main, at + Vector3(0, 0, 2.0), float(info["blast_m"]), info)
	fresh.age = 1.5
	var reused = Fx.fire_ground(main, at + Vector3(0.2, 0, 2.0), float(info["blast_m"]), info)
	_x("nearby repeated hits refresh one existing fire patch", reused == fresh and is_zero_approx(float(fresh.age)) and get_tree().get_nodes_in_group("mount_ground_fire").size() == 1)
	var caps: Array = info["ground_fire_max_by_quality"]
	for quality in 3:
		for p in get_tree().get_nodes_in_group("mount_ground_fire"):
			p.retire()
		Quality.level = quality
		for i in int(caps[quality]) + 3:
			Fx.fire_ground(main, at + Vector3(i * 3.0, 0, 4.0), float(info["blast_m"]), info)
		_x("quality %d caps simultaneous ground fire" % quality, get_tree().get_nodes_in_group("mount_ground_fire").size() == int(caps[quality]))
	for p in get_tree().get_nodes_in_group("mount_ground_fire"):
		p.retire()
	Quality.level = Quality.LOW
	fresh = Fx.fire_ground(main, foe.global_position, float(info["blast_m"]), info)
	main.closeup_at = foe
	await t._wait(0.3)
	_x("Low graphics keeps visible flames with fewer particles", fresh._flames.amount == Quality.particles(22) and fresh._flames.emitting)
	await t._shot("fire_ground_low")
	var prior_area = main.area
	var other := Node3D.new()
	main.area = other
	fresh._process(0.01)
	main.area = prior_area
	other.free()
	_x("changing areas clears the old ground fire", get_tree().get_nodes_in_group("mount_ground_fire").is_empty())
	Quality.level = old_quality
	main.closeup = Vector3.ZERO
	main.closeup_at = null
	_clear()
	_no_gear()
	Save.saddlery["worn"] = ""
	m.set_look()
	m.set_process(true)


func _fire_tracking() -> void:
	var m = main.mount
	var old_range: int = Save.stats.get("range", 0)
	var old_bow: String = Save.bow
	_no_gear()
	_gear("fire_spitter", 1)
	Save.saddlery["worn"] = "fire_spitter"
	Save.saddlery["skills"] = {}
	for look in ["thistle", "bramblewool"]:
		Save.mount_look = look
		m.set_process(false)
		m.set_look()
		for profile in [[0, "twig"], [6, "frost"]]:
			Save.stats["range"] = profile[0]
			Save.bow = profile[1]
			await _reset()
			var reach := Data.cat_range()
			var foe = _foe(main.player.global_position + Vector3(0, 0, reach - 0.1))
			var went: bool = m.try_move("fire_spitter")
			await t._wait((reach + 1.0) / float(Data.saddle_info("attach", "fire_spitter")["projectile_speed"]) + 0.2)
			_x("%s reaches the cat's arrow-range edge with %s/range %d" % [look, profile[1], profile[0]], went and foe.hp < 1e6 and foe.burn_t > 0.0, {"range": reach, "damage": 1e6 - float(foe.hp)})
			foe.global_position = main.player.global_position + Vector3(0, 0, reach + 0.2)
			_x("%s drops a target just beyond the current arrow range" % look, not m.try_move("fire_spitter") and m._fire_target == null)
		Save.stats["range"] = 0
		Save.bow = "twig"
		await _reset()
		var near = _foe(BASE + Vector3(-2.5, 0, 0))
		var chosen = _foe(BASE + Vector3(0, 0, 4.0))
		main.player.target = chosen
		m._update_fire_aim(0.4)
		_x("%s assists the cat's focus and aims its nozzle at it" % look, m._fire_target == chosen and m._fire_aligned() and m._fire_pivot != null)
		chosen.dead = true
		m._update_fire_aim(0.4)
		_x("%s reacquires a side target after the focused enemy dies" % look, m._fire_target == near and m._fire_aligned())
		_x("%s turns only the firing unit above a fixed harness" % look, m.gear["fire_spitter"].transform.is_equal_approx(Transform3D.IDENTITY) and absf(m.rotation.y) < 0.01 and not m._fire_pivot.quaternion.is_equal_approx(m._fire_rest))
		for direction in [-1.0, 1.0]:
			await _reset()
			var foe = _foe(BASE + Vector3(0, 0, -3.5))
			m._track = BASE
			m._spd = 0.0
			main.joystick.force = true
			main.joystick.forced = Vector2(direction * 0.5, 0)
			main.player.set_process(true)
			m.set_process(true)
			var elapsed := 0.0
			var max_error := 0.0
			while elapsed < 1.8:
				await get_tree().process_frame
				elapsed += get_process_delta_time()
				if elapsed > 0.7:
					var from: Array = m._fire_from()
					var to: Vector3 = foe.global_position + Vector3(0, foe.aim_height, 0) - (from[0] as Vector3)
					max_error = maxf(max_error, acos(clampf((from[1] as Vector3).dot(to.normalized()), -1.0, 1.0)))
			main.joystick.forced = Vector2.ZERO
			main.player.set_process(false)
			m.set_process(false)
			var moved: float = (main.player.global_position.x - BASE.x) * direction
			var heading_error := absf(wrapf(m.rotation.y - direction * PI * 0.5, -PI, PI))
			_x("%s steers %s while tracking and hitting an enemy behind" % [look, "left" if direction < 0.0 else "right"], moved > 0.5 and heading_error < 0.08 and max_error < deg_to_rad(12.0) and foe.burn_t > 0.0 and int(m.moves_made.get("fire_spitter", 0)) >= 2, {"moved": moved, "heading_error": heading_error, "aim_error": max_error, "burn": foe.burn_t, "shots": m.moves_made.get("fire_spitter", 0)})
			main.closeup = Vector3(-3.8, 6.2, 5.5).rotated(Vector3.UP, m.rotation.y)
			await t._shot("fire_tracking_%s_%s" % [look, "left" if direction < 0.0 else "right"])
			main.closeup = Vector3.ZERO
		main.joystick.force = false
	_clear()
	main.player.target = null
	Save.stats["range"] = old_range
	Save.bow = old_bow
	Save.mount_look = "thistle"
	_no_gear()
	Save.saddlery["worn"] = ""
	m.set_look()
	m.set_process(true)


# ---------------------------------------------------------------- (g) the ride, in pictures
## Close-up shots of the cat riding each mount (ride_<look>_<moment>_<view>.png in --shots): standing, running, in a
## turn, shooting forward and just after a shot, from the game camera's angle (50 degrees down, brought in: "game") and
## from her bow side ("side"); on Thistle also a moment after each skill (Stomp, Ram, Pounce, Bellow).
var _cam_at: Node3D                                    # what the close-up camera looks at: the cat's chest, riding


func _ride_shots() -> void:
	var pl = main.player
	var j = main.joystick
	var m = main.mount
	_fight(false)
	_clear()
	await t._wait(0.6)
	await _string_side("foot_stand")                     # on foot, before riding
	_cam_at = Node3D.new()
	pl.add_child(_cam_at)
	_cam_at.position = Vector3(0, 0.55, 0)
	main.closeup_at = _cam_at
	var keep_look := Save.mount_look
	for lk in ["thistle", "bramblewool"]:
		Save.mount_look = lk
		m.set_look()
		pl.set_process(true)
		main.set_riding(true, false)
		pl.global_position = BASE
		m.rotation.y = 0.0
		await t._wait(1.2)
		await _string_side("ride_%s_stand" % lk)
		if Data.args().has("--probe"):
			_probe()
		await _view("ride_%s_stand" % lk, "game")
		await t._wait(0.4)
		await _view("ride_%s_stand" % lk, "side")
		j.force = true
		j.forced = Vector2(1, 0)
		await t._wait(1.1)
		await _string_side("ride_%s_run" % lk)
		if Data.args().has("--probe"):
			var rows: Array = []
			for k in 40:
				var g: Transform3D = m._skel.global_transform * m._skel.get_bone_global_pose(m._saddle)
				var bz := g.basis.z.normalized()
				var by := g.basis.y.normalized()
				var bx := g.basis.x.normalized()
				var fw := Vector3(sin(m.rotation.y), 0, cos(m.rotation.y))
				rows.append("%.3f y%.3f fz%.2f fy%.2f fx%.2f yy%.2f spd%.2f" % [t.get_process_delta_time(), g.origin.y, bz.dot(fw), by.dot(fw), bx.dot(fw), by.y, m._spd])
				await get_tree().process_frame
			t._log("PROBE_RUN " + " | ".join(rows))
		await _view("ride_%s_run" % lk, "game")
		await t._wait(0.13)
		await _view("ride_%s_run" % lk, "side")
		var a := 0.0
		var tt := 0.0
		while tt < 0.6:                                 # the stick swings round: a turn to the left (from +X to -Z)
			var dt := get_process_delta_time()
			a = minf(a + dt * 2.6, PI * 0.5)
			j.forced = Vector2(cos(a), -sin(a))
			await get_tree().process_frame
			tt += dt
		await _view("ride_%s_turn" % lk, "game")
		j.forced = Vector2.ZERO
		j.force = false
		await t._wait(0.8)
		var fwd := Vector3(sin(m.rotation.y), 0, cos(m.rotation.y))
		_foe(pl.global_position + fwd * 4.0)
		await t._wait(1.1)
		await _view("ride_%s_shoot" % lk, "game")
		await t._wait(0.3)
		await _view("ride_%s_shoot" % lk, "side")
		_clear()
		await t._wait(0.3)
		await _view("ride_%s_aftershot" % lk, "game")
		await t._wait(0.05)
		await _view("ride_%s_aftershot" % lk, "side")
		if lk == "thistle" and not Data.args().has("--rideshots-noskills"):
			await _skill_shots()
	main.set_riding(false, false)
	Save.mount_look = keep_look
	m.set_look()
	main.closeup = Vector3.ZERO
	main.closeup_at = null
	_cam_at.queue_free()
	_cam_at = null


# ---------------------------------------------------------------- (h) the mount's head, ears and horns clear of her
const CLIPS := ["Idle", "Run", "Stomp", "Ram", "Pounce", "Bellow", "Thump"]


## Every clip of both mounts played under her (standing, the mount facing +Z): how far the mount's head, ear, horn and
## neck points come inside her head, ear and chest spheres, frame by frame, with the lean away off ("before") and on
## ("after"). Logs each clip's worst; with shots, pictures of the worst moments before and after. Returns the worst
## left after the lean away over everything ({"gap": metres (negative: inside), "what": ...}).
func _clear_sweep(shots: bool) -> Dictionary:
	var pl = main.player
	var m = main.mount
	var rm = pl.ride_motion
	_fight(false)
	_clear()
	pl.set_process(true)
	rm.measure = true
	var keep_look := Save.mount_look
	var worst_all := {"gap": INF, "what": ""}
	if shots:
		_cam_at = Node3D.new()
		pl.add_child(_cam_at)
		_cam_at.position = Vector3(0, 0.55, 0)
		main.closeup_at = _cam_at
	for lk in ["thistle", "bramblewool"]:
		Save.mount_look = lk
		m.set_look()
		main.set_riding(true, false)
		pl.global_position = BASE
		m.rotation.y = 0.0
		await t._wait(0.8)
		var rows: Array = []
		var worst_clips: Array = []
		for clip in CLIPS:
			if m.anim == null or not m.anim.has_animation(clip):
				continue
			var res := {}
			for on in [false, true]:
				rm.clear_on = on
				rm.clear_lean = Vector2.ZERO
				await t._wait(0.3)
				var r: Dictionary = await _play_clip(clip)
				res[on] = r
			rows.append("%s: before %s at %.2f s (%s), after %s at %.2f s (%s)" % [clip, _cm(res[false]["left"]), res[false]["t_left"], res[false]["what_left"],
				_cm(res[true]["left"]), res[true]["t_left"], res[true]["what_left"]])
			worst_clips.append([clip, -float(res[false]["left"]), float(res[false]["t_left"])])
			if float(res[true]["left"]) < float(worst_all["gap"]):
				worst_all = {"gap": float(res[true]["left"]), "what": "%s %s %s at %.2f s" % [lk, clip, res[true]["what_left"], res[true]["t_left"]]}
		t._log("CLEAR %s | %s" % [lk, " | ".join(rows)])
		if shots:
			worst_clips.sort_custom(func(a, b): return a[1] > b[1])
			for k in mini(3, worst_clips.size()):
				var c: Array = worst_clips[k]
				for on in [false, true]:
					await _clip_shot(String(c[0]), float(c[2]), on, "clear_%s_%s_%s" % [lk, String(c[0]).to_lower(), "after" if on else "before"])
	m.act_t = 0.0
	if m.anim:
		m.anim.speed_scale = 1.0
	rm.clear_on = true
	rm.measure = false
	main.set_riding(false, false)
	Save.mount_look = keep_look
	m.set_look()
	if shots:
		main.closeup = Vector3.ZERO
		main.closeup_at = null
		_cam_at.queue_free()
		_cam_at = null
	return worst_all


func _cm(x) -> String:
	var v := float(x)
	if v == INF:
		return "-"
	return "%+.1f cm" % (v * 100.0)


## Plays clip once on the mount under her (held: nothing else plays meanwhile) and returns its worst moments: "in" (how
## far a mount point came inside her, before the lean away) and "left" (the closest after it, negative = inside).
func _play_clip(clip: String) -> Dictionary:
	var m = main.mount
	var rm = main.player.ride_motion
	var len: float = m.anim.get_animation(clip).length
	m.anim.play(clip, 0.1)
	m.anim.speed_scale = 1.0
	m.act_t = 99.0
	var tt := 0.0
	var out := {"in": 0.0, "t_in": 0.0, "what_in": "", "left": INF, "t_left": 0.0, "what_left": ""}
	var loops := 2 if clip in ["Idle", "Run"] else 1
	while tt < len * loops:
		await get_tree().process_frame
		tt += get_process_delta_time()
		var at := fmod(tt, len)
		if float(rm.clear_in) > float(out["in"]):
			out["in"] = rm.clear_in
			out["t_in"] = at
			out["what_in"] = rm.clear_what
		if float(rm.clear_left) < float(out["left"]):
			out["left"] = rm.clear_left
			out["t_left"] = at
			out["what_left"] = rm.clear_what
	m.act_t = 0.0
	return out


## The mount held at time `at` of clip, the lean away on or off, a side picture once she has settled.
func _clip_shot(clip: String, at: float, on: bool, name: String) -> void:
	var m = main.mount
	var rm = main.player.ride_motion
	rm.clear_on = on
	rm.clear_lean = Vector2.ZERO
	m.anim.play(clip, 0.0)
	m.anim.seek(at, true)
	m.anim.speed_scale = 0.0
	m.act_t = 99.0
	await t._wait(0.4)
	await _view(name, "side")
	m.anim.speed_scale = 1.0
	m.act_t = 0.0


func _probe() -> void:
	var pl = main.player
	var sk: Skeleton3D = pl.skeleton
	var inv := sk.global_transform.affine_inverse()
	var out := {"sk_scale": sk.global_transform.basis.get_scale(), "model_y": pl.model.position.y}
	for bn in ["hips", "spine", "chest", "neck", "head", "shoulder.L", "upper_arm.L", "forearm.L", "hand.L", "weapon.L", "bowstring", "thigh.L", "shin.L"]:
		var i := sk.find_bone(bn)
		var g := sk.get_bone_global_pose(i)
		out[bn] = "o %s  x %s y %s z %s" % [g.origin, g.basis.x.normalized(), g.basis.y.normalized(), g.basis.z.normalized()]
	var m = main.mount
	out["saddle_in_sk"] = inv * m._saddle_world()
	out["mount_origin_in_sk"] = inv * m.global_position
	var bm := pl.model.find_child("SK_CatBow", true, false) as MeshInstance3D
	var skin := bm.skin
	var wi := -1
	for b in skin.get_bind_count():
		var nm := String(skin.get_bind_name(b))
		if nm == "" and skin.get_bind_bone(b) >= 0:
			nm = sk.get_bone_name(skin.get_bind_bone(b))
		if nm == "weapon.L":
			wi = b
	out["binds"] = skin.get_bind_count()
	if wi >= 0:
		var bp := skin.get_bind_pose(wi)
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for s in bm.mesh.get_surface_count():
			var arr := bm.mesh.surface_get_arrays(s)
			for v in arr[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = bp * v
				lo = lo.min(p)
				hi = hi.max(p)
		out["bow_in_weapon"] = [lo, hi]
	var bh := sk.find_bone("weapon.L")
	var wg := sk.get_bone_global_pose(bh)
	if wi >= 0:
		var lo2: Vector3 = out["bow_in_weapon"][0]
		var hi2: Vector3 = out["bow_in_weapon"][1]
		out["tips_y_axis"] = [wg * Vector3(0, lo2.y, 0), wg * Vector3(0, hi2.y, 0)]
		out["tips_z_axis"] = [wg * Vector3(0, 0, lo2.z), wg * Vector3(0, 0, hi2.z)]
		out["tips_x_axis"] = [wg * Vector3(lo2.x, 0, 0), wg * Vector3(hi2.x, 0, 0)]
	t._log("PROBE " + str(out))


## One picture: "game" (from the game camera's angle, closer) or "side" (from her bow side, the mount's left).
func _view(name: String, how: String) -> void:
	var h: float = main.mount.rotation.y
	var fwd := Vector3(sin(h), 0, cos(h))
	var left := fwd.rotated(Vector3.UP, PI * 0.5)
	if how == "game":
		main.closeup = Vector3(0, sin(0.8727), cos(0.8727)) * 3.8
	else:
		main.closeup = left * 3.3 + fwd * 0.5 + Vector3(0, 0.5, 0)
	await get_tree().process_frame
	await t._shot("%s_%s" % [name, how])


## A moment after each skill goes (the cat jolts and settles): one side picture each.
func _skill_shots() -> void:
	var m = main.mount
	var pl = main.player
	_fight(true)
	for sid in SKILLS:
		Save.saddlery["skills"] = {sid: 1}
		_slots([sid])
		_clear()
		pl.global_position = BASE
		m.gap = 99.0                                    # nothing goes by itself: only try_move below
		await t._wait(0.5)
		m.cooldowns.clear()
		var fwd := Vector3(sin(m.rotation.y), 0, cos(m.rotation.y))
		var at: Vector3 = m.global_position
		if sid == "bellow":
			for k in 4:
				_foe(at + fwd.rotated(Vector3.UP, k * PI * 0.5) * 2.2)
		elif sid == "pounce":
			_foe(at + fwd * 4.0)
			_foe(at + fwd * 4.4 + fwd.rotated(Vector3.UP, PI * 0.5) * 0.8)
		else:
			_foe(at + fwd * 1.3)
		var went: bool = m.try_move(sid)
		await t._wait(0.18)
		await _view("ride_thistle_%s" % sid, "side")
		_x("ride shots: %s went (for its picture)" % sid, went)
		await t._wait(0.9)
	Save.saddlery["skills"] = {}
	_slots([])
	_clear()
	_fight(false)


# ---------------------------------------------------------------- (f) an old save
func _migrate() -> void:
	var keep_path: String = Save.path
	var tmp := "user://leaf_save_g4mig.json"
	var won: Array = []
	for i in 8:
		won.append(String(Data.mission(i)["id"]))
	var old := {"leaves": 10, "bows": {"twig": 1}, "camp_level": 5, "missions_done": won, "stations": {"stall": 1, "bench": 1},
		"attach": {"owned": ["mount_saddle", "mount_bags", "pet_bell"], "mount": "mount_saddle", "pet": "pet_bell"}}
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	Save.path = tmp
	Save.flags.erase("g4_free_stomp")
	Save.flags.erase("g4_old_attach")
	Save.load_game()
	_x("old save with 8 raids won, no 'saddlery' key: Stomp level 1 for free (flag g4_free_stomp)", Data.skill_level("stomp") == 1 and Save.flag("g4_free_stomp"),
		{"skills": Save.saddlery["skills"]})
	_x("its old Burrows saddle is Saddlery saddle level 3, the bags level 5 (flag), the mount slot comes off, the bell stays",
		Data.attach_level("saddle") == 3 and Data.attach_level("saddlebags") == 5 and Save.flag("g4_old_attach") and String(Save.attach["mount"]) == ""
		and String(Save.attach["pet"]) == "pet_bell", {"attach": _owned().get("attachments", {}), "worn": Save.attach})
	_x("H5: the free Stomp sits in a circle (the v5 step fills the circles from the learned skills), so the mount uses it",
		Data.skill_is_slotted("stomp") and Data.active_skill_level("stomp") == 1, {"slots": Data.skill_slots()})
	Save.saddlery["skills"].erase("stomp")
	Save.save_game(true)
	Save.load_game()
	_x("it runs once: after saving, loading again does not hand out Stomp again", Data.skill_level("stomp") == 0 and Data.attach_level("saddle") == 3, {"skills": Save.saddlery["skills"]})
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	var young := {"bows": {"twig": 1}, "missions_done": won.slice(0, 5), "attach": {"owned": []}}
	f = FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(JSON.stringify(young))
	f.close()
	Save.flags = {}
	Save.load_game()
	_x("an old save with only 5 raids won gets nothing", Data.skill_level("stomp") == 0 and Data.attach_level("saddle") == 0 and Data.attach_level("saddlebags") == 0)
	Save.path = keep_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))


## 22 Nov 2026 (the owner: the string faces the cat in every animation): the horizontal angle between grip -> nock and
## grip -> her chest, sampled over 36 frames; logs the worst (cos < 0: the string faces away from her).
func _string_side(tag: String) -> void:
	var sk: Skeleton3D = main.player.skeleton
	var gi := sk.find_bone("weapon.L")
	var si := sk.find_bone("bowstring")
	var ci := sk.find_bone("chest")
	var worst := 2.0
	for k in 36:
		var xf := sk.global_transform
		var g: Vector3 = xf * sk.get_bone_global_pose(gi).origin
		var s: Vector3 = xf * sk.get_bone_global_pose(si).origin
		var c: Vector3 = xf * sk.get_bone_global_pose(ci).origin
		var a := Vector3(s.x - g.x, 0.0, s.z - g.z)
		var b := Vector3(c.x - g.x, 0.0, c.z - g.z)
		if a.length() > 0.0001 and b.length() > 0.0001:
			worst = minf(worst, a.normalized().dot(b.normalized()))
		await get_tree().process_frame
	var bf = main.player.bow_face
	t._log("STRING_SIDE %s animation worst_cos %.3f (%.0f deg off); bow_face turns it %.0f deg toward her" % [tag, worst, rad_to_deg(acos(clampf(worst, -1.0, 1.0))), rad_to_deg(bf.turned) if bf else 0.0])
