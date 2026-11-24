extends Node
## Phase G2: barricade rows and tower repair (`-- --autotest --fresh --rows`), run from autotest.gd. Each check logs
## "EXPECT PASS <what>" or "EXPECT FAIL <what>" through autotest.gd's _expect. Light on purpose: the numbers come from
## balance.json (defences.barricade: row, rings_by_home, crack_at, repair_share, piece; defences.tower.piece; for the
## tower's Mend price raid.repair_share and gloom_raids.repair) and no fight is played.
##   (a) an old save (2 barricades placed, one of them wrecked, a second piece on one spot; 3 in the bag) loads as 2 rows
##       and a leaf refund; the bag and the build button have no barricades; rows load again from the save; pieces put
##       in the bag later (an older mission gift) are refunded too
##   (b) the pads open as the Hearthtree grows (1-2: 4, 3: 8, 4: 10, 5+: 12); a row on a closed pad from an old save
##       stays and can be repaired; every open empty pad can be built; the card explains why Build is disabled
##   (c) one piece hurt below crack_at: cracked (darker, tilted), the others whole; broken: flat, a rubble pile, no
##       collision, and a walker passes the gap (a whole piece still stops it)
##   (d) a row's repair costs its share (a broken piece and a cracked one) and mends every piece
##   (e) a knocked-down tower tips over and shows its repair marker; its card repairs it for the Mend price (the same
##       as "Mend the defences" for that tower alone, during the missions and after them)
##   (f) well_mend raises a cracked piece but never a broken one, clamps a long frame, stops at the cap, never above full
##   (g) screenshots: a row whole, cracked and broken; a road spot's, a row's and a downed tower's cards

var t                     # autotest.gd (its helpers: _wait, _shot, _expect, _until, _at_ring, _log)
var main
var d                     # main.defences
var lane := 0             # the road whose rows the camera sees face on (for the pictures)


func run() -> bool:
	main.player.invincible = true
	d = main.defences
	lane = _face_lane()
	await t._wait(0.3)
	await _old_save()
	await _build()
	await _damage()
	await _repair()
	_spacing()
	await _wave_repair()
	await _tower()
	_well()
	var towers = load("res://scripts/autotest_towers.gd").new()
	towers.t = t
	towers.main = main
	add_child(towers)
	await towers.run()
	main.closeup = Vector3.ZERO
	main.closeup_at = null
	return true


func _x(what: String, ok: bool, extra := {}) -> bool:
	return t._expect(what, ok, extra)


func _bi() -> Dictionary:
	return Data.defence_info("barricade")


## The road whose rows run most across the camera's view (the camera looks north: a row running east-west).
func _face_lane() -> int:
	var best := 0
	var best_c := -1.0
	for s in main.world.barricade_slots():
		var c := absf(cos(float(s[1])))
		if c > best_c:
			best_c = c
			best = int(s[2])
	return best


## The road spots in the order the tests build them: the face-on road's three, then the others'.
func _spot_list() -> Array:
	var out: Array = [[lane, 0], [lane, 1], [lane, 2]]
	for s in main.world.barricade_slots():
		if int(s[2]) != lane:
			out.append([int(s[2]), int(s[3])])
	return out


## The first shop tile of a card with this button.
func _item(spec: Dictionary, label: String) -> Dictionary:
	for r in spec.get("rows", []):
		if String(r.get("kind", "")) == "item" and String(r.get("label", "")) == label:
			return r
	return {}


func _same_cost(a: Dictionary, b: Dictionary) -> bool:
	for k in ["leaves", "timber"]:
		if int(a.get(k, 0)) != int(b.get(k, 0)):
			return false
	return true


## The gloom shade on a model (its first mesh): how dark the props' shader draws it.
func _gloom(n) -> float:
	if not is_instance_valid(n):
		return -1.0
	var stack: Array = [n]
	while not stack.is_empty():
		var c = stack.pop_back()
		if c is GeometryInstance3D:
			var v = (c as GeometryInstance3D).get_instance_shader_parameter("gloom")
			return float(v) if v != null else 0.0
		for ch in c.get_children():
			stack.append(ch)
	return -1.0


func _tilt(p: Dictionary) -> float:
	return absf((p["node"] as Node3D).rotation.x)


## The piece's collision is in the world (enemies bump into it).
func _has_seg(p: Dictionary) -> bool:
	var tag := "piece_%d" % int(p["id"])
	for s in main.world.segments:
		if String(s[4]) == tag:
			return true
	return false


