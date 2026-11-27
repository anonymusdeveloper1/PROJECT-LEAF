## H6 Stage 2 checks, part 2 of 3: Place, Done and the last-placement Undo, the card taps, per-piece levels, and repair
## (the Well, the Hearthtree's goals, raid weights). Moved out of autotest_workshop.gd on 27 Nov 2026 (house rule 1:
## one job a file, under about 800 lines); the checks, their words and their order did not change. autotest_workshop.gd
## runs it from its live run, between the Workshop shop checks and the specialisation checks, and frees it after.
extends Node

const AutotestScript := preload("res://scripts/autotest.gd")
const MainScript := preload("res://scripts/main.gd")
const Home := preload("res://scripts/autotest_workshop.gd")
const TIERS: Dictionary = Home.TIERS
const NO_SLOT := Vector2i(-1, -1)

var t: AutotestScript
var main: MainScript
var g                     # autotest_workshop.gd: the helpers all halves use (_x, _rich, _bare_camp, _put and the rest)


## The checks, in the order they always ran.
func run() -> bool:
	var ok: bool = await _check_place()
	ok = await _check_taps() and ok
	ok = await _check_levels() and ok
	return await _check_repair() and ok


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



# ---------------------------------------------------------------- Place, Done and the last-placement Undo
func _check_place() -> bool:
	var d = main.defences
	var hud = main.hud
	_bare_camp()
	t._veteran(3)
	_rich()
	_drain("tower")
	Bag.return_defence("tower", {"level": 3, "wreck": 0.25}, false)
	Bag.return_defence("tower", {"level": 2}, false)
	var ok: bool = _x("a paid level 3 tower and a level 2 one are held, the best held level is 3", Bag.count("tower") == 2 and Bag.best_held_level("tower") == 3,
		{"reserves": Save.defence_reserves})
	var spot: Vector3 = _spot("tower", 0)
	if spot.x > 1.0e8:
		return _x("an open spot for a placement test exists", false) and ok
	main.player.global_position = spot - Vector3(0, 0, 1.6)
	main.player.facing = 0.0
	main.snap_camera()
	d.start_placing("tower")
	await t._wait(0.4)
	ok = _x("Place mode shows the ghost of the paid level, the Place, Done buttons and no Undo yet", d.placing == "tower" and d.ghost != null and d.ghost_ok
		and hud.p_actions.place_button.visible and hud.p_actions.done_button.visible and not d.can_undo_place(), {"placing": d.placing}) and ok
	await t._shot("workshop_place_ghost")
	var p0: int = Save.placed.size()
	hud.p_actions.place_button.pressed.emit()
	await t._wait(0.5)
	var rec: Dictionary = _dict(Save.placed.back()) if Save.placed.size() > p0 else {}
	var first_id: int = -1
	for p: Dictionary in d.pieces:
		if is_same(p.get("src"), rec):
			first_id = int(p["id"])
	var piece: Dictionary = d.piece_at(first_id)
	ok = _x("Place puts the paid level 3 tower down with its saved record (level and wear) and the live piece agrees",
		Save.placed.size() == p0 + 1 and int(rec.get("level", 0)) == 3 and is_equal_approx(float(rec.get("wreck", -1.0)), 0.25)
		and not piece.is_empty() and d.piece_level(piece) == 3 and Bag.count("tower") == 1, {"record": rec}) and ok
	var file_rec: Array = _dict(JSON.parse_string(FileAccess.get_file_as_string(Save.path))).get("placed", [])
	ok = _x("the placement was saved at once (the file holds the record)", file_rec.size() == Save.placed.size() and _same(file_rec.back(), rec)) and ok
	await t._wait(0.3)
	ok = _x("after a placement the Undo button shows and Undo is available", d.can_undo_place() and hud.p_actions.undo_button.visible) and ok
	await t._shot("workshop_place_undo")
	hud.p_actions.undo_button.pressed.emit()
	await t._wait(0.4)
	ok = _x("Undo takes the tower back at its own level and wear, the record goes, the Bag holds it again",
		d.piece_at(first_id).is_empty() and Save.placed.size() == p0 and Bag.count("tower") == 2 and Bag.best_held_level("tower") == 3
		and not d.can_undo_place() and not d.undo_place(), {"held": Bag.count("tower")}) and ok
	# the same piece placed again, then a second one: the older receipt is stale, only the last can be undone
	hud.p_actions.place_button.pressed.emit()
	await t._wait(0.3)
	var second: Vector3 = _spot("tower", 3)
	main.player.global_position = second - Vector3(0, 0, 1.6)
	await t._wait(0.3)
	hud.p_actions.place_button.pressed.emit()
	await t._wait(0.3)
	ok = _x("after the last piece in the Bag the visit stays (Done, no ghost) and the last one can still be undone", Bag.count("tower") == 0 and d.placing == "tower"
		and d.ghost == null and d.can_undo_place() and hud.p_actions.done_button.visible, {"placing": d.placing}) and ok
	# a full Bag on return
	Save.bag = {}
	Bag.add("berries", Bag.room_for("berries"))
	var held_before: int = Bag.used_slots()
	hud.p_actions.undo_button.pressed.emit()
	await t._wait(0.3)
	ok = _x("a full Bag still takes the undone piece back (forced), once, and the ghost returns", Bag.count("tower") == 1 and Bag.used_slots() > Bag.slots()
		and held_before >= Bag.slots() and d.ghost != null and not d.undo_place(), {"used": Bag.used_slots(), "slots": Bag.slots()}) and ok
	Save.bag = {}
	# Done closes the visit: nothing can be undone afterwards
	hud.p_actions.place_button.pressed.emit()
	await t._wait(0.3)
	var can_before: bool = d.can_undo_place()
	hud.p_actions.done_button.pressed.emit()
	await t._wait(0.3)
	ok = _x("Done ends the visit: no ghost, no placing, and the last placement can no longer be undone", can_before and d.placing == "" and d.ghost == null
		and not d.can_undo_place() and not hud.p_actions.undo_button.visible) and ok
	d.stop_placing()
	return ok


