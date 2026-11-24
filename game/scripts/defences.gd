extends Node3D
## The camp's defences (Phase G2, 20 Nov 2026: barricades in rows of 3 built on the roads, repairs on the spot):
##   barricade  built on the roads in rows (barricade_row.gd), never bought in the shop. Each road has 3 spots
##              (world.barricade_slots(), 12 in all), each with a small marker (marker.gd): tap an empty one to build a
##              row of barricade.row.pieces pieces across the road for row.cost; the Hearthtree opens the pads ring by ring (rings_by_home).
##              Each piece has its own health and is hit on its own: whole, cracked below crack_at (darker, leaning),
##              broken at 0 (it falls flat by a little rubble pile, and enemies walk through the gap it leaves). Tap a
##              row to repair it: repair_share of the row's cost for each broken piece, half that for each cracked one.
##   tower      an acorn tower, bought in the shop and placed with the build button anywhere you like; how many you can
##              have is set by the home level. Enemies go for towers right after barricades. Knocked down, it tips over
##              and shows a repair marker: the leaves "Mend the defences" would ask for that tower stand it up again
##              (mend_price, since 21 Nov 2026).
##   spikes     a thorn trap, bought and placed the same way, that hurts and slows whatever walks over it.
## Broken in a mission, barricades and towers are mended for free when the mission is won; when the camp falls, or
## after a Gloom Raid, the damage is kept ("wrecked") until mended (a row's or a tower's card, the shop, the Watch's
## "Mend all"). The Wishing Well mends what is not broken (well_mend). The markers show in the camp (not below ground);
## in a wave only the built rows' markers stay (a row's repair works at any time, 22 Nov 2026). Every piece of a kind shares one level, upgraded on the Hearthtree's card and capped by its
## level. Old saves: fences are refunded as leaves; placed barricades become rows at their road spots, and barricade
## pieces left in the bag are refunded as leaves (each its old price, barricade.piece).

const TowerScript := preload("res://scripts/tower.gd")
const RowScript := preload("res://scripts/barricade_row.gd")
const MarkerScript := preload("res://scripts/marker.gd")
const AHEAD := 1.6
const TYPES := ["barricade", "tower", "spikes"]
const PIECE_R := 0.3                # a barricade piece's collision half-thickness (it stops enemies only)
const MARK_SIDE := 1.15             # a road spot's marker stands this far from its row: where the cat stands to use it
const TOWER_MARK := 1.05            # a downed tower's marker: this far in front of it (on the camera's side)
const MARK_COL := Color(1.0, 0.82, 0.3)
const FIX_COL := Color(1.0, 0.55, 0.35)
const WOOD := Color(0.55, 0.38, 0.22)

var main
var pieces: Array = []          # {"id", "type", "pos", "rot", "node", "hp", "max_hp", "cd", "wrecked", "broken", "slot", "src"}
                                # src: its own Save.placed entry (wrecks are saved by reference, never by index). A
                                # barricade piece also has "root" (its row's node), "k" (its place in the row), "look"
                                # (whole, cracked, broken) and "a", "b" (the ends of its collision)
var rows: Array = []            # {"slot": [road, spot], "root": its barricade_row.gd node, "pieces": [...], "src": its
                                # Save.placed entry {"type": "barricade", "slot", "row": pieces, "wrecks": [...]}}
var placing := ""               # the kind being placed ("tower" or "spikes"), "" when not placing
var ghost: Node3D
var ghost_ok := false
var _ghost_pos := Vector3.ZERO
var _ghost_rot := 0.0
var _next := 0
var _by_id := {}                # piece id -> piece
var _spots := {}                # "road:spot" -> its marker
var _tower_marks := {}          # tower piece id -> its repair marker (shown while it is down)
var _marks := -1                # what the markers last showed for (_marks_state)
var _crack := 0.5               # barricade.crack_at
var _half := 0.5                # half a barricade piece's length
var _dirty := false             # the Well mended a wrecked piece: its Save.placed entry is written soon (not saved)
var _sync_t := 0.0


func build(m) -> void:
	main = m
	_make_spot_marks()
	load_saved()
	if not Save.changed.is_connected(_update_pulses):
		Save.changed.connect(_update_pulses)


## Builds every placed defence from the save (at the start; the tests call it again after changing the save). Old saves
## are brought up to date first: fences refunded, barricade pieces turned into rows, the bag's barricades refunded.
func load_saved() -> void:
	_read_cfg()
	_clear()
	_refund_fences()
	var changed := _rows_from_old()
	if _absorb_bag(true) > 0 or changed:
		Save.save_game()
	_move_blocked()
	for sp in Save.placed:
		if String(sp.get("type", "")) == "barricade":
			_spawn_row_saved(sp)
			continue
		var p := _spawn_saved(sp)
		if p.is_empty():
			continue
		p["src"] = sp
		if sp.has("wreck"):
			_wreck(p, float(sp["wreck"]))
	_marks = -1
	_refresh_marks()


func _read_cfg() -> void:
	var bi := Data.defence_info("barricade")
	_crack = float(bi.get("crack_at", 0.5))
	_half = float(bi.get("length", 3.0)) / float(pieces_per_row()) * 0.5


## Everything built goes (its nodes, collisions and markers); the road spots' markers stay, empty.
func _clear() -> void:
	if placing != "":
		stop_placing()
	for p in pieces:
		main.world.remove_tag("piece_%d" % int(p["id"]))
		if p["type"] != "barricade" and is_instance_valid(p["node"]):
			(p["node"] as Node3D).queue_free()
	for row in rows:
		if is_instance_valid(row["root"]):
			(row["root"] as Node3D).queue_free()
	for id in _tower_marks:
		var mk = _tower_marks[id]
		main.unregister_ring(mk)
		mk.queue_free()
	_tower_marks = {}
	pieces = []
	rows = []
	_by_id = {}
	for s in main.world.barricade_slots():
		_attach_spot(int(s[2]), int(s[3]))
	for key in _spots:
		_spots[key].pulse = false


func _note(msg: String) -> void:
	if main.hud != null:
		main.hud.toast(msg)
	else:
		main.hud_note = msg if main.hud_note == "" else main.hud_note + "\n" + msg


## Fences are gone: any left in an old save are refunded as leaves.
func _refund_fences() -> void:
	var piece := int(Data.defence_info("fence")["piece"])
	var refund := int(Save.items.get("fence", 0)) * piece
	Save.items.erase("fence")
	var keep: Array = []
	for sp in Save.placed:
		if String(sp.get("type", "")) == "fence":
			refund += piece
			continue
		keep.append(sp)
	Save.placed = keep
	if refund > 0:
		Save.leaves += refund
		Save.set_flag("fence_refund")
		Save.save_game()
		_note("Fences are gone: you got %d leaves back. Block the roads with barricades now." % refund)


