extends RefCounted
## The defences' markers and cards (H6 Stage 1 split them out of defences.gd; Stage 2, 27 Nov 2026, makes every piece tappable).
## Three kinds of marker:
##   road_<lane>_<pad>  one at every road pad (the "barricade" badge): its card builds a row there when the pad is empty,
##                      or is the built row's card (tapping any visible part of the row works: its body proxy covers the
##                      whole row, ends included)
##   tower_<id>         one on each tower: the tower's body takes the tap; its "repair" badge shows only while it is down
##   spikes_<id>        one on each thorn patch: the patch's body takes the tap; its badge is always hidden
## The piece markers show in the camp (states 1 and 2 of marks_state), as H5's tower marker did. A marker's body proxy is a
## Callable that looks the piece up by id each time, so a new model (an upgrade) is picked up without refitting anything.
## The cards come from the windows (defences.use_window_builders), looked up when the marker is tapped, because the
## windows are built after load_saved; the old cards below (card_spot, card_row, card_tower) are kept for the time before
## the HUD is up and for the tests.
## defences.gd owns the rules (what a row costs, who may repair); this file only shows them and draws their cards.
## It keeps the same names the autotests read through the defences facade: spots, tower_marks, card_spot.

const MarkerScript := preload("res://scripts/marker.gd")
const MARK_SIDE := 1.15             # a road spot's marker stands this far from its row: where the cat stands to use it
const TOWER_MARK := 1.05            # a tower's marker: this far from it (the cat walks here; outside its 0.6 m circle)
const PATCH_MARK := 0.9             # a patch's marker, if the middle of the patch is not free
const WALK_R := 0.35                # the cat's room: a walking point must hold this much clear ground
const ROW_HIGH := 1.3               # a row's tap box is this high (m)
const ROW_THICK := 0.3              # and this thick on each side of its line (m)
const MARK_COL := Color(1.0, 0.82, 0.3)
const FIX_COL := Color(1.0, 0.55, 0.35)

var d: Node3D                       # the defences node (defences.gd)
var spots := {}                     # "road:spot" -> its marker
var tower_marks := {}               # tower piece id -> its marker (towers only: the tests read it)
var patch_marks := {}               # thorn patch piece id -> its marker
var marks := -1                     # what the markers last showed for (marks_state)
var _fit_n := 0                     # frames since the walking points were last checked


func setup(defences: Node3D) -> void:
	d = defences


## A small marker at every road spot (the "barricade" badge): its card builds a row there, or shows the row's pieces
## and repairs it (d._card_road picks, when it is tapped).
func make_spot_marks() -> void:
	for s in d.main.world.barricade_slots():
		var lane := int(s[2])
		var idx := int(s[3])
		var mk = MarkerScript.new()
		d.add_child(mk)
		mk.setup("road_%d_%d" % [lane, idx], spot_pos(s), 0.75, d._card_road.bind(lane, idx), MARK_COL)
		mk.visible = false
		d.main.register_ring(mk)
		spots[d._key(lane, idx)] = mk
		attach_spot(lane, idx)


## Every built thing is gone: the tower and patch markers go, the road spots' markers stay and show empty spots.
func reset() -> void:
	for dict: Dictionary in [tower_marks, patch_marks]:
		for id in dict:
			var mk = dict[id]
			d.main.unregister_ring(mk)
			mk.queue_free()
	tower_marks = {}
	patch_marks = {}


## After the rows are gone: each road spot's marker floats over its empty spot again, with no "!".
func reset_spots() -> void:
	for s in d.main.world.barricade_slots():
		attach_spot(int(s[2]), int(s[3]))
	for key in spots:
		spots[key].pulse = false


## Where the cat stands to use a road spot: beside the row on the camp's side, or on the woods' side when the camp's
## side is away from the camera (so the row never hides the cat).
func spot_pos(s: Array) -> Vector3:
	var rot := float(s[1])
	var woods := Vector3(sin(rot), 0.0, cos(rot))
	var side := -woods
	if side.z < -0.3:
		side = woods
	return (s[0] as Vector3) + side * MARK_SIDE


