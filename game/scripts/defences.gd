extends Node3D
## The camp's defences (Phase G2, 20 Nov 2026: barricades in rows of 3 built on the roads, repairs on the spot):
##   barricade  built on the roads in rows (barricade_row.gd), never bought in the shop. Each road has 3 spots
##              (world.barricade_slots(), 12 in all), each with a small marker (marker.gd): tap an empty one to build a
##              row of barricade.row.pieces pieces across the road for row.cost; the Hearthtree opens the pads ring by ring (rings_by_home).
##              Each piece has its own health and is hit on its own: whole, cracked below crack_at (darker, leaning),
##              broken at 0 (it falls flat by a little rubble pile, and enemies walk through the gap it leaves). Tap a
##              row to repair it: repair_share of the row's cost for each broken piece, half that for each cracked one.
##   tower      an acorn tower, bought in the shop into the Bag (H3) and placed from the Bag (its Place button, or the
##              row-2 defence button) anywhere the ghost is green; how many you can have is set by the home level.
##              Enemies go for towers right after barricades. Knocked down, it tips over and shows a repair marker: the
##              leaves "Mend the defences" would ask for that tower stand it up again (mend_price, since 21 Nov 2026).
##   spikes     a thorn trap, bought and placed the same way, that hurts and slows whatever walks over it.
## H3 (26 Nov 2026): the counts of towers and spikes not placed yet go through the Bag (core/bag.gd; they stay in
## Save.items). A placed piece drops in with a bounce and a puff of dust.
## Broken in a mission, barricades and towers are mended for free when the mission is won; when the camp falls, or
## after a Gloom Raid, the damage is kept ("wrecked") until mended (a row's or a tower's card, the shop, the Watch's
## "Mend all"). The Wishing Well mends what is not broken (well_mend). The markers show in the camp (not below ground);
## in a wave only the built rows' markers stay (a row's repair works at any time, 22 Nov 2026). Every piece of a kind
## shares one level, upgraded on the Hearthtree's card and capped by its level.
## H6 Stage 1 (27 Nov 2026): this file is the FACADE. The game plays as in H5, but the work is split by job:
##   scripts/defence_placement.gd  the ghost, Place, Undo and the Bag/Save transaction (B0); start_placing,
##                                  stop_placing, place_here, placing, ghost, ghost_ok, _ghost_pos, _valid forward to it
##   scripts/defence_persistence.gd old-save clean-up, wrecks into Save.placed, relink after a reload (B1; static)
##   scripts/defence_markers.gd     the road-spot and tower markers and their cards (_spots, _card_spot ... forward)
## What stays here: the pieces and rows, levels, repair and Well mending, what enemies ask, and the towers' and spikes'
## work. Towers find foes through main.enemy_grid; spikes hurt through enemy.hurt_spikes (one damage path).
## Ids only grow (_next is never reset), so an old receipt can never match a new piece.

const TowerScript := preload("res://scripts/tower.gd")
const RowScript := preload("res://scripts/barricade_row.gd")
const MarkersScript := preload("res://scripts/defence_markers.gd")
const PlacementScript := preload("res://scripts/defence_placement.gd")
const DefencePersistence := preload("res://scripts/defence_persistence.gd")
const UndoPlaceDefence := preload("res://commands/undo_place_defence.gd")
const AHEAD := 1.6                  # how far in front of the cat the ghost stands (defence_placement.gd reads it here)
const TYPES := ["barricade", "tower", "spikes"]
const PIECE_R := 0.3                # a barricade piece's collision half-thickness (it stops enemies only)
const SPIKE_R := 0.8                # a thorn patch hurts and slows what is this close to it (m)
const WOOD := Color(0.55, 0.38, 0.22)

var main
var pieces: Array = []          # {"id", "type", "pos", "rot", "node", "hp", "max_hp", "cd", "wrecked", "broken", "slot", "src"}
                                # src: its own Save.placed entry (wrecks are saved by reference, never by index). A
                                # barricade piece also has "root" (its row's node), "k" (its place in the row), "look"
                                # (whole, cracked, broken) and "a", "b" (the ends of its collision)
var rows: Array = []            # {"slot": [road, spot], "root": its barricade_row.gd node, "pieces": [...], "src": its
                                # Save.placed entry {"type": "barricade", "slot", "row": pieces, "wrecks": [...]}}
