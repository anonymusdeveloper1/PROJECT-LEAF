extends Node
## Phase G2: barricade rows and tower repair (`-- --autotest --fresh --rows`), run from autotest.gd. Each check logs
## "EXPECT PASS <what>" or "EXPECT FAIL <what>" through autotest.gd's _expect. Light on purpose: the numbers come from
## balance.json (defences.barricade: row, rows_by_home, crack_at, repair_share, piece; defences.tower.repair_share) and
## no fight is played.
##   (a) an old save (2 barricades placed, one of them wrecked, a second piece on one spot; 3 in the bag) loads as 2 rows
##       and a leaf refund; the bag and the build button have no barricades; rows load again from the save; pieces put
##       in the bag later (an older mission gift) are refunded too
##   (b) every road spot has a marker; a tap on an empty one opens its card, whose Build makes a row (its cost taken);
##       the Hearthtree's row cap is kept (the full card says to grow it)
##   (c) one piece hurt below crack_at: cracked (darker, tilted), the others whole; broken: flat, a rubble pile, no
##       collision, and a walker passes the gap (a whole piece still stops it)
##   (d) a row's repair costs its share (a broken piece and a cracked one) and mends every piece
##   (e) a knocked-down tower tips over and shows its repair marker; its card repairs it for its share
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
	await _tower()
	_well()
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


# ---------------------------------------------------------------- (b) building rows, the cap
func _build() -> void:
	Save.placed = []
	d.load_saved()
	Save.camp_level = 1
	Save.leaves = 1000
	Save.timber = 100
	main.hud.refresh()
	await t._wait(0.3)
	var cost: Dictionary = d.row_cost()
	var caps: Array = _bi()["rows_by_home"]
	var cap1 := int(caps[1])
	_x("a row costs balance.json barricade.row.cost", _same_cost(cost, _bi()["row"]["cost"]) and int(cost.get("leaves", 0)) > 0, {"cost": cost})
	_x("every road spot has a marker (%d)" % main.world.barricade_slots().size(), d._spots.size() == main.world.barricade_slots().size()
		and d._spots.size() == 12, {"spots": d._spots.size()})
	var mk = d._spots.get(d._key(lane, 0))
	_x("the road spots' markers show outside a wave, with the barricade badge", mk != null and mk.visible and String(mk.icon) == "barricade")
	main.closeup = Vector3.ZERO
	main.closeup_at = null
	await t._at_ring(mk)
	await t._wait(0.4)
	_x("a tap on an empty spot opens its card", main.hud.card_ring() == mk, {"title": main.hud.card_title()})
	await t._shot("rows_card_spot")
	var it := _item(mk.builder.call(), "Build")
	_x("its card offers a barricade row", not it.is_empty() and bool(it["enabled"]) and _same_cost(it["cost"], cost), {"tile": it.get("title", "")})
	if not it.is_empty():
		(it["action"] as Callable).call()
	main.hud.hide_card()
	_x("Build makes a row there and takes its cost", not d.row_at(lane, 0).is_empty()
		and Save.leaves == 1000 - int(cost.get("leaves", 0)) and Save.timber == 100 - int(cost.get("timber", 0)),
		{"leaves": Save.leaves, "timber": Save.timber})
	var spots := _spot_list()
	var k := 1
	while d.rows_built() < cap1 and k < spots.size():
		d.build_row(int(spots[k][0]), int(spots[k][1]))
		k += 1
	var l0 := Save.leaves
	var over: bool = d.build_row(int(spots[k][0]), int(spots[k][1]))
	_x("the Hearthtree at level 1 holds %d rows: one more is refused and nothing is paid" % cap1,
		d.rows_built() == cap1 and not over and Save.leaves == l0, {"rows": d.rows_built(), "leaves": [l0, Save.leaves]})
	var full := _item(d._card_spot(int(spots[k][0]), int(spots[k][1])), "Build")
	_x("then an empty spot's card says to grow the Hearthtree", not full.is_empty() and not bool(full["enabled"]) and String(full["text"]).contains("Grow"),
		{"text": full.get("text", "")})
	Save.camp_level = 3
	var cap3 := int(caps[3])
	var more: bool = d.build_row(int(spots[k][0]), int(spots[k][1]))
	_x("at level 3 it holds %d: the row is built" % cap3, more and d.rows_built() == cap1 + 1 and cap3 > cap1)
	_x("the row at the face-on road's last spot stands", not d.row_at(lane, 2).is_empty())


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
	var spent := float(info["piece"])
	for k in range(1, d.level("tower")):
		spent += float(info["levels"][k].get("upgrade", 0))
	var leaves := int(ceil(spent * float(info["repair_share"]) - 0.0001))
	var want := {"leaves": leaves, "timber": maxi(1, int(round(leaves / float(info.get("repair_leaves_per_timber", 30)))))}
	var got: Dictionary = d.tower_repair_cost(p)
	_x("its repair: %d%% of what it cost (its price and upgrades), in leaves and a little timber" % int(round(float(info["repair_share"]) * 100.0)),
		_same_cost(got, want), {"got": got, "want": want})
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
		and Save.leaves == l0 - int(want["leaves"]) and Save.timber == t0 - int(want["timber"]),
		{"hp": p["hp"], "leaves": [l0, Save.leaves], "timber": [t0, Save.timber]})


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
	t._log("rows", {"rows": d.rows_built(), "cap": d.row_cap(), "pieces": d.pieces.size()})