## Phase G2: a placed barricade piece of an older save becomes a row at its road spot (two at one spot: one row); a
## wrecked one keeps its wreck in each of the row's pieces. True if the save changed.
func _rows_from_old() -> bool:
	var keep: Array = []
	var seen := {}
	var changed := false
	var turned := 0
	for sp in Save.placed:
		if String(sp.get("type", "")) != "barricade":
			keep.append(sp)
			continue
		var sl = sp.get("slot", [])
		if typeof(sl) != TYPE_ARRAY or (sl as Array).size() != 2:
			keep.append(sp)                          # no road spot: kept as it was (it never showed)
			continue
		var key := _key(int(sl[0]), int(sl[1]))
		if seen.has(key):
			changed = true                           # a second piece at the same spot: one row
			continue
		seen[key] = true
		if not sp.has("row"):
			sp["slot"] = [int(sl[0]), int(sl[1])]
			sp["row"] = pieces_per_row()
			if sp.has("wreck"):
				if not sp.has("wrecks"):
					var f := clampf(float(sp["wreck"]), 0.0, 1.0)
					var w: Array = []
					for k in pieces_per_row():
						w.append(f)
					sp["wrecks"] = w
				sp.erase("wreck")
			turned += 1
			changed = true
		keep.append(sp)
	if changed:
		Save.placed = keep
	if turned > 0:
		_note("Barricades stand in rows of %d now, and each piece breaks on its own. Tap a row on the road to repair it." % pieces_per_row())
	return changed


## Barricade pieces in the bag (an older save, or a gift of pieces): each is refunded at its old price and the bag keeps
## no barricades, so the build button never offers one. Returns the leaves given back. Saves unless `at_load`.
func _absorb_bag(at_load := false) -> int:
	if not Save.items.has("barricade"):
		return 0
	var n := int(Save.items.get("barricade", 0))
	Save.items.erase("barricade")
	if n <= 0:
		return 0
	var refund := n * int(Data.defence_info("barricade").get("piece", 30))
	Save.leaves += refund
	_note("Barricades are built at the road spots now: %d barricade piece%s became %d leaves." % [n, "s" if n > 1 else "", refund])
	if not at_load:
		Save.save_game()
		if main.hud != null:
			main.hud.refresh_build()
	return refund


## Phase C (and E: round a Burrow's hollow; and the camp's buildings round the fire since 18 Nov 2026): towers and
## spikes on the ground kept for the stone, the garden, the fishing spot or a building and its ring go back to the bag
## (older saves could place them anywhere off the roads).
func _move_blocked() -> void:
	var moved := 0
	var keep2: Array = []
	for sp in Save.placed:
		var t := String(sp.get("type", ""))
		var at := Vector3(float(sp.get("x", 0.0)), 0, float(sp.get("z", 0.0)))
		if (t == "tower" or t == "spikes") and sp.has("x") and sp.has("z") \
				and (main.world.in_reserved(at, 0.6) or main.world.in_hollow_clear(at) or main.world.near_hollow(at, _hollow_keep())
				or main.world.in_village(at, 0.6) or main.world.near_home(at, 0.6) or main.world.lake_dist(at) < 0.6):
			Save.items[t] = int(Save.items.get(t, 0)) + 1
			moved += 1
			continue
		keep2.append(sp)
	if moved > 0:
		Save.placed = keep2
		_note("%d defence piece%s stood where the camp needs room: place %s again" % [moved, "s" if moved > 1 else "", "them" if moved > 1 else "it"])
		Save.save_game()


func _spawn_saved(sp: Dictionary) -> Dictionary:
	var type := String(sp.get("type", ""))
	if not (type in ["tower", "spikes"]) or not sp.has("x") or not sp.has("z"):
		return {}
	return _spawn(type, Vector3(float(sp["x"]), 0, float(sp["z"])), float(sp.get("rot", 0.0)))


## A saved row: built at its road spot, each piece's kept wreck (Save.placed "wrecks": its share of health, -1 whole).
func _spawn_row_saved(sp: Dictionary) -> Dictionary:
	var sl = sp.get("slot", [])
	if typeof(sl) != TYPE_ARRAY or (sl as Array).size() != 2:
		return {}
	var row := _spawn_row(int(sl[0]), int(sl[1]), sp)
	if row.is_empty():
		return {}
	var w = sp.get("wrecks", [])
	if typeof(w) == TYPE_ARRAY:
		for p in row["pieces"]:
			var k := int(p["k"])
			if k < (w as Array).size() and float(w[k]) >= 0.0:
				_wreck(p, float(w[k]))
	return row


## The camp grew and the trails moved a little: rows (and their markers) follow their road spots.
func rebuild() -> void:
	for row in rows:
		var s: Array = main.world.barricade_slot(int(row["slot"][0]), int(row["slot"][1]))
		if s.is_empty():
			continue
		var root = row["root"]
		root.place(s[0], float(s[1]))
		for p in row["pieces"]:
			p["pos"] = root.piece_pos(int(p["k"]))
			p["rot"] = float(s[1])
			_set_seg(p)
			_collide(p)
	for s in main.world.barricade_slots():
		var mk = _spots.get(_key(int(s[2]), int(s[3])))
		if mk != null:
			var at := _spot_pos(s)
			mk.global_position = Vector3(at.x, 0.03, at.z)
			_attach_spot(int(s[2]), int(s[3]))


func level(type: String) -> int:
	return clampi(int(Save.def_levels.get(type, 1)), 1, (Data.defence_info(type)["levels"] as Array).size())


func model(type: String, lv: int) -> String:
	var name := ""
	match type:
		"barricade": name = String(Data.defence_info("barricade")["levels"][lv - 1].get("model", ""))
		"tower": name = "acorn_tower_%d" % lv
		"spikes": name = "thorn_spikes_%d" % lv
	if lv > 1 and (name == "" or not Props.has(name)):
		return model(type, lv - 1)                  # a level whose model is not made yet shows the one before it
	return name


func unlocked(type: String) -> bool:
	return Data.progress() >= int(Data.defence_info(type).get("unlock_missions", 0))


func _count(type: String) -> int:
	var n := int(Save.items.get(type, 0))
	for p in pieces:
		if p["type"] == type:
			n += 1
	return n


func tower_cap() -> int:
	var t: Array = Data.defence_info("tower")["max_by_camp_level"]
	return int(t[clampi(Save.camp_level, 0, t.size() - 1)])