## A walker of radius r going straight across the row through piece p, from the woods' side to the camp's, pushed by
## the world's collision as an enemy is (world.constrain). Returns how far past the row it got (metres; < 0: held).
func _walk_through(p: Dictionary, r: float) -> float:
	var rot := float(p["rot"])
	var woods := Vector3(sin(rot), 0.0, cos(rot))
	var c: Vector3 = p["pos"]
	var q := c + woods * 1.2                       # (the next row up the road stands some 3 m further)
	for i in 48:
		q -= woods * 0.05
		q = main.world.constrain(q, r, true)
	return -(q - c).dot(woods)


# ---------------------------------------------------------------- (a) an old save
func _old_save() -> void:
	Save.missions_done = [String(Data.mission(0)["id"])]          # barricades open after mission 1
	Save.mission_run = {}
	Save.camp_level = 1
	Save.leaves = 100
	Save.timber = 0
	Save.def_levels = {"barricade": 1, "tower": 1, "spikes": 1}
	Save.items = {"barricade": 3, "tower": 0, "spikes": 0}
	Save.placed = [{"type": "barricade", "slot": [lane, 0]}, {"type": "barricade", "slot": [lane, 1], "wreck": 0.4},
		{"type": "barricade", "slot": [lane, 0]}]
	Save.save_game()
	Save.load_game()                                                # read back through save.gd, as an old save is
	d.load_saved()
	main.hud.refresh_build()
	await t._wait(0.2)
	var piece := int(_bi().get("piece", 30))
	var per: int = d.pieces_per_row()
	_x("an old save's 2 placed barricades load as 2 rows (two pieces on one spot make one row)", d.rows.size() == 2
		and not d.row_at(lane, 0).is_empty() and not d.row_at(lane, 1).is_empty(), {"rows": d.rows.size()})
	var ok_pieces := true
	for row in d.rows:
		ok_pieces = ok_pieces and (row["pieces"] as Array).size() == per
	_x("each row has %d pieces (balance.json barricade.row.pieces)" % per, ok_pieces and per == int(_bi()["row"]["pieces"]))
	_x("the 3 barricades in the bag are refunded as leaves (%d each)" % piece, Save.leaves == 100 + 3 * piece, {"leaves": Save.leaves})
	_x("the bag has no barricades", int(Save.items.get("barricade", 0)) == 0)
	var labels: Array = main.hud.build_buttons().map(func(b): return String(b.get_meta("label", "")))
	_x("the build button offers no barricades", not labels.any(func(l): return String(l).begins_with("Barricade")), {"buttons": labels})
	_x("the wrecked barricade's damage is kept in every piece of its row", _wrecked_at(d.row_at(lane, 1), 0.4))
	var saved: Array = Save.placed.filter(func(sp): return String(sp.get("type", "")) == "barricade")
	_x("the save holds the 2 rows (their spot and pieces)", saved.size() == 2 and saved.all(func(sp): return sp.has("row") and sp.has("slot")),
		{"placed": saved})
	# the new format reads back the same
	Save.save_game()
	Save.load_game()
	d.load_saved()
	_x("rows and their kept damage load again from the save", d.rows.size() == 2 and _wrecked_at(d.row_at(lane, 1), 0.4))
	# pieces put in the bag later (an older mission's gift) are refunded the same way
	var before := Save.leaves
	Save.items["barricade"] = 2
	await t._wait(0.2)
	_x("barricade pieces put in the bag later are refunded too", not Save.items.has("barricade") and Save.leaves == before + 2 * piece,
		{"leaves": Save.leaves, "before": before})


func _wrecked_at(row: Dictionary, share: float) -> bool:
	if row.is_empty():
		return false
	for p in row["pieces"]:
		if not p["wrecked"] or absf(float(p["hp"]) / float(p["max_hp"]) - share) > 0.01:
			return false
	return true


# ---------------------------------------------------------------- (b) building rows: the pads open ring by ring
func _vis_count(idx: int) -> int:
	var n := 0
	for key in d._spots:
		var pr: PackedStringArray = String(key).split(":")
		if int(pr[1]) == idx and d._spots[key].visible:
			n += 1
	return n