## A spot's badge floats over its row (tapping the row opens it too: its body proxy covers the whole row), or over the
## empty spot.
func attach_spot(lane: int, idx: int) -> void:
	var mk = spots.get(d._key(lane, idx))
	if mk == null:
		return
	var row: Dictionary = d.row_at(lane, idx)
	if not row.is_empty():
		mk.attach(row["root"], "barricade", 1.45)
		mk.set_body_proxy(_row_box.bind(lane, idx))
		return
	mk.set_body_proxy(Callable())
	var s: Array = d.main.world.barricade_slot(lane, idx)
	var at: Vector3 = s[0] if not s.is_empty() else mk.global_position
	mk.attach(null, "barricade", 1.2, Vector3(at.x - mk.global_position.x, 0.0, at.z - mk.global_position.z))


## The camp grew and the trails moved a little: the spot markers follow their road spots.
func follow_spots() -> void:
	for s in d.main.world.barricade_slots():
		var mk = spots.get(d._key(int(s[2]), int(s[3])))
		if mk != null:
			var at := spot_pos(s)
			mk.global_position = Vector3(at.x, 0.03, at.z)
			attach_spot(int(s[2]), int(s[3]))


# ---------------------------------------------------------------- piece markers (towers and patches)
## A tower's or patch's marker: tower_<id> or spikes_<id>. It stands at a walking point beside the piece, takes taps on
## the piece's body (the proxy) and shows its badge only while a tower is down. Its card is d._card_piece(id).
func make_piece_mark(p: Dictionary) -> void:
	var kind := String(p["type"])
	if kind != "tower" and kind != "spikes":
		return
	var id := int(p["id"])
	var mk = MarkerScript.new()
	d.add_child(mk)
	mk.setup("%s_%d" % [kind, id], walk_point(p), 0.75, d._card_piece.bind(id), FIX_COL)
	mk.visible = false
	mk.set_badge_visible(false)
	d.main.register_ring(mk)
	mk.attach(p["node"], "repair")
	mk.set_body_proxy(_piece_box.bind(id))
	if kind == "tower":
		tower_marks[id] = mk
	else:
		patch_marks[id] = mk
	_show_piece_mark(mk, p, marks_state() % 10, kind == "tower")


## A piece leaves the camp (a placement taken back): its marker is unregistered, freed and forgotten.
func remove_piece_mark(id: int) -> void:
	for dict: Dictionary in [tower_marks, patch_marks]:
		var mk = dict.get(id)
		if mk == null:
			continue
		d.main.unregister_ring(mk)
		dict.erase(id)
		mk.queue_free()


## The piece's model was swapped (an upgrade): the marker floats over the new node.
func reattach_piece(id: int) -> void:
	var mk = tower_marks.get(id, patch_marks.get(id))
	var p: Dictionary = d._by_id.get(id, {})
	if mk == null or p.is_empty():
		return
	mk.attach(p["node"], "repair")


## The marker of a placed piece or row (null when it is gone).
func piece_marker(kind: String, id: int, slot: Vector2i) -> Node:
	var mk = null
	if kind == "barricade":
		if not d.row_at(slot.x, slot.y).is_empty():
			mk = spots.get(d._key(slot.x, slot.y))
	elif kind == "tower":
		mk = tower_marks.get(id)
	elif kind == "spikes":
		mk = patch_marks.get(id)
	return mk if mk != null and is_instance_valid(mk) else null


## The marker to walk the cat to for a level goal: a placed piece or row below min_level, the highest level first and the
## lowest id on a tie. Null when there is none, or its marker is not visible now.
func goal_marker(kind: String, min_level: int) -> Node:
	var best_lv := 0
	var best_id := -1
	var best_slot := Vector2i(-1, -1)
	if kind == "barricade":
		for row: Dictionary in d.rows:
			var lv: int = d.row_level(row)
			var rid := int(row["pieces"][0]["id"]) if not (row["pieces"] as Array).is_empty() else 0
			if lv < min_level and (best_id < 0 or lv > best_lv or (lv == best_lv and rid < best_id)):
				best_lv = lv
				best_id = rid
				best_slot = Vector2i(int(row["slot"][0]), int(row["slot"][1]))
	else:
		for p: Dictionary in d.pieces:
			if String(p["type"]) != kind:
				continue
			var lv2: int = d.piece_level(p)
			var pid := int(p["id"])
			if lv2 < min_level and (best_id < 0 or lv2 > best_lv or (lv2 == best_lv and pid < best_id)):
				best_lv = lv2
				best_id = pid
	if best_id < 0:
		return null
	var mk: Node = piece_marker(kind, -1 if kind == "barricade" else best_id, best_slot)
	return mk if mk != null and (mk as Node3D).visible else null