## True if one more piece of this kind can be bought (towers are capped by the home; barricades are never bought now:
## rows are built at the open road pads).
func room_for(type: String) -> bool:
	match type:
		"tower": return _count("tower") < tower_cap()
		"barricade": return false
	return true


func room_note(type: String) -> String:
	match type:
		"tower": return "%s holds %d towers: grow it for more" % [Data.camp_name(true), tower_cap()]
		"barricade": return "Tap a road spot to build a row"
	return ""


func _max_hp(type: String) -> float:
	if type == "spikes":
		return 1.0
	return float(Data.defence_info(type)["levels"][level(type) - 1].get("hp", 1))


## A tower or spikes (placed with the build button). A barricade asked for at a road spot (older tests) is its row's
## first piece (the row is built if there is none).
func _spawn(type: String, pos: Vector3, rot: float, slot: Array = []) -> Dictionary:
	if type == "barricade":
		if slot.size() != 2:
			return {}
		var have := row_at(int(slot[0]), int(slot[1]))
		var row := have if not have.is_empty() else _spawn_row(int(slot[0]), int(slot[1]), null)
		return row["pieces"][0] if not row.is_empty() else {}
	var node := Props.instance(model(type, level(type)))
	node.position = pos
	node.rotation.y = rot
	add_child(node)
	var p := {"id": _next, "type": type, "pos": pos, "rot": rot, "node": node, "hp": 1.0, "max_hp": _max_hp(type), "cd": 0.0,
		"wrecked": false, "broken": false, "slot": slot, "src": null}
	_next += 1
	p["hp"] = p["max_hp"]
	pieces.append(p)
	_by_id[int(p["id"])] = p
	_collide(p)
	if type == "tower":
		_setup_tower(p)
		_make_tower_mark(p)
	return p


## A row of barricade pieces at a road spot (none there yet). src: its Save.placed entry (null: not saved, tests).
func _spawn_row(lane: int, idx: int, src) -> Dictionary:
	var s: Array = main.world.barricade_slot(lane, idx)
	if s.is_empty() or not row_at(lane, idx).is_empty():
		return {}
	var n := pieces_per_row()
	var root = RowScript.new()
	add_child(root)
	root.setup(lane, idx, s[0], float(s[1]), n, float(Data.defence_info("barricade").get("length", 3.0)))
	var row := {"slot": [lane, idx], "root": root, "pieces": [], "src": src}
	var mx := _max_hp("barricade")
	var nm := model("barricade", level("barricade"))
	for k in n:
		var p := {"id": _next, "type": "barricade", "pos": root.piece_pos(k), "rot": float(s[1]), "node": root.set_model(k, nm),
			"hp": mx, "max_hp": mx, "cd": 0.0, "wrecked": false, "broken": false, "slot": [lane, idx], "src": src,
			"root": root, "k": k, "look": "whole", "a": Vector3.ZERO, "b": Vector3.ZERO}
		_next += 1
		_set_seg(p)
		pieces.append(p)
		_by_id[int(p["id"])] = p
		(row["pieces"] as Array).append(p)
		_collide(p)
	rows.append(row)
	_attach_spot(lane, idx)
	return row


func _collide(p: Dictionary) -> void:
	var tag := "piece_%d" % int(p["id"])
	main.world.remove_tag(tag)
	if float(p["hp"]) <= 0.0:
		return
	match String(p["type"]):
		"barricade":
			main.world.add_segment(p["a"], p["b"], PIECE_R, true, tag)
		"tower":
			main.world.add_circle(p["pos"], 0.6, tag)


## A barricade piece's collision runs along the row over its part of it. The ends it shares with its neighbours are
## pulled in by the collision's own radius, so whole pieces close the road and a broken one leaves a gap as wide as
## itself (1 m: most enemies walk through; the big ones need two).
func _set_seg(p: Dictionary) -> void:
	var n := pieces_per_row()
	var k := int(p.get("k", 0))
	var along := Vector3(cos(float(p["rot"])), 0, -sin(float(p["rot"])))
	var a := _half - (PIECE_R if k > 0 else 0.0)
	var b := _half - (PIECE_R if k < n - 1 else 0.0)
	p["a"] = (p["pos"] as Vector3) - along * a
	p["b"] = (p["pos"] as Vector3) + along * b


## A new level for every piece of a kind (bought on the Hearthtree's card): new models and health. Damage kept after a
## raid or a camp fall keeps its share; the rest is whole.
func relevel(type: String) -> void:
	for p in pieces:
		if p["type"] != type:
			continue
		var share := clampf(float(p["hp"]) / maxf(float(p["max_hp"]), 1.0), 0.0, 1.0)
		p["max_hp"] = _max_hp(type)
		if p["wrecked"]:
			p["hp"] = float(p["max_hp"]) * share
			p["broken"] = float(p["hp"]) <= 0.0
		else:
			p["hp"] = p["max_hp"]
			p["broken"] = false
		if type == "barricade":
			p["node"] = p["root"].set_model(int(p["k"]), model(type, level(type)))
		else:
			(p["node"] as Node3D).queue_free()
			var node := Props.instance(model(type, level(type)))
			node.position = p["pos"]
			node.rotation.y = p["rot"]
			add_child(node)
			p["node"] = node
			if type == "tower":
				_setup_tower(p)
		_show(p)
		_collide(p)
		Fx.boing(p["node"], 0.3)
	_refresh_marks()


## How a piece looks: a barricade piece whole, cracked or broken (barricade_row.gd; `anim`: it falls over); a downed
## tower tips over and darkens.
func _show(p: Dictionary, anim := false) -> void:
	if not is_instance_valid(p["node"]):
		return
	if p["type"] == "barricade":
		var st := piece_stage(p)
		p["look"] = st
		if is_instance_valid(p.get("root")):
			p["root"].show_piece(int(p["k"]), st, anim)
		return
	var node := p["node"] as Node3D
	var down: bool = float(p["hp"]) <= 0.0 or p["broken"]
	if p["type"] == "tower" and node.has_method("set_active"):
		node.call("set_active", not down)
	node.rotation.z = 0.22 if down else 0.0
	Props.set_param(node, "gloom", 0.85 if p["wrecked"] else (0.5 if down else 0.0))


## "whole", "cracked" (below barricade.crack_at of its health) or "broken" (0).
func piece_stage(p: Dictionary) -> String:
	return _stage_of(float(p["hp"]), float(p["max_hp"]))


func _stage_of(hp: float, mx: float) -> String:
	if hp <= 0.0:
		return "broken"
	return "cracked" if hp < mx * _crack else "whole"