func _build() -> void:
	var old_lane := (lane + 1) % 4                                  # an old save's row on a far pad (not open at level 1)
	Save.placed = [{"type": "barricade", "slot": [old_lane, 0], "row": d.pieces_per_row()}]
	d.load_saved()
	Save.camp_level = 1
	Save.leaves = 1000
	Save.timber = 100
	main.hud.refresh_build()
	await t._wait(0.3)
	var cost: Dictionary = d.row_cost()
	var rings: Array = _bi()["rings_by_home"]
	_x("rings_by_home is [0, 1, 1, 2, 2, 3, 3, 3, 3]", rings.map(func(v): return int(v)) == [0, 1, 1, 2, 2, 3, 3, 3, 3], {"rings": rings})
	_x("a row costs balance.json barricade.row.cost", _same_cost(cost, _bi()["row"]["cost"]) and int(cost.get("leaves", 0)) > 0, {"cost": cost})
	_x("every road spot has a marker (%d)" % main.world.barricade_slots().size(), d._spots.size() == main.world.barricade_slots().size()
		and d._spots.size() == 12, {"spots": d._spots.size()})
	d._refresh_marks()
	_x("level 1: the 4 nearest pads are open and no others", d.rings_open() == 1 and d.pads_open_count() == 4 and d.pad_open(lane, 2)
		and not d.pad_open(lane, 1) and not d.pad_open(lane, 0))
	_x("level 1: only the 4 nearest pads show a marker (+ the old save's row on a far pad)", _vis_count(2) == 4 and _vis_count(1) == 0 and _vis_count(0) == 1,
		{"near": _vis_count(2), "mid": _vis_count(1), "far": _vis_count(0)})
	# an old save's row on a pad that is not open yet: it stays, its marker shows, it can be repaired
	var orow: Dictionary = d.row_at(old_lane, 0)
	var omk = d._spots.get(d._key(old_lane, 0))
	_x("an old save's row on a closed far pad stays and its marker shows", not orow.is_empty() and omk.visible and not d.pad_open(old_lane, 0))
	_x("its tap opens the row's card (not a build card)", d._card_spot(old_lane, 0)["title"] == "Barricade row")
	d.hurt_piece(int(orow["pieces"][0]["id"]), 999999)
	var l_before := Save.leaves
	_x("and it can be repaired", d.repair_row_at(old_lane, 0) and d.piece_stage(orow["pieces"][0]) == "whole" and Save.leaves < l_before)
	Save.leaves = 1000
	Save.timber = 100
	var closed_card := _item(d._card_spot(lane, 1), "Build")
	_x("a closed pad cannot be built, and nothing is paid", not d.build_row(lane, 1) and d.row_at(lane, 1).is_empty() and Save.leaves == 1000
		and not closed_card.is_empty() and not bool(closed_card["enabled"]))
	var mk = d._spots.get(d._key(lane, 2))
	_x("an open pad's marker shows with the barricade badge", mk != null and mk.visible and String(mk.icon) == "barricade")
	main.closeup = Vector3.ZERO
	main.closeup_at = null
	await t._at_ring(mk)
	await t._wait(0.4)
	_x("a tap on an empty open pad opens its card", main.hud.card_ring() == mk, {"title": main.hud.card_title()})
	await t._shot("rows_card_spot")
	var spec: Dictionary = mk.builder.call()
	var it := _item(spec, "Build")
	_x("its card offers a barricade row, with a plain sub line", not it.is_empty() and bool(it["enabled"]) and _same_cost(it["cost"], cost)
		and String(spec["sub"]) == "Barricade row on this road" and not it.has("badge"), {"tile": it.get("title", ""), "sub": spec["sub"]})
	if not it.is_empty():
		(it["action"] as Callable).call()
	main.hud.hide_card()
	_x("Build makes a row there and takes its cost", not d.row_at(lane, 2).is_empty()
		and Save.leaves == 1000 - int(cost.get("leaves", 0)) and Save.timber == 100 - int(cost.get("timber", 0)),
		{"leaves": Save.leaves, "timber": Save.timber})
	# the card's reasons
	var other := (lane + 3) % 4
	var l0 := Save.leaves
	Save.leaves = 0
	var poor := _item(d._card_spot(other, 2), "Build")
	_x("too poor: the tile says what it needs", not bool(poor["enabled"]) and String(poor["text"]) == "Needs %d leaves and %d timber" % [int(cost["leaves"]), int(cost["timber"])],
		{"text": poor.get("text", "")})
	Save.leaves = l0
	var f = main.fight
	var keep := {"active": f.active, "in_wave": f.in_wave}
	f.active = true
	f.in_wave = true
	var wv := _item(d._card_spot(other, 2), "Build")
	_x("a wave is on: the tile says to build between waves", not bool(wv["enabled"]) and String(wv["text"]) == "A wave is on: build between waves", {"text": wv.get("text", "")})
	f.active = keep["active"]
	f.in_wave = keep["in_wave"]
	var md := Save.missions_done
	Save.missions_done = []
	var cl := _item(d._card_spot(other, 2), "Build")
	_x("barricades not open yet: the tile says so", not bool(cl["enabled"]) and String(cl["text"]) == "Barricades open later", {"text": cl.get("text", "")})
	Save.missions_done = md
	d._refresh_marks()
	# every open empty pad can be built: the 4 nearest at level 1
	for ln in 4:
		if d.row_at(ln, 2).is_empty():
			d.build_row(ln, 2)
	_x("level 1: all 4 nearest pads are built", d.rows.size() == 5 and Save.leaves == 1000 - 4 * int(cost["leaves"]), {"rows": d.rows.size(), "leaves": Save.leaves})
	_x("no 'N of M rows' badge any more", not String(_item(d._card_spot(lane, 1), "Build").get("badge", "")).contains("rows"))
	# Level 3 opens the middle ring. Level 4 opens the far pads on the right, and level 5 opens the rest.
	Save.leaves = 1000
	Save.timber = 100
	Save.camp_level = 3
	await t._wait(0.2)
	_x("level 3: the 4 middle pads open (8 in all) and show", d.rings_open() == 2 and d.pads_open_count() == 8 and _vis_count(1) == 4 and _vis_count(0) == 1,
		{"mid": _vis_count(1), "far": _vis_count(0)})
	Save.camp_level = 4
	await t._wait(0.2)
	_x("level 4: 10 pads can be built", d.pads_open_count() == 10)
	var built_mid := 0
	for ln in 4:
		if d.build_row(ln, 1):
			built_mid += 1
	_x("every open empty middle pad can be built", built_mid == 4 and d.rows.size() == 9, {"built": built_mid})
	for ln in Data.patch_count():
		var right: bool = main.world.patch_dir(ln).x > 0.0
		var marker = d._spots[d._key(ln, 0)]
		var was_built := ln == old_lane
		_x("level 4: %s's far pad opens on the right or keeps its older row" % Data.patch(ln)["name"],
			d.pad_open(ln, 0) == right and marker.visible == (right or was_built))
		if not was_built:
			_x("level 4: %s's empty far pad builds only on the right" % Data.patch(ln)["name"], d.build_row(ln, 0) == right)
	Save.camp_level = 5
	await t._wait(0.2)
	_x("level 5: all 12 pads are open and show", d.rings_open() == 3 and d.pads_open_count() == 12 and _vis_count(0) == 4 and _vis_count(1) == 4 and _vis_count(2) == 4)
	for ln in Data.patch_count():
		if d.row_at(ln, 0).is_empty():
			_x("level 5: %s's remaining far pad can be built" % Data.patch(ln)["name"], d.build_row(ln, 0))
	_x("all 12 rows stand", d.rows.size() == 12)
	Save.leaves = 1000
	Save.timber = 100
	_x("the row at the face-on road's nearest spot stands", not d.row_at(lane, 2).is_empty())