var _next := 0                  # the next piece id: only grows, never reset (a cleared camp keeps counting)
var _by_id := {}                # piece id -> piece
var _crack := 0.5               # barricade.crack_at
var _half := 0.5                # half a barricade piece's length
var _dirty := false             # the Well mended a wrecked piece: its Save.placed entry is written soon (not saved)
var _sync_t := 0.0
var _markers: MarkersScript                  # defence_markers.gd: the road-spot and tower markers and the cards
var _placement: PlacementScript                # defence_placement.gd (B0): the ghost and the Place/Undo transaction
var _win_piece := Callable()    # H6: the windows' card builders (use_window_builders); not used in Stage 1
var _win_row := Callable()
var _win_pad := Callable()

# What the placement helper holds, read through here (the tests and the HUD read these names on defences).
var placing: String:
	get:
		return String(_placement.placing) if _placement != null else ""
	set(v):
		if _placement != null:
			_placement.placing = v
var ghost: Node3D:
	get:
		return _placement.ghost if _placement != null else null
var ghost_ok: bool:
	get:
		return bool(_placement.ghost_ok) if _placement != null else false
var _ghost_pos: Vector3:
	get:
		return _placement.ghost_pos if _placement != null else Vector3.ZERO

# What the markers helper holds (the autotests read these names on defences).
var _spots: Dictionary:
	get:
		return _markers.spots
var _tower_marks: Dictionary:
	get:
		return _markers.tower_marks


func build(m) -> void:
	main = m
	_markers = MarkersScript.new()
	_markers.setup(self)
	_placement = PlacementScript.new(self)
	_markers.make_spot_marks()
	load_saved()
	if not Save.changed.is_connected(_update_pulses):
		Save.changed.connect(_update_pulses)


## Builds every placed defence from the save (at the start; the tests call it again after changing the save). Old saves
## are brought up to date first (DefencePersistence: fences refunded, barricade pieces turned into rows, the bag's
## barricades refunded). The order is the H5 order: config, clear (it stops placing), clean-up, move blocked, spawn.
func load_saved() -> void:
	_read_cfg()
	_clear()
	var norm: Dictionary = DefencePersistence.normalise_saved()
	for n in norm.get("notes", []):
		_note(String(n))
	var changed := bool(norm.get("save", false))
	if changed:
		Save.save_game()
	_move_blocked()
	for sp in Save.placed:
		spawn_placement(sp)
	_markers.marks = -1
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
	_markers.reset()
	pieces = []
	rows = []
	_by_id = {}
	_markers.reset_spots()


func _note(msg: String) -> void:
	if main.hud != null:
		main.hud.toast(msg)
	else:
		main.hud_note = msg if main.hud_note == "" else main.hud_note + "\n" + msg


## Barricade pieces in the bag (an older save, or a gift of pieces) are refunded as leaves (DefencePersistence does the
## sum and the words). True if leaves were given. At load the caller saves; later this saves and refreshes the build menu.
func _absorb_gift(at_load := false) -> bool:
	if not Save.items.has("barricade"):
		return false
	var r: Dictionary = DefencePersistence.absorb_bag()
	var leaves := int(r.get("leaves", 0))
	if leaves <= 0:
		return false
	var msg := String(r.get("note", ""))
	if msg != "":
		_note(msg)
	if not at_load and main.hud != null:
		main.hud.refresh_build()
	return true


## Phase C (and E: round a Burrow's hollow; and the camp's buildings round the fire since 18 Nov 2026): towers and
## spikes on the ground kept for the stone, the garden, the fishing spot or a building and its ring go back to the Bag
## (older saves could place them anywhere off the roads). H3: through Bag.add with force (a piece already paid for
## always goes back, even into a full Bag). The rule is off_limits(), the one the placing ghost uses too.
func _move_blocked() -> void:
	var moved := 0
	var keep2: Array = []
	for sp in Save.placed:
		var t := String(sp.get("type", ""))
		var at := Vector3(float(sp.get("x", 0.0)), 0, float(sp.get("z", 0.0)))
		if (t == "tower" or t == "spikes") and sp.has("x") and sp.has("z") and off_limits(at):
			Bag.add(t, 1, true)
			moved += 1
			continue
		keep2.append(sp)
	if moved > 0:
		Save.placed = keep2
		_note("%d defence piece%s stood where the camp needs room: place %s again" % [moved, "s" if moved > 1 else "", "them" if moved > 1 else "it"])
		Save.save_game()


## A saved row: built at its road spot, each piece's kept wreck (Save.placed "wrecks": its share of health, -1 whole).
func _spawn_row_saved(sp: Dictionary, lv := 0) -> Dictionary:
	var sl = sp.get("slot", [])
	if typeof(sl) != TYPE_ARRAY or (sl as Array).size() != 2:
		return {}
	var row := _spawn_row(int(sl[0]), int(sl[1]), sp, lv if lv > 0 else level("barricade"))
	if row.is_empty():
		return {}
	var w = sp.get("wrecks", [])
	if typeof(w) == TYPE_ARRAY:
		for p in row["pieces"]:
			var k := int(p["k"])
			if k < (w as Array).size() and float(w[k]) >= 0.0:
				_wreck(p, float(w[k]))
	return row