# ---------------------------------------------------------------- taps on pieces (the real touch path)
func _screen(world: Vector3) -> Vector2:
	return main.cam.unproject_position(world)


func _check_taps() -> bool:
	var d = main.defences
	var hud = main.hud
	_bare_camp()
	t._veteran(3)
	_rich()
	Save.camp_level = 3
	main.stations.refresh("all")
	var spot_t: Vector3 = _spot("tower", 0)
	var spot_s: Vector3 = _spot("tower", 6)
	var tower: Dictionary = _put("tower", spot_t, 1)
	var patch: Dictionary = _put("spikes", spot_s, 1)
	var pad: Vector2i = t.build_any_row()
	var row: Dictionary = d.row_at(pad.x, pad.y)
	var ok: bool = _x("a tower, a patch and a row stand for the tap checks", not tower.is_empty() and not patch.is_empty() and not row.is_empty())
	if not ok:
		return false
	var tm: Node = d.piece_marker("tower", int(tower["id"]), NO_SLOT)
	var sm: Node = d.piece_marker("spikes", int(patch["id"]), NO_SLOT)
	var rm: Node = d.piece_marker("barricade", -1, pad)
	ok = _x("each piece has a marker with its own key", tm != null and sm != null and rm != null and String(tm.key) == "tower_%d" % int(tower["id"])
		and String(sm.key) == "spikes_%d" % int(patch["id"]) and String(rm.key) == "road_%d_%d" % [pad.x, pad.y]) and ok
	if tm == null or sm == null or rm == null:
		return false
	# a healthy tower, from beside it
	main.player.global_position = spot_t + Vector3(1.4, 0, 0)
	main.snap_camera()
	await t._wait(0.4)
	hud.hide_card()
	var shown: bool = await t._tap(tm)
	await t._until(func() -> bool: return hud.card_ring() == tm, 2.0)
	ok = _x("a real tap on a healthy tower opens its card (its title, its level, an Upgrade, no Repair)", shown and hud.card_ring() == tm
		and hud.card_title() == String(Data.defence_info("tower")["name"]) and hud.p_card.footer_button(Data.word("upgrade")) != null
		and not bool(main.defences.repair_quote("tower", int(tower["id"]), NO_SLOT)["show"]), {"shown": shown, "ring": hud.card_ring() == tm, "title": hud.card_title(), "up": hud.p_card.footer_button(Data.word("upgrade")) != null}) and ok
	await t._shot("workshop_piece_card")
	hud.hide_card()
	# the patch
	main.player.global_position = spot_s + Vector3(1.4, 0, 0)
	main.snap_camera()
	await t._wait(0.4)
	shown = await t._tap(sm)
	await t._until(func() -> bool: return hud.card_ring() == sm, 2.0)
	ok = _x("a tap on a patch opens its card (never a Repair)", shown and hud.card_ring() == sm and not bool(d.repair_quote("spikes", int(patch["id"]), NO_SLOT)["show"])) and ok
	hud.hide_card()
	# either end of a row
	var pieces: Array = row["pieces"]
	main.player.global_position = (row["root"] as Node3D).global_position + Vector3(0, 0, 1.6)
	main.snap_camera()
	await t._wait(0.4)
	var both: bool = true
	for end: int in [0, pieces.size() - 1]:
		hud.hide_card()
		var at: Vector3 = (pieces[end]["pos"] as Vector3) + Vector3(0, 0.35, 0)
		var sp: Vector2 = _screen(at)
		await t._tap_at(sp)
		await t._until(func() -> bool: return hud.card_ring() == rm, 1.5)
		both = both and hud.card_ring() == rm
	ok = _x("a tap on either end of a row opens the row's card", both) and ok
	hud.hide_card()
	# the downed tower: its badge, and a tap opens the Repair card
	d.hurt_piece(int(tower["id"]), 999999)
	await t._wait(0.3)
	ok = _x("a downed tower shows the repair badge", tm.visible and String(tm.icon) == "repair" and bool(d.repair_quote("tower", int(tower["id"]), NO_SLOT)["show"])) and ok
	main.player.global_position = spot_t + Vector3(1.4, 0, 0)
	main.snap_camera()
	await t._wait(0.3)
	shown = await t._tap(tm)
	await t._until(func() -> bool: return hud.card_ring() == tm, 2.0)
	ok = _x("a tap on the downed tower opens a card with Repair", hud.card_ring() == tm and _has_button("Repair")) and ok
	hud.hide_card()
	d.repair_placed("tower", int(tower["id"]), NO_SLOT)
	# bare ground, a HUD-origin touch, a drag
	var ground: Vector3 = spot_t + Vector3(-4.0, 0, 3.0)
	await t._tap_at(_screen(ground))
	await t._wait(0.2)
	ok = _x("a tap on bare ground opens no card", not hud.card_open() or hud.card_ring() == null) and ok
	hud.hide_card()
	var before_ring: Node = hud.card_ring()
	await t._tap_at(hud.bag_button.get_global_rect().get_center())
	await t._wait(0.3)
	ok = _x("a touch that starts on a HUD button does not reach a piece under it", hud.card_ring() != tm and hud.card_ring() != sm and hud.card_ring() != rm, {"before": before_ring}) and ok
	hud.hide_card()
	var start: Vector2 = _screen(spot_t + Vector3(0, 0.3, 0))
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = get_viewport().get_final_transform() * start
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	for k: int in 6:
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = down.position + Vector2(18.0 * float(k + 1), 0.0)
		drag.relative = Vector2(18.0, 0.0)
		Input.parse_input_event(drag)
		await get_tree().process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = down.position + Vector2(108.0, 0.0)
	up.pressed = false
	Input.parse_input_event(up)
	await t._wait(0.3)
	ok = _x("a drag that starts on a piece steers the cat and opens no card", hud.card_ring() != tm) and ok
	hud.hide_card()
	# an active ghost: pieces do not open
	Bag.return_defence("tower", {"level": 1}, false)
	main.player.global_position = spot_t + Vector3(1.4, 0, 0)
	d.start_placing("tower")
	await t._wait(0.3)
	await t._tap_at(_screen(spot_t + Vector3(0, 0.3, 0)))
	await t._wait(0.3)
	ok = _x("while the ghost is out a tap on a piece opens no card", d.placing == "tower" and hud.card_ring() != tm) and ok
	d.stop_placing()
	hud.hide_card()
	_drain("tower")
	# walking to a marker from a distance, then the card opens by itself
	main.player.global_position = spot_t + Vector3(9.0, 0, 0)
	main.snap_camera()
	await t._wait(0.4)
	await t._tap(tm)
	var walked: bool = await t._until(func() -> bool: return hud.card_ring() == tm, 20.0)
	ok = _x("a tap from far away walks the cat to the piece and its card opens", walked and hud.card_ring() == tm) and ok
	hud.hide_card()
	# a neighbouring building still opens with today's rule
	var ring = main.stations.rings["workshop"]
	main.player.global_position = ring.global_position + Vector3(0, 0, 1.0)
	main.snap_camera()
	await t._wait(0.4)
	await t._tap(ring)
	await t._until(func() -> bool: return hud.card_ring() == ring, 2.0)
	ok = _x("a tap on the Workshop building itself opens the Workshop's card", hud.card_ring() == ring) and ok
	hud.hide_card()
	return ok