# ---------------------------------------------------------------- (c) cracked, broken, the gap
func _damage() -> void:
	var row: Dictionary = d.row_at(lane, 2)
	var ps: Array = row["pieces"]
	var p0: Dictionary = ps[0]
	var p1: Dictionary = ps[1]
	var p2: Dictionary = ps[2]
	var mk = d._spots.get(d._key(lane, 2))
	# the pictures: the row close up, its badge hidden so it does not cover the pieces
	main.player.global_position = Vector3(0, 0, 2.0)
	main.closeup_at = row["root"]
	main.closeup = Vector3(0.0, 3.0, 4.6)
	mk.visible = false
	await t._wait(0.6)
	await t._shot("rows_whole")
	var crack := float(_bi()["crack_at"])
	var mx := float(p1["max_hp"])
	d.hurt_piece(int(p1["id"]), int(ceil(mx * (1.0 - crack))) + 1)
	_x("a piece hurt below %d%% of its health is cracked: darker and tilted" % int(round(crack * 100.0)),
		d.piece_stage(p1) == "cracked" and _gloom(p1["node"]) > 0.1 and _tilt(p1) > 0.05,
		{"stage": d.piece_stage(p1), "gloom": _gloom(p1["node"]), "tilt": _tilt(p1)})
	_x("the other pieces stay whole", d.piece_stage(p0) == "whole" and d.piece_stage(p2) == "whole" and _gloom(p0["node"]) < 0.01
		and _tilt(p0) < 0.01 and _tilt(p2) < 0.01)
	await t._wait(0.4)
	await t._shot("rows_cracked")
	d.hurt_piece(int(p1["id"]), 999999)
	mk.visible = false                                              # (a break refreshes the markers)
	await t._wait(0.8)                                              # it falls over
	var root = row["root"]
	_x("broken at 0: it lies flat", d.piece_stage(p1) == "broken" and bool(p1["broken"]) and _tilt(p1) > 1.2, {"tilt": _tilt(p1)})
	_x("broken: a rubble pile lies by it (only by it)", root.rubble_at(1) != null and root.rubble_at(0) == null and root.rubble_at(2) == null)
	_x("broken: its collision is gone, its neighbours' stay", not _has_seg(p1) and _has_seg(p0) and _has_seg(p2))
	var hit = d.fence_hit(p1["pos"], 0.3)
	_x("no barricade stops a walker standing in the gap", hit == null, {"hit": hit.id if hit != null else -1})
	var past := _walk_through(p1, 0.3)
	var held := _walk_through(p0, 0.3)
	_x("an enemy walks through the gap a broken piece leaves", past > 1.0, {"past_m": snappedf(past, 0.01)})
	_x("a whole piece still stops it", held < 0.0, {"past_m": snappedf(held, 0.01)})
	await t._shot("rows_broken")