## The open, empty road pad nearest the camp (its marker), or null when there is none (or it is not showing now).
func empty_pad_marker() -> Node:
	var best: Node = null
	var best_d := INF
	for s in d.main.world.barricade_slots():
		var lane := int(s[2])
		var idx := int(s[3])
		if not d.row_at(lane, idx).is_empty() or not d.pad_open(lane, idx):
			continue
		var mk = spots.get(d._key(lane, idx))
		if mk == null or not mk.visible:
			continue
		var at: Vector3 = s[0]
		var dist := Vector2(at.x, at.z).length()
		if dist < best_d - 0.001:
			best_d = dist
			best = mk
	return best


# ---------------------------------------------------------------- tap boxes and walking points
## A row's tap box (world): from the middle of its first section to the middle of its last, plus half a section at each
## end and a little thickness, about 1.3 m high. An empty AABB when the row is gone.
func _row_box(lane: int, idx: int) -> AABB:
	var row: Dictionary = d.row_at(lane, idx)
	if row.is_empty() or not is_instance_valid(row["root"]):
		return AABB()
	var root := row["root"] as Node3D
	var n := (row["pieces"] as Array).size()
	var along: Vector3 = root.global_transform.basis.x.normalized()
	var across: Vector3 = root.global_transform.basis.z.normalized() * ROW_THICK
	var half: float = float(root.get("seg")) * 0.5
	var a: Vector3 = root.call("piece_pos", 0) - along * half
	var b: Vector3 = root.call("piece_pos", maxi(n - 1, 0)) + along * half
	var lo := Vector3(INF, 0.0, INF)
	var hi := Vector3(-INF, ROW_HIGH, -INF)
	for c: Vector3 in [a + across, a - across, b + across, b - across]:
		lo = Vector3(minf(lo.x, c.x), 0.0, minf(lo.z, c.z))
		hi = Vector3(maxf(hi.x, c.x), ROW_HIGH, maxf(hi.z, c.z))
	return AABB(lo, hi - lo)


## A piece's tap box (world): its model's meshes merged, looked up by id each call, so an upgrade's new model is
## followed without anything refitted.
func _piece_box(id: int) -> AABB:
	var p: Dictionary = d._by_id.get(id, {})
	if p.is_empty() or not is_instance_valid(p["node"]):
		return AABB()
	var box := AABB()
	var have := false
	var stack: Array = [p["node"]]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).visible:
			var ab: AABB = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
			box = ab if not have else box.merge(ab)
			have = true
		for c in n.get_children():
			stack.append(c)
	if not have:
		var at: Vector3 = p["pos"]
		return AABB(at - Vector3(0.5, 0.0, 0.5), Vector3(1.0, 1.2, 1.0))
	return box


## Is this ground clear for the cat (no building, tower, lake or other solid there)?
func _free(at: Vector3) -> bool:
	if d.main.area != null:
		return true
	var q: Vector3 = d.main.world.constrain(at, WALK_R, false)
	return Vector2(q.x - at.x, q.z - at.z).length() < 0.02


## Where the cat stands to use a tower or patch: in front of a tower (on the camera's side) and outside its 0.6 m circle;
## if that is in a world circle or the lake, another side. A patch has no circle: its own middle first.
func walk_point(p: Dictionary) -> Vector3:
	var at: Vector3 = p["pos"]
	var tower := String(p["type"]) == "tower"
	var dist := TOWER_MARK if tower else PATCH_MARK
	var first := Vector3(0, 0, TOWER_MARK) if tower else Vector3.ZERO
	if _free(at + first):
		return at + first
	for k in 8:
		var a := float((k >> 1) + 1) * (PI / 4.0) * (1.0 if k % 2 == 0 else -1.0)
		var o := Vector3(sin(a), 0.0, cos(a)) * dist
		if _free(at + o):
			return at + o
	return at + first


## A later building or tower may stand where a marker was put: those markers find a free side again.
func _refit_walk_points() -> void:
	for dict: Dictionary in [tower_marks, patch_marks]:
		for id in dict:
			var mk = dict[id]
			var p: Dictionary = d._by_id.get(id, {})
			if p.is_empty() or _free(mk.global_position):
				continue
			var at := walk_point(p)
			mk.global_position = Vector3(at.x, 0.03, at.z)


