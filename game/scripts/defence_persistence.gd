## Defence persistence (H6 Stage 1, 27 Nov 2026; docs/ARCHITECTURE.md part 10 the save): what happens to the defences
## when the camp is loaded, saved or relinked. Static functions only, no class_name: callers preload this file
## (`const DefencePersistence := preload("res://scripts/defence_persistence.gd")`).
## Used by: defences.gd (load_saved, _process gift path, _write_wrecks, relink_saved), B0's placement commands (credits).
## Uses: Save (placed, items, leaves), Data.defence_info.
## Rules:
##   - The first three moves are the H5 ones, moved here unchanged and in the same order: old fences refunded, old
##     single barricade pieces made into rows, barricades in the Bag refunded. They return their notes (the
##     caller shows them) instead of calling the HUD.
##   - Records are shared with the live pieces (`p["src"]`): never duplicate() one. Replacing the Save.placed array with
##     the same dictionaries is fine.
##   - Credits (Save.defence_legacy_credit) are written only by the v6 converter. In Stage 1 they stay empty, so
##     peek_credit and take_credit return 0.


## The old-save clean-up that runs at every load. Returns {"save": bool (the save changed and should be written),
## "notes": Array[String] (what to tell the player, in the H5 order)}.
static func normalise_saved() -> Dictionary:
	var notes: Array[String] = []
	_refund_fences(notes)
	var changed := _rows_from_old(notes)
	var gift := _absorb_bag(notes)
	return {"save": gift > 0 or changed, "notes": notes}


## Barricade pieces in the Bag later in play (an older mission reward): refunded as leaves and saved. Returns
## {"leaves": int refunded (0 = nothing), "note": String ("" = nothing)}. The caller refreshes the HUD.
static func absorb_bag() -> Dictionary:
	var notes: Array[String] = []
	var leaves := _absorb_bag(notes)
	if leaves <= 0:
		return {"leaves": 0, "note": ""}
	Save.save_game()
	return {"leaves": leaves, "note": notes[0]}


## The wrecks into the Save.placed entries (not saved yet): a row's "wrecks" holds each piece's share of health (-1:
## not wrecked; its "wreck" the weakest one's, for older readers: loading uses "wrecks"), a tower's "wreck" its own.
## `pieces` and `rows` are the live arrays of defences.gd.
static func write_wrecks(pieces: Array, rows: Array) -> void:
	for row: Dictionary in rows:
		var sp: Variant = _row_src(row)
		if sp == null:
			continue
		sp["level"] = int(row.get("level", sp.get("level", 1)))
		var worst := 2.0
		for p: Dictionary in row["pieces"]:
			if p["wrecked"]:
				worst = minf(worst, float(p["hp"]) / maxf(float(p["max_hp"]), 1.0))
		if worst > 1.5:
			sp.erase("wrecks")
			sp.erase("wreck")
			continue
		var w: Array = []
		for p: Dictionary in row["pieces"]:
			w.append(snappedf(float(p["hp"]) / maxf(float(p["max_hp"]), 1.0), 0.0001) if p["wrecked"] else -1.0)
		sp["wrecks"] = w
		sp["wreck"] = worst
	for p: Dictionary in pieces:
		if p["type"] == "barricade":
			continue
		var sp2: Variant = p.get("src")
		if sp2 == null:
			continue
		sp2["level"] = int(p.get("level", sp2.get("level", 1)))
		if p["wrecked"]:
			sp2["wreck"] = float(p["hp"]) / float(p["max_hp"])
		else:
			sp2.erase("wreck")


## Points every row and piece at its Save.placed entry again (after the save was read back in while the camp stands:
## tests). Rows match by slot, pieces by position within 0.01.
static func relink_saved(pieces: Array, rows: Array) -> void:
	for row: Dictionary in rows:
		row["src"] = null
		for sp: Dictionary in Save.placed:
			if String(sp.get("type", "")) != "barricade":
				continue
			var sl: Variant = sp.get("slot", [])
			if typeof(sl) == TYPE_ARRAY and (sl as Array).size() == 2 and int(sl[0]) == int(row["slot"][0]) and int(sl[1]) == int(row["slot"][1]):
				row["src"] = sp
				break
		for p: Dictionary in row["pieces"]:
			p["src"] = row["src"]
	for p: Dictionary in pieces:
		if p["type"] == "barricade":
			continue
		p["src"] = null
		for sp: Dictionary in Save.placed:
			if String(sp.get("type", "")) == String(p["type"]) and sp.has("x") \
					and absf(float(sp["x"]) - (p["pos"] as Vector3).x) < 0.01 and absf(float(sp["z"]) - (p["pos"] as Vector3).z) < 0.01:
				p["src"] = sp
				break