# ---------------------------------------------------------------- (d) repairing a row
func _repair() -> void:
	var row: Dictionary = d.row_at(lane, 2)
	var ps: Array = row["pieces"]
	var p2: Dictionary = ps[2]
	var crack := float(_bi()["crack_at"])
	d.hurt_piece(int(p2["id"]), int(ceil(float(p2["max_hp"]) * (1.0 - crack))) + 1)   # a second piece cracked
	var share := float(_bi()["repair_share"])
	var cost: Dictionary = d.row_cost()
	var want := {}
	for k in cost:
		want[k] = int(ceil(float(cost[k]) * share * 1.5 - 0.0001))                   # 1 broken + half for 1 cracked
	var got: Dictionary = d.repair_row_cost(row)
	_x("a row's repair: %d%% of its cost per broken piece, half that per cracked one" % int(round(share * 100.0)),
		_same_cost(got, want), {"got": got, "want": want})
	var card: Dictionary = d._card_spot(lane, 2)
	var it := _item(card, "Repair")
	var tiles: Array = (card["rows"] as Array).filter(func(r): return String(r.get("title", "")).begins_with("Piece"))
	_x("the row's card shows each piece's health and Repair", not it.is_empty() and bool(it["enabled"]) and tiles.size() == ps.size()
		and tiles.all(func(r): return r.has("stats")), {"tiles": tiles.size()})
	main.closeup = Vector3.ZERO
	main.closeup_at = null
	d._refresh_marks()
	var mk = d._spots.get(d._key(lane, 2))
	_x("a damaged row's marker shows its '!' (affordable)", mk.visible and mk.pulse)
	await t._at_ring(mk)
	await t._wait(0.4)
	_x("a tap on a built row opens its card", main.hud.card_ring() == mk, {"title": main.hud.card_title()})
	await t._shot("rows_card_row")
	var l0 := Save.leaves
	var t0 := Save.timber
	if not it.is_empty():
		(it["action"] as Callable).call()
	main.hud.hide_card()
	var whole := true
	for p in ps:
		whole = whole and float(p["hp"]) >= float(p["max_hp"]) - 0.01 and d.piece_stage(p) == "whole" and _has_seg(p) and not p["wrecked"] \
			and _tilt(p) < 0.01 and _gloom(p["node"]) < 0.01
	_x("repaired: every piece whole and standing, its collision back, the rubble gone", whole and row["root"].rubble_at(1) == null)
	_x("the repair took its price", Save.leaves == l0 - int(want.get("leaves", 0)) and Save.timber == t0 - int(want.get("timber", 0)),
		{"leaves": [l0, Save.leaves], "timber": [t0, Save.timber]})
	_x("a whole row's card has no Repair", _item(d._card_spot(lane, 2), "Repair").is_empty())