# ---------------------------------------------------------------- what shows when
## 0: no markers (the cat is below ground); 1: the pieces' only; 2: the open road pads' too (once barricades are
## open); 3: a wave is on: only the built rows' markers (their repair works in a wave). Include the Hearthtree level
## because pads on individual roads can open even when the number of open rings stays the same.
func marks_state() -> int:
	var base := 1
	if d.main.area != null:
		base = 0
	elif d._wave_on():
		base = 3 if d.unlocked("barricade") else 0        # in a wave: only the built rows' markers (to repair them)
	elif d.unlocked("barricade"):
		base = 2
	return base + 10 * Save.camp_level


## Every frame: a wave started or ended, the cat went below ground or came up: the markers follow.
func tick() -> void:
	if marks_state() != marks:
		refresh_marks()
	_fit_n += 1
	if _fit_n >= 90:                                # a building or tower built later may now stand on a walking point
		_fit_n = 0
		_refit_walk_points()


func refresh_marks() -> void:
	var full := marks_state()
	marks = full
	var st := full % 10
	for key in spots:
		var parts: PackedStringArray = String(key).split(":")
		var ln := int(parts[0])
		var ix := int(parts[1])
		var built: bool = not d.row_at(ln, ix).is_empty()
		# a built row's marker always shows (even on a pad not open yet: an older save); an empty pad's only when open
		spots[key].visible = (st == 2 and (built or d.pad_open(ln, ix))) or (st == 3 and built)
	_refit_walk_points()
	for id in tower_marks:
		_show_piece_mark(tower_marks[id], d._by_id.get(id, {}), st, true)
	for id in patch_marks:
		_show_piece_mark(patch_marks[id], d._by_id.get(id, {}), st, false)
	update_pulses()


## A tower's or patch's marker: it shows in the camp (states 1 and 2); a downed tower's badge shows, nothing else does.
func _show_piece_mark(mk, p: Dictionary, st: int, tower: bool) -> void:
	if p.is_empty():
		return
	if not is_instance_valid(mk.obj) or mk.obj != p["node"]:
		mk.attach(p["node"], "repair")                      # a new level: its new model
	mk.visible = st == 1 or st == 2
	mk.set_badge_visible(tower and float(p["hp"]) <= 0.0)


## The "!" on a marker: a row with a broken section, or a downed tower, that can be repaired now.
func update_pulses() -> void:
	for row in d.rows:
		var mk = spots.get(d._key(int(row["slot"][0]), int(row["slot"][1])))
		if mk == null:
			continue
		mk.pulse = d.row_broken(row) and Data.can_afford(d.repair_row_cost(row))
	for id in tower_marks:
		var p: Dictionary = d._by_id.get(id, {})
		tower_marks[id].pulse = not p.is_empty() and float(p["hp"]) <= 0.0 and Data.can_afford(d.tower_repair_cost(p))


# ---------------------------------------------------------------- the cards
## What a tapped tower or patch opens: the window's card (the HUD hands the builders over; looked up now, not at load), or
## the old tower card before the HUD is up.
func card_piece(id: int) -> Dictionary:
	var p: Dictionary = d._by_id.get(id, {})
	if p.is_empty():
		return {"title": "", "sub": "", "rows": []}
	if d._win_piece.is_valid():
		return d._win_piece.call(id)
	if String(p["type"]) == "tower":
		return card_tower(id)
	var title := String(Data.defence_info("spikes").get("name", "Thorn Spikes"))
	return {"title": title, "sub": "Level %d" % d.piece_level(p), "anchor": (p["pos"] as Vector3) + Vector3(0, 1.2, 0), "rows": []}


## What a tapped road marker opens: the built row's card, or the empty pad's.
func card_road(lane: int, idx: int) -> Dictionary:
	if not d.row_at(lane, idx).is_empty():
		if d._win_row.is_valid():
			return d._win_row.call(lane, idx)
		return card_spot(lane, idx)
	if d._win_pad.is_valid():
		return d._win_pad.call(lane, idx)
	return card_spot(lane, idx)


func camp_name() -> String:
	return String(Data.call("camp_name")) if Data.has_method("camp_name") else "the Hearthtree"


func tile(icon: String, title: String, text: String, cost: Dictionary, label: String, ok: bool, action: Callable,
		badge := "", stats: Array = []) -> Dictionary:
	var t := {"kind": "item", "icon": icon, "title": title, "text": text, "cost": cost, "label": label,
		"enabled": ok and label != "" and action.is_valid() and Data.can_afford(cost), "action": action}
	if badge != "":
		t["badge"] = badge
	if not stats.is_empty():
		t["stats"] = stats
	return t