# ---------------------------------------------------------------- upgrades, levels, gates and the confirm
func _check_levels() -> bool:
	var d = main.defences
	var st = main.stations
	var hud = main.hud
	_bare_camp()
	t._veteran(3)
	_rich()
	Save.camp_level = 3
	Save.stations["workshop"] = 3
	st.refresh("all")
	var a: Dictionary = _put("tower", _spot("tower", 0), 1)
	var b: Dictionary = _put("tower", _spot("tower", 2), 1)
	var sa: Dictionary = _put("spikes", _spot("spikes", 4), 1)
	var sb: Dictionary = _put("spikes", _spot("spikes", 7), 1)
	var r1: Vector2i = t.build_any_row()
	var r2: Vector2i = t.build_any_row()
	var ra: Dictionary = d.row_at(r1.x, r1.y)
	var rb: Dictionary = d.row_at(r2.x, r2.y)
	var ok: bool = _x("two of each kind stand at level 1", not a.is_empty() and not b.is_empty() and not sa.is_empty() and not sb.is_empty() and not ra.is_empty() and not rb.is_empty()
		and r1 != r2)
	if not ok:
		return false
	# the card path once: marker -> card -> Upgrade -> the confirm -> Confirm (and Cancel), with a worn tower
	d._wreck(a, 0.4)
	d._save_wrecks()
	var am: Node = d.piece_marker("tower", int(a["id"]), NO_SLOT)
	await t._at_ring(am)
	await t._wait(0.4)
	var up: Button = hud.p_card.footer_button(Data.word("upgrade"))
	ok = _x("the worn tower's card offers Upgrade (no Repair: it is only worn)", up != null and not up.disabled and not bool(d.repair_quote("tower", int(a["id"]), NO_SLOT)["show"])) and ok
	up.pressed.emit()
	await t._wait(0.4)
	ok = _x("Upgrade opens the confirm with the price and what the next level gives", hud.card_ring() == hud.confirm and hud.card_title().contains("2")) and ok
	await t._shot("workshop_confirm")
	var cancel: Button = hud.p_card.footer_button(Data.word("cancel"))
	if cancel != null:
		cancel.pressed.emit()
	await t._wait(0.4)
	ok = _x("Cancel goes back to the piece's card and spends nothing", hud.card_ring() == am and d.piece_level(a) == 1) and ok
	Save.leaves = 50
	hud.p_card.footer_button(Data.word("upgrade")).pressed.emit()
	await t._wait(0.4)
	var ok_btn: Button = hud.p_card.footer_button(Data.word("confirm"))
	ok = _x("an unaffordable Confirm is grey", ok_btn != null and ok_btn.disabled) and ok
	_rich()
	hud.refresh_card()
	await t._wait(0.3)
	ok_btn = hud.p_card.footer_button(Data.word("confirm"))
	var l0: int = Save.leaves
	var t0: int = Save.timber
	ok_btn.pressed.emit()
	await t._wait(0.5)
	var rec_a: Dictionary = _dict(a.get("src"))
	ok = _x("Confirm upgrades this one tower: level 2, whole, its wear cleared in the piece and in the saved record, 220 leaves paid",
		d.piece_level(a) == 2 and float(a["hp"]) >= float(a["max_hp"]) - 0.01 and not a["wrecked"] and not rec_a.has("wreck") and int(rec_a.get("level", 0)) == 2
		and _cost_eq(_spent(l0, t0), TIERS["tower"][1]), {"spent": _spent(l0, t0), "record": rec_a}) and ok
	hud.hide_card()
	# the same piece compared with its untouched twin
	var tower_a = a["node"]
	var tower_b = b["node"]
	var sa_stats: Dictionary = d.level_stats("tower", 2)
	var sb_stats: Dictionary = d.level_stats("tower", 1)
	ok = _x("the upgraded tower has more health, a faster cadence, a longer range, a better arrow and its own model than its twin",
		float(a["max_hp"]) > float(b["max_hp"]) and is_equal_approx(float(a["max_hp"]), float(sa_stats["hp"])) and is_equal_approx(float(b["max_hp"]), float(sb_stats["hp"]))
		and float(sa_stats["every"]) < float(sb_stats["every"]) and float(sa_stats["range"]) > float(sb_stats["range"]) and float(sa_stats["damage"]) > float(sb_stats["damage"])
		and int(tower_a.level) == 2 and int(tower_b.level) == 1 and String(tower_a.name).begins_with("acorn_tower_2") and not String(tower_b.name).begins_with("acorn_tower_2"),
		{"a": sa_stats, "b": sb_stats, "na": String(tower_a.name), "nb": String(tower_b.name), "la": tower_a.level, "lb": tower_b.level}) and ok
	# a patch
	var sa_before: float = float(d.slow_at((sa["pos"] as Vector3)))
	l0 = Save.leaves
	ok = _x("a patch upgrades alone for 180 leaves: stronger slow and damage than its twin, its own model",
		d.upgrade_placed("spikes", int(sa["id"]), NO_SLOT, 1) and d.piece_level(sa) == 2 and d.piece_level(sb) == 1 and _cost_eq(_spent(l0, Save.timber), {"leaves": 180})
		and float(d.slow_at(sa["pos"])) > float(d.slow_at(sb["pos"])) and sa_before < float(d.slow_at(sa["pos"]))
		and float(d.level_stats("spikes", 2)["dps"]) > float(d.level_stats("spikes", 1)["dps"]) and String((sa["node"] as Node3D).name).begins_with("thorn_spikes_2")
		and not String((sb["node"] as Node3D).name).begins_with("thorn_spikes_2"), {"sa": String((sa["node"] as Node3D).name), "sb": String((sb["node"] as Node3D).name), "slow": [d.slow_at(sa["pos"]), d.slow_at(sb["pos"]), sa_before], "lv": [d.piece_level(sa), d.piece_level(sb)]}) and ok
	# a row with a broken section: the whole row mends, the saved wrecks clear
	var pcs: Array = ra["pieces"]
	d.hurt_piece(int(pcs[0]["id"]), 999999)
	d.hurt_piece(int(pcs[1]["id"]), int(float(pcs[1]["max_hp"]) * 0.7))
	d._wreck(pcs[0], 0.0)
	d._wreck(pcs[1], 0.3)
	d._save_wrecks()
	var rec_row: Dictionary = _dict(ra.get("src"))
	var had_wrecks: bool = rec_row.has("wrecks") or rec_row.has("wreck")
	l0 = Save.leaves
	var before_hp: float = float(pcs[2]["max_hp"])
	ok = _x("a row with a broken section upgrades for 200 leaves: every section is whole at the new health, the wrecks clear, its twin stays level 1",
		had_wrecks and d.upgrade_placed("barricade", -1, r1, 1) and d.row_level(ra) == 2 and d.row_level(rb) == 1
		and pcs.all(func(p: Dictionary) -> bool: return float(p["hp"]) >= float(p["max_hp"]) - 0.01 and not p["wrecked"] and not p["broken"] and d.piece_level(p) == 2)
		and float(pcs[2]["max_hp"]) > before_hp and not rec_row.has("wrecks") and not rec_row.has("wreck") and int(rec_row.get("level", 0)) == 2
		and _cost_eq(_spent(l0, Save.timber), {"leaves": 200}) and not d.row_broken(ra), {"record": rec_row}) and ok
	ok = _x("the twin row is untouched (health and level 1 for all its sections)", (rb["pieces"] as Array).all(func(p: Dictionary) -> bool: return d.piece_level(p) == 1)
		and is_equal_approx(float((rb["pieces"] as Array)[0]["max_hp"]), float(d.level_stats("barricade", 1)["hp"]))) and ok
	# stale, missing and money-short targets spend nothing
	l0 = Save.leaves
	var stale: bool = d.upgrade_placed("tower", int(a["id"]), NO_SLOT, 1)
	var gone: bool = d.upgrade_placed("tower", 999999, NO_SLOT, 1)
	var reason_stale: String = String(d.upgrade_quote("tower", int(a["id"]), NO_SLOT, 1)["reason"])
	ok = _x("an upgrade for a level that has changed, or for a piece that is gone, spends nothing and says why", not stale and not gone and Save.leaves == l0
		and reason_stale == Data.word("upgrade_stale") and String(d.upgrade_quote("tower", 999999, NO_SLOT, 1)["reason"]) == Data.word("upgrade_gone"),
		{"stale": reason_stale}) and ok
	Save.leaves = 10
	ok = _x("a quote never gives money as a reason, and a purchase without the money fails whole", String(d.upgrade_quote("tower", int(b["id"]), NO_SLOT, 1)["reason"]) == ""
		and not d.upgrade_placed("tower", int(b["id"]), NO_SLOT, 1) and d.piece_level(b) == 1 and Save.leaves == 10) and ok
	_rich()
	# the gates: the Workshop's own level, then the raids, then the Burrows
	Save.stations["workshop"] = 2
	var q3: Dictionary = d.upgrade_quote("tower", int(a["id"]), NO_SLOT, 2)
	ok = _x("a level-2 Workshop caps pieces at 2: level 3 says Needs Workshop lv 3", d.piece_cap("tower") == 2 and String(q3["reason"]) == Data.word("upgrade_cap") % 3 and not d.upgrade_placed("tower", int(a["id"]), NO_SLOT, 2),
		{"q": q3}) and ok
	Save.stations["workshop"] = 4
	var saved_missions: Array = Save.missions_done.duplicate()
	var left_missions: Array = []
	for i: int in Data.mission_count():
		left_missions.append(String(Data.mission(i)["id"]))
	Save.missions_done = left_missions.slice(0, Data.mission_count() - 1)
	d.upgrade_placed("tower", int(a["id"]), NO_SLOT, 2)
	var q4: Dictionary = d.upgrade_quote("tower", int(a["id"]), NO_SLOT, 3)
	ok = _x("level 4 needs every Raid Mission won even with a level-4 Workshop: capped at 3 with the raids word", not Data.raids_open() and d.piece_cap("tower") == 3
		and int(q4["next_level"]) == 4 and String(q4["reason"]) == Data.word("needs_raids") and not d.upgrade_placed("tower", int(a["id"]), NO_SLOT, 3), {"q": q4}) and ok
	Save.missions_done = left_missions
	main.raids.refresh_open()
	l0 = Save.leaves
	t0 = Save.timber
	var s0: int = Save.shards
	ok = _x("with every raid won level 4 is allowed: timber, no shards (tower 2,400 leaves and 30 timber), per piece", Data.raids_open() and d.piece_cap("tower") == 4
		and d.upgrade_placed("tower", int(a["id"]), NO_SLOT, 3) and d.piece_level(a) == 4 and _cost_eq(_spent(l0, t0), TIERS["tower"][3]) and Save.shards == s0,
		{"spent": _spent(l0, t0)}) and ok
	Save.stations["workshop"] = 5
	var q5: Dictionary = d.upgrade_quote("tower", int(a["id"]), NO_SLOT, 4)
	ok = _x("level 5 needs the Burrows even with a level-5 Workshop", not Data.burrows_open() and d.piece_cap("tower") == 4 and int(q5["next_level"]) == 5
		and String(q5["reason"]) != "" and String(q5["reason"]) != Data.word("upgrade_cap") % 5 and not d.upgrade_placed("tower", int(a["id"]), NO_SLOT, 4), {"q": q5}) and ok
	main.burrows.open_hollow(false)
	main.raids.refresh_open()
	var quote5: Dictionary = d.upgrade_quote("tower", int(a["id"]), NO_SLOT, 4)
	l0 = Save.leaves
	t0 = Save.timber
	ok = _x("with the Burrows open the level-5 quote and price are leaves only (5,760) and it upgrades", Data.burrows_open() and d.piece_cap("tower") == 5 and String(quote5["reason"]) == ""
		and _cost_eq(quote5["price"], {"leaves": 5760}) and d.upgrade_placed("tower", int(a["id"]), NO_SLOT, 4) and d.piece_level(a) == 5 and Save.leaves == l0 - 5760 and Save.timber == t0
		and String(tower_node_name(a)).begins_with("acorn_tower_5")) and ok
	ok = _x("a level-5 piece has no next upgrade (Max level)", int(d.upgrade_quote("tower", int(a["id"]), NO_SLOT, 5)["next_level"]) == 0) and ok
	# the Workshop's cap preview and its own upgrade confirm
	Save.stations["workshop"] = 1
	Save.camp_level = 3
	st.refresh("all")
	var win = main.hud.windows["workshop"]
	await t._at_ring(st.rings["workshop"])
	await t._wait(0.4)
	win.ask_upgrade()
	await t._wait(0.4)
	ok = _x("the Workshop's own Upgrade opens a confirm that lists what level 2 gives and Confirm raises it", hud.card_ring() == hud.confirm) and ok
	await t._shot("workshop_upgrade_confirm")
	var confirm_btn: Button = hud.p_card.footer_button(Data.word("confirm"))
	if confirm_btn != null:
		confirm_btn.pressed.emit()
	await t._wait(0.5)
	ok = _x("Confirm raises the Workshop to level 2, and the card returns to the tab it came from", Data.station_level("workshop") == 2 and win.tab == "defences") and ok
	hud.hide_card()
	return ok


