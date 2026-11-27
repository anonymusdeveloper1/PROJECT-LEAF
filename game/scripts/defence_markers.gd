extends RefCounted
## The defences' markers and cards (H6 Stage 1, split out of defences.gd; nothing the player sees changes).
## Two kinds of marker: one at every road spot (the "barricade" badge: its card builds a row there, or shows the row's
## pieces and repairs it), and one over each tower (the "repair" badge, shown while the tower is knocked down).
## defences.gd owns the rules (what a row costs, who may repair); this file only shows them and draws their cards.
## It keeps the same names the autotests read through the defences facade: spots, tower_marks, card_spot.

const MarkerScript := preload("res://scripts/marker.gd")
const MARK_SIDE := 1.15             # a road spot's marker stands this far from its row: where the cat stands to use it
const TOWER_MARK := 1.05            # a downed tower's marker: this far in front of it (on the camera's side)
const MARK_COL := Color(1.0, 0.82, 0.3)
const FIX_COL := Color(1.0, 0.55, 0.35)

var d                               # the defences node (defences.gd)
var spots := {}                     # "road:spot" -> its marker
var tower_marks := {}               # tower piece id -> its repair marker (shown while it is down)
var marks := -1                     # what the markers last showed for (marks_state)


func setup(defences) -> void:
	d = defences


## A small marker at every road spot (the "barricade" badge): its card builds a row there, or shows the row's pieces
## and repairs it.
func make_spot_marks() -> void:
	for s in d.main.world.barricade_slots():
		var lane := int(s[2])
		var idx := int(s[3])
		var mk = MarkerScript.new()
		d.add_child(mk)
		mk.setup("road_%d_%d" % [lane, idx], spot_pos(s), 0.75, card_spot.bind(lane, idx), MARK_COL)
		mk.visible = false
		d.main.register_ring(mk)
		spots[d._key(lane, idx)] = mk
		attach_spot(lane, idx)


## Every built thing is gone: the tower markers go, the road spots' markers stay and show empty spots.
func reset() -> void:
	for id in tower_marks:
		var mk = tower_marks[id]
		d.main.unregister_ring(mk)
		mk.queue_free()
	tower_marks = {}


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


## A spot's badge floats over its row (tapping the row opens it too), or over the empty spot.
func attach_spot(lane: int, idx: int) -> void:
	var mk = spots.get(d._key(lane, idx))
	if mk == null:
		return
	var row: Dictionary = d.row_at(lane, idx)
	if not row.is_empty():
		mk.attach(row["root"], "barricade", 1.45)
		return
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


## A tower's repair marker (the "repair" badge), shown while it is knocked down.
func make_tower_mark(p: Dictionary) -> void:
	var id := int(p["id"])
	var mk = MarkerScript.new()
	d.add_child(mk)
	mk.setup("tower_%d" % id, (p["pos"] as Vector3) + Vector3(0, 0, TOWER_MARK), 0.75, card_tower.bind(id), FIX_COL)
	mk.visible = false
	d.main.register_ring(mk)
	tower_marks[id] = mk


## A tower leaves the camp (a placement taken back): its marker is unregistered, freed and forgotten.
func remove_tower_mark(id: int) -> void:
	var mk = tower_marks.get(id)
	if mk == null:
		return
	d.main.unregister_ring(mk)
	tower_marks.erase(id)
	mk.queue_free()


## 0: no markers (the cat is below ground); 1: the downed towers' only; 2: the open road pads' too (once barricades are
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
	for id in tower_marks:
		var mk = tower_marks[id]
		var p: Dictionary = d._by_id.get(id, {})
		var show := (st == 1 or st == 2) and not p.is_empty() and float(p["hp"]) <= 0.0
		if show and (not is_instance_valid(mk.obj) or mk.obj != p["node"]):
			mk.attach(p["node"], "repair")             # over the tipped tower (a new level: its new model)
		mk.visible = show
	update_pulses()


## The "!" on a marker: a cracked or broken row, or a downed tower, that can be repaired now.
func update_pulses() -> void:
	for row in d.rows:
		var mk = spots.get(d._key(int(row["slot"][0]), int(row["slot"][1])))
		if mk == null:
			continue
		var need := false
		for p in row["pieces"]:
			if d.piece_stage(p) != "whole":
				need = true
		mk.pulse = need and Data.can_afford(d.repair_row_cost(row))
	for id in tower_marks:
		var p: Dictionary = d._by_id.get(id, {})
		tower_marks[id].pulse = not p.is_empty() and float(p["hp"]) <= 0.0 and Data.can_afford(d.tower_repair_cost(p))


# ---------------------------------------------------------------- the cards (shop-style tiles: hud.gd)
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


## A road pad's card: build a row there, or (built) the row's own card. When Build can't be pressed the tile says why.
func card_spot(lane: int, idx: int) -> Dictionary:
	var row: Dictionary = d.row_at(lane, idx)
	if not row.is_empty():
		return card_row(row)
	var s: Array = d.main.world.barricade_slot(lane, idx)
	var at: Vector3 = s[0] if not s.is_empty() else Vector3.ZERO
	var mx: float = d._max_hp("barricade", d.level("barricade"))
	var cost: Dictionary = d.row_cost()
	var can: bool = d.unlocked("barricade") and d.pad_open(lane, idx) and not d._wave_on() and d.main.area == null
	var it := tile("barricade", "Barricade row", "%d pieces across the road · %d health each" % [d.pieces_per_row(), int(mx)],
		cost, "Build", can, d.build_row.bind(lane, idx), "", [["Health", hp_bar(mx)]])
	if not d.unlocked("barricade"):
		it["text"] = "Barricades open later"
	elif not d.pad_open(lane, idx):
		it["text"] = "This pad opens as the %s grows" % camp_name().trim_prefix("the ")
	elif d._wave_on():
		it["text"] = "A wave is on: build between waves"
	elif not Data.can_afford(cost):
		it["text"] = "Needs %s" % price_words(cost)
	return {"title": "Road spot", "sub": "Barricade row on this road", "anchor": at + Vector3(0, 1.4, 0),
		"rows": [{"kind": "section", "text": "Block the road"}, it]}


## A built row's card: each piece's health and look, and Repair while any piece is damaged.
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
	if d.row_damaged(row):
		list.append({"kind": "section", "text": "Repair"})
		list.append(tile("repair", "Repair the row", "Every piece back to full health", d.repair_row_cost(row), "Repair", true,
			d.repair_row_at.bind(int(row["slot"][0]), int(row["slot"][1]))))
	var root := row["root"] as Node3D
	return {"title": "Barricade row", "sub": "Level %d · %d of %d pieces standing" % [d.level("barricade"), standing, ps.size()],
		"anchor": root.position + Vector3(0, 1.4, 0), "rows": list}


## A knocked-down tower's card: Repair stands it up again.
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