## What a piece carries when it goes back to the Bag: {"level": int} plus "wreck" (its share of health) when worn.
## `piece` is a live piece (it has max_hp) or a saved record (its "wreck", if any). The level is the record's own;
## in Stage 1, where no record has one, it is 1.
static func carried_record(piece: Dictionary) -> Dictionary:
	var out: Dictionary = {"level": maxi(1, int(piece.get("level", 1)))}
	if piece.has("max_hp"):
		if bool(piece.get("wrecked", false)):
			out["wreck"] = clampf(float(piece.get("hp", 0.0)) / maxf(float(piece["max_hp"]), 1.0), 0.0, 1.0)
	elif piece.has("wreck"):
		out["wreck"] = clampf(float(piece["wreck"]), 0.0, 1.0)
	return out


## The level of the legacy credit waiting for kind (0 = none). Stage 1: always 0 (nothing writes credits yet).
static func peek_credit(kind: String) -> int:
	return maxi(0, int(Save.defence_legacy_credit.get(kind, 0)))


## Uses up kind's credit and returns its level (0 = none). The caller commits it in the same step that makes the first
## piece or row of the kind. Marks the save dirty when it used one.
static func take_credit(kind: String) -> int:
	var level := peek_credit(kind)
	if level > 0:
		Save.defence_legacy_credit.erase(kind)
		Save.mark_dirty()
	return level


# ---------------------------------------------------------------- inside (the H5 moves, verbatim)
static func _pieces_per_row() -> int:
	var r: Variant = Data.defence_info("barricade").get("row", {})
	return maxi(1, int(r.get("pieces", 3))) if typeof(r) == TYPE_DICTIONARY else 3


static func _key(lane: int, idx: int) -> String:
	return "%d:%d" % [lane, idx]


## Fences are gone: any left in an old save are refunded as leaves.
static func _refund_fences(notes: Array[String]) -> void:
	var piece := int(Data.defence_info("fence")["piece"])
	var refund := int(Save.items.get("fence", 0)) * piece
	Save.items.erase("fence")
	var keep: Array = []
	for sp: Dictionary in Save.placed:
		if String(sp.get("type", "")) == "fence":
			refund += piece
			continue
		keep.append(sp)
	Save.placed = keep
	if refund > 0:
		Save.leaves += refund
		Save.set_flag("fence_refund")
		Save.save_game()
		notes.append("Fences are gone: you got %d leaves back. Block the roads with barricades now." % refund)


## Phase G2: a placed barricade piece of an older save becomes a row at its road spot (two at one spot: one row); a
## wrecked one keeps its wreck in each of the row's pieces. True if the save changed.
static func _rows_from_old(notes: Array[String]) -> bool:
	var per := _pieces_per_row()
	var keep: Array = []
	var seen := {}
	var changed := false
	var turned := 0
	for sp: Dictionary in Save.placed:
		if String(sp.get("type", "")) != "barricade":
			keep.append(sp)
			continue
		var sl: Variant = sp.get("slot", [])
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
			sp["row"] = per
			if sp.has("wreck"):
				if not sp.has("wrecks"):
					var f := clampf(float(sp["wreck"]), 0.0, 1.0)
					var w: Array = []
					for k in per:
						w.append(f)
					sp["wrecks"] = w
				sp.erase("wreck")
			turned += 1
			changed = true
		keep.append(sp)
	if changed:
		Save.placed = keep
	if turned > 0:
		notes.append("Barricades stand in rows of %d now, and each piece breaks on its own. Tap a row on the road to repair it." % per)
	return changed


## Barricade pieces in the Bag (an older save, or a gift of pieces): each is refunded at its old price and the Bag keeps
## no barricades, so the build button never offers one. Returns the leaves given back (0 = none).
static func _absorb_bag(notes: Array[String]) -> int:
	if not Save.items.has("barricade"):
		return 0
	var n := int(Save.items.get("barricade", 0))
	Save.items.erase("barricade")
	if n <= 0:
		return 0
	var refund := n * int(Data.defence_info("barricade").get("piece", 30))
	Save.leaves += refund
	notes.append("Barricades are built at the road spots now: %d barricade piece%s became %d leaves." % [n, "s" if n > 1 else "", refund])
	return refund


## A row's Save.placed entry (an older test sets it on the row's first piece).
static func _row_src(row: Dictionary) -> Variant:
	if row["src"] == null:
		for p: Dictionary in row["pieces"]:
			if p.get("src") != null:
				row["src"] = p["src"]
				break
	return row["src"]