## A won mission: everything broken in the fight is mended (damage kept after a Gloom Raid or a camp fall is not: see
## repair_raid).
func repair_all() -> void:
	for p in pieces:
		if p["wrecked"]:
			continue
		p["hp"] = p["max_hp"]
		p["broken"] = false
		_show(p)
		_collide(p)
	_refresh_marks()


## The camp fell, or a Gloom Raid wave was held or ended: whatever is broken or damaged stays that way until mended.
## Returns how many pieces.
func keep_damage(quiet := false) -> int:
	var n := 0
	for p in pieces:
		if p["type"] != "spikes" and float(p["hp"]) < float(p["max_hp"]) - 0.5:
			_wreck(p, float(p["hp"]) / float(p["max_hp"]))
			n += 1
	_save_wrecks(quiet)
	return n


func _wreck(p: Dictionary, frac: float) -> void:
	p["wrecked"] = true
	p["hp"] = float(p["max_hp"]) * clampf(frac, 0.0, 1.0)
	p["broken"] = float(p["hp"]) <= 0.0
	_show(p)
	_collide(p)


## Every piece writes its wreck into its own Save.placed entry (by reference: placing or losing pieces never shifts it),
## then the game is saved.
func _save_wrecks(quiet := false) -> void:
	_write_wrecks()
	Save.save_game(quiet)


## The wrecks into the Save.placed entries (not saved yet): a row's "wrecks" holds each piece's share of health (-1:
## not wrecked; its "wreck" the weakest one's, for older readers: loading uses "wrecks"), a tower's "wreck" its own.
func _write_wrecks() -> void:
	for row in rows:
		var sp = _row_src(row)
		if sp == null:
			continue
		var worst := 2.0
		for p in row["pieces"]:
			if p["wrecked"]:
				worst = minf(worst, float(p["hp"]) / maxf(float(p["max_hp"]), 1.0))
		if worst > 1.5:
			sp.erase("wrecks")
			sp.erase("wreck")
			continue
		var w: Array = []
		for p in row["pieces"]:
			w.append(snappedf(float(p["hp"]) / maxf(float(p["max_hp"]), 1.0), 0.0001) if p["wrecked"] else -1.0)
		sp["wrecks"] = w
		sp["wreck"] = worst
	for p in pieces:
		if p["type"] == "barricade":
			continue
		var sp2 = p.get("src")
		if sp2 == null:
			continue
		if p["wrecked"]:
			sp2["wreck"] = float(p["hp"]) / float(p["max_hp"])
		else:
			sp2.erase("wreck")


## A row's Save.placed entry (an older test sets it on the row's first piece).
func _row_src(row: Dictionary):
	if row["src"] == null:
		for p in row["pieces"]:
			if p.get("src") != null:
				row["src"] = p["src"]
				break
	return row["src"]


## Points every row and piece at its Save.placed entry again (after the save was read back in while the camp stands:
## tests).
func relink_saved() -> void:
	for row in rows:
		row["src"] = null
		for sp in Save.placed:
			if String(sp.get("type", "")) != "barricade":
				continue
			var sl = sp.get("slot", [])
			if typeof(sl) == TYPE_ARRAY and (sl as Array).size() == 2 and int(sl[0]) == int(row["slot"][0]) and int(sl[1]) == int(row["slot"][1]):
				row["src"] = sp
				break
		for p in row["pieces"]:
			p["src"] = row["src"]
	for p in pieces:
		if p["type"] == "barricade":
			continue
		p["src"] = null
		for sp in Save.placed:
			if String(sp.get("type", "")) == String(p["type"]) and sp.has("x") \
					and absf(float(sp["x"]) - (p["pos"] as Vector3).x) < 0.01 and absf(float(sp["z"]) - (p["pos"] as Vector3).z) < 0.01:
				p["src"] = sp
				break


## What it costs to mend every wrecked piece (0 when nothing is).
func repair_cost() -> int:
	if Data.raids_open():
		var sum := 0
		for p in pieces:
			if p["wrecked"]:
				sum += piece_mend_cost(p)
		return sum
	var share := float(Data.b["raid"]["repair_share"])
	var cost := 0.0
	for p in pieces:
		if p["wrecked"]:
			var piece := float(Data.defence_info(String(p["type"]))["piece"])
			cost += piece * share * (1.0 - float(p["hp"]) / float(p["max_hp"]))
	return 0 if cost <= 0.0 else maxi(5, int(ceil(cost)))


## Once raids are open, what one wrecked piece costs to mend: piece price x (1 + mend_per_level x (level - 1)) x
## mend_share x the share it is missing, rounded up. (A barricade piece's price is barricade.piece: a third of a row.)
func piece_mend_cost(p: Dictionary) -> int:
	if not p["wrecked"]:
		return 0
	return _endgame_mend(p)


## What "Mend the defences" (repair_cost) would ask for this one piece if it were the only one wrecked, whether it is
## wrecked or only knocked down in a wave (21 Nov 2026: a downed tower's own repair marker costs this): during the
## missions its piece price x raid.repair_share x the share it is missing (at least 5, rounded up); after them
## (Data.raids_open) the endgame price, piece_mend_cost's rule. 0 when it is whole.
func mend_price(p: Dictionary) -> int:
	if p.is_empty() or float(p["hp"]) >= float(p["max_hp"]):
		return 0
	if Data.raids_open():
		return _endgame_mend(p)
	var piece := float(Data.defence_info(String(p["type"]))["piece"])
	var cost := piece * float(Data.b["raid"]["repair_share"]) * (1.0 - float(p["hp"]) / float(p["max_hp"]))
	return 0 if cost <= 0.0 else maxi(5, int(ceil(cost)))


func _endgame_mend(p: Dictionary) -> int:
	var r: Dictionary = Data.gr()["repair"]
	var t := String(p["type"])
	var missing := clampf(1.0 - float(p["hp"]) / maxf(float(p["max_hp"]), 1.0), 0.0, 1.0)
	var c := float(Data.defence_info(t)["piece"]) * (1.0 + float(r["mend_per_level"]) * (level(t) - 1)) * float(r["mend_share"]) * missing
	return maxi(1, int(ceil(c - 0.0001)))


## Mends one wrecked piece (Mend some, Mend all: the caller pays). Returns false if it was not wrecked.
func mend_piece(p: Dictionary, quiet_save := false, fx := true) -> bool:
	if not p["wrecked"]:
		return false
	_mend(p)
	if fx:
		Fx.boing(p["node"], 0.25)
		Fx.flower_ring(main, p["pos"], 0.9)
	_save_wrecks(quiet_save)
	_refresh_marks()
	return true


## A piece whole again: full health, standing, not wrecked.
func _mend(p: Dictionary) -> void:
	p["wrecked"] = false
	p["broken"] = false
	p["hp"] = p["max_hp"]
	_show(p)
	_collide(p)