# ---------------------------------------------------------------- (g) spots spread out; repair in a wave (22 Nov 2026)
func _spacing() -> void:
	var gap := float(_bi().get("slot_gap_min", 2.5))
	var rule: Dictionary = _bi()["pad_rule"]
	var w = main.world
	var keep_lv: int = Save.camp_level
	for lv in range(1, 9):
		Save.camp_level = lv
		w.rebuild_camp()
		var bad: Array = []
		var rule_bad: Array = []
		var gaps: Array = []
		var slots: Array = w.barricade_slots()
		for i in w.trails.size():
			var ps: Array = [null, null, null]
			for s in slots:
				if int(s[2]) == i:
					ps[int(s[3])] = s[0]
			for k in range(1, 3):
				var dd: float = (ps[k] as Vector3).distance_to(ps[k - 1])
				gaps.append(snappedf(dd, 0.01))
				if dd < gap:
					bad.append([i, k, snappedf(dd, 0.01)])
			# each pad sits where the rule says
			var L: float = w.trail_length(i)
			var gate_s: float = w.trail_progress(i, ps[2])
			if absf((L - gate_s) - float(rule["near_from_end_m"])) > 0.15:
				rule_bad.append(["gate", i, snappedf(L - gate_s, 0.01)])
			var mid_s: float = w.trail_progress(i, ps[1])
			if gate_s - mid_s < float(rule["mid_min_gap_from_gate_m"]) - 0.15:
				rule_bad.append(["mid too close to the gate", i, snappedf(gate_s - mid_s, 0.01)])
			var rr: float = Vector2((ps[0] as Vector3).x, (ps[0] as Vector3).z).length()
			var far_pad: Dictionary = Data.patch(i).get("far_pad", {})
			var from_woods := float(far_pad.get("in_from_woods_m", rule["far_in_from_woods_m"]))
			if absf(rr - (w.WOODS_R - from_woods)) > 0.15:
				rule_bad.append(["far", i, snappedf(rr, 0.01)])
			if w.patch_dir(i).x > 0.0:
				var far_s: float = w.trail_progress(i, ps[0])
				if absf((gate_s - mid_s) - (mid_s - far_s)) > 0.05:
					rule_bad.append(["uneven", i, snappedf(gate_s - mid_s, 0.01), snappedf(mid_s - far_s, 0.01)])
				continue
			var win: Array = rule["bend_window"]
			var probe := float(rule["bend_probe_m"])
			var best_a := -1.0
			var best_s := 0.0
			var s2: float = L * float(win[0])
			while s2 <= L * float(win[1]) + 0.0001:
				var a1: Vector3 = w.trail_point(i, s2) - w.trail_point(i, s2 - probe)
				var a2: Vector3 = w.trail_point(i, s2 + probe) - w.trail_point(i, s2)
				a1.y = 0.0
				a2.y = 0.0
				if absf(a1.angle_to(a2)) > best_a:
					best_a = absf(a1.angle_to(a2))
					best_s = s2
				s2 += 0.05 * L
			if absf(mid_s - minf(best_s, gate_s - float(rule["mid_min_gap_from_gate_m"]))) > 0.15:
				rule_bad.append(["bend", i, snappedf(mid_s, 0.01), snappedf(best_s, 0.01)])
		print("PADGAPS level %d (mid-far, gate-mid straight-line per road): %s" % [lv, str(gaps)])
		for i in w.trails.size():
			var row := []
			for s in slots:
				if int(s[2]) == i:
					var pp: Vector3 = s[0]
					row.append([int(s[3]), snappedf(Vector2(pp.x, pp.z).length(), 0.01), snappedf(w.trail_progress(i, pp), 0.01)])
			print("PADPOS level %d road %d [index, dist_from_camp, along]: %s" % [lv, i, str(row)])
		_x("level %d: the 3 spots on each road are at least %.1f m apart" % [lv, gap], bad.is_empty() and slots.size() == 12, {"bad": bad})
		_x("level %d: every pad sits where pad_rule says" % lv, rule_bad.is_empty(), {"bad": rule_bad})
	Save.camp_level = keep_lv
	w.rebuild_camp()