## Builds one placed thing from its Save.placed record: a tower or patch (returns the piece, with p["src"] = record and
## its kept wreck applied) or a row (returns the row). {} when the record can't be built. It never touches Save.placed
## or the Bag: whoever calls it (load_saved, the placement helper) owns those. Stage 1: the kind's shared level.
func spawn_placement(record: Dictionary) -> Dictionary:
	var type := String(record.get("type", ""))
	if type == "barricade":
		return _spawn_row_saved(record, level("barricade"))
	if not (type in ["tower", "spikes"]) or not record.has("x") or not record.has("z"):
		return {}
	var p := _spawn(type, Vector3(float(record["x"]), 0, float(record["z"])), float(record.get("rot", 0.0)), [], level(type))
	p["src"] = record
	if record.has("wreck"):
		_wreck(p, float(record["wreck"]))
	return p


## A tower or patch taken back out of the camp (an undone placement): its node, collision and repair marker go, and so
## does its place in pieces and _by_id. It never touches Save.placed or the Bag. False if there is no such piece (or it
## is a barricade piece: rows are not placed this way).
func remove_placement(id: int) -> bool:
	var p: Dictionary = _by_id.get(id, {})
	if p.is_empty() or String(p["type"]) == "barricade":
		return false
	if is_instance_valid(p["node"]):
		(p["node"] as Node3D).queue_free()
	main.world.remove_tag("piece_%d" % id)
	_markers.remove_tower_mark(id)
	for i in pieces.size():
		if int(pieces[i]["id"]) == id:
			pieces.remove_at(i)
			break
	_by_id.erase(id)
	return true


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
	_markers.follow_spots()


func level(type: String) -> int:
	return clampi(int(Save.def_levels.get(type, 1)), 1, (Data.defence_info(type)["levels"] as Array).size())


## The model of a kind at a level: the tier's own "model" (defence_info levels[].model). A level whose model is not made
## yet shows the one before it.
func model(type: String, lv: int) -> String:
	var name := String(Data.defence_level_info(type, lv).get("model", ""))
	if lv > 1 and (name == "" or not Props.has(name)):
		return model(type, lv - 1)
	return name


func unlocked(type: String) -> bool:
	return Data.progress() >= int(Data.defence_info(type).get("unlock_missions", 0))


## How many of a kind the camp has: in the Bag (H3: Bag.count) and placed.
func _count(type: String) -> int:
	var n := Bag.count(type)
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


## A piece's health at a level (lv 0: the kind's level now).
func _max_hp(type: String, lv := 0) -> float:
	if type == "spikes":
		return 1.0
	return float(Data.defence_level_info(type, lv if lv > 0 else level(type)).get("hp", 1))


## A tower or spikes (placed with the build button) at level `lv` (0: the kind's level now: older tests pass none). A
## barricade asked for at a road spot (older tests) is its row's first piece (the row is built if there is none).
func _spawn(type: String, pos: Vector3, rot: float, slot: Array = [], lv := 0) -> Dictionary:
	var at_level := lv if lv > 0 else level(type)
	if type == "barricade":
		if slot.size() != 2:
			return {}
		var have := row_at(int(slot[0]), int(slot[1]))
		var row := have if not have.is_empty() else _spawn_row(int(slot[0]), int(slot[1]), null, at_level)
		return row["pieces"][0] if not row.is_empty() else {}
	var node := Props.instance(model(type, at_level))
	node.position = pos
	node.rotation.y = rot
	add_child(node)
	var p := {"id": _next, "type": type, "pos": pos, "rot": rot, "node": node, "hp": 1.0, "max_hp": _max_hp(type, at_level), "cd": 0.0,
		"wrecked": false, "broken": false, "slot": slot, "src": null}
	_next += 1
	p["hp"] = p["max_hp"]
	pieces.append(p)
	_by_id[int(p["id"])] = p
	_collide(p)
	if type == "tower":
		_setup_tower(p, at_level)
		_markers.make_tower_mark(p)
	return p