## How well a trail is guarded (sneak raids pick the weakest): the health of its standing barricade pieces, plus a set
## amount for each standing tower whose range (+ a little) reaches the trail's midpoint.
func lane_guard(ln: int) -> float:
	var g := 0.0
	var cfg: Dictionary = Data.gr()["lane_guard"]
	var w = main.world
	if ln < 0 or ln >= w.trails.size():
		return 0.0
	var mid: Vector3 = w.trail_point(ln, 0.5 * w.trail_length(ln))
	var rng := float(Data.defence_info("tower")["levels"][level("tower") - 1]["range"]) + float(cfg["tower_reach_bonus"])
	for p in pieces:
		if float(p["hp"]) <= 0.0:
			continue
		if p["type"] == "barricade" and (p["slot"] as Array).size() == 2 and int(p["slot"][0]) == ln:
			g += float(p["hp"])
		elif p["type"] == "tower" and (p["pos"] as Vector3).distance_to(mid) <= rng:
			g += float(cfg["tower"])
	return g


func wrecked_count() -> int:
	var n := 0
	for p in pieces:
		if p["wrecked"]:
			n += 1
	return n


func repair_raid() -> void:
	for p in pieces:
		if not p["wrecked"]:
			continue
		_mend(p)
		Fx.boing(p["node"], 0.25)
	_save_wrecks()
	_refresh_marks()


# ---------------------------------------------------------------- barricade rows (Phase G2)
func pieces_per_row() -> int:
	var r = Data.defence_info("barricade").get("row", {})
	return maxi(1, int(r.get("pieces", 3))) if typeof(r) == TYPE_DICTIONARY else 3


## What a row costs to build (barricade.row.cost: leaves and timber).
func row_cost() -> Dictionary:
	var out := {}
	var r = Data.defence_info("barricade").get("row", {})
	var c = r.get("cost", {}) if typeof(r) == TYPE_DICTIONARY else {}
	if typeof(c) == TYPE_DICTIONARY:
		for k in c:
			if int(c[k]) > 0:
				out[String(k)] = int(c[k])
	return out


## How many rings of road pads are open at the Hearthtree's level (barricade.rings_by_home), nearest the camp first:
## ring 0 = the pad nearest the camp on each road (idx 2), ring 1 = the middle (idx 1), ring 2 = the far one (idx 0).
func rings_open() -> int:
	var t = Data.defence_info("barricade").get("rings_by_home", [])
	if typeof(t) != TYPE_ARRAY or (t as Array).is_empty():
		return 3
	return int(t[clampi(Save.camp_level, 0, (t as Array).size() - 1)])


## The rings set the default unlocks. Some roads open their far pad a Hearthtree level earlier.
func pad_open(lane: int, idx: int) -> bool:
	if (2 - idx) < rings_open():
		return true
	if idx != 0 or lane < 0 or lane >= Data.patch_count():
		return false
	var far_pad: Dictionary = Data.patch(lane).get("far_pad", {})
	var home := int(far_pad.get("home", 0))
	return home > 0 and Save.camp_level >= home


## How many of the road pads are open, and how many there are (the Hearthtree's card).
func pads_open_count() -> int:
	var n := 0
	for s in main.world.barricade_slots():
		if pad_open(int(s[2]), int(s[3])):
			n += 1
	return n


func rows_built() -> int:
	return rows.size()


## The row at a road spot ({} when the spot is empty).
func row_at(lane: int, idx: int) -> Dictionary:
	for row in rows:
		if int(row["slot"][0]) == lane and int(row["slot"][1]) == idx:
			return row
	return {}


## True if any piece of the row has lost health.
func row_damaged(row: Dictionary) -> bool:
	for p in row.get("pieces", []):
		if float(p["hp"]) < float(p["max_hp"]) - 0.5:
			return true
	return false


## Builds a row at an empty, open road pad (its card's Build): row.cost paid. True if built.
func build_row(lane: int, idx: int) -> bool:
	if _wave_on() or main.area != null or not unlocked("barricade") or not pad_open(lane, idx) or not row_at(lane, idx).is_empty():
		return false
	var s: Array = main.world.barricade_slot(lane, idx)
	if s.is_empty() or not Data.pay(row_cost()):
		return false
	var sp := {"type": "barricade", "slot": [lane, idx], "row": pieces_per_row()}
	Save.placed.append(sp)
	var row := _spawn_row(lane, idx, sp)
	Save.save_game()
	for p in row.get("pieces", []):
		Fx.boing(p["node"], 0.35)
	Fx.flower_ring(main, s[0], 1.5)
	_update_pulses()
	if main.hud != null:
		main.hud.banner("Barricade row built!", Color(1.0, 0.9, 0.45), "Enemies must break it to get past")
		main.on_purchase()
	return true


## A row's repair: repair_share of the row's build cost for each broken piece and half that for each cracked one,
## rounded up; a piece hurt but not yet cracked costs its missing share of health (22 Nov 2026).
func repair_row_cost(row: Dictionary) -> Dictionary:
	var share := float(Data.defence_info("barricade").get("repair_share", 0.3))
	var units := 0.0
	for p in row.get("pieces", []):
		match piece_stage(p):
			"broken": units += 1.0
			"cracked":                              # at least half a piece, more the nearer it is to breaking (22 Nov review)
				var mxc := maxf(float(p["max_hp"]), 1.0)
				units += clampf(1.0 - float(p["hp"]) / mxc, 0.5, 1.0)
			_:
				var mx := maxf(float(p["max_hp"]), 1.0)
				units += clampf(1.0 - float(p["hp"]) / mx, 0.0, 1.0)    # 22 Nov 2026: hurt, not cracked: its missing health
	var out := {}
	if units <= 0.0:
		return out
	var base := row_cost()
	for k in base:
		var n := int(ceil(float(base[k]) * share * units - 0.0001))
		if n > 0:
			out[k] = n
	return out


## Repairs a row (its card's Repair): paid, every piece back to full health and standing. True if done.
func repair_row(row: Dictionary) -> bool:
	if row.is_empty() or not row_damaged(row):         # any time, in a wave too (22 Nov 2026)
		return false
	if not Data.pay(repair_row_cost(row)):
		return false
	for p in row["pieces"]:
		_mend(p)
		Fx.boing(p["node"], 0.25)
	Fx.flower_ring(main, (row["root"] as Node3D).position, 1.5)
	_save_wrecks()
	_refresh_marks()
	if main.hud != null:
		main.hud.banner("Row repaired!", Color(1.0, 0.9, 0.5), "Every piece is whole again")
		main.on_purchase()
	return true