func _wave_repair() -> void:
	var f = main.fight
	var keep := {"active": f.active, "in_wave": f.in_wave}
	Save.leaves = 5000
	Save.timber = 200
	var row: Dictionary = d.row_at(lane, 0)
	var ps: Array = row["pieces"]
	d.hurt_piece(int(ps[0]["id"]), 999999)                              # one broken
	d.hurt_piece(int(ps[1]["id"]), int(ceil(float(ps[1]["max_hp"]) * 0.6)))   # one cracked
	d.hurt_piece(int(ps[2]["id"]), int(round(float(ps[2]["max_hp"]) * 0.2)))  # one hurt, not cracked
	f.active = true
	f.in_wave = true
	d._refresh_marks()
	var mk = d._spots.get(d._key(lane, 0))
	_x("in a wave a built row's marker stays", mk.visible)
	var empty_vis := false
	for key in d._spots:
		var pr: PackedStringArray = String(key).split(":")
		if d.row_at(int(pr[0]), int(pr[1])).is_empty() and d._spots[key].visible:
			empty_vis = true
	_x("in a wave empty spots show no marker", not empty_vis)
	var spec: Dictionary = main.hud._spec(mk)
	var it := _item(spec, "Repair")
	_x("in a wave the tap opens the row's real card with an enabled Repair", not it.is_empty() and bool(it["enabled"]), {"sub": spec.get("sub", "")})
	var cost: Dictionary = d.repair_row_cost(row)
	var share := float(_bi()["repair_share"])
	var pc: Dictionary = row["pieces"][1]                    # the cracked one: at least half a piece, more the nearer it is to breaking
	var units := 1.0 + clampf(1.0 - float(pc["hp"]) / maxf(float(pc["max_hp"]), 1.0), 0.5, 1.0) + 0.2
	var base: Dictionary = d.row_cost()
	var want := {}
	for k in base:
		want[k] = int(ceil(float(base[k]) * share * units - 0.0001))
	_x("repair price: a broken piece 1, a cracked one its missing share (at least 0.5), a hurt one its missing share", _same_cost(cost, want), {"got": cost, "want": want})
	var l0 := Save.leaves
	if not it.is_empty():
		(it["action"] as Callable).call()
	var whole := true
	for p in ps:
		whole = whole and float(p["hp"]) >= float(p["max_hp"]) - 0.01 and d.piece_stage(p) == "whole"
	_x("the broken, the cracked and the hurt piece are repaired during a wave", whole and Save.leaves == l0 - int(cost.get("leaves", 0)), {"leaves": [l0, Save.leaves]})
	# an empty spot cannot be built in a wave
	var spots := _spot_list()
	var free := []
	for sp in spots:
		if d.row_at(int(sp[0]), int(sp[1])).is_empty():
			free = sp
			break
	if not free.is_empty():
		_x("building a row stays closed in a wave", not d.build_row(int(free[0]), int(free[1])))
	f.active = keep["active"]
	f.in_wave = keep["in_wave"]
	d._refresh_marks()


# ---------------------------------------------------------------- (e) a knocked-down tower
func _tower() -> void:
	Save.def_levels["tower"] = 2
	var info: Dictionary = Data.defence_info("tower")
	var pos := Vector3(2.2, 0.0, float(main.world.camp_r) * 0.42 + 1.4)
	var sp := {"type": "tower", "x": pos.x, "z": pos.z, "rot": 0.0}
	Save.placed.append(sp)
	var p: Dictionary = d._spawn("tower", pos, 0.0)
	p["src"] = sp
	var mk = d._tower_marks.get(int(p["id"]))
	await t._wait(0.2)
	_x("a standing tower shows no repair marker", mk != null and not mk.visible)
	d.hurt_piece(int(p["id"]), 999999)
	await t._wait(0.3)
	_x("a knocked-down tower tips over and shows its repair marker", float(p["hp"]) <= 0.0 and absf((p["node"] as Node3D).rotation.z) > 0.1
		and mk.visible and String(mk.icon) == "repair")
	# 21 Nov 2026: the marker's repair costs what "Mend the defences" asks for this tower (leaves only): during the
	# missions its piece price x raid.repair_share (it is missing all its health), at least 5
	var share := float(Data.b["raid"]["repair_share"])
	var want := {"leaves": maxi(5, int(ceil(float(info["piece"]) * share)))}
	var got: Dictionary = d.tower_repair_cost(p)
	_x("its repair: the Mend price, %d%% of its piece price in leaves (no timber)" % int(round(share * 100.0)),
		not Data.raids_open() and _same_cost(got, want), {"got": got, "want": want})
	var mend := _mend_alone(p)
	_x("Mend the defences with only this tower wrecked asks the same", mend == int(want["leaves"]), {"mend": mend, "badge": got})
	# after the missions: the endgame mend rule (gloom_raids.repair), the badge and Mend still the same
	var done0: Array = Save.missions_done.duplicate()
	Save.missions_done = []
	for i in Data.mission_count():
		Save.missions_done.append(String(Data.mission(i)["id"]))
	var r: Dictionary = Data.gr()["repair"]
	var want_e := maxi(1, int(ceil(float(info["piece"]) * (1.0 + float(r["mend_per_level"]) * (d.level("tower") - 1)) * float(r["mend_share"]) - 0.0001)))
	var got_e: Dictionary = d.tower_repair_cost(p)
	var mend_e := _mend_alone(p)
	_x("after the raids: the badge is the endgame Mend price (%d leaves), the same as Mend" % want_e,
		Data.raids_open() and _same_cost(got_e, {"leaves": want_e}) and mend_e == want_e, {"got": got_e, "mend": mend_e, "want": want_e})
	Save.missions_done = done0
	await t._at_ring(mk)
	await t._wait(0.4)
	_x("a tap on its marker opens its card", main.hud.card_ring() == mk, {"title": main.hud.card_title()})
	await t._shot("rows_card_tower")
	var it := _item(mk.builder.call(), "Repair")
	var l0 := Save.leaves
	var t0 := Save.timber
	if not it.is_empty():
		(it["action"] as Callable).call()
	main.hud.hide_card()
	await t._wait(0.3)
	_x("paid: the tower stands up at full health and its marker goes", float(p["hp"]) >= float(p["max_hp"]) - 0.01
		and absf((p["node"] as Node3D).rotation.z) < 0.01 and not mk.visible and _has_tower_circle(p)
		and Save.leaves == l0 - int(want["leaves"]) and Save.timber == t0,
		{"hp": p["hp"], "leaves": [l0, Save.leaves], "timber": [t0, Save.timber]})


