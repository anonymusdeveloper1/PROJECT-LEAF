## Save step 5 -> 6 (H6, 27 Nov 2026; the owner's answers; docs/ARCHITECTURE.md part 10): defence levels move from one
## level per kind (`def_levels`) onto the pieces. Called by core/save_upgrades.gd; no class_name (callers preload it).
## Rules:
##   - A pure function: it reads only the dictionary it is given and balance.json save_upgrades.to_v6 (frozen
##     numbers). It never touches Save, Bag or the world. Any key missing or odd counts as none: {"leaves": 5} passes.
##   - Every tower and spikes record with x and z, and every barricade record (single-piece old ones too), gets
##     `level` = its kind's old level (clamped to 1..level_cap). Records are changed in place; the other fields and
##     unrelated records stay as they are.
##   - Held towers and spikes keep the kind's old level: when it is not 1, reserves[kind] holds one {"level": L} per
##     held piece. Fresh level-1 stock needs no record.
##   - An old paid level above 1 with no piece to carry it (no placed piece, no barricade row spot, no held stock)
##     becomes credit[kind] = L: the first new piece of the kind gets it. A barricade in the Bag is refund stock and
##     never counts.
##   - `def_levels` is erased. A file without it was already converted: the step then only checks the levels, reserves
##     and credits it finds and works out nothing again (a second run must not wipe the reserves).
##   - The result writes into d["defence_reserves"] and d["defence_legacy_credit"] (the names of the two Save fields).

const KINDS_FALLBACK: Array[String] = ["barricade", "tower", "spikes"]


static func upgrade(d: Dictionary) -> Dictionary:
	var cfg: Dictionary = _cfg()
	var default_level: int = maxi(1, int(cfg.get("default_level", 1)))
	var caps: Dictionary = cfg.get("level_cap", {}) if cfg.get("level_cap") is Dictionary else {}
	var bag_kinds: Array = cfg.get("bag_kinds", ["tower", "spikes"]) if cfg.get("bag_kinds") is Array else ["tower", "spikes"]
	var row_kind: String = String(cfg.get("row_kind", "barricade"))
	var placed: Array = d.get("placed", []) if d.get("placed") is Array else []
	var items: Dictionary = d.get("items", {}) if d.get("items") is Dictionary else {}
	var levels: Dictionary = {}
	var converted: bool = not d.has("def_levels")
	var old: Dictionary = d.get("def_levels", {}) if d.get("def_levels") is Dictionary else {}
	for kind: String in KINDS_FALLBACK:
		var cap: int = maxi(1, int(_num(caps.get(kind, 5))))
		var lv: int = default_level if converted else int(_num(old.get(kind, default_level)))
		levels[kind] = clampi(lv, 1, cap)

	# 1. the placed records
	var present: Dictionary = {}                                   # kinds that have a placed piece or a row spot
	for sp: Variant in placed:
		if not sp is Dictionary:
			continue
		var rec: Dictionary = sp
		var t: String = String(rec.get("type", ""))
		if not levels.has(t):
			continue
		if t == row_kind:
			if _valid_slot(rec.get("slot")):
				present[t] = true
		elif rec.has("x") and rec.has("z"):
			present[t] = true
		else:
			continue                                               # a tower without a place: not a piece, left alone
		if converted and rec.has("level"):
			rec["level"] = clampi(int(_num(rec["level"])), 1, _cap(caps, t))
		else:
			rec["level"] = int(levels[t]) if not converted else default_level
	# a barricade record without a valid slot still carries its kind's level
	for sp: Variant in placed:
		if sp is Dictionary and String((sp as Dictionary).get("type", "")) == row_kind and not (sp as Dictionary).has("level"):
			(sp as Dictionary)["level"] = int(levels[row_kind]) if not converted else default_level

	# 2. held stock and credits
	var reserves: Dictionary = {}
	var credit: Dictionary = {}
	if converted:
		var rv: Dictionary = d.get("defence_reserves", {}) if d.get("defence_reserves") is Dictionary else {}
		for k: Variant in bag_kinds:
			var kind: String = String(k)
			var held: int = maxi(0, int(_num(items.get(kind, 0))))
			var list: Array = []
			var src: Variant = rv.get(kind)
			if src is Array:
				for r: Variant in src:
					if r is Dictionary and list.size() < held:
						var one: Dictionary = {"level": clampi(int(_num((r as Dictionary).get("level", 1))), 1, _cap(caps, kind))}
						if (r as Dictionary).has("wreck"):
							one["wreck"] = clampf(_num((r as Dictionary)["wreck"]), 0.0, 1.0)
						list.append(one)
			if not list.is_empty():
				reserves[kind] = list
		var cd: Dictionary = d.get("defence_legacy_credit", {}) if d.get("defence_legacy_credit") is Dictionary else {}
		for kind: String in KINDS_FALLBACK:
			var c: int = int(_num(cd.get(kind, 0)))
			if c > 0:
				credit[kind] = clampi(c, 1, _cap(caps, kind))
	else:
		for k: Variant in bag_kinds:
			var kind: String = String(k)
			if not levels.has(kind):
				continue
			var held: int = maxi(0, int(_num(items.get(kind, 0))))
			if held > 0:
				present[kind] = true
				if int(levels[kind]) != 1:
					var list: Array = []
					for i in held:
						list.append({"level": int(levels[kind])})
					reserves[kind] = list
		for kind: String in KINDS_FALLBACK:
			if int(levels[kind]) > 1 and not present.has(kind):
				credit[kind] = int(levels[kind])
	d["defence_reserves"] = reserves
	d["defence_legacy_credit"] = credit
	d.erase("def_levels")
	return d


## balance.json save_upgrades.to_v6, or {} while it is missing.
static func _cfg() -> Dictionary:
	var su: Variant = Data.b.get("save_upgrades", {})
	if su is Dictionary and (su as Dictionary).get("to_v6") is Dictionary:
		return (su as Dictionary)["to_v6"]
	return {}


static func _cap(caps: Dictionary, kind: String) -> int:
	return maxi(1, int(_num(caps.get(kind, 5))))


static func _valid_slot(sl: Variant) -> bool:
	return typeof(sl) == TYPE_ARRAY and (sl as Array).size() == 2


## A JSON number as a float; anything else counts as 0.
static func _num(v: Variant) -> float:
	return float(v) if (v is float or v is int) else 0.0