func repair_row_at(lane: int, idx: int) -> bool:
	return repair_row(row_at(lane, idx))


## A knocked-down tower's repair (its marker's card): since 21 Nov 2026 the same leaves "Mend the defences" would ask
## for this tower (mend_price: during the missions and after them alike), so the two never disagree. ({} for no tower.)
func tower_repair_cost(p: Dictionary) -> Dictionary:
	if p.is_empty():
		return {}
	return {"leaves": mend_price(p)}


## Stands a knocked-down tower up at full health (its card's Repair). True if done.
func repair_tower(p: Dictionary) -> bool:
	if p.is_empty() or String(p["type"]) != "tower" or float(p["hp"]) > 0.0 or _wave_on():
		return false
	if not Data.pay(tower_repair_cost(p)):
		return false
	_mend(p)
	Fx.boing(p["node"], 0.3)
	Fx.flower_ring(main, p["pos"], 1.2)
	_save_wrecks()
	_refresh_marks()
	if main.hud != null:
		main.hud.banner("Tower repaired!", Color(1.0, 0.9, 0.5), "It shoots again")
		main.on_purchase()
	return true


func repair_tower_id(id: int) -> bool:
	return repair_tower(_by_id.get(id, {}))


## The Wishing Well (stations.gd calls it every frame): every barricade piece and tower that is not broken mends by
## regen_share of its health a second, never above cap_share of it (nor above full); a cracked piece mended past
## crack_at looks whole again. Broken things wait for a repair or a mission won. No allocations.
func well_mend(dt: float, regen_share: float, cap_share: float) -> void:
	if main == null or main.frozen or dt <= 0.0 or regen_share <= 0.0:
		return
	var d := minf(dt, 0.1)
	var top := clampf(cap_share, 0.0, 1.0)
	for p in pieces:
		if p["type"] == "spikes":
			continue
		var hp: float = p["hp"]
		if hp <= 0.0:
			continue
		var mx: float = p["max_hp"]
		var cap := top * mx
		if hp >= cap:
			continue
		hp = minf(hp + regen_share * mx * d, cap)
		p["hp"] = hp
		if p["wrecked"]:
			_dirty = true                           # its Save.placed entry is written within a second (_process)
			if hp >= mx - 0.5:
				p["wrecked"] = false
				_show(p)                            # 22 Nov 2026 review: a mended tower loses its dark wrecked look too
				continue
		if p["type"] == "barricade" and _stage_of(hp, mx) != p["look"]:
			_show(p)


func _wave_on() -> bool:
	return main.fight != null and main.fight.active and main.fight.in_wave


# ---------------------------------------------------------------- the markers: road spots and downed towers
static func _key(lane: int, idx: int) -> String:
	return "%d:%d" % [lane, idx]


## A small marker at every road spot (the "barricade" badge): its card builds a row there, or shows the row's pieces
## and repairs it.
func _make_spot_marks() -> void:
	for s in main.world.barricade_slots():
		var lane := int(s[2])
		var idx := int(s[3])
		var mk = MarkerScript.new()
		add_child(mk)
		mk.setup("road_%d_%d" % [lane, idx], _spot_pos(s), 0.75, _card_spot.bind(lane, idx), MARK_COL)
		mk.visible = false
		main.register_ring(mk)
		_spots[_key(lane, idx)] = mk
		_attach_spot(lane, idx)


## Where the cat stands to use a road spot: beside the row on the camp's side, or on the woods' side when the camp's
## side is away from the camera (so the row never hides the cat).
func _spot_pos(s: Array) -> Vector3:
	var rot := float(s[1])
	var woods := Vector3(sin(rot), 0.0, cos(rot))
	var side := -woods
	if side.z < -0.3:
		side = woods
	return (s[0] as Vector3) + side * MARK_SIDE


## A spot's badge floats over its row (tapping the row opens it too), or over the empty spot.
func _attach_spot(lane: int, idx: int) -> void:
	var mk = _spots.get(_key(lane, idx))
	if mk == null:
		return
	var row := row_at(lane, idx)
	if not row.is_empty():
		mk.attach(row["root"], "barricade", 1.45)
		return
	var s: Array = main.world.barricade_slot(lane, idx)
	var at: Vector3 = s[0] if not s.is_empty() else mk.global_position
	mk.attach(null, "barricade", 1.2, Vector3(at.x - mk.global_position.x, 0.0, at.z - mk.global_position.z))


## A tower's repair marker (the "repair" badge), shown while it is knocked down.
func _make_tower_mark(p: Dictionary) -> void:
	var id := int(p["id"])
	var mk = MarkerScript.new()
	add_child(mk)
	mk.setup("tower_%d" % id, (p["pos"] as Vector3) + Vector3(0, 0, TOWER_MARK), 0.75, _card_tower.bind(id), FIX_COL)
	mk.visible = false
	main.register_ring(mk)
	_tower_marks[id] = mk


## 0: no markers (the cat is below ground); 1: the downed towers' only; 2: the open road pads' too (once barricades are
## open); 3: a wave is on: only the built rows' markers (their repair works in a wave). Include the Hearthtree level
## because pads on individual roads can open even when the number of open rings stays the same.
func _marks_state() -> int:
	var base := 1
	if main.area != null:
		base = 0
	elif _wave_on():
		base = 3 if unlocked("barricade") else 0        # in a wave: only the built rows' markers (to repair them)
	elif unlocked("barricade"):
		base = 2
	return base + 10 * Save.camp_level


func _refresh_marks() -> void:
	var full := _marks_state()
	_marks = full
	var st := full % 10
	for key in _spots:
		var parts: PackedStringArray = String(key).split(":")
		var ln := int(parts[0])
		var ix := int(parts[1])
		var built := not row_at(ln, ix).is_empty()
		# a built row's marker always shows (even on a pad not open yet: an older save); an empty pad's only when open
		_spots[key].visible = (st == 2 and (built or pad_open(ln, ix))) or (st == 3 and built)
	for id in _tower_marks:
		var mk = _tower_marks[id]
		var p: Dictionary = _by_id.get(id, {})
		var show := (st == 1 or st == 2) and not p.is_empty() and float(p["hp"]) <= 0.0
		if show and (not is_instance_valid(mk.obj) or mk.obj != p["node"]):
			mk.attach(p["node"], "repair")             # over the tipped tower (a new level: its new model)
		mk.visible = show
	_update_pulses()