## What "Mend the defences" (defences.repair_cost) asks when p is the only wrecked piece: the others' wreck flags are
## set aside for the sum and put back (nothing else changes).
func _mend_alone(p: Dictionary) -> int:
	var flags := {}
	for q in d.pieces:
		flags[int(q["id"])] = bool(q["wrecked"])
		q["wrecked"] = int(q["id"]) == int(p["id"])
	var c: int = d.repair_cost()
	for q in d.pieces:
		q["wrecked"] = flags[int(q["id"])]
	return c


func _has_tower_circle(p: Dictionary) -> bool:
	var tag := "piece_%d" % int(p["id"])
	for c in main.world.circles:
		if String(c[2]) == tag:
			return true
	return false


# ---------------------------------------------------------------- (f) the Wishing Well's mending
func _well() -> void:
	var row: Dictionary = d.row_at(lane, 1)
	var ps: Array = row["pieces"]
	var p0: Dictionary = ps[0]
	var p1: Dictionary = ps[1]
	var p2: Dictionary = ps[2]
	var mx := float(p0["max_hp"])
	d.hurt_piece(int(p0["id"]), int(round(mx * 0.7)))              # 30% left: cracked
	d.hurt_piece(int(p1["id"]), 999999)                            # broken
	_x("set up: a cracked piece and a broken one", d.piece_stage(p0) == "cracked" and d.piece_stage(p1) == "broken")
	var s_start := float(p0["hp"]) / mx
	for i in 50:
		d.well_mend(0.1, 0.01, 0.6)                                # 5 s at 1% a second
	var s0 := float(p0["hp"]) / mx
	_x("the Well raises a cracked piece by its share a second", absf(s0 - (s_start + 0.05)) < 0.001, {"from": s_start, "to": s0})
	_x("the Well never brings back a broken piece", float(p1["hp"]) <= 0.0 and d.piece_stage(p1) == "broken" and not _has_seg(p1))
	d.well_mend(5.0, 0.01, 0.6)
	var s1 := float(p0["hp"]) / mx
	_x("a long frame counts as 0.1 s at most", absf(s1 - (s0 + 0.001)) < 0.0005, {"from": s0, "to": s1})
	for i in 600:
		d.well_mend(0.1, 0.01, 0.6)                                # 60 s: well past the cap
	var s2 := float(p0["hp"]) / mx
	_x("it stops at the cap (60%) and the piece looks whole again", absf(s2 - 0.6) < 0.001 and d.piece_stage(p0) == "whole" and _gloom(p0["node"]) < 0.01
		and _tilt(p0) < 0.01, {"share": s2})
	_x("a whole piece above the cap is left as it is", float(p2["hp"]) >= float(p2["max_hp"]) - 0.01)
	d.hurt_piece(int(p2["id"]), int(round(mx * 0.05)))
	for i in 300:
		d.well_mend(0.1, 0.05, 2.0)
	_x("and never above full", float(p2["hp"]) <= float(p2["max_hp"]) + 0.001 and float(p2["hp"]) >= float(p2["max_hp"]) - 0.01,
		{"hp": p2["hp"], "max": p2["max_hp"]})
	# the Well brings a hurt piece to full between waves and never revives a broken one (cap 1.0 = full)
	var pw: Dictionary = ps[0]
	d.hurt_piece(int(pw["id"]), int(round(mx * 0.3)))
	for i in 600:
		d.well_mend(0.1, 0.03, 1.0)
	_x("the Well brings a hurt piece all the way to full", absf(float(pw["hp"]) - mx) < 0.01 and d.piece_stage(pw) == "whole", {"hp": pw["hp"]})
	_x("and the broken piece is still broken", float(p1["hp"]) <= 0.0 and d.piece_stage(p1) == "broken")
	t._log("rows", {"rows": d.rows_built(), "open": d.pads_open_count(), "pieces": d.pieces.size()})