func tower_node_name(p: Dictionary) -> String:
	return String((p["node"] as Node3D).name)


func _has_button(label: String) -> bool:
	for b in main.hud.card_buttons():
		if String(b.get_meta("label", "")) == label and not b.disabled:
			return true
	return false


# ---------------------------------------------------------------- repair, the Well, the Hearthtree's goals and raid weights
func _check_repair() -> bool:
	var d = main.defences
	var st = main.stations
	var rd = main.raids
	var hud = main.hud
	_bare_camp()
	t._veteran(3)
	_rich()
	Save.camp_level = 3
	Save.stations["workshop"] = 3
	Save.ruined = []
	st.refresh("all")
	var tw: Dictionary = _put("tower", _spot("tower", 0), 2)
	var pad: Vector2i = t.build_any_row()
	var row: Dictionary = d.row_at(pad.x, pad.y)
	var ok: bool = _x("a level-2 tower and a row stand", not tw.is_empty() and not row.is_empty())
	if not ok:
		return false
	var id: int = int(tw["id"])
	# a worn but standing tower has no Repair (the Well mends it); a downed one has, at the mend price
	d._wreck(tw, 0.5)
	d._save_wrecks()
	var q_worn: Dictionary = d.repair_quote("tower", id, NO_SLOT)
	var l0: int = Save.leaves
	ok = _x("a worn, standing tower shows no Repair and Repair spends nothing", not bool(q_worn["show"]) and not d.repair_placed("tower", id, NO_SLOT) and Save.leaves == l0, {"q": q_worn}) and ok
	for i: int in 140:
		d.well_mend(0.1, 0.05, 1.0)
	ok = _x("the Wishing Well mends the standing wear on its own, to full", not tw["wrecked"] and float(tw["hp"]) >= float(tw["max_hp"]) - 0.01) and ok
	d.hurt_piece(id, 999999)
	await t._wait(0.2)
	var q_down: Dictionary = d.repair_quote("tower", id, NO_SLOT)
	var want: int = int(d.mend_price(tw))
	ok = _x("a downed tower shows Repair at the mend price", bool(q_down["show"]) and String(q_down["reason"]) == "" and int((q_down["price"] as Dictionary).get("leaves", 0)) == want and want > 0, {"q": q_down}) and ok
	for i: int in 40:
		d.well_mend(0.1, 0.05, 1.0)
	ok = _x("the Well never lifts a downed tower", float(tw["hp"]) <= 0.0) and ok
	# a wave: a row repairs, a tower waits
	main.fight.active = true
	main.fight.in_wave = true
	var q_wave: Dictionary = d.repair_quote("tower", id, NO_SLOT)
	ok = _x("in a wave a downed tower cannot be repaired", not d.repair_placed("tower", id, NO_SLOT) and (String(q_wave["reason"]) != "" or not bool(q_wave["show"])), {"q": q_wave}) and ok
	var pcs: Array = row["pieces"]
	d.hurt_piece(int(pcs[0]["id"]), 999999)
	d.hurt_piece(int(pcs[1]["id"]), int(float(pcs[1]["max_hp"]) * 0.7))
	var rq: Dictionary = d.repair_quote("barricade", -1, pad)
	l0 = Save.leaves
	ok = _x("in a wave a row with a broken section shows Repair and repairs for its own price", bool(rq["show"]) and d.repair_placed("barricade", -1, pad)
		and Save.leaves < l0 and not d.row_broken(row) and pcs.all(func(p: Dictionary) -> bool: return float(p["hp"]) >= float(p["max_hp"]) - 0.01), {"q": rq}) and ok
	d.hurt_piece(int(pcs[1]["id"]), int(float(pcs[1]["max_hp"]) * 0.6))
	ok = _x("a row that is only cracked shows no Repair (the Well mends it)", not bool(d.repair_quote("barricade", -1, pad)["show"])) and ok
	main.fight.active = false
	main.fight.in_wave = false
	l0 = Save.leaves
	ok = _x("between waves the downed tower repairs for the mend price and stands whole", d.repair_placed("tower", id, NO_SLOT) and l0 - Save.leaves == want
		and float(tw["hp"]) >= float(tw["max_hp"]) - 0.01) and ok
	# the Hearthtree's Mend all: buildings only, defences never in its price
	d.hurt_piece(id, 999999)
	d._wreck(pcs[2], 0.3)
	Save.wear["stall"] = 0.5
	st.refresh()
	var cc: Dictionary = rd.camp_check()
	var wrecks: int = (cc["items"] as Array).filter(func(i: Dictionary) -> bool: return String(i["kind"]) == "wreck").size()
	var pay_kinds: Array = (cc["pay"] as Array).map(func(i: Dictionary) -> String: return String(i["kind"]))
	ok = _x("the camp check counts broken defences in its items but never in what Mend all and Mend some pay", wrecks >= 1 and not pay_kinds.has("wreck") and pay_kinds.has("wear"),
		{"pay": pay_kinds, "wrecks": wrecks}) and ok
	rd.mend_all()
	await t._wait(0.4)
	ok = _x("Mend all mends the building and leaves the downed tower for its own card", not Save.wear.has("stall") and float(tw["hp"]) <= 0.0) and ok
	d.repair_placed("tower", id, NO_SLOT)
	# raid weights read the pieces as before: a lane's guard is its barricade health plus a fixed bonus per tower in reach
	var cfg: Dictionary = Data.gr()["lane_guard"]
	var lane: int = pad.x
	var expect: float = 0.0
	var mid: Vector3 = main.world.trail_point(lane, 0.5 * main.world.trail_length(lane))
	for p: Dictionary in d.pieces:
		if float(p["hp"]) <= 0.0:
			continue
		if p["type"] == "barricade" and int((p["slot"] as Array)[0]) == lane:
			expect += float(p["hp"])
		elif p["type"] == "tower" and (p["pos"] as Vector3).distance_to(mid) <= float(Data.defence_level_info("tower", d.piece_level(p)).get("range", 5.0)) + float(cfg["tower_reach_bonus"]):
			expect += float(cfg["tower"])
	ok = _x("the lane guard (a raid weight) is the pieces' health and towers' bonus as before, with mixed levels", is_equal_approx(float(d.lane_guard(lane)), expect), {"got": d.lane_guard(lane), "want": expect}) and ok

	# the Hearthtree's goals read the saved pieces' own levels
	var two: Dictionary = Data._goal({"type": "towers", "level": 3, "count": 2})
	_bare_camp()
	var t1: Dictionary = _put("tower", _spot("tower", 0), 3)
	var t2: Dictionary = _put("tower", _spot("tower", 3), 3)
	d.hurt_piece(int(t2["id"]), 999999)
	var after: Dictionary = Data._goal({"type": "towers", "level": 3, "count": 2})
	var kinds_goal: Dictionary = Data._goal({"type": "defence", "id": "barricade", "level": 2})
	_bare_camp()
	var row_pad: Vector2i = t.build_any_row()
	var rec_row: Dictionary = Save.placed.back()
	var low: Dictionary = Data._goal({"type": "defence", "id": "barricade", "level": 2})
	rec_row["level"] = 3
	var high: Dictionary = Data._goal({"type": "defence", "id": "barricade", "level": 2})
	ok = _x("a towers goal counts saved tower records at the level (a downed one too) and a defence goal reads the best record",
		not bool(two["done"]) and bool(after["done"]) and not bool(kinds_goal["done"]) and not bool(low["done"]) and bool(high["done"]), {"after": after.get("progress"), "low": low.get("progress")}) and ok
	# the real Show and Go routes the Hearthtree's window takes
	var win = hud.windows["shop"]
	_bare_camp()
	Save.stations["workshop"] = 0
	st.refresh("all")
	var g_tower: Dictionary = {"type": "towers", "level": 1, "count": 1, "need": 1}
	var g_bar: Dictionary = {"type": "defence", "id": "barricade", "level": 1}
	var t_build: Dictionary = win._defence_goal_target("tower", g_tower)
	var t_pad: Dictionary = win._defence_goal_target("barricade", g_bar)
	Save.stations["workshop"] = 3
	st.refresh("all")
	var t_shop: Dictionary = win._defence_goal_target("tower", g_tower)
	Bag.return_defence("tower", {"level": 1}, false)
	var t_bag: Dictionary = win._defence_goal_target("tower", g_tower)
	_drain("tower")
	var placed_t: Dictionary = _put("tower", _spot("tower", 0), 1)
	var g_lv3: Dictionary = {"type": "towers", "level": 3, "count": 1, "need": 1}
	Save.stations["workshop"] = 2
	var t_wk: Dictionary = win._defence_goal_target("tower", g_lv3)
	Save.stations["workshop"] = 5
	var t_piece: Dictionary = win._defence_goal_target("tower", g_lv3)
	var marker_want: Node = d.goal_marker("tower", 3)
	ok = _x("a tower goal with no Workshop built leads to the build menu at the Workshop", t_build.get("build") == "workshop", {"t": t_build.keys()}) and ok
	ok = _x("a barricade goal with no row leads to the nearest open empty pad", t_pad.has("ring") and t_pad["ring"] == d.empty_pad_marker(), {"t": t_pad.keys()}) and ok
	ok = _x("a tower goal with the Workshop built and nothing held leads to the Workshop; a held tower leads to the Bag", t_shop.get("workshop") == true and t_bag.get("bag") == "tower", {"shop": t_shop.keys(), "bag": t_bag.keys()}) and ok
	ok = _x("a level goal beyond the Workshop's level leads to the Workshop, and to the piece below it once the Workshop is high enough", (t_wk.get("workshop") == true or placed_t.is_empty())
		and t_piece.has("ring") and t_piece["ring"] == marker_want and marker_want != null, {"wk": t_wk.keys(), "piece": t_piece.keys()}) and ok
	_drain("tower")
	Save.stations["workshop"] = 3
	return ok