## The "!" on a marker: a cracked or broken row, or a downed tower, that can be repaired now.
func _update_pulses() -> void:
	for row in rows:
		var mk = _spots.get(_key(int(row["slot"][0]), int(row["slot"][1])))
		if mk == null:
			continue
		var need := false
		for p in row["pieces"]:
			if piece_stage(p) != "whole":
				need = true
		mk.pulse = need and Data.can_afford(repair_row_cost(row))
	for id in _tower_marks:
		var p: Dictionary = _by_id.get(id, {})
		_tower_marks[id].pulse = not p.is_empty() and float(p["hp"]) <= 0.0 and Data.can_afford(tower_repair_cost(p))


# ---------------------------------------------------------------- the cards (shop-style tiles: hud.gd)
func _camp_name() -> String:
	return String(Data.call("camp_name")) if Data.has_method("camp_name") else "the Hearthtree"


func _tile(icon: String, title: String, text: String, cost: Dictionary, label: String, ok: bool, action: Callable,
		badge := "", stats: Array = []) -> Dictionary:
	var t := {"kind": "item", "icon": icon, "title": title, "text": text, "cost": cost, "label": label,
		"enabled": ok and label != "" and action.is_valid() and Data.can_afford(cost), "action": action}
	if badge != "":
		t["badge"] = badge
	if not stats.is_empty():
		t["stats"] = stats
	return t


## A health bar's share: this much health against the top barricade level's.
func _hp_bar(hp: float) -> float:
	var lv: Array = Data.defence_info("barricade")["levels"]
	return clampf(hp / maxf(float(lv[lv.size() - 1].get("hp", hp)), 1.0), 0.05, 1.0)


## "90 leaves and 5 timber": a price in words.
func _price_words(cost: Dictionary) -> String:
	var bits: Array = []
	for k in Data.CURRENCIES:
		var n := int(cost.get(k, 0))
		if n > 0:
			bits.append("%d %s" % [n, Data.mat_name(String(k)) if k in Data.MATS else String(k)])
	if bits.size() <= 1:
		return "".join(bits)
	return ", ".join(bits.slice(0, bits.size() - 1)) + " and " + String(bits[bits.size() - 1])


## A road pad's card: build a row there, or (built) the row's own card. When Build can't be pressed the tile says why.
func _card_spot(lane: int, idx: int) -> Dictionary:
	var row := row_at(lane, idx)
	if not row.is_empty():
		return _card_row(row)
	var s: Array = main.world.barricade_slot(lane, idx)
	var at: Vector3 = s[0] if not s.is_empty() else Vector3.ZERO
	var mx := _max_hp("barricade")
	var cost := row_cost()
	var can := unlocked("barricade") and pad_open(lane, idx) and not _wave_on() and main.area == null
	var it := _tile("barricade", "Barricade row", "%d pieces across the road · %d health each" % [pieces_per_row(), int(mx)],
		cost, "Build", can, build_row.bind(lane, idx), "", [["Health", _hp_bar(mx)]])
	if not unlocked("barricade"):
		it["text"] = "Barricades open later"
	elif not pad_open(lane, idx):
		it["text"] = "This pad opens as the %s grows" % _camp_name().trim_prefix("the ")
	elif _wave_on():
		it["text"] = "A wave is on: build between waves"
	elif not Data.can_afford(cost):
		it["text"] = "Needs %s" % _price_words(cost)
	return {"title": "Road spot", "sub": "Barricade row on this road", "anchor": at + Vector3(0, 1.4, 0),
		"rows": [{"kind": "section", "text": "Block the road"}, it]}


## A built row's card: each piece's health and look, and Repair while any piece is damaged.
func _card_row(row: Dictionary) -> Dictionary:
	var ps: Array = row["pieces"]
	var list: Array = [{"kind": "section", "text": "Pieces"}]
	var standing := 0
	for p in ps:
		var st := piece_stage(p)
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
		list.append(_tile("barricade", "Piece %d" % (int(p["k"]) + 1), txt, {}, "", false, Callable(), badge, [["Health", share]]))
	if row_damaged(row):
		list.append({"kind": "section", "text": "Repair"})
		list.append(_tile("repair", "Repair the row", "Every piece back to full health", repair_row_cost(row), "Repair", true,
			repair_row_at.bind(int(row["slot"][0]), int(row["slot"][1]))))
	var root := row["root"] as Node3D
	return {"title": "Barricade row", "sub": "Level %d · %d of %d pieces standing" % [level("barricade"), standing, ps.size()],
		"anchor": root.position + Vector3(0, 1.4, 0), "rows": list}


## A knocked-down tower's card: Repair stands it up again.
func _card_tower(id: int) -> Dictionary:
	var p: Dictionary = _by_id.get(id, {})
	var title := String(Data.defence_info("tower").get("name", "Acorn Tower"))
	if p.is_empty():
		return {"title": title, "sub": "", "rows": []}
	var at: Vector3 = (p["pos"] as Vector3) + Vector3(0, 2.2, 0)
	if float(p["hp"]) > 0.0:
		return {"title": title, "sub": "Standing and shooting", "rows": [], "anchor": at}
	var it := _tile("repair", "Repair the tower", "It stands up at full health and shoots again", tower_repair_cost(p), "Repair",
		not _wave_on(), repair_tower_id.bind(id), "Broken", [["Health", 0.0]])
	return {"title": title, "sub": "Knocked down by the Gloom", "anchor": at, "rows": [{"kind": "section", "text": "Repair"}, it]}


# ---------------------------------------------------------------- placing (towers and spikes)
func start_placing(type: String) -> void:
	if type == "barricade" or int(Save.items.get(type, 0)) <= 0:
		return                                      # barricades are built in rows at the road spots (their markers)
	stop_placing()
	placing = type
	ghost = Props.instance(model(type, level(type)))
	add_child(ghost)
	main.hud.refresh_build()


func stop_placing() -> void:
	if ghost:
		ghost.queue_free()
	ghost = null
	placing = ""
	if main != null and main.hud:
		main.hud.refresh_build()


func _process(delta: float) -> void:
	if main == null:
		return
	if Save.items.has("barricade"):
		_absorb_bag()                               # a gift of pieces (an older mission reward): refunded as leaves
	if _marks_state() != _marks:
		_refresh_marks()                            # a wave started or ended, the cat went below ground or came up
	if _dirty:
		_sync_t += minf(delta, 0.1)
		if _sync_t >= 1.0:
			_sync_t = 0.0
			_dirty = false
			_write_wrecks()
	if placing == "" or ghost == null:
		return
	var t := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	var cat: Vector3 = main.player.global_position
	var f: float = main.player.facing
	_ghost_pos = cat + Vector3(sin(f), 0, cos(f)) * AHEAD
	_ghost_pos.y = 0.0
	_ghost_rot = f
	ghost_ok = _valid(_ghost_pos)
	ghost.position = _ghost_pos + Vector3(0, 0.02, 0)
	ghost.rotation.y = _ghost_rot
	Props.set_param(ghost, "tint", Color(0.7, 1.25, 0.7) if ghost_ok else Color(1.3, 0.45, 0.4))
	Props.set_param(ghost, "flash", 0.15 + 0.15 * t)