## A row of barricade pieces at a road spot (none there yet) at level `lv` (0: the kind's level now). src: its
## Save.placed entry (null: not saved, tests).
func _spawn_row(lane: int, idx: int, src, lv := 0) -> Dictionary:
	var s: Array = main.world.barricade_slot(lane, idx)
	if s.is_empty() or not row_at(lane, idx).is_empty():
		return {}
	var at_level := lv if lv > 0 else level("barricade")
	var n := pieces_per_row()
	var root = RowScript.new()
	add_child(root)
	root.setup(lane, idx, s[0], float(s[1]), n, float(Data.defence_info("barricade").get("length", 3.0)))
	var row := {"slot": [lane, idx], "root": root, "pieces": [], "src": src}
	var mx := _max_hp("barricade", at_level)
	var nm := model("barricade", at_level)
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
	_markers.attach_spot(lane, idx)
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
	var lv := level(type)
	for p in pieces:
		if p["type"] != type:
			continue
		var share := clampf(float(p["hp"]) / maxf(float(p["max_hp"]), 1.0), 0.0, 1.0)
		p["max_hp"] = _max_hp(type, lv)
		if p["wrecked"]:
			p["hp"] = float(p["max_hp"]) * share
			p["broken"] = float(p["hp"]) <= 0.0
		else:
			p["hp"] = p["max_hp"]
			p["broken"] = false
		if type == "barricade":
			p["node"] = p["root"].set_model(int(p["k"]), model(type, lv))
		else:
			(p["node"] as Node3D).queue_free()
			var node := Props.instance(model(type, lv))
			node.position = p["pos"]
			node.rotation.y = p["rot"]
			add_child(node)
			p["node"] = node
			if type == "tower":
				_setup_tower(p, lv)
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


## The wrecks into the Save.placed entries (not saved yet): DefencePersistence does it (a row's "wrecks" holds each
## piece's share of health, -1 not wrecked; a tower's "wreck" its own).
func _write_wrecks() -> void:
	DefencePersistence.write_wrecks(pieces, rows)


## Points every row and piece at its Save.placed entry again (after the save was read back in while the camp stands:
## tests).
func relink_saved() -> void:
	DefencePersistence.relink_saved(pieces, rows)


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
	var rng := float(Data.defence_level_info("tower", level("tower"))["range"]) + float(cfg["tower_reach_bonus"])
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


# ---------------------------------------------------------------- the level API (H6)
## Stage 1 keeps the shared levels (Save.def_levels) and the old shelf: these answer from them, or are stubs that the
## live switch (Stage 2) fills. -1 means "no piece" for an id and Vector2i(-1, -1) "no slot".

## The piece with an id ({} when there is none: a piece taken back, or an id that never was).
func piece_at(id: int) -> Dictionary:
	return _by_id.get(id, {})


func piece_level(p: Dictionary) -> int:
	return level(String(p.get("type", "tower")))


func row_level(_row: Dictionary) -> int:
	return level("barricade")


func best_level(kind: String) -> int:
	return level(kind)


## How many of a kind stand in the camp (placed, downed ones too): a row counts once.
func placed_count(kind: String) -> int:
	if kind == "barricade":
		return rows.size()
	var n := 0
	for p in pieces:
		if p["type"] == kind:
			n += 1
	return n


## What upgrading one placed piece or row would cost (the live switch: per-piece levels). Stage 1: always "coming later".
func upgrade_quote(_kind: String, _id: int, _slot: Vector2i, _expected_level: int) -> Dictionary:
	return {"next_level": 0, "price": {}, "reason": Data.word("coming_later")}


func upgrade_placed(_kind: String, _id: int, _slot: Vector2i, _expected_level: int) -> bool:
	return false


## The marker to walk the cat to for a level goal (the live switch). Stage 1: none.
func goal_marker(_kind: String, _min_level: int) -> Node:
	return null


## A specialisation changed (the live switch recomputes the pieces it touches). Stage 1: nothing to do.
func refresh_specialisation(_id: String) -> void:
	pass


## The windows hand over how to build the piece, row and pad cards (the live switch uses them).
func use_window_builders(piece: Callable, row: Callable, pad: Callable) -> void:
	_win_piece = piece
	_win_row = row
	_win_pad = pad


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
	var row := _spawn_row(lane, idx, sp, level("barricade"))
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


# ---------------------------------------------------------------- the markers and cards (defence_markers.gd)
static func _key(lane: int, idx: int) -> String:
	return "%d:%d" % [lane, idx]


func _refresh_marks() -> void:
	_markers.refresh_marks()


func _update_pulses() -> void:
	_markers.update_pulses()


func _card_spot(lane: int, idx: int) -> Dictionary:
	return _markers.card_spot(lane, idx)


func _card_row(row: Dictionary) -> Dictionary:
	return _markers.card_row(row)


func _card_tower(id: int) -> Dictionary:
	return _markers.card_tower(id)