## A health bar's share: this much health against the top barricade level's.
func hp_bar(hp: float) -> float:
	var lv: Array = Data.defence_info("barricade")["levels"]
	return clampf(hp / maxf(float(lv[lv.size() - 1].get("hp", hp)), 1.0), 0.05, 1.0)


## "90 leaves and 5 timber": a price in words.
func price_words(cost: Dictionary) -> String:
	var bits: Array = []
	for k in Data.CURRENCIES:
		var n := int(cost.get(k, 0))
		if n > 0:
			bits.append("%d %s" % [n, Data.mat_name(String(k)) if k in Data.MATS else String(k)])
	if bits.size() <= 1:
		return "".join(bits)
	return ", ".join(bits.slice(0, bits.size() - 1)) + " and " + String(bits[bits.size() - 1])


## A road pad's old card (before the windows exist, and the tests): build a row there, or (built) the row's own card.
## When Build can't be pressed the tile says why.
func card_spot(lane: int, idx: int) -> Dictionary:
	var row: Dictionary = d.row_at(lane, idx)
	if not row.is_empty():
		return card_row(row)
	var s: Array = d.main.world.barricade_slot(lane, idx)
	var at: Vector3 = s[0] if not s.is_empty() else Vector3.ZERO
	var mx: float = d._max_hp("barricade", d.new_row_level())
	var cost: Dictionary = d.row_cost()
	var why: String = d.pad_reason(lane, idx)
	var it := tile("barricade", "Barricade row", "%d pieces across the road · %d health each" % [d.pieces_per_row(), int(mx)],
		cost, "Build", why == "", d.build_row.bind(lane, idx), "", [["Health", hp_bar(mx)]])
	if why != "":
		it["text"] = why
	elif not Data.can_afford(cost):
		it["text"] = "Needs %s" % price_words(cost)
	return {"title": "Road spot", "sub": "Barricade row on this road", "anchor": at + Vector3(0, 1.4, 0),
		"rows": [{"kind": "section", "text": "Block the road"}, it]}


## A built row's old card: each piece's health and look, and Repair while any piece is broken.
func card_row(row: Dictionary) -> Dictionary:
	var ps: Array = row["pieces"]
	var list: Array = [{"kind": "section", "text": "Pieces"}]
	var standing := 0
	for p in ps:
		var st: String = d.piece_stage(p)
		if st != "broken":
			standing += 1
		var share := clampf(float(p["hp"]) / maxf(float(p["max_hp"]), 1.0), 0.0, 1.0)
		var txt := "Whole"
		var badge := ""
		if st == "cracked":
			txt = "Cracked: it will break soon"
			badge = "Cracked"
		elif st == "broken":
			txt = "Broken: enemies get through"
			badge = "Broken"
		list.append(tile("barricade", "Piece %d" % (int(p["k"]) + 1), txt, {}, "", false, Callable(), badge, [["Health", share]]))
	if d.row_broken(row):
		list.append({"kind": "section", "text": "Repair"})
		list.append(tile("repair", "Repair the row", "Every piece back to full health", d.repair_row_cost(row), "Repair", true,
			d.repair_row_at.bind(int(row["slot"][0]), int(row["slot"][1]))))
	var root := row["root"] as Node3D
	return {"title": "Barricade row", "sub": "Level %d · %d of %d pieces standing" % [d.row_level(row), standing, ps.size()],
		"anchor": root.position + Vector3(0, 1.4, 0), "rows": list}


## A knocked-down tower's old card: Repair stands it up again.
func card_tower(id: int) -> Dictionary:
	var p: Dictionary = d._by_id.get(id, {})
	var title := String(Data.defence_info("tower").get("name", "Acorn Tower"))
	if p.is_empty():
		return {"title": title, "sub": "", "rows": []}
	var at: Vector3 = (p["pos"] as Vector3) + Vector3(0, 2.2, 0)
	if float(p["hp"]) > 0.0:
		return {"title": title, "sub": "Standing and shooting", "rows": [], "anchor": at}
	var it := tile("repair", "Repair the tower", "It stands up at full health and shoots again", d.tower_repair_cost(p), "Repair",
		not d._wave_on(), d.repair_tower_id.bind(id), "Broken", [["Health", 0.0]])
	return {"title": title, "sub": "Knocked down by the Gloom", "anchor": at, "rows": [{"kind": "section", "text": "Repair"}, it]}