func _valid(pos: Vector3) -> bool:
	var r := Vector2(pos.x, pos.z).length()
	if r < 1.5 or r > main.world.MOVE_R - 0.3:
		return false
	if main.world.in_reserved(pos, 0.6) or main.world.in_village(pos, 0.6):
		return false                                   # the ground kept for the camp's stations, built or not
	if main.world.in_hollow_clear(pos) or main.world.near_hollow(pos, _hollow_keep()):
		return false                                   # Phase E: the Burrows' hollows and their paths stay clear
	var q := Vector2(pos.x, pos.z)
	for c in main.world.circles:
		if String(c[2]).begins_with("piece_"):
			continue
		if q.distance_to(c[0]) < float(c[1]) + 0.6:
			return false
	for p in pieces:
		if (p["pos"] as Vector3).distance_to(pos) < 0.9:
			return false
	return main.world.path_strength(pos) < 0.5 or placing == "spikes"


func place_here() -> void:
	if placing == "" or not ghost_ok or int(Save.items.get(placing, 0)) <= 0:
		return
	Save.items[placing] = int(Save.items[placing]) - 1
	var sp := {"type": placing, "x": _ghost_pos.x, "z": _ghost_pos.z, "rot": _ghost_rot}
	Save.placed.append(sp)
	var p := _spawn(placing, _ghost_pos, _ghost_rot)
	p["src"] = sp
	Save.save_game()
	Fx.boing(p["node"], 0.35)
	Fx.flower_ring(main, _ghost_pos, 1.0)
	Sfx.play("buy", -6.0)
	if int(Save.items[placing]) <= 0:
		stop_placing()
	else:
		var keep := placing
		stop_placing()
		start_placing(keep)


# ---------------------------------------------------------------- what enemies ask
class PieceHandle:
	extends RefCounted
	var owner_ref
	var id := 0
	var kind := ""
	var global_position := Vector3.ZERO

	func hurt(amount: int) -> void:
		owner_ref.hurt_piece(id, amount)


func _handle(p: Dictionary) -> PieceHandle:
	var h := PieceHandle.new()
	h.owner_ref = self
	h.id = int(p["id"])
	h.kind = String(p["type"])
	h.global_position = p["pos"]
	return h


## The standing barricade piece touching a walker at pos (radius r), or null.
func fence_hit(pos: Vector3, r: float):
	for p in pieces:
		if p["type"] != "barricade" or float(p["hp"]) <= 0.0:
			continue
		var a: Vector3 = p["a"]
		var ab: Vector3 = (p["b"] as Vector3) - a
		var t := clampf((pos - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var q := a + ab * t
		if Vector2(pos.x - q.x, pos.z - q.z).length() < r + PIECE_R:
			return _handle(p)
	return null


## Standing towers enemies can go for: [handle, position, radius].
func tower_targets() -> Array:
	var out: Array = []
	for p in pieces:
		if p["type"] == "tower" and float(p["hp"]) > 0.0:
			out.append([_handle(p), p["pos"], 0.6])
	return out


func near(pos: Vector3, r: float) -> Array:
	var out: Array = []
	for p in pieces:
		if p["type"] != "spikes" and float(p["hp"]) > 0.0 and (p["pos"] as Vector3).distance_to(pos) < r:
			out.append(_handle(p))
	return out


func slow_at(pos: Vector3) -> float:
	for p in pieces:
		if p["type"] == "spikes" and not p["broken"] and (p["pos"] as Vector3).distance_to(pos) < 0.8:
			return float(Data.defence_info("spikes")["levels"][level("spikes") - 1]["slow"])
	return 0.0


## A hit on one piece: a barricade piece cracks below crack_at and breaks at 0; a tower is knocked down at 0.
func hurt_piece(id: int, amount: int) -> void:
	main.fight.busy()
	var p: Dictionary = _by_id.get(id, {})
	if p.is_empty() or p["type"] == "spikes" or float(p["hp"]) <= 0.0:
		return
	p["hp"] = maxf(0.0, float(p["hp"]) - amount)
	Fx.hit(main, (p["pos"] as Vector3) + Vector3(0, 0.6, 0), WOOD)
	if float(p["hp"]) <= 0.0:
		_break(p)
		return
	Fx.boing(p["node"], 0.12)
	if p["type"] == "barricade" and piece_stage(p) != String(p["look"]):
		_show(p)                                    # it cracks
		_update_pulses()


## A piece at 0: a barricade piece falls flat in a puff of dust and wood chips, leaving a gap; a tower tips over.
func _break(p: Dictionary) -> void:
	p["broken"] = true
	var at: Vector3 = p["pos"]
	if p["type"] == "barricade":
		Fx.dust(main, at, 9, 1.3)
		Fx.puff(main, at + Vector3(0, 0.45, 0), WOOD, 10)
		Fx.text(main, at + Vector3(0, 1.2, 0), "Barricade broken!", Color(1, 0.6, 0.4))
	else:
		Fx.kill(main, at + Vector3(0, 0.6, 0), WOOD)
		Fx.text(main, at + Vector3(0, 1.4, 0), "Tower down!", Color(1, 0.6, 0.4))
	_show(p, true)
	_collide(p)
	_refresh_marks()


# ---------------------------------------------------------------- towers and spikes at work
func _setup_tower(p: Dictionary) -> void:
	var node = p["node"]
	node.set_script(TowerScript)
	node.setup(main, p, level("tower"))


func _physics_process(delta: float) -> void:
	if main == null or main.frozen:
		return
	var foes := get_tree().get_nodes_in_group("foes")
	for p in pieces:
		if p["broken"] or float(p["hp"]) <= 0.0:
			continue
		match String(p["type"]):
			"tower":
				var tower = p["node"]
				tower.tick(delta, foes)
			"spikes":
				var l2: Dictionary = Data.defence_info("spikes")["levels"][level("spikes") - 1]
				for e in foes:
					if not e.dead and (e.global_position as Vector3).distance_to(p["pos"]) < 0.8:
						e.hp -= float(l2["dps"]) * delta
						if e.hp <= 0.0:
							e.hit(Vector3.ZERO, 0.0)


## Phase E: how far placed defences keep from a Burrow's hollow.
func _hollow_keep() -> float:
	return float(Data.burrow_list()[0]["entrance"].get("defence_keep_out", 2.6))