# ---------------------------------------------------------------- placing (defence_placement.gd, B0)
func start_placing(type: String) -> void:
	_placement.start_placing(type)


func stop_placing() -> void:
	if _placement != null:
		_placement.stop_placing()


## Places the piece where the ghost is green, taking one from the Bag.
func place_here() -> void:
	_placement.place_here()


## The ghost is green here (see defence_placement.gd; kind "": the kind being placed).
func _valid(pos: Vector3, kind := "") -> bool:
	return _placement.valid(pos, kind)


func placement_reason(kind: String, at: Vector3) -> String:
	return _placement.placement_reason(kind, at)


func commit_placement(kind: String, at: Vector3, yaw: float) -> int:
	return _placement.commit(kind, at, yaw)


func undo_reason(id: int) -> String:
	return _placement.undo_reason(id)


func revert_placement(id: int) -> bool:
	return _placement.revert(id)


func can_undo_place() -> bool:
	return _placement.can_undo()


func undo_place() -> bool:
	if not _placement.can_undo():
		return false
	if not UndoPlaceDefence.new(_placement.undo_id()).run(main):
		return false
	Save.save_game()
	return true


## How many held pieces would go back to the Bag if a building of this id were built on its ground (the Workshop's build).
func return_blocked_for_station(id: String) -> int:
	return _placement.return_blocked_for_station(id)


## The ground towers and spikes keep off: the ground kept for the camp's stations and buildings (built or not) and the
## village, a Burrow's hollow and its path (Phase E), the home, and the lake's shore. One rule for the placing ghost
## (_valid) and the start-up check (_move_blocked), so a piece the ghost lets you place is never sent back to the Bag
## (H3, the owner's yes to Q25, 26 Nov 2026: the ghost used to miss the home and the lake).
func off_limits(pos: Vector3) -> bool:
	var w = main.world
	return w.in_reserved(pos, 0.6) or w.in_village(pos, 0.6) or w.in_hollow_clear(pos) or w.near_hollow(pos, _hollow_keep()) \
		or w.near_home(pos, 0.6) or w.lake_dist(pos) < 0.6


func _process(delta: float) -> void:
	if main == null:
		return
	if Save.items.has("barricade"):
		_absorb_gift()                              # a gift of pieces (an older mission reward): refunded as leaves
	_markers.tick()                                 # a wave started or ended, the cat went below ground or came up
	if _dirty:
		_sync_t += minf(delta, 0.1)
		if _sync_t >= 1.0:
			_sync_t = 0.0
			_dirty = false
			_write_wrecks()
	_placement.update_ghost()                        # last: the ghost follows the cat (nothing when not placing)


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
		if p["type"] == "spikes" and not p["broken"] and (p["pos"] as Vector3).distance_to(pos) < SPIKE_R:
			return float(Data.defence_level_info("spikes", level("spikes"))["slow"])
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
func _setup_tower(p: Dictionary, lv: int) -> void:
	var node = p["node"]
	node.set_script(TowerScript)
	node.setup(main, p, lv)


## Towers and spikes work every physics frame, in the order of `pieces`. Who is near comes from the enemy grid: a
## tower asks for the foes in a box its range wide (tower.tick keeps its own exact range and nearest-first rule, the
## first in line wins a tie), a patch asks for a box of SPIKE_R, then checks the exact distance and hurts through
## enemy.hurt_spikes (the one damage path: quiet, with the old lethal wake-up).
func _physics_process(delta: float) -> void:
	if main == null or main.frozen:
		return
	var grid = main.enemy_grid
	var reach := float(Data.defence_level_info("tower", level("tower"))["range"])
	var dps := float(Data.defence_level_info("spikes", level("spikes"))["dps"])
	for p in pieces:
		if p["broken"] or float(p["hp"]) <= 0.0:
			continue
		var at: Vector3 = p["pos"]
		match String(p["type"]):
			"tower":
				var foes: Array = grid.candidates(Vector2(at.x - reach, at.z - reach), Vector2(at.x + reach, at.z + reach), &"foes")
				p["node"].tick(delta, foes)
			"spikes":
				var under: Array = grid.candidates(Vector2(at.x - SPIKE_R, at.z - SPIKE_R), Vector2(at.x + SPIKE_R, at.z + SPIKE_R), &"foes")
				for e in under:
					if not e.dead and (e.global_position as Vector3).distance_to(at) < SPIKE_R:
						e.hurt_spikes(dps * delta)


## Phase E: how far placed defences keep from a Burrow's hollow.
func _hollow_keep() -> float:
	return float(Data.burrow_list()[0]["entrance"].get("defence_keep_out", 2.6))
